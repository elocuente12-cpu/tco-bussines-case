# test region
provider "aws" {
  region = var.region
}

# locals
locals {
  name = "eits-tf-aws-autoscaling-template"
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

# get latest rhel 9 ami
data "aws_ami" "exp_rhel_9_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_rhel_9*"]
  }
}

# create external launch template
resource "aws_launch_template" "this" {
  name                   = "${local.name}-lt"
  description            = "Launch template for auto scaling group eits-tf-aws-autoscaling"
  image_id               = data.aws_ami.exp_rhel_9_ami.id
  instance_type          = "t3.micro"
  vpc_security_group_ids = [module.security_group.id]
  update_default_version = true

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      adDomain = "gdc.local"
      adGroup  = "WS-ADM_example_ec2_servers"
    })
  }

  block_device_mappings {
    device_name = "/dev/sde"
    ebs {
      delete_on_termination = true
      volume_size           = 30
      volume_type           = "gp3"
    }
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = var.tags
}

# test module
# example of creating an autoscaling group with an existing launch template
module "autoscaling" {
  source = "./../.."

  name       = local.name
  min_size   = 1
  max_size   = 2
  subnet_ids = var.subnet_ids

  # pass ami id even though we're not creating launch template
  # the module will detect it as an EEC ami and create the KMS grant for us
  ami = data.aws_ami.exp_rhel_9_ami.id

  # use existing template
  create_launch_template = false
  existing_launch_template = {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  tags = var.tags
}
