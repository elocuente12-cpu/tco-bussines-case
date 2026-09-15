# test region
provider "aws" {
  region = var.region
}

# test module
module "sns" {
  source = "./../.."

  name       = "eits-tf-aws-sns-with-fifo"
  fifo_topic = true

  fifo_content_based_deduplication = true

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

