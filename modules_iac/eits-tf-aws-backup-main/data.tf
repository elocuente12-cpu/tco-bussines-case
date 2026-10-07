data "aws_caller_identity" "current" {}

# Assume role policy for AWS Backup
data "aws_iam_policy_document" "aws_backup_assume_role" {
  # Block unsecure uploads
  statement {
    sid    = "AssumeRoleBackup"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }

    actions = [
      "sts:AssumeRole"
    ]
  }
}

# Policy for the AWS Backup role
data "aws_iam_policy_document" "aws_backup_role" {
  # Add any additional custom policy
  source_policy_documents = [var.backup_custom_policy]

  statement {
    sid    = "AllowTaggingBackup"
    effect = "Allow"

    actions = [
      "backup:TagResource",
      "backup:ListTags",
      "backup:UntagResource",
      "tag:GetResources"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "BackupActions"
    effect = "Allow"

    actions = [
      "backup:ListBackupVaults",
      "backup:StartBackupJob",
      "backup:DescribeBackupJob",
      "backup:GetRecoveryPointRestoreMetadata",
      "ec2:ModifyInstanceMetadataOptions"
    ]

    resources = ["*"]
  }

  statement {
    sid    = "AllowEC2RolePassToService"
    effect = "Allow"

    actions = [
      "iam:GetRole",
      "iam:PassRole"
    ]

    resources = [
      for role_name in var.backup_ec2_pass_role_names : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${role_name}"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ec2.amazonaws.com"]
    }
  }

  dynamic "statement" {
    for_each = local.effective_scan_setting != null ? [local.effective_scan_setting] : []
    content {
      sid    = "AllowScannerRolePassToBackup"
      effect = "Allow"

      actions = [
        "iam:GetRole",
        "iam:PassRole"
      ]

      resources = [statement.value.scanner_role_arn]

      condition {
        test     = "StringEquals"
        variable = "iam:PassedToService"
        values   = ["backup.amazonaws.com"]
      }
    }
  }
}

data "aws_iam_policy_document" "aws_backup_deny_deletions" {
  count = var.create_backup_vault && var.create_vault_policy ? 1 : 0
  # Block recovery points from being deleted
  statement {
    sid    = "DenyDelete"
    effect = "Deny"

    actions = [
      "backup:DeleteRecoveryPoint"
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = ["*"]
  }
}

data "aws_iam_policy_document" "aws_backup_lag_vault" {
  count = var.create_backup_lag_vault && var.lag_vault_policy == null ? 1 : 0
  statement {
    sid    = "AllowCopyToLAG"
    effect = "Allow"

    actions = [
      "backup:CopyIntoBackupVault"
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    resources = ["*"]
  }
}

### GuardDuty Malware Protection for Backup: IAM Role Permissions https://docs.aws.amazon.com/guardduty/latest/ug/malware-protection-backup-iam-permissions.html
data "aws_iam_policy_document" "aws_backup_scanner_assume_role" {
  # Block unsecure uploads
  statement {
    sid    = "AssumeRoleBackupScanner"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["malware-protection.guardduty.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "aws_backup_scanner_role" {
  statement {
    effect = "Allow"
    actions = [
      "ebs:ListSnapshotBlocks",
      "ebs:ListChangedBlocks",
      "ebs:GetSnapshotBlock"
    ]
    resources = ["arn:aws:ec2:*::snapshot/*"]
  }

  statement {
    sid       = "CreateGrantPermissions"
    effect    = "Allow"
    actions   = ["kms:CreateGrant"]
    resources = ["arn:aws:kms:*:*:key/*"]
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "kms:EncryptionContext:aws:guardduty:id"
      values   = ["snap-*"]
    }
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "kms:ViaService"
      values = [
        "guardduty.*.amazonaws.com",
        "backup.*.amazonaws.com"
      ]
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "kms:GrantOperations"
      values = [
        "Decrypt",
        "CreateGrant",
        "GenerateDataKeyWithoutPlaintext",
        "ReEncryptFrom",
        "ReEncryptTo",
        "RetireGrant",
        "DescribeKey"
      ]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  statement {
    sid       = "CreateGrantPermissionsForReEncryptAndDirectAPIs"
    effect    = "Allow"
    actions   = ["kms:CreateGrant"]
    resources = ["arn:aws:kms:*:*:key/*"]
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "kms:EncryptionContext:aws:ebs:id"
      values   = ["snap-*"]
    }
    condition {
      test     = "ForAnyValue:StringLike"
      variable = "kms:ViaService"
      values = [
        "guardduty.*.amazonaws.com",
        "backup.*.amazonaws.com"
      ]
    }
    condition {
      test     = "ForAllValues:StringEquals"
      variable = "kms:GrantOperations"
      values = [
        "Decrypt",
        "ReEncryptTo",
        "ReEncryptFrom",
        "RetireGrant",
        "DescribeKey"
      ]
    }
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }

  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeImages",
      "ec2:DescribeSnapshots"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "ShareSnapshotPermission"
    effect    = "Allow"
    actions   = ["ec2:ModifySnapshotAttribute"]
    resources = ["arn:aws:ec2:*:*:snapshot/*"]
  }

  statement {
    sid    = "ShareSnapshotKMSPermission"
    effect = "Allow"
    actions = [
      "kms:ReEncryptTo",
      "kms:ReEncryptFrom"
    ]
    resources = ["arn:aws:kms:*:*:key/*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["ec2.*.amazonaws.com"]
    }
  }

  statement {
    sid       = "DescribeKeyPermission"
    effect    = "Allow"
    actions   = ["kms:DescribeKey"]
    resources = ["arn:aws:kms:*:*:key/*"]
  }

  statement {
    sid       = "DescribeRecoveryPointPermission"
    effect    = "Allow"
    actions   = ["backup:DescribeRecoveryPoint"]
    resources = ["*"]
  }

  statement {
    sid       = "CreateBackupAccessPointPermissions"
    effect    = "Allow"
    actions   = ["backup:CreateBackupAccessPoint"]
    resources = ["arn:aws:backup:*:*:recovery-point:*"]
  }

  statement {
    sid    = "ReadAndDeleteBackupAccessPointPermissions"
    effect = "Allow"
    actions = [
      "backup:DescribeBackupAccessPoint",
      "backup:DeleteBackupAccessPoint"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "KMSKeyPermissionsForInstantAccess"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["arn:aws:kms:*:*:key/*"]
    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["backup.*.amazonaws.com"]
    }
  }
}

# IAM role for LAG vault copy Lambda function

data "aws_iam_policy_document" "aws_backup_lag_lambda_assume_role" {
  count = var.copy_to_lag ? 1 : 0
  # Block unsecure uploads
  statement {
    sid    = "AssumeRoleBackupLAGLambda"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

data "aws_iam_policy_document" "aws_backup_lag_lambda_role" {
  count = var.copy_to_lag ? 1 : 0

  statement {
    sid    = "AllowBackupCopyJob"
    effect = "Allow"
    actions = [
      "backup:StartCopyJob",
      "backup:DescribeRecoveryPoint",
      "backup:ListRecoveryPointsByBackupVault",
      "backup:DeleteRecoveryPoint"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowEC2Actions"
    effect = "Allow"
    actions = [
      "ec2:DescribeImages",
      "ec2:DeregisterImage",
      "ec2:DeleteSnapshot"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["arn:aws:logs:*:${data.aws_caller_identity.current.account_id}:*"]
  }
  statement {
    sid       = "AllowPassRole"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [local.backup_role_arn]
  }
}