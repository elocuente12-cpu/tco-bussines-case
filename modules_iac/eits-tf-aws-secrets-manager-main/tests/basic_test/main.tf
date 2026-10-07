# test region
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# create kms key
module "kms_key" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  description = "KMS key for testing Secret Manager module"
  key_owners  = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BUAdministratorAccessRole"]
  key_users   = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BUAdministratorAccessRole"]
  tags        = var.tags
}

# test module
module "secrets" {
  source = "../../."

  name          = "eits-tf-aws-secrets-manager"
  description   = "Test for Secret Manager module"
  kms_key_id    = module.kms_key.key_id
  secret_owners = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BUAdministratorAccessRole"]

  # generate a random password, note this cannot be changed by terraform after creation
  generate_random_password = true

  # test values - not recommended for prod
  recovery_window_in_days        = 7
  force_overwrite_replica_secret = true
  tags                           = var.tags
}
