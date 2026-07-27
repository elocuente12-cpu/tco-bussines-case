# Proceso Manual de Construcción de AMI

Cuando EC2 Image Builder no está disponible, usar estos scripts para construir
Application AMIs manualmente sobre la Golden AMI de Experian.

## Pre-requisitos

- Instancia EC2 lanzada desde la Golden AMI EEC (Windows 2022/2025)
- Instance Profile con permisos: `ec2:CreateImage`, `ec2:CreateTags`, `ssm:*`
- PowerShell con permisos de administrador
- Conectividad a internet (para descargar Windows Features)
- AWS CLI disponible en la instancia

## Uso Rápido

```powershell
# Copiar la carpeta 'manual/' a la instancia (via S3, RDP, o SSM)
# Luego ejecutar:
.\Build-AMI.ps1 -AmiName "eec-aws-us-eits-intelisrcpa-dev-windows-iis" -AppVersion "1.0.0" -Environment "dev"
```

## Pasos del Orquestador

| Paso | Script | Qué hace |
|------|--------|----------|
| 1 | `01-install-iis.ps1` | Instala IIS + .NET 4.5 + configura AppPool |
| 2 | `02-configure-fsx-mount.ps1` | Crea `C:\Scripts\Startup\Mount-FsxShare.ps1` |
| 3 | `03-domain-join-prep.ps1` | Crea `Join-Domain.ps1` y `Leave-Domain.ps1` |
| 4 | (validación interna) | Verifica que todo existe y IIS funciona |
| 5 | Sysprep | Generaliza la instancia (EC2Launch v2) |
| 6 | `aws ec2 create-image` | Crea la AMI y la tagea |

## Opciones del Orquestador

```powershell
# Build completo (Sysprep + crear AMI)
.\Build-AMI.ps1 -AmiName "mi-ami" -AppVersion "1.0.0"

# Solo instalar y validar (sin Sysprep ni AMI)
.\Build-AMI.ps1 -AmiName "mi-ami" -AppVersion "1.0.0" -SkipSysprep -SkipAmiCreation

# Instalar + crear AMI sin Sysprep (para debug)
.\Build-AMI.ps1 -AmiName "mi-ami" -AppVersion "1.0.0" -SkipSysprep
```

## Flujo Recomendado para Producción

```
1. Lanzar instancia desde Golden AMI en la cuenta destino
2. Conectar via SSM Session Manager (o RDP)
3. Copiar scripts: aws s3 cp s3://bucket/manual/ C:\Build\ --recursive
4. Ejecutar: C:\Build\Build-AMI.ps1 -AmiName "..." -AppVersion "1.2.0" -Environment "prd"
5. Esperar a que la AMI esté 'available'
6. Actualizar el AMI ID en iac/repo/intelisrcpa/{env}/terraform.tfvars
7. Aplicar terraform para actualizar Launch Template / ASG
```

## Notas

- **Sysprep**: generaliza la instancia (remueve SID, resetea hostname). Es necesario
  para que el domain join funcione correctamente con hostnames únicos.
- **--no-reboot**: la AMI se crea sin reiniciar la instancia. Si hiciste Sysprep,
  la instancia ya está apagada y creas la AMI desde tu CLI local.
- **Versionado**: usa el formato `{nombre}-{fecha}-v{version}` para identificar AMIs.
