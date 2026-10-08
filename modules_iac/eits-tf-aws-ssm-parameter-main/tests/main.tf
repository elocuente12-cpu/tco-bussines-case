# test region
provider "aws" {
  region = var.region
}

# generate KMS key for secure string use
module "kms" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  description  = "Test KMS Key for parameter store terraform tesing"
  key_services = ["ssm"]
  tags         = var.tags
}

# a big map of different parameter types to run through
locals {
  parameters = {
    "string_simple" = {
      value       = "string_value123"
      description = "Simple string"
    }
    "string" = {
      type            = "String"
      value           = "string_value123"
      tier            = "Intelligent-Tiering"
      allowed_pattern = "[a-z0-9_]+"
      description     = "string"
    }
    "secure" = {
      type        = "SecureString"
      value       = "secret123123!!!"
      tier        = "Advanced"
      description = "Secure string"
    }
    "secure_encrypted_true" = {
      secure_type = true
      value       = "secret123123!!!"
      key_id      = module.kms.key_id
      description = "CMK Secure string"
    }
    "list_as_autoguess_type" = {
      values      = ["item1", "item2"]
      description = "Auto guess list"
    }
    "list_as_jsonencoded_string" = {
      type        = "StringList"
      value       = jsonencode(["item1", "item2"])
      description = "JSON encoded list"
    }
    "list_as_plain_string" = {
      type        = "StringList"
      value       = "item1,item2"
      description = "Plain text list"
    }
    "list_as_autoconvert_values" = {
      type        = "StringList"
      values      = ["item1", "item2"]
      description = "String list"
    }
    "list_empty_as_jsonencoded_string" = {
      type        = "StringList"
      value       = jsonencode([])
      description = "Empty string list"
    }
    "secure_write_only" = {
      type             = "SecureString"
      value_wo         = "write_only_secret!!!"
      value_wo_version = 1
      description      = "SecureString using write-only value (not stored in state)"
    }
    "secure_write_only_cmk" = {
      type             = "SecureString"
      value_wo         = "write_only_secret_cmk!!!"
      value_wo_version = 1
      key_id           = module.kms.key_id
      description      = "SecureString using write-only value with CMK encryption"
    }
  }
}

// multiple parameter type test
module "parameter" {
  source   = "./.."
  for_each = local.parameters

  name             = format("eits-tf-aws-ssm-%s", try(each.value.name, each.key))
  value            = try(each.value.value, null)
  values           = try(each.value.values, [])
  value_wo         = try(each.value.value_wo, null)
  value_wo_version = try(each.value.value_wo_version, null)
  type             = try(each.value.type, null)
  secure_type      = try(each.value.secure_type, null)
  description      = try(each.value.description, null)
  tier             = try(each.value.tier, null)
  key_id           = try(each.value.key_id, null)
  allowed_pattern  = try(each.value.allowed_pattern, null)
  data_type        = try(each.value.data_type, null)
  tags             = var.tags
}
