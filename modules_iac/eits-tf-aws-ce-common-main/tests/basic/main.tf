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

# outputs
output "tags" {
  value       = module.eits_ce_common.tags
  description = "Map of standard EITS CE tags"
}

output "prefix" {
  value       = module.eits_ce_common.prefix
  description = "Prefix label"
}
