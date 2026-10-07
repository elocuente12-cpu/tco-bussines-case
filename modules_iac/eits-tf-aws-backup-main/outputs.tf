output "backup_events_sns_topic_arn" {
  description = "The ARN of the backup SNS topic, if created"
  value       = try(module.backup_events_sns[0].topic_arn, null)
}

output "backup_plan_id" {
  description = "The ID of the backup plan, if created"
  value       = try(aws_backup_plan.bkp_plan[0].id, null)
}

output "backup_plan_arn" {
  description = "The ARN of the backup plan, if created"
  value       = try(aws_backup_plan.bkp_plan[0].arn, null)
}

output "backup_iam_role" {
  description = "IAM role ARN for AWS Backup service, if created"
  value       = try(module.bkp_iam_role[0].role_arn, null)
}

output "backup_vault_id" {
  description = "Backup vault name, if created"
  value       = try(aws_backup_vault.bkp_vault[0].id, null)
}

output "backup_vault_arn" {
  description = "Backup vault ARN, if created"
  value       = try(aws_backup_vault.bkp_vault[0].arn, null)
}

output "backup_lag_vault_id" {
  description = "Logically air gapped vault name, if created"
  value       = try(aws_backup_logically_air_gapped_vault.this[0].id, null)
}

output "backup_lag_vault_arn" {
  description = "Logically air gapped vault ARN, if created"
  value       = try(aws_backup_logically_air_gapped_vault.this[0].arn, null)
}

output "backup_lag_vault_iam_role_lambda_arn" {
  description = "IAM role ARN for AWS Backup LAG vault copy Lambda function, if created"
  value       = try(module.iam_role_lag_lambda[0].role_arn, null)
}

output "backup_lag_vault_lambda_copy_function_arn" {
  description = "ARN of the AWS Backup LAG vault copy Lambda function, if created"
  value       = try(module.lambda_copy_to_lag[0].arn, null)
}

output "backup_lag_vault_lambda_cleanup_function_arn" {
  description = "ARN of the AWS Backup LAG vault copy cleanup Lambda function, if created"
  value       = try(module.lambda_cleanup_temp_vault[0].arn, null)
}

output "backup_lag_vault_eventbridge_copy_rule_arn" {
  description = "ARN of the AWS Backup LAG vault copy EventBridge rule, if created"
  value       = try(module.eventbridge_backup_lag_copy[0].rule_arn, null)

}

output "backup_lag_vault_eventbridge_cleanup_rule_arn" {
  description = "ARN of the AWS Backup LAG vault copy cleanup EventBridge rule, if created"
  value       = try(module.eventbridge_backup_cleanup_temp_vault[0].rule_arn, null)
}