# Test region
provider "aws" {
  region = var.region
}

data "aws_vpc" "this" {}

# Locals
locals {
  security_group_ingress_rules = [
    {
      description = "SMB client"
      from_port   = 445
      to_port     = 445
      protocol    = "tcp"
      cidr_blocks = data.aws_vpc.this.cidr_block_associations[*].cidr_block
    },
    {
      description = "Administration"
      from_port   = 5985
      to_port     = 5985
      protocol    = "tcp"
      cidr_blocks = data.aws_vpc.this.cidr_block_associations[*].cidr_block
    },
  ]
  security_group_egress_rules = [
    {
      description = "Allow all egress"
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

module "fsx_security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git"

  security_group_name          = "eits_test_fsx"
  security_group_description   = "Security group for FSx Windows File Server eits-test-fsx"
  vpc_id                       = var.vpc_id
  security_group_ingress_rules = local.security_group_ingress_rules
  security_group_egress_rules  = local.security_group_egress_rules

  tags = var.tags
}

module "fsx_cloudwatch_log_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs"

  log_group_name    = "/aws/fsx/eits_test_fsx"
  retention_in_days = 7
  resource_policy_principals = {
    Service = ["fsx.amazonaws.com"]
  }

  tags = var.tags
}

# Create an FSx for Windows file system with a security group and CloudWatch Log Group created by the module
module "fsx" {
  source = "./../.."

  name                            = "eits-test-fsx"
  aliases                         = ["eits-test-fsx.uk.experian.local"]
  subnet_ids                      = var.subnet_ids
  security_group_ids              = [module.fsx_security_group.id]
  throughput_capacity             = 8
  deployment_type                 = "SINGLE_AZ_2"
  storage_type                    = "HDD"
  storage_capacity                = 2000
  automatic_backup_retention_days = 0
  skip_final_backup               = true
  weekly_maintenance_start_time   = "6:22:00"
  disk_iops_configuration = {
    iops = 10
    mode = "AUTOMATIC"
  }
  audit_log_configuration = {
    audit_log_destination             = module.fsx_cloudwatch_log_group.log_group_arn
    audit_log_status                  = "FAILURE_ONLY"
    file_share_access_audit_log_level = "FAILURE_ONLY"
  }
  self_managed_active_directory = {
    dns_ips                                = ["10.173.251.106", "10.215.252.10"]
    domain_name                            = "uk.experian.local"
    username                               = var.ad_username
    password                               = var.ad_password
    file_system_administrators_group       = "FSx_admins"
    organizational_unit_distinguished_name = "OU=FSx,OU=uk,OU=experian,OU=local"
  }

  tags = var.tags
}
