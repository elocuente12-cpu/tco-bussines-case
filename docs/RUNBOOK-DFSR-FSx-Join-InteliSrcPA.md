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

> **Este runbook lo ejecutan manos remotas.** Cada fase incluye su propio bloque de variables completo. **Pegar el bloque de variables de la fase al inicio de cada sesión de PowerShell** — las variables no sobreviven al cierre de la ventana ni al cambio de máquina.

### 5.0 — Valores y contexto de ejecución

**Valores confirmados** (ya verificados, no modificar):

| Variable | Valor | Origen |
|---|---|---|
| `$rg` | `APXEXPERIAN` | B.2 — State `Normal`, dominio `gdc.local` |
| `$rf` | `APC` | B.2 — `Get-DfsReplicatedFolder` |
| `$fsxHost` | `AMZNFSXEZE56TBV` | AWS |
| `$fsx` | `amznfsxeze56tbv.gdc.local` | AWS |
| `$fsxDn` | `CN=AMZNFSXEZE56TBV,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local` | AD |
| `$dom` | `DC=gdc,DC=local` | — |
| `$contentPath` | `D:\share\APC` | Elegido por consistencia con los otros 4 miembros (todos usan `APC`) |
| `$stagingMB` | `4096` | B.2 — valor en uso por los 4 miembros actuales |
| `$conflictMB` | `660` | Default DFSR |
| Cuenta operativa | `GDC\C91582B-A` | — |

**Miembros actuales del RG `APXEXPERIAN`** (B.2):

| Miembro | ContentPath | StagingQuota | PrimaryMember |
|---|---|---|---|
| PAHWPAPTUI03 | `E:\APC` | 4096 | False |
| PAHWPAPTUI04 | `D:\APC` | 4096 | False |
| PACLPAPTUI03 | `E:\APC` | 4096 | False |
| PACLPAPTUI04 | `E:\APC` | 4096 | False |

> `PrimaryMember = False` en los cuatro es lo esperado: DFSR limpia esa marca al completar la replicación inicial. Confirma que el RG está convergido, y refuerza que `-PrimaryMember $false` es correcto para el FSx.
>
> El `ContentPath` varía entre miembros (`D:` vs `E:`) — es una ruta **local de cada miembro**, no un identificador compartido. Por eso `D:\share\APC` en el FSx es válido y no hay que alinearlo.

**Valor pendiente de completar antes de entregar a manos remotas:**

| Variable | Qué es | Cómo decidirlo |
|---|---|---|
| `$onprem` | Miembro al que se conectará el FSx | Ver §5.1 — depende de topología y cobertura del Security Group |

---

### 5.1 — Decisión pendiente: a qué miembro conectar el FSx

El RG tiene **cuatro miembros**, presumiblemente en dos sitios (`PAHW*` y `PACL*` — datacenter principal y alterno de DR). El paso C.2 crea la conexión desde **un** miembro, y esa elección define la topología y el punto único de fallo hacia AWS.

**Dato bloqueante — cobertura del Security Group.** Las reglas de `terraform.tfvars:238` abren 135, 445 y 49152-65535 hacia el FSx solo desde tres IPs:

```
192.168.210.63    192.168.210.64    10.54.128.63
```

Hay cuatro miembros, así que al menos uno queda fuera. Además, las `.63/.64` tienen también reglas LDAP, lo que sugiere que podrían ser DCs y no file servers.

**Si `$onprem` no está entre esas tres IPs:** la configuración se escribe correctamente en AD, aparece el evento 4102, y luego **5002/5004/5008** — replicación bloqueada por firewall.

**Comandos para cerrar la decisión:**

```powershell
# Topologia actual de conexiones
Get-DfsrConnection -GroupName "APXEXPERIAN" |
  Format-Table SourceComputerName, DestinationComputerName, Enabled, RdcEnabled -AutoSize

# Mapeo miembro -> IP, para cruzar con las reglas del SG
"PAHWPAPTUI03","PAHWPAPTUI04","PACLPAPTUI03","PACLPAPTUI04" | ForEach-Object {
  [PSCustomObject]@{
    Miembro = $_
    IP = (Resolve-DnsName "$_.gdc.local" -Type A -ErrorAction SilentlyContinue).IPAddress -join ", "
  }
} | Format-Table -AutoSize
```

**Criterio de selección:** el miembro debe (a) tener su IP en las reglas del SG y (b) estar en el sitio con mejor conectividad hacia AWS. Si ninguno de los cuatro está cubierto, hay que agregar su IP a `sg_fsx_extra_ingress_rules` antes de la Fase C.

**Consideración de topología:** conectar el FSx a un solo miembro lo deja dependiente de ese servidor. Si el RG actual es full mesh, evaluar agregar una segunda conexión (repetir C.2 con otro miembro) para redundancia.

**Dónde se ejecuta cada fase:**

| Fase | Host | Cuenta | Requisitos del host |
|---|---|---|---|
| A — Delegaciones AD | File server on-prem (o cualquier host del dominio) | `GDC\C91582B-A` | Módulo `ActiveDirectory` + ADWS (TCP 9389) hacia un DC |
| B.1 — Crear carpeta | Cualquier host con SMB al FSx | **Domain Admins** | TCP 445 hacia el FSx |
| B.2–B.4 — Descubrimiento | **File server on-prem miembro del RG** | `GDC\C91582B-A` | RSAT DFS |
| C — Configuración | **File server on-prem miembro del RG** | `GDC\C91582B-A` | RSAT DFS |
| D — Verificación | **File server on-prem miembro del RG** | `GDC\C91582B-A` | RSAT DFS; D.1 requiere LDAP (389) |
| E — Consumo | EC2 Windows del VPC | Admin local de la EC2 | SMB al FSx |

**Estado de ejecución** (actualizar conforme se avanza):

| Paso | Estado |
|---|---|
| A.1 — Full Control en Topology del RG | ⬜ pendiente de verificar |
| A.2 — Full Control en computer object FSx | ✅ completado |
| A.3 — Propagar a AD | ⬜ pendiente |
| B.1 — Carpeta destino en FSx | ✅ completado |
| B.2 — Descubrimiento del RG | ✅ completado — `$rg`, `$rf`, `$stagingMB` obtenidos |
| B.3 — Dimensionamiento | ✅ **omitido con justificación** — ver nota |
| 5.1 — Elegir miembro origen | ✅ `PAHWPAPTUI03` — pendiente validar su IP contra el SG |
| B.4 — Limpiar residuos | ⚠️ omitido — el wizard había dejado miembro y conexiones (ver error 5) |
| C.1 — Agregar miembro | ✅ completado (lo había creado el wizard) |
| C.2 — Conexiones | ✅ completado — **bidireccional**, ambos sentidos `Enabled = True` |
| **C.3 — Membresía** | ⬜ **pendiente** — falló con *Access is denied*, ver error 5 |
| A.1b — `Grant-DfsrDelegation` | ⬜ **pendiente, desbloquea C.3** |
| B.1b — Crear `D:\share\APC` | ⬜ pendiente (B.1 creó `Datos`) |
| D.1 / D.2 / D.3 | ⬜ pendiente |

> **Estado real del miembro FSx:** existe en el RG con ambas conexiones activas, pero su membresía tiene **`ContentPath` vacío** — está en el grupo sin replicar nada. C.3 es lo único que falta.

> **Por qué se omite B.3:** los cuatro miembros actuales replican este dataset con `StagingPathQuotaInMB = 4096` de forma estable. Es evidencia operativa directa de que el default alcanza, superior al cálculo teórico de los 32 archivos mayores. Con ~20 GiB de datos: `20 + 4 + 0,65 = 24,6 GiB sobre 32 GiB = 77%` de ocupación. Cabe, sin margen de crecimiento.
>
> Confirmación opcional — verificar que los miembros actuales no estén sufriendo en silencio:
> ```powershell
> Get-WinEvent -LogName "DFS Replication" -MaxEvents 200 -ErrorAction SilentlyContinue |
>   Where-Object { $_.Id -in 4202,4204,4206,4208 } | Format-Table TimeCreated, Id -AutoSize
> ```
> Salida vacía = 4096 es sano. Con eventos = el default ya está corto y el FSx heredaría el problema.

---

> ⚠️ **El dominio `gdc.local` contiene ~30 file systems FSx** de distintos equipos, en al menos cinco OUs. Solo en la OU de este proyecto hay nueve. **Nunca resolver el computer object con un filtro tipo `Name -like "amznfsx*"`** — devuelve un array y rompe todo lo que dependa de él (§8, error 3). Por eso `$fsxDn` va con valor fijo.
>
> El nombre del computer object lo genera AWS al crear el file system; no se deriva de `fsx_name` ni del `FileSystemId`, y no está en el tfvars. **Si el file system se recrea, cambia y hay que actualizar §5.0.** Para re-obtenerlo:
> ```bash
> aws fsx describe-file-systems \
>   --query "FileSystems[?Tags[?Key=='Name'&&Value=='intelisrcpa-prd']].{Id:FileSystemId,DNS:DNSName}"
> ```

---

### Fase A — Delegaciones en Active Directory (una vez)

Esta fase no toca DFS-R: solo ajusta permisos en AD para que la cuenta pueda crear los objetos que DFS-R necesita.

**Bloque de variables — pegar al inicio de la sesión:**

```powershell
# ===== FASE A - VARIABLES =====
$rg      = "APXEXPERIAN"
$dom     = "DC=gdc,DC=local"
$fsxHost = "AMZNFSXEZE56TBV"
$fsx     = "amznfsxeze56tbv.gdc.local"
$fsxDn   = "CN=AMZNFSXEZE56TBV,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local"
$ouFsx   = "OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local"
$cuenta  = "GDC\C91582B-A"
$topoDn  = "CN=Topology,CN=$rg,CN=DFSR-GlobalSettings,CN=System,$dom"
# ==============================
```

> **A.1 requiere `$rg`.** Si aún no se ejecutó B.2, hacerlo primero y completar el valor arriba.

---

#### A.1 — Delegación sobre el replication group

> ⚠️ **Usar `Grant-DfsrDelegation`, no la ACL manual sobre Topology.** La versión original de este paso solo cubría `CN=Topology`, lo que permite agregar miembros y conexiones pero **no configurar membresías** — esas tocan `CN=Content`. El resultado es un `Set-DfsrMembership` que falla con *"Security cannot be set on the replicated folder. Access is denied"* (§8, error 5).

| | |
|---|---|
| **Ejecutar en** | File server on-prem |
| **Cuenta** | **Domain Admins** (una sola vez) |
| **Requiere** | `$rg` |
| **Estado** | ⬜ pendiente |

```powershell
$rg     = "APXEXPERIAN"
$cuenta = "GDC\C91582B-A"

# Estado actual
Get-DfsrDelegation -GroupName $rg | Format-Table AccountName, IsInherited -AutoSize

# Otorgar
Grant-DfsrDelegation -GroupName $rg -AccountName $cuenta -Force

# Confirmar
Get-DfsrDelegation -GroupName $rg |
  Where-Object AccountName -like "*C91582B-A*" |
  Format-Table AccountName, IsInherited -AutoSize
```

**Qué hace:** concede permiso para crear *replicated folders, connections, members y **memberships*** dentro del replication group — los cuatro tipos de objeto, en `CN=Content` y `CN=Topology` a la vez. Es el equivalente de *Delegate Management Permissions* en la GUI de DFS Management.

Según [Microsoft](https://learn.microsoft.com/en-us/powershell/module/dfsr/grant-dfsrdelegation), permite que administradores locales de los servidores DFSR gestionen la parte de AD DS de la topología sin ser Domain Admins.

**Resultado esperado:** la cuenta aparece en `Get-DfsrDelegation` con `IsInherited = False`.

Después, propagar (A.3).

---

<details>
<summary>Alternativa manual — ACL directa sobre los nodos del RG (solo si <code>Grant-DfsrDelegation</code> no está disponible)</summary>

Hay que aplicarla sobre **`CN=Topology` y `CN=Content`**, o sobre el objeto del RG completo con herencia. Otorgarla solo sobre Topology es lo que produce el error 5.

| | |
|---|---|
| **Ejecutar en** | File server on-prem |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | `$rg` completado; módulo `ActiveDirectory` con ADWS operativo |
| **Estado** | ⬜ pendiente de verificar |

Aplicar sobre el **objeto del RG completo**, para que la herencia cubra `Content` y `Topology` de una vez:

```powershell
$rgDn = "CN=$rg,CN=DFSR-GlobalSettings,CN=System,$dom"

# Verificar
(Get-Acl "AD:\$rgDn").Access |
  Where-Object { $_.IdentityReference -like "*C91582B-A*" -or $_.IdentityReference -like "*Domain Admins*" } |
  Format-Table IdentityReference, ActiveDirectoryRights, InheritanceType, IsInherited -AutoSize

# Otorgar
$sid = (New-Object System.Security.Principal.NTAccount($cuenta)).Translate(
         [System.Security.Principal.SecurityIdentifier])
$acl  = Get-Acl -Path "AD:\$rgDn"
$rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
          $sid,
          [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
          [System.Security.AccessControl.AccessControlType]::Allow,
          [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All)
$acl.AddAccessRule($rule); Set-Acl -Path "AD:\$rgDn" -AclObject $acl
```

**Estructura de los nodos del RG:**

```
CN=APXEXPERIAN,CN=DFSR-GlobalSettings,CN=System,DC=gdc,DC=local
  ├── CN=Content     -> msDFSR-ContentSet (una por replicated folder)  <- lo que necesita C.3
  └── CN=Topology    -> msDFSR-Member + msDFSR-Connection              <- lo que necesita C.1 y C.2
```

**Línea por línea:**

| Línea | Acción |
|---|---|
| `$sid = ...Translate(...)` | Convierte `GDC\usuario` a su SID. Las ACL de AD se escriben con SIDs, no nombres |
| `$acl = Get-Acl` | Descarga la ACL actual |
| `ActiveDirectoryAccessRule(...)` | Construye la regla de permiso |
| `GenericAll` | Equivale a **Full Control** |
| `AccessControlType::Allow` | Regla de permitir, no de denegar |
| `ActiveDirectorySecurityInheritance::All` | Aplica a este objeto **y todos los descendientes** — aquí es lo que hace que cubra `Content` y `Topology` |
| `$acl.AddAccessRule($rule)` | Agrega la regla **en memoria** |
| `Set-Acl` | Persiste en AD. Hasta aquí nada se había escrito |

</details>

---

#### A.2 — Full Control sobre el computer object del FSx

| | |
|---|---|
| **Ejecutar en** | File server on-prem |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | Módulo `ActiveDirectory` con ADWS operativo |
| **Estado** | ✅ **completado** — verificado con `GenericAll` / `InheritanceType = All` |

Se conserva por referencia y para reejecución si el file system se recrea.

```powershell
# Confirmar que la herencia de la OU no este bloqueada
(Get-Acl "AD:\$ouFsx").AreAccessRulesProtected

# Aplicar Full Control con propagacion a descendientes
$sid = (New-Object System.Security.Principal.NTAccount($cuenta)).Translate(
         [System.Security.Principal.SecurityIdentifier])
$acl  = Get-Acl -Path "AD:\$fsxDn"
$rule = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
          $sid,
          [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
          [System.Security.AccessControl.AccessControlType]::Allow,
          [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All)
$acl.AddAccessRule($rule); Set-Acl -Path "AD:\$fsxDn" -AclObject $acl
```

**Qué hace:** mismo patrón de A.1, aplicado al **computer object del FSx**. Es necesario porque los objetos `DFSR-LocalSettings` → `msDFSR-Subscriber` → `msDFSR-Subscription` se crean como **hijos del computer object del miembro** (§3). Sin este permiso aparece el error 1 de §8.

`AreAccessRulesProtected` responde: *¿esta OU tiene la herencia bloqueada?*

- `False` → hereda del padre; lo normal. **Valor confirmado en este entorno.**
- `True` → herencia bloqueada; los permisos heredados no aplican

**Verificar el resultado:**

```powershell
(Get-Acl "AD:\$fsxDn").Access |
  Where-Object { $_.IdentityReference -like "*C91582B-A*" } |
  Format-Table IdentityReference, ActiveDirectoryRights, InheritanceType, IsInherited -AutoSize
```

**Resultado esperado:** `GenericAll` con `InheritanceType = All` e `IsInherited = False`.

> `InheritanceType = None` significa que se aplicó como *"This object only"*: el permiso existe pero **no alcanza a los objetos hijos** que DFS-R debe crear. Es la causa exacta del error 1. En este entorno conviven dos ACEs (`None` del intento por GUI y `All` del correcto); AD hace unión de permisos, así que el `None` es redundante pero inofensivo.

**Vía GUI (ADUC):** View → **Advanced Features** → computer object → Properties → Security → Advanced → Add → **Applies to: "This object and all descendant objects"**. Dejarlo en *This object only* es el error más común.

---

#### A.3 — Propagar a AD y refrescar token

| | |
|---|---|
| **Ejecutar en** | File server on-prem |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | A.1 y/o A.2 aplicados |
| **Estado** | ⬜ pendiente |

```powershell
repadmin /syncall (Get-ADDomain).PDCEmulator /AdeP
```

**Sin el módulo `ActiveDirectory` disponible** (si ADWS está caído, ver §8 error 4):

```powershell
$pdc = (nltest /dsgetdc:gdc.local | Select-String "DC:").ToString().Split('\')[-1].Trim()
repadmin /syncall $pdc /AdeP
```

**Qué hace:** fuerza la replicación de AD hacia el PDC emulator para que el permiso recién escrito esté disponible ahí de inmediato, en vez de esperar el ciclo normal entre DCs.

Flags: `/A` todos los naming contexts, `/d` identifica servidores por DN, `/e` cruza sitios, `/P` empuja desde el servidor local.

**Por qué el PDC emulator:** las herramientas DFS se anclan a ese DC para leer y escribir la configuración DFSR. Si el permiso se otorgó contra otro DC y no replicó aún, los comandos siguen fallando aunque el permiso "ya esté puesto".

> **Si se cambió membresía de grupo, cerrar sesión y volver a entrar.** El token de Kerberos se emite al iniciar sesión y arrastra los grupos de ese momento. Ningún `repadmin` lo actualiza.

---

### Fase B — Preparación

**Bloque de variables — pegar al inicio de la sesión:**

```powershell
# ===== FASE B - VARIABLES =====
$fsx         = "amznfsxeze56tbv.gdc.local"
$contentPath = "D:\share\APC"
$uncAdmin    = "\\$fsx\D`$\share\APC"     # admin share D$ (backtick escapa el $)
$uncShare    = "\\$fsx\share\APC"          # share publico
$rutaOrigen  = "PENDIENTE_RUTA_LOCAL_DEL_REPLICATED_FOLDER_ONPREM"
# ==============================
```

---

#### B.1 — Crear la carpeta destino en el FSx

| | |
|---|---|
| **Ejecutar en** | Cualquier host con SMB 445 al FSx |
| **Cuenta** | **Domain Admins** (obligatorio) |
| **Requiere** | Resolución DNS de `amznfsxeze56tbv.gdc.local` |
| **Estado** | ✅ **completado** |

```powershell
New-Item -Type Directory -Path $uncAdmin
Get-ChildItem "\\$fsx\D`$\share\"
```

**Qué hace:** crea por SMB la carpeta que será el replicated folder.

`D$` es el **admin share** del volumen D: del file system. FSx expone el share visible `\share`, que internamente es `D:\share`. Se usa `D$` porque en C.3 hay que declarar la **ruta local vista por el miembro** (`D:\share\APC`), y esta notación deja explícita la correspondencia.

**Por qué exige `Domain Admins`:** acceder a un admin share requiere privilegios administrativos sobre el file system, y en FSx eso lo define `file_system_administrators_group`, que en este despliegue es `Domain Admins` (§4).

**Si falla con *access denied*:** la cuenta no está en ese grupo. No es problema de red — que `telnet` al 445 conecte solo prueba que el puerto está abierto, no que haya permisos.

> ⚠️ **No modificar las ACL NTFS del usuario `SYSTEM`** sobre esta carpeta. AWS advierte que `SYSTEM` requiere Full control en toda carpeta con share, y alterarlo puede dejar el file system inaccesible y los backups inutilizables.

---

#### B.2 — Descubrimiento del replication group

| | |
|---|---|
| **Ejecutar en** | **File server on-prem miembro del RG** |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | RSAT DFS (`Install-WindowsFeature RSAT-DFS-Mgmt-Con`) |
| **Estado** | ⬜ pendiente — **bloquea A.1 y toda la Fase C** |

```powershell
Get-DfsReplicationGroup | Format-Table GroupName, DomainName, State -AutoSize
Get-DfsReplicatedFolder  | Format-Table GroupName, FolderName, DfsnPath -AutoSize
Get-DfsrMember           | Format-Table GroupName, ComputerName, DomainName -AutoSize
Get-DfsrMembership       | Format-Table GroupName, ComputerName, ContentPath, StagingPath, StagingPathQuotaInMB, PrimaryMember -AutoSize
```

**Qué hace:** fotografía del RG antes de tocarlo. Son cuatro niveles distintos:

| Cmdlet | Devuelve | Para qué sirve aquí |
|---|---|---|
| `Get-DfsReplicationGroup` | El grupo en sí | Confirmar que `DomainName` es `gdc.local`; obtener `$rg` |
| `Get-DfsReplicatedFolder` | Las carpetas replicadas | Obtener `$rf` |
| `Get-DfsrMember` | Los servidores que participan | Obtener `$onprem`; detectar residuos de intentos previos |
| `Get-DfsrMembership` | La relación miembro ↔ carpeta | Es donde viven `ContentPath`, `StagingPath` y las cuotas |

> **Nota:** el cmdlet es `Get-DfsReplicatedFolder` (sin la `r` de `Dfsr`), a diferencia de `Get-DfsrMember`. El módulo es inconsistente en el naming.

**Estos cmdlets no dependen de ADWS** — van por LDAP/RPC directo. Funcionan aunque `Get-ADComputer` falle (§8, error 4).

**Qué anotar en la tabla de §5.0:**

- `$rg` ← columna `GroupName`
- `$rf` ← columna `FolderName`
- `$onprem` ← columna `ComputerName` del miembro existente
- El `StagingPathQuotaInMB` del miembro on-prem (se replica ese valor o mayor en C.3)
- Cuál miembro tiene `PrimaryMember = True`

---

#### B.3 — Dimensionamiento

| | |
|---|---|
| **Ejecutar en** | File server on-prem |
| **Cuenta** | Cualquiera con lectura sobre el replicated folder |
| **Requiere** | `$rutaOrigen` completado desde B.2 (`ContentPath` del miembro on-prem) |
| **Estado** | ⬜ pendiente — **gate obligatorio, ver §7** |

```powershell
# Tamano total del dataset
Get-ChildItem $rutaOrigen -Recurse -File |
  Measure-Object -Property Length -Sum |
  Select-Object Count, @{n='GB';e={[math]::Round($_.Sum/1GB,2)}}

# Suma de los 32 archivos mas grandes -> staging quota minimo
Get-ChildItem $rutaOrigen -Recurse -File |
  Sort-Object Length -Descending | Select-Object -First 32 |
  Measure-Object -Property Length -Sum |
  ForEach-Object { [math]::Round($_.Sum/1GB,2) }
```

**Qué hace el primero:** recorre recursivamente la carpeta origen y suma el tamaño de todos los archivos. `-File` excluye directorios para no contar dos veces.

**Qué hace el segundo:** ordena de mayor a menor, toma los 32 primeros y suma. Ese número es el **mínimo de staging quota** según la regla de Microsoft.

**Por qué 32 archivos:** DFSR usa el staging como área intermedia donde prepara los archivos antes de transmitirlos. Si la cuota no alcanza para los archivos más grandes en vuelo simultáneo, DFSR entra en un ciclo de limpieza y reintento que se manifiesta como backlog permanente (eventos 4202/4204).

**Criterio de aprobación:**

```
dataset_GB + staging_GB + 4 GB (conflict)  <  32 GiB
```

**Si no cumple: DETENERSE.** Hay que aumentar `fsx_storage_capacity` antes de continuar (§7).

Completar en §5.0: `$stagingMB` = suma de los 32 mayores en MB, redondeado hacia arriba.

---

#### B.4 — Limpiar residuos de intentos previos

| | |
|---|---|
| **Ejecutar en** | File server on-prem |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | `$rg` completado desde B.2 |
| **Estado** | ⬜ pendiente |

```powershell
$rg  = "COMPLETAR_DESDE_B2"
$fsx = "amznfsxeze56tbv.gdc.local"

Get-DfsrMember -GroupName $rg | Format-Table ComputerName -AutoSize

if (Get-DfsrMember -GroupName $rg | Where-Object ComputerName -like "*AMZNFSXEZE56TBV*") {
    Remove-DfsrMember -GroupName $rg -ComputerName $fsx -Force
    Write-Host "Residuo eliminado" -ForegroundColor Yellow
} else {
    Write-Host "Sin residuos, continuar" -ForegroundColor Green
}
```

**Qué hace:** si el FSx ya figura como miembro del RG, lo elimina antes de reintentar.

**Por qué es necesario:** el wizard de DFS Management aborta a mitad de camino (§8, error 2) y puede dejar un `msDFSR-Member` creado sin su suscripción. Ese estado a medias hace que `Add-DfsrMember` falle con *"already exists"*.

`-Force` suprime la confirmación. **Solo borra objetos de AD del miembro FSx: no toca al miembro on-premises ni sus datos.**

---

### Fase C — Configuración

Los tres cmdlets **solo escriben objetos en Active Directory**. No abren SCM ni WMI contra el FSx, que es exactamente por lo que funcionan donde el wizard falla (§2). El servicio DFSR del FSx recoge esta configuración por su cuenta en el siguiente ciclo de polling (~5 min, hasta 1 hora).

**Bloque de variables — pegar al inicio de la sesión:**

```powershell
# ===== FASE C - VARIABLES =====
$rg          = "APXEXPERIAN"
$rf          = "APC"
$onprem      = "COMPLETAR_SEGUN_5.1"      # uno de: PAHWPAPTUI03/04, PACLPAPTUI03/04
$fsx         = "amznfsxeze56tbv.gdc.local"
$contentPath = "D:\share\APC"
$stagingMB   = 4096       # validado: los 4 miembros actuales usan este valor
$conflictMB  = 660        # default de DFSR
# ==============================

# Validacion previa - no continuar si falta elegir el miembro origen
if ($onprem -like "COMPLETAR*") {
    throw "Falta definir el miembro origen. Ver seccion 5.1 (topologia + cobertura del Security Group)."
}

# Validacion de capacidad - dataset + staging + conflict debe caber en el file system
$capacidadGiB = 32                          # actualizar si se aumenta fsx_storage_capacity
$datasetGiB   = 20                          # resultado de B.3
$totalGiB = $datasetGiB + ($stagingMB/1024) + ($conflictMB/1024)
if ($totalGiB -gt ($capacidadGiB * 0.85)) {
    throw "No cabe: $([math]::Round($totalGiB,1)) GiB requeridos sobre $capacidadGiB GiB (limite 85%). Aumentar fsx_storage_capacity."
}
Write-Host "Capacidad OK: $([math]::Round($totalGiB,1)) de $capacidadGiB GiB" -ForegroundColor Green
```

**Dimensionamiento con el dataset actual (~20 GiB) sobre 32 GiB:**

| `$stagingMB` | Total ocupado | % del volumen | Veredicto |
|---|---|---|---|
| 4096 (4 GiB) | 24,6 GiB | 77% | Cabe, sin margen de crecimiento |
| 8192 (8 GiB) | 28,6 GiB | 90% | Demasiado justo |
| 16384 (16 GiB) | 36,6 GiB | **>100%** | **No cabe** |

`$stagingMB` debe ser ≥ la suma de los 32 archivos más grandes (resultado de B.3). Si ese número supera 4 GiB, **no se puede continuar a 32 GiB de capacidad** — hay que aumentar `fsx_storage_capacity` primero (§7).

---

#### C.1 — Agregar el FSx como miembro del RG

| | |
|---|---|
| **Ejecutar en** | **File server on-prem miembro del RG** |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | A.1 (Full Control en Topology) + B.4 |
| **Estado** | ⬜ pendiente |

```powershell
Add-DfsrMember -GroupName $rg -ComputerName $fsx -Description "FSx intelisrcpa-prd (Single-AZ 1)"
```

**Qué hace:** crea un objeto `msDFSR-Member` bajo `CN=Topology` del RG, con un atributo `msDFSR-ComputerReference` que apunta al computer object del FSx.

Esto solo declara *"este servidor pertenece al grupo"*. Todavía no replica nada: no hay conexión ni carpeta asignada.

**Permiso que ejercita:** Full Control sobre `CN=Topology` (A.1).

**Si falla por permisos:** el problema está en A.1, no en A.2.

---

#### C.2 — Crear la conexión de replicación

| | |
|---|---|
| **Ejecutar en** | **File server on-prem miembro del RG** |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | C.1 completado |
| **Estado** | ⬜ pendiente |

```powershell
Add-DfsrConnection -GroupName $rg -SourceComputerName $onprem -DestinationComputerName $fsx
```

**Qué hace:** crea los objetos `msDFSR-Connection` que definen la topología — qué miembro replica con cuál.

**Dirección:** por defecto **bidireccional**. El cmdlet crea dos objetos de conexión, uno por sentido. Para unidireccional estricto (solo on-prem → FSx) agregar `-CreateOneWay`.

> Bidireccional implica que **las eliminaciones se propagan de vuelta**: si una aplicación en las EC2 borra una carpeta en el FSx, se borra también on-premises. Este es el riesgo operativo principal de la replicación multi-master, más que los conflictos de edición.

---

#### C.3 — Configurar la membresía

| | |
|---|---|
| **Ejecutar en** | **File server on-prem miembro del RG** |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | C.1 y C.2 completados; A.2 (Full Control en computer object FSx) |
| **Estado** | ⬜ pendiente |

```powershell
Set-DfsrMembership -GroupName $rg -FolderName $rf -ComputerName $fsx `
  -ContentPath $contentPath `
  -StagingPathQuotaInMB $stagingMB `
  -ConflictAndDeletedQuotaInMB $conflictMB `
  -PrimaryMember $false `
  -Force
```

**Qué hace:** crea los objetos *server-local* bajo el computer object del FSx (`DFSR-LocalSettings` → `msDFSR-Subscriber` → `msDFSR-Subscription`) y les escribe los atributos de configuración. Es el paso que le dice al FSx **qué carpeta replicar y cómo**.

**Permiso que ejercita:** Full Control sobre el computer object del FSx (A.2). Si falta, aquí aparece el error 1 de §8.

| Parámetro | Atributo AD | Qué hace |
|---|---|---|
| `-ContentPath "D:\share\APC"` | `msDFSR-RootPath` | Ruta **local vista por el FSx**, no la UNC. Corresponde a `\\amznfsxeze56tbv.gdc.local\share\APC` |
| `-StagingPathQuotaInMB` | `msDFSR-StagingSizeInMb` | Tamaño del área de staging. Usar el valor de B.3; el default de 4096 rara vez alcanza |
| `-ConflictAndDeletedQuotaInMB` | `msDFSR-ConflictSizeInMb` | Espacio para archivos perdedores de conflictos y borrados. Default: 660 MB |
| `-PrimaryMember $false` | — | **Crítico.** Declara que este miembro *no* es la fuente autoritativa |
| `-Force` | — | Suprime la confirmación interactiva |

> **Por qué `-PrimaryMember $false` es crítico:** en la replicación inicial, el contenido del miembro primario gana. Como el FSx está vacío, marcarlo como primario haría que su vacío se propague y **borre los datos on-premises**. El primario debe seguir siendo el miembro que ya tiene los datos.

**Nota sobre las rutas:** `-ContentPath` usa la ruta del sistema de archivos tal como la ve el servicio DFSR dentro del FSx (`D:\share\APC`), no la UNC con la que se creó la carpeta en B.1 (`\\...\D$\share\APC`). Ambas apuntan al mismo lugar.

Para membresía de solo lectura (si las EC2 únicamente leen), agregar `-ReadOnly $true`. Que FSx acepte membresía read-only no está documentado por AWS — validar en el PoC.

---

### Fase D — Verificación

**Bloque de variables — pegar al inicio de la sesión:**

```powershell
# ===== FASE D - VARIABLES =====
$fsx      = "amznfsxeze56tbv.gdc.local"
$fsxDn    = "CN=AMZNFSXEZE56TBV,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local"
$uncShare = "\\$fsx\share\APC"
# ==============================
```

---

#### D.1 — Objetos en Active Directory

| | |
|---|---|
| **Ejecutar en** | File server on-prem |
| **Cuenta** | `GDC\C91582B-A` |
| **Requiere** | Fase C completada; esperar ~5 min |
| **Estado** | ⬜ pendiente |

**Con el módulo `ActiveDirectory` (requiere ADWS / TCP 9389):**

```powershell
Get-ADObject -SearchBase $fsxDn -Filter * -SearchScope Subtree | Select-Object Name, ObjectClass
```

**Sin ADWS — por LDAP puro (TCP 389), siempre funciona:**

```powershell
$entry    = [ADSI]"LDAP://$fsxDn"
$searcher = New-Object System.DirectoryServices.DirectorySearcher($entry)
$searcher.Filter      = "(objectClass=*)"
$searcher.SearchScope = "Subtree"
$searcher.FindAll() | ForEach-Object { $_.Path }
```

**Qué hace:** enumera todo lo que cuelga del computer object del FSx en AD.

**Resultado esperado:** `DFSR-LocalSettings` → `msDFSR-Subscriber` → `msDFSR-Subscription`.

> **Por qué este paso es la frontera de responsabilidad:** si los tres objetos existen, todo lo que dependía de nosotros está hecho. De ahí en adelante el trabajo lo hace el servicio DFSR dentro del FSx, que es código gestionado por AWS y no observable desde fuera. Si falla después de este punto, el caso es de Soporte AWS (§9).

---

#### D.2 — Eventos en el miembro on-premises

| | |
|---|---|
| **Ejecutar en** | **File server on-prem** (log local) |
| **Cuenta** | Admin local o `Event Log Readers` |
| **Requiere** | D.1 confirmado; esperar 5 min a 1 hora |
| **Estado** | ⬜ pendiente |

```powershell
Get-WinEvent -LogName "DFS Replication" -MaxEvents 30 |
  Format-Table TimeCreated, Id, Message -Wrap
```

**Filtrar solo los eventos relevantes:**

```powershell
Get-WinEvent -LogName "DFS Replication" -MaxEvents 100 |
  Where-Object { $_.Id -in 4102,4104,4202,4204,4302,4304,5002,5004,5008 } |
  Format-Table TimeCreated, Id, Message -Wrap
```

**Qué hace:** lee el log de eventos `DFS Replication` **local** del file server on-premises.

**Por qué desde on-prem y no contra el FSx:** es el único miembro cuyos logs son accesibles — el FSx no expone su log de eventos. Como la replicación es una conversación entre ambos, el lado on-prem registra el estado de la conexión con el FSx.

**Por qué hay que esperar:** no existe forma de forzar el refresco (`Update-DfsrConfigurationFromAD` requiere WMI contra el FSx, §2). El servicio DFSR consulta AD por su cuenta cada ~5 minutos.

| Evento | Significado | Acción |
|---|---|---|
| **4102** | Replicación inicial iniciada | ✅ la configuración llegó al FSx |
| **4104** | Replicación inicial completada | ✅ listo, habilitar escrituras |
| 4202 / 4204 | Staging quota excedida | Subir `-StagingPathQuotaInMB` |
| 4302 / 4304 | Archivos atascados | Revisar locks / archivos en uso |
| 5002 / 5004 / 5008 | Fallo de conexión | Firewall on-prem: RPC 49152-65535 desde las ENI del FSx |

> **Punto de decisión:** si tras **una hora** D.1 muestra los tres objetos pero no aparece el evento 4102, el servicio DFSR del FSx no está procesando la suscripción. Abrir caso con Soporte AWS (§9).

---

#### D.3 — Verificación por contenido

| | |
|---|---|
| **Ejecutar en** | Cualquier host con SMB al FSx |
| **Cuenta** | Con lectura sobre el share |
| **Requiere** | Evento 4102 visto |
| **Estado** | ⬜ pendiente |

```powershell
Get-ChildItem $uncShare -Recurse -File | Measure-Object -Property Length -Sum |
  Select-Object Count, @{n='GB';e={[math]::Round($_.Sum/1GB,2)}}
```

**Qué hace:** cuenta archivos y suma bytes en el destino, por SMB.

**Por qué importa:** es la única verificación que no depende de WMI ni de admin local. Comparar contra el resultado de B.3 indica el avance real. **Si el número crece entre ejecuciones, está replicando** — sin importar lo que digan (o dejen de decir) los cmdlets de diagnóstico.

> No usar `Get-DfsrBacklog`, `dfsrdiag` ni `Write-DfsrHealthReport` contra el FSx: requieren WMI o admin local del miembro y van a fallar. **Su fallo no indica que la replicación esté rota** (§2).

---

### Fase E — Consumo desde las EC2

| | |
|---|---|
| **Ejecutar en** | EC2 Windows del VPC |
| **Cuenta** | Admin local de la EC2 |
| **Requiere** | **Evento 4104 confirmado** |
| **Estado** | ⬜ pendiente |

```powershell
net use Z: \\amznfsxeze56tbv.gdc.local\share\APC /persistent:yes
```

**Qué hace:** mapea el share como unidad de red. `/persistent:yes` mantiene el mapeo entre reinicios. Aquí se usa el share público `\share`, no el admin share `D$` de B.1.

**Opcional — publicar en el namespace existente** para mantener el mismo UNC que on-premises:

```powershell
New-DfsnFolderTarget -Path "\\gdc.local\<Namespace>\<Folder>" `
  -TargetPath "\\amznfsxeze56tbv.gdc.local\share\APC" `
  -ReferralPriorityClass SiteCostNormal
```

**Qué hace:** agrega el share del FSx como *folder target* adicional de una carpeta del namespace DFS existente. Las aplicaciones siguen usando el mismo UNC y DFS-N las dirige a un target u otro.

`-ReferralPriorityClass SiteCostNormal` hace que la selección siga el costo de sitio de AD: cada cliente va al target de su propio sitio. Así las EC2 llegan al FSx y los clientes on-premises al file server local, sin cambiar nada en las aplicaciones.

> ⚠️ **No permitir escrituras desde las EC2 hasta ver el evento 4104.** Con replicación bidireccional, escribir durante la sincronización inicial genera conflictos evitables.

---

## 6. Rollback

| | |
|---|---|
| **Ejecutar en** | File server on-prem miembro del RG |
| **Cuenta** | `GDC\C91582B-A` |

```powershell
# ===== ROLLBACK - VARIABLES =====
$rg  = "COMPLETAR_DESDE_B2"
$fsx = "amznfsxeze56tbv.gdc.local"
# ================================

Remove-DfsrMember -GroupName $rg -ComputerName $fsx -Force

# Verificar que el FSx ya no figura
Get-DfsrMember -GroupName $rg | Format-Table ComputerName -AutoSize
```

Saca el FSx del RG **sin tocar el miembro on-premises ni sus datos**. Los datos ya replicados quedan en el FSx sin sincronizar.

Limpieza posterior de la carpeta interna de DFSR (requiere `Domain Admins`):

```powershell
Remove-Item "\\amznfsxeze56tbv.gdc.local\D`$\share\APC\DfsrPrivate" -Recurse -Force
```

---

## 7. Riesgo abierto: capacidad de 32 GiB

`fsx_storage_capacity = 32` es el mínimo absoluto de FSx SSD y aparenta ser un valor por defecto sin dimensionar. Ese volumen debe alojar simultáneamente:

| Componente | Tamaño |
|---|---|
| Datos replicados | **~20 GiB** (dato aportado por el equipo, pendiente de confirmar con B.3) |
| Staging (`DfsrPrivate`) | default 4 GiB = **12,5% del volumen**; requerido ≥ suma de los 32 archivos más grandes |
| `ConflictAndDeleted` | default 660 MB (configurable) |
| `PreExisting` | solo si hubo pre-seeding con hashes no coincidentes — no aplica, no se hace pre-seeding |

**Situación con 20 GiB de datos:** 20 + 4 (staging default) + 0,65 (conflict default) = **24,6 GiB, el 77% del volumen**. Cabe, pero sin margen de crecimiento y asumiendo que el staging por defecto alcanza.

Si el staging queda corto, DFSR entra en backlog permanente (eventos 4202/4204). La capacidad se puede aumentar en caliente, pero **no se puede reducir**.

### Recomendación: aumentar a 64 GiB antes de arrancar

| | 32 GiB | 64 GiB |
|---|---|---|
| Ocupación con 20 GiB de datos | 77% | 38% |
| Margen para staging holgado | No | Sí |
| Margen de crecimiento del share | Nulo | ~30 GiB |
| SSD IOPS por defecto (3/GiB) | ~96 | ~192 |
| Costo adicional (SSD, us-east-1 ~$0,13/GB-mes) | — | **~$4/mes** |

**Restricciones del aumento** ([Increasing storage capacity](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/increase-storage-capacity.html)): mínimo 10% por operación, online y sin downtime, hasta 65.536 GiB. De 32 a 64 es un solo salto válido.

**Opción A — vía IaC (preferida):** `fsx_storage_capacity = 64` en `terraform.tfvars:675` y aplicar. Requiere resolver antes el bloqueador de abajo.

**Opción B — vía CLI (desbloquea de inmediato, genera drift):**

```bash
aws fsx update-file-system --file-system-id fs-XXXXXXXX --storage-capacity 64
aws fsx describe-file-systems --file-system-id fs-XXXXXXXX \
  --query "FileSystems[0].AdministrativeActions"
```

Si se usa B, **reflejar el 64 en tfvars después**: el próximo apply intentaría bajarlo a 32 y fallaría, porque FSx no permite reducir capacidad.

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

### Error 3 — Resolución ambigua del computer object

```
Get-Acl : Cannot find path 'AD:\CN=AMZNFSX03TTJZMW,OU=AWS FSX Servers,OU=Servers,OU=Systems,DC=gdc,DC=local
CN=amznfsx0i5lbxmu,OU=FSx,OU=Windows,... CN=amznfsx26oislzq,OU=FSx,OU=Windows,... [~30 DNs concatenados]'
because it does not exist.

You cannot call a method on a null-valued expression.
+ $acl.AddAccessRule($rule); Set-Acl -Path "AD:\$fsxDn" -AclObject $acl

Set-Acl : Cannot bind argument to parameter 'AclObject' because it is null.
```

**Causa:** `$fsxDn` se resolvió con un filtro amplio:

```powershell
# INCORRECTO
$fsxDn = (Get-ADComputer -Filter 'Name -like "amznfsx*"').DistinguishedName
```

El dominio `gdc.local` contiene **~30 file systems FSx** de distintos equipos. El filtro los matcheó todos y `$fsxDn` quedó como un **array**. Al interpolarlo en `"AD:\$fsxDn"`, PowerShell unió todos los elementos separados por espacios formando una ruta inexistente.

Los dos errores siguientes son cascada: `$acl` quedó `$null`, y `Set-Acl` no acepta un `AclObject` nulo.

**No se modificó nada en AD** — el fallo ocurre antes de cualquier escritura.

**Resolución:** identificar el file system por su DNS name en AWS y resolver el objeto con `-eq` más una guarda de conteo (ver sección Variables de §5).

**Riesgo asociado:** los FSx del dominio están repartidos en al menos cinco OUs, y solo en la OU de este proyecto hay nueve objetos. Otorgar Full Control sobre el objeto equivocado **no produce error**: simplemente no sirve, y el `Add-DfsrMember` posterior apuntaría a un file system de otro equipo. Siempre confirmar el DN antes de escribir.

**Diagnóstico rápido del inventario:**

```powershell
Get-ADComputer -Filter 'Name -like "amznfsx*"' |
  Select-Object Name, DistinguishedName |
  Sort-Object DistinguishedName | Format-Table -AutoSize
```

### Error 4 — Active Directory Web Services no disponible

```
Get-ADComputer : Unable to find a default server with Active Directory Web Services running.
    + CategoryInfo : ResourceUnavailable: (:) [Get-ADComputer], ADServerDownException
    + FullyQualifiedErrorId : ActiveDirectoryServer:1355
```

**Causa:** el módulo `ActiveDirectory` de PowerShell **no habla LDAP directamente**: usa **Active Directory Web Services (ADWS)**, que corre en los DCs sobre **TCP 9389** — el mismo puerto que la documentación de FSx lista como *"Microsoft AD DS Web Services, PowerShell"*.

El host no está alcanzando ADWS en ningún DC. En este entorno el error apareció en la **misma máquina** donde `Get-ADComputer` había funcionado antes, lo que apunta a caída del servicio en el DC o a que el descubrimiento automático cambió de DC.

**Qué queda afectado:** solo los cmdlets del módulo `ActiveDirectory` (`Get-ADComputer`, `Get-ADDomain`, `Get-ADObject`) y el PSDrive `AD:\` que usan A.1, A.2 y D.1.

**Qué NO queda afectado:** todos los cmdlets DFSR (`Get-DfsReplicationGroup`, `Get-DfsrMember`, `Get-DfsrMembership`, `Add-DfsrMember`, `Add-DfsrConnection`, `Set-DfsrMembership`) van por LDAP/RPC directo. **Las fases B.2–B.4 y toda la Fase C funcionan sin ADWS.**

**Diagnóstico:**

```powershell
nltest /dsgetdc:gdc.local                      # que DC eligio el descubrimiento
Test-NetConnection 10.5.214.247 -Port 9389     # DCs de domain_dns_ips
Test-NetConnection 10.8.18.167  -Port 9389
Test-NetConnection 192.168.210.63 -Port 9389   # DCs del segmento on-prem
Test-NetConnection 192.168.210.64 -Port 9389
```

**Resolución 1 — forzar un DC específico** en los cmdlets del módulo AD:

```powershell
Get-ADComputer -Filter "Name -eq 'AMZNFSXEZE56TBV'" -Server 10.5.214.247
```

**Resolución 2 — usar valores fijos.** El runbook ya trae `$fsxDn` y `$dom` con valor literal en §5.0, precisamente para no depender de ADWS.

**Resolución 3 — fallback por LDAP puro** para D.1 (ver el bloque ADSI en ese paso). Usa `System.DirectoryServices` sobre el puerto 389, sin ADWS.

> Este error también explica por qué `$dom = (Get-ADDomain).DistinguishedName` es frágil en este entorno. En §5.0 está fijado como `"DC=gdc,DC=local"`.

### Error 5 — Membresía rechazada por permisos sobre el nodo Content

Al ejecutar la Fase C completa aparecieron tres mensajes. Los dos primeros son benignos:

```
Add-DfsrMember : A computer with the specified name already exists and cannot be added.
Add-DfsrConnection : ... The connection already exists.
```

**Causa (1 y 2):** el wizard de DFS Management, que falló en el SCM (error 2), **alcanzó a escribir los objetos en AD antes de abortar** — esa validación ocurre después de la escritura. Quedaron el `msDFSR-Member` y ambas conexiones.

Es exactamente lo que B.4 previene. Se había omitido ese paso.

**No es un fallo:** verificado con `Get-DfsrConnection`, las dos conexiones existen en ambos sentidos y `Enabled = True`. C.1 y C.2 quedaron efectivamente completos, hechos por el wizard.

---

El tercer mensaje sí es bloqueante:

```
Set-DfsrMembership : Security cannot be set on the replicated folder. Access is denied
    + FullyQualifiedErrorId : DfsrCore.ThrowIfInconsistent
```

**Causa:** la delegación cubría solo `CN=Topology`. Configurar una **membresía** también toca el objeto de la carpeta replicada — `msDFSR-ContentSet`, bajo `CN=Content` — porque DFSR escribe ahí un descriptor de seguridad para el nuevo miembro.

[Microsoft separa explícitamente](https://learn.microsoft.com/en-us/troubleshoot/windows-server/networking/delegating-dfs-replication) las dos delegaciones:

| Operación | Nodo AD |
|---|---|
| Add/Remove/Modify **members and connections** | `CN=Topology` |
| Add/Remove/Modify **replicated folders** (incluye membresías) | `CN=Content` |

**Síntoma diagnóstico:** el miembro aparece en `Get-DfsrMembership` con **`ContentPath` vacío** mientras los demás miembros muestran su ruta. Está en el grupo pero sin replicar nada.

**Resolución:**

```powershell
Grant-DfsrDelegation -GroupName "APXEXPERIAN" -AccountName "GDC\C91582B-A" -Force
repadmin /syncall (Get-ADDomain).PDCEmulator /AdeP
```

Cubre los cuatro tipos de objeto del RG en una sola operación. Luego reejecutar **solo C.3** — C.1 y C.2 no deben repetirse.

**Defecto corregido en el runbook:** A.1 pasó de aplicar una ACL manual sobre `CN=Topology` a usar `Grant-DfsrDelegation` sobre el RG completo.

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
