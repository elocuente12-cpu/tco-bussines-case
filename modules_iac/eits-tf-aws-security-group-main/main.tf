data "aws_region" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-security-group"
  tags        = var.tags
}

resource "aws_security_group" "this" {
  # checkov:skip=CKV2_AWS_5: Generic module to create security group. This will be attached by the calling module
  name_prefix = local.sg_name
  description = var.security_group_description
  vpc_id      = var.vpc_id

  tags = local.tags

  # Setting this should avoid downtime when the resource needs to be recreated
  lifecycle {
    create_before_destroy = true
  }
}

### RULES ###
# aws_vpc_security_group_ingress_rule only allows string and not list(string) for cidr_ipv4, cidr_ipv6, prefix_list_ids, and self, while aws_security_group and aws_security_group_rule allows lists too
# Therefore, there are multiple resources that loops cidr_ipv4, cidr_ipv6 (even if IPv6 is not used in Experian currently), prefix_list_ids, and self (only one of the 3 is allowed at any time)
# This way, we can keep the same arguments as before, and users can use lists, which makes the code leaner

# Wait 5 seconds when rules are being created, to avoid errors when replacing existing rules
resource "time_sleep" "sg_rule_wait" {
  create_duration = "${var.sleep_timeout}s"
}

## INGRESS RULES ##

# Add default EEC EC2 rules if required
resource "aws_vpc_security_group_ingress_rule" "eec_default" {
  for_each = var.ec2_agent_rules == "windows" ? local.eec_ingress_rules_win : var.ec2_agent_rules == "linux" ? local.eec_ingress_rules_lin : {}

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  cidr_ipv4         = each.value.cidr_ipv4

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

# Add CyberArk SIA rules if required
resource "aws_vpc_security_group_ingress_rule" "cyberark_sia" {
  for_each = local.cyberark_sia_rules == "windows" ? local.cyberark_sia_rules_win : local.cyberark_sia_rules == "linux" ? local.cyberark_sia_rules_lin : {}

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  cidr_ipv4         = each.value.cidr_ipv4

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_ingress_rule" "cidr_ipv4" {
  for_each = local.sg_ingress_rule_ipv4cidr

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  cidr_ipv4         = each.value.cidr_ipv4
  tags              = each.value.tags

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_ingress_rule" "ipv6_cidr_blocks" {
  for_each = local.sg_ingress_rule_ipv6cidr

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  cidr_ipv6         = each.value.cidr_ipv6
  tags              = each.value.tags

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_ingress_rule" "prefix_list_ids" {
  for_each = local.sg_ingress_rule_pl

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  prefix_list_id    = each.value.prefix_list_id
  tags              = each.value.tags

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_ingress_rule" "security_groups" {
  for_each = local.sg_ingress_rule_sg

  security_group_id            = aws_security_group.this.id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  description                  = each.value.description
  referenced_security_group_id = each.value.referenced_security_group_id
  tags                         = each.value.tags

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_ingress_rule" "self" {
  for_each = local.sg_ingress_rule_self

  security_group_id            = aws_security_group.this.id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  description                  = each.value.description
  referenced_security_group_id = each.value.referenced_security_group_id

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

## EGRESS RULES ##

# Add default EEC EC2 rules if required
# Ignoring Trivy alert "AVD-AWS-0104 (CRITICAL): Security group rule allows unrestricted egress to any IP address." as the default SG allows that
#trivy:ignore:AVD-AWS-0104 
resource "aws_vpc_security_group_egress_rule" "eec_default" {
  for_each = var.ec2_agent_rules == "windows" || var.ec2_agent_rules == "linux" ? local.eec_egress_rules : {}

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  cidr_ipv4         = each.value.cidr_ipv4

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_egress_rule" "cidr_ipv4" {
  for_each = local.sg_egress_rule_ipv4cidr

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  cidr_ipv4         = each.value.cidr_ipv4
  tags              = each.value.tags

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_egress_rule" "ipv6_cidr_blocks" {
  for_each = local.sg_egress_rule_ipv6cidr

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  cidr_ipv6         = each.value.cidr_ipv6
  tags              = each.value.tags

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_egress_rule" "prefix_list_ids" {
  for_each = local.sg_egress_rule_pl

  security_group_id = aws_security_group.this.id
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  ip_protocol       = each.value.ip_protocol
  description       = each.value.description
  prefix_list_id    = each.value.prefix_list_id
  tags              = each.value.tags

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_egress_rule" "security_groups" {
  for_each = local.sg_egress_rule_sg

  security_group_id            = aws_security_group.this.id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  description                  = each.value.description
  referenced_security_group_id = each.value.referenced_security_group_id
  tags                         = each.value.tags

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}

resource "aws_vpc_security_group_egress_rule" "self" {
  for_each = local.sg_egress_rule_self

  security_group_id            = aws_security_group.this.id
  from_port                    = each.value.from_port
  to_port                      = each.value.to_port
  ip_protocol                  = each.value.ip_protocol
  description                  = each.value.description
  referenced_security_group_id = each.value.referenced_security_group_id

  depends_on = [
    time_sleep.sg_rule_wait
  ]
}
