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

  tags = var.tags
}

# trust policy to allow lambda to execute role
data "aws_iam_policy_document" "trust_policy" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
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

# create iam role for lambda execution
module "iam_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam" # we recommend to pin this to a specific version

  role_name          = "eits-tf-aws-lambda"
  role_description   = "IAM role for lambda execution"
  policy_name        = "eits-tf-aws-lambda"
  policy_description = "IAM policy for lambda execution"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole",
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole",
    "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
  ]
  policy_documents = [data.aws_iam_policy_document.lambda_policy.json]

  tags = var.tags
}

# test module
module "lambda" {
  source = "./../.."

  function_scope = "eits-tf-aws-lambda"

  filename = "test.zip"
  handler  = "test.lambda_handler"
  runtime  = "python3.11"
  role     = module.iam_role.role_arn
  vpc_config = {
    security_group_ids = [module.security_group.id]
    subnet_ids         = var.subnet_ids
  }
  lambda_function_recursion_config_enabled = false

  # test automatic NO_PROXY addition
  environment_variables = {
    NO_PROXY = "test.no.proxy,localhost"
  }
  kms_key_arn = module.kms_key.key_arn

  # DEPRECATED variable - PLEASE use environment_variables instead
  # lambda_environment = {
  #   variables = {
  #     TEST_ENV_VAR = "test_value"
  #   } 
  # }

  # test alias creation for latest version
  alias_name = "cloud_enablement_test_latest"

  # test function url creation
  function_url = {
    cors = {
      allow_credentials = true
      allow_headers     = ["*"]
      allow_methods     = ["GET", "POST"]
      allow_origins     = ["*"]
      expose_headers    = ["X-Amzn-Trace-Id"]
      max_age           = 3600
    }
  }

  tags = var.tags

  depends_on = [module.iam_role]
}

output "function_url" {
  description = "The HTTP URL endpoint for the function"
  value       = module.lambda.function_url
}
