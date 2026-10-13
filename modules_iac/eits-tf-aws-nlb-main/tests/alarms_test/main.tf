# test region
provider "aws" {
  region = var.region
}

# Create an EC2 target so target group health alarms have a real target to evaluate.
module "test_ec2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ec2-innersource.git"

  ec2_name         = var.ec2_name
  ami              = "amzn_lnx_2023"
  instance_type    = "t3.micro"
  vpc_id           = var.vpc_id
  subnet           = var.subnet_ids[0]
  root_volume_type = "gp3"
  root_volume_size = "50"

  security_group_name        = "eits-tf-aws-nlb-alarms"
  security_group_description = "eits-tf-aws-nlb-alarms"

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

# Example alarm fixture: enable default alarms and override target-level thresholds.
module "nlb" {
  source = "./../.."

  nlb_name   = "eits-tf-aws-nlb-alarms"
  vpc_id     = var.vpc_id
  subnet_ids = [var.subnet_ids[0]]

  security_groups = [module.test_ec2.security_group_id]

  enable_deletion_protection = false

  # Alarm settings example: set module-wide defaults, then override at target group level.
  alarm_sns_topics               = []
  disable_default_alarms         = false
  enable_all_alarm_actions       = false
  alarm_tcp_elb_reset_threshold  = 25
  healthy_host_alarm_threshold   = 0
  unhealthy_host_alarm_threshold = 2

  target_groups = {
    nlb-alarms-test = {
      port     = 80
      protocol = "TCP"
      health_check = {
        enabled = true
        port    = "traffic-port"
      }

      # Override target-level thresholds to validate precedence over module defaults.
      target_alarm = {
        unhealthy_threshold = 1
        healthy_threshold   = 1
      }

      target_type = "instance"
      targets = [
        {
          name      = "alarm-test-target"
          target_id = module.test_ec2.id
        }
      ]
    }
  }

  listeners = [
    {
      port                 = 80
      protocol             = "TCP"
      default_target_group = "nlb-alarms-test"
    }
  ]

  tags = var.tags
}
