variable "region" {
  type        = string
  description = "AWS region to provision into"
}

variable "lag_vault_shared_accounts" {
  type        = list(string)
  description = "List of AWS account IDs to share the logically air gapped vault with. Only applicable if `create_backup_lag_vault` is `true`."
  default     = ["077820194866"]
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}
