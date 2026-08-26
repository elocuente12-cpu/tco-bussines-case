locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false
  alarm_data = {
    errors = {
      alarm_description   = "This alarm detects high error counts."
      metric_name         = "Errors"
      statistic           = "Sum"
      extended_statistic  = null
      evaluation_periods  = 3
      datapoints_to_alarm = 3
      threshold           = lookup(var.alarm_metric_thresholds, "Errors", null)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = lookup(var.alarm_metric_thresholds, "Errors", null) != null
    }
    throttles = {
      alarm_description   = "This alarm detects a high number of throttled invocation requests."
      metric_name         = "Throttles"
      statistic           = "Sum"
      extended_statistic  = null
      evaluation_periods  = 5
      datapoints_to_alarm = 5
      threshold           = lookup(var.alarm_metric_thresholds, "Throttles", null)
      comparison_operator = "GreaterThanOrEqualToThreshold"
      alarm_enabled       = lookup(var.alarm_metric_thresholds, "Throttles", null) != null
    }
    duration = {
      alarm_description   = "This alarm detects long duration times for processing an event by a Lambda function."
      metric_name         = "Duration"
      statistic           = null
      extended_statistic  = "p90"
      evaluation_periods  = 15
      datapoints_to_alarm = 15
      threshold           = lookup(var.alarm_metric_thresholds, "Duration", null)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = lookup(var.alarm_metric_thresholds, "Duration", null) != null
    }
    concurrent_executions = {
      alarm_description   = "This alarm helps to monitor if the concurrency of the function is approaching the Region-level concurrency limit of your account."
      metric_name         = "ConcurrentExecutions"
      statistic           = "Maximum"
      extended_statistic  = null
      evaluation_periods  = 10
      datapoints_to_alarm = 10
      threshold           = lookup(var.alarm_metric_thresholds, "ConcurrentExecutions", 900)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = true
    }
    memory_utilization = {
      alarm_description   = "This alarm is used to detect if the memory utilization of a lambda function is approaching the configured limit."
      metric_name         = "memory_utilization"
      statistic           = "Average"
      extended_statistic  = null
      evaluation_periods  = 10
      datapoints_to_alarm = 10
      threshold           = lookup(var.alarm_metric_thresholds, "memory_utilization", 90)
      comparison_operator = "GreaterThanThreshold"
      alarm_enabled       = var.cloudwatch_lambda_insights_enabled
    }
  }
  cloudwatch_tags = merge(var.tags, var.cloudwatch_tags)
}

module "alarm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.0"

  for_each = var.disable_default_alarms ? {} : { for k, v in local.alarm_data : k => v if v.alarm_enabled }

  alarm_name         = "AWS/Lambda ${each.value.metric_name} FunctionName=${local.function_name}"
  alarm_description  = each.value.alarm_description
  metric_name        = each.value.metric_name
  namespace          = "AWS/Lambda"
  statistic          = each.value.statistic
  extended_statistic = each.value.extended_statistic
  period             = 60
  dimensions = {
    FunctionName = local.function_name
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

  tags = merge(local.cloudwatch_tags, { "eitsce:parentmodule" = "eits-tf-aws-lambda" })
}
