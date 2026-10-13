locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false
  cloudwatch_tags = local.tags

  default_alarm_data = {
    nlb_tcp_elb_reset_count = {
      alarm_name          = "AWS/NetworkELB TCP_ELB_Reset_Count LoadBalancer=${aws_lb.this.arn_suffix}"
      alarm_description   = "This alarm helps you detect a sustained increase in NLB TCP resets."
      metric_name         = "TCP_ELB_Reset_Count"
      namespace           = "AWS/NetworkELB"
      statistic           = "Sum"
      period              = 300
      dimensions          = { LoadBalancer = aws_lb.this.arn_suffix }
      evaluation_periods  = 3
      datapoints_to_alarm = 3
      threshold           = var.alarm_tcp_elb_reset_threshold
      comparison_operator = "GreaterThanOrEqualToThreshold"
      treat_missing_data  = "missing"
    }
  }

  target_group_alarm_data = {
    for tg_alarm in flatten([
      for tg_key, tg in var.target_groups : [
        {
          key               = "${tg_key}_unhealthy"
          alarm_name        = "AWS/NetworkELB UnHealthyHostCount LoadBalancer=${aws_lb.this.arn_suffix} TargetGroup=${aws_lb_target_group.this[tg_key].arn_suffix}"
          alarm_description = "This alarm detects when one or more targets in target group ${tg_key} become unhealthy."
          metric_name       = "UnHealthyHostCount"
          namespace         = "AWS/NetworkELB"
          statistic         = "Maximum"
          period            = 60
          dimensions = {
            LoadBalancer = aws_lb.this.arn_suffix
            TargetGroup  = aws_lb_target_group.this[tg_key].arn_suffix
          }
          evaluation_periods  = 1
          datapoints_to_alarm = 1
          threshold           = try(tg.target_alarm.unhealthy_threshold != null, false) ? tg.target_alarm.unhealthy_threshold : var.unhealthy_host_alarm_threshold
          comparison_operator = "GreaterThanOrEqualToThreshold"
          treat_missing_data  = "missing"
        },
        {
          key               = "${tg_key}_healthy_min"
          alarm_name        = "AWS/NetworkELB HealthyHostCount LoadBalancer=${aws_lb.this.arn_suffix} TargetGroup=${aws_lb_target_group.this[tg_key].arn_suffix}"
          alarm_description = "This alarm detects when target group ${tg_key} has insufficient healthy targets."
          metric_name       = "HealthyHostCount"
          namespace         = "AWS/NetworkELB"
          statistic         = "Minimum"
          period            = 60
          dimensions = {
            LoadBalancer = aws_lb.this.arn_suffix
            TargetGroup  = aws_lb_target_group.this[tg_key].arn_suffix
          }
          evaluation_periods  = 1
          datapoints_to_alarm = 1
          threshold           = try(tg.target_alarm.healthy_threshold != null, false) ? tg.target_alarm.healthy_threshold : var.healthy_host_alarm_threshold
          comparison_operator = "LessThanOrEqualToThreshold"
          treat_missing_data  = "breaching"
        }
      ]
    ]) : tg_alarm.key => tg_alarm
  }

  alarm_data = merge(
    var.disable_default_alarms ? {} : local.default_alarm_data,
    var.disable_default_alarms ? {} : local.target_group_alarm_data
  )
}

module "alarm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.1"

  for_each = local.alarm_data

  alarm_name          = each.value.alarm_name
  alarm_description   = each.value.alarm_description
  metric_name         = each.value.metric_name
  namespace           = each.value.namespace
  statistic           = each.value.statistic
  period              = each.value.period
  dimensions          = each.value.dimensions
  evaluation_periods  = each.value.evaluation_periods
  datapoints_to_alarm = each.value.datapoints_to_alarm
  threshold           = each.value.threshold
  comparison_operator = each.value.comparison_operator
  treat_missing_data  = each.value.treat_missing_data

  actions_enabled           = local.actions_enabled
  alarm_actions             = var.alarm_sns_topics
  insufficient_data_actions = var.enable_all_alarm_actions ? var.alarm_sns_topics : []
  ok_actions                = var.enable_all_alarm_actions ? var.alarm_sns_topics : []

  tags = merge(local.cloudwatch_tags, { "eitsce:parentmodule" = "eits-tf-aws-nlb" })
}