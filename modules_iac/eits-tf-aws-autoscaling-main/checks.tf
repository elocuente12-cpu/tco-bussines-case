check "warning_imdsv2_not_required" {
  assert {
    condition     = lookup(var.metadata_options, "http_tokens", "required") == "required"
    error_message = "WARNING: IMDSv2 is not required (http_tokens != 'required'). This is against security best practices."
  }
}

check "warning_single_availability_zone" {
  assert {
    condition     = length(try(aws_autoscaling_group.this[0].vpc_zone_identifier, [])) >= 2
    error_message = "WARNING: ASG spans fewer than 2 Availability Zones. Configure multiple subnets for high availability."
  }
}

check "warning_elb_health_check_not_used" {
  assert {
    condition     = length(var.target_group_arns) == 0 || var.health_check_type == "ELB"
    error_message = "WARNING: ASG is associated with a load balancer but not using ELB health checks (health_check_type != 'ELB')."
  }
}

check "warning_capacity_rebalance_disabled" {
  assert {
    condition     = var.capacity_rebalance == true
    error_message = "WARNING: Capacity rebalancing is not enabled. Enable it if using multiple instance types."
  }
}