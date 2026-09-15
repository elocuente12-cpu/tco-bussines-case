variable "archive_policy" {
  type        = string
  default     = null
  description = "The message archive policy for FIFO topics, see [Message archiving for FIFO topics](https://docs.aws.amazon.com/sns/latest/dg/message-archiving-and-replay-topic-owner.html)"
}

variable "delivery_policy" {
  type        = string
  default     = null
  description = "The SNS delivery policy as JSON, see [Amazon SNS message delivery retries](https://docs.aws.amazon.com/sns/latest/dg/sns-message-delivery-retries.html)"
}

variable "display_name" {
  type        = string
  default     = null
  description = "The optional display name for the topic"

  validation {
    condition = (
      can(regex("^[a-zA-Z0-9-_]+$", var.display_name)) || var.display_name == null
    )
    error_message = "The name variable must have alphanumeric, underscore and hyphen characters"
  }
}

variable "fifo_content_based_deduplication" {
  type        = bool
  default     = false
  description = "Enable content-based deduplication for FIFO topics, only applicable if `fifo_topic` is `true`"
}

variable "fifo_topic" {
  type        = bool
  default     = false
  description = "Whether or not to create the topic as FIFO (first-in-first-out), will add .fifo name suffix automatically"
}

variable "kms_master_key_id" {
  type        = string
  default     = "alias/aws/sns"
  description = "The ID of an AWS-managed customer master key (CMK) for Amazon SNS or a custom CMK. Defaults to AWS managed key"

  validation {
    condition     = length(trimspace(var.kms_master_key_id)) > 0
    error_message = "The kms_master_key_id variable must not be an empty string"
  }
}

variable "message_delivery_status" {
  type = object({
    application = optional(object({
      success_sample_rate = optional(number, 10)
      success_role_arn    = optional(string)
      failure_role_arn    = optional(string)
    }), {})
    http = optional(object({
      success_sample_rate = optional(number, 10)
      success_role_arn    = optional(string)
      failure_role_arn    = optional(string)
    }), {})
    lambda = optional(object({
      success_sample_rate = optional(number, 10)
      success_role_arn    = optional(string)
      failure_role_arn    = optional(string)
    }), {})
    sqs = optional(object({
      success_sample_rate = optional(number, 10)
      success_role_arn    = optional(string)
      failure_role_arn    = optional(string)
    }), {})
    firehose = optional(object({
      success_sample_rate = optional(number, 10)
      success_role_arn    = optional(string)
      failure_role_arn    = optional(string)
    }), {})
  })
  default     = {}
  description = "Generate Message Delivery Status Logs. Each endpoint is an (optional) key in the map. See README for details"
}

variable "name" {
  type        = string
  description = "The name of the topic. The actual resource name will be created as `{name_prefix}-{name}-sns-topic` in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E). If `fifo` is set to `true` a .fifo suffix will be automatically added"

  validation {
    condition = (
      can(regex("^[a-zA-Z0-9-_]+$", var.name)) || var.name == null
    )
    error_message = "The name variable must have alphanumeric, underscore and hyphen characters"
  }
}

variable "name_prefix" {
  type        = string
  default     = null
  description = "Used to prefix all created resources. If left `null`, a prefix will be automatically calculated based on account name in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E)"
}

variable "policy_allowed_aws_services" {
  type        = list(string)
  description = "AWS services that will have permission to publish to SNS topic. Used when `policy_json` is not supplied"
  default     = []
}

variable "policy_allowed_iam_arns" {
  type        = list(string)
  description = "IAM role/user ARNs that will have permission to publish to SNS topic. Used when `policy_json` is not supplied"
  default     = []
}

variable "policy_json" {
  type        = string
  default     = ""
  description = "The fully-formed AWS policy as JSON. Will override anything specified in `policy_allowed_aws_services` or `policy_allowed_iam_arns`"
}

variable "signature_version" {
  type        = string
  default     = null
  description = "If [SignatureVersion](https://docs.aws.amazon.com/sns/latest/dg/sns-verify-signature-of-message.html) should be `1` (SHA1) or `2` (SHA256). The signature version corresponds to the hashing algorithm used while creating the signature of the notifications, subscription confirmations, or unsubscribe confirmation messages sent by SNS"
}

variable "subscribers" {
  type = map(object({
    protocol                        = string
    endpoint                        = string
    endpoint_auto_confirms          = optional(bool, false)
    raw_message_delivery            = optional(bool, false)
    filter_policy                   = optional(string)
    filter_policy_scope             = optional(string)
    redrive_policy                  = optional(string)
    replay_policy                   = optional(string)
    delivery_policy                 = optional(string)
    confirmation_timeout_in_minutes = optional(number)
  }))
  default     = {}
  description = "Required configuration for subscribers to SNS topic. See README.md for more details."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}

variable "tracing_config" {
  type        = string
  default     = null
  description = "Tracing mode of the topic. Valid values `PassThrough` or `Active`. See [Active tracing in SNS](https://docs.aws.amazon.com/sns/latest/dg/sns-active-tracing.html)"
}

variable "enable_secure_transport_policy" {
  type        = bool
  default     = true
  description = "Adds a policy which denies publishing to the topic if the transport mechanism is not secure"
}

variable "disable_default_alarms" {
  type        = bool
  default     = false
  description = "To disable the best practice AWS alarms outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#SNS)"
}

variable "alarm_sns_topics" {
  type        = list(string)
  default     = []
  description = "List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions"
}

variable "enable_all_alarm_actions" {
  type        = bool
  description = "Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions"
  default     = false
}

variable "alarm_metric_thresholds" {
  type = object({
    NumberOfMessagesPublished                           = optional(number)
    NumberOfNotificationsDelivered                      = optional(number)
    NumberOfNotificationsFailed                         = optional(number)
    NumberOfNotificationsFilteredOut-InvalidAttributes  = optional(number)
    NumberOfNotificationsFilteredOut-InvalidMessageBody = optional(number)
    NumberOfNotificationsRedrivenToDlq                  = optional(number)
    NumberOfNotificationsFailedToRedriveToDlq           = optional(number)
    SMSMonthToDateSpentUSD                              = optional(number)
    SMSSuccessRate                                      = optional(number)
  })

  default     = {}
  description = "A map of custom alarm thresholds. See [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#SNS) for a list of metrics, the name of the metric is the key to use when setting a threshold"
}

variable "cloudwatch_tags" {
  type        = map(string)
  default     = {}
  description = "Cloudwatch Alarm tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags"
}
