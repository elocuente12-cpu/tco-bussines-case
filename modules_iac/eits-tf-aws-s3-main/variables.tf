variable "access_logging_bucket_name" {
  description = "Defines the target bucket for logging."
  type        = string
  default     = null
}

variable "access_points" {
  description = <<-EOT
    A list of S3 Access Points to create for the bucket. Please note there are limitations with using access points, see [AWS Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points.html) for more information. Usage:
    <pre>access_points = [
     {
        name                    = Unique name you want to assign to this access point. See [AWS Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-access-points.html?icmpid=docs_amazons3_console#access-points-names) for naming conditions.
        policy                  = Valid JSON document that specifies the policy that you want to apply to this access point, see [AWS Docs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-points-policies.html?icmpid=docs_amazons3_console).
        restricted_vpc_id       = Restrict access to this access point to requests from the specified VPC.
        block_public_acls       = Whether to block public ACLs. Defaults to 'true'.
        block_public_policy     = Whether to block public bucket policies. Defaults to 'true'.
        ignore_public_acls      = Whether to ignore public ACLs. Defaults to 'true'.
        restrict_public_buckets = Whether to restrict public buckets. Defaults to 'true'.
      }
    ]</pre>
    EOT
  type = list(object({
    name                    = string
    policy                  = optional(string)
    restricted_vpc_id       = optional(string)
    block_public_acls       = optional(bool, true)
    block_public_policy     = optional(bool, true)
    ignore_public_acls      = optional(bool, true)
    restrict_public_buckets = optional(bool, true)
  }))
  default = []
}

variable "acl_canned" {
  description = "The canned ACL to apply, [see here](https://docs.aws.amazon.com/AmazonS3/latest/dev/acl-overview.html#canned-acl). Deprecated by AWS in favour of bucket policies. Is ignored when `acl_grants` is set or `object_ownership` is set to `BucketOwnerEnforced` (default)."
  type        = string
  default     = "private"
}

variable "acl_grants" {
  description = "The access control policy to apply. Deprecated by AWS in favour of bucket policies. Is ignored when `object_ownership` is set to `BucketOwnerEnforced` (default). Will overwrite value in `acl_canned`. Requires a list of policy grants for the bucket, taking a list of permissions"
  type = list(
    object({
      id          = optional(string)
      type        = string
      permissions = list(string)
      uri         = optional(string)
    })
  )
  default = []
}

variable "prefix" {
  description = "Optional prefix for the bucket name. When set, the full bucket name is constructed as `{prefix}-{bucket_name}-s3`. When null (default), `bucket_name` is used as-is."
  type        = string
  default     = null
}

variable "bucket_name" {
  description = "The name of the bucket, must be unique."
  type        = string
}

variable "bucket_policy" {
  description = "Accepts either a relative path for a bucket policy json file, or direct json (e.g. from aws_iam_policy_document). Policy will be merged with `source_policy_documents` if also supplied."
  type        = string
  default     = null
}

variable "source_policy_documents" {
  description = "List of IAM policy documents (in json) that will be merged together (e.g. from aws_iam_policy_document). All statements must have unique SIDs. Does not support json files. Policy will be merged with `bucket_policy` if also supplied."
  type        = list(any)
  default     = []
}

variable "force_destroy" {
  description = "A boolean that indicates all objects should be deleted from the bucket so that the bucket can be destroyed without error. These objects are not recoverable."
  type        = bool
  default     = false
}

variable "intelligent_tiering" {
  description = "A map of maps containing intelligent tiering configuration. The map key will be used to name the configuration. Note that the map key for `tiering` must be either `ARCHIVE_ACCESS` or `DEEP_ARCHIVE_ACCESS`.See [s3_bucket_intelligent_tiering_configuration](https://registry.terraform.io/providers/-/aws/latest/docs/resources/s3_bucket_intelligent_tiering_configuration) for guidance on values"
  type = map(
    object({
      status = optional(string, "Enabled")
      filter = optional(object({
        prefix = optional(string)
        tags   = optional(map(string))
      }))
      tiering = optional(map(
        object({
          days = optional(number)
        })
      ), {})
    })
  )
  default = {}
}

variable "kms_key_arn" {
  description = "ARN of an existing AWS KMS key. Must be set if `sse_algorithm` is set to `aws:kms`."
  type        = string
  default     = null
}

variable "lifecycle_rules" {
  description = "A list of maps defining the lifecycle rules for the bucket. See [s3_bucket_lifecycle_configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_lifecycle_configuration#argument-reference) for guidance on values. Note that if no `rule.filter` value is set, it will default to filtering objects with an empty string prefix"
  type = list(
    object({
      id                                     = optional(string)
      status                                 = optional(string, "Enabled")
      abort_incomplete_multipart_upload_days = optional(number)
      expiration = optional(object({
        date                         = optional(string)
        days                         = optional(number)
        expired_object_delete_marker = optional(bool)
      }))
      filter = optional(object({
        prefix                   = optional(string)
        object_size_greater_than = optional(number)
        object_size_less_than    = optional(number)
        tags                     = optional(map(string), {})
      }), {})
      noncurrent_version_expiration = optional(object({
        newer_noncurrent_versions = optional(number)
        noncurrent_days           = optional(number)
      }))
      noncurrent_version_transition = optional(list(
        object({
          newer_noncurrent_versions = optional(number)
          noncurrent_days           = optional(number)
          storage_class             = optional(string)
        })
      ), [])
      transition = optional(list(
        object({
          date          = optional(string)
          days          = optional(number)
          storage_class = optional(string)
        })
      ), [])
    })
  )
  default = []
}

variable "logging_key_format_partitioned_prefix" {
  description = "Setting this enables the partitioned prefix format for logging object key. The partition_date_source is required and can be only one of ['EventTime', 'DeliveryTime']"
  type = object({
    partition_date_source = string
  })
  default = null
  validation {
    condition     = var.logging_key_format_partitioned_prefix == null || contains(["EventTime", "DeliveryTime"], try(var.logging_key_format_partitioned_prefix.partition_date_source, ""))
    error_message = "Value of partition_date_source must be one of ['EventTime', 'DeliveryTime']"
  }
}

variable "enable_abort_incomplete_multipart_upload" {
  description = "Whether to enable a default lifecycle rule to abort incomplete multipart uploads. If 'true', 'default_abort_incomplete_multipart_upload_days' will be used unless overridden per rule."
  type        = bool
  default     = true
}

variable "default_abort_incomplete_multipart_upload_days" {
  description = "Number of days after which incomplete multipart uploads are aborted when 'enable_abort_incomplete_multipart_upload' is 'true' and no per-rule override is provided."
  type        = number
  default     = 7
}

variable "object_ownership" {
  description = "Object ownership. Valid values are `BucketOwnerPreferred`, `ObjectWriter` or `BucketOwnerEnforced`. `BucketOwnerEnforced` is not compatible with the acl_* variables."
  type        = string
  default     = "BucketOwnerEnforced"
}

variable "public_access_config" {
  description = "A map of public access config, defaults to all values being `true`"
  type = object({
    block_public_acls       = optional(bool, true)
    block_public_policy     = optional(bool, true)
    ignore_public_acls      = optional(bool, true)
    restrict_public_buckets = optional(bool, true)
  })
  default = {}
}

variable "replication_role_name" {
  description = "Exact IAM role/policy name to use for the replication role. When null (default), the module auto-generates the name as `Replication-{bucket_name}`."
  type        = string
  default     = null
}

variable "permissions_boundary" {
  description = "ARN of an IAM policy to use as a permissions boundary for the replication IAM role. Required in environments where CI/Jenkins enforces boundaries on role creation."
  type        = string
  default     = null
}

variable "replication_role_attach_policy_inline" {
  description = "When set to true, Replication role permissions are attached as an inline role policy instead of a standalone managed policy. Use this when your environment restricts creation of IAM managed policies."
  type        = bool
  default     = false
}


variable "replication_config" {
  description = "Replication configuration, see README.md for details"
  type = object({
    enabled                = optional(bool, false)
    destination_bucket_arn = optional(string)
    destination_region     = optional(string)
    storage_class          = optional(string, "STANDARD")
    replica_owner          = optional(string)
    replica_account        = optional(string)
    enable_kms_encryption  = optional(bool, false)
    replica_kms_key_id     = optional(string)
    rules = optional(list(
      object({
        id                        = optional(string)
        status                    = optional(string, "Enabled")
        priority                  = optional(number)
        delete_marker_replication = optional(string, "Disabled")
        replica_modifications     = optional(string, "Disabled")
        filter = optional(object({
          prefix = optional(string)
          and = optional(list(
            object({
              prefix = optional(string)
              tags   = optional(map(string))
            })
          ))
          tags = optional(list(
            object({
              key   = optional(string)
              value = optional(string)
            })
          ))
        }))
      })
    ))
  })
  default = {}

  validation {
    condition     = var.replication_config.enabled ? var.replication_config.destination_bucket_arn != null : true
    error_message = "If replication_config.enabled is true, replication_config.destination_bucket_arn must have a value"
  }

  validation {
    condition     = var.replication_config.enabled && var.replication_config.enable_kms_encryption ? var.replication_config.replica_kms_key_id != null : true
    error_message = "If replication_config.enable_kms_encryption is true, replication_config.replica_kms_key_id must have a value"
  }
}

variable "sse_algorithm" {
  description = "Server-side encryption algorithm to use. Valid values are `AES256` or `aws:kms`."
  type        = string
  default     = "AES256"
}

variable "tags" {
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags."
  type        = map(string)
  default     = {}
}

variable "versioning_enabled" {
  description = "Defines whether bucket versioning is enables or disabled, enabled by default. If replication is enabled, versioning will be automatically enabled"
  type        = bool
  default     = true
}

variable "disable_default_alarms" {
  description = "To disable the best practice AWS alarms outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#S3). Please note bucket request metrics will be disabled if this is set to `true`"
  type        = bool
  default     = false
}

variable "alarm_sns_topics" {
  description = "List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions"
  type        = list(string)
  default     = []
}

variable "enable_all_alarm_actions" {
  type        = bool
  description = "Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions"
  default     = false
}

variable "alarm_metric_thresholds" {
  description = "A map of custom alarm thresholds. See [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#S3) for a list of metrics, the name of the metric is the key to use when setting a threshold"
  type = object({
    Average4xxErrors = optional(number)
    Average5xxErrors = optional(number)
    OperationsFailedReplication = optional(object({
      DestinationBucket = optional(string)
      RuleIdList        = optional(list(string))
      threshold         = optional(number)
    }))
  })
  default = {}
}

variable "disable_org_check" {
  type        = bool
  default     = false
  description = "Set this to `true` to remove the default trust policy which stops roles from outside the Experian Organization from assuming the replication IAM role. Only applicable if `replication_config` is enabled"
}

variable "disable_source_ip_check" {
  type        = bool
  default     = false
  description = "Set this to `true` to remove default bucket policy that denies any access to source IPs not originating from the EEC approved CIDR list"
}

variable "disable_source_vpce_check" {
  type        = bool
  default     = false
  description = "Set this to `true` for non-EEC compliant accounts, and if your terraform returns a `no matching EC2 VPC Endpoint found` error. Already disabled if `disable_source_ip_check` is `true`"
}

variable "allowed_source_vpce_ids" {
  type        = list(string)
  default     = []
  description = "List of VPC Endpoint IDs to allow access to the bucket. The local regional S3 VPCE gateway will automatically be added unless `disable_source_vpce_check` is `true`. Not used if `disable_source_ip_check` is `true`"
}

variable "object_lock_configuration" {
  type = object({
    mode  = string
    days  = optional(number)
    years = optional(number)
  })
  description = <<EOT
  Configuration block for specifying the default Object Lock retention settings for new objects placed in the specified bucket. You cannot disable S3 Object Lock or S3 Versioning for buckets once S3 Object Lock is enabled.
  Values:
  `mode`  - (Required) Default Object Lock retention mode you want to apply to new objects placed in the specified bucket. Valid values: `COMPLIANCE` or `GOVERNANCE`.
  `days`  - (Optional, Required if `years` is not specified) Number of days that you want to specify for the default retention period.
  `years` - (Optional, Required if `days` is not specified) Number of years that you want to specify for the default retention period.
  See the [Terraform documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_object_lock_configuration#default_retention) and the [AWS Documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/object-lock.html) for more information"
  EOT
  default     = null
}

variable "cloudwatch_tags" {
  type        = map(string)
  default     = {}
  description = "Cloudwatch Alarm tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags"
}
