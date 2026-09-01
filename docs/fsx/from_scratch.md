# Paso a paso: Configurar un nuevo Replication Group hacia FSx existente

**Escenario:** Ya existe un FSx en AWS con DFS-R funcionando (RG `APXEXPERIAN`). Ahora se necesita crear un **nuevo Replication Group** para replicar otro directorio desde on-premise hacia el **mismo FSx**.

**FSx existente con:** `file_system_administrators_group = "ADMIN GDC DFS Management"`  
**Cuenta operativa:** miembro de `ADMIN GDC DFS Management`  
**Ejecutar todo desde:** el servidor on-prem que será miembro del nuevo RG

---

## Pre-requisitos

- [ ] FSx existente accesible (DNS resolviendo, DFS-R ya funciona con el RG anterior)
- [ ] Cuenta operativa es miembro de `ADMIN GDC DFS Management`
- [ ] RSAT DFS instalado en el servidor on-prem
- [ ] Identificar el servidor on-prem que tiene el contenido a replicar
- [ ] Identificar la IP NAT de salida del servidor on-prem (ya permitida en SG del FSx en AWS)
- [ ] Validar reglas de firewall on-premise (entrada y salida)

---

## Variables (completar antes de empezar)

```powershell
# ===== COMPLETAR ESTOS VALORES =====
$rgNuevo     = "NOMBRE_NUEVO_RG"                     # Nombre del nuevo Replication Group
$rfNuevo     = "NOMBRE_REPLICATED_FOLDER"            # Nombre del Replicated Folder
$fsx         = "amznfsxXXXXXXXX.gdc.local"          # DNS name del FSx existente
$fsxHost     = "AMZNFSXXXXXXXYZ"                     # Hostname corto del FSx (sin .gdc.local)
$fsxDn       = "CN=$fsxHost,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local"
$onprem      = "SERVIDOR-ONPREM.gdc.local"           # FQDN del servidor on-prem origen
$onpremIP    = "10.x.x.x"                           # IP real del servidor on-prem
$natIP       = "x.x.x.x"                            # IP NAT de salida del on-prem (ya en SG AWS)
$fsxIP       = "10.64.160.x"                        # IP privada del FSx en AWS

# Rutas
$contentPathOnPrem = "D:\share\CARPETA_ORIGEN"       # Ruta del contenido en on-prem
$contentPathFSx    = "D:\share\CARPETA_DESTINO"      # Ruta destino en el FSx

# Cuotas
$stagingMB   = 4096
$conflictMB  = 660

# Cuenta operativa
$cuenta      = "GDC\C91582B-A"
# ====================================
```

---

## Fase 1: Validación de Firewall y Conectividad

### Paso 1.1: Puertos requeridos por DFS-R

| Puerto | Protocolo | Dirección | Uso |
|--------|-----------|-----------|-----|
| 135 | TCP | Bidireccional | RPC Endpoint Mapper |
| 5722 | TCP | Bidireccional | DFS-R (WMI-DFSR) |
| 49152-65535 | TCP | Bidireccional | RPC dinámicos |
| 445 | TCP | Bidireccional | SMB (opcional, para admin shares) |

### Paso 1.2: Verificar conectividad DESDE on-prem HACIA FSx

```powershell
# Ejecutar desde el servidor on-prem
Write-Host "=== Test conectividad On-Prem -> FSx ===" -ForegroundColor Cyan

# RPC Endpoint Mapper
Test-NetConnection -ComputerName $fsx -Port 135
# DFS-R
Test-NetConnection -ComputerName $fsx -Port 5722
# SMB
Test-NetConnection -ComputerName $fsx -Port 445
# RPC dinámico (un puerto de prueba)
Test-NetConnection -ComputerName $fsx -Port 49152
```

**Resultado esperado:** `TcpTestSucceeded: True` en todos.

**Si falla:**
- Puerto 135/5722/445: Revisar SG del FSx en AWS (debería tener la IP NAT del on-prem permitida)
- Puertos 49152+: Puede haber bloqueo en firewall on-premise de salida

### Paso 1.3: Verificar conectividad DESDE FSx HACIA on-prem

> **Nota:** FSx no permite ejecutar comandos directamente. La validación se hace observando logs después de configurar DFS-R. Sin embargo, el firewall on-premise debe permitir tráfico **entrante** desde la IP del FSx.

**Reglas requeridas en firewall on-premise (ENTRADA):**

| Origen | Destino | Puerto | Protocolo | Acción |
|--------|---------|--------|-----------|--------|
| IP del FSx (`$fsxIP`) | IP del servidor on-prem (`$onpremIP`) | 135 | TCP | Allow |
| IP del FSx (`$fsxIP`) | IP del servidor on-prem (`$onpremIP`) | 5722 | TCP | Allow |
| IP del FSx (`$fsxIP`) | IP del servidor on-prem (`$onpremIP`) | 49152-65535 | TCP | Allow |

**Reglas requeridas en firewall on-premise (SALIDA):**

| Origen | Destino | Puerto | Protocolo | Acción |
|--------|---------|--------|-----------|--------|
| IP del servidor on-prem (`$onpremIP`) | IP del FSx (`$fsxIP`) | 135 | TCP | Allow |
| IP del servidor on-prem (`$onpremIP`) | IP del FSx (`$fsxIP`) | 5722 | TCP | Allow |
| IP del servidor on-prem (`$onpremIP`) | IP del FSx (`$fsxIP`) | 49152-65535 | TCP | Allow |
| IP del servidor on-prem (`$onpremIP`) | IP del FSx (`$fsxIP`) | 445 | TCP | Allow |

### Paso 1.4: Verificar reglas de Windows Firewall en el servidor on-prem

```powershell
# Ver reglas DFS-R existentes
Get-NetFirewallRule -DisplayGroup "DFS Replication" | Format-Table Name, Enabled, Direction, Action -AutoSize

# Si no existen, habilitarlas
Enable-NetFirewallRule -DisplayGroup "DFS Replication"

# Verificar que los puertos están abiertos localmente
Get-NetFirewallRule -Direction Inbound -Enabled True |
  Get-NetFirewallPortFilter |
  Where-Object { $_.LocalPort -in 135,5722,445 } |
  Format-Table Protocol, LocalPort -AutoSize
```

**Si las reglas no existen, crearlas:**

```powershell
# RPC Endpoint Mapper (entrada desde FSx)
New-NetFirewallRule -DisplayName "DFS-R RPC (desde FSx)" -Direction Inbound -Protocol TCP -LocalPort 135 -RemoteAddress $fsxIP -Action Allow

# DFS-R WMI (entrada desde FSx)
New-NetFirewallRule -DisplayName "DFS-R WMI-DFSR (desde FSx)" -Direction Inbound -Protocol TCP -LocalPort 5722 -RemoteAddress $fsxIP -Action Allow

# RPC dinamicos (entrada desde FSx)
New-NetFirewallRule -DisplayName "DFS-R RPC Dinamico (desde FSx)" -Direction Inbound -Protocol TCP -LocalPort 49152-65535 -RemoteAddress $fsxIP -Action Allow
```

### Paso 1.5: Verificar resolución DNS bidireccional

```powershell
# Desde on-prem: resolver FSx
Resolve-DnsName $fsx
# Debe retornar la IP privada del FSx

# Verificar que el FSx puede resolver el on-prem (via DNS del dominio)
Resolve-DnsName $onprem
# Debe retornar la IP del servidor on-prem
```

**Si falla:** Verificar que ambos servidores usan los DNS del dominio `gdc.local`.

---

## Fase 2: Preparar el FSx para el nuevo RG

### Paso 2.1: Crear la carpeta destino en el FSx

```powershell
New-Item -Type Directory -Path "\\$fsx\D`$\share\$rfNuevo" -Force
Get-ChildItem "\\$fsx\D`$\share\"
```

**Resultado esperado:** carpeta creada bajo `D:\share\`

Si da *Access denied*: la cuenta no es miembro del grupo `ADMIN GDC DFS Management`.

### Paso 2.2: Verificar que el FSx no está ya en un RG con ese nombre

```powershell
Get-DfsrMember -GroupName $rgNuevo -ErrorAction SilentlyContinue
```

**Resultado esperado:** error o vacío (el RG no existe aún).

---

## Fase 3: Crear el nuevo Replication Group

### Paso 3.1: Crear el Replication Group

```powershell
New-DfsReplicationGroup -GroupName $rgNuevo -Description "DFS-R entre on-prem y FSx AWS - $rfNuevo" -DomainName "gdc.local"
```

**Verificar:**

```powershell
Get-DfsReplicationGroup -GroupName $rgNuevo | Format-List *
```

### Paso 3.2: Crear el Replicated Folder

```powershell
New-DfsReplicatedFolder -GroupName $rgNuevo -FolderName $rfNuevo -DomainName "gdc.local"
```

**Verificar:**

```powershell
Get-DfsReplicatedFolder -GroupName $rgNuevo | Format-Table FolderName, State -AutoSize
```

### Paso 3.3: Agregar el servidor on-prem como miembro

```powershell
Add-DfsrMember -GroupName $rgNuevo -ComputerName $onprem -Description "Servidor on-prem origen"
```

### Paso 3.4: Agregar el FSx como miembro

```powershell
Add-DfsrMember -GroupName $rgNuevo -ComputerName $fsx -Description "FSx AWS destino"
```

**Verificar ambos:**

```powershell
Get-DfsrMember -GroupName $rgNuevo | Format-Table ComputerName, DnsName, Description -AutoSize
```

**Resultado esperado:** 2 miembros listados.

---

## Fase 4: Configurar conexiones y membresías

### Paso 4.1: Delegar permisos sobre el nuevo RG

```powershell
Grant-DfsrDelegation -GroupName $rgNuevo -AccountName $cuenta -Force

# Verificar
Get-DfsrDelegation -GroupName $rgNuevo |
  Format-Table AccountName, IsInherited -AutoSize
```

### Paso 4.2: Permisos sobre el computer object del FSx (si no se hizo antes)

> Si ya se otorgaron permisos GenericAll en el paso del RG anterior, este paso puede omitirse. Verificar:

```powershell
$entry = [ADSI]"LDAP://$fsxDn"
$entry.ObjectSecurity.Access |
  Where-Object { $_.IdentityReference -like "*C91582B*" } |
  Format-Table IdentityReference, ActiveDirectoryRights -AutoSize
```

Si no aparece `GenericAll`, ejecutar:

```powershell
$entry = [ADSI]"LDAP://$fsxDn"
$sid   = (New-Object System.Security.Principal.NTAccount($cuenta)).Translate(
           [System.Security.Principal.SecurityIdentifier])
$acl   = $entry.ObjectSecurity
$rule  = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
           $sid,
           [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
           [System.Security.AccessControl.AccessControlType]::Allow,
           [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All)
$acl.AddAccessRule($rule)
$entry.CommitChanges()
Write-Host "Full Control otorgado sobre $fsxDn" -ForegroundColor Green
```

### Paso 4.3: Crear conexión bidireccional

```powershell
Add-DfsrConnection -GroupName $rgNuevo -SourceComputerName $onprem -DestinationComputerName $fsx
```

**Verificar:**

```powershell
Get-DfsrConnection -GroupName $rgNuevo |
  Format-Table SourceComputerName, DestinationComputerName, Enabled -AutoSize
```

**Resultado esperado:** 2 conexiones bidireccionales, ambas `Enabled = True`

### Paso 4.4: Configurar membresía del servidor on-prem (PRIMARY)

```powershell
Set-DfsrMembership -GroupName $rgNuevo -FolderName $rfNuevo -ComputerName $onprem `
  -ContentPath $contentPathOnPrem `
  -StagingPathQuotaInMB $stagingMB `
  -ConflictAndDeletedQuotaInMB $conflictMB `
  -PrimaryMember $true `
  -Force
```

### Paso 4.5: Configurar membresía del FSx (SECONDARY)

```powershell
Set-DfsrMembership -GroupName $rgNuevo -FolderName $rfNuevo -ComputerName $fsx `
  -ContentPath $contentPathFSx `
  -StagingPathQuotaInMB $stagingMB `
  -ConflictAndDeletedQuotaInMB $conflictMB `
  -PrimaryMember $false `
  -Force
```

**Si da error *"Access is denied"*:** usar `runas` con la cuenta del grupo `ADMIN GDC DFS Management`:

```powershell
runas /user:GDC\CUENTA_ADMIN_DFS powershell.exe
# En esa ventana: definir variables y ejecutar Set-DfsrMembership
```

**Verificar:**

```powershell
Get-DfsrMembership -GroupName $rgNuevo |
  Format-Table ComputerName, ContentPath, StagingPathQuotaInMB, Enabled, ReadOnly -AutoSize
```

---

## Fase 5: Debugging y monitoreo de replicación

### Paso 5.1: Forzar actualización de la configuración DFS-R

```powershell
# En el servidor on-prem
Update-DfsrConfigurationFromAD -ComputerName $onprem -Verbose

# Esperar 1-2 minutos y verificar
dfsrdiag.exe PollAD /Member:$onprem
```

### Paso 5.2: Verificar objetos en AD

```powershell
$entry = [ADSI]"LDAP://$fsxDn"
$searcher = New-Object System.DirectoryServices.DirectorySearcher($entry)
$searcher.Filter = "(objectClass=*)"
$searcher.SearchScope = "Subtree"
$results = $searcher.FindAll()
$results | ForEach-Object { $_.Path }
```

**Resultado esperado:** Debe aparecer el nuevo RG bajo `DFSR-LocalSettings`:
```
LDAP://CN=AMZNFSXXXXXXXYZ,...
LDAP://CN=DFSR-LocalSettings,CN=AMZNFSXXXXXXXYZ,...
LDAP://CN=APXEXPERIAN,CN=DFSR-LocalSettings,...         ← RG anterior
LDAP://CN=NOMBRE_NUEVO_RG,CN=DFSR-LocalSettings,...     ← RG NUEVO
```

### Paso 5.3: Monitorear eventos DFS-R en on-prem

```powershell
# Eventos recientes
Get-WinEvent -LogName "DFS Replication" -MaxEvents 50 |
  Where-Object { $_.Id -in 4102,4104,4114,5002,5004,5008,5012,5014 } |
  Format-Table TimeCreated, Id, Message -Wrap
```

| Evento | Significado |
|--------|-------------|
| 4102 | Replicación inicial iniciada ✅ |
| 4104 | Replicación inicial completada ✅ |
| 4114 | Servicio no pudo conectar al partner (firewall/DNS) ❌ |
| 5002 | Error al conectar con miembro (timeout) ❌ |
| 5004 | Conexión establecida ✅ |
| 5008 | Conexión perdida ❌ |
| 5012 | Backlog detectado (normal en sync inicial) ⚠️ |
| 5014 | Backlog resuelto ✅ |

### Paso 5.4: Diagnosticar si el problema es de firewall

Si aparece evento 4114 o 5002:

```powershell
# Verificar estado de las conexiones del RG
Get-DfsrConnectionSchedule -GroupName $rgNuevo -SourceComputerName $onprem -DestinationComputerName $fsx

# Intentar conexión RPC directa
dfsrdiag.exe MembersInPeer /RGName:$rgNuevo /MemName:$onprem /Partner:$fsx
```

**Si `dfsrdiag` falla con timeout:**

```powershell
# Test rápido de puertos
@(135, 5722, 445, 49152) | ForEach-Object {
    $result = Test-NetConnection -ComputerName $fsx -Port $_ -WarningAction SilentlyContinue
    [PSCustomObject]@{
        Port   = $_
        Status = if ($result.TcpTestSucceeded) { "✅ Open" } else { "❌ Blocked" }
    }
} | Format-Table -AutoSize
```

### Paso 5.5: Verificar estado del backlog

```powershell
# Backlog desde on-prem hacia FSx
dfsrdiag.exe Backlog /SendingMember:$onprem /ReceivingMember:$fsx /RGName:$rgNuevo /RFName:$rfNuevo

# Backlog desde FSx hacia on-prem
dfsrdiag.exe Backlog /SendingMember:$fsx /ReceivingMember:$onprem /RGName:$rgNuevo /RFName:$rfNuevo
```

**Resultado esperado:** 
- Backlog count > 0 durante sync inicial (normal)
- Backlog count = 0 cuando se completa la replicación

### Paso 5.6: Verificar salud de la replicación

```powershell
# Reporte de salud (genera HTML)
Write-DfsrHealthReport -GroupName $rgNuevo -ReferenceComputerName $onprem -Path "C:\temp" -MemberComputerName $fsx

# Abrir el reporte
Start-Process "C:\temp\*.html"
```

---

## Fase 6: Validar replicación exitosa

### Paso 6.1: Crear archivo de prueba en on-prem

```powershell
# Crear archivo de prueba
$testFile = "$contentPathOnPrem\TEST-REPLICACION-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
"Prueba de replicacion DFS-R - $(Get-Date)" | Out-File $testFile -Encoding UTF8
Write-Host "Archivo creado: $testFile" -ForegroundColor Green
```

### Paso 6.2: Verificar que aparezca en el FSx

```powershell
# Esperar 30-60 segundos y verificar
Start-Sleep -Seconds 60
Get-ChildItem "\\$fsx\D`$\share\$rfNuevo\TEST-REPLICACION*"
```

**Resultado esperado:** El archivo aparece en el FSx.

### Paso 6.3: Verificar tamaño total replicado

```powershell
# Contenido en on-prem
$onpremSize = Get-ChildItem $contentPathOnPrem -Recurse -File |
  Measure-Object -Property Length -Sum
Write-Host "On-prem: $($onpremSize.Count) archivos, $([math]::Round($onpremSize.Sum/1GB,2)) GB"

# Contenido en FSx
$fsxSize = Get-ChildItem "\\$fsx\D`$\share\$rfNuevo" -Recurse -File |
  Measure-Object -Property Length -Sum
Write-Host "FSx:     $($fsxSize.Count) archivos, $([math]::Round($fsxSize.Sum/1GB,2)) GB"

# Comparar
if ($fsxSize.Count -eq $onpremSize.Count) {
    Write-Host "✅ Replicacion completa!" -ForegroundColor Green
} else {
    Write-Host "⚠️  Replicacion en progreso ($($fsxSize.Count)/$($onpremSize.Count) archivos)" -ForegroundColor Yellow
}
```

---

## Rollback (si algo sale mal)

```powershell
# Remover miembros y eliminar el RG completo
Remove-DfsrMember -GroupName $rgNuevo -ComputerName $fsx -Force
Remove-DfsrMember -GroupName $rgNuevo -ComputerName $onprem -Force
Remove-DfsReplicatedFolder -GroupName $rgNuevo -FolderName $rfNuevo -Force
Remove-DfsReplicationGroup -GroupName $rgNuevo -Force

# Verificar
Get-DfsReplicationGroup -GroupName $rgNuevo -ErrorAction SilentlyContinue
```

---

## Checklist de firewall resumen

### En AWS (Security Group del FSx) — YA CONFIGURADO

| Origen (IP NAT on-prem) | Puerto | Protocolo | Estado |
|--------------------------|--------|-----------|--------|
| `$natIP` | 135 | TCP | ✅ Ya permitido |
| `$natIP` | 5722 | TCP | ✅ Ya permitido |
| `$natIP` | 445 | TCP | ✅ Ya permitido |
| `$natIP` | 49152-65535 | TCP | ✅ Ya permitido |

### En Firewall On-Premise — VALIDAR/CONFIGURAR

| Dirección | Origen | Destino | Puerto | Estado |
|-----------|--------|---------|--------|--------|
| SALIDA | `$onpremIP` | `$fsxIP` | 135, 5722, 445, 49152-65535 TCP | ⬜ Verificar |
| ENTRADA | `$fsxIP` | `$onpremIP` | 135, 5722, 49152-65535 TCP | ⬜ Verificar |

### En Windows Firewall del servidor on-prem — VALIDAR

| Dirección | Puerto | Estado |
|-----------|--------|--------|
| Inbound | 135, 5722, 49152-65535 TCP | ⬜ Verificar reglas DFS Replication |

---

## Troubleshooting rápido

| Síntoma | Causa probable | Acción |
|---------|---------------|--------|
| `Test-NetConnection` falla en puerto 135 | Firewall on-prem bloquea salida | Abrir salida TCP 135 hacia IP FSx |
| Evento 4114 en logs | Firewall bloquea entrada desde FSx | Abrir entrada desde IP FSx |
| Evento 5002 (timeout) | Puertos RPC dinámicos bloqueados | Abrir 49152-65535 bidireccional |
| `Set-DfsrMembership` Access denied | Cuenta sin permisos sobre FSx | Verificar membresía en `ADMIN GDC DFS Management` |
| Backlog no baja | Ancho de banda limitado o archivos grandes | Normal en sync inicial, esperar |
| `dfsrdiag Backlog` error RPC | RPC Endpoint Mapper bloqueado | Verificar puerto 135 + dinámicos |
