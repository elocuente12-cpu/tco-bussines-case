output "id" {
  description = "The created or target Security Group ID"
  value       = aws_security_group.this.id
}

output "arn" {
  description = "The created Security Group ARN"
  value       = aws_security_group.this.arn
}

output "name" {
  description = "The created Security Group Name"
  value       = aws_security_group.this.name
}

output "ingress_rules" {
  description = "A map of all the ingress rules created for the security group"
  value = merge(
    aws_vpc_security_group_ingress_rule.eec_default,
    aws_vpc_security_group_ingress_rule.cidr_ipv4,
    aws_vpc_security_group_ingress_rule.ipv6_cidr_blocks,
    aws_vpc_security_group_ingress_rule.prefix_list_ids,
    aws_vpc_security_group_ingress_rule.security_groups,
    aws_vpc_security_group_ingress_rule.self
  )
}

output "egress_rules" {
  description = "A map of all the egress rules created for the security group"
  value = merge(
    aws_vpc_security_group_egress_rule.cidr_ipv4,
    aws_vpc_security_group_egress_rule.ipv6_cidr_blocks,
    aws_vpc_security_group_egress_rule.prefix_list_ids,
    aws_vpc_security_group_egress_rule.security_groups,
    aws_vpc_security_group_egress_rule.self
  )
}

output "vpc_id" {
  description = "The VPC ID where the security group is created"
  value       = aws_security_group.this.vpc_id
}