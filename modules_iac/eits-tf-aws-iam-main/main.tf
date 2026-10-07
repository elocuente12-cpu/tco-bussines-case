module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-iam"
  tags        = var.tags
}

locals {
  tags = merge(var.tags, module.eits_ce_common.tags)

  # List of Experian PrincipalOrgIDs
  principal_org_ids = [
    "o-33fd8d019b",
    "o-m6fjxrdr7x",
    "o-c7zjgfu8y0",
    "o-yfj05rswby",
    "o-m5tvfoa2j3",
    "o-v4zenr53b5",
    "o-r4orxccey7",
    "o-72fonqzrib",
    "o-rhlgy4h75h",
    "o-sg7wkai3ne",
    "o-mw9tjv7zmd",
    "o-8jhc22ry8c",
    "o-khqbuhx1kx",
    "o-mtyumpp7ml"
  ]
  assume_role_policy = concat(
    var.assume_role_policy != null ? [var.assume_role_policy] : [],
    var.trusted_service != null ? [data.aws_iam_policy_document.principal_assume_role[0].json] : []
  )
  trusted_service = try(endswith(var.trusted_service, ".amazonaws.com") ? var.trusted_service : "${var.trusted_service}.amazonaws.com", null)
}

data "aws_iam_policy_document" "principal_assume_role" {
  count = local.trusted_service != null ? 1 : 0
  statement {
    sid    = "AssumeRoleService"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = [local.trusted_service]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "assume_role_policy" {
  source_policy_documents = local.assume_role_policy
  dynamic "statement" {
    for_each = var.disable_org_check ? [] : [1]
    content {
      sid     = "DenyNonExperianAccountAccess"
      effect  = "Deny"
      actions = ["sts:AssumeRole"]
      principals {
        type        = "AWS"
        identifiers = ["*"]
      }
      condition {
        test     = "StringNotEquals"
        variable = "aws:PrincipalOrgID"
        values   = local.principal_org_ids
      }
      condition {
        test     = "Bool"
        variable = "aws:PrincipalIsAWSService"
        values   = ["false"]
      }
    }
  }
}

# IAM role
resource "aws_iam_role" "default" {
  count = var.create_role ? 1 : 0

  name                 = var.override_role_name ? var.role_name : "BURoleFor${var.role_name}"
  description          = var.role_description == null ? "Role for ${var.role_name}" : var.role_description
  assume_role_policy   = data.aws_iam_policy_document.assume_role_policy.json
  max_session_duration = var.max_session_duration
  permissions_boundary = var.permissions_boundary
  path                 = var.path
  tags                 = local.tags

  lifecycle {
    ignore_changes = [
      tags["eec:ThirdPartyAccess"],
      tags["eec:ThirdPartyType"],
      tags["eec:ThirdPartyName"],
      tags["eec:SourceIPException"],
      tags["eec:ArcherVendorID"],
      tags["eec:ArcherEngagementID"],
      tags["eec:ArcherQuestionnaireID"],
      tags["eec:PSAID"],
      tags["eec:ARBID"],
      tags["eec:AppID"],
      tags["eec:NonExperianImageIDException01"],
      tags["eec:NonExperianImageIDException02"],
      tags["eec:NonExperianImageIDException03"],
      tags["eec:NonExperianImageOwnerException01"],
      tags["eec:NonExperianImageOwnerException02"],
      tags["eec:NonExperianImageOwnerException03"],
      tags["eitsce:orgcheck"]
    ]
  }
}

# IAM Policy document(s)
data "aws_iam_policy_document" "default" {
  count = length(var.policy_documents) > 0 ? 1 : 0

  source_policy_documents = var.policy_documents
}

# IAM Policy
resource "aws_iam_policy" "default" {
  count = length(var.policy_documents) > 0 ? 1 : 0

  name        = var.override_policy_name ? var.policy_name : "BUPolicyFor${var.policy_name}"
  description = var.policy_description == null ? "${var.policy_name} policy for ${var.role_name} role" : var.policy_description
  policy      = data.aws_iam_policy_document.default[0].json
  path        = var.path
  tags        = local.tags

  lifecycle {
    precondition {
      condition     = var.policy_name != "" && var.policy_name != null
      error_message = "The policy name is mandatory if a policy document is passed!"
    }
  }
}

# IAM Policy attachment to new role for newly created policy
resource "aws_iam_role_policy_attachment" "default" {
  count = length(var.policy_documents) > 0 && var.create_role ? 1 : 0

  role       = aws_iam_role.default[0].name
  policy_arn = aws_iam_policy.default[0].arn
}

# IAM Policy attachment for existing policies
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.create_role ? var.managed_policy_arns : []

  role       = aws_iam_role.default[0].name
  policy_arn = each.key
}

# IAM Instance Profile role
resource "aws_iam_instance_profile" "default" {
  count = var.instance_profile_enabled ? 1 : 0

  name = var.override_role_name ? var.role_name : "BURoleFor${var.role_name}"
  role = aws_iam_role.default[0].name
  tags = local.tags
}

data "aws_caller_identity" "current" {}