# Test region
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

# Locals
locals {
  s3_access_logs_bucket_name    = "eits-tf-aws-backup-access-logs"
  s3_backup_reports_bucket_name = "eits-tf-aws-backup-reports"
  backup_vault_name             = "eits-tf-aws-backup-vault"
  backup_vault_report_name      = "eits_tf_aws_backup_report"
  backup_sns_topic_name         = "eits-tf-aws-backup-topic-sns"
  sns_email_subscription        = "tom.meer@experian.com"
  account_id                    = data.aws_caller_identity.current.account_id

  kms_keys = [
    {
      name         = "s3"
      description  = "KMS key for AWS Backup S3 buckets"
      key_services = ["logging.s3"]
    },
    {
      name         = "vault"
      description  = "KMS key for AWS Backup vault"
      key_services = ["backup"]
    },
    {
      name         = "sns"
      description  = "KMS key for AWS Backup SNS topic"
      key_services = ["sns"]
    }
  ]
}

# KMS key for AWS Backup S3 buckets
module "kms" {
  source   = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"
  for_each = { for k, v in local.kms_keys : v.name => v }

  prefix      = "eits-tf-aws-backup-${each.value.name}"
  description = each.value.description
  key_owners = [
    "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${local.account_id}:root"
  ]
  key_administrators = [
    "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${local.account_id}:role/eec-aws-infrastructure-deployment-role",
    "arn:aws:iam::${local.account_id}:root"
  ]
  key_users = [
    "arn:aws:iam::${local.account_id}:role/BUAdministratorAccessRole",
    "arn:aws:iam::${local.account_id}:role/eec-aws-infrastructure-deployment-role",
  ]
  key_services = each.value.key_services

  tags = var.tags
}

# S3 Access policy for AWS Backup Reports
data "aws_iam_policy_document" "s3_aws_backup_reports_bucket_policy" {
  statement {
    sid    = "AWSBackupReports"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:role/aws-service-role/reports.backup.amazonaws.com/AWSServiceRoleForBackupReports"]
    }

    actions = [
      "s3:PutObject"
    ]

    resources = ["arn:aws:s3:::${local.s3_backup_reports_bucket_name}/*"]

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

# Create S3 bucket where to store reports
module "s3_backup_report_bucket" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-s3.git"

  bucket_name                = local.s3_backup_reports_bucket_name
  versioning_enabled         = false
  access_logging_bucket_name = var.access_logging_bucket
  source_policy_documents    = [data.aws_iam_policy_document.s3_aws_backup_reports_bucket_policy.json]
  sse_algorithm              = "aws:kms"
  kms_key_arn                = module.kms.s3.key_arn

  # Archive and delete old versions
  lifecycle_rules = [
    {
      id                                     = "delete_old_backup_report"
      status                                 = "Enabled"
      abort_incomplete_multipart_upload_days = 7
      filter_and = {
        prefix = "Backup/"
      }
      noncurrent_version_transition = [
        {
          noncurrent_days = 30
          storage_class   = "ONEZONE_IA"
        },
      ]
      expiration = {
        days = 30
      }
      noncurrent_version_expiration = {
        noncurrent_days = 90
      }
    }
  ]

  disable_default_alarms = true
  # due to devtest vpce structure
  disable_source_vpce_check = true

  tags = var.tags
}

# Create AWS Backup infrastructure (Vault + Reports + SNS)
module "aws_backup_vault" {
  source = "../.."

  create_backup_vault = true
  vault_name          = local.backup_vault_name
  vault_kms_key_arn   = module.kms.vault.key_arn
  vault_force_destroy = true # for testing purposes

  # Vault lock configuration
  vault_lock_config = {
    enabled            = true
    max_retention_days = 7
    min_retention_days = 1
  }

  # Create IAM role
  create_backup_iam_role = true
  iam_role_name          = "AWSBackupTest"
  iam_policy_name        = "AWSBackupTest"

  # Create backup report
  create_backup_report         = true
  backup_report_name           = local.backup_vault_report_name
  s3_backup_report_bucket_name = module.s3_backup_report_bucket.s3_bucket_id

  # Set this so it will only create the vault but no backup plan
  backup_enabled = false

  # AWS Backup config
  resource_type_opt_in_preference = {
    "Aurora"   = true
    "DynamoDB" = true
    "EBS"      = true
    "EC2"      = true
    "EFS"      = true
    "FSx"      = true
    "RDS"      = true
    "S3"       = true
  }

  # Notifications
  backup_sns_topic_name = local.backup_sns_topic_name
  backup_notifications = {
    #sns_topic_arn       = aws_sns_topic.backup_events.arn
    #backup_vault_events = ["BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED", "RESTORE_JOB_COMPLETED"]
    subscribers = {
      tom = {
        protocol = "email"
        endpoint = local.sns_email_subscription
      }
    }
  }
  sns_kms_key_id = module.kms.sns.key_arn

  # Test cloudwatch alarm metrics
  enable_vault_alarms = {
    NumberOfBackupJobsAborted = true
  }

  tags = var.tags
}

# Create AWS Backup hourly plan
module "aws_backup_hourly" {
  source = "../.."

  vault_name        = local.backup_vault_name
  backup_enabled    = true
  backup_plan_name  = "eits-tf-aws-backup-plan-hourly"
  vault_kms_key_arn = module.kms.vault.key_arn
  iam_role_arn      = module.aws_backup_vault.backup_iam_role
  backup_rules = [
    {
      rule_name         = "eits-tf-aws-backup-rule-hourly"
      target_vault_name = module.aws_backup_vault.backup_vault_id
      schedule          = "cron(40 1/1 ? * * *)"
      start_window      = 60
      completion_window = 720
      lifecycle = {
        cold_storage_after = 0
        delete_after       = 7
      }
    }
  ]
  vss_enabled = true

  # No need to duplicate region settings
  manage_region_settings = false

  # Backup selection rule
  backup_selections = [
    {
      name      = "eits-tf-aws-backup-ruleselection-hourly"
      resources = ["*"]
      conditions = {
        string_equals = [
          {
            key   = "aws:ResourceTag/test_backup"
            value = "yes"
          }
        ]
      }
    }
  ]

  tags = var.tags
}
