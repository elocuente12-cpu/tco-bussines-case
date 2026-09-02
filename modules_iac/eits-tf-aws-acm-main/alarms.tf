locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false
  alarm_data = {
    cert_expiration = {
      alarm_description   = "This alarm helps you detect when a certificate managed by or imported into ACM is approaching its expiration date."
      metric_name         = "CertificateArn"
      statistic           = "Minimum"
      evaluation_periods  = 1
      datapoints_to_alarm = 1
      threshold           = 44
      comparison_operator = "LessThanOrEqualToThreshold"
    }
  }
  certificate_arn = var.action == "import" ? aws_acm_certificate.import_cert[0].arn : aws_acm_certificate.request_cert[0].arn
}

module "alarm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.0"

  for_each = var.disable_default_alarms ? {} : local.alarm_data

  alarm_name        = "AWS/CertificateManager ${each.value.metric_name} CertificateArn=i-${local.certificate_arn}"
  alarm_description = each.value.alarm_description
  metric_name       = each.value.metric_name
  namespace         = "AWS/CertificateManager"
  statistic         = each.value.statistic
  period            = 86400
  dimensions = {
    CertificateArn = local.certificate_arn
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

  tags = merge(local.cloudwatch_tags, { "eitsce:parentmodule" = "eits-tf-aws-acm" })
}
