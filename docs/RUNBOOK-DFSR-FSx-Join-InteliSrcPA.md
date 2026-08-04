# Runbook: Agregar FSx for Windows a un Replication Group DFS-R existente

**Proyecto:** InteliSrcPA — Migración Producción a AWS
**Alcance:** Unir el FSx `intelisrcpa-prd` al grupo de replicación DFS-R que ya opera on-premises, para que los datos queden disponibles a las EC2 Windows del VPC.
**Decisión de arquitectura de referencia:** [DECISION-DFS-FSx-DR-InteliSrcPA.md](DECISION-DFS-FSx-DR-InteliSrcPA.md) (Opción C)
**Puertos:** [ports-fsx-dfs.md](ports-fsx-dfs.md)

---

## 1. Estado verificado del despliegue

Valores tomados de `iac/repo/intelisrcpa/pro/`:

| Parámetro | Valor | Fuente | Requisito DFS-R |
|---|---|---|---|
| Deployment type | `SINGLE_AZ_1` | `terraform.tfvars:674` | ✅ único tipo que soporta DFS-R |
| Storage type | `SSD` | `terraform.tfvars:677` | ✅ Single-AZ 1 no soporta HDD |
| Storage capacity | **32 GiB** | `terraform.tfvars:675` | ⚠️ mínimo de FSx — ver §7 |
| Active Directory | self-managed `gdc.local` | `fsx.tf:31-38` | ✅ mismo dominio del RG |
| OU del FSx | `OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local` | `terraform.tfvars:685` | ✅ OU distinta es válida — ver §3 |
| `file_system_administrators_group` | `Domain Admins` | `terraform.tfvars:679` | ⚠️ inmutable — ver §4 |
| Puertos DFS-R en SG | 135, 445, 49152-65535, 53, 88, 389/636, 3268-3269 | `terraform.tfvars:238` | ✅ |

> **Nota de consistencia:** el documento de decisión menciona el dominio `ena.us.experian.local` y el puerto `5722`. Ambos están desactualizados respecto al despliegue real: el dominio es `gdc.local` y Windows Server 2012+ usa RPC dinámico (49152-65535) en lugar del 5722 fijo.

---

## 2. Restricción fundamental: FSx no expone sistema operativo

Esta es la causa raíz de casi todos los problemas de este procedimiento y conviene entenderla antes de ejecutar.

FSx for Windows es un servicio gestionado. **No hay acceso al SO, no existe un grupo de "Administradores locales" del file system, y el Service Control Manager no es accesible remotamente.** El endpoint de PowerShell remoto (`FsxRemoteAdmin`) es una sesión *constrained* que solo expone cmdlets propios de FSx — no incluye cmdlets DFSR.

Consecuencias directas:

| Herramienta | Mecanismo | Contra FSx |
|---|---|---|
| **DFS Management (GUI)** | Valida en vivo contra el miembro vía RPC/SCM | ❌ **falla siempre** |
| `Add-DfsrMember` / `Add-DfsrConnection` / `Set-DfsrMembership` | Escriben solo objetos en AD | ✅ **ruta viable** |
| `Update-DfsrConfigurationFromAD` | WMI al miembro | ❌ |
| `Get-DfsrBacklog` / `dfsrdiag backlog` | WMI al miembro | ❌ |
| `Write-DfsrHealthReport` | Requiere admin local del miembro | ❌ |
| `Export-DfsrClone` / `Import-DfsrClone` (pre-seeding) | Ejecución en el SO del miembro | ❌ |

**El wizard "New Member" de DFS Management no puede completarse contra un FSx.** Todo el procedimiento se hace por PowerShell escribiendo en Active Directory; el servicio DFSR del FSx recoge esa configuración en su ciclo de polling (~5 min, hasta 1 hora).

Que los cmdlets de diagnóstico fallen **no** significa que la replicación esté rota. La verificación se hace desde el lado on-premises (§6).

---

## 3. Por qué la OU distinta no es un problema (y dónde sí importa)

La configuración del replication group **no vive en ninguna OU**: está en `CN=DFSR-GlobalSettings,CN=System,DC=gdc,DC=local`, que es domain-wide. El requisito siempre fue *mismo dominio/bosque*, no misma OU.

Donde sí importa la OU: Microsoft separa los objetos DFSR en dos grupos, y los *server-local* se crean **como hijos del computer object del miembro**:

```
CN=<FSx>,OU=FSx,OU=Windows,...,DC=gdc,DC=local
  └── CN=DFSR-LocalSettings           (msDFSR-LocalSettings)
        └── CN=<ReplicationGroup>     (msDFSR-Subscriber)
              └── CN=<Folder>          (msDFSR-Subscription)
                    ├── msDFSR-RootPath
                    ├── msDFSR-StagingPath
                    ├── msDFSR-StagingSizeInMb
                    └── msDFSR-ConflictSizeInMb
```

Por eso la cuenta que ejecuta el procedimiento necesita permisos de creación de objetos hijos sobre el computer object del FSx, dentro de `OU=FSx`. Si esa OU tiene herencia bloqueada o delegación restringida, el procedimiento falla (§8, error 1).

---

## 4. Cuenta y permisos requeridos

Se usa una **cuenta de usuario del dominio** en sesión interactiva. Los cmdlets DFSR **no aceptan `-Credential`**: si se necesita otra identidad, hay que abrir la sesión completa con `runas /user:GDC\<cuenta> powershell.exe`.

| Permiso | Para qué | Cómo otorgarlo |
|---|---|---|
| Full Control sobre `CN=Topology,CN=<RG>,CN=DFSR-GlobalSettings,CN=System,DC=gdc,DC=local` | Agregar miembro y conexión | §5.A.1 |
| Full Control sobre el computer object del FSx | Crear `DFSR-LocalSettings` y la suscripción | §5.A.2 |
| Admin local en el file server on-prem (o Full Control sobre su computer object) | Modificar miembros del RG | Ya se tiene si se administra ese servidor |
| Miembro de `Domain Admins` | **Solo** para crear la carpeta destino vía `\\fsx\D$` | Ver nota |

> **Sobre `Domain Admins`:** DFS-R en sí **no** lo requiere — es delegable. Lo requiere el lado FSx porque `file_system_administrators_group = "Domain Admins"` en el IaC. Ese valor **no es modificable después del despliegue**: la API `SelfManagedActiveDirectoryConfigurationUpdates` permite actualizar `FileSystemAdministratorsGroup` únicamente en FSx for ONTAP, no en FSx for Windows. Cambiarlo exige recrear el file system o restaurar desde backup.
>
> Mitigación sin recrear: que un Domain Admin ejecute **solo el paso B.1** (una línea, una vez). El resto funciona con las delegaciones de arriba.

La **cuenta de servicio de FSx** (`fsx.tf:34-35`) es otra cosa: solo la usa el servicio FSx para unir y mantener el file system en el dominio. No participa en DFS-R y no debe usarse para este procedimiento.

---

## 5. Procedimiento

Ejecutar desde el **file server on-premise miembro del RG**. Es el host correcto porque ya tiene las RSAT de DFS, tiene línea de vista a los DCs, y permite leer el log `DFS Replication` localmente — que es donde vive toda la evidencia útil.

### Variables

```powershell
$rg     = "<ReplicationGroup>"          # Get-DfsReplicationGroup
$rf     = "<FolderName>"                # Get-DfsReplicatedFolder -GroupName $rg
$fsx    = "amznfsxXXXXXXXX.gdc.local"   # DNS name del FSx
$onprem = "FS01.gdc.local"              # miembro actual del RG
$dom    = (Get-ADDomain).DistinguishedName
$fsxDn  = (Get-ADComputer -Filter 'Name -like "amznfsx*"').DistinguishedName
```

### Fase A — Delegaciones (una vez)

**A.1 — Verificar/otorgar Full Control sobre el Topology del RG**

```powershell
$topoDn = "CN=Topology,CN=$rg,CN=DFSR-GlobalSettings,CN=System,$dom"

# Verificar
(Get-Acl "AD:\$topoDn").Access |
  Where-Object { $_.IdentityReference -like "*$env:USERNAME*" } |
  Format-Table IdentityReference, ActiveDirectoryRights, InheritanceType
```

Si está vacío (requiere Domain Admin una vez):

```powershell
$sid = (New-Object System.Security.Principal.NTAccount("GDC\$env:USERNAME")).Translate(
         [System.Security.Principal.SecurityIdentifier])
$acl  = Get-Acl -Path "AD:\$topoDn"
$rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
          $sid,
          [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
          [System.Security.AccessControl.AccessControlType]::Allow,
          [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All)
$acl.AddAccessRule($rule); Set-Acl -Path "AD:\$topoDn" -AclObject $acl
```

**A.2 — Full Control sobre el computer object del FSx**

```powershell
# Verificar que la herencia de la OU no lo bloquee
(Get-Acl "AD:\OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,$dom").AreAccessRulesProtected

$acl  = Get-Acl -Path "AD:\$fsxDn"
$rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
          $sid,
          [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
          [System.Security.AccessControl.AccessControlType]::Allow,
          [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All)
$acl.AddAccessRule($rule); Set-Acl -Path "AD:\$fsxDn" -AclObject $acl
```

> Vía GUI (ADUC): View → **Advanced Features** → computer object → Properties → Security → Advanced → Add → **Applies to: "This object and all descendant objects"** (dejarlo en *This object only* es el error más común).

**A.3 — Propagar y refrescar token**

```powershell
repadmin /syncall (Get-ADDomain).PDCEmulator /AdeP
```

DFS Management se ancla normalmente al PDC emulator. Si se otorgó el permiso contra otro DC, esperar la replicación. **Si se cambió membresía de grupo, cerrar sesión y volver a entrar** — el token de Kerberos arrastra los grupos anteriores.

### Fase B — Preparación

**B.1 — Crear la carpeta destino en el FSx** *(requiere `Domain Admins`)*

```powershell
New-Item -Type Directory -Path "\\$fsx\D$\share\Datos"
Get-ChildItem "\\$fsx\D$\share\"
```

> ⚠️ **No modificar las ACL NTFS del usuario `SYSTEM`** sobre esta carpeta. AWS advierte que `SYSTEM` requiere Full control en toda carpeta con share, y alterarlo puede dejar el file system inaccesible y los backups inutilizables.

El share por defecto es `\share`, que corresponde a `D:\share` en el file system.

**B.2 — Estado actual del RG**

```powershell
Get-DfsReplicationGroup -GroupName $rg | Format-List GroupName, DomainName, State
Get-DfsrMember -GroupName $rg | Format-Table ComputerName, DomainName
Get-DfsrMembership -GroupName $rg |
  Format-Table ComputerName, ContentPath, StagingPath, StagingPathQuotaInMB, PrimaryMember
```

Anotar el `StagingPathQuotaInMB` del miembro on-prem: replicar ese valor o mayor.

**B.3 — Dimensionamiento** *(gate obligatorio — ver §7)*

```powershell
# Tamano del dataset
Get-ChildItem "E:\RutaDelFolder" -Recurse -File |
  Measure-Object -Property Length -Sum |
  Select-Object Count, @{n='GB';e={[math]::Round($_.Sum/1GB,2)}}

# Suma de los 32 archivos mas grandes -> staging quota minimo (regla de Microsoft)
Get-ChildItem "E:\RutaDelFolder" -Recurse -File |
  Sort-Object Length -Descending | Select-Object -First 32 |
  Measure-Object -Property Length -Sum |
  ForEach-Object { [math]::Round($_.Sum/1GB,2) }
```

**No continuar** si `dataset + staging + conflict` no cabe holgado en la capacidad del FSx.

**B.4 — Limpiar residuos de intentos previos**

```powershell
if (Get-DfsrMember -GroupName $rg | Where-Object ComputerName -like "amznfsx*") {
    Remove-DfsrMember -GroupName $rg -ComputerName $fsx -Force
}
```

### Fase C — Configuración

```powershell
# C.1 Agregar el FSx como miembro del RG
Add-DfsrMember -GroupName $rg -ComputerName $fsx -Description "FSx intelisrcpa-prd (Single-AZ 1)"

# C.2 Conexion — bidireccional por defecto; agregar -CreateOneWay para unidireccional estricto
Add-DfsrConnection -GroupName $rg -SourceComputerName $onprem -DestinationComputerName $fsx

# C.3 Membresia
Set-DfsrMembership -GroupName $rg -FolderName $rf -ComputerName $fsx `
  -ContentPath "D:\share\Datos" `
  -StagingPathQuotaInMB 16384 `
  -ConflictAndDeletedQuotaInMB 4096 `
  -PrimaryMember $false `
  -Force
```

**`-PrimaryMember $false` es crítico:** garantiza que el contenido del miembro on-premises es el autoritativo. Marcar el FSx como primario haría que su contenido (vacío) gane y sobrescriba los datos on-premises.

Para membresía de solo lectura (si las EC2 únicamente leen), agregar `-ReadOnly $true`. Nota: que FSx acepte membresía read-only no está documentado por AWS — validar en el PoC.

### Fase D — Verificación

**D.1 — Objetos en AD** *(frontera de control: si esto pasa, la responsabilidad es del servicio gestionado)*

```powershell
Get-ADObject -SearchBase $fsxDn -Filter * -SearchScope Subtree | Select-Object Name, ObjectClass
```

Debe aparecer: `DFSR-LocalSettings` → `msDFSR-Subscriber` → `msDFSR-Subscription`.

**D.2 — Eventos en el miembro on-premises** (esperar ~5 min; hasta 1 hora)

```powershell
Get-WinEvent -LogName "DFS Replication" -MaxEvents 30 |
  Format-Table TimeCreated, Id, Message -Wrap
```

| Evento | Significado | Acción |
|---|---|---|
| **4102** | Replicación inicial iniciada | ✅ la configuración llegó al FSx |
| **4104** | Replicación inicial completada | ✅ listo |
| 4202 / 4204 | Staging quota excedida | Subir `-StagingPathQuotaInMB` |
| 4302 / 4304 | Archivos atascados | Revisar locks / archivos en uso |
| 5002 / 5004 / 5008 | Fallo de conexión con el miembro | Firewall on-prem, RPC dinámico sentido de vuelta |

**D.3 — Verificación por contenido** (siempre funciona, no depende de WMI)

```powershell
Get-ChildItem "\\$fsx\share\Datos" -Recurse -File | Measure-Object -Property Length -Sum
```

### Fase E — Consumo desde las EC2

```powershell
net use Z: \\amznfsxXXXXXXXX.gdc.local\share\Datos /persistent:yes
```

Opcionalmente, publicar el share en el namespace existente para mantener el mismo UNC:

```powershell
New-DfsnFolderTarget -Path "\\gdc.local\<Namespace>\<Folder>" `
  -TargetPath "\\amznfsxXXXXXXXX.gdc.local\share\Datos" `
  -ReferralPriorityClass SiteCostNormal
```

> **No permitir escrituras desde las EC2 hasta ver el evento 4104.** Con replicación bidireccional, escribir durante la sincronización inicial genera conflictos evitables.

---

## 6. Rollback

```powershell
Remove-DfsrMember -GroupName $rg -ComputerName $fsx -Force
```

Saca el FSx del RG sin tocar el miembro on-premises. Los datos ya replicados quedan en el FSx sin sincronizar. Limpiar manualmente `D:\share\Datos\DfsrPrivate` después.

---

## 7. Riesgo abierto: capacidad de 32 GiB

`fsx_storage_capacity = 32` es el mínimo absoluto de FSx SSD y aparenta ser un valor por defecto sin dimensionar. Ese volumen debe alojar simultáneamente:

| Componente | Tamaño |
|---|---|
| Datos replicados | dataset completo |
| Staging (`DfsrPrivate`) | default 4 GB = **12,5% del volumen**; recomendado ≥ suma de los 32 archivos más grandes |
| `ConflictAndDeleted` | default 660 MB (configurable) |
| `PreExisting` | solo si hubo pre-seeding con hashes no coincidentes |

Si el staging queda corto, DFSR entra en backlog permanente (eventos 4202/4204). La capacidad se puede aumentar en caliente, pero **no se puede reducir**.

> **Bloqueador para el aumento:** `securitygroups.tf:133` referencia `module.sg_windows["PAHWPWSAPI01"]` y `["PAHWPWFINT01"]`, pero ambas claves están comentadas en el mapa `sg_windows` de `terraform.tfvars:149`. Un `terraform plan` debería fallar con *invalid index*. **Corregir esto antes de necesitar un apply de emergencia.**

### Sobre el pre-seeding

La siembra previa con `Export-DfsrClone`/`Import-DfsrClone` **no es posible** en FSx. La alternativa es `robocopy` con `/E /B /COPYALL /DCOPY:DAT /XD DfsrPrivate` antes de agregar el miembro.

A la escala que permiten 32 GiB (decenas de GB como techo), el pre-seeding no aporta: la sincronización inicial directa toma 1-2 horas sobre un enlace de 100 Mbps. Omitirlo es además más seguro — un pre-seeding mal hecho genera hashes no coincidentes que van a `PreExisting`, consumen disco y se re-descargan igual.

El pre-seeding se justifica a partir de cientos de GB. Si ese es el caso, el problema real es que la capacidad no alcanza.

---

## 8. Errores encontrados y su resolución

Registro de los problemas reales de esta implementación.

### Error 1 — Permisos de AD

```
The DFS Replication Subscriber object cannot be created in Active Directory Domain Services.
There are insufficient permissions to create the DFSR-LocalSettings container.
```

**Causa:** la cuenta carecía de *create child* sobre el computer object del FSx en `OU=FSx`.

**Resolución:** Full Control sobre el computer object, aplicado a *"This object and all descendant objects"* (§5.A.2) + `repadmin /syncall`.

**Nota:** si el error mencionara el miembro o la conexión en lugar del contenedor LocalSettings, el permiso faltante sería sobre `CN=Topology` (§5.A.1).

### Error 2 — Service Control Manager

```
The service control manager cannot be opened. Access is denied.
```

**Causa:** DFS Management intenta abrir el SCM remoto del FSx para verificar que el servicio DFS Replication esté corriendo. El acceso remoto al SCM exige pertenecer al grupo **Administradores locales del servidor destino**.

**En FSx esto es imposible:** no hay SO expuesto ni grupo de administradores locales. **Ningún permiso de AD resuelve este error** — no es un problema de AD.

**Resolución:** abandonar el wizard de DFS Management y usar la Fase C por PowerShell, que escribe directamente en AD sin validación en vivo contra el miembro.

> Este error confirma que el GUI **nunca** podrá completar el procedimiento contra un FSx. No reintentar.

---

## 9. Estado de la documentación oficial de AWS

AWS **retiró** la página `using-dfsr.html` del FSx for Windows User Guide. La URL redirige a `what-is.html`, no aparece en el TOC del guide ni en el PDF vigente (verificado agosto 2026).

Lo que permanece oficialmente:

- La tabla *Feature support by deployment type*, que sigue marcando **DFS replication ✓ solo en Single-AZ 1**
- La página de troubleshooting *"You can't configure DFS-R on a Multi-AZ or Single-AZ 2 file system"*

**Implicación:** el procedimiento sigue siendo soportado según la tabla de features, pero **no tiene guía oficial vigente**. Se recomienda abrir un caso con Soporte AWS para (a) confirmar el escenario on-premises → FSx y (b) preguntar si DFS-R sigue siendo una ruta recomendada para Single-AZ 1 o si internamente se considera en desuso. La respuesta debería influir en si se sostiene este diseño.

Si tras una hora los objetos AD existen (D.1) pero no aparece el evento 4102, el problema está del lado gestionado de AWS. Datos para el caso: file system ID, deployment type `SINGLE_AZ_1`, nombre del RG, y evidencia de que `msDFSR-Subscriber`/`msDFSR-Subscription` están creados bajo el computer object.

---

## 10. Referencias

**AWS**

- [Availability and durability: feature support by deployment type](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/high-availability-multiAZ.html)
- [You can't configure DFS-R on a Multi-AZ or Single-AZ 2 file system](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/dfs-r.html)
- [File system access control with Amazon VPC (puertos)](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/limit-access-security-groups.html)
- [Using a self-managed Microsoft Active Directory](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/self-managed-AD.html)
- [Delegating permissions to the Amazon FSx service account](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/assign-permissions-to-service-account.html)
- [Managing file shares](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/managing-file-shares.html)
- [API: SelfManagedActiveDirectoryConfigurationUpdates](https://docs.aws.amazon.com/fsx/latest/APIReference/API_SelfManagedActiveDirectoryConfigurationUpdates.html)
- [Using DFS Namespaces](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/using-dfs-namespaces.html)

**Microsoft**

- [Delegate DFS replication (KB 911604)](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/delegating-dfs-replication) — objetos AD, delegación y la alternativa "Full Control sobre computer objects" en lugar de admin local
- [DFS Replication FAQ](https://learn.microsoft.com/en-us/windows-server/storage/dfs-replication/dfsr-faq)
- [Grant-DfsrDelegation](https://learn.microsoft.com/en-us/powershell/module/dfsr/grant-dfsrdelegation)

---

*Documento generado: agosto 2026*
*Proyecto: InteliSrcPA — Migración Producción a AWS · Región us-east-1*
