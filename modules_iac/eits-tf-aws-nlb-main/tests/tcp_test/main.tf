# test region
provider "aws" {
  region = var.region
}

# create ec2 to use for testing load balancer
module "test_ec2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ec2-innersource.git"

  ec2_name         = "eits-tf-aws-nlb-tcp"
  ami              = "amzn_lnx_2023"
  instance_type    = "t3.micro"
  vpc_id           = var.vpc_id
  subnet           = var.subnet_ids[0]
  root_volume_type = "gp3"
  root_volume_size = "50"

  security_group_name        = "eits-tf-aws-nlb-tcp"
  security_group_description = "eits-tf-aws-nlb-tcp"

  security_group_ingress_rules = [
    {
      description = "http"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]
  security_group_egress_rules = [
    {
      type        = "egress"
      from_port   = "0"
      to_port     = "0"
      protocol    = "-1"
      cidr_blocks = ["10.0.0.0/8"]
      description = "Allow outbound traffic to Experian network"
    }
  ]

  disable_default_alarms = true

  tags = var.tags
}

# test module
module "nlb" {
  source = "./../.."

  nlb_name   = "eits-tf-aws-nlb-tcp"
  vpc_id     = var.vpc_id
  subnet_ids = [var.subnet_ids[0]]

  security_groups = [module.test_ec2.security_group_id]

  enable_deletion_protection = false

  target_groups = {
    eits-tf-aws-nlb = {
      port     = 80
      protocol = "TCP"
      health_check = {
        enabled = true
        port    = "traffic-port"
      }
      target_type = "instance"
      targets = [
        {
          name      = "eits-tf-aws-nlb"
          target_id = module.test_ec2.id
        }
      ]
    }
  }

  listeners = [
    {
      port                 = 80
      protocol             = "TCP"
      default_target_group = "eits-tf-aws-nlb"
    }
  ]

  tags = var.tags
}
