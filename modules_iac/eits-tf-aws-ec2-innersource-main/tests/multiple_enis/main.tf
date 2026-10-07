# test region
provider "aws" {
  region = var.region
}

# test module with multiple additional ENIs
module "ec2" {
  source = "./../../"

  ec2_name      = "UKAEW2DAPUCLN01"
  ami           = "amzn_lnx_2023"
  instance_type = "t3a.medium" # t3a.medium supports up to 3 additional ENIs
  subnet        = var.subnet_ids[0]

  # Configure multiple additional ENIs
  additional_enis = [
    {
      # ENI 1: Same subnet with specific IPs
      subnet_id         = var.subnet_ids[0] # Same subnet to ensure same AZ
      device_index      = 1
      private_ips_count = 2
      description       = "Management ENI"
      tags = {
        Purpose = "Management"
      }
    },

    {
      # ENI 2: This will test the validation
      subnet_id    = var.subnet_ids[0]
      device_index = 2
      private_ips  = ["10.0.1.100"]
      description  = "Test ENI with conflicts"
      tags = {
        Purpose = "ValidationTesting"
      }
    }
  ]

  security_group_name        = "eits-tf-aws-ec2-sg"
  security_group_description = "eits-tf-aws-ec2-sg"
  security_group_ingress_rules = [
    {
      description = "ssh"
      from_port   = 22
      to_port     = 22
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

  root_volume_type = "gp3"
  root_volume_size = "60"

  ebs_block_device = [{
    device_name = "/dev/sde"
    volume_size = "30"
    volume_type = "gp3"
  }]

  disable_default_alarms = true

  tags = merge(var.tags, {
    ResourceAppRole  = "app"
    adDomain         = "gdc.local"
    CentrifyUnixRole = "UNX-ADM_example_ec2_servers"
  })
}

# Custom security group for one of the ENIs
resource "aws_security_group" "custom_eni" {
  name_prefix = "custom-eni-sg"
  description = "Custom security group for ENI"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "HTTP traffic"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "HTTPS traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = merge(var.tags, {
    ResourceAppRole  = "app"
    adDomain         = "gdc.local"
    CentrifyUnixRole = "UNX-ADM_example_ec2_servers"
  })
}