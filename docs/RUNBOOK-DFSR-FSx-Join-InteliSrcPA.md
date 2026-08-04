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

**Qué hace:** define los identificadores que usa todo el runbook.

| Variable | Qué es | De dónde sale |
|---|---|---|
| `$rg` | Nombre del replication group existente | `Get-DfsReplicationGroup` |
| `$rf` | Nombre del replicated folder dentro del RG | `Get-DfsReplicatedFolder -GroupName $rg` |
| `$fsx` | FQDN del file system | Consola FSx → Network & Security → DNS name, o `aws fsx describe-file-systems` |
| `$onprem` | FQDN del file server que ya es miembro | `Get-DfsrMember -GroupName $rg` |
| `$dom` | DN del dominio (ej. `DC=gdc,DC=local`) | Se calcula solo |
| `$fsxDn` | DN del computer object del FSx en AD | Se calcula solo; el FSx registra su objeto con prefijo `amznfsx` |

`Get-ADComputer` requiere el módulo `ActiveDirectory`. Si falta: `Install-WindowsFeature RSAT-AD-PowerShell`.

### Fase A — Delegaciones (una vez)

Esta fase no toca DFS-R: solo ajusta permisos en Active Directory para que la cuenta pueda crear los objetos que DFS-R necesita. Se ejecuta una sola vez.

**A.1 — Verificar/otorgar Full Control sobre el Topology del RG**

```powershell
$topoDn = "CN=Topology,CN=$rg,CN=DFSR-GlobalSettings,CN=System,$dom"

# Verificar
(Get-Acl "AD:\$topoDn").Access |
  Where-Object { $_.IdentityReference -like "*$env:USERNAME*" } |
  Format-Table IdentityReference, ActiveDirectoryRights, InheritanceType
```

**Qué hace:** lee la ACL del contenedor `Topology` del replication group y filtra las entradas de tu usuario.

`CN=Topology` es el nodo de AD donde viven los objetos `msDFSR-Member` (un miembro del RG) y `msDFSR-Connection` (una conexión de replicación). Sin permisos de escritura ahí, `Add-DfsrMember` y `Add-DfsrConnection` fallan.

`AD:\` es el PSDrive de Active Directory: permite tratar objetos de AD como rutas de archivo y usar `Get-Acl`/`Set-Acl` sobre ellos.

**Resultado esperado:** una fila con `ActiveDirectoryRights = GenericAll`. Si sale vacío, no tienes el permiso.

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

**Qué hace, línea por línea:**

| Línea | Acción |
|---|---|
| `$sid = ...Translate(...)` | Convierte el nombre de cuenta `GDC\usuario` a su SID. Las ACL de AD se escriben con SIDs, no con nombres |
| `$acl = Get-Acl` | Descarga la ACL actual del objeto |
| `ActiveDirectoryAccessRule(...)` | Construye la nueva regla de permiso |
| `GenericAll` | Equivale a **Full Control** |
| `AccessControlType::Allow` | Es una regla de permitir (no de denegar) |
| `ActiveDirectorySecurityInheritance::All` | Aplica a **este objeto y todos los descendientes** — equivale a *"This object and all descendant objects"* en la GUI |
| `$acl.AddAccessRule($rule)` | Agrega la regla al objeto ACL **en memoria** |
| `Set-Acl` | Escribe la ACL modificada de vuelta a AD. Hasta aquí nada se había persistido |

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

###ERROR

False
Get-Acl : Cannot find path 'AD:\CN=AMZNFSX03TTJZMW,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=amznfsx0i5lbxmu,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=amznfsx26oislzq,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSX2J1KXUNF,OU=Servers,OU=Systems,DC=gdc,DC=local CN=AMZNFSX2MZF7YJL,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSX3FKCOPYD,OU=AlteryxFSx,OU=Servers,OU=Systems,DC=gdc,DC=local CN=AMZNFSX4BH43O9J,OU=AWS FSX 
Servers,OU=Servers,OU=Systems,DC=gdc,DC=local CN=amznfsx4cnoi0km,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSX564DKDLG,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local CN=amznfsx6tiqlz4w,OU=AWS FSX 
Servers,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSX7HZQVVUA,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local CN=amznfsx9lzfnymf,OU=AWS 
FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local CN=AMZNFSXCIAFVGNR,OU=AlteryxFSx,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=amznfsxdhnmfnkv,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=amznfsxet830km1,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSXEZE56TBV,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSXGADPDL0X,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSXHPNQTZR2,OU=AlteryxFSx,OU=Servers,OU=Systems,DC=gdc,DC=local CN=amznfsxi4waark1,OU=AWS FSX 
Servers,OU=Servers,OU=Systems,DC=gdc,DC=local CN=amznfsxjraxv1xz,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSXLCXIQNKX,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSXP48SWHBX,OU=CEMDataOpsFSx,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSXPHPXL23K,OU=AlteryxFSx,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=amznfsxpqhg3mmm,OU=AlteryxFSx,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=AMZNFSXTNSRVP6D,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=amznfsxusylgtaq,OU=CEMDataOpsFSx,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=amznfsxwgkjf8fd,OU=AlteryxFSx,OU=Servers,OU=Systems,DC=gdc,DC=local CN=AMZNFSXWVK2EFPT,OU=AWS FSX 
Servers,OU=Servers,OU=Systems,DC=gdc,DC=local CN=amznfsxxklsyxgn,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local 
CN=amznfsxyn82hu7w,OU=CEMDataOpsFSx,OU=Servers,OU=Systems,DC=gdc,DC=local CN=AMZNFSXZD02YIIR,OU=AWS FSX 
Servers,OU=Servers,OU=Systems,DC=gdc,DC=local CN=AMZNFSXZIOQ5PG6,OU=CEMDataOpsFSx,OU=Servers,OU=Systems,DC=gdc,DC=local' because it 
does not exist.
At line:31 char:9
+ $acl  = Get-Acl -Path "AD:\$fsxDn"
+         ~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : ObjectNotFound: (:) [Get-Acl], ItemNotFoundException
    + FullyQualifiedErrorId : GetAcl_PathNotFound_Exception,Microsoft.PowerShell.Commands.GetAclCommand
You cannot call a method on a null-valued expression.
At line:37 char:1
+ $acl.AddAccessRule($rule); Set-Acl -Path "AD:\$fsxDn" -AclObject $acl
+ ~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : InvalidOperation: (:) [], RuntimeException
    + FullyQualifiedErrorId : InvokeMethodOnNull
Set-Acl : Cannot bind argument to parameter 'AclObject' because it is null.
At line:37 char:66
+ $acl.AddAccessRule($rule); Set-Acl -Path "AD:\$fsxDn" -AclObject $acl
+                                                                  ~~~~
    + CategoryInfo          : InvalidData: (:) [Set-Acl], ParameterBindingValidationException
    + FullyQualifiedErrorId : ParameterArgumentValidationErrorNullNotAllowed,Microsoft.PowerShell.Commands.SetAclCommand

 
PS C:\Users\c91582b-a>

**Qué hace:** el mismo patrón de A.1, pero aplicado al **computer object del FSx** en lugar del nodo Topology.

Es necesario porque los objetos `DFSR-LocalSettings` → `msDFSR-Subscriber` → `msDFSR-Subscription` se crean como **hijos del computer object del miembro** (ver §3). Sin este permiso aparece el error 1 de §8.

`AreAccessRulesProtected` responde: *¿esta OU tiene la herencia bloqueada?*

- `False` → la OU hereda permisos del padre; lo normal
- `True` → herencia bloqueada. Los permisos heredados **no aplican**, así que ni un Domain Admin heredado necesariamente pasa. Hay que otorgar la ACL explícita de abajo

> Vía GUI (ADUC): View → **Advanced Features** → computer object → Properties → Security → Advanced → Add → **Applies to: "This object and all descendant objects"** (dejarlo en *This object only* es el error más común).

**A.3 — Propagar y refrescar token**

```powershell
repadmin /syncall (Get-ADDomain).PDCEmulator /AdeP
```

**Qué hace:** fuerza la replicación de AD hacia el PDC emulator para que el permiso recién escrito esté disponible ahí de inmediato, en vez de esperar el ciclo normal de replicación entre DCs.

Los flags: `/A` todos los naming contexts, `/d` identifica servidores por DN, `/e` cruza sitios (enterprise), `/P` empuja desde el servidor local en lugar de traer.

**Por qué el PDC emulator:** las herramientas DFS se anclan a ese DC para leer y escribir la configuración DFSR. Si otorgaste el permiso contra otro DC y no replicó aún, los comandos siguen fallando aunque el permiso "ya esté puesto".

**Si se cambió membresía de grupo, cerrar sesión y volver a entrar** — el token de Kerberos se emite al iniciar sesión y arrastra los grupos que tenías en ese momento. Ningún `repadmin` lo actualiza.

### Fase B — Preparación

**B.1 — Crear la carpeta destino en el FSx** *(requiere `Domain Admins`)*

```powershell
New-Item -Type Directory -Path "\\$fsx\D$\share\Datos"
Get-ChildItem "\\$fsx\D$\share\"
```

**Qué hace:** crea por SMB la carpeta que será el replicated folder, y lista el contenido para confirmarlo.

`D$` es el **admin share** del volumen D: del file system. FSx expone el share visible `\share`, que internamente es `D:\share`. Se usa `D$` en lugar de `\share` porque en el paso C.3 hay que declarar la **ruta local vista por el miembro** (`D:\share\Datos`), y esta notación deja explícita esa correspondencia.

**Por qué necesita `Domain Admins`:** acceder a un admin share (`D$`) exige privilegios administrativos sobre el file system, y en FSx eso lo define `file_system_administrators_group`, que en este despliegue es `Domain Admins` (§4).

**Si falla con *access denied*:** la cuenta no está en ese grupo. No es un problema de red — que `telnet` al 445 conecte solo prueba que el puerto está abierto, no que tengas permisos.

> ⚠️ **No modificar las ACL NTFS del usuario `SYSTEM`** sobre esta carpeta. AWS advierte que `SYSTEM` requiere Full control en toda carpeta con share, y alterarlo puede dejar el file system inaccesible y los backups inutilizables.

**B.2 — Estado actual del RG**

```powershell
Get-DfsReplicationGroup -GroupName $rg | Format-List GroupName, DomainName, State
Get-DfsrMember -GroupName $rg | Format-Table ComputerName, DomainName
Get-DfsrMembership -GroupName $rg |
  Format-Table ComputerName, ContentPath, StagingPath, StagingPathQuotaInMB, PrimaryMember
```

**Qué hace:** fotografía del RG antes de tocarlo. Son tres niveles distintos:

| Cmdlet | Devuelve | Para qué sirve aquí |
|---|---|---|
| `Get-DfsReplicationGroup` | El grupo en sí | Confirmar que `DomainName` es `gdc.local` — si fuera otro dominio, el FSx no puede unirse |
| `Get-DfsrMember` | Los servidores que participan | Ver quién está hoy y detectar residuos de intentos previos |
| `Get-DfsrMembership` | La relación miembro ↔ carpeta replicada | Es donde viven `ContentPath`, `StagingPath` y las cuotas |

**Qué anotar:** el `StagingPathQuotaInMB` del miembro on-prem — se replica ese valor o mayor en C.3. Y confirmar cuál miembro tiene `PrimaryMember = True`.

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

**Qué hace el primero:** recorre recursivamente la carpeta origen, suma el tamaño de todos los archivos y devuelve cantidad y GB. `-File` excluye directorios para no contar dos veces.

**Qué hace el segundo:** ordena los archivos de mayor a menor, toma los 32 primeros y suma su tamaño. Ese número es el **mínimo de staging quota** según la regla de Microsoft.

**Por qué 32 archivos:** DFSR usa el staging como área intermedia donde prepara los archivos antes de transmitirlos. Si la cuota no alcanza para los archivos más grandes en vuelo simultáneo, DFSR entra en un ciclo de limpieza y reintento que se manifiesta como backlog permanente (eventos 4202/4204).

**No continuar** si `dataset + staging + conflict` no cabe holgado en la capacidad del FSx.

**B.4 — Limpiar residuos de intentos previos**

```powershell
if (Get-DfsrMember -GroupName $rg | Where-Object ComputerName -like "amznfsx*") {
    Remove-DfsrMember -GroupName $rg -ComputerName $fsx -Force
}
```

**Qué hace:** si el FSx ya figura como miembro del RG, lo elimina antes de reintentar.

**Por qué es necesario:** el wizard de DFS Management aborta a mitad de camino (§8, error 2), y puede dejar un `msDFSR-Member` creado sin su suscripción correspondiente. Ese estado a medias hace que `Add-DfsrMember` falle con *"already exists"*.

`-Force` suprime la confirmación interactiva. El cmdlet solo borra objetos de AD del miembro FSx: **no toca al miembro on-premises ni sus datos**.

### Fase C — Configuración

Los tres cmdlets **solo escriben objetos en Active Directory**. No abren SCM ni WMI contra el FSx, que es exactamente por lo que funcionan donde el wizard falla (§2). El servicio DFSR del FSx recoge esta configuración por su cuenta en el siguiente ciclo de polling.

**C.1 — Agregar el FSx como miembro del RG**

```powershell
Add-DfsrMember -GroupName $rg -ComputerName $fsx -Description "FSx intelisrcpa-prd (Single-AZ 1)"
```

**Qué hace:** crea un objeto `msDFSR-Member` bajo `CN=Topology` del RG, con un atributo `msDFSR-ComputerReference` que apunta al computer object del FSx.

Esto solo declara *"este servidor pertenece al grupo"*. Todavía no replica nada: no hay conexión ni carpeta asignada.

**Permiso que ejercita:** Full Control sobre `CN=Topology` (A.1).

**C.2 — Crear la conexión de replicación**

```powershell
Add-DfsrConnection -GroupName $rg -SourceComputerName $onprem -DestinationComputerName $fsx
```

**Qué hace:** crea los objetos `msDFSR-Connection` que definen la topología — qué miembro replica con cuál.

**Dirección:** por defecto **bidireccional**. El cmdlet crea dos objetos de conexión, uno por sentido. Para unidireccional estricto (solo on-prem → FSx) hay que agregar `-CreateOneWay`.

> Bidireccional implica que **las eliminaciones se propagan de vuelta**: si una aplicación en las EC2 borra una carpeta en el FSx, se borra también on-premises. Este es el riesgo operativo principal de la replicación multi-master, más que los conflictos de edición.

**C.3 — Configurar la membresía**

```powershell
Set-DfsrMembership -GroupName $rg -FolderName $rf -ComputerName $fsx `
  -ContentPath "D:\share\Datos" `
  -StagingPathQuotaInMB 16384 `
  -ConflictAndDeletedQuotaInMB 4096 `
  -PrimaryMember $false `
  -Force
```

**Qué hace:** crea los objetos *server-local* bajo el computer object del FSx (`DFSR-LocalSettings` → `msDFSR-Subscriber` → `msDFSR-Subscription`) y les escribe los atributos de configuración. Es el paso que le dice al FSx **qué carpeta replicar y cómo**.

**Permiso que ejercita:** Full Control sobre el computer object del FSx (A.2). Si falta, aquí aparece el error 1 de §8.

| Parámetro | Atributo AD | Qué hace |
|---|---|---|
| `-ContentPath "D:\share\Datos"` | `msDFSR-RootPath` | Ruta **local vista por el FSx**, no la UNC. Corresponde a `\\$fsx\share\Datos` |
| `-StagingPathQuotaInMB 16384` | `msDFSR-StagingSizeInMb` | Tamaño del área de staging. Ajustar con el valor de B.3; el default de 4096 rara vez alcanza |
| `-ConflictAndDeletedQuotaInMB 4096` | `msDFSR-ConflictSizeInMb` | Espacio para archivos perdedores de conflictos y borrados. Default: 660 MB |
| `-PrimaryMember $false` | — | **Crítico.** Declara que este miembro *no* es la fuente autoritativa |
| `-Force` | — | Suprime la confirmación interactiva |

**Por qué `-PrimaryMember $false` es crítico:** en la replicación inicial, el contenido del miembro primario gana. Como el FSx está vacío, marcarlo como primario haría que su vacío se propague y **borre los datos on-premises**. El primario debe seguir siendo el miembro que ya tiene los datos.

**Nota sobre las rutas:** `-ContentPath` usa la ruta del sistema de archivos tal como la ve el servicio DFSR corriendo dentro del FSx (`D:\share\Datos`), no la ruta de red con la que tú creaste la carpeta en B.1 (`\\$fsx\D$\share\Datos`). Ambas apuntan al mismo lugar.

Para membresía de solo lectura (si las EC2 únicamente leen), agregar `-ReadOnly $true`. Nota: que FSx acepte membresía read-only no está documentado por AWS — validar en el PoC.

### Fase D — Verificación

**D.1 — Objetos en AD** *(frontera de control: si esto pasa, la responsabilidad es del servicio gestionado)*

```powershell
Get-ADObject -SearchBase $fsxDn -Filter * -SearchScope Subtree | Select-Object Name, ObjectClass
```

**Qué hace:** enumera todo lo que cuelga del computer object del FSx en AD. `-SearchScope Subtree` recorre todos los niveles; `-Filter *` no descarta nada.

Debe aparecer: `DFSR-LocalSettings` → `msDFSR-Subscriber` → `msDFSR-Subscription`.

**Por qué este paso es la frontera:** si los tres objetos existen, todo lo que dependía de ti está hecho. De ahí en adelante el trabajo es del servicio DFSR corriendo dentro del FSx, que es código gestionado por AWS y no observable desde tu lado. Si falla después de este punto, el caso es de Soporte AWS (§9).

**D.2 — Eventos en el miembro on-premises** (esperar ~5 min; hasta 1 hora)

```powershell
Get-WinEvent -LogName "DFS Replication" -MaxEvents 30 |
  Format-Table TimeCreated, Id, Message -Wrap
```

**Qué hace:** lee el log de eventos `DFS Replication` **local** del file server on-premises.

**Por qué desde on-prem y no contra el FSx:** es el único miembro cuyos logs son accesibles. El FSx no expone su log de eventos. Como la replicación es una conversación entre ambos, el lado on-prem registra el estado de la conexión con el FSx — que es justo lo que necesitas saber.

**Por qué hay que esperar:** no existe forma de forzar el refresco (`Update-DfsrConfigurationFromAD` requiere WMI contra el FSx, ver §2). El servicio DFSR consulta AD por su cuenta cada ~5 minutos.

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

**Qué hace:** cuenta archivos y suma bytes en el destino, por SMB.

**Por qué importa:** es la única verificación que no depende de WMI ni de admin local. Comparar este resultado contra el de B.3 te dice el avance real. Si el número crece entre ejecuciones, está replicando — sin importar lo que digan (o dejen de decir) los cmdlets de diagnóstico.

### Fase E — Consumo desde las EC2

```powershell
net use Z: \\amznfsxXXXXXXXX.gdc.local\share\Datos /persistent:yes
```

**Qué hace:** mapea el share como unidad de red en la EC2. `/persistent:yes` mantiene el mapeo entre reinicios. Nótese que aquí se usa el share público `\share`, no el admin share `D$` de B.1.

Opcionalmente, publicar el share en el namespace existente para mantener el mismo UNC:

```powershell
New-DfsnFolderTarget -Path "\\gdc.local\<Namespace>\<Folder>" `
  -TargetPath "\\amznfsxXXXXXXXX.gdc.local\share\Datos" `
  -ReferralPriorityClass SiteCostNormal
```

**Qué hace:** agrega el share del FSx como *folder target* adicional de una carpeta del namespace DFS que ya existe. Las aplicaciones siguen usando el mismo UNC (`\\gdc.local\<Namespace>\<Folder>`) y DFS-N las dirige a un target u otro.

`-ReferralPriorityClass SiteCostNormal` hace que la selección de target siga el costo de sitio de AD: cada cliente va al target de su propio sitio. Así las EC2 llegan al FSx y los clientes on-premises al file server local, sin cambiar nada en las aplicaciones.

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
