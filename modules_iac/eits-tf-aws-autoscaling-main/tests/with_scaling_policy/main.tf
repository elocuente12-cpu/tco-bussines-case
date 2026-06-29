# test region
provider "aws" {
  region = var.region
}

# locals
locals {
  name = "eits-tf-aws-autoscaling-sscaling"
}

# create test security group
module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git"

  security_group_name        = local.name
  security_group_description = "For eits-tf-aws-autoscaling module testing"
  vpc_id                     = var.vpc_id
  security_group_ingress_rules = [
    {
      description = "Ping"
      from_port   = 8
      to_port     = 0
      protocol    = "icmp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
  ]
  security_group_egress_rules = [
    {
      description = "Centrify"
      from_port   = 389
      to_port     = 389
      protocol    = "tcp"
      cidr_blocks = ["194.60.173.145/32", "194.60.173.146/32", "194.60.173.147/32"]
    }
  ]

  tags = var.tags
}

# test module
# example of creating an autoscaling group and launch template, with auto scaling policies
module "autoscaling" {
  source = "./../.."

  name                      = local.name
  ami                       = "rhel_9"
  min_size                  = 1
  max_size                  = 2
  wait_for_capacity_timeout = 0
  default_instance_warmup   = 300
  health_check_type         = "EC2"
  subnet_ids                = var.subnet_ids

  # create launch template
  launch_template_config = {
    instance_type          = "t3.micro"
    security_groups        = [module.security_group.id]
    update_default_version = true
    instance_tags = {
      adDomain = "gdc.local"
      adGroup  = "WS-ADM_example_ec2_servers"
    }
  }

  # create scaling policy
  # these are just a couple of examples
  # for more details see https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy
  # check variables.tf for scaling_policies variable type specificiation
  scaling_policies = [
    {
      name        = "CPU Tracking Policy"
      policy_type = "TargetTrackingScaling"
      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = 50.0
      }
    },
    {
      name                      = "Step Scaling Policy"
      policy_type               = "StepScaling"
      adjustment_type           = "PercentChangeInCapacity"
      estimated_instance_warmup = 300
      step_adjustment = [
        {
          scaling_adjustment          = 20
          metric_interval_lower_bound = 0
          metric_interval_upper_bound = 5
        },
        {
          scaling_adjustment          = 25
          metric_interval_lower_bound = 5
          metric_interval_upper_bound = 15
        },
        {
          scaling_adjustment          = 50
          metric_interval_lower_bound = 15
        }
      ]
    }
  ]

  tags = var.tags
}
