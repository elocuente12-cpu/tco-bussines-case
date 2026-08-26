module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-lambda"
  tags        = var.tags
}

module "cloudwatch_log_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs?ref=2.6.1"

  create_iam_role   = false
  kms_key_arn       = var.cloudwatch_logs_kms_key_arn
  retention_in_days = var.cloudwatch_logs_retention_in_days
  log_group_name    = "/aws/lambda/${local.function_name}"
  tags              = merge(local.tags, { "eitsce:parentmodule" = "eits-tf-aws-lambda" })
}

resource "aws_lambda_function" "this" {
  architectures                  = var.architectures
  description                    = var.description
  filename                       = var.filename
  function_name                  = local.function_name
  handler                        = var.handler
  image_uri                      = var.image_uri
  kms_key_arn                    = var.kms_key_arn
  layers                         = var.layers
  memory_size                    = var.memory_size
  package_type                   = var.package_type
  publish                        = var.publish
  reserved_concurrent_executions = var.reserved_concurrent_executions
  role                           = var.role == null ? module.lambda_iam_role[0].role_arn : var.role
  runtime                        = var.runtime
  s3_bucket                      = var.s3_bucket
  s3_key                         = var.s3_key
  s3_object_version              = var.s3_object_version
  source_code_hash               = var.source_code_hash
  tags                           = local.tags
  timeout                        = var.timeout
  source_kms_key_arn             = var.source_kms_key_arn

  dynamic "dead_letter_config" {
    for_each = try(length(var.dead_letter_config_target_arn), 0) > 0 ? [true] : []

    content {
      target_arn = var.dead_letter_config_target_arn
    }
  }

  dynamic "environment" {
    for_each = length(local.function_env_variables) > 0 ? [true] : []

    content {
      variables = local.function_env_variables
    }
  }

  dynamic "image_config" {
    for_each = length(var.image_config) > 0 ? [true] : []

    content {
      command           = lookup(var.image_config, "command", null)
      entry_point       = lookup(var.image_config, "entry_point", null)
      working_directory = lookup(var.image_config, "working_directory", null)
    }
  }

  logging_config {
    log_format            = var.logging_config.log_format
    log_group             = var.logging_config.log_group == null ? module.cloudwatch_log_group.log_group_name : var.logging_config.log_group
    system_log_level      = var.logging_config.system_log_level
    application_log_level = var.logging_config.application_log_level
  }

  dynamic "tracing_config" {
    for_each = var.tracing_config_mode != null ? [true] : []

    content {
      mode = var.tracing_config_mode
    }
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []

    content {
      security_group_ids = vpc_config.value.security_group_ids
      subnet_ids         = vpc_config.value.subnet_ids
    }
  }

  dynamic "ephemeral_storage" {
    for_each = var.ephemeral_storage_size != null ? [var.ephemeral_storage_size] : []

    content {
      size = var.ephemeral_storage_size
    }
  }

  depends_on = [module.cloudwatch_log_group]
}

resource "aws_lambda_function_recursion_config" "this" {
  count = var.lambda_function_recursion_config_enabled ? 1 : 0

  function_name  = aws_lambda_function.this.function_name
  recursive_loop = "Allow"
}

resource "aws_lambda_provisioned_concurrency_config" "this" {
  count = var.provisioned_concurrent_executions > 0 ? 1 : 0

  function_name                     = aws_lambda_function.this.function_name
  provisioned_concurrent_executions = var.provisioned_concurrent_executions
  qualifier                         = aws_lambda_function.this.version
}

resource "aws_lambda_alias" "this" {
  count = var.alias_name != null ? 1 : 0

  name             = var.alias_name
  description      = var.description
  function_name    = aws_lambda_function.this.function_name
  function_version = aws_lambda_function.this.version
}

resource "aws_lambda_function_url" "this" {
  count = var.function_url != null ? 1 : 0

  function_name      = aws_lambda_function.this.function_name
  authorization_type = "AWS_IAM"
  invoke_mode        = var.function_url.invoke_mode

  dynamic "cors" {
    for_each = length(var.function_url.cors) == 0 ? [] : [var.function_url.cors]

    content {
      allow_credentials = cors.value.allow_credentials
      allow_headers     = cors.value.allow_headers
      allow_methods     = cors.value.allow_methods
      allow_origins     = cors.value.allow_origins
      expose_headers    = cors.value.expose_headers
      max_age           = cors.value.max_age
    }
  }
}
