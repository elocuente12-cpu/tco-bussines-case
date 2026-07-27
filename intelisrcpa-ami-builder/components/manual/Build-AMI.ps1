<#
.SYNOPSIS
    Orquestador: Construye una Application AMI desde la Golden AMI.
.DESCRIPTION
    Ejecutar este script DENTRO de una instancia EC2 lanzada desde la Golden AMI.
    Ejecuta todos los pasos de configuracion en orden y al final crea la AMI.

    Pre-requisitos:
    - Instancia lanzada desde la Golden AMI EEC (Windows 2022/2025)
    - AWS CLI instalado y configurado (via Instance Profile o credenciales)
    - PowerShell con permisos de administrador
    - Conectividad a internet (para Windows Features)

    Uso:
      .\Build-AMI.ps1 -AmiName "eec-aws-us-eits-intelisrcpa-dev-windows-iis" -AppVersion "1.0.0"

    Pasos que ejecuta:
      1. Instala IIS + .NET Features
      2. Configura scripts de FSx mount
      3. Crea scripts de domain join/leave
      4. Valida que todo esta correcto
      5. Ejecuta Sysprep (generaliza la instancia)
      6. Crea la AMI via AWS CLI

.PARAMETER AmiName
    Nombre para la AMI resultante.
.PARAMETER AppVersion
    Version de la aplicacion (se agrega como tag).
.PARAMETER SkipSysprep
    Si se especifica, no ejecuta Sysprep (util para debug).
.PARAMETER SkipAmiCreation
    Si se especifica, no crea la AMI (util para validar los scripts).
#>

param(
    [Parameter(Mandatory)]
    [string]$AmiName,

    [string]$AppVersion = "1.0.0",

    [string]$Environment = "dev",

    [switch]$SkipSysprep,

    [switch]$SkipAmiCreation
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Write-Output ""
Write-Output "╔══════════════════════════════════════════════════╗"
Write-Output "║  InteliSrcPA - AMI Builder (Manual)             ║"
Write-Output "║  AMI Name: $AmiName"
Write-Output "║  Version:  $AppVersion"
Write-Output "╚══════════════════════════════════════════════════╝"
Write-Output ""

# ─── Paso 1: Instalar IIS ──────────────────────────────────────
Write-Output ">>> Ejecutando Paso 1: Instalar IIS..."
& "$scriptDir\01-install-iis.ps1"
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    Write-Error "FALLO en Paso 1. Abortando."
    exit 1
}

# ─── Paso 2: Configurar FSx ────────────────────────────────────
Write-Output ">>> Ejecutando Paso 2: Configurar FSx mount..."
& "$scriptDir\02-configure-fsx-mount.ps1"
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    Write-Error "FALLO en Paso 2. Abortando."
    exit 1
}

# ─── Paso 3: Domain Join Prep ──────────────────────────────────
Write-Output ">>> Ejecutando Paso 3: Preparar domain join..."
& "$scriptDir\03-domain-join-prep.ps1"
if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    Write-Error "FALLO en Paso 3. Abortando."
    exit 1
}

# ─── Paso 4: Validacion ────────────────────────────────────────
Write-Output ""
Write-Output "========================================="
Write-Output " VALIDACION"
Write-Output "========================================="

$requiredFiles = @(
    "C:\Scripts\Domain\Join-Domain.ps1",
    "C:\Scripts\Domain\Leave-Domain.ps1",
    "C:\Scripts\Startup\Mount-FsxShare.ps1"
)

$allPassed = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Output "  [OK] $file"
    } else {
        Write-Error "  [FALLO] $file NO EXISTE"
        $allPassed = $false
    }
}

$iis = Get-WindowsFeature -Name Web-Server
if ($iis.InstallState -eq 'Installed') {
    Write-Output "  [OK] IIS Web-Server instalado"
} else {
    Write-Error "  [FALLO] IIS no instalado"
    $allPassed = $false
}

$w3svc = Get-Service -Name W3SVC -ErrorAction SilentlyContinue
if ($w3svc) {
    Write-Output "  [OK] W3SVC service presente"
} else {
    Write-Error "  [FALLO] W3SVC service no encontrado"
    $allPassed = $false
}

if (-not $allPassed) {
    Write-Error "Validacion fallida. Corregir errores antes de crear AMI."
    exit 1
}

Write-Output ""
Write-Output "VALIDACION EXITOSA: Todo listo para crear AMI."
Write-Output ""

# ─── Paso 5: Sysprep (opcional) ────────────────────────────────
if (-not $SkipSysprep) {
    Write-Output "========================================="
    Write-Output " SYSPREP"
    Write-Output "========================================="
    Write-Output "Ejecutando EC2Launch Sysprep para generalizar la instancia..."
    Write-Output "NOTA: La instancia se apagara despues de Sysprep."
    Write-Output ""

    # EC2Launch v2 (Windows 2022/2025)
    $ec2LaunchPath = "C:\ProgramData\Amazon\EC2Launch\EC2Launch.exe"
    if (Test-Path $ec2LaunchPath) {
        & $ec2LaunchPath sysprep --shutdown
    } else {
        # EC2Launch v1 fallback (Windows 2019)
        $ec2ConfigPath = "C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\InitializeInstance.ps1"
        if (Test-Path $ec2ConfigPath) {
            & "C:\ProgramData\Amazon\EC2-Windows\Launch\Scripts\SysprepInstance.ps1"
        } else {
            Write-Error "No se encontro EC2Launch ni EC2Config. Ejecutar Sysprep manualmente."
            exit 1
        }
    }

    Write-Output "Sysprep iniciado. La instancia se apagara."
    Write-Output "Espera a que la instancia este en estado 'stopped' antes de crear la AMI."
    exit 0
}

# ─── Paso 6: Crear AMI (si no se hizo Sysprep) ─────────────────
if (-not $SkipAmiCreation) {
    Write-Output "========================================="
    Write-Output " CREAR AMI"
    Write-Output "========================================="

    # Obtener instance-id
    $token = Invoke-RestMethod -Method PUT -Uri "http://169.254.169.254/latest/api/token" `
        -Headers @{"X-aws-ec2-metadata-token-ttl-seconds" = "300"}
    $instanceId = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/instance-id" `
        -Headers @{"X-aws-ec2-metadata-token" = $token}
    $region = Invoke-RestMethod -Uri "http://169.254.169.254/latest/meta-data/placement/region" `
        -Headers @{"X-aws-ec2-metadata-token" = $token}

    $date = Get-Date -Format "yyyyMMdd"
    $fullAmiName = "$AmiName-$date-v$AppVersion"

    Write-Output "Instance ID: $instanceId"
    Write-Output "Region:      $region"
    Write-Output "AMI Name:    $fullAmiName"
    Write-Output ""

    # Crear AMI (--no-reboot para no reiniciar, asegura consistencia)
    Write-Output "Creando AMI (esto puede tardar varios minutos)..."
    $amiOutput = aws ec2 create-image `
        --instance-id $instanceId `
        --name $fullAmiName `
        --description "InteliSrcPA Application AMI - $Environment - v$AppVersion" `
        --no-reboot `
        --output json | ConvertFrom-Json

    $amiId = $amiOutput.ImageId
    Write-Output ""
    Write-Output "AMI creada: $amiId"
    Write-Output ""

    # Tagear la AMI
    Write-Output "Aplicando tags..."
    aws ec2 create-tags --resources $amiId --tags `
        "Key=Name,Value=$fullAmiName" `
        "Key=AppID,Value=22272" `
        "Key=CostString,Value=1850.PA.135.601000" `
        "Key=Application,Value=InteliSrcPA" `
        "Key=Environment,Value=$Environment" `
        "Key=Version,Value=$AppVersion" `
        "Key=ManagedBy,Value=Manual" `
        "Key=BuildDate,Value=$date" `
        --region $region

    Write-Output ""
    Write-Output "╔══════════════════════════════════════════════════╗"
    Write-Output "║  AMI CREADA EXITOSAMENTE                        ║"
    Write-Output "║                                                  ║"
    Write-Output "║  AMI ID:   $amiId"
    Write-Output "║  Nombre:   $fullAmiName"
    Write-Output "║  Region:   $region"
    Write-Output "║                                                  ║"
    Write-Output "║  Espera a que el estado sea 'available' con:     ║"
    Write-Output "║  aws ec2 describe-images --image-ids $amiId"
    Write-Output "║                                                  ║"
    Write-Output "╚══════════════════════════════════════════════════╝"
} else {
    Write-Output ""
    Write-Output "AMI creation skipped (--SkipAmiCreation). Scripts instalados correctamente."
    Write-Output "Para crear la AMI manualmente:"
    Write-Output ""
    Write-Output "  1. Ejecutar Sysprep:"
    Write-Output "     C:\ProgramData\Amazon\EC2Launch\EC2Launch.exe sysprep --shutdown"
    Write-Output ""
    Write-Output "  2. Esperar a que la instancia este en estado 'stopped'"
    Write-Output ""
    Write-Output "  3. Crear AMI desde AWS CLI (en tu maquina local):"
    Write-Output "     aws ec2 create-image --instance-id <INSTANCE_ID> --name `"$AmiName-$(Get-Date -Format yyyyMMdd)-v$AppVersion`" --no-reboot"
    Write-Output ""
}
