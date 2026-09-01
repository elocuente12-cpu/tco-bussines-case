# Paso a paso: Agregar nuevo FSx a DFS-R (desde cero)

**FSx nuevo con:** `file_system_administrators_group = "ADMIN GDC DFS Management"`
**Cuenta operativa:** miembro de `ADMIN GDC DFS Management`
**Ejecutar todo desde:** el servidor on-prem miembro del RG (donde corren los cmdlets DFS)

---

## Pre-requisitos

- [ ] Nuevo FSx creado y accesible (DNS resolviendo)
- [ ] Cuenta operativa es miembro de `ADMIN GDC DFS Management`
- [ ] RSAT DFS instalado en el servidor donde se ejecuta
- [ ] Anotar el DNS name del nuevo FSx (ej: `amznfsxXXXXXXXX.gdc.local`)
- [ ] Anotar el hostname corto del FSx (ej: `AMZNFSXXXXXXXYZ`)

---

## Variables (completar antes de empezar)

```powershell
# ===== COMPLETAR ESTOS VALORES =====
$rg          = "APXEXPERIAN"
$rf          = "APC"
$fsx         = "amznfsxXXXXXXXX.gdc.local"         # DNS name del nuevo FSx
$fsxHost     = "AMZNFSXXXXXXXYZ"                     # Hostname corto (sin .gdc.local)
$fsxDn       = "CN=$fsxHost,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local"
$onprem      = "PAHWPAPTUI03.gdc.local"             # Miembro on-prem a conectar
$contentPath = "D:\share\APC"
$stagingMB   = 4096
$conflictMB  = 660
# ====================================
```

---

## Paso 1: Crear la carpeta destino en el FSx

```powershell
# Requiere: cuenta miembro de "ADMIN GDC DFS Management"
New-Item -Type Directory -Path "\\$fsx\D`$\share\APC" -Force
Get-ChildItem "\\$fsx\D`$\share\"
```

**Resultado esperado:** carpeta `APC` creada bajo `D:\share\`

Si da *Access denied*: la cuenta no es miembro del grupo `file_system_administrators_group` del FSx.

---

## Paso 2: Verificar estado actual del RG

```powershell
Get-DfsrMember -GroupName $rg | Format-Table ComputerName, DnsName -AutoSize
Get-DfsrMembership -GroupName $rg | Format-Table ComputerName, ContentPath, StagingPathQuotaInMB -AutoSize
```

**Verificar:** el nuevo FSx NO debe aparecer todavía. Solo los 4 miembros on-prem.

---

## Paso 3: Delegar permisos sobre el RG

```powershell
# Cuenta que ejecutará C.1/C.2/C.3 (puede ser la misma sesión si tiene permisos)
$cuenta = "GDC\C91582B-A"   # O la cuenta que corresponda

Grant-DfsrDelegation -GroupName $rg -AccountName $cuenta -Force

# Verificar
Get-DfsrDelegation -GroupName $rg |
  Where-Object AccountName -like "*C91582B*" |
  Format-Table AccountName, IsInherited -AutoSize
```

**Resultado esperado:** `IsInherited = False`

---

## Paso 4: Permisos sobre el computer object del FSx

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

**Verificar:**

```powershell
$entry = [ADSI]"LDAP://$fsxDn"
$entry.ObjectSecurity.Access |
  Where-Object { $_.IdentityReference -like "*C91582B*" } |
  Format-Table IdentityReference, ActiveDirectoryRights, InheritanceType -AutoSize
```

**Resultado esperado:** `GenericAll` con `InheritanceType = All`

---

## Paso 5: Agregar miembro al RG (C.1)

```powershell
Add-DfsrMember -GroupName $rg -ComputerName $fsx -Description "FSx nuevo intelisrcpa (ADMIN GDC DFS Management)"
```

**Verificar:**

```powershell
Get-DfsrMember -GroupName $rg | Format-Table ComputerName -AutoSize
```

---

## Paso 6: Crear conexiones (C.2)

```powershell
Add-DfsrConnection -GroupName $rg -SourceComputerName $onprem -DestinationComputerName $fsx
```

**Verificar:**

```powershell
Get-DfsrConnection -GroupName $rg |
  Where-Object { $_.SourceComputerName -like "*$fsxHost*" -or $_.DestinationComputerName -like "*$fsxHost*" } |
  Format-Table SourceComputerName, DestinationComputerName, Enabled -AutoSize
```

**Resultado esperado:** 2 conexiones bidireccionales, ambas `Enabled = True`

---

## Paso 7: Configurar membresía (C.3)

```powershell
Set-DfsrMembership -GroupName $rg -FolderName $rf -ComputerName $fsx `
  -ContentPath $contentPath `
  -StagingPathQuotaInMB $stagingMB `
  -ConflictAndDeletedQuotaInMB $conflictMB `
  -PrimaryMember $false `
  -Force
```

**Si da error *"Access is denied"*:** probar directamente con la cuenta que es miembro de `ADMIN GDC DFS Management` usando `runas`:

```powershell
runas /user:GDC\CUENTA_ADMIN_DFS powershell.exe
# En esa ventana, pegar las variables y ejecutar Set-DfsrMembership
```

**Verificar:**

```powershell
Get-DfsrMembership -GroupName $rg |
  Format-Table ComputerName, ContentPath, StagingPathQuotaInMB, Enabled -AutoSize
```

**Resultado esperado:** el FSx muestra `ContentPath = D:\share\APC`

---

## Paso 8: Verificar objetos en AD

```powershell
$entry = [ADSI]"LDAP://$fsxDn"
$searcher = New-Object System.DirectoryServices.DirectorySearcher($entry)
$searcher.Filter = "(objectClass=*)"
$searcher.SearchScope = "Subtree"
$searcher.FindAll() | ForEach-Object { $_.Path }
```

**Resultado esperado:**
```
LDAP://CN=AMZNFSXXXXXXXYZ,...
LDAP://CN=DFSR-LocalSettings,CN=AMZNFSXXXXXXXYZ,...
LDAP://CN=APXEXPERIAN,CN=DFSR-LocalSettings,...
LDAP://CN=APC,CN=APXEXPERIAN,CN=DFSR-LocalSettings,...
```

---

## Paso 9: Esperar replicación

Monitorear eventos en el servidor on-prem:

```powershell
Get-WinEvent -LogName "DFS Replication" -MaxEvents 30 |
  Where-Object { $_.Id -in 4102,4104,5002,5004,5008 } |
  Format-Table TimeCreated, Id, Message -Wrap
```

| Evento | Significado |
|--------|-------------|
| 4102 | Replicación inicial iniciada ✅ |
| 4104 | Replicación inicial completada ✅ |
| 5002/5004/5008 | Error de conexión (firewall) |

**Tiempo esperado:** 5 min a 1 hora para que aparezca el 4102.

---

## Paso 10: Verificar contenido replicado

```powershell
Get-ChildItem "\\$fsx\share\APC" -Recurse -File |
  Measure-Object -Property Length -Sum |
  Select-Object Count, @{n='GB';e={[math]::Round($_.Sum/1GB,2)}}
```

Si crece entre ejecuciones → está replicando.

---

## Rollback (si algo sale mal)

```powershell
Remove-DfsrMember -GroupName $rg -ComputerName $fsx -Force
Get-DfsrMember -GroupName $rg | Format-Table ComputerName -AutoSize
```

---

## Diferencia clave con el FSx anterior

| Aspecto | FSx anterior | FSx nuevo |
|---------|-------------|-----------|
| `file_system_administrators_group` | `Domain Admins` (nadie lo tiene) | `ADMIN GDC DFS Management` (cuenta operativa sí es miembro) |
| Acceso a `D$` | Bloqueado | Funciona |
| `Set-DfsrMembership` | *Access is denied* | **Debería funcionar** |

La hipótesis es que el cmdlet necesita que la cuenta tenga relación con el grupo administrativo del FSx para escribir el security descriptor del ContentSet.
