output "tags" {
  value       = local.tags_to_output
  description = "Map of standard EITS CE tags"
}

output "prefix" {
  value       = local.label_prefix
  description = "Prefix label"
}

output "module_version" {
  value       = local.module_version
  description = "The version of the module"
}
