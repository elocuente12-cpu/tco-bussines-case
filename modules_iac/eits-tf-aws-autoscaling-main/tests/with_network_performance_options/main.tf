# test region
provider "aws" {
  region = var.region
}

# test module - SUPPORTED instance type
# example of creating an autoscaling group with network performance options
# bandwidth_weighting is supported on 8th gen instance families:
# - General purpose: M8a, M8g, M8gd, M8i, M8id, M8i-flex
# - Compute optimized: C8a, C8g, C8gd, C8i, C8id, C8i-flex
# - Memory optimized: R8a, R8g, R8gd, R8i, R8id, R8i-flex
# See: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-bandwidth-weighting.html
module "autoscaling_supported" {
  source = "./../.."

  name                      = "eits-tf-aws-asg-net-perf-supported"
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
        description = "SSH"
        from_port   = 22
        to_port     = 22
        protocol    = "tcp"
        cidr_blocks = ["10.0.0.0/8"]
      }
    ]
  }

  # create launch template with a supported instance type (C8i family)
  launch_template_config = {
    instance_type          = "c8i.xlarge"
    update_default_version = true
    instance_tags = {
      adDomain = "gdc.local"
      adGroup  = "WS-ADM_example_ec2_servers"
    }
  }

  # configure network performance options
  # vpc-1 prioritizes network bandwidth over EBS throughput
  network_performance_options = {
    bandwidth_weighting = "vpc-1"
  }

  tags = var.tags
}
