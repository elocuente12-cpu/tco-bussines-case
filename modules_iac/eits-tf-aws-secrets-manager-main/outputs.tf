
output "secret_id" {
  description = "Amazon Resource Name (ARN) of the secret."
  value       = aws_secretsmanager_secret.this.id
}

output "secret_arn" {
  description = "Amazon Resource Name (ARN) of the secret."
  value       = aws_secretsmanager_secret.this.arn
}

output "secret_replica" {
  description = "All attributes for replica"
  value       = aws_secretsmanager_secret.this.replica
}

output "rotation_enabled" {
  description = "Specifies whether automatic rotation is enabled for this secret"
  value       = try(aws_secretsmanager_secret_rotation.this[0].rotation_enabled, false)
}

output "secret_version" {
  description = "The unique identifier of the version of the secret."
  value       = aws_secretsmanager_secret_version.this.version_id
}
