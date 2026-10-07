variable "aliases" {
  type        = list(string)
  default     = []
  description = <<EOF
  A list of aliases.
  If configured, an alias for each element of the list will be built in this format: alias/{local.prefix}-{alias}-kms
  If not configured, one single alias will be built in this format: alias/{local.prefix}-{dash-separated-services-from-key_services}-kms
  EOF
}

variable "description" {
  type        = string
  default     = null
  description = "The description of the key as viewed in AWS console"
}

variable "deletion_window_in_days" {
  type        = number
  default     = 30
  description = "The window you have to restore a disabled KMS key before it is gone forever"
}

variable "is_enabled" {
  type        = bool
  default     = true
  description = "Specifies whether the key is enabled. Defaults to `true`."
}

variable "key_usage" {
  type        = string
  default     = "ENCRYPT_DECRYPT"
  description = "Specifies the intended use of the key. Valid values: `ENCRYPT_DECRYPT`,`SIGN_VERIFY`, or `GENERATE_VERIFY_MAC`. Defaults to `ENCRYPT_DECRYPT`"
}


variable "key_owners" {
  type        = list(string)
  default     = []
  description = "A list of IAM ARNs for those who will have full key permissions (`kms:*`)"
}

variable "key_administrators" {
  type        = list(string)
  default     = []
  description = "A list of IAM ARNs for [key administrators](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators)"
}

variable "key_users" {
  type        = list(string)
  default     = []
  description = "A list of IAM ARNs for [key users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-users)"
}

variable "key_services" {
  type        = list(string)
  default     = []
  description = "A list of AWS services for [key users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-users)"
}

variable "key_service_users" {
  type        = list(string)
  default     = []
  description = "A list of IAM ARNs for [key service users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-service-integration)"
}

variable "key_symmetric_encryption_users" {
  type        = list(string)
  default     = []
  description = "A list of IAM ARNs for [key symmetric encryption users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto)"
}

variable "key_hmac_users" {
  type        = list(string)
  default     = []
  description = "A list of IAM ARNs for [key HMAC users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto)"
}

variable "key_asymmetric_public_encryption_users" {
  type        = list(string)
  default     = []
  description = "A list of IAM ARNs for [key asymmetric public encryption users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto)"
}

variable "key_asymmetric_sign_verify_users" {
  type        = list(string)
  default     = []
  description = "A list of IAM ARNs for [key asymmetric sign and verify users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto)"
}

variable "external_key" {
  type        = bool
  default     = false
  description = "Whether the created key is external"
}

variable "key_material_base64" {
  type        = string
  default     = null
  description = "Provide the base64 key material for key imports. This will create an external key if provided, and a regular KMS key if not. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_external_key for more details"
  sensitive   = true
}

variable "key_statements" {
  type        = any
  default     = {}
  description = "A map of IAM policy [statements](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document#statement) for custom permission usage"
}

variable "grants" {
  type = map(object({
    name              = optional(string)
    grantee_principal = string
    operations        = list(string)
    constraints = optional(map(object({
      encryption_context_equals = optional(map(string))
      encryption_context_subset = optional(map(string))
    })), {})
    retiring_principal    = optional(string)
    grant_creation_tokens = optional(list(string))
    retire_on_delete      = optional(bool)
  }))
  default     = {}
  description = "A map of grant definitions to create, see type definition and [Terraform docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_grant) for details. Note that grants will not be created if `external_key` is true and `key_material_base64` is not provided, as the key must have key material to be able to create grants"
  validation {
    condition     = length(var.grants) > 0 ? !var.external_key || (var.external_key && var.key_material_base64 != null) : true
    error_message = "Grants cannot be created for an external key without key material. Please provide `key_material_base64` or set `external_key` to false to create grants."
  }
}

variable "multi_region" {
  type        = bool
  default     = false
  description = "Indicates whether the KMS key is a multi-Region (true) or regional (false) key. Defaults to `false`."
}

variable "policy" {
  type        = string
  default     = null
  description = "A valid policy JSON document, will be merged with any configuration supplied to the key_* variables, Although this is a key policy, not an IAM policy, an `aws_iam_policy_document`, in the form that designates a principal, can be used"
}

variable "prefix" {
  type        = string
  default     = ""
  description = "Used for naming your cloud resources. The KMS alias will be 'alias/{local.prefix}-{alias}-kms'"
}

variable "xks_key_id" {
  type        = string
  default     = null
  description = "Identifies the external key that serves as key material for the KMS key in an external key store.  This variable is ignored if `external_key` is true."
}

variable "custom_key_store_id" {
  type        = string
  default     = null
  description = "ID of the KMS Custom Key Store where the key will be stored instead of KMS. This variable is ignored if `external_key` is true."
}

variable "rotation_period_in_days" {
  type        = number
  default     = 365
  description = "Custom period of time between each rotation date. Must be a number between 90 and 2560. This variable is ignored if `external_key` is true."
}

variable "customer_master_key_spec" {
  type        = string
  default     = "SYMMETRIC_DEFAULT"
  description = "Specifies the type of KMS key to create. Defaults to `SYMMETRIC_DEFAULT`. For a list of valid values and help with choosing a key spec, see the [AWS KMS Developer Guide](https://docs.aws.amazon.com/kms/latest/developerguide/symm-asymm-choose.html). This variable is ignored if `external_key` is true."
}

# TAGS #

variable "tags" {
  type        = map(string)
  default     = {}
  description = "KMS key tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags"
}
