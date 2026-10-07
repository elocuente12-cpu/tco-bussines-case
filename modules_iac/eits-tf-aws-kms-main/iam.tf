data "aws_iam_policy_document" "this" {

  # Merge any supplied json with this policy
  source_policy_documents = var.policy == null ? null : [var.policy]

  # Key owner - all key operations
  dynamic "statement" {
    for_each = length(var.key_owners) > 0 ? [1] : []

    content {
      sid       = "KeyOwner"
      actions   = ["kms:*"]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_owners
      }
    }
  }

  # Key administrators - https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators
  # Always add terraform (current) user even if var.key_administrators is not passed to avoid terraform management errors
  statement {
    sid = "KeyAdministration"
    actions = [
      "kms:Create*",
      "kms:Describe*",
      "kms:Enable*",
      "kms:List*",
      "kms:Put*",
      "kms:Update*",
      "kms:Revoke*",
      "kms:Disable*",
      "kms:Get*",
      "kms:Delete*",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion",
      "kms:CancelKeyDeletion",
      "kms:ImportKeyMaterial"
    ]
    resources = ["*"]

    principals {
      type = "AWS"
      identifiers = concat(var.key_administrators, [
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BUAdministratorAccessRole",
        data.aws_iam_session_context.current.issuer_arn
      ])
    }
  }

  # Key users - https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-users
  dynamic "statement" {
    for_each = length(var.key_users) > 0 ? [1] : []

    content {
      sid = "KeyUsageUsers"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_users
      }
    }
  }

  # Key usage service - https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-users
  dynamic "statement" {
    for_each = length(var.key_services) > 0 ? [1] : []

    content {
      sid = "KeyUsageServices"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:DescribeKey",
      ]
      resources = ["*"]

      principals {
        type        = "Service"
        identifiers = local.service_principals
      }
    }
  }

  # Key service users - https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-service-integration
  dynamic "statement" {
    for_each = length(var.key_service_users) > 0 ? [1] : []

    content {
      sid = "KeyServiceUsage"
      actions = [
        "kms:CreateGrant",
        "kms:ListGrants",
        "kms:RevokeGrant",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_service_users
      }

      condition {
        test     = "Bool"
        variable = "kms:GrantIsForAWSResource"
        values   = [true]
      }
    }
  }

  # Key cryptographic operations - https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto
  dynamic "statement" {
    for_each = length(var.key_symmetric_encryption_users) > 0 ? [1] : []

    content {
      sid = "KeySymmetricEncryption"
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:Encrypt",
        "kms:GenerateDataKey*",
        "kms:ReEncrypt*",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_symmetric_encryption_users
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.key_hmac_users) > 0 ? [1] : []

    content {
      sid = "KeyHMAC"
      actions = [
        "kms:DescribeKey",
        "kms:GenerateMac",
        "kms:VerifyMac",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_hmac_users
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.key_asymmetric_public_encryption_users) > 0 ? [1] : []

    content {
      sid = "KeyAsymmetricPublicEncryption"
      actions = [
        "kms:Encrypt",
        "kms:Decrypt",
        "kms:ReEncrypt*",
        "kms:DescribeKey",
        "kms:GetPublicKey",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_asymmetric_public_encryption_users
      }
    }
  }

  dynamic "statement" {
    for_each = length(var.key_asymmetric_sign_verify_users) > 0 ? [1] : []

    content {
      sid = "KeyAsymmetricSignVerify"
      actions = [
        "kms:DescribeKey",
        "kms:GetPublicKey",
        "kms:Sign",
        "kms:Verify",
      ]
      resources = ["*"]

      principals {
        type        = "AWS"
        identifiers = var.key_asymmetric_sign_verify_users
      }
    }
  }

  dynamic "statement" {
    for_each = var.key_statements

    content {
      sid           = try(statement.value.sid, null)
      actions       = try(statement.value.actions, null)
      not_actions   = try(statement.value.not_actions, null)
      effect        = try(statement.value.effect, null)
      resources     = try(statement.value.resources, null)
      not_resources = try(statement.value.not_resources, null)

      dynamic "principals" {
        for_each = try(statement.value.principals, [])

        content {
          type        = principals.value.type
          identifiers = principals.value.identifiers
        }
      }

      dynamic "not_principals" {
        for_each = try(statement.value.not_principals, [])

        content {
          type        = not_principals.value.type
          identifiers = not_principals.value.identifiers
        }
      }

      dynamic "condition" {
        for_each = try(statement.value.conditions, [])

        content {
          test     = condition.value.test
          values   = condition.value.values
          variable = condition.value.variable
        }
      }
    }
  }
}