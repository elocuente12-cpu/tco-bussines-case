data "aws_partition" "this" {}
data "aws_region" "this" {}
data "aws_caller_identity" "this" {}
data "aws_default_tags" "this" {}

data "aws_iam_policy_document" "assume_role_policy" {

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = concat(["lambda.amazonaws.com"], var.lambda_at_edge_enabled ? ["edgelambda.amazonaws.com"] : [])
    }
  }
}

data "aws_iam_policy_document" "ssm" {
  count = try((var.ssm_parameter_names != null && length(var.ssm_parameter_names) > 0), false) ? 1 : 0

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
    ]

    resources = formatlist("arn:${local.partition}:ssm:${local.region_name}:${local.account_id}:parameter%s", var.ssm_parameter_names)
  }
}
