data "aws_caller_identity" "current" {}

data "aws_iam_session_context" "this" {
  arn = data.aws_caller_identity.current.arn
}

data "aws_iam_policy_document" "this" {
  dynamic "statement" {
    for_each = length(var.secret_owners) > 0 ? [true] : []

    content {
      sid    = "PolicyForSecretOwners"
      effect = "Deny"
      actions = [
        "secretsmanager:CancelRotateSecret",
        "secretsmanager:CreateSecret",
        "secretsmanager:DeleteResourcePolicy",
        "secretsmanager:DeleteSecret",
        "secretsmanager:GetResourcePolicy",
        "secretsmanager:ListSecrets",
        "secretsmanager:PutResourcePolicy",
        "secretsmanager:RemoveRegionsFromReplication",
        "secretsmanager:ReplicateSecretToRegions",
        "secretsmanager:RestoreSecret",
        "secretsmanager:RotateSecret",
        "secretsmanager:StopReplicationToReplica",
        "secretsmanager:TagResource",
        "secretsmanager:UntagResource",
        "secretsmanager:UpdateSecret",
        "secretsmanager:UpdateSecretVersionStage",
        "secretsmanager:ValidateResourcePolicy",
      ]
      resources = ["*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEquals"
        values   = concat(var.secret_owners, [data.aws_iam_session_context.this.issuer_arn])
        variable = "aws:PrincipalArn"
      }
    }
  }

  dynamic "statement" {
    for_each = (length(var.secret_users) > 0 || length(var.secret_owners) > 0) ? [true] : []

    content {
      sid    = "PolicyForSecretUsers"
      effect = "Deny"
      actions = [
        "secretsmanager:GetSecretValue"
      ]
      resources = ["*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEquals"
        values   = concat(var.secret_users, var.secret_owners)
        variable = "aws:PrincipalArn"
      }
    }
  }

  dynamic "statement" {
    for_each = (length(var.secret_users) > 0 || length(var.secret_owners) > 0) ? [true] : []

    content {
      sid    = "PolicyForDescribeSecret"
      effect = "Deny"
      actions = [
        "secretsmanager:ListSecretVersionIds",
        "secretsmanager:DescribeSecret"
      ]
      resources = ["*"]

      principals {
        type        = "*"
        identifiers = ["*"]
      }

      condition {
        test     = "StringNotEquals"
        values   = concat(var.secret_users, var.secret_owners, [data.aws_iam_session_context.this.issuer_arn])
        variable = "aws:PrincipalArn"
      }
    }
  }
}
