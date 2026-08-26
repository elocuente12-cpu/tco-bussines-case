check "reserved_concurrent_executions_warning" {
  assert {
    condition     = var.reserved_concurrent_executions != -1
    error_message = <<EOF
Wiz Security Warning - Serverless-016
AWS Lambda allows you to set a concurrency limit for individual functions to prevent a single function from consuming all available concurrency in the AWS account and region. Setting a function-level concurrent execution limit helps in managing resource allocation, controlling costs, and preventing potential issues caused by unexpected traffic spikes or infinite loops in your Lambda functions.
EOF
  }
}

check "kms_key_arn_unset_warning" {
  assert {
    condition     = var.kms_key_arn != null || length(var.environment_variables) == 0
    error_message = <<EOF
Wiz Security Warning - Serverless-010
Lambda function environment variables should be encrypted at rest with a KMS customer master key.
EOF
  }
}
