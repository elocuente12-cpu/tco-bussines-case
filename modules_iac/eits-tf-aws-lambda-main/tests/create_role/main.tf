# test region
provider "aws" {
  region = var.region
}

# create security group to use for testing lambda
module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git" # we recommend to pin this to a specific version

  security_group_name        = "eits-tf-aws-lambda"
  security_group_description = "For eits-tf-aws-lambda testing"
  vpc_id                     = var.vpc_id
  security_group_ingress_rules = [
    {
      description = "Ping"
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]
  security_group_egress_rules = [
    {
      type        = "egress"
      from_port   = "0"
      to_port     = "0"
      protocol    = "-1"
      cidr_blocks = ["10.0.0.0/8"]
      description = "Allow outbound traffic to Experian network"
    }
  ]

  tags = var.tags

}

# kms key policy
data "aws_iam_policy_document" "kms_policy" {
  statement {
    resources = ["*"]
    effect    = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# kms key to encrypt env variables
module "kms_key" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git" # we recommend to pin this to a specific version

  prefix      = "eits-tf-aws-lambda"
  description = "KMS key to encrypt lambda vars, log group and s3 bucket for testing"
  policy      = data.aws_iam_policy_document.kms_policy.json
  key_users   = [data.aws_iam_session_context.current.arn]

  tags = var.tags
}

# create iam policy to allow lambda to decrypt kms key
data "aws_iam_policy_document" "lambda_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [module.kms_key.key_arn]
  }
}

data "aws_iam_policy_document" "permissions_boundary" {
  statement {
    effect = "Allow"
    actions = [
      "*"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "permissions_boundary" {
  name_prefix = "eits-tf-aws-lambda-pb-"
  description = "Permissions boundary policy for eits-tf-aws-lambda create_role test"
  policy      = data.aws_iam_policy_document.permissions_boundary.json
}

# test module
module "lambda" {
  source = "./../.."

  function_scope       = "eits-tf-aws-lambda"
  filename             = "test.zip"
  handler              = "test.lambda_handler"
  runtime              = "python3.11"
  kms_key_arn          = module.kms_key.key_arn
  source_kms_key_arn   = module.kms_key.key_arn
  permissions_boundary = aws_iam_policy.permissions_boundary.arn
  policy_documents     = [data.aws_iam_policy_document.lambda_policy.json]
  logging_config = {
    log_group             = "/aws/lambda/lambda-test"
    log_format            = "JSON"
    application_log_level = "INFO"
    system_log_level      = "INFO"
  }
  lambda_function_recursion_config_enabled = true
  vpc_config = {
    security_group_ids = [module.security_group.id]
    subnet_ids         = var.subnet_ids
  }

  # test automatic NO_PROXY addition
  environment_variables = {
    TEST_ENV_VAR = "test_value"
    HTTP_PROXY   = "http://ukpcorp-proxy.uk.experian.local:9595"
    HTTPS_PROXY  = "http://ukpcorp-proxy.uk.experian.local:9595"
  }

  tags = var.tags
}

data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}