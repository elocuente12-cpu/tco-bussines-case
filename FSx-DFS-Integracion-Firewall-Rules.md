# Integración Amazon FSx for Windows File Server con DFS On-Premise

## Resumen

Este documento describe los requisitos de red y reglas de firewall necesarias para integrar un Amazon FSx for Windows File Server (desplegado en AWS) con un DFS (Distributed File System) existente on-premise, en el contexto del proyecto InteliSrcPA.

**Ambiente:** STG (Staging)  
**Tipo de despliegue FSx:** Single-AZ 1  
**Active Directory:** Self-Managed (on-premise)  
**Conectividad AWS ↔ On-Premise:** Ya establecida (Direct Connect / VPN)

---

## Arquitectura de Integración

```
┌─────────────────────────────┐         ┌─────────────────────────────┐
│        AWS (VPC STG)        │         │         On-Premise          │
│                             │         │                             │
│  ┌───────────────────────┐  │         │  ┌───────────────────────┐  │
│  │  FSx for Windows      │  │◄───────►│  │  DFS Namespace Server │  │
│  │  File Server          │  │  Direct │  │  (File Server)        │  │
│  │                       │  │ Connect │  │                       │  │
│  │  - Joined to AD       │  │  / VPN  │  │  - DFS-N / DFS-R      │  │
│  │  - SG: sg_fsx         │  │         │  │  - Active Directory   │  │
│  └───────────────────────┘  │         │  └───────────────────────┘  │
│                             │         │                             │
│  ┌───────────────────────┐  │         │  ┌───────────────────────┐  │
│  │  Windows Instances    │  │         │  │  Domain Controllers   │  │
│  │  (App Servers)        │  │         │  │  + DNS Servers        │  │
│  └───────────────────────┘  │         │  └───────────────────────┘  │
└─────────────────────────────┘         └─────────────────────────────┘
```

---

## Reglas de Firewall Requeridas

### 1. FSx ↔ Active Directory Domain Controllers (On-Premise)

Estas reglas son necesarias para que el FSx se una y opere correctamente dentro del dominio de Active Directory. Deben estar abiertas **bidireccionalmente** en los firewalls on-premise.

| Protocolo | Puerto(s) | Función |
|-----------|-----------|---------|
| TCP/UDP | 53 | Domain Name System (DNS) |
| TCP/UDP | 88 | Kerberos Authentication |
| TCP/UDP | 464 | Kerberos Change/Set Password |
| TCP/UDP | 389 | Lightweight Directory Access Protocol (LDAP) |
| UDP | 123 | Network Time Protocol (NTP) |
| TCP | 135 | DCE/RPC Endpoint Mapper |
| TCP | 445 | Directory Services SMB file sharing |
| TCP | 636 | LDAPS (LDAP over TLS/SSL) |
| TCP | 3268 | Microsoft Global Catalog |
| TCP | 3269 | Microsoft Global Catalog over SSL |
| TCP | 5985 | WinRM 2.0 (Windows Remote Management) |
| TCP | 9389 | Microsoft AD DS Web Services / PowerShell |
| TCP | 49152–65535 | Puertos efímeros para RPC |
| ICMP | — | Health checks (recomendado por AWS) |

> **Importante:** AWS indica que FSx ignorará cualquier Domain Controller que tenga bloqueado TCP/UDP en el puerto 389.

**Fuente:** [Amazon FSx - Self-Managed AD Prerequisites](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/self-managed-AD.html)

---

### 2. FSx ↔ DFS Server On-Premise (DFS Namespaces / DFS-R)

Estas son las reglas **específicas** para la integración de DFS Namespaces y/o DFS Replication entre el file server on-premise y el FSx en AWS.

| Protocolo | Puerto(s) | Función | Dirección |
|-----------|-----------|---------|-----------|
| TCP | **445** | SMB — tráfico principal DFS (referrals + data) | Bidireccional |
| TCP | **135** | RPC Endpoint Mapper (negociación DFS-R) | Bidireccional |
| TCP | **49152–65535** | RPC Dynamic Ports (replicación DFS-R) | Bidireccional |
| TCP | **389** | LDAP (resolución de DFS Namespace targets) | Bidireccional |
| UDP | **389** | LDAP (resolución de DFS Namespace targets) | Bidireccional |
| TCP/UDP | **53** | DNS (resolución de nombres del FSx) | Bidireccional |

**Fuente:** [Amazon FSx - File System Access Control with VPC](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/limit-access-security-groups.html)

---

### 3. Resumen de Puertos Mínimos Críticos para DFS

Si se busca la configuración mínima para que DFS Namespaces funcione:

| Prioridad | Puerto | Protocolo | Justificación |
|-----------|--------|-----------|---------------|
| 🔴 Crítico | 445 | TCP | Sin este puerto no hay acceso SMB ni DFS referrals |
| 🔴 Crítico | 135 | TCP | Requerido para iniciar sesiones RPC (DFS-R) |
| 🔴 Crítico | 49152–65535 | TCP | Puertos dinámicos donde se ejecuta la replicación |
| 🟡 Importante | 389 | TCP/UDP | Resolución de namespace targets en DFS-N |
| 🟡 Importante | 53 | TCP/UDP | Resolución DNS del FSx |

---

## Consideraciones Importantes

### Bidireccionalidad
> "While Amazon VPC security groups require ports to be opened only in the direction that network traffic is initiated, most Windows firewalls and VPC network ACLs require ports to be open in **both directions**."
>
> — AWS Documentation

Esto significa que aunque el Security Group de AWS es stateful (la respuesta se permite automáticamente), en el **firewall on-premise** se deben abrir los puertos en ambas direcciones.

### Network ACLs
Si se utilizan NACLs en la VPC, recordar que son stateless y requieren reglas explícitas de entrada **y** salida, incluyendo los puertos efímeros (49152–65535) para respuestas.

### Active Directory Sites
AWS recomienda asegurarse de que las subnets de la VPC donde reside el FSx estén definidas en un Active Directory Site para optimizar la localización de Domain Controllers.

### DNS
Amazon FSx solo registra automáticamente los DNS records si se usa Microsoft DNS como servicio DNS por defecto. Si se utiliza un DNS de terceros, los registros deben crearse manualmente.

---

## Estado Actual del Security Group (`sg_fsx`) en STG

### Reglas activas (desde instancias Windows en AWS):
| Puerto | Protocolo | Origen | Estado |
|--------|-----------|--------|--------|
| 445 | TCP | sg_windows | ✅ Activo |
| 5985 | TCP | sg_windows | ✅ Activo |
| 135 | TCP | sg_windows | ✅ Activo |
| 49152–65535 | TCP | sg_windows | ✅ Activo |

### Reglas preparadas para DFS on-premise (comentadas):
| Puerto | Protocolo | Origen | Estado |
|--------|-----------|--------|--------|
| 445 | TCP | CIDR on-premise | 🔲 Comentado |
| 135 | TCP | CIDR on-premise | 🔲 Comentado |
| 49152–65535 | TCP | CIDR on-premise | 🔲 Comentado |
| 389 | TCP | CIDR on-premise | 🔲 Comentado |
| 389 | UDP | CIDR on-premise | 🔲 Comentado |

### Egress:
- Permitido todo el tráfico saliente (`0.0.0.0/0`) ✅

---

## Pasos para Habilitar la Integración

1. **Obtener el CIDR** del servidor DFS on-premise (o la subred donde reside).
2. **Descomentar las reglas** en `iac/repo/intelisrcpa/stg/securitygroups.tf`, reemplazando `10.x.x.x/24` con el CIDR real.
3. **Solicitar al equipo de networking on-premise** la apertura bidireccional de los puertos listados en la sección 2 en el firewall perimetral.
4. **Validar conectividad** usando el [Amazon FSx Active Directory Validation Tool](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/validate-ad-config.html).
5. **Configurar DFS Namespace** agregando el FSx como folder target en la consola de DFS Management.

---

## Referencias

- [Amazon FSx for Windows File Server - File System Access Control with VPC](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/limit-access-security-groups.html)
- [Amazon FSx - Using a Self-Managed Microsoft Active Directory](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/self-managed-AD.html)
- [Amazon FSx - Using DFS Namespaces](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/using-dfs-namespaces.html)
- [Microsoft - DFS Namespaces Overview](https://learn.microsoft.com/en-us/windows-server/storage/dfs-namespaces/dfs-overview)
- [Microsoft - DFS Replication Overview](https://learn.microsoft.com/en-us/windows-server/storage/dfs-replication/dfsr-overview)
