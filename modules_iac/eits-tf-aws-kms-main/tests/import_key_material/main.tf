# test region
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# locals
locals {
  account_id = data.aws_caller_identity.current.account_id
}

# test module - create a key to test module defaults
# it is recommend NOT to do this, this is for testing only
module "kms" {
  source = "./../.."

  external_key        = true
  aliases             = ["testalias"]
  prefix              = "eits-tf-aws-kms-defaults"
  description         = "Basic key with all defaults"
  is_enabled          = true
  key_material_base64 = filebase64("PlaintextKeyMaterial.bin")

  grants = {
    s3_logging = {
      name              = "s3-logging-grant"
      grantee_principal = "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole"
      operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
    }
  }

  tags = var.tags
}
