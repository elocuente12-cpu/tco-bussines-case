# Launch template outputs
output "launch_template_id" {
  value       = try(aws_launch_template.this[0].id, null)
  description = "The ID of the launch template"
}

output "launch_template_arn" {
  value       = try(aws_launch_template.this[0].arn, null)
  description = "The ARN of the launch template"
}

output "launch_template_name" {
  value       = try(aws_launch_template.this[0].name, null)
  description = "The name of the launch template"
}

output "launch_template_latest_version" {
  value       = try(aws_launch_template.this[0].latest_version, null)
  description = "The latest version of the launch template"
}

output "launch_template_default_version" {
  value       = try(aws_launch_template.this[0].default_version, null)
  description = "The default version of the launch template"
}

output "launch_template_http_tokens" {
  value       = try(aws_launch_template.this[0].metadata_options[0].http_tokens, null)
  description = "IMDSv2 HttpTokens setting (should be 'required')"
}

# Auto Scaling Group outputs
output "asg_id" {
  value       = try(aws_autoscaling_group.this[0].id, null)
  description = "The autoscaling group id"
}

output "asg_name" {
  value       = try(aws_autoscaling_group.this[0].name, null)
  description = "The autoscaling group name"
}

output "asg_arn" {
  value       = try(aws_autoscaling_group.this[0].arn, null)
  description = "The ARN for this AutoScaling Group"
}

output "asg_min_size" {
  value       = try(aws_autoscaling_group.this[0].min_size, null)
  description = "The minimum size of the autoscale group"
}

output "asg_max_size" {
  value       = try(aws_autoscaling_group.this[0].max_size, null)
  description = "The maximum size of the autoscale group"
}

output "asg_desired_capacity" {
  value       = try(aws_autoscaling_group.this[0].desired_capacity, null)
  description = "The number of Amazon EC2 instances that should be running in the group"
}

output "asg_default_cooldown" {
  value       = try(aws_autoscaling_group.this[0].default_cooldown, null)
  description = "Time between a scaling activity and the succeeding scaling activity"
}

output "asg_availability_zones" {
  value       = try(aws_autoscaling_group.this[0].availability_zones, [])
  description = "The availability zones of the autoscale group"
}

output "asg_vpc_zone_identifier" {
  value       = try(aws_autoscaling_group.this[0].vpc_zone_identifier, [])
  description = "The VPC zone identifier (subnets used by the ASG)"
}

output "asg_target_group_arns" {
  value       = var.target_group_arns
  description = "ARNs of the target groups associated with the ASG"
}

output "asg_health_check_type" {
  value       = try(aws_autoscaling_group.this[0].health_check_type, null)
  description = "Health check type used by the ASG (should be 'ELB')"
}

output "asg_capacity_rebalance" {
  value       = try(aws_autoscaling_group.this[0].capacity_rebalance, null)
  description = "Whether capacity rebalancing is enabled"
}

# Auto Scaling Policy outputs
output "scaling_policy_name" {
  value       = try(aws_autoscaling_policy.this[*].name, null)
  description = "Scaling policy's name"
}

output "scaling_policy_arn" {
  value       = try(aws_autoscaling_policy.this[*].arn, null)
  description = "ARN assigned by AWS to the scaling policy"
}

output "scaling_policy_adjustment_type" {
  value       = try(aws_autoscaling_policy.this[*].adjustment_type, null)
  description = "Scaling policy's adjustment type"
}

output "scaling_policy_policy_type" {
  value       = try(aws_autoscaling_policy.this[*].policy_type, null)
  description = "Scaling policy's type"
}

# Other resources outputs
output "kms_grant_id" {
  value       = try(aws_kms_grant.this[0].grant_id, null)
  description = "The unique identifier for the KMS grant"
}

output "service_linked_role_arn" {
  value       = try(aws_iam_service_linked_role.this[0].arn, null)
  description = "ARN specifying the IAM service-linked role"
}

output "schedule_arn" {
  value       = try(aws_autoscaling_schedule.this[0].arn, null)
  description = "ARN assigned by AWS to the autoscaling schedule"
}