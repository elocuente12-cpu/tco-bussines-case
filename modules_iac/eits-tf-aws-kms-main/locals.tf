module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"


  module_repo = "eits-tf-aws-kms"
  tags        = var.tags
}

locals {
  prefix             = length(var.prefix) > 0 ? var.prefix : module.eits_ce_common.prefix
  is_prod            = length(regexall("prd", local.prefix)) > 0
  service_principals = [for service in var.key_services : "${service}.amazonaws.com"]
  formatted_services = [for service in var.key_services : replace(service, ".", "-")]
  aliases            = length(var.aliases) > 0 ? var.aliases : length(local.formatted_services) > 0 ? [join("-", local.formatted_services)] : []
  tags               = merge(var.tags, module.eits_ce_common.tags)
}