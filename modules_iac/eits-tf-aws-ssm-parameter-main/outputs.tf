
output "parameter_value" {
  description = "Secure value of the parameter"
  value       = aws_ssm_parameter.this.value == null ? aws_ssm_parameter.this.insecure_value : aws_ssm_parameter.this.value
  sensitive   = true
}

output "secure_type" {
  description = "Whether SSM parameter is a SecureString or not"
  value       = local.secure_type
}

################
# SSM Parameter
################

output "ssm_parameter_arn" {
  description = "The ARN of the parameter"
  value       = aws_ssm_parameter.this.arn
}

output "ssm_parameter_version" {
  description = "Version of the parameter"
  value       = aws_ssm_parameter.this.version
}

output "ssm_parameter_name" {
  description = "Name of the parameter"
  value       = aws_ssm_parameter.this.name
}

output "ssm_parameter_type" {
  description = "Type of the parameter"
  value       = aws_ssm_parameter.this.type
}

output "ssm_parameter_tags_all" {
  description = "All tags used for the parameter"
  value       = aws_ssm_parameter.this.tags_all
}
