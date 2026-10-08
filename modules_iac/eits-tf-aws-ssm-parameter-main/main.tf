module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common?ref=v1"

  module_repo = "eits-tf-aws-ssm-parameter"
  tags        = var.tags
}

resource "aws_ssm_parameter" "this" {

  name             = var.name
  type             = local.type
  description      = var.description
  value            = var.value_wo == null && local.secure_type ? local.value : null
  insecure_value   = var.value_wo == null && (local.list_type || local.string_type) ? local.value : null
  value_wo         = var.value_wo
  value_wo_version = var.value_wo != null ? var.value_wo_version : null
  tier             = var.tier
  key_id           = local.secure_type ? var.key_id : null
  allowed_pattern  = var.allowed_pattern
  data_type        = var.data_type
  tags             = local.tags
}
