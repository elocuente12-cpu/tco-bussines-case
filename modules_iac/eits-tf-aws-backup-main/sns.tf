locals {
  default_backup_events = ["BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED", "RESTORE_JOB_COMPLETED"]
  allowed_events = ["BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED",
    "COPY_JOB_STARTED", "COPY_JOB_SUCCESSFUL", "COPY_JOB_FAILED",
    "RESTORE_JOB_STARTED", "RESTORE_JOB_COMPLETED", "RECOVERY_POINT_MODIFIED",
  "S3_BACKUP_OBJECT_FAILED", "S3_RESTORE_OBJECT_FAILED"]
}

# Create SNS topic
module "backup_events_sns" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sns.git?ref=1.8.0"

  count = length(var.backup_notifications) > 0 && lookup(var.backup_notifications, "sns_topic_arn", null) == null ? 1 : 0

  name                        = length(var.backup_sns_topic_name) > 0 ? var.backup_sns_topic_name : "aws-backup-events"
  name_prefix                 = var.backup_sns_topic_name_prefix
  kms_master_key_id           = var.sns_kms_key_id
  policy_allowed_aws_services = ["backup.amazonaws.com"]
  subscribers                 = lookup(var.backup_notifications, "subscribers", null)
  disable_default_alarms      = true
  tags                        = local.tags
}

# Backup events
resource "aws_backup_vault_notifications" "backup_events" {
  count = length(var.backup_notifications) > 0 ? 1 : 0

  backup_vault_name   = var.vault_name != null ? var.vault_name : "Default"
  sns_topic_arn       = lookup(var.backup_notifications, "sns_topic_arn", module.backup_events_sns[0].topic_arn)
  backup_vault_events = lookup(var.backup_notifications, "backup_vault_events", local.default_backup_events)

  depends_on = [aws_backup_vault.bkp_vault]
}
