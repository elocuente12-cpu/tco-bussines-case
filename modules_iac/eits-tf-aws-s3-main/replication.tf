# replication IAM assume role policy
data "aws_iam_policy_document" "replication_assume_role" {
  count = var.replication_config.enabled ? 1 : 0

  statement {
    sid     = "AssumeServiceRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

# replication IAM policy
data "aws_iam_policy_document" "replication" {
  count = var.replication_config.enabled ? 1 : 0

  statement {
    sid    = "GetReplicationConfiguration"
    effect = "Allow"
    actions = [
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.this.arn]
  }

  statement {
    sid    = "AllowReplicationFromSource"
    effect = "Allow"
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging"
    ]
    resources = ["${aws_s3_bucket.this.arn}/*"]
  }

  statement {
    sid    = "AllowReplicationToDestination"
    effect = "Allow"
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner"
    ]
    resources = ["${var.replication_config.destination_bucket_arn}/*"]
  }
}

# replication IAM policy for source bucket kms keys
data "aws_iam_policy_document" "source_kms" {
  count = var.replication_config.enabled && var.sse_algorithm == "aws:kms" ? 1 : 0

  statement {
    sid       = "DecryptSourceKMS"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [var.kms_key_arn]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.${data.aws_region.current.region}.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = [aws_s3_bucket.this.arn]
    }
  }
}

# replication IAM policy for destination replica bucket kms keys
data "aws_iam_policy_document" "replica_kms" {
  count = var.replication_config.enabled && var.replication_config.enable_kms_encryption ? 1 : 0

  statement {
    sid       = "EncryptReplicaKMS"
    effect    = "Allow"
    actions   = ["kms:Encrypt"]
    resources = [var.replication_config.replica_kms_key_id]

    condition {
      test     = "StringLike"
      variable = "kms:ViaService"
      values   = ["s3.${var.replication_config.destination_region == null ? data.aws_region.current.region : var.replication_config.destination_region}.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "kms:EncryptionContext:aws:s3:arn"
      values   = [var.replication_config.destination_bucket_arn]
    }
  }
}

# create iam role for replication
module "replication_iam_role" {
  source               = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam?ref=1.9.7"
  count                = var.replication_config.enabled ? 1 : 0
  role_name            = var.replication_role_name != null ? var.replication_role_name : "BURoleForReplication-${local.bucket_name}"
  override_role_name   = true
  role_description     = "IAM Role for replication from ${local.bucket_name}"
  policy_name          = var.replication_role_name != null ? var.replication_role_name : "Replication-${local.bucket_name}"
  policy_description   = ""
  assume_role_policy   = data.aws_iam_policy_document.replication_assume_role[0].json
  disable_org_check    = var.disable_org_check
  permissions_boundary = var.permissions_boundary
  policy_documents     = var.replication_role_attach_policy_inline ? [] : [data.aws_iam_policy_document.replication_combined[0].json]

  tags = merge(var.tags, { "eitsce:parentmodule" = "eits-tf-aws-s3" })
}

resource "aws_iam_role_policy" "replication_inline" {
  count = var.replication_config.enabled && var.replication_role_attach_policy_inline ? 1 : 0

  name   = "BUInlineForReplicationDefault"
  role   = module.replication_iam_role[0].role_name
  policy = data.aws_iam_policy_document.replication_combined[0].json
}

# consolidated replication policy document
data "aws_iam_policy_document" "replication_combined" {
  count = var.replication_config.enabled ? 1 : 0

  source_policy_documents = concat(
    [data.aws_iam_policy_document.replication[0].json],
    var.sse_algorithm == "aws:kms" ? [data.aws_iam_policy_document.source_kms[0].json] : [],
    var.replication_config.enable_kms_encryption ? [data.aws_iam_policy_document.replica_kms[0].json] : []
  )
}

# set up replication configuration
resource "aws_s3_bucket_replication_configuration" "this" {
  count = var.replication_config.enabled ? 1 : 0

  role   = module.replication_iam_role[0].role_arn
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.replication_config.rules

    content {
      id       = rule.value.id
      status   = rule.value.status
      priority = rule.value.priority

      # destination configuration block
      destination {
        bucket        = var.replication_config.destination_bucket_arn
        storage_class = var.replication_config.storage_class
        account       = var.replication_config.replica_account

        # set replica ownership values
        dynamic "access_control_translation" {
          for_each = var.replication_config.replica_owner != null ? [var.replication_config.replica_owner] : []

          content {
            owner = access_control_translation.value
          }
        }

        # set encryption if we have a key
        dynamic "encryption_configuration" {
          for_each = var.replication_config.enable_kms_encryption ? [var.replication_config.replica_kms_key_id] : []

          content {
            replica_kms_key_id = encryption_configuration.value
          }
        }

        # enable metrics if disable_default_alarms is not true
        # event_threshold can only have 15 as a valid/default value anyway, so no point configuring it
        dynamic "metrics" {
          for_each = var.disable_default_alarms ? [] : [true]

          content {
            status = "Enabled"
            event_threshold {
              minutes = 15

            }
          }
        }

        # set replication time if specified
        # only set block if metrics are actually used
        # more info here: https://docs.aws.amazon.com/AmazonS3/latest/userguide/replication-walkthrough-5.html
        dynamic "replication_time" {
          for_each = var.disable_default_alarms ? [] : [1]
          content {
            status = "Enabled"

            time {
              minutes = 15
            }
          }
        }

      }

      # delete marker replication configuration block
      # must be actively specified as Disabled as default, for cross region compatibility
      delete_marker_replication {
        status = try(rule.value.delete_marker_replication, "Disabled")
      }

      # source selection criteria configuration block
      source_selection_criteria {

        replica_modifications {
          status = try(rule.value.replica_modifications, "Disabled")
        }

        # sse_kms_encrypted_objects is enabled if we set enable_kms_encryption to true
        # even if we set it to "Disabled" terraform throws an error, the entire block must be omitted
        dynamic "sse_kms_encrypted_objects" {
          for_each = var.replication_config.enable_kms_encryption ? [true] : []
          content {
            status = "Enabled"
          }
        }
      }

      # filter configuration block, takes either: empty block, "prefix" argument, "and" block, or "tag" block
      # create empty filter block if no keys specified
      dynamic "filter" {
        for_each = rule.value.filter != null ? (length(rule.value.filter) == 0 ? [true] : []) : [true]

        content {
        }
      }

      # filter block with content if filter is supplied
      # if both "tags" and "and" keys are supplied tf will error
      dynamic "filter" {
        for_each = rule.value.filter != null ? [rule.value.filter] : []

        content {
          prefix = filter.value.prefix

          dynamic "tag" {
            for_each = filter.value.tags != null ? filter.value.tags : []

            content {
              key   = tag.value.key
              value = tag.value.value
            }
          }

          dynamic "and" {
            for_each = filter.value.and != null ? filter.value.and : []

            content {
              prefix = and.value.prefix
              tags   = and.value.tags
            }
          }
        }
      }

    }
  }

  # must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.this]
}
