locals {
  actions_enabled = length(var.alarm_sns_topics) > 0 ? true : false
  cloudwatch_tags = merge(local.tags, var.cloudwatch_tags)

  alarm_data = {
    storage_capacity_utilization = {
      alarm_description = "This alarm helps you detect when the FSx storage capacity utilization is high."
      metric_name       = "StorageCapacityUtilization"
      threshold         = var.alarm_thresholds.storage_capacity_utilization
    },
    network_capacity_utilization = {
      alarm_description = "This alarm helps you detect when the FSx network throughput utilization is high."
      metric_name       = "NetworkThroughputUtilization"
      threshold         = var.alarm_thresholds.network_capacity_utilization
    },
    disk_iops_utilization = {
      alarm_description = "This alarm helps you detect when the FSx disk IOPS utilization is high."
      metric_name       = "DiskIopsUtilization"
      threshold         = var.alarm_thresholds.disk_iops_utilization
    },
    fs_disk_iops_utilization = {
      alarm_description = "This alarm helps you detect when the FSx file server disk IOPS utilization is high."
      metric_name       = "FileServerDiskIopsUtilization"
      threshold         = var.alarm_thresholds.fs_disk_iops_utilization
    }
  }
}

module "alarm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git?ref=1.3.0"

  for_each = var.enable_default_alarms ? local.alarm_data : {}

  alarm_name        = "AWS/FSx ${each.value.metric_name} FileSystemId=${aws_fsx_windows_file_system.this.id}"
  alarm_description = each.value.alarm_description
  metric_name       = each.value.metric_name
  namespace         = "AWS/FSx"
  period            = 86400
  dimensions = {
    FileSystemId = aws_fsx_windows_file_system.this.id
  }
  statistic           = "Minimum"
  evaluation_periods  = 1
  datapoints_to_alarm = 1
  threshold           = each.value.threshold
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "missing"

  actions_enabled           = local.actions_enabled
  alarm_actions             = var.alarm_sns_topics
  insufficient_data_actions = var.enable_all_alarm_actions ? var.alarm_sns_topics : []
  ok_actions                = var.enable_all_alarm_actions ? var.alarm_sns_topics : []

  tags = merge(local.cloudwatch_tags, { "eitsce:parentmodule" = "eits-tf-aws-fsx-windows" })
}