# test region
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# locals
locals {
  account_id = data.aws_caller_identity.current.account_id
}

# example policy document
# will be merged with those from module
data "aws_iam_policy_document" "this" {
  statement {
    sid       = "ExampleS3ServicePolicy"
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
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

# test module - create a key that merges policy json and key_users
module "kms" {
  source = "./../.."

  prefix      = "eits-tf-aws-kms-with-policy"
  description = "Example KMS key that merges policy and key_users"
  policy      = data.aws_iam_policy_document.this.json

  key_users = [
    "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${local.account_id}:role/eec-aws-infrastructure-deployment-role",
  ]

  tags = var.tags
}
