# test region
provider "aws" {
  region = var.region
}

# test module
module "ec2" {
  source = "./../../"

  ec2_name                   = "UKAEW2DAPUCLN01"
  ami                        = "amzn_lnx_2023"
  instance_type              = "t3a.small"
  subnet                     = var.subnet_ids[0]
  network_interface          = [{ device_index = 0, network_interface_id = aws_network_interface.test.id }]
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

# network interface resource for test module2
resource "aws_network_interface" "test" {
  subnet_id         = var.subnet_ids[0]
  private_ips_count = 2
}

