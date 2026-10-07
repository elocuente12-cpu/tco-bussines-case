# test region
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# locals
locals {
  account_id = data.aws_caller_identity.current.account_id
}

# test module - create a simple s3 key
module "kms" {
  source = "./../.."

  aliases     = ["testalias"]
  prefix      = "eits-tf-aws-kms-test"
  description = "Example KMS key for S3 buckets"
  key_owners = [
    "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${local.account_id}:root"
  ]
  key_administrators = [
    "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${local.account_id}:role/eec-aws-infrastructure-deployment-role",
    "arn:aws:iam::${local.account_id}:root"
  ]
  key_users = [
    "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${local.account_id}:role/eec-aws-infrastructure-deployment-role",
  ]
  key_services = ["logging.s3"]

  # test grants
  grants = {
    s3_logging = {
      name              = "s3-logging-grant"
      grantee_principal = "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole"
      operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
    }
  }

  tags = var.tags
}
