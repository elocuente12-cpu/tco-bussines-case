data "aws_default_tags" "account_tags" {}
data "aws_vpc" "this" {
  id = var.vpc_id
}
data "aws_subnet" "this" {
  count = length(var.security_group_ids) > 0 ? 0 : 1

  id = var.subnet_ids[0]
}

module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-fsx-windows"
  tags        = var.tags
}

resource "aws_fsx_windows_file_system" "this" {
  aliases                           = var.aliases
  storage_capacity                  = var.storage_capacity
  storage_type                      = var.storage_type
  subnet_ids                        = var.subnet_ids
  throughput_capacity               = var.throughput_capacity
  weekly_maintenance_start_time     = var.weekly_maintenance_start_time
  automatic_backup_retention_days   = var.automatic_backup_retention_days
  backup_id                         = var.backup_id
  copy_tags_to_backups              = var.copy_tags_to_backups
  daily_automatic_backup_start_time = var.daily_automatic_backup_start_time
  skip_final_backup                 = var.skip_final_backup
  deployment_type                   = local.environment == "prd" ? "MULTI_AZ_1" : var.deployment_type
  kms_key_id                        = var.create_kms_key ? module.fsx_kms[0].key_arn : var.kms_key_arn
  preferred_subnet_id               = var.preferred_subnet_id
  security_group_ids                = length(var.security_group_ids) > 0 ? var.security_group_ids : [module.fsx_security_group[0].id]

  audit_log_configuration {
    audit_log_destination             = var.create_cloudwatch_log_group ? module.fsx_cloudwatch_log_group[0].log_group_arn : var.audit_log_configuration.audit_log_destination
    file_access_audit_log_level       = var.audit_log_configuration.file_access_audit_log_level
    file_share_access_audit_log_level = var.audit_log_configuration.file_share_access_audit_log_level
  }

  # This block is dynamic as otherwise it wouldn't accept null values or having both values configured like below in the variable definition
  dynamic "disk_iops_configuration" {
    for_each = var.disk_iops_configuration != null ? [var.disk_iops_configuration] : []

    content {
      iops = try(disk_iops_configuration.value.iops, 3)
      mode = try(disk_iops_configuration.value.mode, "AUTOMATIC")
    }
  }

  self_managed_active_directory {
    dns_ips                                = var.self_managed_active_directory.dns_ips
    domain_name                            = var.self_managed_active_directory.domain_name
    file_system_administrators_group       = var.self_managed_active_directory.file_system_administrators_group
    organizational_unit_distinguished_name = var.self_managed_active_directory.organizational_unit_distinguished_name
    username                               = var.self_managed_active_directory.username
    password                               = var.self_managed_active_directory.password
  }

  timeouts {
    create = var.timeouts.create
    update = var.timeouts.update
    delete = var.timeouts.delete
  }

  tags = merge(local.tags, {
    "Name" = "${var.name}-fsx"
  })
}

resource "aws_fsx_backup" "this" {
  count = var.automatic_backup_retention_days > 0 ? 1 : 0

  file_system_id = aws_fsx_windows_file_system.this.id
  tags           = local.tags
}

module "fsx_security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git?ref=3.5.1"
  count  = length(var.security_group_ids) > 0 ? 0 : 1

  security_group_name          = "fsx_${var.name}"
  security_group_description   = "Security group for FSx Windows File Server ${var.name}"
  vpc_id                       = data.aws_subnet.this[0].vpc_id
  security_group_ingress_rules = local.security_group_ingress_rules
  security_group_egress_rules  = local.security_group_egress_rules

  tags = merge(local.tags, { "eitsce:parentmodule" = "eits-tf-aws-fsx-windows" })
}

module "fsx_cloudwatch_log_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs?ref=2.6.1"
  count  = var.create_cloudwatch_log_group ? 1 : 0

  log_group_name    = "/aws/fsx/${var.name}"
  retention_in_days = var.cloudwatch_log_group_retention != null ? var.cloudwatch_log_group_retention : (local.environment == "prd" ? 90 : 30)
  resource_policy_principals = {
    Service = ["fsx.amazonaws.com"]
  }

  tags = merge(local.tags, { "eitsce:parentmodule" = "eits-tf-aws-fsx-windows" })
}

module "fsx_kms" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms?ref=1.9.0"
  count  = var.create_kms_key ? 1 : 0

  aliases      = [var.name]
  description  = "KMS key for FSx for Windows file system ${var.name}"
  key_services = ["fsx"]

  tags = merge(local.tags, { "eitsce:parentmodule" = "eits-tf-aws-fsx-windows" })
}
