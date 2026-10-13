output "nlb_name" {
  description = "The ARN suffix of the NLB"
  value       = aws_lb.this.name
}

output "nlb_arn" {
  description = "The ARN of the NLB"
  value       = aws_lb.this.arn
}

output "nlb_dns_name" {
  description = "DNS name of NLB"
  value       = aws_lb.this.dns_name
}

output "nlb_zone_id" {
  description = "The ID of the zone which NLB is provisioned"
  value       = aws_lb.this.zone_id
}

output "target_group_arns" {
  description = "A list of all the target group ARNs"
  value       = values(aws_lb_target_group.this)[*].arn
}

output "target_group_names" {
  description = "A list of all the target group names"
  value       = values(aws_lb_target_group.this)[*].name
}

output "listener_arns" {
  description = "A list of all the listener ARNs"
  value       = values(aws_lb_listener.this)[*].arn
}
