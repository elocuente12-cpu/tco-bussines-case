<#
.SYNOPSIS
    Ingenieria inversa de IIS en un Windows Server existente.
    Levanta las features Web-* instaladas y la configuracion real de IIS
    (app pools, sites, bindings, aplicaciones y directorios virtuales)
    y genera Apply-IISConfig.ps1: un PowerShell autocontenido que replica
    esa misma configuracion al ejecutarse en un servidor nuevo.

.DESCRIPTION
    Ejecutar en el servidor ORIGEN como administrador:
        .\Export-IISConfig.ps1 -OutputPath C:\IISExport

    Produce en OutputPath:
        iis-inventory.json    -> resumen legible de lo detectado
        applicationHost.config.reference -> copia de referencia (no se importa)
        Apply-IISConfig.ps1   -> script GENERADO que replica todo en el servidor nuevo

    Luego: copiar Apply-IISConfig.ps1 al servidor destino y ejecutarlo
    como administrador.
#>
#Requires -RunAsAdministrator
param(
    [string]$OutputPath = "C:\IISExport"
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

$web = Get-WindowsFeature -Name 'Web-Server'
if (-not $web.Installed) {
    throw "El rol Web-Server (IIS) no esta instalado en este servidor. Nada que exportar."
}
Import-Module WebAdministration

# ---------------------------------------------------------------------------
# 1. Features de IIS instaladas (solo hojas: los padres se instalan solos)
# ---------------------------------------------------------------------------
Write-Host '[*] Detectando features Web-* instaladas...'
$installed = Get-WindowsFeature -Name 'Web-*' | Where-Object Installed
$leaf = $installed | Where-Object {
    $f = $_
    -not ($installed | Where-Object { $_.Parent -eq $f.Name })
} | Select-Object -ExpandProperty Name

# ---------------------------------------------------------------------------
# 2. Application Pools
# ---------------------------------------------------------------------------
Write-Host '[*] Exportando application pools...'
$defaultPools = @('DefaultAppPool', 'Classic .NET AppPool',
                  '.NET v4.5', '.NET v4.5 Classic', '.NET v2.0', '.NET v2.0 Classic')
$pools = Get-ChildItem IIS:\AppPools | ForEach-Object {
    [ordered]@{
        Name           = $_.Name
        RuntimeVersion = $_.managedRuntimeVersion
        PipelineMode   = "$($_.managedPipelineMode)"
        IdentityType   = "$($_.processModel.identityType)"
        AutoStart      = $_.autoStart
        Enable32Bit    = $_.enable32BitAppOnWin64
        IsDefault      = ($_.Name -in $defaultPools)
    }
}

# ---------------------------------------------------------------------------
# 3. Sites, bindings, aplicaciones y directorios virtuales
# ---------------------------------------------------------------------------
Write-Host '[*] Exportando sites, bindings, apps y vdirs...'
$sites = Get-Website | ForEach-Object {
    $siteName = $_.Name
    [ordered]@{
        Name         = $siteName
        PhysicalPath = [Environment]::ExpandEnvironmentVariables($_.PhysicalPath)
        AppPool      = $_.applicationPool
        State        = $_.State
        Bindings     = @($_.bindings.Collection | ForEach-Object {
            [ordered]@{ Protocol = $_.protocol; BindingInformation = $_.bindingInformation }
        })
        Applications = @(Get-WebApplication -Site $siteName | ForEach-Object {
            [ordered]@{
                Path         = $_.Path
                PhysicalPath = [Environment]::ExpandEnvironmentVariables($_.PhysicalPath)
                AppPool      = $_.ApplicationPool
            }
        })
        VirtualDirs  = @(Get-WebVirtualDirectory -Site $siteName | ForEach-Object {
            [ordered]@{
                Path         = $_.Path
                PhysicalPath = [Environment]::ExpandEnvironmentVariables($_.PhysicalPath)
            }
        })
    }
}

# Copia de referencia de la config completa (para auditoria, NO se importa tal cual)
Copy-Item "$env:windir\System32\inetsrv\config\applicationHost.config" `
          (Join-Path $OutputPath 'applicationHost.config.reference')

# ---------------------------------------------------------------------------
# 4. inventory.json
# ---------------------------------------------------------------------------
$inventory = [ordered]@{
    SourceServer  = $env:COMPUTERNAME
    OSVersion     = (Get-CimInstance Win32_OperatingSystem).Caption
    ExportedAtUtc = (Get-Date).ToUniversalTime().ToString('o')
    Features      = @($leaf)
    AppPools      = $pools
    Sites         = $sites
    Notes         = @(
        'El CONTENIDO de los sitios (archivos en PhysicalPath) NO viaja en este export: copialo a S3 aparte o despliegalo desde tu pipeline.',
        'Los certificados SSL (bindings https) no se exportan; instalarlos via ACM/secretos y re-crear el binding https con el thumbprint nuevo.'
    )
}
$inventory | ConvertTo-Json -Depth 8 | Out-File (Join-Path $OutputPath 'iis-inventory.json') -Encoding UTF8

# ---------------------------------------------------------------------------
# 5. Generar Apply-IISConfig.ps1
# ---------------------------------------------------------------------------
Write-Host '[*] Generando Apply-IISConfig.ps1...'
$L = New-Object System.Collections.Generic.List[string]
$L.Add('# Apply-IISConfig.ps1 (GENERADO por Export-IISConfig.ps1 - revisar antes de usar)')
$L.Add("# Origen: $($env:COMPUTERNAME)  Exportado: $((Get-Date).ToString('s'))")
$L.Add('#Requires -RunAsAdministrator')
$L.Add("`$ErrorActionPreference = 'Stop'")
$L.Add("Start-Transcript -Path 'C:\Windows\Temp\apply-iisconfig.log' -Append")
$L.Add('')
$L.Add('# --- 1. Instalar IIS con las mismas features del origen ---')
$featureList = ($leaf | ForEach-Object { "'$_'" }) -join ', '
$L.Add("Install-WindowsFeature -Name @($featureList) -IncludeManagementTools")
$L.Add('Import-Module WebAdministration')
$L.Add('')
$L.Add('# --- 2. Application Pools ---')
foreach ($p in ($pools | Where-Object { -not $_.IsDefault })) {
    $L.Add("if (-not (Test-Path 'IIS:\AppPools\$($p.Name)')) { New-WebAppPool -Name '$($p.Name)' | Out-Null }")
    $L.Add("Set-ItemProperty 'IIS:\AppPools\$($p.Name)' managedRuntimeVersion '$($p.RuntimeVersion)'")
    $L.Add("Set-ItemProperty 'IIS:\AppPools\$($p.Name)' managedPipelineMode '$($p.PipelineMode)'")
    $L.Add("Set-ItemProperty 'IIS:\AppPools\$($p.Name)' processModel.identityType '$($p.IdentityType)'")
    if ($p.Enable32Bit) { $L.Add("Set-ItemProperty 'IIS:\AppPools\$($p.Name)' enable32BitAppOnWin64 `$true") }
}
$L.Add('')
$L.Add('# --- 3. Sites, bindings, aplicaciones y vdirs ---')
foreach ($s in $sites) {
    if ($s.Name -eq 'Default Web Site') { continue }
    $http = $s.Bindings | Where-Object { $_.Protocol -eq 'http' } | Select-Object -First 1
    if (-not $http) { $http = $s.Bindings[0] }
    $bp = $http.BindingInformation -split ':'   # ip:puerto:hostheader
    $L.Add("New-Item -ItemType Directory -Path '$($s.PhysicalPath)' -Force | Out-Null")
    $L.Add("if (-not (Get-Website -Name '$($s.Name)' -ErrorAction SilentlyContinue)) {")
    $L.Add("    New-Website -Name '$($s.Name)' -PhysicalPath '$($s.PhysicalPath)' -ApplicationPool '$($s.AppPool)' -IPAddress '$($bp[0])' -Port $($bp[1]) -HostHeader '$($bp[2])' | Out-Null")
    $L.Add('}')
    foreach ($b in ($s.Bindings | Where-Object { $_ -ne $http })) {
        $xp = $b.BindingInformation -split ':'
        if ($b.Protocol -eq 'https') {
            $L.Add("# TODO binding https $($b.BindingInformation): instalar certificado y crear binding con su thumbprint")
            $L.Add("# New-WebBinding -Name '$($s.Name)' -Protocol https -IPAddress '$($xp[0])' -Port $($xp[1]) -HostHeader '$($xp[2])'")
        } else {
            $L.Add("New-WebBinding -Name '$($s.Name)' -Protocol '$($b.Protocol)' -IPAddress '$($xp[0])' -Port $($xp[1]) -HostHeader '$($xp[2])' -ErrorAction SilentlyContinue")
        }
    }
    foreach ($a in $s.Applications) {
        if ($a.Path -eq '/') { continue }   # la app raiz la crea New-Website
        $appName = $a.Path.TrimStart('/')
        $L.Add("New-Item -ItemType Directory -Path '$($a.PhysicalPath)' -Force | Out-Null")
        $L.Add("if (-not (Get-WebApplication -Site '$($s.Name)' -Name '$appName')) { New-WebApplication -Site '$($s.Name)' -Name '$appName' -PhysicalPath '$($a.PhysicalPath)' -ApplicationPool '$($a.AppPool)' | Out-Null }")
    }
    foreach ($v in $s.VirtualDirs) {
        if ($v.Path -eq '/') { continue }
        $vName = $v.Path.TrimStart('/')
        $L.Add("New-Item -ItemType Directory -Path '$($v.PhysicalPath)' -Force | Out-Null")
        $L.Add("if (-not (Get-WebVirtualDirectory -Site '$($s.Name)' -Name '$vName')) { New-WebVirtualDirectory -Site '$($s.Name)' -Name '$vName' -PhysicalPath '$($v.PhysicalPath)' | Out-Null }")
    }
    $L.Add("Start-Website -Name '$($s.Name)' -ErrorAction SilentlyContinue")
    $L.Add('')
}
$L.Add("Write-Host 'Replicacion de IIS completada.'")
$L.Add('Stop-Transcript')

$L -join "`r`n" | Out-File (Join-Path $OutputPath 'Apply-IISConfig.ps1') -Encoding UTF8

Write-Host ''
Write-Host "[OK] Export completado en: $OutputPath"
Write-Host '     - iis-inventory.json                (inventario legible; revisa Notes)'
Write-Host '     - Apply-IISConfig.ps1               (script de replicacion generado)'
Write-Host '     - applicationHost.config.reference  (solo referencia/auditoria)'
Write-Host ''
Write-Host 'Siguiente paso: copiar Apply-IISConfig.ps1 al servidor nuevo y ejecutarlo como administrador.'
