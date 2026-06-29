locals {

  tags          = merge(var.tags, module.eits_ce_common.tags)
  tags_to_check = merge(data.aws_default_tags.account_tags.tags, var.tags)
  environment   = local.tags_to_check["Environment"]

  # https://docs.aws.amazon.com/fsx/latest/WindowsGuide/limit-access-security-groups.html
  security_group_ingress_rules = [
    {
      description = "SMB client"
      from_port   = 445
      to_port     = 445
      protocol    = "tcp"
      cidr_blocks = data.aws_vpc.this.cidr_block_associations[*].cidr_block
    },
    {
      description = "Administration"
      from_port   = 5985
      to_port     = 5985
      protocol    = "tcp"
      cidr_blocks = data.aws_vpc.this.cidr_block_associations[*].cidr_block
    },
  ]
  security_group_egress_rules = [
    {
      description = "Allow all egress"
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}