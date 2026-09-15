# EITS Cloud Enablement AWS SNS Module

EITS Terraform module for AWS Simple Notification Service. This module will:

- Create an SNS topic
- Configure SNS topic policy, if required
- Create SNS topic subscriptions, if required
- Support FIFO (First-In-First-Out) messaging, if required

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> **IMPORTANT:**
> 
> As of version 1.1.0, default alarms based on [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#SNS) will be automatically created. This may incur an extra charge of between $0.40 and $0.90 per month for each SNS topic (depending on which thresholds have been set). To disable the creation of these alarms, please set the variable `disable_default_alarms` to true.

## EITS Security & Compliance

**Last Module Review**: 2025-02-07

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-02-05 | 1.11.4 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-02-05 | 0.60.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-02-05 | 0.68.2 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-02-05 | 0.107.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## SNS Topic Resource Naming

This module attempts to adhere to the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E). Topics will be named as follows:

```txt
{'name_prefix' variable}-{'name' variable}-sns-topic
```

## SNS Server-side Encryption (SSE)

By default, the SNS topic is encrypted with the "alias/aws/sns" default AWS KMS key; however, key management is very limited when using default keys. It is recommended to use a CMK for SNS topic encryption. To provide a customer managed key, use the `kms_master_key_id` variable. 

**WARNING:**
Encryption is enforced, and a warning will be shown if a CMK is not used.

## SNS Topic IAM Policy

The module can automatically generate a policy for the SNS topic, pass either one or both of the following variables:

```hcl
policy_allowed_aws_services = ["<service>"] # list of aws services
policy_allowed_iam_arns     = ["<arn>"]     # list of iam role/user arns
```

If you would like to provide a policy json string yourself, use:

```hcl
policy_json = "<fully-formed aws policy as json>"
```

This will override the two policy_allowed_* variables.

## Subscribing to SNS topics

This module allows you to automatically place messages sent to SNS topics in to SQS queues, send them as POST requests, send SMS messages, emails, etc.

To configure subscribers, use a map of maps in the `subscribers` variable, for example:

```hcl
subscribers = {
    <subscriberid> = {
        protocol = "email"
        endpoint = "<email address>"
    }
}
```

The map key ("subscriberid" in the example above) can be any identifier, it is not used in naming.

The following keys are required in the `subscribers[*]` map:

- `protocol` - (Required) Protocol to use. Valid values are: `sqs`, `sms`, `lambda`, and `application`. Protocols `email`, `email-json`, `http` and `https` are also valid but partially supported. See details: [sns_topic_subscription](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription)
- `endpoint` - (Required) Endpoint to send data to. The contents vary with the protocol. See details: See details: [sns_topic_subscription](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription)

Optionally, the following keys are supported depending on protocol provided:

- `endpoint_auto_confirms` - Whether the endpoint is capable of auto confirming subscription (e.g., PagerDuty). Default is `false`.
- `raw_message_delivery` - Whether to enable raw message delivery (the original message is directly passed, not wrapped in JSON with the original message in the message property). Default is `false`.
- `filter_policy` - JSON String with the filter policy that will be used in the subscription to filter messages seen by the target resource. Refer to the [SNS docs](https://docs.aws.amazon.com/sns/latest/dg/message-filtering.html) for more details.
- `filter_policy_scope` - Whether the filter_policy applies to `MessageAttributes` (default) or `MessageBody`.
- `redrive_policy` - JSON String with the redrive policy that will be used in the subscription. Refer to the [SNS docs](https://docs.aws.amazon.com/sns/latest/dg/sns-dead-letter-queues.html#how-messages-moved-into-dead-letter-queue) for more details.
- `replay_policy` - JSON String with the archived message replay policy that will be used in the subscription. Refer to the [SNS docs](https://docs.aws.amazon.com/sns/latest/dg/message-archiving-and-replay-subscriber.html) for more details.
- `delivery_policy` - JSON String with the delivery policy (retries, backoff, etc.) that will be used in the subscription - this only applies to HTTP/S subscriptions. Refer to the [SNS docs](https://docs.aws.amazon.com/sns/latest/dg/DeliveryPolicies.html) for more details.
- `confirmation_timeout_in_minutes` - Integer indicating number of minutes to wait in retrying mode for fetching subscription arn before marking it as failure. Only applicable for http and https protocols. Default is `1`.

## Message Delivery Status Arguments

The `message_delivery_status` argument can be used to generate CloudWatch Logs, see [AWS Docs](https://docs.aws.amazon.com/sns/latest/dg/sns-topic-attributes.html). Each endpoint is an (optional) key in the map. `success_role_arn` and `failure_role_arn` are used to give SNS write access to CloudWatch Logs. `success_sample_rate` is for specifying the sample rate percentage (0-100) of successfully delivered messages. If you configure `failure_role_arn` all failed message deliveries generate CloudWatch Logs.

```hcl
message_delivery_status = {
    application = {
        success_sample_rate = <Percentage of success to sample>
        success_role_arn    = "<IAM role for success feedback>"
        failure_role_arn    = "<IAM role for failure feedback>"
    }
    http = {
        success_sample_rate = <Percentage of success to sample>
        success_role_arn    = "<IAM role for success feedback>"
        failure_role_arn    = "<IAM role for failure feedback>"
    }
    lambda = {
        success_sample_rate = <Percentage of success to sample>
        success_role_arn    = "<IAM role for success feedback>"
        failure_role_arn    = "<IAM role for failure feedback>"
    }
    sqs = {
        success_sample_rate = <Percentage of success to sample>
        success_role_arn    = "<IAM role for success feedback>"
        failure_role_arn    = "<IAM role for failure feedback>"
    }
    firehose = {
        success_sample_rate = <Percentage of success to sample>
        success_role_arn    = "<IAM role for success feedback>"
        failure_role_arn    = "<IAM role for failure feedback>"
    }
}
```


## Usage

### Standard Topic

```hcl
module "sns_topic" {
	source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sns.git"

    name = "<name of topic>"

    # policy arguments - see Subscribing to SNS topics above
    policy_allowed_aws_services = ["<list of services>"]
    policy_allowed_iam_arns     = ["<list of iam role/user arns>"]

    # map of subscribers, if required - see Subscribing to SNS topics above
    subscribers = {
        <subscriberid> = {
            protocol = "<protocol>"
            endpoint = "<endpoint>"
        }
    }

    # encyption config - omit if not using own KMS CMK
    kms_master_key_id = "<CMK ID>"

    # optional arguments, omit if not using, see Inputs below for details
    display_name    = "<string>"
    delivery_policy = "<json string>"

    tags = {
        Environment = <env>
        CostString  = <CostString>
        AppID       = <AppID>
    }
}
```

### FIFO Topic

```hcl
module "fifo_sns_topic" {
	source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sns.git"

    name                             = "<name of topic>"
    fifo_queue                       = true
    fifo_content_based_deduplication = <bool>

    tags = {
        Environment = <env>
        CostString  = <CostString>
        AppID       = <AppID>
    }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.46 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.46 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.0 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |

## Resources

| Name | Type |
|------|------|
| [aws_sns_topic.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic) | resource |
| [aws_sns_topic_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_policy) | resource |
| [aws_sns_topic_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sns_topic_subscription) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_metric_thresholds"></a> [alarm\_metric\_thresholds](#input\_alarm\_metric\_thresholds) | A map of custom alarm thresholds. See [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#SNS) for a list of metrics, the name of the metric is the key to use when setting a threshold | <pre>object({<br/>    NumberOfMessagesPublished                           = optional(number)<br/>    NumberOfNotificationsDelivered                      = optional(number)<br/>    NumberOfNotificationsFailed                         = optional(number)<br/>    NumberOfNotificationsFilteredOut-InvalidAttributes  = optional(number)<br/>    NumberOfNotificationsFilteredOut-InvalidMessageBody = optional(number)<br/>    NumberOfNotificationsRedrivenToDlq                  = optional(number)<br/>    NumberOfNotificationsFailedToRedriveToDlq           = optional(number)<br/>    SMSMonthToDateSpentUSD                              = optional(number)<br/>    SMSSuccessRate                                      = optional(number)<br/>  })</pre> | `{}` | no |
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions | `list(string)` | `[]` | no |
| <a name="input_archive_policy"></a> [archive\_policy](#input\_archive\_policy) | The message archive policy for FIFO topics, see [Message archiving for FIFO topics](https://docs.aws.amazon.com/sns/latest/dg/message-archiving-and-replay-topic-owner.html) | `string` | `null` | no |
| <a name="input_cloudwatch_tags"></a> [cloudwatch\_tags](#input\_cloudwatch\_tags) | Cloudwatch Alarm tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags | `map(string)` | `{}` | no |
| <a name="input_delivery_policy"></a> [delivery\_policy](#input\_delivery\_policy) | The SNS delivery policy as JSON, see [Amazon SNS message delivery retries](https://docs.aws.amazon.com/sns/latest/dg/sns-message-delivery-retries.html) | `string` | `null` | no |
| <a name="input_disable_default_alarms"></a> [disable\_default\_alarms](#input\_disable\_default\_alarms) | To disable the best practice AWS alarms outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#SNS) | `bool` | `false` | no |
| <a name="input_display_name"></a> [display\_name](#input\_display\_name) | The optional display name for the topic | `string` | `null` | no |
| <a name="input_enable_all_alarm_actions"></a> [enable\_all\_alarm\_actions](#input\_enable\_all\_alarm\_actions) | Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions | `bool` | `false` | no |
| <a name="input_enable_secure_transport_policy"></a> [enable\_secure\_transport\_policy](#input\_enable\_secure\_transport\_policy) | Adds a policy which denies publishing to the topic if the transport mechanism is not secure | `bool` | `true` | no |
| <a name="input_fifo_content_based_deduplication"></a> [fifo\_content\_based\_deduplication](#input\_fifo\_content\_based\_deduplication) | Enable content-based deduplication for FIFO topics, only applicable if `fifo_topic` is `true` | `bool` | `false` | no |
| <a name="input_fifo_topic"></a> [fifo\_topic](#input\_fifo\_topic) | Whether or not to create the topic as FIFO (first-in-first-out), will add .fifo name suffix automatically | `bool` | `false` | no |
| <a name="input_kms_master_key_id"></a> [kms\_master\_key\_id](#input\_kms\_master\_key\_id) | The ID of an AWS-managed customer master key (CMK) for Amazon SNS or a custom CMK. Defaults to AWS managed key | `string` | `"alias/aws/sns"` | no |
| <a name="input_message_delivery_status"></a> [message\_delivery\_status](#input\_message\_delivery\_status) | Generate Message Delivery Status Logs. Each endpoint is an (optional) key in the map. See README for details | <pre>object({<br/>    application = optional(object({<br/>      success_sample_rate = optional(number, 10)<br/>      success_role_arn    = optional(string)<br/>      failure_role_arn    = optional(string)<br/>    }), {})<br/>    http = optional(object({<br/>      success_sample_rate = optional(number, 10)<br/>      success_role_arn    = optional(string)<br/>      failure_role_arn    = optional(string)<br/>    }), {})<br/>    lambda = optional(object({<br/>      success_sample_rate = optional(number, 10)<br/>      success_role_arn    = optional(string)<br/>      failure_role_arn    = optional(string)<br/>    }), {})<br/>    sqs = optional(object({<br/>      success_sample_rate = optional(number, 10)<br/>      success_role_arn    = optional(string)<br/>      failure_role_arn    = optional(string)<br/>    }), {})<br/>    firehose = optional(object({<br/>      success_sample_rate = optional(number, 10)<br/>      success_role_arn    = optional(string)<br/>      failure_role_arn    = optional(string)<br/>    }), {})<br/>  })</pre> | `{}` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the topic. The actual resource name will be created as `{name_prefix}-{name}-sns-topic` in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E). If `fifo` is set to `true` a .fifo suffix will be automatically added | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Used to prefix all created resources. If left `null`, a prefix will be automatically calculated based on account name in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E) | `string` | `null` | no |
| <a name="input_policy_allowed_aws_services"></a> [policy\_allowed\_aws\_services](#input\_policy\_allowed\_aws\_services) | AWS services that will have permission to publish to SNS topic. Used when `policy_json` is not supplied | `list(string)` | `[]` | no |
| <a name="input_policy_allowed_iam_arns"></a> [policy\_allowed\_iam\_arns](#input\_policy\_allowed\_iam\_arns) | IAM role/user ARNs that will have permission to publish to SNS topic. Used when `policy_json` is not supplied | `list(string)` | `[]` | no |
| <a name="input_policy_json"></a> [policy\_json](#input\_policy\_json) | The fully-formed AWS policy as JSON. Will override anything specified in `policy_allowed_aws_services` or `policy_allowed_iam_arns` | `string` | `""` | no |
| <a name="input_signature_version"></a> [signature\_version](#input\_signature\_version) | If [SignatureVersion](https://docs.aws.amazon.com/sns/latest/dg/sns-verify-signature-of-message.html) should be `1` (SHA1) or `2` (SHA256). The signature version corresponds to the hashing algorithm used while creating the signature of the notifications, subscription confirmations, or unsubscribe confirmation messages sent by SNS | `string` | `null` | no |
| <a name="input_subscribers"></a> [subscribers](#input\_subscribers) | Required configuration for subscribers to SNS topic. See README.md for more details. | <pre>map(object({<br/>    protocol                        = string<br/>    endpoint                        = string<br/>    endpoint_auto_confirms          = optional(bool, false)<br/>    raw_message_delivery            = optional(bool, false)<br/>    filter_policy                   = optional(string)<br/>    filter_policy_scope             = optional(string)<br/>    redrive_policy                  = optional(string)<br/>    replay_policy                   = optional(string)<br/>    delivery_policy                 = optional(string)<br/>    confirmation_timeout_in_minutes = optional(number)<br/>  }))</pre> | `{}` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags | `map(string)` | `{}` | no |
| <a name="input_tracing_config"></a> [tracing\_config](#input\_tracing\_config) | Tracing mode of the topic. Valid values `PassThrough` or `Active`. See [Active tracing in SNS](https://docs.aws.amazon.com/sns/latest/dg/sns-active-tracing.html) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_beginning_archive_time"></a> [beginning\_archive\_time](#output\_beginning\_archive\_time) | The oldest timestamp at which a FIFO topic subscriber can start a replay |
| <a name="output_topic_arn"></a> [topic\_arn](#output\_topic\_arn) | SNS topic ARN |
| <a name="output_topic_id"></a> [topic\_id](#output\_topic\_id) | SNS topic ID |
| <a name="output_topic_name"></a> [topic\_name](#output\_topic\_name) | SNS topic name |
| <a name="output_topic_owner"></a> [topic\_owner](#output\_topic\_owner) | SNS topic owner |
| <a name="output_topic_subscriptions"></a> [topic\_subscriptions](#output\_topic\_subscriptions) | SNS topic subscriptions |
<!-- END_TF_DOCS -->

## Metadata
```discoveryhub
summary: Terraform module for AWS Simple Notification Service (SNS)
region: Global
bu: EITS
contacts:
  technical: EITS UK&I Cloud Enablement Team eitsukicloud@experian.com
  product: 
```
