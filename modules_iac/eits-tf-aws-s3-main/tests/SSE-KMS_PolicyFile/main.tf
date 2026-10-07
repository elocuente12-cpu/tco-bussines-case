# test region
provider "aws" {
  region = var.region
}

# get account id
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${data.aws_caller_identity.current.account_id}-eits-tf-aws-s3-kms"
}

# create key
module "kms_key" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  prefix       = "eits-tf-aws-s3-kms"
  description  = "KMS key for S3 bucket ${local.bucket_name}"
  key_services = ["s3"]

  tags = var.tags
}

# test module
module "s3_bucket" {
  source = "./../.."

  bucket_name                = local.bucket_name
  access_logging_bucket_name = var.access_logging_bucket
  sse_algorithm              = "aws:kms"
  kms_key_arn                = module.kms_key.key_arn
  bucket_policy              = templatefile("policy.tftpl", { bucket_name = local.bucket_name })

  disable_default_alarms    = true
  disable_source_vpce_check = true

  # test intelligent tiering
  intelligent_tiering = {
    devtest = {
      status = "Enabled"
      filter = {
        tags = {
          Environment = "dev"
        }
      }
      tiering = {
        ARCHIVE_ACCESS = {
          days = 90
        },
        DEEP_ARCHIVE_ACCESS = {
          days = 365
        }
      }
    }
  }

  tags = var.tags
}
