locals {
  prefix        = length(var.prefix) > 0 ? var.prefix : module.eits_ce_common.prefix
  account_id    = data.aws_caller_identity.this.account_id
  partition     = data.aws_partition.this.partition
  region_name   = data.aws_region.this.region
  function_name = "${local.prefix}-${var.function_scope}-lambda"
  tags          = merge(var.tags, module.eits_ce_common.tags, data.aws_default_tags.this.tags)

  iam_policies = {
    cloudwatch_logs     = "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    cloudwatch_insights = var.cloudwatch_lambda_insights_enabled ? "arn:${local.partition}:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy" : null,
    vpc_access          = var.vpc_config != null ? "arn:${local.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole" : null,
    xray                = var.tracing_config_mode != null ? "arn:${local.partition}:iam::aws:policy/AWSXRayDaemonWriteAccess" : null
  }

  enabled_iam_policies = [for policy in values(local.iam_policies) : policy if policy != null]

  # default NO_PROXY configuration
  no_proxy_value = "localhost,.${local.region_name}.vpce.amazonaws.com,.${local.region_name}.amazonaws.com,.internal,.local,.coaas.net,.experian.com,.experian.corp,.eeca,.eecm,.eeco,.eecg,10.0.0.0/8,127.0.0.1,169.254.169.254,172.16.0.0/12,192.168.0.0/16,194.60.160.0/19"
  no_proxy = {
    NO_PROXY = try(var.environment_variables["NO_PROXY"], try(var.environment_variables["no_proxy"], local.no_proxy_value))
    no_proxy = try(var.environment_variables["no_proxy"], try(var.environment_variables["NO_PROXY"], local.no_proxy_value))
  }

  # merge environment variables from different sources
  is_proxy_set = can(var.environment_variables["http_proxy"]) || can(var.environment_variables["HTTP_PROXY"]) || can(var.environment_variables["https_proxy"]) || can(var.environment_variables["HTTPS_PROXY"])
  function_env_variables = merge(var.environment_variables,
    var.lambda_environment != null ? var.lambda_environment.variables : {},
    var.vpc_config != null && local.is_proxy_set ? local.no_proxy : {}
  )
}
