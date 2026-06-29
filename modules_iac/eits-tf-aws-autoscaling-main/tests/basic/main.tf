# test region
provider "aws" {
  region = var.region
}

# test module
# example of creating an autoscaling group and launch template
module "autoscaling" {
  source = "./../.."

  name                      = "eits-tf-aws-autoscaling-test"
  ami                       = "rhel_9"
  min_size                  = 1
  max_size                  = 2
  wait_for_capacity_timeout = 0
  default_instance_warmup   = 300
  health_check_type         = "EC2"
  subnet_ids                = var.subnet_ids

  # create security group
  create_security_group = {
    vpc_id      = var.vpc_id
    agent_rules = "linux"
    ingress_rules = [
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
      }
    ]
    egress_rules = [
      {
        description = "Centrify"
        from_port   = 389
        to_port     = 389
        protocol    = "tcp"
        cidr_blocks = ["194.60.173.145/32", "194.60.173.146/32", "194.60.173.147/32"]
      }
    ]
  }

  # create launch template
  launch_template_config = {
    instance_type          = "t3.micro"
    update_default_version = true
    instance_tags = {
      adDomain = "gdc.local"
      adGroup  = "WS-ADM_example_ec2_servers"
    }
  }

  # add new sde volume
  block_device_mappings = [
    {
      device_name = "/dev/sde"
      ebs = {
        delete_on_termination = true
        volume_size           = 30
        volume_type           = "gp3"
      }
    }
  ]

  # add instance refresh config
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      checkpoint_delay             = 600
      checkpoint_percentages       = [35, 70, 100]
      instance_warmup              = 300
      min_healthy_percentage       = 50
      auto_rollback                = true
      scale_in_protected_instances = "Refresh"
      standby_instances            = "Terminate"
    }
  }

  # add schedule to auto scale up and down
  schedules = [
    {
      action_name      = "scale_down"
      min_size         = 0
      max_size         = 0
      desired_capacity = 0
      recurrence       = "0 20 * * *"
    },
    {
      action_name      = "scale_up"
      min_size         = 1
      max_size         = 2
      desired_capacity = 1
      recurrence       = "0 6 * * *"
    }
  ]

  tags = var.tags
}
