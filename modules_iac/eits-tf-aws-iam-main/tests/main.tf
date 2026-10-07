# test region
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# example policy document to list bucket on a specific resource
data "aws_iam_policy_document" "s3_read_example" {
  statement {
    sid = "ListBucketTest"

    actions = [
      "s3:ListBucket"
    ]

    resources = ["arn:aws:s3:::${data.aws_caller_identity.current.account_id}-eits-tf-aws-s3"]
    effect    = "Allow"
  }
}

# test policy that will fail wiz checks
# data "aws_iam_policy_document" "failure_example" {
#   statement {
#     sid = "InsecurePolicyTest"

#     actions = [
#       "s3:*",
#       "ec2:RunInstances",
#       "iam:PassRole"
#     ]

#     resources = ["*"]
#     effect    = "Allow"
#   }
# }

# example trust policy for using it with EC2
data "aws_iam_policy_document" "assume_role_example" {
  statement {
    sid = "AssumeRoleEC2Test"

    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# test module - create an iam role for ec2
module "iam_role" {
  source = "./.."

  role_name          = "eits-tf-aws-iam-ec2"
  role_description   = "Automated terraform module testing resource for eits-tf-aws-iam"
  policy_name        = "eits-tf-aws-iam-ec2"
  policy_description = "Automated terraform module testing resource for eits-tf-aws-iam"
  assume_role_policy = data.aws_iam_policy_document.assume_role_example.json
  policy_documents   = [data.aws_iam_policy_document.s3_read_example.json]
  # policy_documents    = [data.aws_iam_policy_document.s3_read_example.json, data.aws_iam_policy_document.failure_example.json]
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"]

  # uncomment to test
  # disable_org_check = true

  tags = var.tags
}