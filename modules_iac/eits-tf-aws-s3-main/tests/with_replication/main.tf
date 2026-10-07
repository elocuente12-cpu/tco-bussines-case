# test region
provider "aws" {
  region = var.region
}

# replica bucket region
provider "aws" {
  alias  = "replica"
  region = "eu-central-1"
}

# get account id
data "aws_caller_identity" "current" {}

# locals
locals {
  account_id              = data.aws_caller_identity.current.account_id
  destination_bucket_name = "${local.account_id}-eits-tf-aws-s3-replica"
  source_bucket_name      = "${local.account_id}-eits-tf-aws-s3-source"
}

# create replica destination bucket in different region
module "replica_bucket" {
  source = "./../.."
  providers = {
    aws = aws.replica
  }

  bucket_name   = local.destination_bucket_name
  force_destroy = true

  disable_default_alarms  = true
  disable_source_ip_check = true

  tags = var.tags
}

# create source bucket with replication config
module "source_bucket" {
  source = "./../.."

  bucket_name                = local.source_bucket_name
  access_logging_bucket_name = var.access_logging_bucket
  force_destroy              = true

  disable_default_alarms  = true
  disable_source_ip_check = true

  replication_config = {
    enabled                = true
    destination_bucket_arn = module.replica_bucket.s3_bucket_arn
    destination_region     = "eu-central-1"
    replica_owner          = "Destination"
    replica_account        = local.account_id

    # list of rules, must have at least 1
    # example of multiple rules, with a filter
    rules = [
      {
        id       = "ReplicateOnlySomeThings"
        priority = 0
        filter = {
          prefix = "test/"
        }
      },
      {
        id       = "ReplicateSomeOtherThings"
        priority = 1
        filter = {
          prefix = "test2/"
        }
      }
    ]

  }

  tags = var.tags
}

# upload object to test replication
resource "aws_s3_object" "source_object" {
  bucket       = module.source_bucket.s3_bucket_id
  key          = "test/replicate_me.txt"
  source       = "replicate_me.txt"
  content_type = "text/plain"

  depends_on = [module.source_bucket]
}

# upload another object to test NON replication (due to filter)
resource "aws_s3_object" "source_object_2" {
  bucket       = module.source_bucket.s3_bucket_id
  key          = "do_not_replicate_me.txt"
  source       = "replicate_me.txt"
  content_type = "text/plain"

  depends_on = [module.source_bucket]
}

# check for s3 object in replica bucket and output body
resource "time_sleep" "wait_for_replication" {
  depends_on      = [aws_s3_object.source_object]
  create_duration = "2m"
}

data "aws_s3_object" "replica_object" {
  provider = aws.replica

  bucket = module.replica_bucket.s3_bucket_id
  key    = "test/replicate_me.txt"

  depends_on = [time_sleep.wait_for_replication]
}

output "replica_test_body" {
  description = "Replication test file contents"
  value       = data.aws_s3_object.replica_object.body
}
