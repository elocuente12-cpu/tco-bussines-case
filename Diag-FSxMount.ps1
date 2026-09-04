<#
.SYNOPSIS
    Diagnostico del fallo de montaje FSx en PROD:
    "A specified logon session does not exist. It may already have been terminated."

.DESCRIPTION
    Ejecutar en la instancia de PROD que falla, por RDP o SSM Session Manager,
    ANTES de que corra la Fase 2 del bootstrap (o despues del fallo, da igual).

    Recupera las credenciales de svc-ec2 desde Secrets Manager (mismo formato
    de keys que el bootstrap) y ejecuta una bateria de pruebas para aislar la
    causa: persistencia de credencial, SMB cifrado (privacy), canal seguro con
    el DC, y estado Kerberos de la maquina recien unida.

    NO modifica nada permanente: los mapeos de prueba se crean con -Persistent
    $false y se eliminan al final. El unico efecto es limpiar mapeos/credenciales
    huerfanos (que es justamente lo que queremos validar).

.PARAMETER SecretId
    ARN o nombre del secret en Secrets Manager con las credenciales de svc-ec2.
    Ej: arn:aws:secretsmanager:us-east-1:274193347839:secret:eec-aws-us-eits-intelisrcpa-prd-ec2ad-credentials-Zac1YP

.PARAMETER FsxDns
    DNS del FSx en prod. Default: amznfsxsokjtgsj.gdc.local

.PARAMETER Share
    Nombre del share. Default: share

.PARAMETER Drive
    Letra de unidad de prueba. Default: Z

.PARAMETER DomainFqdn
    FQDN del dominio (para nltest y para armar el user si el secret no trae dominio).
    Default: gdc.local

.EXAMPLE
    .\Diag-FSxMount.ps1 -SecretId "arn:aws:secretsmanager:us-east-1:274193347839:secret:eec-aws-us-eits-intelisrcpa-prd-ec2ad-credentials-Zac1YP"
#>

param(
    [Parameter(Mandatory)]
    [string]$SecretId,

    [string]$Region = "us-east-1",

    [string]$FsxDns = "amznfsxsokjtgsj.gdc.local",

    [string]$Share = "share",

    [string]$Drive = "Z",

    [string]$DomainFqdn = "gdc.local"
)

$ErrorActionPreference = "Continue"   # queremos ver TODOS los fallos, no abortar al primero
$remote = "\\$FsxDns\$Share"

function Section($t) {
    Write-Output ""
    Write-Output "==================================================================="
    Write-Output " $t"
    Write-Output "==================================================================="
}

function Show($label, $value) { Write-Output ("  {0,-28}: {1}" -f $label, $value) }

Section "0. Contexto de ejecucion"
Show "Usuario actual"    (whoami)
Show "Hostname"          $env:COMPUTERNAME
Show "Fecha/hora local"  (Get-Date -Format o)
Show "Timezone"          (Get-TimeZone).Id
Show "FSx remote"        $remote
Show "PartOfDomain"      ((Get-CimInstance Win32_ComputerSystem).PartOfDomain)
Show "Dominio"           ((Get-CimInstance Win32_ComputerSystem).Domain)

# ------------------------------------------------------------------
# Recuperar credenciales desde Secrets Manager (doble formato de keys)
# ------------------------------------------------------------------
Section "1. Recuperando credenciales desde Secrets Manager"
$cred = $null
try {
    $secretString = $null

    if (Get-Command Get-SECSecretValue -ErrorAction SilentlyContinue) {
        $secretString = (Get-SECSecretValue -SecretId $SecretId -Region $Region).SecretString
        Write-Output "  Secret leido via AWS.Tools (Get-SECSecretValue)."
    } else {
        $awsExe = (Get-Command aws -ErrorAction SilentlyContinue).Source
        if (-not $awsExe) { $awsExe = "C:\Program Files\Amazon\AWSCLIV2\aws.exe" }
        if (Test-Path $awsExe) {
            $secretString = & $awsExe secretsmanager get-secret-value --secret-id $SecretId --region $Region --query SecretString --output text
            Write-Output "  Secret leido via AWS CLI."
        } else {
            throw "No hay AWS.Tools ni AWS CLI disponibles."
        }
    }

    $secret = $secretString | ConvertFrom-Json
    $user = if ($secret.username) { $secret.username } else { $secret.SELF_MANAGED_ACTIVE_DIRECTORY_USERNAME }
    $pass = if ($secret.password) { $secret.password } else { $secret.SELF_MANAGED_ACTIVE_DIRECTORY_PASSWORD }
    if (-not $user -or -not $pass) { throw "El secret no tiene username/password poblados." }
    if ($user -notlike "*\*") { $user = "$DomainFqdn\$user" }

    $secPass = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential($user, $secPass)
    Show "Usuario del secret" $user
    Write-Output "  Credencial construida OK."
} catch {
    Write-Output "  [ERROR] No se pudo recuperar/construir la credencial: $($_.Exception.Message)"
    Write-Output "  Sin credencial no se pueden correr los pasos 4-6. Abortando."
    return
}

# ------------------------------------------------------------------
# Estado ANTES de tocar nada
# ------------------------------------------------------------------
Section "2. Estado actual de mapeos y credenciales (ANTES)"
Write-Output "--- Get-SmbGlobalMapping ---"
Get-SmbGlobalMapping -ErrorAction SilentlyContinue | Format-Table LocalPath, RemotePath, Status, Persistent -AutoSize | Out-String | Write-Output

Write-Output "--- SmbMappings persistentes en registro (HKLM) ---"
$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\SmbMappingsGlobal",
    "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters"
)
foreach ($rp in $regPaths) {
    if (Test-Path $rp) {
        Write-Output "  [$rp]"
        Get-Item $rp | Select-Object -ExpandProperty Property -ErrorAction SilentlyContinue | ForEach-Object { Write-Output "    $_" }
    }
}

Write-Output "--- cmdkey /list (credenciales guardadas) ---"
cmdkey /list | Out-String | Write-Output

Write-Output "--- net use ---"
net use | Out-String | Write-Output

# ------------------------------------------------------------------
# Estado del canal seguro / Kerberos (nucleo de la hipotesis reuso)
# ------------------------------------------------------------------
Section "3. Canal seguro con el DC y estado Kerberos (hipotesis reuso de objeto)"
Write-Output "--- nltest /sc_verify (valida machine password contra el DC) ---"
nltest /sc_verify:$DomainFqdn 2>&1 | Out-String | Write-Output

Write-Output "--- nltest /sc_query (que DC esta atendiendo) ---"
nltest /sc_query:$DomainFqdn 2>&1 | Out-String | Write-Output

Write-Output "--- Test-ComputerSecureChannel (True = machine key consistente) ---"
try { Show "SecureChannel OK" (Test-ComputerSecureChannel -Server $DomainFqdn -ErrorAction Stop) }
catch { Write-Output "  [ERROR] Test-ComputerSecureChannel: $($_.Exception.Message)" }

Write-Output "--- klist -li 0x3e7 (tickets Kerberos de LocalSystem) ---"
klist -li 0x3e7 2>&1 | Out-String | Write-Output

Write-Output "--- Resolucion DNS del FSx ---"
Resolve-DnsName $FsxDns -ErrorAction SilentlyContinue | Format-Table Name, Type, IPAddress -AutoSize | Out-String | Write-Output

Write-Output "--- Conectividad SMB (445) al FSx ---"
Test-NetConnection -ComputerName $FsxDns -Port 445 -WarningAction SilentlyContinue |
    Select-Object ComputerName, RemotePort, TcpTestSucceeded | Format-List | Out-String | Write-Output

# ------------------------------------------------------------------
# Limpieza de mapeos/credenciales huerfanos ANTES de probar
# ------------------------------------------------------------------
Section "4. Limpieza de mapeos/credenciales residuales"
try {
    Get-SmbGlobalMapping -ErrorAction SilentlyContinue |
        Where-Object { $_.LocalPath -eq "$Drive`:" -or $_.RemotePath -eq $remote } |
        Remove-SmbGlobalMapping -Force -ErrorAction SilentlyContinue
    Write-Output "  Remove-SmbGlobalMapping ejecutado sobre $Drive`: / $remote."
} catch { Write-Output "  Aviso Remove-SmbGlobalMapping: $($_.Exception.Message)" }

cmd /c "net use * /delete /y" 2>&1 | Out-String | Write-Output
Write-Output "  Credenciales guardadas del FSx purgadas (si existian)."

# ------------------------------------------------------------------
# PRUEBA A: mount SIN cifrado y SIN persistencia (aisla privacy/persistencia)
# ------------------------------------------------------------------
Section "5. PRUEBA A: New-SmbGlobalMapping SIN privacy, SIN persistencia"
try {
    New-SmbGlobalMapping -LocalPath "$Drive`:" -RemotePath $remote -Credential $cred -Persistent $false -ErrorAction Stop
    Write-Output "  [OK] Mount SIN privacy funciono."
    Show "Test-Path $Drive`:\" (Test-Path "$Drive`:\")
    Get-ChildItem "$Drive`:\" -ErrorAction SilentlyContinue | Select-Object -First 3 Name | Out-String | Write-Output
    Remove-SmbGlobalMapping -RemotePath $remote -Force -ErrorAction SilentlyContinue
    Write-Output "  (mapeo de prueba A eliminado)"
} catch {
    Write-Output "  [FALLO] Mount SIN privacy: $($_.Exception.Message)"
}

# ------------------------------------------------------------------
# PRUEBA B: mount CON cifrado (privacy) SIN persistencia (replica prod sin -Persistent)
# ------------------------------------------------------------------
Section "6. PRUEBA B: New-SmbGlobalMapping CON privacy (-RequirePrivacy), SIN persistencia"
try {
    New-SmbGlobalMapping -LocalPath "$Drive`:" -RemotePath $remote -Credential $cred -Persistent $false -RequirePrivacy $true -ErrorAction Stop
    Write-Output "  [OK] Mount CON privacy funciono (sin persistencia)."
    Show "Test-Path $Drive`:\" (Test-Path "$Drive`:\")
    Remove-SmbGlobalMapping -RemotePath $remote -Force -ErrorAction SilentlyContinue
    Write-Output "  (mapeo de prueba B eliminado)"
} catch {
    Write-Output "  [FALLO] Mount CON privacy: $($_.Exception.Message)"
}

# ------------------------------------------------------------------
# PRUEBA C: net use (pila de autenticacion distinta a New-SmbGlobalMapping)
# ------------------------------------------------------------------
Section "7. PRUEBA C: net use con credencial explicita"
$netUser = $cred.UserName
$netPass = $cred.GetNetworkCredential().Password
$netCmd = "net use $Drive`: $remote /user:$netUser $netPass"
# no imprimimos el password
Write-Output "  Ejecutando: net use $Drive`: $remote /user:$netUser ******"
cmd /c $netCmd 2>&1 | Out-String | Write-Output
Show "Test-Path $Drive`:\" (Test-Path "$Drive`:\")
cmd /c "net use $Drive`: /delete /y" 2>&1 | Out-String | Write-Output

# ------------------------------------------------------------------
# PRUEBA D: replica EXACTA del comando de prod (privacy + persistencia)
# ------------------------------------------------------------------
Section "8. PRUEBA D: replica EXACTA de prod (-Persistent + -RequirePrivacy)"
try {
    New-SmbGlobalMapping -LocalPath "$Drive`:" -RemotePath $remote -Credential $cred -Persistent $true -RequirePrivacy $true -ErrorAction Stop
    Write-Output "  [OK] Mount EXACTO de prod funciono tras la limpieza."
    Show "Test-Path $Drive`:\" (Test-Path "$Drive`:\")
    Remove-SmbGlobalMapping -RemotePath $remote -Force -ErrorAction SilentlyContinue
    Write-Output "  (mapeo de prueba D eliminado)"
} catch {
    Write-Output "  [FALLO] Mount EXACTO de prod: $($_.Exception.Message)"
}

Section "9. Resumen / interpretacion"
Write-Output @"
  Interpreta asi los resultados:

  - Si PRUEBA A/B/C/D FUNCIONAN tras la limpieza del paso 4
      => la causa es un mapeo/credencial HUERFANO residual. Fix: limpiar antes de montar.

  - Si A funciona pero B/D (con -RequirePrivacy) FALLAN
      => el problema es SMB cifrado / Kerberos en el contexto recien unido.
         Refuerza la hipotesis de reuso de objeto / clave de maquina.

  - Si nltest /sc_verify o Test-ComputerSecureChannel FALLAN
      => canal seguro roto: machine password desincronizada entre DCs.
         Confirma la hipotesis de reuso intensivo de los 2 objetos.

  - Si TODO falla (incluido net use)
      => FSx/AD cachea la identidad previa del nombre reusado, o hay
         bloqueo a nivel de GPO/SG especifico de prod.
"@

Section "FIN del diagnostico"
Write-Output "  Copia TODO este output y compartelo para analizar."
