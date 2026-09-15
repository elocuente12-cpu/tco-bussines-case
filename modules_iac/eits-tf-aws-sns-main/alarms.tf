locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false
  alarm_data = {
    NumberOfMessagesPublished = {
      alarm_description   = "This alarm can detect when the number of SNS messages published is too low. For troubleshooting, check why the publishers are sending less traffic."
      metric_name         = "NumberOfMessagesPublished"
      statistic           = "Sum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "NumberOfMessagesPublished", null)
      comparison_operator = "LessThanThreshold"
      alarm_enabled       = lookup(var.alarm_metric_thresholds, "NumberOfMessagesPublished", null) != null
    },
    NumberOfNotificationsDelivered = {
      alarm_description   = "This alarm helps you detect a drop in the volume of messages delivered. You should create this alarm if you expect your system to have a minimum traffic that it is serving."
      metric_name         = "NumberOfNotificationsDelivered"
      statistic           = "Sum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "NumberOfNotificationsDelivered", null)
      comparison_operator = "LessThanThreshold"
      alarm_enabled       = lookup(var.alarm_metric_thresholds, "NumberOfNotificationsDelivered", null) != null
    },
    NumberOfNotificationsFailed = {
      alarm_description   = "This alarm helps you proactively find issues with the delivery of notifications and take appropriate actions to address them."
      metric_name         = "NumberOfNotificationsFailed"
      statistic           = "Sum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "NumberOfNotificationsFailed", null)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = lookup(var.alarm_metric_thresholds, "NumberOfNotificationsFailed", null) != null
    },
    InvalidAttributes = {
      alarm_description   = "The alarm is used to detect if the published messages are not valid or if inappropriate filters have been applied to a subscriber."
      metric_name         = "NumberOfNotificationsFilteredOut-InvalidAttributes"
      statistic           = "Sum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "NumberOfNotificationsFilteredOut-InvalidAttributes", 0)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
    },
    InvalidMessageBody = {
      alarm_description   = "The alarm is used to detect if the published messages are not valid or if inappropriate filters have been applied to a subscriber."
      metric_name         = "NumberOfNotificationsFilteredOut-InvalidMessageBody"
      statistic           = "Sum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "NumberOfNotificationsFilteredOut-InvalidMessageBody", 0)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
    },
    RedrivenToDlq = {
      alarm_description   = "The alarm is used to detect messages that moved to a dead-letter queue."
      metric_name         = "NumberOfNotificationsRedrivenToDlq"
      statistic           = "Sum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "NumberOfNotificationsRedrivenToDlq", 0)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
    },
    FailedToRedriveToDlq = {
      alarm_description   = "The alarm is used to detect messages that couldn't be moved to a dead-letter queue."
      metric_name         = "NumberOfNotificationsFailedToRedriveToDlq"
      statistic           = "Sum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "NumberOfNotificationsFailedToRedriveToDlq", 0)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
    },
    SMSMonthToDateSpentUSD = {
      alarm_description   = "This alarm is used to detect if you have a sufficient quota in your account for your SMS messages to be delivered successfully."
      metric_name         = "SMSMonthToDateSpentUSD"
      statistic           = "Maximum"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "SMSMonthToDateSpentUSD", null)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = lookup(var.alarm_metric_thresholds, "SMSMonthToDateSpentUSD", null) != null
    },
    SMSSuccessRate = {
      alarm_description   = "This alarm is used to detect failing SMS message deliveries."
      metric_name         = "SMSSuccessRate"
      statistic           = "Average"
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      period              = 60
      threshold           = lookup(var.alarm_metric_thresholds, "SMSSuccessRate", null)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = lookup(var.alarm_metric_thresholds, "SMSSuccessRate", null) != null
    }
  }
  cloudwatch_tags = merge(var.tags, var.cloudwatch_tags)
}

module "alarm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.0"

  for_each = var.disable_default_alarms ? {} : { for k, v in local.alarm_data : k => v if v.alarm_enabled }

  alarm_name        = format("AWS/SNS %s TopicName=%s", each.value.metric_name, reverse(split(":", aws_sns_topic.this.arn))[0])
  alarm_description = each.value.alarm_description
  metric_name       = each.value.metric_name
  namespace         = "AWS/SNS"
  statistic         = each.value.statistic
  period            = each.value.period
  dimensions = {
    TopicName = reverse(split(":", aws_sns_topic.this.arn))[0]
  }
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  treat_missing_data  = "missing"

  actions_enabled           = local.actions_enabled
  alarm_actions             = var.alarm_sns_topics
  insufficient_data_actions = var.enable_all_alarm_actions ? var.alarm_sns_topics : []
  ok_actions                = var.enable_all_alarm_actions ? var.alarm_sns_topics : []

  tags = merge(local.cloudwatch_tags, { "eitsce:parentmodule" = "eits-tf-aws-sns" })
}
