### AWS BACKUP ###

# Create tracking tags from EITS vars module
module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-backup"
  tags        = var.tags
}

# Merge tracking tags and var tags
locals {
  target_vault_name = var.create_backup_vault ? aws_backup_vault.bkp_vault[0].id : "Default"
  tags              = merge(var.tags, module.eits_ce_common.tags)
  has_scan_rule = anytrue([
    for rule in var.backup_rules : try(rule.scan_mode, null) != null
  ])
  effective_scan_setting = local.has_scan_rule ? {
    malware_scanner  = "GUARDDUTY"
    resource_types   = var.scanner_resource_types
    scanner_role_arn = coalesce(var.scanner_role_arn, try(module.bkp_scanner_iam_role[0].role_arn, null))
  } : null
}

check "scan_setting_required_for_scan_mode" {
  assert {
    condition = alltrue([
      for rule in var.backup_rules :
      try(rule.scan_mode, null) == null || local.effective_scan_setting != null
    ])
    error_message = "Malware scan settings could not be resolved."
  }
}

check "scanner_role_arn_required_for_scan_setting" {
  assert {
    condition     = local.effective_scan_setting == null || local.effective_scan_setting.scanner_role_arn != null
    error_message = "`scanner_role_arn` is required for malware scan when a scan rule has been configured."
  }
}

# Enable/Opt-in services
resource "aws_backup_region_settings" "this" {
  count = var.manage_region_settings ? 1 : 0

  resource_type_opt_in_preference = var.resource_type_opt_in_preference
}

# AWS Backup vault
resource "aws_backup_vault" "bkp_vault" {
  count = var.create_backup_vault ? 1 : 0

  name          = var.vault_name
  kms_key_arn   = var.vault_kms_key_arn
  force_destroy = var.vault_force_destroy
  tags          = local.tags

  lifecycle {
    ignore_changes = [
      tags["CreatedOn"]
    ]
  }
}

resource "aws_backup_vault_policy" "deny_delete" {
  count             = var.create_backup_vault && var.create_vault_policy ? 1 : 0
  backup_vault_name = aws_backup_vault.bkp_vault[0].name
  policy            = data.aws_iam_policy_document.aws_backup_deny_deletions[0].json
}

resource "aws_backup_vault_lock_configuration" "this" {
  count = var.create_backup_vault && var.vault_lock_config.enabled ? 1 : 0

  backup_vault_name   = aws_backup_vault.bkp_vault[0].id
  changeable_for_days = var.vault_lock_config.changeable_for_days
  max_retention_days  = var.vault_lock_config.max_retention_days
  min_retention_days  = var.vault_lock_config.min_retention_days
}

# AWS Backup plan
resource "aws_backup_plan" "bkp_plan" {
  count = var.backup_enabled ? 1 : 0
  name  = var.backup_plan_name

  # Rules
  dynamic "rule" {
    for_each = var.backup_rules
    content {
      rule_name                                    = rule.value.rule_name
      target_vault_name                            = rule.value.target_vault_name != null ? rule.value.target_vault_name : local.target_vault_name
      schedule                                     = rule.value.schedule
      start_window                                 = rule.value.start_window
      completion_window                            = rule.value.completion_window
      enable_continuous_backup                     = rule.value.enable_continuous_backup
      recovery_point_tags                          = length(rule.value.recovery_point_tags) > 0 ? rule.value.recovery_point_tags : local.tags
      target_logically_air_gapped_backup_vault_arn = rule.value.target_logically_air_gapped_backup_vault_arn

      # Lifecycle
      dynamic "lifecycle" {
        for_each = rule.value.lifecycle != null ? [rule.value.lifecycle] : []

        content {
          cold_storage_after = lifecycle.value.cold_storage_after
          delete_after       = lifecycle.value.delete_after
        }
      }

      # Copy action
      dynamic "copy_action" {
        for_each = rule.value.copy_actions
        content {
          destination_vault_arn = copy_action.value.destination_vault_arn

          # Copy Action Lifecycle
          dynamic "lifecycle" {
            for_each = copy_action.value.lifecycle != null ? [copy_action.value.lifecycle] : []
            content {
              cold_storage_after = lifecycle.value.cold_storage_after
              delete_after       = lifecycle.value.delete_after
            }
          }
        }
      }

      # Malware scan action
      dynamic "scan_action" {
        for_each = try(rule.value.scan_mode, null) != null ? [rule] : []
        content {
          malware_scanner = "GUARDDUTY"
          scan_mode       = rule.value.scan_mode
        }
      }
    }
  }

  # Malware scan setting (plan-level)
  dynamic "scan_setting" {
    for_each = local.effective_scan_setting != null ? [local.effective_scan_setting] : []
    content {
      malware_scanner  = scan_setting.value.malware_scanner
      resource_types   = scan_setting.value.resource_types
      scanner_role_arn = scan_setting.value.scanner_role_arn
    }
  }

  # Advanced backup setting
  dynamic "advanced_backup_setting" {
    for_each = var.vss_enabled ? [1] : []
    content {
      backup_options = {
        WindowsVSS = "enabled"
      }
      resource_type = "EC2"
    }
  }

  # Tags
  tags = local.tags
  lifecycle {
    ignore_changes = [
      tags["CreatedOn"]
    ]
  }

  # First create the vault if needed
  depends_on = [aws_backup_vault.bkp_vault]
}

### RESOURCE SELECTION ###
resource "aws_backup_selection" "bkp_selection" {

  count = var.backup_enabled ? length(var.backup_selections) : 0

  iam_role_arn = var.iam_role_arn != null ? var.iam_role_arn : module.bkp_iam_role[0].role_arn #aws_iam_role.bkp_role[0].arn
  name         = lookup(element(var.backup_selections, count.index), "name", aws_backup_plan.bkp_plan[0].id)
  plan_id      = aws_backup_plan.bkp_plan[0].id

  resources     = lookup(element(var.backup_selections, count.index), "resources", null)
  not_resources = lookup(element(var.backup_selections, count.index), "not_resources", null)

  condition {
    dynamic "string_equals" {
      for_each = lookup(lookup(element(var.backup_selections, count.index), "conditions", {}), "string_equals", [])
      content {
        key   = lookup(string_equals.value, "key", null)
        value = lookup(string_equals.value, "value", null)
      }
    }
  }
}

### BACKUP JOPS REPORT ###
resource "aws_backup_report_plan" "bkp_backup_jobs_report" {
  count = var.create_backup_report ? 1 : 0

  name        = var.backup_report_name == "" ? "backup_jobs_report_${data.aws_caller_identity.current.account_id}" : var.backup_report_name
  description = var.backup_report_description

  report_delivery_channel {
    formats = [
      "CSV"
    ]
    s3_bucket_name = var.s3_backup_report_bucket_name
  }

  report_setting {
    report_template = "BACKUP_JOB_REPORT"
  }

  tags = local.tags

  lifecycle {
    ignore_changes = [
      tags["CreatedOn"]
    ]
  }
}

### IAM ###

module "bkp_iam_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = var.create_backup_iam_role ? 1 : 0

  role_name          = var.iam_role_name
  role_description   = "IAM role for AWS Backup"
  policy_name        = var.iam_policy_name
  policy_description = "IAM policy for AWS Backup"
  assume_role_policy = length(var.backup_custom_assume_role) > 0 ? var.backup_custom_assume_role : data.aws_iam_policy_document.aws_backup_assume_role.json
  policy_documents   = [data.aws_iam_policy_document.aws_backup_role.json]
  disable_org_check  = var.disable_org_check
  managed_policy_arns = concat(
    [
      "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup",
      "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup",
      "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores",
      "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
    ],
    local.has_scan_rule ? ["arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForScans"] : []
  )

  tags = local.tags
}

module "bkp_scanner_iam_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git?ref=1.9.7"
  count  = local.has_scan_rule && var.scanner_role_arn == null ? 1 : 0

  role_name          = "${var.iam_role_name}-scanner"
  role_description   = "IAM role for AWS Backup Malware Scanning"
  policy_name        = "${var.iam_policy_name}-scanner"
  policy_description = "IAM policy for AWS Backup Malware Scanning"
  assume_role_policy = data.aws_iam_policy_document.aws_backup_scanner_assume_role.json
  policy_documents   = [data.aws_iam_policy_document.aws_backup_scanner_role.json]
  disable_org_check  = true

  tags = local.tags
}
