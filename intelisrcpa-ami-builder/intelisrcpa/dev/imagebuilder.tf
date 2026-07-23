##############################################
# Image Builder Pipeline (via module)
#
# El módulo se encarga de crear:
# - Components (build + test) a partir de AWSTOE YAML docs
# - Infrastructure Configuration
# - Image Recipe (parent image + components + block devices)
# - Distribution Configuration (cross-account sharing)
# - Image Pipeline
#
# El consumidor solo define los AWSTOE YAML documents
# con la lógica de sus scripts.
##############################################

module "imagebuilder" {
  source = "../../modules/eits-tf-aws-imagebuilder-main"

  # ─── General ───────────────────────────────────────
  name_prefix = local.name_prefix
  environment = var.tagenv
  identifier  = var.imagebuilder_identifier
  region      = var.region
  os_family   = "windows"

  # ─── Infrastructure ────────────────────────────────
  instance_types        = var.instance_types
  instance_profile_name = aws_iam_instance_profile.imagebuilder.name
  subnet_id             = data.aws_subnets.private.ids[0]
  security_group_ids    = [aws_security_group.imagebuilder.id]
  s3_log_bucket         = var.s3_log_bucket

  # IMDSv2 enforced (best practice)
  instance_metadata_http_tokens = "required"

  # ─── Image Recipe ──────────────────────────────────
  parent_image   = var.parent_image_ami
  recipe_version = var.recipe_version

  block_device_mappings = [
    {
      device_name = "/dev/sda1"
      ebs = {
        delete_on_termination = true
        encrypted             = true
        kms_key_id            = module.kms_imagebuilder.key_arn
        volume_size           = var.root_volume_size
        volume_type           = "gp3"
      }
    }
  ]

  # No desinstalar SSM agent (necesario para domain join en runtime)
  uninstall_ssm_agent_after_build = false

  # ─── Build Components (AWSTOE YAML) ───────────────
  # Ejecutados en orden durante build stage (pre-snapshot):
  #   1. Install IIS → 2. Configure FSx → 3. Domain Join Prep
  build_components = [
    {
      name        = "install-iis"
      description = "Install IIS Web Server with .NET features"
      version     = var.recipe_version
      data        = file("${path.module}/../../components/install-iis.yaml")
    },
    {
      name        = "configure-fsx-mount"
      description = "Prepare FSx mount scripts for runtime"
      version     = var.recipe_version
      data        = file("${path.module}/../../components/configure-fsx-mount.yaml")
    },
    {
      name        = "domain-join-prep"
      description = "Prepare domain join/leave scripts for runtime"
      version     = var.recipe_version
      data        = file("${path.module}/../../components/domain-join-prep.yaml")
    }
  ]

  # ─── External Components (AWS Managed) ─────────────
  external_component_arns = [
    "arn:aws:imagebuilder:us-east-1:aws:component/amazon-cloudwatch-agent-windows/1.0.1/1"
  ]

  # ─── Test Components (post-snapshot validation) ────
  # Se ejecutan en una instancia fresca lanzada desde el snapshot.
  # Si alguno falla, la AMI NO se distribuye.
  test_components = [
    {
      name        = "test-iis-service"
      description = "Validate IIS, .NET, and runtime scripts on fresh instance"
      version     = var.recipe_version
      data        = file("${path.module}/../../components/test-iis-service.yaml")
    }
  ]

  # ─── Distribution ──────────────────────────────────
  ami_share_account_ids   = var.ami_share_account_ids
  distribution_kms_key_id = module.kms_imagebuilder.key_arn

  ami_tags = {
    Application   = "InteliSrcPA"
    AppID         = var.appId
    CostString    = var.costString
    ResourceOwner = var.ResourceOwner
  }

  # ─── Pipeline ──────────────────────────────────────
  # Manual execution (triggered by Jenkins).
  # Para auto-rebuild semanal, descomentar schedule_expression.
  pipeline_status     = "ENABLED"
  schedule_expression = null
  # schedule_expression                = "cron(0 3 ? * SUN *)"
  # pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"

  image_tests_enabled         = true
  image_tests_timeout_minutes = 90

  # ─── Tags ──────────────────────────────────────────
  tags = {
    ResourceOwner = var.ResourceOwner
    Application   = "InteliSrcPA"
  }
}
