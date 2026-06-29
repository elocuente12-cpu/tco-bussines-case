output "file_system_arn" {
  description = "Amazon Resource Name (ARN) of the file system."
  value       = try(aws_fsx_windows_file_system.this.arn, null)
}

output "file_system_dns_name" {
  description = "DNS name for the file system, e.g., `fs-12345678.fsx.us-west-2.amazonaws.com` (domain name matching the Active Directory domain name)."
  value       = try(aws_fsx_windows_file_system.this.dns_name, null)
}

output "file_system_id" {
  description = "Identifier of the file system, e.g., `fs-12345678`"
  value       = try(aws_fsx_windows_file_system.this.id, null)
}

output "file_system_network_interface_ids" {
  description = "Set of Elastic Network Interface identifiers from which the file system is accessible."
  value       = try(aws_fsx_windows_file_system.this.network_interface_ids, [])
}

output "file_system_preferred_file_server_ip" {
  description = "IP address of the primary, or preferred, file server."
  value       = try(aws_fsx_windows_file_system.this.preferred_file_server_ip, null)
}

output "file_system_remote_administration_endpoint" {
  description = "For `MULTI_AZ_1` deployment types, use this endpoint when performing administrative tasks on the file system using Amazon FSx Remote PowerShell. For `SINGLE_AZ_1` deployment types, this is the DNS name of the file system."
  value       = try(aws_fsx_windows_file_system.this.remote_administration_endpoint, null)
}

output "cloudwatch_log_group_name" {
  description = "Name of the created Cloudwatch Log Group."
  value       = try(module.fsx_cloudwatch_log_group[0].log_group_name, null)
}

output "cloudwatch_log_group_arn" {
  description = "Arn of the created Cloudwatch Log Group."
  value       = try(module.fsx_cloudwatch_log_group[0].log_group_arn, null)
}

output "security_group_arn" {
  description = "Amazon Resource Name (ARN) of the created Security Group."
  value       = try(module.fsx_security_group[0].arn, null)
}

output "security_group_id" {
  description = "ID of the security group of the created Security Group."
  value       = try(module.fsx_security_group[0].id, null)
}