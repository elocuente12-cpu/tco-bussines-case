output "backup_lag_vault_id" {
  description = "Backup lag vault ID from malware scan test"
  value       = module.aws_backup_lag_vault.backup_lag_vault_id
}

output "backup_lag_vault_arn" {
  description = "Backup lag vault ARN from malware scan test"
  value       = module.aws_backup_lag_vault.backup_lag_vault_arn
}
