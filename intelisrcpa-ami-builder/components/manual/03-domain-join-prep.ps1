<#
.SYNOPSIS
    Paso 3: Crea los scripts de domain join/leave para ejecucion en runtime.
.DESCRIPTION
    Ejecutar en la instancia base antes de crear la AMI.
    Crea:
      - C:\Scripts\Domain\Join-Domain.ps1  (invocado por UserData al arrancar)
      - C:\Scripts\Domain\Leave-Domain.ps1 (invocado por Lifecycle Hook al terminar)
    Usa SSM Parameter Store como counter incremental con reciclaje de hostnames.
#>

Write-Output "========================================="
Write-Output " PASO 3: Preparando scripts de dominio"
Write-Output "========================================="

$domainScriptsPath = "C:\Scripts\Domain"
if (-not (Test-Path $domainScriptsPath)) {
    New-Item -Path $domainScriptsPath -ItemType Directory -Force | Out-Null
}

# ─── Join-Domain.ps1 ────────────────────────────────────────────
$joinScript = @'
param(
    [Parameter(Mandatory)][string]$HostnamePrefix,
    [Parameter(Mandatory)][string]$DomainFQDN,
    [Parameter(Mandatory)][string]$SecretId,
    [string]$OUPath,
    [string]$Region = "us-east-1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Obtener instance-id via IMDSv2
$token = Invoke-RestMethod -Method PUT -Uri "http://169.254.169.254/latest/api/token" `
    -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "300"}
$instanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" `
    -Headers @{"X-aws-ec2-metadata-token" = $token}

# Adquirir numero del pool (SSM Parameter Store)
$poolParam = "/intelisrcpa/hostname-pool/$HostnamePrefix"
$availableNumbers = @()
try {
    $poolValue = (Get-SSMParameter -Name $poolParam -Region $Region).Value
    if ($poolValue -and $poolValue.Trim() -ne "") {
        $availableNumbers = $poolValue.Split(",") | Where-Object { $_ -ne "" } | ForEach-Object { [int]$_ }
    }
} catch {}

if ($availableNumbers.Count -gt 0) {
    $assignedNumber = $availableNumbers[0]
    $remainingNumbers = $availableNumbers[1..($availableNumbers.Count - 1)]
    $newPoolValue = ($remainingNumbers -join ",")
    Write-SSMParameter -Name $poolParam -Value $newPoolValue -Type String -Overwrite $true -Region $Region
} else {
    $counterParam = "/intelisrcpa/hostname-counter/$HostnamePrefix"
    $currentMax = 0
    try { $currentMax = [int](Get-SSMParameter -Name $counterParam -Region $Region).Value } catch {}
    $assignedNumber = $currentMax + 1
    Write-SSMParameter -Name $counterParam -Value "$assignedNumber" -Type String -Overwrite $true -Region $Region
}

# Construir hostname
$hostname = "$HostnamePrefix{0:D2}" -f $assignedNumber
Write-Output "Hostname asignado: $hostname (numero: $assignedNumber)"

# Registrar mapping instance-id → numero
$mappingParam = "/intelisrcpa/hostname-mapping/$instanceId"
Write-SSMParameter -Name $mappingParam -Value "$HostnamePrefix|$assignedNumber" -Type String -Overwrite $true -Region $Region

# Obtener credenciales de AD
$secretValue = Get-SECSecretValue -SecretId $SecretId -Region $Region
$creds = $secretValue.SecretString | ConvertFrom-Json
$securePassword = ConvertTo-SecureString $creds.password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($creds.username, $securePassword)

# Renombrar y unir al dominio
Rename-Computer -NewName $hostname -Force
$joinParams = @{
    DomainName = $DomainFQDN
    Credential = $credential
    NewName    = $hostname
    Force      = $true
    Restart    = $true
}
if ($OUPath -and $OUPath -ne "") { $joinParams.OUPath = $OUPath }

Add-Computer @joinParams
'@

Set-Content -Path "$domainScriptsPath\Join-Domain.ps1" -Value $joinScript -Force

# ─── Leave-Domain.ps1 ───────────────────────────────────────────
$leaveScript = @'
param(
    [Parameter(Mandatory)][string]$SecretId,
    [string]$Region = "us-east-1"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Obtener instance-id
$token = Invoke-RestMethod -Method PUT -Uri "http://169.254.169.254/latest/api/token" `
    -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "300"}
$instanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" `
    -Headers @{"X-aws-ec2-metadata-token" = $token}

# Leer mapping
$mappingParam = "/intelisrcpa/hostname-mapping/$instanceId"
$mappingValue = ""
try { $mappingValue = (Get-SSMParameter -Name $mappingParam -Region $Region).Value } catch {
    Write-Warning "No se encontro mapping para $instanceId"
}

# Obtener credenciales
$secretValue = Get-SECSecretValue -SecretId $SecretId -Region $Region
$creds = $secretValue.SecretString | ConvertFrom-Json
$securePassword = ConvertTo-SecureString $creds.password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($creds.username, $securePassword)

# Remover del dominio
try {
    Remove-Computer -UnjoinDomainCredential $credential -Force -PassThru
    Write-Output "Removido del dominio."
} catch {
    Write-Warning "Remove-Computer fallo: $($_.Exception.Message)"
}

# Eliminar objeto de AD
$computerName = $env:COMPUTERNAME
try {
    $searcher = New-Object DirectoryServices.DirectorySearcher
    $searcher.Filter = "(&(objectClass=computer)(cn=$computerName))"
    $result = $searcher.FindOne()
    if ($result) {
        $computerEntry = $result.GetDirectoryEntry()
        $computerEntry.DeleteTree()
        Write-Output "Objeto AD '$computerName' eliminado."
    }
} catch {
    Write-Warning "No se pudo eliminar objeto AD: $($_.Exception.Message)"
}

# Reciclar numero al pool
if ($mappingValue -and $mappingValue.Contains("|")) {
    $parts = $mappingValue.Split("|")
    $prefix = $parts[0]
    $number = $parts[1]

    $poolParam = "/intelisrcpa/hostname-pool/$prefix"
    $currentPool = ""
    try { $currentPool = (Get-SSMParameter -Name $poolParam -Region $Region).Value } catch {}

    $newPool = if ($currentPool -and $currentPool.Trim() -ne "") { "$currentPool,$number" } else { "$number" }
    Write-SSMParameter -Name $poolParam -Value $newPool -Type String -Overwrite $true -Region $Region
    Write-Output "Numero $number reciclado al pool de $prefix."

    Remove-SSMParameter -Name $mappingParam -Region $Region -Force
    Write-Output "Mapping de $instanceId eliminado."
}

Write-Output "Leave-Domain completado."
'@

Set-Content -Path "$domainScriptsPath\Leave-Domain.ps1" -Value $leaveScript -Force

# DNS Client
Set-Service -Name Dnscache -StartupType Automatic

Write-Output ""
Write-Output "OK: Scripts de dominio creados:"
Write-Output "  - $domainScriptsPath\Join-Domain.ps1"
Write-Output "  - $domainScriptsPath\Leave-Domain.ps1"
Write-Output "  - DNS Client: Automatic"
Write-Output ""
