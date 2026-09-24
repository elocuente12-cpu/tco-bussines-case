# KT — Terraform `intelisrcpa/pro` (Producción)

**Ruta del código:** `/Users/javier.sepulveda/projects/experian/iac/repo/intelisrcpa/pro`
**Audiencia:** ingenieros con Terraform básico (recursos, variables, módulos) que necesitan entender expresiones avanzadas (`for`, `for_each`, `concat`, `setproduct`, etc.) usadas en este ambiente.
**Objetivo:** que cualquier persona del equipo pueda leer el código, entender el porqué de cada patrón, y modificarlo con seguridad sin romper el `plan`/`apply`.

---

## 1. Mapa del proyecto: qué hace cada archivo

| Archivo | Qué construye |
|---|---|
| `provider.tf` | Provider AWS, región, assume role, tags por defecto |
| `backend.tf` | Backend remoto del state |
| `variables.tf` | Contrato de entrada: todas las `variable` con sus tipos |
| `terraform.tfvars` | Los valores reales para producción (`environment=prd`) |
| `locals.tf` | Toda la lógica de transformación de datos (naming, filtros, listeners del ALB, nombres de recursos DMS, etc.) |
| `data.tf` | Consultas a recursos que ya existen en AWS (VPC, subnets, secrets, otra RDS) |
| `acm.tf` | Certificados ACM (uno por dominio público del ALB) |
| `alb.tf` | El Application Load Balancer, sus target groups y sus reglas de enrutamiento |
| `asg.tf` | Un Auto Scaling Group de Windows por cada app detrás del ALB |
| `asg_lifecycle.tf` | Lambda + EventBridge que limpia el objeto de AD cuando una instancia del ASG se termina |
| `ec2.tf` | 3 instancias Windows fijas (no autoescalables) |
| `rds.tf` | Las 2 instancias de SQL Server (RDS) |
| `fsx.tf` | El file server compartido (FSx for Windows) |
| `dms.tf` | Migración/replicación de datos entre RDS y el SQL Server on-premise |
| `iam.tf` | Roles que usan las instancias, RDS y DMS |
| `kms.tf` | Llaves de cifrado (una por servicio: EBS, Secrets, RDS, S3, SNS, Backup) |
| `secrets.tf` | Credenciales de Active Directory y DMS guardadas en Secrets Manager |
| `securitygroups.tf` | Los Security Groups (firewalls) de ALB, Windows, FSx, DMS |
| `sns.tf` | El topic de notificaciones para alertas de expiración de certificados |
| `aws-backup.tf` | El plan de backups automáticos |
| `s3.tf` | Buckets para backups de RDS y reportes |
| `builder.tf` | Instancia temporal para "hornear" la AMI de Windows |
| `outputs.tf` | Valores que Terraform expone al terminar (ARNs, IDs, DNS names) |

La idea de fondo del proyecto es: **una sola app puede tener varias "sub-apps"** (`app1`, `app2`, ... en `alb_apps`), y casi todo el código de ALB/ASG/Security Groups existe para poder repetir "un target group + un ASG + un SG" por cada sub-app sin copiar y pegar bloques de código.

---

## 2. Lo mínimo de Terraform para entender lo que sigue

Antes de entrar en los patrones "raros", un repaso rápido de las piezas que se combinan:

- **`variable`**: un parámetro de entrada. Puede ser un tipo simple (`string`, `bool`, `number`) o un tipo complejo (`map`, `list`, `object`).
- **`local`**: una variable calculada dentro del propio código (no la define el usuario, la calcula Terraform a partir de otras variables). Vive en `locals.tf` en este proyecto.
- **`module`**: un bloque de código reutilizable (viene de un repositorio Git externo, ej. `eits-tf-aws-alb`). Se le pasan variables y devuelve outputs.
- **`for_each`**: le dice a un `module` o `resource` "crea una copia de este bloque por cada elemento de este map/set". Si el map tiene 3 keys, se crean 3 copias, cada una identificada por su key.
- **`for` (comprehension)**: no crea recursos, solo **transforma datos**: toma un map o lista de entrada y devuelve un map o lista nuevo, con la forma que uno defina. Se usa dentro de `locals` o dentro de argumentos de un `module`/`resource`.

La diferencia clave: `for_each` crea **recursos** (cosas en AWS). `for` crea **datos** (valores dentro de Terraform, usados para alimentar `for_each` o cualquier otro atributo).

---

## 3. `for_each`: "una copia de este módulo por cada elemento del map"

Esta es la herramienta más usada en el proyecto. El patrón general:

```hcl
module "algo" {
  source   = "..."
  for_each = var.mi_mapa   # un map(object({...}))

  nombre = each.key     # la key del map (ej: "app1")
  config = each.value   # el objeto completo de esa key
}
```

Cada iteración de `for_each` se identifica por su **key**, y dentro del bloque, `each.key` es esa key y `each.value` es el valor asociado. Fuera del módulo, se referencia una instancia específica con `module.algo["esa_key"]`.

### Ejemplos reales en el proyecto

| `for_each` sobre... | Dónde | Qué crea, una copia por cada... |
|---|---|---|
| `var.acm_certificates` | `acm.tf` | ...certificado ACM (dominio público del ALB) |
| `var.alb_apps` | `asg.tf` (`module.asg_windows_web`) | ...Auto Scaling Group de Windows, uno por sub-app |
| `var.alb_apps` | `asg.tf` (`aws_autoscaling_attachment.asg_alb`) | ...conexión entre un ASG y su target group |
| `var.rds_instances` | `rds.tf` (`module.rds_sqlserver`) | ...instancia de RDS SQL Server (hoy: `produccion`, `procesos`) |
| `var.rds_instances` | `rds.tf` (`module.sg_rds_sqlserver`) | ...Security Group dedicado para esa instancia RDS |
| `var.ec2_windows` | `ec2.tf` | ...instancia Windows fija |
| `local.sg_alb` / `local.sg_windows_asg` / `local.sg_fsx` / `var.sg_windows` / `var.sg_dms-replication` | `securitygroups.tf` | ...Security Group (uno por cada grupo lógico de reglas) |
| `{ for k, v in local.kms_keys : v.name => v }` | `kms.tf` (`module.kms_aws_backup`) | ...llave KMS de AWS Backup (s3, vault, sns) |

**Idea clave para explicar a alguien nuevo:** si ves `for_each = var.algo` en un módulo, pregúntate "¿cuántas keys tiene `var.algo` en el tfvars?" — esa es la cantidad de recursos reales que se van a crear en AWS. Por ejemplo, hoy `var.alb_apps` tiene 7 apps, así que `asg.tf` crea 7 Auto Scaling Groups completos, cada uno con su propio Launch Template, tamaño mínimo/máximo, etc.

### Por qué el attachment del ASG está separado del módulo (asg.tf)

En `asg.tf`, el módulo del ASG recibe `target_group_arns = []` (vacío a propósito), y la conexión real al target group se hace en un recurso separado más abajo:

```hcl
resource "aws_autoscaling_attachment" "asg_alb" {
  for_each = var.alb_apps
  autoscaling_group_name = module.asg_windows_web[each.key].asg_name
  lb_target_group_arn    = local.alb_tg_arn_by_app[each.key]
}
```

El motivo: en el primer despliegue, el ARN del target group todavía no existe (se crea en el mismo `apply`), así que Terraform no puede saber ese valor de antemano ("unknown"). Si ese ARN desconocido se usara **dentro del propio `for_each` del módulo ASG**, Terraform no podría calcular cuántas copias crear y el plan fallaría. Separar el attachment en un recurso propio, que solo depende de `var.alb_apps` (que sí se conoce siempre), evita el problema.

Esta idea —"no dejar que un valor desconocido decida la forma de un `for_each`"— es el hilo conductor de casi todos los patrones raros del proyecto. Aparece de nuevo en la sección 6.

---

## 4. `for` (comprehensions): "transforma este dato en otro dato"

A diferencia de `for_each`, un `for` no crea nada en AWS, solo transforma un map o lista en otro. Se usa mucho dentro de `locals.tf` para preparar datos antes de pasarlos a un módulo.

### Sintaxis básica

```hcl
# de un map a otro map
{ for key, value in var.entrada : key => transformar(value) }

# de un map a una lista
[ for key, value in var.entrada : transformar(value) ]

# con filtro (la parte "if" es opcional)
{ for key, value in var.entrada : key => value if condicion }
```

### Ejemplos reales, explicados uno por uno

**a) Renombrar recursos DMS a partir de sus keys** (`locals.tf`):
```hcl
replication_instance_names = {
  for key, config in var.replication_instances : key => "${local.identifier_base}-${key}"
}
```
Traducción: "para cada instancia de réplica definida en el tfvars, genera su nombre completo pegando el prefijo del proyecto". Si `var.replication_instances` tiene la key `"poc"`, el resultado es `{ "poc" = "eec-aws-us-eits-intelisrcpa-prd-dms" }` (aproximado).

**b) Extraer un solo atributo de un `for_each` de módulos** (patrón repetido en `outputs.tf` y `locals.tf`):
```hcl
acm_cert_arns = { for key, mod in module.acm : key => mod.arn }
```
Traducción: "el módulo ACM se creó una vez por cada dominio (`for_each`); ahora quiero un mapa simple de `dominio -> su ARN`, sin cargar todo el objeto del módulo". Esto es el mismo patrón que usan casi todos los `outputs.tf` (`sg_windows_ids`, `ec2_windows`, `asg_name`, etc.): "toma el resultado de un `for_each` y quédate solo con el atributo que te interesa".

**c) Filtrar con `if`** (`locals.tf`, cadena de ACM):
```hcl
acm_issued_cert_arns = {
  for key, arn in local.acm_cert_arns : key => arn
  if var.acm_certificates[key].attach_to_listener
}
```
Traducción: "de todos los certificados, quédate solo con los que tengan `attach_to_listener = true` en el tfvars". El `if` al final de un `for` es un filtro: si la condición es falsa para esa key, esa key simplemente no aparece en el resultado. Ver la sección 6 para el porqué de este filtro específico.

**d) `for` anidado (doble)** (`rds.tf`, dentro de `option_group_options`):
```hcl
option_group_options = [
  for opt in each.value.option_group_options : merge(opt, {
    option_settings = [
      for setting in opt.option_settings : {
        name  = setting.name
        value = setting.name == "IAM_ROLE_ARN" ? module.iam_rds_backup.role_arn : setting.value
      }
    ]
  })
]
```
Traducción: "por cada opción del option group (SSIS, SSRS, TDE...), y dentro de cada opción, por cada configuración (`option_settings`), si el nombre es `IAM_ROLE_ARN` reemplaza el valor por el ARN real del rol de backup; si no, deja el valor tal cual". Esto existe porque en el `tfvars` no se puede escribir el ARN real (todavía no existe cuando se escribe el tfvars), así que se deja un placeholder de texto (`"PLACEHOLDER_BACKUP_ROLE_ARN"`) y este `for` anidado lo sustituye en el momento del `plan`, cuando el ARN real sí es conocido.

---

## 5. Funciones que combinan o transforman listas/maps

Estas funciones aparecen sueltas dentro de expresiones `for`/`locals`, resolviendo un problema puntual cada una.

### `concat(lista1, lista2, ...)` — "junta varias listas en una sola"

```hcl
alb_listeners = concat([local.alb_listener_http], local.alb_listener_https)
```
`local.alb_listener_http` es siempre **un objeto único** (el listener HTTP existe siempre), por eso se envuelve en `[...]` para convertirlo en una lista de 1 elemento. `local.alb_listener_https` ya es una lista que puede tener 0 o 1 elementos (0 si no hay certificados listos, 1 si sí los hay). `concat` los junta en una sola lista final de 1 o 2 elementos, que es lo que espera el módulo del ALB en su variable `listeners`.

### `setproduct(lista1, lista2)` — "todas las combinaciones posibles entre dos listas"

Este es el más difícil de visualizar. `setproduct` devuelve **todas las combinaciones (pares)** entre los elementos de la primera lista y los de la segunda — como una tabla de multiplicar.

```hcl
setproduct(["http_80", "https_443"], ["app1", "app2"])
# resultado:
# [["http_80","app1"], ["http_80","app2"], ["https_443","app1"], ["https_443","app2"]]
```

En `alb.tf`:
```hcl
listener_rules = [
  for pair in setproduct(local.alb_rule_listeners, keys(var.alb_apps)) : {
    listener         = pair[0]   # "http_80" o "https_443"
    target_group_key = pair[1]   # "app1", "app2", etc.
    priority         = var.alb_apps[pair[1]].priority
    ...
  }
]
```

**Por qué se usa esto:** cada app necesita una "regla de enrutamiento" (listener rule) en el listener HTTP, y **la misma regla** también en el listener HTTPS (para que HTTPS enrute igual que HTTP). En vez de escribir el bloque de la regla dos veces (uno para HTTP, uno para HTTPS, cambiando solo el nombre del listener), `setproduct` genera automáticamente el "cruce" de listeners × apps, y un solo `for` construye todas las reglas necesarias. Si en el futuro se agrega un tercer listener, no hay que tocar este código: `local.alb_rule_listeners` simplemente tendría 3 elementos en vez de 2, y el `setproduct` genera automáticamente el triple de combinaciones.

### `zipmap(lista_keys, lista_valores)` — "combina dos listas paralelas en un map"

```hcl
alb_tg_arn_by_name = zipmap(module.alb.target_group_names, module.alb.target_group_arns)
```

El módulo del ALB devuelve dos listas separadas: los nombres de los target groups y sus ARNs, **en el mismo orden**. `zipmap` las combina en un solo map `{ nombre = arn }`, mucho más fácil de consultar por nombre que tener que buscar el índice en dos listas paralelas.

### `slice(lista, desde, hasta)` — "recorta una parte de la lista"

```hcl
subnet_ids = slice(data.aws_subnets.private.ids, 0, 2)
```
Toma solo las 2 primeras subredes privadas de todas las que existen (el ALB/ASG solo necesitan 2 para multi-AZ).

```hcl
acm_additional_cert_arns = slice(local.acm_cert_arns_sorted, 1, length(local.acm_cert_arns_sorted))
```
Toma "desde el segundo elemento hasta el final" — es decir, todos menos el primero. Ver sección 6.

### `sort(lista_de_strings)` — "ordena alfabéticamente"

```hcl
acm_cert_arns_sorted = [for key in sort(keys(local.acm_issued_cert_arns)) : local.acm_issued_cert_arns[key]]
```
Antes de convertir el map de certificados en una lista, se ordenan las **keys** (los dominios) alfabéticamente. Esto asegura que, aunque el map interno de Terraform no tenga un orden garantizado, el resultado siempre sea el mismo en cada `plan` — así el "certificado principal" (el primero de la lista) no cambia de un apply a otro sin motivo.

### `merge(mapa1, mapa2, ...)` — "combina dos maps, el segundo pisa al primero si hay claves repetidas"

```hcl
sg_alb = merge(var.sg_alb, /* aquí se agregarían reglas adicionales si hicieran falta */)
```
Hoy no le agrega nada extra (el segundo argumento está vacío), es un punto de extensión preparado para el futuro: si algún día se necesita inyectar una regla de Security Group con un ID que solo se conoce en tiempo de plan (por ejemplo, el ID de otro SG creado dinámicamente), se agregaría aquí sin tocar el resto del código.

### `coalesce(valor1, valor2, ...)` — "el primer valor que no sea null"

```hcl
hostname_start = coalesce(each.value.hostname_start, 1)
```
Si la app no define `hostname_start` en el tfvars, usa `1` por defecto.

---

## 6. El caso más importante del proyecto: certificados ACM + Listener HTTPS

Esta es la parte más compleja y la más importante de entender bien, porque combina casi todo lo anterior y resuelve un problema real de Terraform que rompe el `apply` si no se maneja con cuidado.

### El problema de fondo

Al pedir un certificado nuevo a ACM (`action = "request"`), AWS no lo emite al instante: queda en estado `PENDING_VALIDATION` hasta que alguien crea el registro DNS de validación (en este proyecto, la validación es **externa**, es decir, el equipo de DNS de cada dominio público tiene que crear un CNAME manualmente).

Un listener HTTPS del ALB **solo acepta certificados en estado `ISSUED`**. Si se intenta usar un certificado `PENDING_VALIDATION`, AWS rechaza la creación del listener con el error `UnsupportedCertificate`.

La solución "obvia" sería: filtrar automáticamente los certificados por su `status`, así:
```hcl
# ESTO NO FUNCIONA BIEN — solo como ejemplo de lo que NO se debe hacer
acm_issued_cert_arns = { for key, mod in module.acm : key => mod.arn if mod.status == "ISSUED" }
```
El problema: `mod.status` de un certificado **recién creado** es un valor "unknown" (no se conoce hasta que el `apply` termina, porque depende de un dato que AWS todavía no calculó). Cuando Terraform no puede calcular el resultado de un `if` de un `for` porque depende de un valor unknown, **toda la estructura del resultado se vuelve unknown** — y eso rompe el `for_each` del módulo ALB (aparece el error `Invalid for_each argument`), incluso antes de intentar crear nada.

### La solución real implementada: un flag manual y estático

En vez de depender del `status` (que es unknown), el proyecto usa un campo que el operador humano controla directamente en el `tfvars`: `attach_to_listener`.

```hcl
# variables.tf
variable "acm_certificates" {
  type = map(object({
    domain_name        = string
    hosted_zone_name   = string
    attach_to_listener = optional(bool, true)
  }))
}
```

```hcl
# terraform.tfvars (fragmento real)
acm_certificates = {
  "mobile.apc.com.pa" = {
    domain_name        = "mobile.apc.com.pa"
    hosted_zone_name   = "apc.com.pa"
    attach_to_listener = true    # ya validado -> se adjunta al listener
  }
  "tuintelidat.com" = {
    domain_name        = "tuintelidat.com"
    hosted_zone_name   = "tuintelidat.com"
    attach_to_listener = false   # todavia PENDING_VALIDATION -> no se adjunta
  }
  ...
}
```

Y el filtro real en `locals.tf`:
```hcl
acm_issued_cert_arns = {
  for key, arn in local.acm_cert_arns : key => arn
  if var.acm_certificates[key].attach_to_listener
}
```

`var.acm_certificates[key].attach_to_listener` es un booleano que viene **directo del tfvars**, así que Terraform lo conoce siempre desde el primer instante del `plan` — nunca es unknown. Esto hace que el resultado de `acm_issued_cert_arns` (y todo lo que depende de él) sea 100% predecible antes de tocar AWS.

**El costo de esta solución:** ya no es automático. Alguien del equipo tiene que:
1. Crear el CNAME de validación en el DNS externo del dominio correspondiente (usando el output `acm_domain_validation_options`).
2. Esperar a que ACM confirme el estado `ISSUED` (se puede revisar con el output `acm_certificate_status`, o directamente en la consola de ACM).
3. **Cambiar manualmente `attach_to_listener = true`** en el `terraform.tfvars` para ese dominio.
4. Correr `plan`/`apply` de nuevo — en ese momento el certificado se agrega al listener HTTPS.

### La cadena completa, paso a paso

```
terraform.tfvars (acm_certificates, 11 dominios)
        │
        ▼
acm.tf → module.acm (for_each, 1 certificado por dominio)
        │
        ▼
locals.tf:
  acm_cert_arns          → { dominio => ARN }  (todos, sin filtrar)
  acm_cert_status        → { dominio => status } (solo informativo, NO se usa para decidir nada)
  acm_issued_cert_arns   → { dominio => ARN }  (filtrado por attach_to_listener == true)
  acm_cert_arns_sorted   → [ARN, ARN, ...]     (ordenado alfabéticamente por dominio)
  acm_primary_cert_arn   → el primer ARN de la lista (o null si la lista está vacía)
  acm_additional_cert_arns → el resto de los ARN (servidos por SNI)
        │
        ▼
  alb_listener_https → lista de 0 o 1 elementos:
     - 0 elementos si NO hay ningún certificado con attach_to_listener=true
     - 1 elemento (el listener 443 completo) si hay al menos uno
        │
        ▼
  alb_listeners = concat([listener_http], alb_listener_https)
  alb_rule_listeners = ["http_80"] + (["https_443"] solo si hay certs)
        │
        ▼
alb.tf → module.alb.listeners = local.alb_listeners
       → listener_rules (usa setproduct sobre alb_rule_listeners × apps)
```

**En resumen para explicarlo en una frase:** *"El certificado no entra al listener HTTPS solo porque exista, sino porque alguien confirmó manualmente en el tfvars que ya está validado. Mientras eso no pase, Terraform ni siquiera intenta crear el listener 443 con ese certificado, evitando el error de AWS."*

### Por qué el listener HTTP:80 declara atributos que no usa

```hcl
alb_listener_http = {
  port             = var.alb_listener_port
  protocol         = var.alb_listener_protocol
  ssl_policy       = null
  certificate_arn  = null
  additional_certs = []
  fixed_response   = var.alb_http_redirect_to_https ? null : { ... }
  redirect         = var.alb_http_redirect_to_https ? { ... } : null
}
```

El listener HTTP no necesita `ssl_policy` ni `certificate_arn` (esos son cosas de HTTPS), pero se declaran igual con valor `null`. Esto es porque este objeto se junta con el objeto del listener HTTPS usando `concat()`, y Terraform exige que **todos los elementos de una misma lista tengan exactamente la misma forma** (los mismos atributos, aunque algunos valgan `null`). Si un objeto tuviera un atributo que el otro no tiene, `concat` fallaría con un error de tipos incompatibles.

### El flag `alb_http_redirect_to_https`

```hcl
variable "alb_http_redirect_to_https" {
  type    = bool
  default = false
}
```

Controla qué hace el listener :80 por defecto:
- `false` (valor actual): responde `404` directamente en HTTP, y las reglas de enrutamiento (`listener_rules`) mandan cada request a su app. Esto es lo que se usa **mientras los certificados se están validando**, para no dejar las apps sin acceso.
- `true`: en vez de servir contenido, redirige (HTTP 301) todo el tráfico a HTTPS:443. Esta es la buena práctica recomendada por AWS una vez que todos los certificados necesarios ya estén `ISSUED` y adjuntos al listener — no tiene sentido seguir sirviendo HTTP sin cifrar si ya existe HTTPS funcionando.

No hay que tocar ningún otro archivo para activar el redirect: solo cambiar este único valor en el `tfvars`.

---

## 7. Otros patrones que vale la pena conocer

### a) El "truco" del tag `Environment=prod` en el FSx

```hcl
# fsx.tf
tags = {
  Environment = "prod"   # NO "prd"
  backup      = "yes"
}
```

El módulo de FSx tiene una regla interna: si detecta el tag `Environment = "prd"` (el tag real del proyecto, que usan todos los demás recursos), fuerza el `deployment_type` a `MULTI_AZ_1`. Pero este FSx necesita ser `SINGLE_AZ_1` obligatoriamente, porque así lo requiere la replicación DFS-R con el servidor on-premise (esa característica no funciona en Multi-AZ). La solución fue taguear este recurso específico con `"prod"` (con "o", no "prd") — sigue siendo semánticamente producción, pero el módulo no reconoce ese string exacto y no aplica el guardrail. Es un workaround frágil: si el módulo cambiara su lógica de comparación en una versión futura (por ejemplo, buscando "prod" en vez de "prd"), este truco dejaría de funcionar y habría que revisarlo.

### b) `lookup(map, key, default)` en DMS

```hcl
cdc_start_position = lookup(var.cdc_start_positions, "clave_especifica", null)
```
Busca un valor por clave en un map, y si no existe, devuelve el valor por defecto (aquí `null`) en vez de fallar con un error. Se usa para las tareas de replicación donde el LSN (punto de partida de la replicación incremental) no siempre está definido.

### c) Doble intento de nombre de clave en credenciales AD

```hcl
ad_credentials = {
  username = try(local.ad_secret_data.username, local.ad_secret_data.SELF_MANAGED_ACTIVE_DIRECTORY_USERNAME, null)
}
```
`try()` intenta cada expresión en orden y devuelve la primera que no falle. Esto tolera que el secret en Secrets Manager se haya poblado manualmente con cualquiera de los dos formatos de nombre de clave (`username` o `SELF_MANAGED_ACTIVE_DIRECTORY_USERNAME`), sin que el `plan` falle si falta una de las dos.

### d) Uso del dominio (FQDN) como key del map, en vez de un nombre corto

En `acm_certificates`, la key de cada entrada es el propio dominio (`"api.apcexperian.com"`) en vez de un nombre corto arbitrario (`"cert5"`). Esto tiene dos ventajas: permite hacer `var.acm_certificates[dominio].attach_to_listener` directamente sin tabla de traducción, y el nombre del recurso en AWS también usa esa key (`Name = "...-${each.key}-acm"`), así el nombre del certificado en la consola de AWS coincide con el dominio real, facilitando la identificación visual.

---

## 8. Cómo modificar cosas comunes sin romper nada

**Agregar una nueva sub-app detrás del ALB:**
Agregar una nueva entrada en `var.alb_apps` (tfvars) con su `priority`, `host_headers`, AMI, tamaños de ASG, etc. Automáticamente se crearán: un target group, un ASG completo, un Security Group dedicado (si se agrega también en `sg_windows_asg`), y las listener rules correspondientes (en HTTP y en HTTPS si ya hay certificados activos) — sin tocar `alb.tf` ni `asg.tf`.

**Agregar un nuevo certificado ACM:**
Agregar la entrada en `acm_certificates` (tfvars) con `attach_to_listener = false` inicialmente. Después de crear el CNAME de validación externo y confirmar `ISSUED`, cambiar a `true` y volver a aplicar.

**Activar el redirect HTTP→HTTPS:**
Cambiar `alb_http_redirect_to_https = true` en el tfvars, **solo cuando** todos los certificados necesarios ya tengan `attach_to_listener = true` y estén `ISSUED`. Si se activa antes, las apps quedan inaccesibles (el 80 redirige a un 443 que no tiene los certs correctos, o las apps que aún no tienen su cert validado no podrán ser alcanzadas por HTTPS).

**Agregar una nueva instancia RDS:**
Agregar la entrada en `var.rds_instances` (tfvars). Se crea automáticamente la instancia, su Security Group dedicado, y la asociación con el rol de backup S3.

---

## Referencias

- Documentación oficial de expresiones `for`: https://developer.hashicorp.com/terraform/language/expressions/for
- Documentación oficial de `for_each`: https://developer.hashicorp.com/terraform/language/meta-arguments/for_each
- Función `setproduct`: https://developer.hashicorp.com/terraform/language/functions/setproduct
- AWS best practice de redirect HTTP→HTTPS en ALB: https://docs.aws.amazon.com/securityhub/latest/userguide/elb-controls.html
