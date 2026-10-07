locals {
  backup_role_arn = try(module.bkp_iam_role[0].role_arn, var.iam_role_arn)
}

# AWS Backup logically air gapped (LAG) vault

resource "aws_backup_logically_air_gapped_vault" "this" {
  count = var.create_backup_lag_vault ? 1 : 0

  name               = var.lag_vault_name
  max_retention_days = var.lag_vault_lock_config.max_retention_days
  min_retention_days = var.lag_vault_lock_config.min_retention_days
  encryption_key_arn = var.lag_vault_encryption_key_arn
  tags               = local.tags
}

resource "aws_backup_vault_policy" "lag_vault" {
  count = var.create_backup_lag_vault ? 1 : 0

  backup_vault_name = aws_backup_logically_air_gapped_vault.this[0].name
  policy            = var.lag_vault_policy == null ? data.aws_iam_policy_document.aws_backup_lag_vault[0].json : var.lag_vault_policy
}

resource "aws_ram_resource_share" "lag_vault" {
  count = var.create_backup_lag_vault && length(var.lag_vault_shared_accounts) > 0 ? 1 : 0

  name                      = "${var.lag_vault_name}-share"
  allow_external_principals = false

  tags = local.tags
}

resource "aws_ram_resource_association" "this" {
  count = var.create_backup_lag_vault && length(var.lag_vault_shared_accounts) > 0 ? 1 : 0

  resource_arn       = aws_backup_logically_air_gapped_vault.this[0].arn
  resource_share_arn = aws_ram_resource_share.lag_vault[0].arn
}

resource "aws_ram_principal_association" "this" {
  for_each = var.create_backup_lag_vault && length(var.lag_vault_shared_accounts) > 0 ? toset(var.lag_vault_shared_accounts) : []

  principal          = each.key
  resource_share_arn = aws_ram_resource_share.lag_vault[0].arn
}

# LAG vault copy via intermediate vault (when AMKs are used for resources like EBS)

module "iam_role_lag_lambda" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = var.copy_to_lag ? 1 : 0

  role_name          = "LAGVaultCopyLambda"
  role_description   = "IAM role for AWS Backup LAG vault copy Lambda function"
  policy_name        = "LAGVaultCopyLambda"
  policy_description = "IAM policy for AWS Backup LAG vault copy Lambda function"
  assume_role_policy = data.aws_iam_policy_document.aws_backup_lag_lambda_assume_role[0].json
  policy_documents   = [data.aws_iam_policy_document.aws_backup_lag_lambda_role[0].json]

  tags = local.tags
}

# LAMBDA

data "archive_file" "lambda_copy_to_lag_zip" {
  count = var.copy_to_lag ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/src/lambda_copy_to_lag.py"
  output_path = "${path.module}/src/lambda_copy_to_lag.zip"
}

data "archive_file" "lambda_cleanup_temp_vault_zip" {
  count = var.copy_to_lag ? 1 : 0

  type        = "zip"
  source_file = "${path.module}/src/lambda_cleanup_temp_vault.py"
  output_path = "${path.module}/src/lambda_cleanup_temp_vault.zip"
}

module "lambda_copy_to_lag" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git?ref=1.11.1"
  count  = var.copy_to_lag ? 1 : 0

  function_scope                    = "aws_backup_lag_vault_copy"
  description                       = "Copies AWS Backup recovery points from source vault to destination LAG vault"
  filename                          = data.archive_file.lambda_copy_to_lag_zip[0].output_path
  source_code_hash                  = data.archive_file.lambda_copy_to_lag_zip[0].output_base64sha256
  handler                           = "lambda_copy_to_lag.lambda_handler"
  runtime                           = "python3.14"
  memory_size                       = 256
  role                              = module.iam_role_lag_lambda[0].role_arn
  timeout                           = 60
  cloudwatch_logs_retention_in_days = 30
  lambda_environment = {
    variables = {
      BACKUP_ROLE_ARN       = local.backup_role_arn
      DESTINATION_VAULT_ARN = "arn:aws:backup:eu-west-2:${data.aws_caller_identity.current.account_id}:backup-vault:${var.lag_vault_name}"
      RETENTION_DAYS        = var.lag_vault_max_retention_days
    }
  }
}

module "lambda_cleanup_temp_vault" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git?ref=1.11.1"
  count  = var.copy_to_lag ? 1 : 0

  function_scope                    = "aws_backup_lag_vault_cleanup"
  description                       = "Deletes recovery points from intermediate vault after successful copy to LAG vault"
  filename                          = data.archive_file.lambda_cleanup_temp_vault_zip[0].output_path
  source_code_hash                  = data.archive_file.lambda_cleanup_temp_vault_zip[0].output_base64sha256
  handler                           = "lambda_cleanup_temp_vault.lambda_handler"
  runtime                           = "python3.14"
  memory_size                       = 256
  role                              = module.iam_role_lag_lambda[0].role_arn
  timeout                           = 60
  cloudwatch_logs_retention_in_days = 30
  lambda_environment = {
    variables = {
      INTERMEDIATE_VAULT_NAME = var.intermediate_vault_name
    }
  }
}

# give Eventbridge permission to trigger lambda
resource "aws_lambda_permission" "allow_eventbridge_copy_to_lag" {
  count = var.copy_to_lag ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_copy_to_lag[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge_backup_lag_copy[0].rule_arn
}

resource "aws_lambda_permission" "allow_eventbridge_cleanup_temp_vault" {
  count = var.copy_to_lag ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_cleanup_temp_vault[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = module.eventbridge_backup_cleanup_temp_vault[0].rule_arn
}

# EVENTBRIDGE

module "eventbridge_backup_lag_copy" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git?ref=2.5.1"
  count  = var.copy_to_lag ? 1 : 0

  name            = "aws-backup-lag-copy"
  description     = "Triggers LAG vault copy Lambda when a copy job completes to ${var.lag_vault_name}-intermediate vault"
  create_iam_role = false
  event_pattern_json = jsonencode({
    "source" : ["aws.backup"],
    "detail-type" : ["Copy Job State Change"],
    "detail" : {
      "state" : ["COMPLETED"],
      "destinationBackupVaultArn" : ["arn:aws:backup:eu-west-2:${data.aws_caller_identity.current.account_id}:backup-vault:${var.intermediate_vault_name}"]
    }
  })
  rule_targets = {
    lambda_backup_lag_copy = {
      arn = module.lambda_copy_to_lag[0].arn
    }
  }

  tags = local.tags
}

module "eventbridge_backup_cleanup_temp_vault" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git?ref=2.5.1"
  count  = var.copy_to_lag ? 1 : 0

  name            = "aws-backup-lag-cleanup-temp-vault"
  description     = "Triggers cleanup Lambda when copy job completes to LAG vault"
  create_iam_role = false
  event_pattern_json = jsonencode({
    "source" : ["aws.backup"],
    "detail-type" : ["Copy Job State Change"],
    "detail" : {
      "state" : ["COMPLETED"],
      "destinationBackupVaultArn" : ["arn:aws:backup:eu-west-2:${data.aws_caller_identity.current.account_id}:backup-vault:${var.lag_vault_name}"]
    }
  })
  rule_targets = {
    lambda_backup_lag_cleanup = {
      arn = module.lambda_cleanup_temp_vault[0].arn
    }
  }

  tags = local.tags
}
