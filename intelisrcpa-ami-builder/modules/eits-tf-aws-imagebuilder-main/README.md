# EITS Cloud Enablement - EC2 Image Builder Module

Terraform module to create EC2 Image Builder pipelines for baking Application AMIs.
OS-agnostic: supports both Windows and Linux Golden AMI layering.

## Best Practices Implemented

Based on [AWS EC2 Image Builder official documentation](https://docs.aws.amazon.com/imagebuilder/latest/userguide/how-image-builder-works.html):

| Best Practice | Implementation |
|---------------|----------------|
| **Versionless parent image ARN** | Use `parent_image` with versionless ARN for automatic base image updates |
| **Dependency-aware scheduling** | `EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE` ensures builds only when updates exist |
| **AWSTOE component separation** | Build components (`build`/`validate` phases) separate from test components (`test` phase) |
| **Image testing before distribution** | `image_tests_enabled = true` by default; images only distribute if tests pass |
| **IMDSv2 enforcement** | `http_tokens = "required"` by default for build instances |
| **Encrypted volumes** | All EBS volumes encrypted by default with KMS support |
| **Cross-account distribution** | Launch permissions + KMS key policy for sharing AMIs |
| **SNS notifications** | Optional pipeline notifications for build lifecycle events |
| **Amazon Inspector scanning** | Optional vulnerability scanning of output images |
| **S3 logging** | AWSTOE logs exported to S3 for troubleshooting |

## Naming Convention

| Resource | Format |
|----------|--------|
| Infrastructure Config | `{name_prefix}-{environment}-imagebuilder-{identifier}-infra` |
| Image Recipe | `{name_prefix}-{environment}-imagebuilder-{identifier}-recipe` |
| Distribution Config | `{name_prefix}-{environment}-imagebuilder-{identifier}-distribution` |
| Image Pipeline | `{name_prefix}-{environment}-imagebuilder-{identifier}-pipeline` |
| Build Component | `{name_prefix}-{environment}-imagebuilder-{identifier}-{component_name}` |
| Test Component | `{name_prefix}-{environment}-imagebuilder-{identifier}-test-{component_name}` |
| Output AMI | `{name_prefix}-{environment}-imagebuilder-{identifier}-{buildDate}` |

## Usage: Windows IIS Application

```hcl
module "imagebuilder_windows_iis" {
  source = "../../modules/eits-tf-aws-imagebuilder-main"

  # General
  name_prefix = "eec-aws-us-eits-intelisrcpa"
  environment = "dev"
  identifier  = "windows-iis"
  region      = "us-east-1"
  os_family   = "windows"

  # Infrastructure
  instance_types        = ["m5.large"]
  instance_profile_name = aws_iam_instance_profile.imagebuilder.name
  subnet_id             = data.aws_subnets.private.ids[0]
  security_group_ids    = [aws_security_group.imagebuilder.id]
  s3_log_bucket         = "my-logs-bucket"

  # Recipe: Golden AMI Windows 2022
  parent_image   = "ami-08552a347fc5fd803"
  recipe_version = "1.0.0"

  # Build components (AWSTOE YAML documents)
  build_components = [
    {
      name        = "install-iis"
      description = "Install IIS with all features"
      version     = "1.0.0"
      data        = file("${path.module}/../../components/install-iis.yaml")
    },
    {
      name        = "configure-fsx"
      description = "Configure FSx mount scripts"
      version     = "1.0.0"
      data        = file("${path.module}/../../components/configure-fsx.yaml")
    }
  ]

  # External AWS managed components
  external_component_arns = [
    "arn:aws:imagebuilder:us-east-1:aws:component/amazon-cloudwatch-agent-windows/1.0.1/1"
  ]

  # Test components
  test_components = [
    {
      name        = "verify-iis"
      description = "Verify IIS is running"
      version     = "1.0.0"
      data        = file("${path.module}/../../components/test-iis.yaml")
    }
  ]

  # Distribution: share with QA, STG, PRO
  ami_share_account_ids = ["409447266290", "375662988321", "274193347839"]

  tags = {
    AppID       = "22272"
    CostString  = "1850.PA.135.601000"
  }
}
```

## Usage: Amazon Linux 2023 Application

```hcl
module "imagebuilder_linux_nginx" {
  source = "../../modules/eits-tf-aws-imagebuilder-main"

  name_prefix = "eec-aws-us-eits-myapp"
  environment = "dev"
  identifier  = "linux-nginx"
  region      = "us-east-1"
  os_family   = "linux"

  instance_types        = ["t3.medium"]
  instance_profile_name = aws_iam_instance_profile.imagebuilder.name
  subnet_id             = data.aws_subnets.private.ids[0]
  security_group_ids    = [aws_security_group.imagebuilder.id]
  s3_log_bucket         = "my-logs-bucket"

  # Use versionless ARN for auto-updates (best practice)
  parent_image   = "arn:aws:imagebuilder:us-east-1:aws:image/amazon-linux-2023-x86/x.x.x"
  recipe_version = "1.0.0"

  build_components = [
    {
      name        = "install-nginx"
      description = "Install and configure nginx"
      version     = "1.0.0"
      data = yamlencode({
        schemaVersion = "1.0"
        phases = [{
          name = "build"
          steps = [{
            name   = "InstallNginx"
            action = "ExecuteBash"
            inputs = { commands = ["yum install -y nginx", "systemctl enable nginx"] }
          }]
        }]
      })
    }
  ]

  external_component_arns = [
    "arn:aws:imagebuilder:us-east-1:aws:component/amazon-cloudwatch-agent-linux/1.0.1/1"
  ]

  # Schedule: weekly builds on Sunday 3 AM UTC
  schedule_expression                = "cron(0 3 ? * SUN *)"
  pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"

  tags = { AppID = "12345" }
}
```

## Usage: Cascading Pipeline (Auto-update on Golden AMI change)

```hcl
module "imagebuilder_auto_update" {
  source = "../../modules/eits-tf-aws-imagebuilder-main"

  # ... (same as above) ...

  # Use versionless ARN — pipeline auto-triggers when AWS updates the base
  parent_image = "arn:aws:imagebuilder:us-east-1:aws:image/windows-server-2022-english-full-base-x86/x.x.x"

  # Check daily, only build if parent image updated
  schedule_expression                = "cron(0 6 * * ? *)"
  pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
}
```

## AWSTOE Component Document Format

Components must follow the [AWSTOE schema](https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-use-documents.html):

```yaml
schemaVersion: "1.0"
phases:
  - name: build          # Runs during build stage (pre-snapshot)
    steps:
      - name: MyStep
        action: ExecutePowerShell   # Windows
        # action: ExecuteBash       # Linux
        timeoutSeconds: 600
        onFailure: Abort
        inputs:
          commands:
            - |
              # Your PowerShell/Bash script here
  - name: validate       # Optional: runs after build, before snapshot
    steps:
      - name: ValidateStep
        action: ExecutePowerShell
        inputs:
          commands:
            - |
              # Validation logic
```

For test components (run post-snapshot on a fresh instance):

```yaml
schemaVersion: "1.0"
phases:
  - name: test
    steps:
      - name: VerifyService
        action: ExecutePowerShell
        inputs:
          commands:
            - |
              $svc = Get-Service -Name W3SVC
              if ($svc.Status -ne 'Running') { exit 1 }
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5 |
| aws | >= 5.37 |

## Resources Created

| Resource | Condition |
|----------|-----------|
| `aws_imagebuilder_component` (build) | When `build_components` is not empty |
| `aws_imagebuilder_component` (test) | When `test_components` is not empty |
| `aws_imagebuilder_infrastructure_configuration` | Always |
| `aws_imagebuilder_image_recipe` | Always |
| `aws_imagebuilder_distribution_configuration` | Always |
| `aws_imagebuilder_image_pipeline` | Always |

## Outputs

| Name | Description |
|------|-------------|
| pipeline_arn | Image Builder pipeline ARN (for triggering builds) |
| pipeline_name | Pipeline name |
| recipe_arn | Image recipe ARN |
| infrastructure_configuration_arn | Infrastructure config ARN |
| distribution_configuration_arn | Distribution config ARN |
| build_component_arns | Map of build component name => ARN |
| test_component_arns | Map of test component name => ARN |
