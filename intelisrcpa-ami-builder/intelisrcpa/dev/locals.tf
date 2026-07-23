locals {
  ###############################################
  # Naming Conventions (CloudNamingConventions.pdf)
  ###############################################
  name_prefix      = "eec-aws-us-eits-intelisrcpa"
  naming_construct = "${local.name_prefix}-${var.tagenv}"

  account_id = data.aws_caller_identity.current.account_id
}
