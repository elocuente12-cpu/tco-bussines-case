module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-s3"
  tags        = var.tags
}

# Get list of gateway VPC endpoints in all VPCs
data "aws_vpcs" "this" {}
data "aws_region" "current" {}
data "aws_vpc_endpoint" "s3_gateways" {
  for_each = var.disable_source_ip_check || var.disable_source_vpce_check ? [] : toset(data.aws_vpcs.this.ids)

  vpc_id       = each.value
  service_name = "com.amazonaws.${data.aws_region.current.region}.s3"

  filter {
    name   = "vpc-endpoint-type"
    values = ["Gateway"]
  }
}



#Logging added in aws_s3_bucket_logging.this resource
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = var.force_destroy
  tags          = merge(local.tags, var.disable_source_ip_check ? { "eitsce:sourceipcheck" = "disabled" } : {})
}

resource "aws_s3_bucket_logging" "this" {
  count = var.access_logging_bucket_name != null ? 1 : 0

  bucket        = aws_s3_bucket.this.id
  target_bucket = var.access_logging_bucket_name
  target_prefix = "${local.bucket_name}/"

  target_object_key_format {
    dynamic "partitioned_prefix" {
      for_each = var.logging_key_format_partitioned_prefix != null ? [1] : []
      content {
        partition_date_source = var.logging_key_format_partitioned_prefix.partition_date_source
      }
    }
    dynamic "simple_prefix" {
      for_each = var.logging_key_format_partitioned_prefix == null ? [1] : []
      content {}
    }
  }
}

resource "time_sleep" "wait_for_s3_bucket" {
  depends_on      = [aws_s3_bucket.this]
  create_duration = "5s"
}

# Enable versioning automatically if replicating
resource "aws_s3_bucket_versioning" "this" {
  count = var.versioning_enabled || var.replication_config.enabled ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }

  # Otherwise fails to wait for completion and errors
  depends_on = [time_sleep.wait_for_s3_bucket]
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count = length(local.lifecycle_rules) > 0 ? 1 : 0

  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = local.lifecycle_rules

    content {
      id     = rule.value.id
      status = rule.value.status

      # Create abort_incomplete_multipart_upload block if we have a value
      dynamic "abort_incomplete_multipart_upload" {
        for_each = rule.value.abort_incomplete_multipart_upload_days != null ? [rule.value.abort_incomplete_multipart_upload_days] : []

        content {
          days_after_initiation = rule.value.abort_incomplete_multipart_upload_days
        }
      }

      # Max 1 block - expiration
      dynamic "expiration" {
        for_each = rule.value.expiration != null ? [rule.value.expiration] : []

        content {
          date                         = expiration.value.date
          days                         = expiration.value.days
          expired_object_delete_marker = expiration.value.expired_object_delete_marker
        }
      }

      # Several blocks - transition
      dynamic "transition" {
        for_each = rule.value.transition

        content {
          date          = transition.value.date
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      # Max 1 block - noncurrent_version_expiration
      dynamic "noncurrent_version_expiration" {
        for_each = rule.value.noncurrent_version_expiration != null ? [rule.value.noncurrent_version_expiration] : []

        content {
          newer_noncurrent_versions = noncurrent_version_expiration.value.newer_noncurrent_versions
          noncurrent_days           = noncurrent_version_expiration.value.noncurrent_days
        }
      }

      # Several blocks - noncurrent_version_transition
      dynamic "noncurrent_version_transition" {
        for_each = rule.value.noncurrent_version_transition

        content {
          newer_noncurrent_versions = noncurrent_version_transition.value.newer_noncurrent_versions
          noncurrent_days           = noncurrent_version_transition.value.noncurrent_days
          storage_class             = noncurrent_version_transition.value.storage_class
        }
      }

      # If no filter is supplied, set prefix to default empty string
      dynamic "filter" {
        for_each = try(length(rule.value.filter), 0) == 0 ? [true] : []

        content {}
      }

      # No more than 1 filter block is allowed - with a single or no tag
      dynamic "filter" {
        for_each = length(rule.value.filter) > 0 && try(length(rule.value.filter.tags), 0) <= 1 ? [rule.value.filter] : []

        content {
          object_size_greater_than = try(filter.value.object_size_greater_than, null)
          object_size_less_than    = try(filter.value.object_size_less_than, null)
          prefix                   = try(filter.value.prefix, null)

          dynamic "tag" {
            for_each = try(filter.value.tags, {})

            content {
              key   = tag.key
              value = tag.value
            }
          }
        }
      }

      # No more than 1 filter block is allowed - with and block
      dynamic "filter" {
        for_each = length(rule.value.filter) > 0 && try(length(rule.value.filter.tags), 0) > 1 ? [rule.value.filter] : []

        content {
          and {
            object_size_greater_than = try(filter.value.object_size_greater_than, null)
            object_size_less_than    = try(filter.value.object_size_less_than, null)
            prefix                   = try(filter.value.prefix, null)
            tags                     = try(filter.value.tags, {})
          }
        }
      }
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  for_each = var.intelligent_tiering

  name   = each.key
  bucket = aws_s3_bucket.this.id
  status = each.value.status

  # No more than 1 filter block is allowed
  dynamic "filter" {
    for_each = each.value.filter != null ? [each.value.filter] : []

    content {
      prefix = filter.value.prefix
      tags   = filter.value.tags
    }
  }

  dynamic "tiering" {
    for_each = each.value.tiering

    content {
      access_tier = tiering.key
      days        = tiering.value.days
    }
  }

}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = lookup(var.public_access_config, "block_public_acls", true)
  block_public_policy     = lookup(var.public_access_config, "block_public_policy", true)
  ignore_public_acls      = lookup(var.public_access_config, "ignore_public_acls", true)
  restrict_public_buckets = lookup(var.public_access_config, "restrict_public_buckets", true)
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      sse_algorithm     = var.sse_algorithm
      kms_master_key_id = var.sse_algorithm == "aws:kms" ? var.kms_key_arn : null
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = var.object_ownership
  }
}

# ACLs are only configured if object ownership hasn't been set to "BucketOwnerEnforced"
data "aws_canonical_user_id" "default" {}

resource "aws_s3_bucket_acl" "this" {
  count = var.object_ownership != "BucketOwnerEnforced" ? 1 : 0

  bucket = aws_s3_bucket.this.id

  # Canned ACLs conflict with access_control_policy so this is only enabled if no grants
  acl = length(local.acl_grants) == 0 ? var.acl_canned : null

  dynamic "access_control_policy" {
    for_each = length(local.acl_grants) == 0 ? [] : [1]

    content {
      dynamic "grant" {
        for_each = local.acl_grants

        content {
          grantee {
            id   = grant.value.id
            type = grant.value.type
            uri  = grant.value.uri
          }
          permission = grant.value.permission
        }
      }

      owner {
        id = one(data.aws_canonical_user_id.default[*].id)
      }
    }
  }
  depends_on = [aws_s3_bucket_ownership_controls.this]
}

# Create policy to block unsecure uploads by enforcing SSL and TLS 1.2 or higher
data "aws_iam_policy_document" "block_nonsecure_access" {
  statement {
    sid       = "EITSEnforceSSLOnlyAccess"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid       = "EITSEnforceTLSv12orHigher"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = ["${aws_s3_bucket.this.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "NumericLessThan"
      variable = "s3:TlsVersion"
      values   = ["1.2"]
    }
  }
}

# Create policy to restrict source ips outside of Experian
# Ignores aws services, vpc endpoints and tagged exceptions
data "aws_iam_policy_document" "restrict_source_ips" {
  count = var.disable_source_ip_check ? 0 : 1

  statement {
    sid     = "EITSRestrictSourceIPs"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*"
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "NotIpAddress"
      variable = "aws:SourceIp"
      values   = local.experian_source_ips
    }

    condition {
      test     = "Bool"
      variable = "aws:ViaAWSService"
      values   = ["false"]
    }

    condition {
      test     = "Bool"
      variable = "aws:PrincipalIsAWSService"
      values   = ["false"]
    }

    condition {
      test     = "StringNotEquals"
      variable = "aws:SourceVpce"
      values = concat(
        var.disable_source_vpce_check ? [] : [for gateway in data.aws_vpc_endpoint.s3_gateways : gateway.id],
        contains(keys(local.eec_shared_vpce), data.aws_region.current.region) ? [local.eec_shared_vpce[data.aws_region.current.region]] : [], # Only add VPCE if region is in list to prevent TF errors
        var.allowed_source_vpce_ids
      )
    }

    condition {
      test     = "ForAnyValue:StringNotEquals"
      variable = "aws:CalledVia"
      values = [
        "aoss.amazonaws.com",
        "athena.amazonaws.com",
        "backup.amazonaws.com",
        "cloud9.amazonaws.com",
        "cloudformation.amazonaws.com",
        "databrew.amazonaws.com",
        "dataexchange.amazonaws.com",
        "dynamodb.amazonaws.com",
        "imagebuilder.amazonaws.com",
        "kms.amazonaws.com",
        "mgn.amazonaws.com",
        "nimble.amazonaws.com",
        "omics.amazonaws.com",
        "ram.amazonaws.com",
        "robomaker.amazonaws.com",
        "servicecatalog-appregistry.amazonaws.com",
        "sqlworkbench.amazonaws.com",
        "ssm-guiconnect.amazonaws.com"
      ]
    }

    condition {
      test     = "Null"
      variable = "aws:PrincipalTag/eec:SourceIPException"
      values   = ["true"]
    }
  }
}

# Aggregate all sources of policy into one
data "aws_iam_policy_document" "source_documents" {
  source_policy_documents = concat(
    var.source_policy_documents,
    [data.aws_iam_policy_document.block_nonsecure_access.json],
    var.disable_source_ip_check ? [] : [data.aws_iam_policy_document.restrict_source_ips[0].json],
    var.bucket_policy != null ? [try(file(var.bucket_policy), var.bucket_policy)] : []
  )
}

# Apply bucket policy
resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.source_documents.json
}

# Turn on metrics for entire bucket by default
# AWS recommend using "EntireBucket" name for filters that apply to all objects 
resource "aws_s3_bucket_metric" "entire_bucket" {
  count = var.disable_default_alarms ? 0 : 1

  bucket = aws_s3_bucket.this.id
  name   = "EntireBucket"
}

# Create S3 access points, if required
resource "aws_s3_access_point" "this" {
  for_each = { for ap in var.access_points : ap.name => ap }

  name   = each.key
  bucket = aws_s3_bucket.this.id

  dynamic "vpc_configuration" {
    for_each = each.value.restricted_vpc_id != null ? [each.value] : []

    content {
      vpc_id = vpc_configuration.value.restricted_vpc_id
    }
  }

  public_access_block_configuration {
    block_public_acls       = each.value.block_public_acls
    block_public_policy     = each.value.block_public_policy
    ignore_public_acls      = each.value.ignore_public_acls
    restrict_public_buckets = each.value.restrict_public_buckets
  }

  lifecycle {
    ignore_changes = [policy]
  }
}

resource "aws_s3control_access_point_policy" "this" {
  for_each = { for ap in var.access_points : ap.name => ap if ap.policy != null }

  access_point_arn = aws_s3_access_point.this[each.key].arn
  policy           = each.value.policy
}

resource "aws_s3_bucket_object_lock_configuration" "this" {
  count = var.object_lock_configuration != null ? 1 : 0

  bucket              = aws_s3_bucket.this.id
  object_lock_enabled = "Enabled"
  rule {
    default_retention {
      mode  = var.object_lock_configuration.mode
      days  = var.object_lock_configuration.days
      years = var.object_lock_configuration.years
    }
  }
  depends_on = [aws_s3_bucket_versioning.this] # Add this line to ensure versioning is applied first
}