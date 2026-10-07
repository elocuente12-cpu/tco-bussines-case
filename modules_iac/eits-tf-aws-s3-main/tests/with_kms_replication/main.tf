# test region
provider "aws" {
  region = var.region
}

# replica bucket region
provider "aws" {
  alias  = "replica"
  region = "eu-central-1"
}

# get account id and role
data "aws_caller_identity" "current" {}
data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}

# locals
locals {
  account_id              = data.aws_caller_identity.current.account_id
  destination_bucket_name = "${local.account_id}-eits-tf-aws-s3-kms-replica"
  source_bucket_name      = "${local.account_id}-eits-tf-aws-s3-kms-source"
  replication_iam_role    = "arn:aws:iam::${local.account_id}:role/BURoleForReplication-${local.source_bucket_name}"
}

# replication IAM role policy to add to kms key, allows replication role to access keys
# we need to construct a condition like this because we want to create the KMS key BEFORE iam role is created otherwise the key creation will error
data "aws_iam_policy_document" "replication_role_access" {
  statement {
    sid    = "AllowReplicationIAMRole"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:DescribeKey",
    ]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = [local.replication_iam_role]
    }
  }
}

# create kms keys to encrypt source bucket
# grant access to current user in order to upload objects
module "kms_key_source" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  prefix       = "eits-tf-aws-s3-kms-source"
  description  = "KMS key to encrypt S3 buckets and objects for replication testing"
  policy       = data.aws_iam_policy_document.replication_role_access.json
  key_services = ["s3"]
  key_users    = [data.aws_iam_session_context.current.issuer_arn]

  tags = var.tags
}

# create seperate key in replica region as aws doesnt allow multi-region keys for this...
module "kms_key_replica" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"
  providers = {
    aws = aws.replica
  }

  prefix       = "eits-tf-aws-s3-kms-replica"
  description  = "KMS key to encrypt S3 buckets and objects for replication testing"
  policy       = data.aws_iam_policy_document.replication_role_access.json
  key_services = ["s3"]
  key_users    = [data.aws_iam_session_context.current.issuer_arn]

  tags = var.tags
}

# create replica destination bucket in different region
module "replica_bucket" {
  source = "./../.."
  providers = {
    aws = aws.replica
  }

  bucket_name   = local.destination_bucket_name
  force_destroy = true
  sse_algorithm = "aws:kms"
  kms_key_arn   = module.kms_key_replica.key_arn

  disable_default_alarms    = true
  disable_source_vpce_check = true

  tags = var.tags
}

# create source bucket with replication config
module "source_bucket" {
  source = "./../.."

  bucket_name                = local.source_bucket_name
  access_logging_bucket_name = var.access_logging_bucket
  force_destroy              = true
  sse_algorithm              = "aws:kms"
  kms_key_arn                = module.kms_key_source.key_arn

  disable_default_alarms  = true
  disable_source_ip_check = true

  replication_config = {
    enabled                = true
    destination_bucket_arn = module.replica_bucket.s3_bucket_arn
    destination_region     = "eu-central-1"
    replica_owner          = "Destination"
    replica_account        = local.account_id
    enable_kms_encryption  = true
    replica_kms_key_id     = module.kms_key_replica.key_arn
    rules                  = [{ id = "EntireBucket" }]
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
