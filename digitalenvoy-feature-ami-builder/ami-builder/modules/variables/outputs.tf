output "server" {
  value = var.server
}

output "instance_types" {
  value = local.instance_types
}

output "volume_size" {
  value = local.volume_size
}

output "root_volume_size" {
  value = local.root_volume_size
}
output "imageBuilderComponents" {
  value = local.imageBuilderComponents
}

output "common_tags" {
  value = local.common_tags
}

output "name" {
  value = local.name
}

output "current_caller_identity" {
  value = data.aws_caller_identity.current
}

output "team" {
  value = var.team
}

output "region" {
  value = var.region
}

output "instance_min_size" {
  value = local.min_size
}

output "instance_max_size" {
  value = local.max_size
}

output "instance_desired_capacity" {
  value = local.desired_capacity
}

output "cpu_target_value" {
  value = local.cpu_target_value
}

output "asg_instance_name" {
  value = local.asg_instance_name
}

output "user_data_path" {
  value = local.user_data_path
}