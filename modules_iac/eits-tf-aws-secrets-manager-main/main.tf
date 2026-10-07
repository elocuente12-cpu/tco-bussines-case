module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-secrets-manager"
  tags        = var.tags
}

locals {
  tags = merge(var.tags, module.eits_ce_common.tags)
}


ephemeral "aws_secretsmanager_random_password" "this" {
  count = var.generate_random_password ? 1 : 0

  exclude_characters         = var.random_password_config.exclude_characters
  exclude_lowercase          = var.random_password_config.exclude_lowercase
  exclude_numbers            = var.random_password_config.exclude_numbers
  exclude_punctuation        = var.random_password_config.exclude_punctuation
  exclude_uppercase          = var.random_password_config.exclude_uppercase
  include_space              = var.random_password_config.include_space
  password_length            = var.random_password_config.password_length
  require_each_included_type = var.random_password_config.require_each_included_type
}

resource "aws_secretsmanager_secret" "this" {
  name                           = var.name
  name_prefix                    = var.name_prefix
  description                    = var.description
  kms_key_id                     = var.kms_key_id
  recovery_window_in_days        = var.recovery_window_in_days
  force_overwrite_replica_secret = var.force_overwrite_replica_secret
  policy                         = var.policy
  type                           = var.type

  dynamic "replica" {
    for_each = var.replicas != null ? var.replicas : []

    content {
      kms_key_id = replica.value.kms_key_id
      region     = replica.value.region
    }
  }

  tags = local.tags
}

resource "aws_secretsmanager_secret_policy" "this" {
  count = var.policy_override != null || length(concat(var.secret_users, var.secret_owners)) > 0 ? 1 : 0

  secret_arn = aws_secretsmanager_secret.this.arn
  policy     = var.policy_override != null ? var.policy_override : data.aws_iam_policy_document.this.json
}

resource "aws_secretsmanager_secret_rotation" "this" {
  count = var.rotation_lambda_arn != null || var.external_secret_rotation_role_arn != null ? 1 : 0

  secret_id                         = aws_secretsmanager_secret.this.id
  rotation_lambda_arn               = var.rotation_lambda_arn
  rotate_immediately                = var.rotate_immediately
  external_secret_rotation_role_arn = var.external_secret_rotation_role_arn

  dynamic "external_secret_rotation_metadata" {
    for_each = var.external_secret_rotation_metadata

    content {
      key   = external_secret_rotation_metadata.value.key
      value = external_secret_rotation_metadata.value.value
    }
  }

  rotation_rules {
    automatically_after_days = var.rotation_rules.automatically_after_days
    duration                 = var.rotation_rules.duration
    schedule_expression      = var.rotation_rules.schedule_expression
  }
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id                = aws_secretsmanager_secret.this.id
  secret_string_wo         = var.generate_random_password ? ephemeral.aws_secretsmanager_random_password.this[0].random_password : var.secret_string
  secret_string_wo_version = var.generate_random_password || var.secret_string != null ? var.secret_string_version : null
  secret_binary            = var.secret_binary
  version_stages           = var.version_stages

  lifecycle {
    # Allows migration from secret_string to secret_string_wo without resource recreation
    ignore_changes = [secret_string]
  }
}
