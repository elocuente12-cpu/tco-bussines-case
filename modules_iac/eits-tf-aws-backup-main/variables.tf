#
# AWS Backup Config
#

variable "resource_type_opt_in_preference" {
  description = "Resources that are enabled for AWS Backup, note that this config makes changes to AWS Backup account/region wide, not just for this vault. List can change depending on region, use `aws backup describe-region-settings` to see available resources. Only used if `manage_region_settings` is `true`"
  type        = map(bool)
  default = {
    "Aurora"          = true
    "CloudFormation"  = false
    "DocumentDB"      = false
    "DynamoDB"        = true
    "EBS"             = true
    "EC2"             = true
    "EFS"             = true
    "FSx"             = true
    "Neptune"         = false
    "RDS"             = true
    "Redshift"        = false
    "S3"              = true
    "Storage Gateway" = false
    "VirtualMachine"  = false
  }
}

variable "manage_region_settings" {
  description = "Enables management of AWS Backup Region Settings using the `resource_type_opt_in_preference` variable. To disable this in order to manage region settings outside of this module, set to `false`"
  type        = bool
  default     = true
}

#
# AWS Backup vault
#

# Create backup report
variable "create_backup_vault" {
  description = "Enable creation of Vault for AWS Backup"
  type        = bool
  default     = false
}

variable "vault_name" {
  description = "Name of the backup vault to create. If not given, AWS use default"
  type        = string
  default     = null
}

variable "vault_kms_key_arn" {
  description = "The server-side encryption key that is used to protect your backups"
  type        = string
  default     = null
}

variable "vault_lock_config" {
  description = "A map to configure [AWS Backup Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html). To enable Vault Lock, set `enabled` to `true`, see type for default values. Only used if `create_backup_vault` is `true`"
  type = object({
    enabled             = optional(bool, false)
    changeable_for_days = optional(number, null)
    max_retention_days  = optional(number, 180)
    min_retention_days  = optional(number, 14)
  })
  default = {}
}

variable "vault_force_destroy" {
  description = "A boolean that indicates that all recovery points stored in the vault are deleted so that the vault can be destroyed without error. PLEASE NOTE: This is irreversible and will delete all recovery points in the vault when destroyed!"
  type        = bool
  default     = false
}

# LAG vault
variable "create_backup_lag_vault" {
  description = "Set to `true` to create a logically air-gapped backup vault"
  type        = bool
  default     = false
}

variable "lag_vault_name" {
  description = "Name of the logically air-gapped backup vault to create. Required if `create_backup_lag_vault` is `true`. "
  type        = string
  default     = null

  validation {
    condition     = var.create_backup_lag_vault ? var.lag_vault_name != null : true
    error_message = "`lag_vault_name` must be specified if `create_backup_lag_vault` is `true`."
  }
}

variable "lag_vault_lock_config" {
  description = "A map to configure [AWS Backup Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html) for the LAG vault. Only used if `create_backup_lag_vault` is `true`."
  type = object({
    min_retention_days = optional(number, 7)
    max_retention_days = optional(number, 30)
  })
  default = {
    min_retention_days = 7
    max_retention_days = 30
  }
}

variable "lag_vault_max_retention_days" {
  description = "Maximum retention period that the Logically Air Gapped Backup Vault retains recovery points. Only used by the Lambda function if it's unable to obtain the retention period from the intermediate vault copy."
  type        = number
  default     = null
}

variable "lag_vault_encryption_key_arn" {
  description = "  KMS key ARN used to encrypt the logically air-gapped vault. It's recommended to leave this `null` so to use the AWS owned key (AOK)."
  type        = string
  default     = null
}

variable "lag_vault_policy" {
  description = "Optional JSON access policy to apply to the logically air-gapped vault. Only used if `create_backup_lag_vault` is `true`. If not provided, a default policy to allow copies will be applied to the LAG vault."
  type        = string
  default     = null
}

variable "lag_vault_shared_accounts" {
  description = "List of AWS account IDs that the logically air-gapped vault will be shared with. Only used if `create_backup_lag_vault` is `true`"
  type        = list(string)
  default     = []
}

variable "copy_to_lag" {
  description = <<EOT
  Set to `true` to create a Lambda function that copies recovery points from an intermediate backup vault to theLAG vault.
  To use this, you must create a temporary intermediate vault, and configure a backup copy to that intermediate vault. The Lambda function will then copy those recovery points to the LAG vault.
  EOT
  type        = bool
  default     = false
}

variable "intermediate_vault_name" {
  description = "Name of the intermediate backup vault to copy recovery points from. Only used if `copy_to_lag` is `true`"
  type        = string
  default     = null

  validation {
    condition     = var.copy_to_lag ? var.intermediate_vault_name != null : true
    error_message = "`intermediate_vault_name` must be specified if `copy_to_lag` is `true`."
  }
}

# Alarms
variable "enable_vault_alarms" {
  description = "A map of backup vault alarm metrics to configure, set a metric to `true` to configure the CloudWatch alarm. Default threshold is greater than 1 within 60 minutes. Use `alarm_sns_topics` to enable alarm actions. Only used if `create_backup_vault` is `true`"
  type = object({
    NumberOfBackupJobsFailed      = optional(bool, false)
    NumberOfBackupJobsExpired     = optional(bool, false)
    NumberOfBackupJobsAborted     = optional(bool, false)
    NumberOfCopyJobsFailed        = optional(bool, false)
    NumberOfRestoreJobsFailed     = optional(bool, false)
    NumberOfRecoveryPointsExpired = optional(bool, false)
  })
  default = {}
}

variable "alarm_sns_topics" {
  description = "List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions. Only used if `enable_vault_alarms` is configured and `create_backup_vault` is `true`"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A mapping of tags to assign to the resource"
  type        = map(string)
  default     = {}
}

#
# AWS Backup plan
#

variable "backup_plan_name" {
  description = "The name of the backup plan"
  type        = string
  default     = ""
}

# Rules
variable "backup_rules" {
  description = "A list of rule maps. If `create_backup_vault` is `true` then `target_vault_name` will be automatically populated if omitted from the map"
  type = list(object({
    rule_name                = optional(string)
    target_vault_name        = optional(string)
    schedule                 = optional(string)
    start_window             = optional(number)
    completion_window        = optional(number)
    enable_continuous_backup = optional(bool)
    recovery_point_tags      = optional(map(string), {})
    lifecycle = optional(object({
      cold_storage_after = optional(number, 0)
      delete_after       = optional(number, 90)
    }))
    copy_actions = optional(list(object({
      destination_vault_arn = optional(string)
      lifecycle = optional(object({
        cold_storage_after = optional(number, 0)
        delete_after       = optional(number, 90)
      }))
    })), [])
    scan_mode                                    = optional(string)
    target_logically_air_gapped_backup_vault_arn = optional(string)
  }))
  default = []

  validation {
    condition = alltrue([
      for rule in var.backup_rules :
      try(rule.scan_mode, null) == null || contains(["FULL_SCAN", "INCREMENTAL_SCAN"], rule.scan_mode)
    ])
    error_message = "backup_rules[*].scan_mode must be FULL_SCAN or INCREMENTAL_SCAN when configured."
  }

}

variable "scanner_resource_types" {
  description = "Resource types for malware scan setting when any backup rule configures scan_mode."
  type        = list(string)
  default     = ["ALL"]

  validation {
    condition = alltrue([
      for value in var.scanner_resource_types :
      contains(["EBS", "EC2", "S3", "ALL"], value)
    ])
    error_message = "scanner_resource_types values must be EBS, EC2, S3, or ALL."
  }
}

variable "scanner_role_arn" {
  description = "IAM role ARN used for malware scans when scan_mode is configured in any backup rule. If omitted and create_backup_iam_role=true, the module-created backup role ARN is used."
  type        = string
  default     = null
}

# Selection
variable "backup_selections" {
  description = "A list of selection maps"
  type        = any
  default     = []
}

variable "backup_enabled" {
  description = "Change to false to avoid deploying any AWS Backup resources"
  type        = bool
  default     = true
}

# Windows Backup parameter
variable "vss_enabled" {
  description = "Enable Windows VSS backup option and create a VSS Windows backup"
  type        = bool
  default     = false
}

# Create backup report
variable "create_backup_report" {
  description = "Enable creation of reports for AWS Backup"
  type        = bool
  default     = false
}

# Backup report name
variable "backup_report_name" {
  description = "The name of the backup report"
  type        = string
  default     = ""
}

# Backup report description
variable "backup_report_description" {
  description = "The description of the backup report"
  type        = string
  default     = "Backup jobs report by Experian"
}

# S3 bucket for reports
variable "s3_backup_report_bucket_name" {
  description = "Name of the S3 bucket where to store the backup jobs reports"
  type        = string
  default     = ""
}

#
# Notifications
#

variable "backup_sns_topic_name" {
  description = "Name of the SNS topic"
  type        = string
  default     = ""
}

variable "backup_sns_topic_name_prefix" {
  description = "Prefix of the SNS topic. If left `null`, a prefix will be automatically calculated based on account name in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E)"
  type        = string
  default     = null
}

variable "backup_notifications" {
  description = "Notification block which defines backup vault events and the SNS Topic ARN to send AWS Backup notifications to. Leave it empty to disable notifications"
  type        = any
  default     = {}
}

variable "sns_kms_key_id" {
  description = "The server-side encryption key that is used to encrypt the SNS Topic"
  type        = string
  default     = "alias/aws/sns"
}

#
# IAM
#

variable "create_backup_iam_role" {
  description = "Enable creation of IAM role for AWS Backup"
  type        = bool
  default     = false
}

variable "iam_role_arn" {
  description = "If configured, the module will attach this role to selections, instead of creating IAM resources by itself"
  type        = string
  default     = null
}

variable "iam_role_name" {
  description = "IAM role name"
  type        = string
  default     = "AWSBackup"
}

variable "iam_policy_name" {
  description = "IAM policy name"
  type        = string
  default     = "AWSBackup"
}

variable "backup_custom_policy" {
  description = "JSON custom policy to add to the default backup policy, if needed"
  type        = string
  default     = ""
}

variable "backup_custom_assume_role" {
  description = "JSON policy document to replace the default assume role policy, if needed. Remember to allow action 'sts:AssumeRole' for service 'backup.amazonaws.com'"
  type        = string
  default     = ""
}

variable "disable_org_check" {
  type        = bool
  description = "Set this to true to remove the Deny permission in the trust policy which stops services from outside the Experian Organization from assuming the role"
  default     = false
}

variable "create_vault_policy" {
  type        = bool
  description = "If enabled, a policy that disables deleting snapshots from a vault will be created and deployed to the backup vault."
  default     = true
}

variable "backup_ec2_pass_role_names" {
  type        = list(string)
  description = "List of IAM roles that the created Backup role will be allowed to pass to the EC2 service (in order to restore instances), must be in the same account as the Backup vault. Only used if `create_backup_iam_role` is `true`. By default allows the role associated with the standard EEC instance profile."
  default     = ["eec-aws-ami-factory-instance-role"]
}
