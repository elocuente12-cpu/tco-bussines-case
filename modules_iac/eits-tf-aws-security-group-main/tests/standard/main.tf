# test region
provider "aws" {
  region = var.region
}

# test module
module "security_group" {
  source = "./../.."

  security_group_name        = "eits-tf-aws"
  security_group_description = "Security group for automated testing of eits-tf-aws-security-group repository"
  vpc_id                     = var.vpc_id
  ec2_agent_rules            = "linux"
  security_group_ingress_rules = [
    {
      description = "Ping"
      from_port   = -1
      to_port     = -1
      protocol    = "icmp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "Internal SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      self        = true
    }
  ]
  security_group_egress_rules = []

  tags = var.tags

}

output "ingress_rules" {
  value = module.security_group.ingress_rules
}

output "egress_rules" {
  value = module.security_group.egress_rules
}
