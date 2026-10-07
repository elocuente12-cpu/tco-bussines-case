resource "aws_kms_key" "this" {
  count = var.external_key ? 0 : 1

  deletion_window_in_days  = local.is_prod ? 30 : var.deletion_window_in_days
  description              = var.description
  enable_key_rotation      = true
  rotation_period_in_days  = var.rotation_period_in_days
  is_enabled               = var.is_enabled
  key_usage                = var.key_usage
  policy                   = data.aws_iam_policy_document.this.json
  multi_region             = var.multi_region
  xks_key_id               = var.xks_key_id
  custom_key_store_id      = var.custom_key_store_id
  customer_master_key_spec = var.customer_master_key_spec

  tags = local.tags
}

moved {
  from = resource.aws_kms_key.this
  to   = resource.aws_kms_key.this[0]
}

resource "aws_kms_external_key" "this" {
  count = var.external_key ? 1 : 0

  deletion_window_in_days = local.is_prod ? 30 : var.deletion_window_in_days
  description             = var.description
  key_usage               = var.key_usage
  policy                  = data.aws_iam_policy_document.this.json
  multi_region            = var.multi_region
  key_material_base64     = var.key_material_base64
  enabled                 = var.is_enabled

  tags = local.tags
}

resource "aws_kms_alias" "this" {
  for_each = { for k, v in local.aliases : v => v }

  name          = "alias/${local.prefix}-${each.value}-kms"
  target_key_id = var.external_key ? aws_kms_external_key.this[0].id : aws_kms_key.this[0].key_id
}

resource "aws_kms_grant" "this" {
  for_each = var.grants

  name              = each.value.name != null ? each.value.name : each.key
  key_id            = var.external_key ? aws_kms_external_key.this[0].id : aws_kms_key.this[0].key_id
  grantee_principal = each.value.grantee_principal
  operations        = each.value.operations

  dynamic "constraints" {
    for_each = length(lookup(each.value, "constraints", {})) == 0 ? [] : [each.value.constraints]

    content {
      encryption_context_equals = try(constraints.value.encryption_context_equals, null)
      encryption_context_subset = try(constraints.value.encryption_context_subset, null)
    }
  }

  retiring_principal    = each.value.retiring_principal
  grant_creation_tokens = each.value.grant_creation_tokens
  retire_on_delete      = each.value.retire_on_delete
}
