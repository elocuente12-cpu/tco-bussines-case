# test region
provider "aws" {
  region = var.region
}

# test module
module "eits_ce_common" {
  source = "./../.."

  module_repo = "eits-tf-aws-ce-common-test"
  tags        = var.tags
}

locals {
  tags = merge(var.tags, module.eits_ce_common.tags)
}

module "recheck" {
  source = "./../.."

  module_repo = "eits-tf-aws-ce-common-recheck"
  tags        = local.tags
}

# outputs
output "ce_common_tags" {
  value       = module.eits_ce_common.tags
  description = "Map of standard EITS CE tags"
}

output "recheck_tags" {
  value       = module.recheck.tags
  description = "Map of standard EITS CE tags"
}

output "prefix" {
  value       = module.eits_ce_common.prefix
  description = "Prefix label"
}
