output "arn" {
  description = "ARN of the lambda function"
  value       = aws_lambda_function.this.arn
}

output "code_sha256" {
  description = "SHA256 hash of the function's deployment package"
  value       = aws_lambda_function.this.code_sha256
}

output "invoke_arn" {
  description = "Invoke ARN of the lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "qualified_arn" {
  description = "ARN identifying your Lambda Function Version (if versioning is enabled via publish = true)"
  value       = aws_lambda_function.this.qualified_arn
}

output "qualified_invoke_arn" {
  description = "Qualified ARN (ARN with lambda version number) to be used for invoking Lambda Function from API Gateway"
  value       = aws_lambda_function.this.qualified_invoke_arn
}

output "function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.this.function_name
}

output "version" {
  description = "Latest published version of your Lambda Function."
  value       = aws_lambda_function.this.version
}

output "role_name" {
  description = "Lambda IAM role name"
  value       = try(module.lambda_iam_role[0].role_name, reverse(split("/", var.role))[0])
}

output "role_arn" {
  description = "Lambda IAM role ARN"
  value       = try(module.lambda_iam_role[0].role_arn, var.role)
}

output "cloudwatch_log_group_name" {
  description = "Lambda CloudWatch log group name"
  value       = try(length(module.cloudwatch_log_group) > 0 ? module.cloudwatch_log_group[0].log_group_name : aws_lambda_function.this.logging_config[0].log_group, null)
}

output "function_url" {
  description = "The HTTP URL endpoint for the function in the format https://<url_id>.lambda-url.<region>.on.aws/"
  value       = var.function_url != null ? aws_lambda_function_url.this[0].function_url : null
}
