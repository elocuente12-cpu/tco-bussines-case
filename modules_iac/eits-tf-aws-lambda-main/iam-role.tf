module "lambda_iam_role" {
  count = var.role == null ? 1 : 0

  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam?ref=1.9.7"

  override_role_name   = var.override_role_name
  role_name            = var.override_role_name && var.role_name != null ? var.role_name : local.function_name
  role_description     = "IAM role for lambda execution"
  policy_name          = local.function_name
  policy_description   = "IAM policy for lambda execution"
  policy_documents     = var.policy_documents
  permissions_boundary = var.permissions_boundary
  assume_role_policy   = data.aws_iam_policy_document.assume_role_policy.json
  managed_policy_arns  = concat(var.custom_iam_policy_arns, local.enabled_iam_policies)
  disable_org_check    = var.disable_org_check

  tags = local.tags
}

resource "aws_iam_policy" "ssm" {
  count = try((var.ssm_parameter_names != null && length(var.ssm_parameter_names) > 0), false) ? 1 : 0

  name        = "${local.function_name}-ssm-policy-${local.region_name}"
  description = var.ssm_iam_policy_description
  policy      = data.aws_iam_policy_document.ssm[count.index].json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  count = try((var.ssm_parameter_names != null && length(var.ssm_parameter_names) > 0), false) ? 1 : 0

  policy_arn = aws_iam_policy.ssm[count.index].arn
  role       = var.role == null ? module.lambda_iam_role[0].role_name : reverse(split("/", var.role))[0]
}
