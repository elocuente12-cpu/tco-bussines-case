<#
.SYNOPSIS
    Paso 2: Crea el script de mount de FSx para ejecucion en runtime.
.DESCRIPTION
    Ejecutar en la instancia base antes de crear la AMI.
    Crea C:\Scripts\Startup\Mount-FsxShare.ps1 que se invoca desde UserData.
#>

Write-Output "========================================="
Write-Output " PASO 2: Configurando scripts de FSx"
Write-Output "========================================="

$scriptsPath = "C:\Scripts\Startup"
if (-not (Test-Path $scriptsPath)) {
    New-Item -Path $scriptsPath -ItemType Directory -Force | Out-Null
}

$mountScript = @'
param(
    [Parameter(Mandatory)]
    [string]$FsxDnsName,
    [string]$ShareName = "share",
    [string]$DriveLetter = "Z"
)

$maxRetries = 30
$retryCount = 0
while ($retryCount -lt $maxRetries) {
    try {
        $testPath = "\\$FsxDnsName\$ShareName"
        if (Test-Path $testPath) { break }
    } catch {
        Write-Output "Esperando disponibilidad de FSx... intento $retryCount"
    }
    Start-Sleep -Seconds 10
    $retryCount++
}

if (Test-Path "\\$FsxDnsName\$ShareName") {
    New-PSDrive -Name $DriveLetter -PSProvider FileSystem `
        -Root "\\$FsxDnsName\$ShareName" -Persist -Scope Global
    Write-Output "FSx montado en ${DriveLetter}:"
} else {
    Write-Error "FSx no disponible despues de $maxRetries intentos"
    exit 1
}
'@

Set-Content -Path "$scriptsPath\Mount-FsxShare.ps1" -Value $mountScript -Force

Write-Output ""
Write-Output "OK: Script de mount creado en $scriptsPath\Mount-FsxShare.ps1"
Write-Output ""
