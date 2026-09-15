# test region
provider "aws" {
  region = var.region
}

# set alarm thresholds
locals {
  alarm_metric_thresholds = {
    NumberOfMessagesPublished                           = 1
    NumberOfNotificationsDelivered                      = 1
    NumberOfNotificationsFailed                         = 0
    NumberOfNotificationsFilteredOut-InvalidAttributes  = 0
    NumberOfNotificationsFilteredOut-InvalidMessageBody = 0
    NumberOfNotificationsRedrivenToDlq                  = 0
    NumberOfNotificationsFailedToRedriveToDlq           = 0
    SMSMonthToDateSpentUSD                              = 10
    SMSSuccessRate                                      = 100
  }
}

# create sns topic for alarms
module "sns_alarms" {
  source = "./../.."

  name = "eits-tf-aws-sns-test-alarms"

  # disable alarms for the alarm topic...
  disable_default_alarms = true

  tags = var.tags

  subscribers = {
    # SQS FIFO Queue Subscriber
    "order_processing" = {
      protocol             = "sqs"
      endpoint             = "arn:aws:sqs:us-east-1:123456789012:order-processing.fifo"
      raw_message_delivery = true
      filter_policy = jsonencode({
        "event_type" : ["order_created", "order_updated"]
      })
    }

    # Lambda Function Subscriber
    "order_handler" = {
      protocol = "lambda"
      endpoint = "arn:aws:lambda:us-east-1:123456789012:function:order-handler"
      filter_policy = jsonencode({
        "priority" : ["high"]
      })
    }

    # Email Notifications
    "admin_alerts" = {
      protocol                        = "email"
      endpoint                        = "admin@yourdomain.com"
      confirmation_timeout_in_minutes = 10
    }
  }
}


# test module
module "sns" {
  source = "./../.."

  name = "eits-tf-aws-sns-with-alarms"

  policy_allowed_aws_services = ["backup.amazonaws.com"]

  subscribers = {
    emailme = {
      protocol = "email"
      endpoint = var.email_address
    }
  }

  # add sns topic to send alarms
  alarm_sns_topics        = [module.sns.topic_arn]
  alarm_metric_thresholds = local.alarm_metric_thresholds

  tags = var.tags
}
