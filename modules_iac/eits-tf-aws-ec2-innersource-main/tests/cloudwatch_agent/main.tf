# test region
provider "aws" {
  region = var.region
}

# test creating multiple instances
locals {
  instances = {
    UKAEW2DAPUCLN01 = {
      ami           = "rhel_9"
      instance_type = "t3a.small"
      # other instance specific settings as required
    }
    UKAEW2DAPUCLN02 = {
      ami           = "sles_15"
      instance_type = "t3a.medium"
    }
    UKAEW2DAPUCLN03 = {
      ami           = "amzn_lnx_2023"
      instance_type = "t3a.small"
    }
  }
}

# create one security group for both instances
module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git"

  security_group_name        = "eits-tf-aws-ec2-cw"
  security_group_description = "Security group to test instances with cloudwatch agent"
  vpc_id                     = var.vpc_id
  ec2_agent_rules            = "linux"

  tags = var.tags
}

# test module
module "ec2" {
  source   = "./../../"
  for_each = local.instances

  ec2_name      = each.key
  ami           = each.value.ami
  instance_type = each.value.instance_type
  subnet        = var.subnet_ids[0]

  # install cloudwatch agent
  enable_cloudwatch_agent = true
  create_cloudwatch_role  = each.key == keys(local.instances)[0]                                              # only create the role for the first instance
  instance_profile        = each.key != keys(local.instances)[0] ? "BURoleForEC2CloudWatchIntegration" : null # add the role to non-first instances

  # use shared security group
  exclude_default_security_group = true
  security_groups                = [module.security_group.id]

  root_volume_size = "60"

  disable_default_alarms = true

  tags = merge(var.tags, {
    ResourceAppRole  = "app"
    adDomain         = "gdc.local"
    CentrifyUnixRole = "UNX-ADM_example_ec2_servers"
  })
}
