variable "name" {
  type        = string
  default     = null
  description = "Friendly name of the new secret. The secret name can consist of uppercase letters, lowercase letters, digits, and any of the following characters: /_+=.@-. Conflicts with `name_prefix`"
}

variable "name_prefix" {
  type        = string
  default     = null
  description = "Name for the resource, terraform will append a random suffix. Conflicts with `name`"
}

variable "kms_key_id" {
  type        = string
  default     = null
  description = "Customer Master Key Id to be used to encrypt the secrets values"
}

variable "description" {
  type        = string
  default     = null
  description = "Description of the secret."
}

variable "recovery_window_in_days" {
  type        = number
  default     = 30
  description = "Number of days that AWS Secrets Manager waits before it can delete the secret"
}

variable "policy" {
  type        = string
  default     = null
  description = "Removing `policy` from your configuration or setting `policy` to null or an empty string (i.e., `policy =`) will not delete the `policy` since it could have been set by `aws_secretsmanager_secret_policy`."
}

variable "policy_override" {
  type        = string
  default     = null
  description = "Override generated policy. Requires a valid JSON document representing a resource policy"
}

variable "force_overwrite_replica_secret" {
  type        = bool
  default     = false
  description = "Accepts boolean value to specify whether to overwrite a secret with the same name in the destination Region"
}

variable "secret_owners" {
  type        = list(string)
  default     = []
  description = "AWS principals that are granted ownership of the secret, terraform user will automatically be added"
}

variable "secret_users" {
  type        = list(string)
  default     = []
  description = "AWS principals that are allowed to use the secret"
}

variable "type" {
  type        = string
  default     = null
  description = "Type of secret. Valid values: `AWS_OPAQUE`, `AWS_MANAGED_ROTATION`. Required when using managed external secret rotation."
}

variable "rotation_lambda_arn" {
  type        = string
  default     = null
  description = "Specifies the ARN of the Lambda function that can rotate the secret. Must be supplied if the secret is not [Managed by AWS](https://docs.aws.amazon.com/secretsmanager/latest/userguide/service-linked-secrets.html)"
}

variable "rotate_immediately" {
  type        = bool
  default     = null
  description = "Specifies whether to rotate the secret immediately or wait until the next scheduled rotation window"
}

variable "external_secret_rotation_metadata" {
  type = list(object({
    key   = string
    value = string
  }))
  default     = []
  description = "One or more metadata key/value blocks required by the external rotation partner. Used with managed external secret rotation."
}

variable "external_secret_rotation_role_arn" {
  type        = string
  default     = null
  description = "ARN of the IAM role to be assumed by Secrets Manager to rotate the secret via an external rotation service. Used with managed external secret rotation."
}

variable "secret_string" {
  type        = string
  sensitive   = true
  default     = null
  description = "Specifies text data that you want to encrypt and store in this version of the secret. This is required if `secret_binary` is not set. Ignored if `generate_random_password` is `true`."
}

variable "secret_binary" {
  type        = string
  sensitive   = true
  default     = null
  description = "Specifies binary data that you want to encrypt and store in this version of the secret. This is required if `secret_string` is not set. Needs to be encoded to base64."
}

variable "version_stages" {
  type        = list(string)
  default     = []
  description = "Specifies a list of staging labels that are attached to this version of the secret. A staging label must be unique to a single version of the secret."
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}

variable "replicas" {
  type = list(object({
    kms_key_id = string,
    region     = string
  }))
  default     = []
  description = <<EOT
   Configuration block to support secret replication. Defined below.
   <pre>replicas =  
    [{
      kms_key_id  = (Optional) ARN, Key ID, or Alias of the `AWS KMS key` within the region secret is replicated to. If one is not specified, then Secrets Manager defaults to using the AWS account's default KMS key `(aws/secretsmanager)` in the region or creates one for use if non-existent.
      region               = (Required) Region for replicating the secret.
    }]
   </pre>
  EOT
}

variable "rotation_rules" {
  type = object({
    automatically_after_days = optional(number)
    duration                 = optional(string)
    schedule_expression      = optional(string)
  })
  default     = {}
  description = <<EOT
   A structure that defines the rotation configuration for this secret. Defined below.
   <pre>rotation_rules = 
    {
      automatically_after_days = (Optional) Specifies the number of days between automatic scheduled rotations of the secret. Either `automatically_after_days` or `schedule_expression` must be specified.
      duration                 = (Optional) The length of the rotation window in hours. For example, `3h` for a three hour window.
      schedule_expression      = (Optional) `A cron()` or `rate()` expression that defines the schedule for rotating your secret. Either `automatically_after_days` or `schedule_expression` must be specified.
    }
   </pre>
  EOT
}

variable "generate_random_password" {
  type        = bool
  default     = false
  description = "If `true`, a random password will be generated and used as the `secret_string` value."
}

variable "random_password_config" {
  type = object({
    exclude_characters         = optional(string)
    exclude_lowercase          = optional(bool)
    exclude_numbers            = optional(bool)
    exclude_punctuation        = optional(bool)
    exclude_uppercase          = optional(bool)
    include_space              = optional(bool)
    password_length            = optional(number)
    require_each_included_type = optional(bool)
  })
  default     = {}
  description = "Random password configuration to use when `generate_random_password` is `true`. By default, Secrets Manager uses uppercase and lowercase letters, numbers, and [these characters in passwords](https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetRandomPassword.html)."
}

variable "secret_string_version" {
  type        = number
  default     = 1
  description = "Increment this value when an update to `secret_string` is required, otherwise changes will be ignored by terraform. See README for details."
}
