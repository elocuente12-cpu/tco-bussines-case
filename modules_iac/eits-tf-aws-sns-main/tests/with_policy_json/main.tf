# test region
provider "aws" {
  region = var.region
}

# locals
locals {
  name = "eits-tf-aws-sns-with-policy"
}

# get account id
data "aws_caller_identity" "current" {}

# create policy document
# due to the way terraform handles (or doesnt) circular references we need to
# build the fully formed ARN values rather than referencing the module outputs here
data "aws_iam_policy_document" "this" {
  policy_id = "SNSTopicsPublish"

  statement {
    sid    = "SNSTopicsPublish"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    actions = [
      "SNS:Subscribe",
      "SNS:SetTopicAttributes",
      "SNS:RemovePermission",
      "SNS:Receive",
      "SNS:Publish",
      "SNS:ListSubscriptionsByTopic",
      "SNS:GetTopicAttributes",
      "SNS:DeleteTopic",
      "SNS:AddPermission"
    ]
    resources = [
      "arn:aws:sns:us-east-2:${data.aws_caller_identity.current.account_id}:*${local.name}-sns-topic"
    ]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceOwner"
      values = [
        data.aws_caller_identity.current.account_id
      ]
    }
  }
}

# test module
module "sns" {
  source = "./../.."

  name        = local.name
  policy_json = data.aws_iam_policy_document.this.json

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



