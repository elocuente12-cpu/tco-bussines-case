locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false
  alarm_data = {
    in_service = {
      alarm_description   = "This alarm helps to detect when the capacity in the group is below the desired capacity required for your workload."
      metric_name         = "GroupInServiceCapacity"
      statistic           = "Average"
      evaluation_periods  = 10
      datapoints_to_alarm = 10
      period              = 60
      threshold           = try(aws_autoscaling_group.this[0].desired_capacity, null)
      comparison_operator = "LessThanThreshold"
    }
  }
  cloudwatch_tags = merge(var.tags, var.cloudwatch_tags)
}

module "alarm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.0"

  for_each = var.disable_default_alarms || !var.create_autoscaling_group ? {} : local.alarm_data

  alarm_name        = "AWS/AutoScaling ${each.value.metric_name} AutoScalingGroupName=${aws_autoscaling_group.this[0].name}"
  alarm_description = each.value.alarm_description
  metric_name       = each.value.metric_name
  namespace         = "AWS/AutoScaling"
  statistic         = each.value.statistic
  period            = each.value.period
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this[0].name
  }
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  treat_missing_data  = "breaching"

  actions_enabled           = local.actions_enabled
  alarm_actions             = var.alarm_sns_topics
  insufficient_data_actions = var.enable_all_alarm_actions ? var.alarm_sns_topics : []
  ok_actions                = var.enable_all_alarm_actions ? var.alarm_sns_topics : []

  tags = merge(local.cloudwatch_tags, { "eitsce:parentmodule" = "eits-tf-aws-autoscaling" })
}
