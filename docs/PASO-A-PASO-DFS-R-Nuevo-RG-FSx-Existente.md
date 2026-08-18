# Paso a paso: Agregar FSx existente a un segundo Replication Group

**Escenario:** Ya existe un FSx en AWS con DFS-R funcionando (RG `APXEXPERIAN`). Ahora se necesita agregar **ese mismo FSx** a un **segundo Replication Group ya existente** en on-premise, para replicar otro directorio.

**FSx existente con:** `file_system_administrators_group = "ADMIN GDC DFS Management"`  
**Cuenta operativa:** miembro de `ADMIN GDC DFS Management`  
**Ejecutar todo desde:** el servidor on-prem miembro del RG (donde corren los cmdlets DFS)

---

## Pre-requisitos

- [ ] FSx existente accesible (DNS resolviendo, DFS-R ya funciona con el RG anterior)
- [ ] El segundo Replication Group ya existe en on-premise con miembros activos
- [ ] Cuenta operativa es miembro de `ADMIN GDC DFS Management`
- [ ] RSAT DFS instalado en el servidor on-prem
- [ ] Identificar el servidor on-prem del RG que será partner del FSx
- [ ] IP NAT de salida del on-prem ya permitida en SG del FSx en AWS
- [ ] Validar reglas de firewall on-premise (entrada y salida)

---

## Variables (completar antes de empezar)

```powershell
# ===== COMPLETAR ESTOS VALORES =====
$rg          = "NOMBRE_RG_EXISTENTE"                 # Nombre del Replication Group existente
$rf          = "NOMBRE_REPLICATED_FOLDER"            # Nombre del Replicated Folder dentro del RG
$fsx         = "amznfsxXXXXXXXX.gdc.local"          # DNS name del FSx existente
$fsxHost     = "AMZNFSXXXXXXXYZ"                     # Hostname corto del FSx (sin .gdc.local)
$fsxDn       = "CN=$fsxHost,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local"
$onprem      = "SERVIDOR-ONPREM.gdc.local"           # FQDN del servidor on-prem partner
$onpremIP    = "10.x.x.x"                           # IP real del servidor on-prem
$natIP       = "x.x.x.x"                            # IP NAT de salida del on-prem (ya en SG AWS)
$fsxIP       = "10.64.160.x"                        # IP privada del FSx en AWS

# Rutas
$contentPath = "D:\share\CARPETA_DESTINO"            # Ruta destino en el FSx

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
| 445 | TCP | Bidireccional | SMB (admin shares) |

### Paso 1.2: Verificar conectividad DESDE on-prem HACIA FSx

```powershell
Write-Host "=== Test conectividad On-Prem -> FSx ===" -ForegroundColor Cyan

@(135, 5722, 445, 49152) | ForEach-Object {
    $result = Test-NetConnection -ComputerName $fsx -Port $_ -WarningAction SilentlyContinue
    [PSCustomObject]@{
        Port   = $_
        Status = if ($result.TcpTestSucceeded) { "OK" } else { "BLOCKED" }
    }
} | Format-Table -AutoSize
```

**Resultado esperado:** todos `OK`.

**Si falla:**
- Puerto 135/5722/445: Revisar SG del FSx en AWS (la IP NAT del on-prem debe estar permitida)
- Puertos 49152+: Firewall on-premise puede bloquear salida

### Paso 1.3: Reglas requeridas en firewall on-premise

> FSx no permite ejecutar comandos. La validación de retorno se hace observando logs DFS-R después de configurar. El firewall on-premise **debe permitir tráfico entrante** desde la IP del FSx.

**SALIDA (on-prem → FSx):**

| Origen | Destino | Puerto | Protocolo |
|--------|---------|--------|-----------|
| `$onpremIP` | `$fsxIP` | 135 | TCP |
| `$onpremIP` | `$fsxIP` | 5722 | TCP |
| `$onpremIP` | `$fsxIP` | 445 | TCP |
| `$onpremIP` | `$fsxIP` | 49152-65535 | TCP |

**ENTRADA (FSx → on-prem):**

| Origen | Destino | Puerto | Protocolo |
|--------|---------|--------|-----------|
| `$fsxIP` | `$onpremIP` | 135 | TCP |
| `$fsxIP` | `$onpremIP` | 5722 | TCP |
| `$fsxIP` | `$onpremIP` | 49152-65535 | TCP |

### Paso 1.4: Verificar Windows Firewall en el servidor on-prem

```powershell
# Ver reglas DFS-R existentes
Get-NetFirewallRule -DisplayGroup "DFS Replication" | Format-Table Name, Enabled, Direction, Action -AutoSize

# Si no existen o están deshabilitadas
Enable-NetFirewallRule -DisplayGroup "DFS Replication"
```

**Si las reglas no existen:**

```powershell
New-NetFirewallRule -DisplayName "DFS-R RPC (desde FSx)" -Direction Inbound -Protocol TCP -LocalPort 135 -RemoteAddress $fsxIP -Action Allow
New-NetFirewallRule -DisplayName "DFS-R WMI-DFSR (desde FSx)" -Direction Inbound -Protocol TCP -LocalPort 5722 -RemoteAddress $fsxIP -Action Allow
New-NetFirewallRule -DisplayName "DFS-R RPC Dinamico (desde FSx)" -Direction Inbound -Protocol TCP -LocalPort 49152-65535 -RemoteAddress $fsxIP -Action Allow
```

### Paso 1.5: Verificar resolución DNS bidireccional

```powershell
Resolve-DnsName $fsx
Resolve-DnsName $onprem
```

Ambos deben resolver a sus IPs correctas.

---

## Fase 2: Verificar estado actual del RG existente

### Paso 2.1: Listar miembros actuales

```powershell
Get-DfsrMember -GroupName $rg | Format-Table ComputerName, DnsName -AutoSize
```

**Verificar:** el FSx NO debe aparecer todavía.

### Paso 2.2: Listar membresías y carpetas replicadas

```powershell
Get-DfsrMembership -GroupName $rg | Format-Table ComputerName, ContentPath, StagingPathQuotaInMB -AutoSize
Get-DfsReplicatedFolder -GroupName $rg | Format-Table FolderName -AutoSize
```

**Anotar:** el `ContentPath` que usan los miembros existentes para saber la estructura esperada.

---

## Fase 3: Preparar el FSx

### Paso 3.1: Crear la carpeta destino en el FSx

```powershell
New-Item -Type Directory -Path "\\$fsx\D`$\share\$rf" -Force
Get-ChildItem "\\$fsx\D`$\share\"
```

**Resultado esperado:** carpeta creada.

Si da *Access denied*: la cuenta no es miembro de `ADMIN GDC DFS Management`.

---

## Fase 4: Agregar FSx al Replication Group

### Paso 4.1: Delegar permisos sobre el RG

```powershell
Grant-DfsrDelegation -GroupName $rg -AccountName $cuenta -Force

# Verificar
Get-DfsrDelegation -GroupName $rg |
  Where-Object AccountName -like "*C91582B*" |
  Format-Table AccountName, IsInherited -AutoSize
```

**Resultado esperado:** `IsInherited = False`

### Paso 4.2: Permisos sobre el computer object del FSx en AD

> Si ya se otorgaron en el RG anterior, verificar primero:

```powershell
$entry = [ADSI]"LDAP://$fsxDn"
$entry.ObjectSecurity.Access |
  Where-Object { $_.IdentityReference -like "*C91582B*" } |
  Format-Table IdentityReference, ActiveDirectoryRights -AutoSize
```

Si no aparece `GenericAll`:

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

### Paso 4.3: Agregar FSx como miembro del RG

```powershell
Add-DfsrMember -GroupName $rg -ComputerName $fsx -Description "FSx AWS - $rg"
```

**Verificar:**

```powershell
Get-DfsrMember -GroupName $rg | Format-Table ComputerName -AutoSize
```

### Paso 4.4: Crear conexión bidireccional con el partner on-prem

```powershell
Add-DfsrConnection -GroupName $rg -SourceComputerName $onprem -DestinationComputerName $fsx
```

**Verificar:**

```powershell
Get-DfsrConnection -GroupName $rg |
  Where-Object { $_.SourceComputerName -like "*$fsxHost*" -or $_.DestinationComputerName -like "*$fsxHost*" } |
  Format-Table SourceComputerName, DestinationComputerName, Enabled -AutoSize
```

**Resultado esperado:** 2 conexiones bidireccionales, `Enabled = True`

### Paso 4.5: Configurar membresía del FSx

```powershell
Set-DfsrMembership -GroupName $rg -FolderName $rf -ComputerName $fsx `
  -ContentPath $contentPath `
  -StagingPathQuotaInMB $stagingMB `
  -ConflictAndDeletedQuotaInMB $conflictMB `
  -PrimaryMember $false `
  -Force
```

**Si da *"Access is denied"*:**

```powershell
runas /user:GDC\CUENTA_ADMIN_DFS powershell.exe
# En esa ventana: definir variables y ejecutar Set-DfsrMembership
```

**Verificar:**

```powershell
Get-DfsrMembership -GroupName $rg |
  Format-Table ComputerName, ContentPath, StagingPathQuotaInMB, Enabled -AutoSize
```

**Resultado esperado:** el FSx aparece con `ContentPath` correcto.

---

## Fase 5: Verificar objetos en AD

```powershell
$entry = [ADSI]"LDAP://$fsxDn"
$searcher = New-Object System.DirectoryServices.DirectorySearcher($entry)
$searcher.Filter = "(objectClass=*)"
$searcher.SearchScope = "Subtree"
$searcher.FindAll() | ForEach-Object { $_.Path }
```

**Resultado esperado:** el nuevo RG aparece bajo `DFSR-LocalSettings`:
```
LDAP://CN=AMZNFSXXXXXXXYZ,...
LDAP://CN=DFSR-LocalSettings,CN=AMZNFSXXXXXXXYZ,...
LDAP://CN=APXEXPERIAN,CN=DFSR-LocalSettings,...         ← RG anterior
LDAP://CN=NOMBRE_RG_EXISTENTE,CN=DFSR-LocalSettings,... ← RG NUEVO
```

---

## Fase 6: Debugging y monitoreo de replicación

### Paso 6.1: Forzar actualización de configuración

```powershell
Update-DfsrConfigurationFromAD -ComputerName $onprem -Verbose
dfsrdiag.exe PollAD /Member:$onprem
```

### Paso 6.2: Monitorear eventos DFS-R

```powershell
Get-WinEvent -LogName "DFS Replication" -MaxEvents 50 |
  Where-Object { $_.Id -in 4102,4104,4114,5002,5004,5008,5012,5014 } |
  Format-Table TimeCreated, Id, Message -Wrap
```

| Evento | Significado |
|--------|-------------|
| 4102 | Replicación inicial iniciada ✅ |
| 4104 | Replicación inicial completada ✅ |
| 4114 | No pudo conectar al partner (firewall/DNS) ❌ |
| 5002 | Timeout de conexión ❌ |
| 5004 | Conexión establecida ✅ |
| 5008 | Conexión perdida ❌ |
| 5012 | Backlog detectado (normal en sync inicial) ⚠️ |
| 5014 | Backlog resuelto ✅ |

### Paso 6.3: Diagnosticar problemas de firewall

Si aparece evento 4114 o 5002:

```powershell
# Test rápido de puertos
@(135, 5722, 445, 49152) | ForEach-Object {
    $result = Test-NetConnection -ComputerName $fsx -Port $_ -WarningAction SilentlyContinue
    [PSCustomObject]@{
        Port   = $_
        Status = if ($result.TcpTestSucceeded) { "OK" } else { "BLOCKED" }
    }
} | Format-Table -AutoSize

# Diagnóstico DFS-R directo
dfsrdiag.exe MembersInPeer /RGName:$rg /MemName:$onprem /Partner:$fsx
```

### Paso 6.4: Verificar backlog

```powershell
# Backlog on-prem → FSx
dfsrdiag.exe Backlog /SendingMember:$onprem /ReceivingMember:$fsx /RGName:$rg /RFName:$rf

# Backlog FSx → on-prem
dfsrdiag.exe Backlog /SendingMember:$fsx /ReceivingMember:$onprem /RGName:$rg /RFName:$rf
```

- Backlog > 0 durante sync inicial = **normal**
- Backlog = 0 = **replicación completa**

### Paso 6.5: Health report

```powershell
Write-DfsrHealthReport -GroupName $rg -ReferenceComputerName $onprem -Path "C:\temp" -MemberComputerName $fsx
Start-Process "C:\temp\*.html"
```

---

## Fase 7: Validar replicación exitosa

### Paso 7.1: Crear archivo de prueba

```powershell
# Crear en on-prem (en el ContentPath del RG)
$testFile = "TEST-REPLICA-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
"Prueba DFS-R - $(Get-Date)" | Out-File "\\$onprem\D`$\share\$rf\$testFile" -Encoding UTF8
Write-Host "Archivo creado: $testFile" -ForegroundColor Green
```

### Paso 7.2: Verificar en FSx

```powershell
Start-Sleep -Seconds 60
Get-ChildItem "\\$fsx\D`$\share\$rf\TEST-REPLICA*"
```

### Paso 7.3: Comparar contenido

```powershell
$onpremSize = Get-ChildItem "\\$onprem\D`$\share\$rf" -Recurse -File |
  Measure-Object -Property Length -Sum
$fsxSize = Get-ChildItem "\\$fsx\D`$\share\$rf" -Recurse -File |
  Measure-Object -Property Length -Sum

Write-Host "On-prem: $($onpremSize.Count) archivos, $([math]::Round($onpremSize.Sum/1GB,2)) GB"
Write-Host "FSx:     $($fsxSize.Count) archivos, $([math]::Round($fsxSize.Sum/1GB,2)) GB"

if ($fsxSize.Count -eq $onpremSize.Count) {
    Write-Host "Replicacion completa!" -ForegroundColor Green
} else {
    Write-Host "Replicacion en progreso ($($fsxSize.Count)/$($onpremSize.Count))" -ForegroundColor Yellow
}
```

---

## Rollback

```powershell
Remove-DfsrMember -GroupName $rg -ComputerName $fsx -Force
Get-DfsrMember -GroupName $rg | Format-Table ComputerName -AutoSize
```

---

## Checklist de firewall resumen

### AWS (Security Group del FSx) — YA CONFIGURADO

| Origen (IP NAT on-prem) | Puerto | Estado |
|--------------------------|--------|--------|
| `$natIP` | 135 TCP | ✅ Permitido |
| `$natIP` | 5722 TCP | ✅ Permitido |
| `$natIP` | 445 TCP | ✅ Permitido |
| `$natIP` | 49152-65535 TCP | ✅ Permitido |

### Firewall On-Premise — VALIDAR

| Dirección | Origen | Destino | Puerto | Estado |
|-----------|--------|---------|--------|--------|
| SALIDA | `$onpremIP` | `$fsxIP` | 135, 5722, 445, 49152-65535 TCP | ⬜ Verificar |
| ENTRADA | `$fsxIP` | `$onpremIP` | 135, 5722, 49152-65535 TCP | ⬜ Verificar |

### Windows Firewall (servidor on-prem)

| Regla | Estado |
|-------|--------|
| DFS Replication (grupo) habilitado | ⬜ Verificar |

---

## Troubleshooting rápido

| Síntoma | Causa probable | Acción |
|---------|---------------|--------|
| `Test-NetConnection` falla puerto 135 | Firewall on-prem bloquea salida | Abrir salida TCP 135 hacia `$fsxIP` |
| Evento 4114 en logs | Firewall bloquea entrada desde FSx | Abrir entrada desde `$fsxIP` en on-prem |
| Evento 5002 (timeout) | Puertos RPC dinámicos bloqueados | Abrir 49152-65535 bidireccional |
| `Set-DfsrMembership` Access denied | Cuenta sin permisos | Verificar membresía en `ADMIN GDC DFS Management` |
| Backlog no baja | Sync inicial con muchos datos | Normal, esperar |
| `dfsrdiag Backlog` error RPC | Puerto 135 + dinámicos bloqueados | Verificar firewall bidireccional |
| DNS no resuelve FSx | Servidor no usa DNS del dominio | Verificar config DNS |
