locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false

  replication_alarm_data = var.replication_config.enabled ? {
    for rule in var.replication_config.rules : "OperationsFailedReplication-${rule.id}" => {
      alarm_description   = "This alarm is used to detect if there is a failed replication operation."
      metric_name         = "OperationsFailedReplication"
      statistic           = "Maximum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = try(var.alarm_metric_thresholds.OperationsFailedReplication.threshold, 0.0)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
      dimensions = {
        SourceBucket      = aws_s3_bucket.this.id
        DestinationBucket = var.replication_config.destination_bucket_arn
        RuleId            = rule.id
      }
    }
  } : {}

  override_replication_alarm_data = length(try(var.alarm_metric_thresholds.OperationsFailedReplication.RuleIdList, [])) > 0 ? {
    for rule_id in var.alarm_metric_thresholds.OperationsFailedReplication.RuleIdList : "OperationsFailedReplication-${rule_id}" => {
      alarm_description   = "This alarm is used to detect if there is a failed replication operation."
      metric_name         = "OperationsFailedReplication"
      statistic           = "Maximum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = try(var.alarm_metric_thresholds.OperationsFailedReplication.threshold, 0.0)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
      dimensions = {
        SourceBucket      = aws_s3_bucket.this.id
        DestinationBucket = try(var.alarm_metric_thresholds.OperationsFailedReplication.DestinationBucket, null)
        RuleId            = rule_id
      }
    }
  } : {}

  core_alarm_data = {
    Average4xxErrors = {
      alarm_description   = "This alarm is used to create a baseline for typical 4xx error rates so that you can look into any abnormalities that might indicate a setup issue."
      metric_name         = "4xxErrors"
      statistic           = "Average"
      evaluation_periods  = 15
      datapoints_to_alarm = 15
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "Average4xxErrors", 0.05)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
      dimensions = {
        BucketName = aws_s3_bucket.this.id
        FilterId   = "EntireBucket"
      }
    },
    Average5xxErrors = {
      alarm_description   = "This alarm can help to detect if the application is experiencing issues due to 5xx errors."
      metric_name         = "5xxErrors"
      statistic           = "Average"
      evaluation_periods  = 15
      datapoints_to_alarm = 15
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "Average5xxErrors", 0.05)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
      dimensions = {
        BucketName = aws_s3_bucket.this.id
        FilterId   = "EntireBucket"
      }
    }
  }

  alarm_data = (
    length(try(var.alarm_metric_thresholds.OperationsFailedReplication.RuleIdList, [])) > 0 ? merge(local.override_replication_alarm_data, local.core_alarm_data) : (
      var.replication_config.enabled ? merge(local.replication_alarm_data, local.core_alarm_data) : local.core_alarm_data
    )
  )
  cloudwatch_tags = merge(var.tags, var.cloudwatch_tags)
}

module "alarm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.0"

  for_each = var.disable_default_alarms ? {} : { for k, v in local.alarm_data : k => v if v.alarm_enabled }

  alarm_name        = format("AWS/S3 %s BucketName=%s", each.key, aws_s3_bucket.this.id)
  alarm_description = each.value.alarm_description
  metric_name       = each.value.metric_name
  namespace         = "AWS/S3"
  statistic         = each.value.statistic
  period            = each.value.period
  dimensions        = each.value.dimensions

  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  treat_missing_data  = "ignore"

  actions_enabled           = local.actions_enabled
  alarm_actions             = var.alarm_sns_topics
  insufficient_data_actions = var.enable_all_alarm_actions ? var.alarm_sns_topics : []
  ok_actions                = var.enable_all_alarm_actions ? var.alarm_sns_topics : []

  tags = merge(local.cloudwatch_tags, { "eitsce:parentmodule" = "eits-tf-aws-s3" })
}
