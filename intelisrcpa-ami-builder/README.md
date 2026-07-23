# InteliSrcPA AMI Builder

Pipeline para construir Application AMIs Windows sobre Golden AMIs de Experian (EEC).

## Descripción

Este proyecto automatiza la creación de AMIs pre-configuradas para las aplicaciones
Windows IIS de InteliSrcPA usando **EC2 Image Builder**. El objetivo es reducir el
tiempo de bootstrap de ~30 minutos a <2 minutos para los Auto Scaling Groups.

## Arquitectura

```
Golden AMI (EEC Windows 2022/2025 hardenizada)
    └── EC2 Image Builder Pipeline
            ├── Componente: Instalar IIS + Features/Roles
            ├── Componente: Configurar conexión FSx
            └── Componente: Preparar Domain Join (Sysprep-friendly)
                    └── Application AMI (output)
                            └── Launch Template → Auto Scaling Group
```

## Estructura del Repositorio

```
intelisrcpa-ami-builder/
├── Jenkinsfile                          # Pipeline (splatam_template)
├── Jenkinsfile.promote                  # Pipeline de promotion entre cuentas
├── ami.yaml                             # Inventario de AMIs por app/env/region
├── .gitignore
├── modules/
│   └── eits-tf-aws-imagebuilder-main/   # Módulo reutilizable Image Builder
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── locals.tf
│       ├── versions.tf
│       ├── provider.tf
│       ├── README.md
│       ├── CHANGELOG.md
│       └── CONTRIBUTING.md
├── intelisrcpa/
│   ├── dev/                             # Environment: Desarrollo
│   │   ├── backend.tf
│   │   ├── provider.tf
│   │   ├── data.tf
│   │   ├── locals.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   ├── iam.tf
│   │   ├── kms.tf
│   │   ├── securitygroups.tf
│   │   ├── imagebuilder.tf              # Componentes + llamada al módulo
│   │   └── outputs.tf
│   ├── qa/                              # Environment: QA (por crear)
│   ├── stg/                             # Environment: Staging (por crear)
│   └── pro/                             # Environment: Producción
│       ├── (misma estructura que dev)
│       └── terraform.tfvars
└── components/                          # Scripts PowerShell para Image Builder
    ├── install-iis.ps1
    ├── configure-fsx-mount.ps1
    └── domain-join-prep.ps1
```

## Environments / Cuentas AWS

| Env   | Account ID     | S3 Backend Bucket                      |
|-------|----------------|----------------------------------------|
| dev   | 779394371865   | infrasplatam-terraform-779394371865    |
| qa    | 409447266290   | infrasplatam-terraform-409447266290    |
| stg   | 375662988321   | infrasplatam-terraform-375662988321    |
| pro   | 274193347839   | infrasplatam-terraform-274193347839    |

## Uso

### Despliegue de infraestructura

El pipeline usa `splatam_template` (igual que el repo de IaC principal).
Jenkins ejecuta `terraform plan` y `terraform apply` para cada environment.

Después del apply, Jenkins ejecuta el Image Builder pipeline y espera
a que la AMI se construya.

### Promote AMI entre cuentas

Ejecutar `Jenkinsfile.promote`:
1. Seleccionar AMI de origen (dev)
2. Seleccionar environment destino (qa/stg/pro)
3. El pipeline comparte la AMI via `aws_ami_launch_permission`

### Consumo desde IaC (repo principal)

En `iac/repo/intelisrcpa/{env}/terraform.tfvars`:

```hcl
ec2_windows = {
  "APP01" = {
    ami = "ami-0xxxxxxxxxxxxxxxxx"  # Del ami.yaml de este repo
    # ...
  }
}
```

## Módulo: eits-tf-aws-imagebuilder-main

Módulo Terraform reutilizable para EC2 Image Builder.
Sigue la estructura estándar EITS (como `eits-tf-aws-rds-main`).

Ver [modules/eits-tf-aws-imagebuilder-main/README.md](modules/eits-tf-aws-imagebuilder-main/README.md).

## Iteración futura

- [ ] Agregar environments `qa` y `stg`
- [ ] Agregar componentes por aplicación (9 apps)
- [ ] Configurar scheduled builds semanales
- [ ] Integrar WIZ scan post-build
- [ ] Lifecycle hook para AD cleanup en el repo de IaC principal
