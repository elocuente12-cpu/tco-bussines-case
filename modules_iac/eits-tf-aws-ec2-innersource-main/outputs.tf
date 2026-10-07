output "name" {
  description = "Instance name"
  value       = local.required_tags["Name"]
}

output "id" {
  description = "Disambiguated ID of the instance"
  value       = join("", aws_instance.default[*].id)
}

output "arn" {
  description = "ARN of the instance"
  value       = join("", aws_instance.default[*].arn)
}

output "ami_id" {
  description = "ID of the AMI used to create the instance"
  value       = try(local.ami, null)
}

output "ssh_key_pair" {
  description = "Name of the SSH key pair provisioned on the instance"
  value       = var.ssh_key_pair
}

output "security_group_id" {
  description = "ID of the security group created for the EC2 instance"
  value       = try(module.security_group[0].id, null)
}

output "security_group_ids" {
  description = "IDs on the AWS Security Groups associated with the instance"
  value       = try(concat([module.security_group[0].id], var.security_groups), var.security_groups, null)
}

output "private_ip" {
  description = "Private IP of instance"
  value       = aws_instance.default.private_ip
}

output "private_dns" {
  description = "Private DNS of instance"
  value       = aws_instance.default.private_dns
}

output "multiple_network_interfaces" {
  description = "Map of additional network interfaces with their IDs and private DNS names"
  value = {
    for k, v in aws_network_interface.multiple : k => {
      id              = v.id
      private_dns     = v.private_dns_name
      private_ip      = v.private_ip
      private_ips     = v.private_ips
      subnet_id       = v.subnet_id
      device_index    = try([for att in v.attachment : att.device_index][0], null)
      security_groups = v.security_groups
    }
  }
}

output "tags" {
  description = "Map of tags assigned to the resource, including those inherited from the provider `default_tags` configuration block"
  value       = try(aws_instance.default.tags_all, null)
}
