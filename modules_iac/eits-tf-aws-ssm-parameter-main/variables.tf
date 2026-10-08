variable "secure_type" {
  description = "Whether the type of the value should be considered as secure or not"
  type        = bool
  default     = false
}

################################################################################
# SSM Parameter
################################################################################

variable "name" {
  description = "Name of SSM parameter"
  type        = string
  default     = null
}

variable "value" {
  description = "Value of the parameter"
  type        = string
  default     = null
}

variable "value_wo" {
  description = "Write-only alternative to `value`. Sets the parameter value without storing it in Terraform state or plan files. Requires Terraform v1.11.0 or later. Primarily intended for sensitive data, especially `SecureString` parameters. Mutually exclusive with `value` and `values`."
  type        = string
  default     = null
  sensitive   = true
}

variable "value_wo_version" {
  description = "Version number used to trigger updates to `value_wo`. Increment this value to force a re-write of the parameter when `value_wo` is used."
  type        = number
  default     = null
}

variable "values" {
  description = "List of values of the parameter (will be jsonencoded to store as string natively in SSM)"
  type        = list(string)
  default     = []
}

variable "description" {
  description = "Description of the parameter"
  type        = string
  default     = null
}

variable "type" {
  description = "Type of the parameter. Valid types are `String`, `StringList` and `SecureString`."
  type        = string
  default     = null
}

variable "tier" {
  description = "Parameter tier to assign to the parameter. If not specified, will use the default parameter tier for the region. Valid tiers are `Standard`, `Advanced`, and `Intelligent-Tiering`. Downgrading an `Advanced` tier parameter to `Standard` will recreate the resource. For more information on parameter tiers, see the [AWS SSM Parameter tier comparison and guide](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html)."
  type        = string
  default     = null
}

variable "key_id" {
  description = "KMS key ID or ARN for encrypting a parameter (when type is `SecureString`). By default `SecureString` will use the default AWS KMS key `alias/aws/ssm`, but it is recommended to use a customer managed key if possible."
  type        = string
  default     = "alias/aws/ssm"
}

variable "allowed_pattern" {
  description = "Regular expression used to validate the parameter value."
  type        = string
  default     = null
}

variable "data_type" {
  description = "Data type of the parameter. Valid values: `text`, `aws:ssm:integration` and `aws:ec2:image` for AMI format."
  type        = string
  default     = null
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for AWS resources. See the [Experian Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E)"
}
