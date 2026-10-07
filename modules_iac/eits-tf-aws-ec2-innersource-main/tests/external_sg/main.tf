# test region
provider "aws" {
  region = var.region
}

module "sns_topic" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-sns.git"

  name = "test"
  subscribers = {
    test_email = {
      protocol = "email"
      endpoint = "test@experian.com"
    }
  }

  tags = var.tags
}

module "sg" {
  source = "git::https://code.uk.experian.local/scm/EUCES/eits-tf-aws-security-group.git"

  security_group_name        = "eits-tf-aws-ec2-sg"
  security_group_description = "EC2 security group"
  vpc_id                     = var.vpc_id
  ec2_agent_rules            = "linux"

  security_group_ingress_rules = [
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.187.144.0/20"]
    }
  ]
}

# test module
module "ec2" {
  source = "./../../"

  ec2_name        = "UKAEW2DAPUCLN01"
  ami             = "amzn_lnx_2023"
  instance_type   = "t3a.small"
  subnet          = var.subnet_ids[0]
  security_groups = [module.sg.id]

  root_volume_type = "gp3"
  root_volume_size = "60"

  ebs_block_device = [{
    device_name = "/dev/sde"
    volume_size = "30"
    volume_type = "gp3"
  }]

  tags = merge(var.tags, {
    ResourceAppRole  = "app"
    adDomain         = "gdc.local"
    CentrifyUnixRole = "UNX-ADM_example_ec2_servers"
  })

  alarm_sns_topics = [module.sns_topic.topic_arn]
}
