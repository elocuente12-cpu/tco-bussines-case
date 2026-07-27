# Runbook: Creación de Application AMI - InteliSrcPA

## Objetivo

Crear una Application AMI Windows pre-configurada con IIS y scripts de runtime
para usar en Auto Scaling Groups. Reduce el tiempo de bootstrap de ~30 min a ~2.5 min.

## Información General

| Campo | Valor |
|-------|-------|
| Proyecto | InteliSrcPA |
| AppID | 22272 |
| CostString | 1850.PA.135.601000 |
| Owner | Fernando Hidalgo |
| Golden AMI base | `ami-08552a347fc5fd803` (eec_aws_windows_2025) |
| Región | us-east-1 |
| Repo IaC | `iac/repo/intelisrcpa/{env}/` |
| Scripts | `iac/repo/ami-builder-scripts/` |

## Cuentas AWS

| Ambiente | Account ID | terraform.tfvars |
|----------|------------|------------------|
| dev | 779394371865 | `intelisrcpa/dev/terraform.tfvars` |
| qa | 409447266290 | `intelisrcpa/qa/terraform.tfvars` |
| stg | 375662988321 | `intelisrcpa/stg/terraform.tfvars` |
| pro | 274193347839 | `intelisrcpa/pro/terraform.tfvars` |

---

## Pre-requisitos

- [ ] Acceso al repositorio IaC (`iac/repo`)
- [ ] Pipeline de Jenkins funcional para el environment destino
- [ ] Golden AMI disponible en la cuenta (verificar con `aws ec2 describe-images --image-ids ami-08552a347fc5fd803`)
- [ ] Bucket S3 de Terraform existente en la cuenta (para subir scripts)

---

## Paso 1: Activar la instancia builder via Terraform

### 1.1 — Modificar terraform.tfvars

Editar `iac/repo/intelisrcpa/{env}/terraform.tfvars`:

```hcl
# Cambiar de false a true
create_ami_builder_instance = true
ami_builder_golden_ami      = "ami-08552a347fc5fd803"  # Golden AMI mas reciente
```

### 1.2 — Ejecutar el pipeline

Hacer commit + push. El pipeline de Jenkins ejecutará `terraform apply` y creará:
- IAM Role + Instance Profile (SSM + S3 + ec2:CreateImage)
- Security Group (egress-only)
- EC2 Instance desde la Golden AMI

Si ejecutas localmente:

```bash
cd iac/repo/intelisrcpa/pro
terraform plan -out plan.tfplan
terraform apply plan.tfplan
```

### 1.3 — Obtener el Instance ID

```bash
aws ec2 describe-instances \
    --filters "Name=tag:Purpose,Values=AMI-Baking" "Name=instance-state-name,Values=running" \
    --query "Reservations[0].Instances[0].InstanceId" \
    --output text
```

---

## Paso 2: Conectar a la instancia

### Via SSM Session Manager (recomendado)

```bash
INSTANCE_ID="i-0xxxxxxxxxxxxxxxxx"
aws ssm start-session --target $INSTANCE_ID
```

Dentro de la sesión, cambiar a PowerShell:

```
powershell
```

---

## Paso 3: Copiar scripts a la instancia

### Opción A: Desde S3

Primero, subir los scripts (desde tu máquina local, una sola vez por versión):

```bash
ACCOUNT_ID="274193347839"  # Ajustar segun ambiente
aws s3 sync iac/repo/ami-builder-scripts/ \
    s3://infrasplatam-terraform-${ACCOUNT_ID}/ami-builder/scripts/
```

Luego en la instancia (PowerShell):

```powershell
New-Item -Path "C:\Build" -ItemType Directory -Force
aws s3 cp s3://infrasplatam-terraform-274193347839/ami-builder/scripts/ C:\Build\ --recursive
```

### Opción B: Copiar directamente via SSM (archivos pequeños)

Desde tu terminal local, para cada script:

```bash
# Ejemplo para un archivo
aws ssm send-command \
    --instance-ids $INSTANCE_ID \
    --document-name "AWS-RunPowerShellScript" \
    --parameters commands="aws s3 cp s3://infrasplatam-terraform-274193347839/ami-builder/scripts/ C:\Build\ --recursive"
```

### Verificar que los archivos están presentes

```powershell
Get-ChildItem C:\Build\

# Debe mostrar:
#   Build-AMI.ps1
#   01-install-iis.ps1
#   02-configure-fsx-mount.ps1
#   03-domain-join-prep.ps1
```

---

## Paso 4: Ejecutar el orquestador

### 4.1 — Ejecución completa (instala + valida + Sysprep + crea AMI)

```powershell
cd C:\Build

.\Build-AMI.ps1 `
    -AmiName "eec-aws-us-eits-intelisrcpa-prd-windows-iis" `
    -AppVersion "1.0.0" `
    -Environment "prd"
```

El script ejecuta en orden:
1. Instala IIS con los 33 features de producción
2. Crea `C:\Scripts\Startup\Mount-FsxShare.ps1`
3. Crea `C:\Scripts\Domain\Join-Domain.ps1` y `Leave-Domain.ps1`
4. Valida que todo existe y IIS responde
5. Ejecuta Sysprep (la instancia se apaga)
6. Crea la AMI y la tagea

### 4.2 — Ejecución paso a paso (para debug)

```powershell
cd C:\Build

# Solo instalar y validar (sin crear AMI)
.\Build-AMI.ps1 `
    -AmiName "eec-aws-us-eits-intelisrcpa-prd-windows-iis" `
    -AppVersion "1.0.0" `
    -Environment "prd" `
    -SkipSysprep `
    -SkipAmiCreation
```

Si todo pasa correctamente, puedes:
- Verificar manualmente (RDP, IIS Manager, etc.)
- Luego ejecutar sin los flags de skip para crear la AMI

### 4.3 — Si Sysprep se ejecutó (instancia se apagó)

Crear la AMI desde tu máquina local:

```bash
INSTANCE_ID="i-0xxxxxxxxxxxxxxxxx"
AMI_NAME="eec-aws-us-eits-intelisrcpa-prd-windows-iis-$(date +%Y%m%d)-v1.0.0"

aws ec2 create-image \
    --instance-id $INSTANCE_ID \
    --name "$AMI_NAME" \
    --description "InteliSrcPA Application AMI - prd - v1.0.0" \
    --no-reboot \
    --output json
```

Tagear:

```bash
AMI_ID="ami-0xxxxxxxxxxxxxxxxx"

aws ec2 create-tags --resources $AMI_ID --tags \
    Key=Name,Value=$AMI_NAME \
    Key=AppID,Value=22272 \
    Key=CostString,Value=1850.PA.135.601000 \
    Key=Application,Value=InteliSrcPA \
    Key=Environment,Value=prd \
    Key=Version,Value=1.0.0 \
    Key=BuildDate,Value=$(date +%Y%m%d)
```

---

## Paso 5: Verificar la AMI

### 5.1 — Esperar a que esté disponible

```bash
aws ec2 wait image-available --image-ids $AMI_ID
echo "AMI disponible: $AMI_ID"
```

### 5.2 — Verificar tags y estado

```bash
aws ec2 describe-images --image-ids $AMI_ID \
    --query "Images[0].[Name,State,Tags]" --output table
```

### 5.3 — Test funcional (opcional pero recomendado)

Lanzar una instancia de prueba desde la nueva AMI:

```bash
aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t3.medium \
    --subnet-id subnet-xxxxxxxx \
    --security-group-ids sg-xxxxxxxx \
    --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=AMI-Test},{Key=Purpose,Value=Test}]" \
    --output json
```

Conectar via SSM y validar:

```powershell
# IIS instalado?
(Get-WindowsFeature -Name Web-Server).InstallState

# W3SVC corriendo?
Get-Service W3SVC | Select Status

# Scripts existen?
Test-Path "C:\Scripts\Domain\Join-Domain.ps1"
Test-Path "C:\Scripts\Domain\Leave-Domain.ps1"
Test-Path "C:\Scripts\Startup\Mount-FsxShare.ps1"

# IIS responde?
(Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing).StatusCode
```

Terminar la instancia de prueba al finalizar:

```bash
aws ec2 terminate-instances --instance-ids i-0xxxxxxxxxxxxxxxxx
```

---

## Paso 6: Destruir la instancia builder

### 6.1 — Modificar terraform.tfvars

```hcl
# Volver a false
create_ami_builder_instance = false
```

### 6.2 — Ejecutar el pipeline

Commit + push → Jenkins ejecuta `terraform apply` → instancia, IAM role y SG se destruyen.

---

## Paso 7: Usar la AMI en producción

### 7.1 — Actualizar el AMI ID

Editar `iac/repo/intelisrcpa/{env}/terraform.tfvars`:

```hcl
# Para instancias standalone
ec2_windows = {
  "PAHQPAPAPP02" = {
    ami = "ami-0xxxxxxxxxxxxxxxxx"  # ← Nueva Application AMI
    # ...
  }
}

# O para el ASG (cuando se habilite)
# windows_ami = "ami-0xxxxxxxxxxxxxxxxx"
```

### 7.2 — Ejecutar pipeline de IaC

Commit + push → Jenkins aplica el cambio → instancias usan la nueva AMI.

---

## Troubleshooting

| Problema | Causa probable | Solución |
|----------|---------------|----------|
| Install-WindowsFeature falla | Sin internet (NAT Gateway) | Verificar SG egress y route table |
| SSM Session no conecta | Instance Profile sin `AmazonSSMManagedInstanceCore` | Verificar que `create_ami_builder_instance = true` se aplicó |
| Sysprep falla | EC2Launch no instalado o instancia ya sysprep'd | Verificar `C:\ProgramData\Amazon\EC2Launch\EC2Launch.exe` |
| AMI en "pending" mucho tiempo | Normal (10-30 min según disco) | `aws ec2 describe-images --image-ids ami-xxx --query "Images[0].State"` |
| `ec2:CreateImage` access denied | Instance Profile sin permisos | Verificar que el módulo `iam_ami_builder` se creó correctamente |

---

## Versionado de AMIs

| Campo | Convención |
|-------|------------|
| Nombre | `eec-aws-us-eits-intelisrcpa-{env}-windows-iis-{fecha}-v{version}` |
| Ejemplo | `eec-aws-us-eits-intelisrcpa-prd-windows-iis-20260724-v1.0.0` |
| Incrementar versión | Al cambiar features de IIS, actualizar scripts, o cambiar Golden AMI base |

---

## Checklist

- [ ] `create_ami_builder_instance = true` aplicado
- [ ] Instancia builder running y accesible via SSM
- [ ] Scripts copiados a `C:\Build\`
- [ ] `Build-AMI.ps1` ejecutado sin errores
- [ ] Validación interna pasó (IIS + scripts)
- [ ] AMI creada con estado `available`
- [ ] Tags correctos en la AMI
- [ ] Test funcional pasó (opcional)
- [ ] `create_ami_builder_instance = false` aplicado (instancia destruida)
- [ ] AMI ID actualizado en `terraform.tfvars`
- [ ] Pipeline de IaC ejecutado con nueva AMI
