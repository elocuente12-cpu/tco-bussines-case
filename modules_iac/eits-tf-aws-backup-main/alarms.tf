locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false
  alarm_data = {
    NumberOfBackupJobsFailed = {
      alarm_description   = "The number of backup jobs with status of Failed."
      metric_name         = "NumberOfBackupJobsFailed"
      statistic           = "Maximum"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      period              = 3600
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      alarm_enabled       = var.enable_vault_alarms.NumberOfBackupJobsFailed
    },
    NumberOfBackupJobsExpired = {
      alarm_description   = "The number of backup jobs that have a status of EXPIRED."
      metric_name         = "NumberOfBackupJobsExpired"
      statistic           = "Maximum"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      period              = 3600
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      alarm_enabled       = var.enable_vault_alarms.NumberOfBackupJobsExpired
    },
    NumberOfBackupJobsAborted = {
      alarm_description   = "The number of user cancelled backup jobs."
      metric_name         = "NumberOfBackupJobsAborted"
      statistic           = "Maximum"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      period              = 3600
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      alarm_enabled       = var.enable_vault_alarms.NumberOfBackupJobsAborted
    },
    NumberOfCopyJobsFailed = {
      alarm_description   = "The number of cross-account and cross-Region copy jobs that AWS Backup attempted but could not complete."
      metric_name         = "NumberOfCopyJobsFailed"
      statistic           = "Maximum"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      period              = 3600
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      alarm_enabled       = var.enable_vault_alarms.NumberOfCopyJobsFailed
    },
    NumberOfRestoreJobsFailed = {
      alarm_description   = "The number of restore jobs that AWS Backup attempted but could not complete."
      metric_name         = "NumberOfRestoreJobsFailed"
      statistic           = "Maximum"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      period              = 3600
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      alarm_enabled       = var.enable_vault_alarms.NumberOfRestoreJobsFailed
    },
    NumberOfRecoveryPointsExpired = {
      alarm_description   = "The number of recovery points that AWS Backup attempted to delete based on your backup retention lifecycle, but could not delete."
      metric_name         = "NumberOfRecoveryPointsExpired"
      statistic           = "Maximum"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      period              = 3600
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
      alarm_enabled       = var.enable_vault_alarms.NumberOfRecoveryPointsExpired
    }
  }
}

module "alarm" {
  source   = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.0"
  for_each = var.create_backup_vault ? { for k, v in local.alarm_data : k => v if v.alarm_enabled } : {}

  alarm_name        = format("AWS/Backup %s BackupVault=%s", each.value.metric_name, aws_backup_vault.bkp_vault[0].id)
  alarm_description = each.value.alarm_description
  metric_name       = each.value.metric_name
  namespace         = "AWS/Backup"
  statistic         = each.value.statistic
  period            = each.value.period
  dimensions = {
    BackupVaultName = aws_backup_vault.bkp_vault[0].id
  }
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  treat_missing_data  = "missing"

  actions_enabled           = local.actions_enabled
  alarm_actions             = var.alarm_sns_topics
  insufficient_data_actions = var.alarm_sns_topics
  ok_actions                = var.alarm_sns_topics

  tags = merge(local.tags, { "eitsce:parentmodule" = "eits-tf-aws-backup" })
}
