<#
.SYNOPSIS
    Paso 1: Instala IIS con los features exactos de produccion InteliSrcPA.
.DESCRIPTION
    Ejecutar en la instancia base (Golden AMI) antes de crear la AMI.
    Features extraidos de la configuracion productiva (USAEA1TWBWES38).
#>

Write-Output "========================================="
Write-Output " PASO 1: Instalando IIS Web Server"
Write-Output "========================================="

# Features exactos de produccion InteliSrcPA
$features = @(
    'Web-Default-Doc',
    'Web-Dir-Browsing',
    'Web-Http-Errors',
    'Web-Static-Content',
    'Web-Http-Redirect',
    'Web-Http-Logging',
    'Web-Custom-Logging',
    'Web-Log-Libraries',
    'Web-ODBC-Logging',
    'Web-Http-Tracing',
    'Web-Stat-Compression',
    'Web-Filtering',
    'Web-Basic-Auth',
    'Web-CertProvider',
    'Web-Client-Auth',
    'Web-Cert-Auth',
    'Web-IP-Security',
    'Web-Url-Auth',
    'Web-Windows-Auth',
    'Web-Net-Ext',
    'Web-Net-Ext45',
    'Web-AppInit',
    'Web-ASP',
    'Web-Asp-Net',
    'Web-Asp-Net45',
    'Web-CGI',
    'Web-ISAPI-Ext',
    'Web-ISAPI-Filter',
    'Web-Ftp-Service',
    'Web-Ftp-Ext',
    'Web-Mgmt-Console',
    'Web-Scripting-Tools',
    'Web-Mgmt-Service'
)

Write-Output "Instalando $($features.Count) features..."
Install-WindowsFeature -Name $features -IncludeManagementTools

# Verificar instalacion
$failed = @()
foreach ($feature in $features) {
    $f = Get-WindowsFeature -Name $feature
    if ($f.InstallState -ne 'Installed') {
        $failed += $feature
    }
}

if ($failed.Count -gt 0) {
    Write-Error "FALLO: Los siguientes features no se instalaron: $($failed -join ', ')"
    exit 1
}

# Importar modulo para configuracion
Import-Module WebAdministration

# Configurar DefaultAppPool
Set-ItemProperty "IIS:\AppPools\DefaultAppPool" -Name "managedRuntimeVersion" -Value "v4.0"
Set-ItemProperty "IIS:\AppPools\DefaultAppPool" -Name "startMode" -Value "AlwaysRunning"

# Logging W3C
Set-WebConfigurationProperty -Filter "system.applicationHost/sites/siteDefaults/logFile" `
    -Name "logFormat" -Value "W3C"

Write-Output ""
Write-Output "OK: IIS instalado con $($features.Count) features."
Write-Output "  - DefaultAppPool: .NET 4.0, AlwaysRunning"
Write-Output "  - Logging: W3C"
Write-Output ""
