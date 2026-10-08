locals {
  type = var.type != null ? var.type : (
    length(var.values) > 0 ? "StringList" : (
      can(tostring(var.value)) ? (try(tobool(var.secure_type) == true, false) ? "SecureString" : "String") : "StringList"
  ))
  secure_type = local.type == "SecureString"
  list_type   = local.type == "StringList"
  string_type = local.type == "String"
  tags        = merge(var.tags, module.eits_ce_common.tags)
  value       = local.list_type ? (length(var.values) > 0 ? jsonencode(var.values) : var.value) : var.value
}
