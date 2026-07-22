# data "aws_kms_key" "by_alias" {
#   key_id = "alias/${module.global_variables.kmskey}"
# }

data "aws_caller_identity" "current" {}