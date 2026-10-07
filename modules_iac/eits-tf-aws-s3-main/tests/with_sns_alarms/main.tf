# test region
provider "aws" {
  region = var.region
}

# get account id
data "aws_caller_identity" "current" {}

# locals
locals {
  name = "${data.aws_caller_identity.current.account_id}-eits-tf-aws-s3-alarms"

  # set alarm thresholds
  alarm_metric_thresholds = {
    "4xxErrors" = 0.05
    "5xxErrors" = 0.05
  }
}

# create sns topic for alarms
module "sns_alarms" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sns.git"

  name                   = local.name
  disable_default_alarms = true

  tags = var.tags
}

# test module
module "s3_bucket" {
  source = "./../.."

  bucket_name                = local.name
  access_logging_bucket_name = var.access_logging_bucket
  logging_key_format_partitioned_prefix = {
    partition_date_source = "EventTime"
  }

  disable_source_vpce_check = true

  # add sns topic to send alarms
  alarm_sns_topics        = [module.sns_alarms.topic_arn]
  alarm_metric_thresholds = local.alarm_metric_thresholds

  tags = var.tags
}
