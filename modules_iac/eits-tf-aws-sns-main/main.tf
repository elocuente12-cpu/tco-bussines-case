locals {
  name = format("%s-%s-sns-topic%s", var.name_prefix != null ? var.name_prefix : module.eits_ce_common.prefix, var.name, var.fifo_topic ? ".fifo" : "")
  tags = merge(var.tags, module.eits_ce_common.tags)
  set_policy = anytrue([
    length(var.policy_json) > 0,
    length(var.policy_allowed_aws_services) > 0,
    length(var.policy_allowed_iam_arns) > 0,
    var.enable_secure_transport_policy
  ])
}

data "aws_caller_identity" "current" {}
module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-sns"
  tags        = var.tags
}

# recommendation added to README.md about CMK
#tfsec:ignore:aws-sns-topic-encryption-use-cmk
resource "aws_sns_topic" "this" {
  name              = local.name
  display_name      = var.display_name
  delivery_policy   = var.delivery_policy
  kms_master_key_id = var.kms_master_key_id
  archive_policy    = var.archive_policy
  signature_version = var.signature_version
  tracing_config    = var.tracing_config

  # fifo topic config
  fifo_topic                  = var.fifo_topic
  content_based_deduplication = var.fifo_content_based_deduplication && var.fifo_topic ? true : false

  # message delivery status logging
  application_success_feedback_sample_rate = var.message_delivery_status.application != null ? var.message_delivery_status.application.success_sample_rate : null
  application_success_feedback_role_arn    = var.message_delivery_status.application != null ? var.message_delivery_status.application.success_role_arn : null
  application_failure_feedback_role_arn    = var.message_delivery_status.application != null ? var.message_delivery_status.application.failure_role_arn : null

  http_success_feedback_sample_rate = var.message_delivery_status.http != null ? var.message_delivery_status.http.success_sample_rate : null
  http_success_feedback_role_arn    = var.message_delivery_status.http != null ? var.message_delivery_status.http.success_role_arn : null
  http_failure_feedback_role_arn    = var.message_delivery_status.http != null ? var.message_delivery_status.http.failure_role_arn : null

  lambda_success_feedback_sample_rate = var.message_delivery_status.lambda != null ? var.message_delivery_status.lambda.success_sample_rate : null
  lambda_success_feedback_role_arn    = var.message_delivery_status.lambda != null ? var.message_delivery_status.lambda.success_role_arn : null
  lambda_failure_feedback_role_arn    = var.message_delivery_status.lambda != null ? var.message_delivery_status.lambda.failure_role_arn : null

  sqs_success_feedback_sample_rate = var.message_delivery_status.sqs != null ? var.message_delivery_status.sqs.success_sample_rate : null
  sqs_success_feedback_role_arn    = var.message_delivery_status.sqs != null ? var.message_delivery_status.sqs.success_role_arn : null
  sqs_failure_feedback_role_arn    = var.message_delivery_status.sqs != null ? var.message_delivery_status.sqs.failure_role_arn : null

  firehose_success_feedback_sample_rate = var.message_delivery_status.firehose != null ? var.message_delivery_status.firehose.success_sample_rate : null
  firehose_success_feedback_role_arn    = var.message_delivery_status.firehose != null ? var.message_delivery_status.firehose.success_role_arn : null
  firehose_failure_feedback_role_arn    = var.message_delivery_status.firehose != null ? var.message_delivery_status.firehose.failure_role_arn : null
  tags                                  = local.tags
}

data "aws_iam_policy_document" "this" {
  policy_id = "SNSTopicsPublish"
  dynamic "statement" {
    for_each = alltrue([
      length(var.policy_json) == 0,
      anytrue([
        length(var.policy_allowed_aws_services) > 0,
        length(var.policy_allowed_iam_arns) > 0,
        var.enable_secure_transport_policy
      ])
    ]) ? ["_enable"] : []

    content {
      sid       = "AllowedPrincipals"
      effect    = "Allow"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.this.arn]

      dynamic "principals" {
        for_each = length(var.policy_allowed_aws_services) > 0 ? ["_enable"] : []
        content {
          type        = "Service"
          identifiers = var.policy_allowed_aws_services
        }
      }

      dynamic "principals" {
        for_each = length(var.policy_allowed_iam_arns) > 0 ? ["_enable"] : []
        content {
          type        = "AWS"
          identifiers = var.policy_allowed_iam_arns
        }
      }

      dynamic "principals" {
        for_each = alltrue([
          var.enable_secure_transport_policy,
          length(var.policy_allowed_iam_arns) == 0,
          length(var.policy_allowed_aws_services) == 0
        ]) ? ["_enable"] : []

        content {
          type        = "AWS"
          identifiers = ["*"]
        }
      }

      dynamic "condition" {
        for_each = alltrue([
          var.enable_secure_transport_policy,
          length(var.policy_allowed_iam_arns) == 0,
          length(var.policy_allowed_aws_services) == 0
        ]) ? ["_enable"] : []

        content {
          test     = "StringEquals"
          variable = "AWS:SourceOwner"
          values   = [data.aws_caller_identity.current.account_id]
        }
      }
    }
  }

  dynamic "statement" {
    for_each = var.enable_secure_transport_policy ? ["_enable"] : []

    content {
      sid       = "SecureTransport"
      effect    = "Deny"
      actions   = ["sns:Publish"]
      resources = [aws_sns_topic.this.arn]
      condition {
        test     = "Bool"
        variable = "aws:SecureTransport"
        values   = ["false"]
      }
      principals {
        identifiers = ["*"]
        type        = "*"
      }
    }
  }

  source_policy_documents = concat(length(var.policy_json) > 0 ? [var.policy_json] : [])
}

resource "aws_sns_topic_policy" "this" {
  count = local.set_policy ? 1 : 0

  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.this.json
}

resource "aws_sns_topic_subscription" "this" {
  for_each = var.subscribers

  topic_arn = aws_sns_topic.this.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  # optional arguments
  endpoint_auto_confirms          = each.value.endpoint_auto_confirms
  raw_message_delivery            = each.value.raw_message_delivery
  filter_policy                   = each.value.filter_policy
  filter_policy_scope             = each.value.filter_policy_scope
  redrive_policy                  = each.value.redrive_policy
  replay_policy                   = each.value.replay_policy
  delivery_policy                 = each.value.delivery_policy
  confirmation_timeout_in_minutes = each.value.confirmation_timeout_in_minutes
}


