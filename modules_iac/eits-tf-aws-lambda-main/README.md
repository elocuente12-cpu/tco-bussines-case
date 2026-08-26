# EITS Cloud Enablement AWS Lambda module

EITS Terraform module for AWS Lambda Functions. This module will:

- Deploy an AWS Lambda function from a Zip file or from a Docker image.
- Create a Cloudwatch log group and configure logging.
- Create an IAM role for the Lambda function, with optional policies for:
  - CloudWatch Logs
  - Cloudwatch Insights
  - VPC Access
  - X-Ray Tracing
- Optionally override the created IAM role name.
- Create a Lambda Function Alias, if required
- Create a Lambda Function URL, if required

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> **IMPORTANT:**
>
> As of version 1.3.0 a check has been added to the iam module which denies access to assume created roles from services outside of the Experian AWS Organization. If this breaks your use case, disable this functionality by setting the variable `disable_org_check` to `true`.
>
> As of version 1.2.0, when creating a health check the default alarm based on [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#Lambda) will be automatically created. This may incur an extra charge of $0.40 per month. The alarm will only be created if `create_health_check` is true. To disable the creation of these alarms, please set the variable `disable_default_alarms` to true.

## EITS Security & Compliance

**Last Module Review**: 2026-07-01

See below for the date and results of our EITS security and compliance scanning.

<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-07-01 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-07-01 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-07-01 | 0.70.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-07-01 | 1.47.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Resource naming

This module automatically calculates the name for your lambda function, in accordance with the [Cloud Naming Conventions](https://pages.experian.com/display/SC/Cloud+Naming+Conventions+or+Constructs). For example:

```
<account naming construct (see EEC doc)>-<function_scope variable>-lambda
```

> **NOTE:** If your AWS account name is not in the standard format, you may get unpredictable results from the prefix generation. If this is the case you can manually override the account naming construct using the `prefix` variable.

The created CloudWatch log group is named:

```
/aws/lambda/<lambda function name>
```

## NOTES

- For more information about the Terraform Lambda resources, please visit the [Hashicorp Terraform Registry](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
- By default, the CloudWatch Logs log group is created with retention set to `Never expire`. We recommend setting `cloudwatch_logs_retention_in_days` to a value that is acceptable for your use case, to avoid unnecessary logs storage costs.
- IAM role naming: by default the role name follows the module naming convention. If you need to override the role name (only when this module creates the role), set `override_role_name = true` and provide `role_name`.

## Usage

### With .zip file

```hcl
module "lambda" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git"

  function_scope = <used for naming> 
  filename       = <function code in .zip format>
  handler        = <handler>
  runtime        = <runtime>

  # vpc config
  vpc_config = {
    security_group_ids = [<list of ids>]
    subnet_ids         = [<list of ids>]
  }

  # optional environment variables
  # kms key recommended when using vars
  environment_variables = {
    <key> = "<value>"
  }
  kms_key_arn = <kms arn>

  # optional role name override (only when this module creates the role)
  override_role_name = true
  role_name          = <custom role name>

  # optional alias creation
  alias_name = <alias name>

  # optional function url creation
  function_url = {
    cors = {
      allow_credentials = <true/false>
      allow_headers     = [<list>]
      allow_methods     = [<list>]
      allow_origins     = [<list>]
      expose_headers    = [<list>]
      max_age           = <number>
    }
  }

  # mandatory tags
  tags = {
    AppID       = <app_id>
    CostString  = <cost_string>
    Environment = <environment>
  }
}
```

### With image in ECR

```hcl
module "lambda" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git"
  
  function_scope = <function-scope> 
  image_uri      = <image_uri>

  # mandatory tags
  tags = {
    AppID       = <app_id>
    CostString  = <cost_string>
    Environment = <environment>
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.48.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.48.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.0 |
| <a name="module_cloudwatch_log_group"></a> [cloudwatch\_log\_group](#module\_cloudwatch\_log\_group) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs | 2.6.1 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |
| <a name="module_lambda_iam_role"></a> [lambda\_iam\_role](#module\_lambda\_iam\_role) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam | 1.9.7 |

## Resources

| Name | Type |
|------|------|
| [aws_iam_policy.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role_policy_attachment.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_lambda_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_alias) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function_recursion_config.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_recursion_config) | resource |
| [aws_lambda_function_url.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url) | resource |
| [aws_lambda_provisioned_concurrency_config.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_provisioned_concurrency_config) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_default_tags.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_iam_policy_document.assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_metric_thresholds"></a> [alarm\_metric\_thresholds](#input\_alarm\_metric\_thresholds) | A map of custom alarm thresholds. See [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#Route53) for a list of metrics, the name of the metric is the key to use when setting a threshold | <pre>object({<br>    Errors               = optional(number),<br>    Throttles            = optional(number),<br>    Duration             = optional(number),<br>    ConcurrentExecutions = optional(number, 900),<br>    memory_utilization   = optional(number, 90)<br>  })</pre> | `{}` | no |
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions | `list(string)` | `[]` | no |
| <a name="input_alias_name"></a> [alias\_name](#input\_alias\_name) | Creates an alias that points to the LATEST Lambda function version. If not set, no alias will be created. If aliases for specific versions are needed, use the `aws_lambda_alias` resource instead. | `string` | `null` | no |
| <a name="input_architectures"></a> [architectures](#input\_architectures) | Instruction set architecture for your Lambda function. Valid values are ["x86\_64"] and ["arm64"].<br>    Default is ["x86\_64"]. Removing this attribute, function's architecture stay the same. | `list(string)` | <pre>[<br>  "x86_64"<br>]</pre> | no |
| <a name="input_cloudwatch_lambda_insights_enabled"></a> [cloudwatch\_lambda\_insights\_enabled](#input\_cloudwatch\_lambda\_insights\_enabled) | Enable CloudWatch Lambda Insights for the Lambda Function. | `bool` | `false` | no |
| <a name="input_cloudwatch_logs_kms_key_arn"></a> [cloudwatch\_logs\_kms\_key\_arn](#input\_cloudwatch\_logs\_kms\_key\_arn) | The ARN of the KMS Key to use when encrypting log data. | `string` | `null` | no |
| <a name="input_cloudwatch_logs_retention_in_days"></a> [cloudwatch\_logs\_retention\_in\_days](#input\_cloudwatch\_logs\_retention\_in\_days) | Specifies the number of days you want to retain log events in the specified log group. Possible values are:<br>  0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653. If 0 or omitted, the events in the<br>  log group are always retained and never expire. | `number` | `0` | no |
| <a name="input_cloudwatch_tags"></a> [cloudwatch\_tags](#input\_cloudwatch\_tags) | Cloudwatch Alarm tags. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags | `map(string)` | `{}` | no |
| <a name="input_custom_iam_policy_arns"></a> [custom\_iam\_policy\_arns](#input\_custom\_iam\_policy\_arns) | ARNs of custom policies to be attached to the lambda role | `list(string)` | `[]` | no |
| <a name="input_dead_letter_config_target_arn"></a> [dead\_letter\_config\_target\_arn](#input\_dead\_letter\_config\_target\_arn) | ARN of an SNS topic or SQS queue to notify when an invocation fails. If this option is used, the function's IAM role<br>  must be granted suitable access to write to the target object, which means allowing either the sns:Publish or<br>  sqs:SendMessage action on this ARN, depending on which service is targeted." | `string` | `null` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of what the Lambda Function does. | `string` | `null` | no |
| <a name="input_disable_default_alarms"></a> [disable\_default\_alarms](#input\_disable\_default\_alarms) | To disable the best practice AWS alarms outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#Route53) | `bool` | `false` | no |
| <a name="input_disable_org_check"></a> [disable\_org\_check](#input\_disable\_org\_check) | Set this to true to remove the Deny permission in the trust policy which stops services from outside the Experian Organization from assuming the role | `bool` | `false` | no |
| <a name="input_enable_all_alarm_actions"></a> [enable\_all\_alarm\_actions](#input\_enable\_all\_alarm\_actions) | Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions | `bool` | `false` | no |
| <a name="input_environment_variables"></a> [environment\_variables](#input\_environment\_variables) | Map of environment variables that are accessible from the function code during execution. `NO_PROXY` is automatically configured if not provided and `vpc_config` is set. | `map(string)` | `{}` | no |
| <a name="input_ephemeral_storage_size"></a> [ephemeral\_storage\_size](#input\_ephemeral\_storage\_size) | The size of the Lambda function Ephemeral storage (/tmp) represented in MB.<br>  The minimum supported ephemeral\_storage value defaults to 512MB and the maximum supported value is 10240MB. | `number` | `null` | no |
| <a name="input_filename"></a> [filename](#input\_filename) | The path to the function's deployment package within the local filesystem. If defined, The s3\_-prefixed options and image\_uri cannot be used. | `string` | `null` | no |
| <a name="input_function_scope"></a> [function\_scope](#input\_function\_scope) | A mandatory input used for differentiating between different lambdas related to the same application, this will be interpolated into the function name. | `string` | n/a | yes |
| <a name="input_function_url"></a> [function\_url](#input\_function\_url) | Create a dedicated HTTP(S) endpoint for the latest version of the Lambda function. See [lambda\_function\_url docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url) for required values. Please note that only `AWS_IAM` authorization is supported (you do not need to supply it). | <pre>object({<br>    invoke_mode = optional(string, "BUFFERED")<br>    cors = optional(object({<br>      allow_credentials = optional(bool)<br>      allow_headers     = optional(list(string))<br>      allow_methods     = optional(list(string))<br>      allow_origins     = optional(list(string))<br>      expose_headers    = optional(list(string))<br>      max_age           = optional(number)<br>    }), {})<br>  })</pre> | `null` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | The function entrypoint in your code. It should be <function\_filename>.<function\_handler> (e.g., myfunction.lambda\_handler) | `string` | `null` | no |
| <a name="input_image_config"></a> [image\_config](#input\_image\_config) | The Lambda OCI [image configurations](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function#image_config)<br>  block with three (optional) arguments:<br>  - *entry\_point* - The ENTRYPOINT for the docker image (type `list(string)`).<br>  - *command* - The CMD for the docker image (type `list(string)`).<br>  - *working\_directory* - The working directory for the docker image (type `string`). | `any` | `{}` | no |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | The ECR image URI containing the function's deployment package. Conflicts with filename, s3\_bucket, s3\_key, and s3\_object\_version. | `string` | `null` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | Amazon Resource Name (ARN) of the AWS Key Management Service (KMS) key that is used to encrypt environment variables.<br>  If this configuration is not provided when environment variables are in use, AWS Lambda uses a default service key.<br>  If this configuration is provided when environment variables are not in use, the AWS Lambda API does not save this<br>  configuration and Terraform will show a perpetual difference of adding the key. To fix the perpetual difference,<br>  remove this configuration. | `string` | `null` | no |
| <a name="input_lambda_at_edge_enabled"></a> [lambda\_at\_edge\_enabled](#input\_lambda\_at\_edge\_enabled) | Enable Lambda@Edge for your Node.js or Python functions. The required trust relationship and publishing of function versions will be configured in this module. | `bool` | `false` | no |
| <a name="input_lambda_environment"></a> [lambda\_environment](#input\_lambda\_environment) | DEPRECATED: Please use `environment_variables` instead. This variable will be removed in a future release. | <pre>object({<br>    variables = map(string)<br>  })</pre> | `null` | no |
| <a name="input_lambda_function_recursion_config_enabled"></a> [lambda\_function\_recursion\_config\_enabled](#input\_lambda\_function\_recursion\_config\_enabled) | Enable recursion config for Lambda Function `note:` Destruction of this resource will return the `recursive_loop` configuration back to the default value of `Terminate` | `bool` | `false` | no |
| <a name="input_layers"></a> [layers](#input\_layers) | List of Lambda Layer Version ARNs (maximum of 5) to attach to the Lambda Function. | `list(string)` | `[]` | no |
| <a name="input_logging_config"></a> [logging\_config](#input\_logging\_config) | Configuration block used to specify advanced logging settings See [terraform\_aws\_provider\_docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function.html#logging_config) and [monitoring-cloudwatchlogs-advanced](https://docs.aws.amazon.com/lambda/latest/dg/monitoring-cloudwatchlogs-advanced.html) for guidance on values | <pre>object({<br>    application_log_level = optional(string)<br>    log_format            = optional(string, "Text")<br>    system_log_level      = optional(string)<br>    log_group             = optional(string)<br>  })</pre> | `{}` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Amount of memory in MB the Lambda Function can use at runtime. | `number` | `128` | no |
| <a name="input_override_role_name"></a> [override\_role\_name](#input\_override\_role\_name) | Override the default role name for the Lambda IAM role | `bool` | `false` | no |
| <a name="input_package_type"></a> [package\_type](#input\_package\_type) | The Lambda deployment package type. Valid values are Zip and Image. | `string` | `"Zip"` | no |
| <a name="input_permissions_boundary"></a> [permissions\_boundary](#input\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for the role | `string` | `null` | no |
| <a name="input_policy_documents"></a> [policy\_documents](#input\_policy\_documents) | List of JSON IAM policy documents | `list(string)` | `[]` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Used for naming your cloud resources, if this is specified your lambda function name will be '{prefix}-{function\_scope}-lambda' | `string` | `""` | no |
| <a name="input_provisioned_concurrent_executions"></a> [provisioned\_concurrent\_executions](#input\_provisioned\_concurrent\_executions) | The amount of pre-initialized execution environments allocated to this function, see [AWS docs](https://docs.aws.amazon.com/lambda/latest/dg/provisioned-concurrency.html) for details | `number` | `0` | no |
| <a name="input_publish"></a> [publish](#input\_publish) | Whether to publish creation/change as new Lambda Function Version. | `bool` | `false` | no |
| <a name="input_reserved_concurrent_executions"></a> [reserved\_concurrent\_executions](#input\_reserved\_concurrent\_executions) | The amount of reserved concurrent executions for this lambda function. A value of 0 disables lambda from being triggered and -1 removes any concurrency limitations. | `number` | `5` | no |
| <a name="input_role"></a> [role](#input\_role) | IAM role arn for lambda function | `string` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Custom role name for the Lambda IAM role if override\_role\_name is true | `string` | `null` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | The runtime environment for the Lambda function you are uploading. For a full list of runtimes, please refer to https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html | `string` | `null` | no |
| <a name="input_s3_bucket"></a> [s3\_bucket](#input\_s3\_bucket) | The S3 bucket location containing the function's deployment package. Conflicts with filename and image\_uri.<br>  This bucket must reside in the same AWS region where you are creating the Lambda function. | `string` | `null` | no |
| <a name="input_s3_key"></a> [s3\_key](#input\_s3\_key) | The S3 key of an object containing the function's deployment package. Conflicts with filename and image\_uri. | `string` | `null` | no |
| <a name="input_s3_object_version"></a> [s3\_object\_version](#input\_s3\_object\_version) | The object version containing the function's deployment package. Conflicts with filename and image\_uri. | `string` | `null` | no |
| <a name="input_source_code_hash"></a> [source\_code\_hash](#input\_source\_code\_hash) | Used to trigger updates. Must be set to a base64-encoded SHA256 hash of the package file specified with either<br>  filename or s3\_key. The usual way to set this is `filebase64sha256('file.zip')` where 'file.zip' is the local filename<br>  of the lambda function source archive. | `string` | `null` | no |
| <a name="input_source_kms_key_arn"></a> [source\_kms\_key\_arn](#input\_source\_kms\_key\_arn) | ARN of the AWS Key Management Service key used to encrypt the function's .zip deployment package. | `string` | `null` | no |
| <a name="input_ssm_iam_policy_description"></a> [ssm\_iam\_policy\_description](#input\_ssm\_iam\_policy\_description) | Description of the IAM policy for the Lambda IAM role | `string` | `"Provides minimum SSM read permissions."` | no |
| <a name="input_ssm_parameter_names"></a> [ssm\_parameter\_names](#input\_ssm\_parameter\_names) | List of AWS Systems Manager Parameter Store parameter names. The IAM role of this Lambda function will be enhanced<br>  with read permissions for those parameters. Parameters must start with a forward slash and can be encrypted with the<br>  default KMS key. | `list(string)` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | The amount of time the Lambda Function has to run in seconds. | `number` | `3` | no |
| <a name="input_tracing_config_mode"></a> [tracing\_config\_mode](#input\_tracing\_config\_mode) | Tracing config mode of the Lambda function. Can be either PassThrough or Active. | `string` | `null` | no |
| <a name="input_vpc_config"></a> [vpc\_config](#input\_vpc\_config) | Provide this to allow your function to access your VPC (if both 'subnet\_ids' and 'security\_group\_ids' are empty then<br>  vpc\_config is considered to be empty or unset, see https://docs.aws.amazon.com/lambda/latest/dg/vpc.html for details). | <pre>object({<br>    security_group_ids = list(string)<br>    subnet_ids         = list(string)<br>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the lambda function |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Lambda CloudWatch log group name |
| <a name="output_code_sha256"></a> [code\_sha256](#output\_code\_sha256) | SHA256 hash of the function's deployment package |
| <a name="output_function_name"></a> [function\_name](#output\_function\_name) | Lambda function name |
| <a name="output_function_url"></a> [function\_url](#output\_function\_url) | The HTTP URL endpoint for the function in the format https://<url\_id>.lambda-url.<region>.on.aws/ |
| <a name="output_invoke_arn"></a> [invoke\_arn](#output\_invoke\_arn) | Invoke ARN of the lambda function |
| <a name="output_qualified_arn"></a> [qualified\_arn](#output\_qualified\_arn) | ARN identifying your Lambda Function Version (if versioning is enabled via publish = true) |
| <a name="output_qualified_invoke_arn"></a> [qualified\_invoke\_arn](#output\_qualified\_invoke\_arn) | Qualified ARN (ARN with lambda version number) to be used for invoking Lambda Function from API Gateway |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | Lambda IAM role ARN |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | Lambda IAM role name |
| <a name="output_version"></a> [version](#output\_version) | Latest published version of your Lambda Function. |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS Lambda Function
region: Global
bu: EITS
contacts:
  technical: EITS UK&I Cloud Enablement Team eitsukicloud@experian.com
  product: 
```
