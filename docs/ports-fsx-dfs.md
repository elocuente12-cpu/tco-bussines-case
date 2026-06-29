La página oficial pone la tabla de puertos en una imagen, pero el conjunto de puertos de FSx for Windows está bien establecido. Aquí va lo que necesitas abrir en tu firewall on-premise para que DFS-R alcance el FSx.

⚠️ Lo más importante: DFS-R es bidireccional
DFS-R no es cliente→servidor; los dos miembros (tu file server on-prem y el FSx) inician conexiones entre sí para replicar. Por eso:

En AWS (security group del FSx): inbound desde los CIDRs on-prem (las reglas que dejamos comentadas en securitygroups.tf).
En on-premise (firewall/Windows Firewall): permitir el tráfico en ambos sentidos hacia/desde el rango de IPs del FSx. Los SG de AWS son stateful (basta abrir un sentido), pero el Windows Firewall y los ACLs suelen requerir ambas direcciones.
Puertos para DFS-R y acceso a archivos (file server on-prem ↔ FSx)
Puerto	Protocolo	Para qué
445	TCP	SMB (acceso a archivos / DFS)
135	TCP	RPC Endpoint Mapper (negociación de DFS-R)
49152–65535	TCP	Puertos RPC dinámicos — tráfico real de replicación DFS-R
5985	TCP	WinRM, solo si administras el FSx remotamente
Nota: las versiones modernas de Windows Server (2012+) usan RPC dinámico para DFS-R; el viejo puerto fijo 5722 ya no aplica.

Puertos de dominio (porque DFS-R se autentica vía AD)
El FSx está unido a tu AD self-managed, así que entre el FSx y tus domain controllers / DNS on-premise deben fluir:

Puerto	Protocolo	Para qué
53	TCP/UDP	DNS
88	TCP/UDP	Kerberos
389	TCP/UDP	LDAP
445	TCP	SMB / servicios de directorio
464	TCP/UDP	Kerberos (cambio de contraseña)
636	TCP	LDAPS
3268 / 3269	TCP	LDAP Global Catalog (y sobre SSL)
9389	TCP	AD DS Web Services (requerido en Single-AZ 2 y Multi-AZ; en Single-AZ 1 no es obligatorio)
Resumen práctico para tu caso (Single-AZ 1)
Abre, en ambas direcciones, entre el rango de IPs de tu file server on-prem y la IP del FSx:

TCP 445, 135 y 49152–65535 → esto es lo que hace funcionar DFS-R.
Y asegúrate de que el FSx pueda hablar con tus DCs/DNS en los puertos AD de arriba (normalmente ya abiertos si el dominio opera híbrido).
Del lado AWS solo descomenta las reglas de securitygroups.tf (445/135/49152-65535) con tus CIDRs on-prem. El 5985 es opcional (administración).

Sources:

File system access control with Amazon VPC — puertos de FSx for Windows
Using Microsoft DFS Replication
Si me confirmas los CIDRs de tu segmento on-premise, te dejo las reglas del sg_fsx ya descomentadas y listas con esos valores.

Los segmentos de red onpremse no los conozco, pero los de aws tengo solo dos subredes que serian 10.64.160.192/26 y 10.64.160.128/26