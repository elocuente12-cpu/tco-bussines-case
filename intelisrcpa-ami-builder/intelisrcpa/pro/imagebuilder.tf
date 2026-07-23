##############################################
# Image Builder Pipeline (via module)
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

  uninstall_ssm_agent_after_build = false

  # ─── Build Components ──────────────────────────────
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

  external_component_arns = [
    "arn:aws:imagebuilder:us-east-1:aws:component/amazon-cloudwatch-agent-windows/1.0.1/1"
  ]

  # ─── Test Components ───────────────────────────────
  test_components = [
    {
      name        = "test-iis-service"
      description = "Validate IIS, .NET, and runtime scripts on fresh instance"
      version     = var.recipe_version
      data        = file("${path.module}/../../components/test-iis-service.yaml")
    }
  ]

  # ─── Distribution ──────────────────────────────────
  # Pro no comparte con nadie (es el destino final)
  ami_share_account_ids   = var.ami_share_account_ids
  distribution_kms_key_id = module.kms_imagebuilder.key_arn

  ami_tags = {
    Application   = "InteliSrcPA"
    AppID         = var.appId
    CostString    = var.costString
    ResourceOwner = var.ResourceOwner
  }

  # ─── Pipeline ──────────────────────────────────────
  pipeline_status             = "ENABLED"
  schedule_expression         = null
  image_tests_enabled         = true
  image_tests_timeout_minutes = 90

  tags = {
    ResourceOwner = var.ResourceOwner
    Application   = "InteliSrcPA"
  }
}
