# test region
provider "aws" {
  region = var.region
}

# test module - create a key to test module defaults
# it is recommend NOT to do this, this is for testing only
module "kms" {
  source = "./../.."

  prefix      = "eits-tf-aws-kms-defaults"
  description = "Basic key with all defaults"

  tags = var.tags
}
