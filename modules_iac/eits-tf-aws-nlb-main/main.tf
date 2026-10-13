locals {
  nlb_name = "${var.nlb_name}-nlb"
  tags     = merge(var.tags, module.eits_ce_common.tags)

  # get a list of additional_certs with their listener
  cert_list = flatten([
    for listener, value in var.listeners : [
      for additional_cert in value.additional_certs : {
        listener = "${lower(value.protocol)}_${value.port}"
        cert_arn = additional_cert
      }
    ]
  ])

  # get a map of targets with their target_group
  target_list = flatten([
    for target_group, value in var.target_groups : [
      for target in value.targets : {
        key               = target.name
        target_group      = target_group
        target_id         = target.target_id
        port              = target.port
        availability_zone = target.availability_zone
      }
    ]
  ])

  # check if the environment is prod
  has_prod_tag = lookup(merge(data.aws_default_tags.this.tags, var.tags), "Environment", "") == "prd"
}

# get provider tags
data "aws_default_tags" "this" {}

module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-nlb"
  tags        = local.tags
}

resource "aws_lb" "this" {
  name               = local.nlb_name
  tags               = merge(local.tags, { Name = local.nlb_name })
  internal           = var.scheme == "internal" ? true : false
  load_balancer_type = "network"
  subnets            = length(var.subnet_mapping) > 0 || length(var.subnet_ids) == 0 ? null : var.subnet_ids
  security_groups    = var.security_groups

  dynamic "subnet_mapping" {
    for_each = var.subnet_mapping

    content {
      subnet_id            = subnet_mapping.value.subnet_id
      allocation_id        = subnet_mapping.value.allocation_id
      private_ipv4_address = subnet_mapping.value.private_ipv4_address
    }
  }

  ip_address_type                  = "ipv4"
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing != null ? var.enable_cross_zone_load_balancing : local.has_prod_tag ? true : false
  enable_deletion_protection       = var.enable_deletion_protection
  desync_mitigation_mode           = var.desync_mitigation_mode

  dns_record_client_routing_policy       = var.dns_record_client_routing_policy
  secondary_ips_auto_assigned_per_subnet = var.secondary_ips_auto_assigned_per_subnet

  dynamic "access_logs" {
    for_each = var.access_log_bucket_id != null ? [1] : []

    content {
      bucket  = var.access_log_bucket_id
      prefix  = local.nlb_name
      enabled = true
    }
  }

  dynamic "minimum_load_balancer_capacity" {
    for_each = var.minimum_load_balancer_capacity_units != null ? [1] : []

    content {
      capacity_units = var.minimum_load_balancer_capacity_units
    }
  }

}

resource "aws_lb_target_group" "this" {
  for_each               = var.target_groups
  name                   = "${each.key}-tg" # has 32 character limit, only alphanumeric characters and hyphens allowed
  tags                   = merge(local.tags, { Name = "${var.nlb_name}-${each.key}" })
  vpc_id                 = var.vpc_id
  port                   = each.value.port
  protocol               = each.value.protocol
  proxy_protocol_v2      = each.value.proxy_protocol_v2
  target_type            = each.value.target_type
  deregistration_delay   = each.value.deregistration_delay
  connection_termination = each.value.connection_termination
  slow_start             = each.value.slow_start
  preserve_client_ip     = each.value.preserve_client_ip

  dynamic "health_check" {
    for_each = each.value.health_check != null ? [each.value.health_check] : []

    content {
      enabled             = health_check.value.enabled
      port                = health_check.value.port
      protocol            = health_check.value.protocol
      path                = health_check.value.path
      healthy_threshold   = health_check.value.healthy_threshold
      unhealthy_threshold = health_check.value.unhealthy_threshold
      interval            = health_check.value.interval
      timeout             = health_check.value.timeout
    }
  }

  dynamic "stickiness" {
    for_each = each.value.stickiness == true ? [1] : []

    content {
      enabled = true
      type    = "source_ip"
    }
  }

  lifecycle {
    create_before_destroy = true
  }

}

resource "aws_lb_listener" "this" {
  for_each = { for k, v in var.listeners : "${lower(v.protocol)}_${v.port}" => v }

  load_balancer_arn = aws_lb.this.arn
  port              = each.value.port
  protocol          = each.value.protocol

  ssl_policy      = each.value.ssl_policy
  certificate_arn = each.value.certificate_arn

  default_action {
    target_group_arn = aws_lb_target_group.this[each.value.default_target_group].arn
    type             = "forward"
  }

  tags = local.tags
}

resource "aws_lb_listener_certificate" "additional" {
  count = length(local.cert_list)

  listener_arn    = aws_lb_listener.this[local.cert_list[count.index].listener].arn
  certificate_arn = local.cert_list[count.index].cert_arn
}

resource "aws_lb_target_group_attachment" "this" {
  for_each = { for k, v in local.target_list : v.key => v }

  target_group_arn  = aws_lb_target_group.this[each.value.target_group].arn
  target_id         = each.value.target_id
  port              = each.value.port
  availability_zone = each.value.availability_zone
}
