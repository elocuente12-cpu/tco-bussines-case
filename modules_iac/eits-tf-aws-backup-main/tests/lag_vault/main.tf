provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

module "kms" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  prefix      = "test-backup-lag"
  description = "Test KMS key for AWS Backup LAG vault testing"
  key_owners = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
  key_administrators = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
  ]
  key_users = [
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BUAdministratorAccessRole"
  ]
  key_services = ["backup"]
}

module "aws_backup_vault" {
  source = "../.."

  create_backup_vault = true
  vault_name          = "tf-vault-test-primary"
  vault_kms_key_arn   = module.kms.key_arn
  vault_force_destroy = true # for testing purposes

  # Create IAM role
  create_backup_iam_role = true
  iam_role_name          = "TFAWSBackupTest"
  iam_policy_name        = "TFAWSBackupTest"

  backup_enabled = false

  tags = var.tags
}

module "aws_backup_int_vault" {
  source = "../.."

  create_backup_vault    = true
  vault_name             = "tf-vault-test-int"
  vault_kms_key_arn      = module.kms.key_arn
  backup_enabled         = false
  manage_region_settings = false
  create_backup_iam_role = false
  create_vault_policy    = false
  iam_role_arn           = module.aws_backup_vault.backup_iam_role

  tags = var.tags
}

module "aws_backup_lag_vault" {
  source = "../.."

  backup_enabled            = false
  manage_region_settings    = false
  create_backup_lag_vault   = true
  iam_role_arn              = module.aws_backup_vault.backup_iam_role
  lag_vault_name            = "tf-vault-test-lag"
  lag_vault_shared_accounts = var.lag_vault_shared_accounts
  copy_to_lag               = true
  intermediate_vault_name   = module.aws_backup_int_vault.backup_vault_id

  tags = var.tags
}

module "aws_backup_plan" {
  source = "../.."

  vault_name       = module.aws_backup_vault.backup_vault_id
  backup_enabled   = true
  backup_plan_name = "tf-plan-1"
  iam_role_arn     = module.aws_backup_vault.backup_iam_role
  backup_rules = [
    {
      rule_name         = "tf-backup-rule-1"
      target_vault_name = module.aws_backup_vault.backup_vault_id
      schedule          = "cron(0 1 ? * * *)"
      start_window      = 60
      completion_window = 720
      lifecycle = {
        cold_storage_after = 0
        delete_after       = 1
      }
      copy_actions = [{
        destination_vault_arn = module.aws_backup_int_vault.backup_vault_arn
        lifecycle = {
          cold_storage_after = 0
          delete_after       = 3
        }
      }]
    }
  ]
  vss_enabled = true
  # No need to duplicate region settings
  manage_region_settings = false

  # Backup selection rule
  backup_selections = [
    {
      name      = "tf-ruleselection-1"
      resources = ["*"]
      conditions = {
        string_equals = [
          {
            key   = "aws:ResourceTag/backup_to_lag"
            value = "yes"
          }
        ]
      }
    }
  ]

  tags = var.tags
}
