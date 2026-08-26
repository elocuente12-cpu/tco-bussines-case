variable "alias_name" {
  type        = string
  description = "Creates an alias that points to the LATEST Lambda function version. If not set, no alias will be created. If aliases for specific versions are needed, use the `aws_lambda_alias` resource instead."
  default     = null
}

variable "architectures" {
  type        = list(string)
  description = <<EOF
    Instruction set architecture for your Lambda function. Valid values are ["x86_64"] and ["arm64"].
    Default is ["x86_64"]. Removing this attribute, function's architecture stay the same.
  EOF
  default     = ["x86_64"]
}

variable "cloudwatch_logs_retention_in_days" {
  type        = number
  description = <<EOF
  Specifies the number of days you want to retain log events in the specified log group. Possible values are:
  0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653. If 0 or omitted, the events in the
  log group are always retained and never expire.
  EOF
  default     = 0
}

variable "cloudwatch_logs_kms_key_arn" {
  type        = string
  description = "The ARN of the KMS Key to use when encrypting log data."
  default     = null
}

variable "cloudwatch_lambda_insights_enabled" {
  type        = bool
  description = "Enable CloudWatch Lambda Insights for the Lambda Function."
  default     = false
}

variable "alarm_sns_topics" {
  type        = list(string)
  default     = []
  description = "List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions"
}

variable "enable_all_alarm_actions" {
  type        = bool
  description = "Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions"
  default     = false
}

variable "alarm_metric_thresholds" {
  type = object({
    Errors               = optional(number),
    Throttles            = optional(number),
    Duration             = optional(number),
    ConcurrentExecutions = optional(number, 900),
    memory_utilization   = optional(number, 90)
  })
  default     = {}
  description = "A map of custom alarm thresholds. See [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#Route53) for a list of metrics, the name of the metric is the key to use when setting a threshold"
}

variable "disable_default_alarms" {
  type        = bool
  default     = false
  description = "To disable the best practice AWS alarms outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#Route53)"
}

variable "custom_iam_policy_arns" {
  type        = list(string)
  description = "ARNs of custom policies to be attached to the lambda role"
  default     = []
}

variable "dead_letter_config_target_arn" {
  type        = string
  description = <<EOF
  ARN of an SNS topic or SQS queue to notify when an invocation fails. If this option is used, the function's IAM role
  must be granted suitable access to write to the target object, which means allowing either the sns:Publish or
  sqs:SendMessage action on this ARN, depending on which service is targeted."
  EOF
  default     = null
}

variable "description" {
  type        = string
  description = "Description of what the Lambda Function does."
  default     = null
}

variable "environment_variables" {
  type        = map(string)
  description = "Map of environment variables that are accessible from the function code during execution. `NO_PROXY` is automatically configured if not provided and `vpc_config` is set."
  default     = {}
}

# DEPRECATED: Use environment_variables instead
variable "lambda_environment" {
  type = object({
    variables = map(string)
  })
  description = "DEPRECATED: Please use `environment_variables` instead. This variable will be removed in a future release."
  default     = null
}

variable "ephemeral_storage_size" {
  type        = number
  description = <<EOF
  The size of the Lambda function Ephemeral storage (/tmp) represented in MB.
  The minimum supported ephemeral_storage value defaults to 512MB and the maximum supported value is 10240MB.
  EOF
  default     = null
}

variable "filename" {
  type        = string
  description = "The path to the function's deployment package within the local filesystem. If defined, The s3_-prefixed options and image_uri cannot be used."
  default     = null
}

variable "function_scope" {
  type        = string
  description = "A mandatory input used for differentiating between different lambdas related to the same application, this will be interpolated into the function name."
}

variable "function_url" {
  type = object({
    invoke_mode = optional(string, "BUFFERED")
    cors = optional(object({
      allow_credentials = optional(bool)
      allow_headers     = optional(list(string))
      allow_methods     = optional(list(string))
      allow_origins     = optional(list(string))
      expose_headers    = optional(list(string))
      max_age           = optional(number)
    }), {})
  })
  description = "Create a dedicated HTTP(S) endpoint for the latest version of the Lambda function. See [lambda_function_url docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url) for required values. Please note that only `AWS_IAM` authorization is supported (you do not need to supply it)."
  default     = null
}

variable "handler" {
  type        = string
  description = "The function entrypoint in your code. It should be <function_filename>.<function_handler> (e.g., myfunction.lambda_handler)"
  default     = null
}

variable "ssm_iam_policy_description" {
  type        = string
  description = "Description of the IAM policy for the Lambda IAM role"
  default     = "Provides minimum SSM read permissions."
}

variable "image_config" {
  type        = any
  description = <<EOF
  The Lambda OCI [image configurations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#image_config)
  block with three (optional) arguments:
  - *entry_point* - The ENTRYPOINT for the docker image (type `list(string)`).
  - *command* - The CMD for the docker image (type `list(string)`).
  - *working_directory* - The working directory for the docker image (type `string`).
  EOF
  default     = {}
}

variable "image_uri" {
  type        = string
  description = "The ECR image URI containing the function's deployment package. Conflicts with filename, s3_bucket, s3_key, and s3_object_version."
  default     = null
}

variable "kms_key_arn" {
  type        = string
  description = <<EOF
  Amazon Resource Name (ARN) of the AWS Key Management Service (KMS) key that is used to encrypt environment variables.
  If this configuration is not provided when environment variables are in use, AWS Lambda uses a default service key.
  If this configuration is provided when environment variables are not in use, the AWS Lambda API does not save this
  configuration and Terraform will show a perpetual difference of adding the key. To fix the perpetual difference,
  remove this configuration.
  EOF
  default     = null
}

variable "lambda_at_edge_enabled" {
  type        = bool
  description = "Enable Lambda@Edge for your Node.js or Python functions. The required trust relationship and publishing of function versions will be configured in this module."
  default     = false
}

variable "lambda_function_recursion_config_enabled" {
  type        = bool
  description = "Enable recursion config for Lambda Function `note:` Destruction of this resource will return the `recursive_loop` configuration back to the default value of `Terminate`"
  default     = false
}

variable "layers" {
  type        = list(string)
  description = "List of Lambda Layer Version ARNs (maximum of 5) to attach to the Lambda Function."
  default     = []
}

variable "logging_config" {
  type = object({
    application_log_level = optional(string)
    log_format            = optional(string, "Text")
    system_log_level      = optional(string)
    log_group             = optional(string)
  })
  description = "Configuration block used to specify advanced logging settings See [terraform_aws_provider_docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function.html#logging_config) and [monitoring-cloudwatchlogs-advanced](https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-advanced.html) for guidance on values"
  default     = {}
}

variable "memory_size" {
  type        = number
  description = "Amount of memory in MB the Lambda Function can use at runtime."
  default     = 128
}

variable "package_type" {
  type        = string
  description = "The Lambda deployment package type. Valid values are Zip and Image."
  default     = "Zip"
}

variable "role" {
  description = "IAM role arn for lambda function"
  type        = string
  default     = null
}

variable "policy_documents" {
  description = "List of JSON IAM policy documents"
  type        = list(string)
  default     = []
}

variable "prefix" {
  type        = string
  description = "Used for naming your cloud resources, if this is specified your lambda function name will be '{prefix}-{function_scope}-lambda'"
  default     = ""
}

variable "provisioned_concurrent_executions" {
  type        = number
  description = "The amount of pre-initialized execution environments allocated to this function, see [AWS docs](https://docs.aws.amazon.com/lambda/latest/dg/provisioned-concurrency.html) for details"
  default     = 0
}

variable "publish" {
  type        = bool
  description = "Whether to publish creation/change as new Lambda Function Version."
  default     = false
}

variable "reserved_concurrent_executions" {
  type        = number
  description = "The amount of reserved concurrent executions for this lambda function. A value of 0 disables lambda from being triggered and -1 removes any concurrency limitations."
  default     = 5
}

variable "runtime" {
  type        = string
  description = "The runtime environment for the Lambda function you are uploading. For a full list of runtimes, please refer to https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html"
  default     = null
}

variable "s3_bucket" {
  type        = string
  description = <<EOF
  The S3 bucket location containing the function's deployment package. Conflicts with filename and image_uri.
  This bucket must reside in the same AWS region where you are creating the Lambda function.
  EOF
  default     = null
}

variable "s3_key" {
  type        = string
  description = "The S3 key of an object containing the function's deployment package. Conflicts with filename and image_uri."
  default     = null
}

variable "s3_object_version" {
  type        = string
  description = "The object version containing the function's deployment package. Conflicts with filename and image_uri."
  default     = null
}

variable "source_code_hash" {
  type        = string
  description = <<EOF
  Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either
  filename or s3_key. The usual way to set this is `filebase64sha256('file.zip')` where 'file.zip' is the local filename
  of the lambda function source archive.
  EOF
  default     = null
}

variable "ssm_parameter_names" {
  type        = list(string)
  description = <<EOF
  List of AWS Systems Manager Parameter Store parameter names. The IAM role of this Lambda function will be enhanced
  with read permissions for those parameters. Parameters must start with a forward slash and can be encrypted with the
  default KMS key.
  EOF
  default     = null
}

variable "timeout" {
  type        = number
  description = "The amount of time the Lambda Function has to run in seconds."
  default     = 3
}

variable "tracing_config_mode" {
  type        = string
  description = "Tracing config mode of the Lambda function. Can be either PassThrough or Active."
  default     = null
}

variable "vpc_config" {
  type = object({
    security_group_ids = list(string)
    subnet_ids         = list(string)
  })
  description = <<EOF
  Provide this to allow your function to access your VPC (if both 'subnet_ids' and 'security_group_ids' are empty then
  vpc_config is considered to be empty or unset, see https://docs.aws.amazon.com/lambda/latest/dg/vpc.html for details).
  EOF
  default     = null
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags"
  default     = {}
}

variable "disable_org_check" {
  type        = bool
  description = "Set this to true to remove the Deny permission in the trust policy which stops services from outside the Experian Organization from assuming the role"
  default     = false
}

variable "cloudwatch_tags" {
  type        = map(string)
  description = "Cloudwatch Alarm tags. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags"
  default     = {}
}

variable "source_kms_key_arn" {
  type        = string
  description = "ARN of the AWS Key Management Service key used to encrypt the function's .zip deployment package."
  default     = null
}

variable "override_role_name" {
  type        = bool
  description = "Override the default role name for the Lambda IAM role"
  default     = false
}

variable "role_name" {
  type        = string
  description = "Custom role name for the Lambda IAM role if override_role_name is true"
  default     = null
}

variable "permissions_boundary" {
  type        = string
  description = "ARN of the policy that is used to set the permissions boundary for the role"
  default     = null
}