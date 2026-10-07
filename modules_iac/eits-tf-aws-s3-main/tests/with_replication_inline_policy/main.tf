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
  destination_bucket_name = "${local.account_id}-eits-tf-aws-s3-inline-replica"
  source_bucket_name      = "${local.account_id}-eits-tf-aws-s3-inline-source"
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
# This test exercises the new replication IAM role variables:
# - prefix: custom bucket name prefix
# - replication_role_name: custom role name instead of auto-generated
# - replication_role_attach_policy_inline: use inline policy instead of managed policy
module "source_bucket" {
  source = "./../.."

  bucket_name                = local.source_bucket_name
  prefix                     = "test"
  access_logging_bucket_name = var.access_logging_bucket
  force_destroy              = true

  disable_default_alarms  = true
  disable_source_ip_check = true

  # Test the new replication role variables with non-default values
  replication_role_name                 = "CustomReplicationRole-${local.source_bucket_name}"
  replication_role_attach_policy_inline = true

  replication_config = {
    enabled                = true
    destination_bucket_arn = module.replica_bucket.s3_bucket_arn
    destination_region     = "eu-central-1"
    replica_owner          = "Destination"
    replica_account        = local.account_id

    rules = [{ id = "EntireBucket" }]
  }

  tags = var.tags
}

# upload object to test replication
resource "aws_s3_object" "source_object" {
  bucket       = module.source_bucket.s3_bucket_id
  key          = "replicate_me.txt"
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
  key    = "replicate_me.txt"

  depends_on = [time_sleep.wait_for_replication]
}

output "replica_test_body" {
  description = "Replication test file contents"
  value       = data.aws_s3_object.replica_object.body
}

output "replication_role_name" {
  description = "Name of the IAM role created for replication - should be the custom name"
  value       = module.source_bucket.replication_role_name
}

output "replication_policy_json" {
  description = "Combined replication IAM policy JSON - used for inline policy"
  value       = module.source_bucket.replication_policy_json
  sensitive   = true
}
