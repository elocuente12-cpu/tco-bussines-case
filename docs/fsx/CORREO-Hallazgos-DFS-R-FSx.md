# Correo: Hallazgos integración DFS-R con FSx for Windows — InteliSrcPA

---

**Para:** Equipo de Infraestructura / Seguridad de Red / Active Directory
**De:** [Tu nombre]
**Asunto:** Hallazgos y requerimientos pendientes — Integración DFS-R con FSx for Windows (InteliSrcPA)

---

Equipo,

Comparto los hallazgos del laboratorio controlado que montamos en AWS para validar la integración de FSx for Windows con DFS-R. El laboratorio replica las condiciones del entorno productivo (directorio activo con cuentas delegadas, OUs separadas, security groups segmentados) y nos permitió identificar con precisión los dos bloqueantes que tenemos actualmente.

---

## 1. Hallazgo de Active Directory — Permisos insuficientes

### Situación actual

La cuenta operativa (`C91582B-A`) que ejecuta la configuración DFS-R es miembro del grupo `ADMIN GDC DFS Management`. Sin embargo, al intentar ejecutar `Set-DfsrMembership` (el paso que configura la carpeta replicada en el FSx), obtenemos el error:

> *"Security cannot be set on the replicated folder. Access is denied"*

### Causa raíz (validada en laboratorio)

El grupo `ADMIN GDC DFS Management` necesita **dos permisos** que actualmente no tiene (o están incompletos):

| # | Permiso requerido | Sobre qué objeto | Estado actual |
|---|-------------------|-------------------|---------------|
| 1 | **Delegación DFS-R** (`Grant-DfsrDelegation`) | Replication Group `APXEXPERIAN` | ⚠️ Se ejecutó pero no se propagó correctamente entre DCs |
| 2 | **Full Control con herencia** (`GenericAll`, `InheritanceType = All`) | Computer object del FSx (`CN=AMZNFSXEZE56TBV`) | ⚠️ Existe con `InheritanceType = Descendents` pero falta con scope `All` (objeto + descendientes) |

### Acción requerida (ejecución única, como Domain Admin)

```powershell
# Permiso 1: Delegación sobre el Replication Group
Grant-DfsrDelegation -GroupName "APXEXPERIAN" -AccountName "GDC\ADMIN GDC DFS Management" -Force

# Permiso 2: Full Control (This object and all descendants) sobre el computer object del FSx
$fsxDn = "CN=AMZNFSXEZE56TBV,OU=FSx,OU=Windows,OU=AWS,OU=ExperianExpressCloud,OU=Servers,OU=Systems,DC=gdc,DC=local"
$grupo = "GDC\ADMIN GDC DFS Management"
$sid   = (New-Object System.Security.Principal.NTAccount($grupo)).Translate([System.Security.Principal.SecurityIdentifier])
$entry = [ADSI]"LDAP://$fsxDn"
$rule  = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
           $sid,
           [System.DirectoryServices.ActiveDirectoryRights]::GenericAll,
           [System.Security.AccessControl.AccessControlType]::Allow,
           [System.DirectoryServices.ActiveDirectorySecurityInheritance]::All)
$entry.ObjectSecurity.AddAccessRule($rule)
$entry.CommitChanges()
```

**Importante:** el `InheritanceType` debe ser `All` (no `None` ni `Descendents`). La diferencia es que `Set-DfsrMembership` crea objetos **hijos** del computer object del FSx (`DFSR-LocalSettings` → Subscriber → Subscription), y sin herencia completa no puede escribir en ellos.

---

## 2. Hallazgo de Red — Tráfico bidireccional requerido

### Situación actual

DFS-R usa RPC (puertos 135 + 49152-65535) para la replicación. Actualmente tenemos reglas de Security Group en AWS que permiten tráfico **entrante** al FSx desde los servidores on-premise. Sin embargo, la replicación no inicia y el evento de error es:

> *"The DFS Replication service is stopping communication with partner. Error: 1726 (The remote procedure call failed.)"*

### Causa raíz (validada en laboratorio)

DFS-R es **bidireccional a nivel de red**: el FSx también inicia conexiones RPC **hacia** los servidores on-premise. No basta con abrir reglas en el Security Group del FSx — también se requiere que el **firewall on-premise** permita tráfico entrante desde las IPs del FSx.

### Flujo de red requerido

```
Servidor On-Premise → FSx (puertos 135, 445, 49152-65535)  ← YA CONFIGURADO en AWS SG
FSx → Servidor On-Premise (puertos 135, 49152-65535)       ← FALTA en firewall on-premise
```

### Acción requerida (equipo de red/firewall)

Permitir tráfico **entrante** en el firewall on-premise:

| Origen (Source) | Destino | Puertos | Protocolo | Motivo |
|-----------------|---------|---------|-----------|--------|
| ENIs del FSx (IPs del VPC AWS: `10.64.160.x/26`) | File servers DFS-R on-premise (`PAHWPAPTUI03`, `PAHWPAPTUI04`) | 135 | TCP | RPC Endpoint Mapper |
| ENIs del FSx (IPs del VPC AWS: `10.64.160.x/26`) | File servers DFS-R on-premise | 49152-65535 | TCP | RPC Dynamic Ports (DFS-R) |

Para obtener las IPs exactas de las ENIs del FSx:

```bash
aws fsx describe-file-systems --query "FileSystems[?Tags[?Key=='Name'&&Value=='intelisrcpa-prd']].NetworkInterfaceIds" --output json
aws ec2 describe-network-interfaces --network-interface-ids <eni-ids> --query "NetworkInterfaces[*].PrivateIpAddress"
```

---

## 3. Hallazgo adicional — `file_system_administrators_group`

El FSx actual tiene `file_system_administrators_group = "Domain Admins"`. Este grupo controla quién puede acceder a los admin shares (`\\FSx\D$\`) y crear carpetas destino para DFS-R.

Si ninguna cuenta operativa es miembro de `Domain Admins`, no se puede crear la carpeta destino en el FSx. Este valor **no es modificable después de la creación** del file system (limitación de la API de FSx for Windows).

**Opciones:**
- A) Agregar temporalmente la cuenta operativa a `Domain Admins` solo para crear la carpeta (un solo comando, una vez)
- B) Recrear el FSx con `file_system_administrators_group = "ADMIN GDC DFS Management"` (requiere destruir y recrear)

---

## Resumen de acciones solicitadas

| # | Equipo | Acción | Esfuerzo |
|---|--------|--------|----------|
| 1 | Active Directory | Ejecutar `Grant-DfsrDelegation` + Full Control sobre computer object FSx | 5 min (una vez) |
| 2 | Redes / Firewall | Abrir puertos 135 + 49152-65535 desde IPs del FSx hacia servidores on-prem | Según proceso de cambio |
| 3 | AD / FSx | Definir estrategia para `file_system_administrators_group` | Decisión |

---

## Evidencia del laboratorio

El laboratorio se desplegó en la cuenta `academia-pragma` (034034141479) con:
- AWS Managed AD (`lab.dfsr.local`)
- FSx SINGLE_AZ_1 con `self_managed_active_directory` y `file_system_administrators_group = "ADMIN GDC DFS Management"`
- EC2 Windows Server 2025 como miembro DFS-R
- Cuenta operativa (`operador-dfsr`) miembro de `ADMIN GDC DFS Management` — **sin** privilegios de Domain Admin

**Resultado:** replicación bidireccional funcionando correctamente con los permisos mínimos documentados arriba.

Quedo atento a coordinar la ejecución de las acciones.

Saludos,
[Tu nombre]
