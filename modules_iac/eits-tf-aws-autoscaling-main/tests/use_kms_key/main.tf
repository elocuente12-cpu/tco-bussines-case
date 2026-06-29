# test region
provider "aws" {
  region = var.region
}

# locals
locals {
  name = "eits-tf-aws-autoscaling-use-kms"
}

# create test security group
module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git"

  security_group_name        = local.name
  security_group_description = "For eits-tf-aws-autoscaling module testing"
  vpc_id                     = var.vpc_id
  security_group_ingress_rules = [
    {
      description = "Ping"
      from_port   = 8
      to_port     = 0
      protocol    = "icmp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
  ]
  security_group_egress_rules = [
    {
      description = "Centrify"
      from_port   = 389
      to_port     = 389
      protocol    = "tcp"
      cidr_blocks = ["194.60.173.145/32", "194.60.173.146/32", "194.60.173.147/32"]
    }
  ]

  tags = var.tags
}

# get account id
data "aws_caller_identity" "current" {}

# create kms key for ebs volumes
module "kms_key" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git?ref=1.3.0"

  description = "KMS key for autoscaling group ${local.name} instances"
  key_owners = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eec-aws-infrastructure-deployment-role",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
  key_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling_${local.name}",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/eec-aws-infrastructure-deployment-role",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BURoleForAWSBackup"
  ]
  key_service_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling_${local.name}"
  ]

  tags = var.tags
}

# test module
# example of creating an autoscaling group with a new launch template and encrypting volumes with a custom kms key
module "autoscaling" {
  source = "./../.."

  name                      = local.name
  ami                       = "rhel_9"
  min_size                  = 1
  max_size                  = 2
  wait_for_capacity_timeout = 0
  default_instance_warmup   = 300
  health_check_type         = "EC2"
  subnet_ids                = var.subnet_ids

  # create launch template
  launch_template_config = {
    instance_type          = "t3.micro"
    security_groups        = [module.security_group.id]
    update_default_version = true
    instance_tags = {
      adDomain = "gdc.local"
      adGroup  = "WS-ADM_example_ec2_servers"
    }
  }

  # encypt root volume with custom key
  root_block_device = {
    encrypted  = true
    kms_key_id = module.kms_key.key_arn
  }

  # add new sde volume with custom key
  block_device_mappings = [
    {
      device_name = "/dev/sde"
      ebs = {
        encrypted             = true
        kms_key_id            = module.kms_key.key_arn
        delete_on_termination = true
        volume_size           = 30
        volume_type           = "gp3"
      }
    }
  ]

  tags = var.tags
}
