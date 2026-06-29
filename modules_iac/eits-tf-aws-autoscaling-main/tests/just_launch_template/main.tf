# test region
provider "aws" {
  region = var.region
}

# example of creating JUST a launch template, without an autoscaling group
module "launch_template" {
  source = "./../.."

  # do not create asg group
  create_autoscaling_group = false

  # even though the below arguments are not in launch_template_config, they are still used to configure the launch template
  name        = "launch-template"
  name_prefix = "eits-tf-aws" # test override
  ami         = "rhel_9"

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

  # create launch template
  launch_template_config = {
    instance_type          = "t3.micro"
    update_default_version = true
    instance_tags = {
      adDomain = "gdc.local"
      adGroup  = "WS-ADM_example_ec2_servers"
    }
    network_interfaces = [
      {
        description = "default"
        subnet_id   = var.subnet_ids[0]
      }
    ]
  }

  tags = var.tags
}
