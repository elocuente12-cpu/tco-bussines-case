# test region
provider "aws" {
  region = var.region
}

# get account id
data "aws_caller_identity" "current" {}

locals {
  account_id  = data.aws_caller_identity.current.account_id
  bucket_name = "${local.account_id}-eits-tf-aws-s3-test"
}

# create policy document to allow iam from sandbox to test cross-account access
data "aws_iam_policy_document" "sandbox_admin" {
  statement {
    sid    = "AllowSandboxAccessRole"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::077820194866:role/BUAdministratorAccessRole"
      ]
    }

    actions = ["s3:*"]

    resources = [
      "arn:aws:s3:::${local.bucket_name}",
      "arn:aws:s3:::${local.bucket_name}/*"
    ]
  }
}

# create policy document
data "aws_iam_policy_document" "this" {
  statement {
    sid    = "RequireEncryptedStorage"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:PutObject"]

    resources = ["arn:aws:s3:::${local.bucket_name}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["AES256"]
    }
  }
}

# create policy documents for s3 access points
data "aws_iam_policy_document" "access_point_1" {
  statement {
    sid    = "AllowAccessToAccessPoint1"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
      ]
    }

    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:${var.region}:${local.account_id}:accesspoint/${local.account_id}-eits-tf-aws-s3-ap-1/object/*"
    ]
  }
}

data "aws_iam_policy_document" "access_point_2" {
  statement {
    sid    = "AllowAccessToAccessPoint2"
    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
      ]
    }

    actions = [
      "s3:PutObject",
      "s3:GetObject"
    ]

    resources = [
      "arn:aws:s3:${var.region}:${local.account_id}:accesspoint/${local.account_id}-eits-tf-aws-s3-ap-2/object/*"
    ]
  }
}

# test module
module "s3_bucket" {
  source = "./../.."

  bucket_name                = local.bucket_name
  access_logging_bucket_name = var.access_logging_bucket
  source_policy_documents    = [data.aws_iam_policy_document.this.json, data.aws_iam_policy_document.sandbox_admin.json]

  disable_default_alarms    = true
  disable_source_vpce_check = true
  # allowed_source_vpce_ids  = ["vpce-0fdeba1e4ddb7d030"]

  # test lifecycle rules
  lifecycle_rules = [
    {
      id     = "rule1"
      status = "Enabled"
      filter = {
        tags = {
          log = "yes"
        }
      }
      transition = [
        {
          days          = 30
          storage_class = "STANDARD_IA"
        },
        {
          days          = 60
          storage_class = "ONEZONE_IA"
        }
      ]
      expiration = {
        days = 90
      }
      noncurrent_version_expiration = {
        newer_noncurrent_versions = 1
        noncurrent_days           = 30
      }
    }
  ]

  # test access points
  access_points = [
    {
      name              = "${local.account_id}-eits-tf-aws-s3-ap-1"
      policy            = data.aws_iam_policy_document.access_point_1.json
      restricted_vpc_id = var.vpc_id
    },
    {
      name   = "${local.account_id}-eits-tf-aws-s3-ap-2"
      policy = data.aws_iam_policy_document.access_point_2.json
    }
  ]

  tags = var.tags
}

output "s3_access_points" {
  value = module.s3_bucket.s3_access_points
}
