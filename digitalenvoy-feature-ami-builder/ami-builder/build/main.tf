module "global_variables" {
  source = "../../modules/variables"
}

module "local_variables" {
  source = "../modules/variables"

  team   = module.global_variables.team
  region = module.global_variables.region
}

locals {
  # Keep east names unchanged; suffix west resources to avoid global IAM/policy name collisions.
  imagebuilder_server_name = local.is_west_workspace ? "${module.local_variables.server}-west" : module.local_variables.server
}

module "imagebuilder" {
  source = "git::ssh://git@code.experian.local/nadasre/ami-ec2-image-builder.git?ref=fa/update_ami"


  team                  = module.local_variables.team
  instance_vpc_name     = "EEC-VPC"
  instance_subnet_name  = "EEC-PrivateSubnet1A"
  server                = local.imagebuilder_server_name
  get_artifacts_from_s3 = true
  os                    = "amzn_lnx_2023" # It could be one of [linux, windows_2019, windows_2022]

  components = module.local_variables.imageBuilderComponents

  component_external_arns = ["arn:aws:imagebuilder:${module.local_variables.region}:aws:component/amazon-cloudwatch-agent-linux/1.0.1/1"]
  image_recipe_version    = "1.0.28"

  block_device_mapping = [
    {
      device_name  = "/dev/xvda"
      no_device    = null
      virtual_name = null
      ebs = {
        device_name           = "/dev/xvda"
        delete_on_termination = true
        volume_size           = module.local_variables.root_volume_size
        volume_type           = "gp3"
        encrypted             = true
        kms_key_id            = local.is_west_workspace ? data.aws_kms_alias.digital_envoy_ami_sharing_key_west[0].target_key_arn : aws_kms_key.digital_envoy_ami_sharing_key[0].arn
      }
    },
    {
      device_name  = "/dev/sda1"
      no_device    = null
      virtual_name = null
      ebs = {
        device_name           = "/dev/sda1"
        delete_on_termination = true
        volume_size           = module.local_variables.volume_size
        volume_type           = "gp3"
        encrypted             = true
        kms_key_id            = local.is_west_workspace ? data.aws_kms_alias.digital_envoy_ami_sharing_key_west[0].target_key_arn : aws_kms_key.digital_envoy_ami_sharing_key[0].arn
      }
    }
    # Add more block_device_mapping objects for additional EBS volumes
  ]

  instance_types       = module.local_variables.instance_types
  enable_resource_tags = true
  tags                 = module.local_variables.common_tags

  create_distribution_configuration = true
  distribution_configuration_region = module.local_variables.region

  ami_distribution_configuration = {
    name = module.local_variables.name
    ami_tags = {
      CostCenter = "IT"
    }
  }

  # NOTE: The current module ref does not support a secondary distribution regions input.

  image_tests_configuration_schedule_enabled    = true
  image_tests_configuration_schedule_expression = "cron(0 0 * * ? *)"
}
