# Decisión de Arquitectura: DFS + Amazon FSx — Estrategia de DR para InteliSrcPA PRD

## Contexto

Los servidores Windows de producción de InteliSrcPA utilizan **DFS (Distributed File System)** para sincronizar archivos entre el datacenter principal y un datacenter alterno que funciona como DR (Disaster Recovery).

Con la migración del datacenter principal a AWS, se requiere definir cómo se integra el almacenamiento compartido en la nube con el mecanismo de replicación DFS-R que el equipo de operaciones ya opera.

### Premisas

- El equipo de operaciones ya conoce y administra DFS-R y DFS Namespaces.
- El alcance del proyecto no incluye introducir herramientas nuevas que el equipo no maneje.
- La solución debe integrarse con lo que operaciones ya opera, minimizando curva de aprendizaje.
- El datacenter alterno (DR) permanece on-premises.
- La conectividad AWS ↔ on-premises ya existe (VPN Site-to-Site / Direct Connect) para integración con Active Directory.

---

## Decisión Final: Opción C — FSx for Windows (Single-AZ 1) + DFS-R

**Amazon FSx for Windows File Server desplegado en Single-AZ 1**, que es el único deployment type que soporta DFS Replication. FSx reemplaza al File Server del datacenter principal como nodo DFS-R, y el datacenter alterno (DR) mantiene su rol de target de replicación exactamente como funciona hoy.

### Justificación

1. **Transparencia operativa**: El equipo de operaciones sigue usando la misma consola DFS Management, los mismos conceptos de grupos de replicación y namespaces.
2. **Cero herramientas nuevas**: No se introduce DataSync, Storage Gateway, ni ningún servicio ajeno al flujo actual.
3. **Mínimo cambio on-prem**: Solo se actualiza el membership del grupo DFS-R para reemplazar el File Server viejo por FSx.
4. **Compatibilidad nativa**: FSx es un Windows File Server fully managed que se une al dominio AD existente.

### Documentación oficial

- [Feature support by deployment type (DFS-R solo en Single-AZ 1)](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/high-availability-multiAZ.html)
- [DFS-R not supported on Multi-AZ / Single-AZ 2](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/dfs-r.html)
- [Using DFS Namespaces with FSx](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/using-dfs-namespaces.html)

### Trade-offs aceptados

| Aspecto | Detalle |
|---------|---------|
| Single-AZ (sin failover automático a otra AZ) | Aceptable porque DFS-R al DC alterno ES el mecanismo de DR. Si la AZ cae, el DC alterno tiene los datos. |
| Solo SSD (no HDD) | Single-AZ 1 solo soporta SSD. Costo ligeramente mayor pero mejor rendimiento. |
| ~30 min downtime en maintenance/recovery | Mitigado con maintenance windows programadas y la copia DFS-R. |

---

## Alternativas Evaluadas

### Opción A: FSx for Windows + Acceso directo desde on-prem DR

**Descripción**: Desplegar FSx en AWS y que el DC alterno acceda directamente a FSx via SMB sobre VPN/DX, sin replicación local.

**Cómo funciona**:
- FSx es el storage principal en AWS.
- El DC alterno simplemente mapea el share de FSx como network drive remoto.
- No hay copia local de datos en el DC alterno.

**Ventajas**:
- Cero configuración DFS-R en ningún lado.
- Arquitectura más simple (un solo punto de datos).

**Desventajas**:
- Si se pierde la conectividad VPN/DX, el DC alterno no tiene acceso a los datos.
- No hay copia offline para DR real.
- La latencia de red afecta la experiencia de acceso desde on-prem.
- No cumple el objetivo de DR (tener una copia disponible si AWS falla).

**Decisión**: Descartada — no provee DR real.

**Referencia**: [Accessing FSx from on-premises](https://aws.amazon.com/blogs/storage/accessing-smb-file-shares-remotely-with-amazon-fsx-for-windows-file-server/)

---

### Opción B: FSx for Windows + Amazon FSx File Gateway en on-prem DR

**Descripción**: Desplegar un appliance FSx File Gateway en el DC alterno que provee cache local SMB con respaldo en FSx.

**Cómo funciona**:
- FSx File Gateway es un appliance VM (VMware/Hyper-V) que se despliega on-premises.
- Provee acceso SMB local con cache, respaldado por FSx en AWS.
- Los usuarios on-prem ven un share local con latencia baja.

**Ventajas**:
- Cache local para acceso rápido.
- No requiere configurar DFS-R.

**Desventajas**:
- **DESCARTADA POR AWS**: A partir de octubre 2024, AWS dejó de permitir la creación de nuevos FSx File Gateway para clientes nuevos.
- Introduce una herramienta nueva que operaciones no conoce.
- Requiere desplegar y mantener un appliance VM on-premises.

**Decisión**: No viable — servicio deprecated para nuevos clientes.

**Referencia**: [Switch from FSx File Gateway (announcement Oct 2024)](https://aws.amazon.com/blogs/storage/switch-your-file-share-access-from-amazon-fsx-file-gateway-to-amazon-fsx-for-windows-file-server/)

---

### Opción C: FSx for Windows (Single-AZ 1) + DFS-R al DC alterno ✅ SELECCIONADA

**Descripción**: FSx reemplaza al File Server del DC principal como miembro del grupo DFS-R. El DC alterno mantiene su rol de target de replicación.

**Cómo funciona**:
- FSx se une al dominio AD (ena.us.experian.local).
- Desde DFS Management Console, se agrega FSx al grupo de replicación existente.
- Se retira el File Server viejo del DC principal.
- El DC alterno sigue recibiendo réplicas DFS-R normalmente.

**Ventajas**:
- Operaciones ya conoce DFS-R — cero curva de aprendizaje.
- FSx es Windows nativo (mismo protocolo, misma integración AD).
- DR real: el DC alterno tiene copia completa de los datos.
- DFS Namespaces permite path unificado transparente.

**Desventajas**:
- Requiere Single-AZ 1 (sin failover automático entre AZs).
- Solo SSD disponible.

**Requisitos técnicos**:
- FSx deployment type: **Single-AZ 1**
- Conectividad: VPN/DX entre VPC y DC alterno
- AD: FSx se une al mismo dominio
- Puertos: SMB (445), RPC (135), DFS-R (5722), RPC dinámico (49152-65535)
- Security Group: Permitir tráfico DFS-R desde CIDR del DC alterno

**Decisión**: SELECCIONADA.

**Referencias**:
- [FSx Single-AZ 1 supports DFS-R](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/high-availability-multiAZ.html)
- [DFS-R limitation on Multi-AZ/Single-AZ 2](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/dfs-r.html)
- [DFS Namespaces with FSx](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/using-dfs-namespaces.html)
- [Group multiple FSx file systems under DFS Namespace](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/group-fsx-namespace.html)

---

### Opción D: FSx for Windows + AWS DataSync + S3 File Gateway en DR

**Descripción**: DataSync copia periódicamente los datos de FSx a S3. En el DC alterno, un S3 File Gateway expone los datos como share SMB local.

**Cómo funciona**:
- AWS DataSync ejecuta tareas programadas (cada 15 min, 1 hora, etc.) copiando de FSx a S3.
- En el DC alterno se despliega un appliance S3 File Gateway (VM).
- El File Gateway expone los datos de S3 como SMB share con cache local.

**Ventajas**:
- No requiere DFS-R.
- Cache local SMB disponible en DR (funciona offline con datos cacheados).
- S3 File Gateway sigue disponible para nuevos clientes (a diferencia de FSx File Gateway).

**Desventajas**:
- Introduce herramientas nuevas que operaciones no conoce (DataSync + Storage Gateway).
- No es real-time (hay ventana de RPO según schedule de DataSync).
- Pierde semántica DFS Namespaces (el path unificado no aplica en el appliance).
- Requiere desplegar y mantener appliance VM on-premises.
- Mayor complejidad operativa.

**Decisión**: Descartada — introduce complejidad y herramientas nuevas que contradicen la premisa de integrarse con lo que operaciones ya conoce.

**Referencias**:
- [Migrating files to FSx with DataSync](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/migrate-files-to-fsx-datasync.html)
- [S3 File Gateway SMB shares](https://docs.aws.amazon.com/filegateway/latest/files3/using-smb-fileshare.html)
- [AWS Storage Gateway overview](https://aws.amazon.com/storagegateway/faqs/)
- [Getting Started with FSx File Gateway (reference architecture)](https://aws.amazon.com/solutions/guidance/getting-started-with-amazon-fsx-file-gateway/)

---

## Resumen Comparativo

| Criterio | Opción A (Acceso directo) | Opción B (FSx File GW) | Opción C (DFS-R) ✅ | Opción D (DataSync+S3 GW) |
|----------|--------------------------|------------------------|---------------------|---------------------------|
| DR real (copia local) | ✗ | ✓ (cache) | ✓ (réplica completa) | ✓ (cache + S3) |
| Herramientas conocidas por ops | ✓ (SMB) | ✗ (Storage GW) | ✓ (DFS-R, DFS Mgmt) | ✗ (DataSync, GW) |
| Disponibilidad del servicio | ✓ | ✗ (deprecated Oct 2024) | ✓ | ✓ |
| Real-time sync | N/A | Sí (cache) | Sí (DFS-R) | No (scheduled) |
| Complejidad on-prem | Nula | Media (appliance) | Baja (update membership) | Media (appliance) |
| Complejidad AWS | Baja | Media | Baja | Alta |
| Offline access en DR | ✗ | ✓ | ✓ | ✓ (cache) |

---

## Diagrama de referencia

Ver: `diagrams/intelisrcpa-pdn-infrastructure.drawio`

---

*Documento generado: Junio 2025*
*Proyecto: InteliSrcPA — Migración Producción a AWS*
*Región: us-east-1 (N. Virginia)*



check this for diagram onpremise-aws

https://docs.aws.amazon.com/filegateway/latest/filefsxw/what-is-file-fsxw.html