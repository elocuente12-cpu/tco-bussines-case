locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false
  alarm_data = {
    cpu = {
      alarm_description   = "This alarm is used to detect high CPU utilization."
      metric_name         = "CPUUtilization"
      statistic           = "Average"
      evaluation_periods  = 3
      datapoints_to_alarm = 3
      threshold           = 80
      comparison_operator = "GreaterThanThreshold"
    }
    status = {
      alarm_description   = "This alarm helps to monitor both system status checks and instance status checks. If either type of status check fails, then this alarm should be in ALARM state."
      metric_name         = "StatusCheckFailed"
      statistic           = "Maximum"
      evaluation_periods  = 2
      datapoints_to_alarm = 2
      threshold           = 1
      comparison_operator = "GreaterThanOrEqualToThreshold"
    }
  }
}

module "alarm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.1"

  for_each = var.disable_default_alarms ? {} : local.alarm_data

  alarm_name        = "AWS/EC2 ${each.value.metric_name} InstanceId=${aws_instance.default.id}"
  alarm_description = each.value.alarm_description
  metric_name       = each.value.metric_name
  namespace         = "AWS/EC2"
  statistic         = each.value.statistic
  period            = 300
  dimensions = {
    InstanceId = aws_instance.default.id
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

  tags = merge(local.cloudwatch_tags, { "eitsce:parentmodule" = "eits-tf-aws-ec2-innersource" })


}
