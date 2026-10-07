locals {
  # module version locals

  # get key based on module path, modules that use remote eits_ce_common will have .eits_ce_common directory, for example ".terraform/modules/ec2_ansible_server.security_group.eits_ce_common"
  # we can use this to get the "working" module key and parse the modules.json file
  # this will depend on this module being named "eits_ce_common" in every module we use it in
  module_key              = reverse(split(".", path.module))[0] == "eits_ce_common" ? trimsuffix(reverse(split("/", path.module))[0], ".eits_ce_common") : "local"
  artifactory_module_repo = replace(var.module_repo, "/(eits-tf-aws-|ukice-tf-aws-)/", "")

  module_source_list = flatten([
    for module in jsondecode(file("${path.root}/.terraform/modules/modules.json")).Modules : module.Source
    if module.Key == local.module_key && (strcontains(module.Source, var.module_repo) || strcontains(module.Source, local.artifactory_module_repo))
  ])

  module_source = length(local.module_source_list) > 0 ? local.module_source_list[0] : "local"

  module_version = (
    strcontains(local.module_source, "artifacts") && fileexists("${path.root}/.terraform/modules/modules.json") ? flatten([
      for module in jsondecode(file("${path.root}/.terraform/modules/modules.json")).Modules : lookup(module, "Version", "remote_latest")
      if module.Key == local.module_key && (strcontains(module.Source, var.module_repo) || strcontains(module.Source, local.artifactory_module_repo))
      ])[0] : (
      strcontains(local.module_source, "?ref") ? split("?ref=", local.module_source)[1] : (
        strcontains(local.module_source, "git") ? "remote_latest" : "local"
      )
    )
  )

  tags_to_output = merge(
    var.module_repo == "NONE" ? {} : {
      "eitsce:modulename"    = var.module_repo
      "eitsce:moduleversion" = local.module_version == "remote_latest" ? jsondecode(data.http.get_tags[0].response_body).values[0].displayId : local.module_version
    },
    { "eitsce:tagschecked" = "true" }
  )

  # label locals
  account_name = split("-", data.aws_iam_account_alias.current.account_alias)
  env_map = {
    "sandbox" = "sbx"
    "dev"     = "dev"
    "test"    = "tst"
    "uat"     = "uat"
    "stage"   = "stg"
    "prod"    = "prd"
  }
  number_elements       = length(local.account_name) - 1
  product_name_computed = local.number_elements > 5 ? join("", slice(local.account_name, 4, local.number_elements)) : local.account_name[local.number_elements - 1]
  country               = local.number_elements > 3 ? "${local.account_name[2]}-" : ""
  env                   = local.account_name[local.number_elements]
  label_prefix          = "${local.country}${local.product_name_computed}-${lookup(local.env_map, local.env, local.account_name[local.number_elements])}"

  # tag validation locals
  tags_to_validate = merge(data.aws_default_tags.account_tags.tags, var.tags)

  tags_checked = lookup(local.tags_to_validate, "eitsce:tagschecked", "false") == "true" ? true : false
}

### EITS CE TAG GENERATION ###

# get details from remote repo
data "http" "get_tags" {
  count = local.module_version == "remote_latest" ? 1 : 0
  url   = "https://code.experian.local/rest/api/1.0/projects/${var.module_project}/repos/${var.module_repo}/tags"

  request_headers = {
    Accept = "application/json"
  }
}

### TAG AND ACCOUNT NAME VALIDATION ###

# get AWS account alias
data "aws_iam_account_alias" "current" {}

# get AWS default tags
data "aws_default_tags" "account_tags" {}

check "cost_centre" {
  assert {
    condition     = local.tags_checked || length(regexall("^[0-9]{4}\\.[A-Z0-9]{2}\\.[0-9]{3}\\.[0-9]{6}$", lookup(local.tags_to_validate, "CostString", ""))) == 1
    error_message = "Invalid Cost Centre string '${lookup(local.tags_to_validate, "CostString", "")}' in 'CostString' tag. The format should be like '1234.CC.123.123456'"
  }
}

check "app_id" {
  assert {
    condition     = local.tags_checked || can(regex("^[1-9]\\d*$", lookup(local.tags_to_validate, "AppID", null))) || (can(lookup(local.tags_to_validate, "AppID", null) >= 0) && lookup(local.tags_to_validate, "Environment", "Environment") == "sbx")
    error_message = "'AppID' and 'Environment' tags are both required. AppID = 0 is only valid for Sandbox accounts (Environment = 'sbx'). Current AppID value: '${lookup(local.tags_to_validate, "AppID", "")}'"
  }
}

check "environment" {
  assert {
    condition     = local.tags_checked || contains(values(local.env_map), lookup(local.tags_to_validate, "Environment", ""))
    error_message = "'Environment' tag '${lookup(local.tags_to_validate, "Environment", "")}' not valid. It must be one of [${join(", ", values(local.env_map))}]"
  }
}
