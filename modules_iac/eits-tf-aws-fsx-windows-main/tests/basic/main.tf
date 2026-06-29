# Test region
provider "aws" {
  region = var.region
}

# Locals
locals {
}

# Create an FSx for Windows file system with a security group and CloudWatch Log Group created by the module
module "fsx" {
  source = "./../.."

  name                        = "eits-test-fsx"
  subnet_ids                  = var.subnet_ids
  throughput_capacity         = 8
  create_cloudwatch_log_group = true

  self_managed_active_directory = {
    dns_ips     = ["10.173.251.106", "10.215.252.10"]
    domain_name = "uk.experian.local"
    username    = var.ad_username
    password    = var.ad_password
  }
  automatic_backup_retention_days = 0
  skip_final_backup               = true

  tags = var.tags

}
