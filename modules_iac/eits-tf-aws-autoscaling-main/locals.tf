locals {
  name_prefix = var.name_prefix != null ? var.name_prefix : module.eits_ce_common.prefix
  ami_id      = var.ami == null ? null : length(regexall("ami-", var.ami)) > 0 ? var.ami : local.exp_ami_id[var.ami]
  tags        = merge(var.tags, module.eits_ce_common.tags, data.aws_default_tags.current.tags)
  asg_tags = merge(local.tags, {
    "Name"         = var.instance_name == "" ? format("%s-%s-asg", local.name_prefix, var.name) : var.instance_name
    "ResourceName" = var.instance_name == "" ? format("%s-%s-asg", local.name_prefix, var.name) : var.instance_name
  })

  # merge root_block_device and block_device_mappings
  block_device_mappings = concat(var.block_device_mappings, var.root_block_device != null ? [
    {
      device_name = data.aws_ami.current[0].root_device_name
      ebs         = var.root_block_device
    }
  ] : [])

  # map to EEC AMIs
  exp_ami_id = {
    "windows_2019"  = data.aws_ami.exp_win_2019_ami.id
    "windows_2022"  = data.aws_ami.exp_win_2022_ami.id
    "amzn_lnx"      = data.aws_ami.exp_amzn_lnx_ami.id
    "amzn_lnx_2023" = data.aws_ami.exp_amzn_lnx_2023_ami.id
    "amzn_eks"      = data.aws_ami.exp_amzn_eks_ami.id
    "rhel_8"        = data.aws_ami.exp_rhel_8_ami.id
    "rhel_9"        = data.aws_ami.exp_rhel_9_ami.id
    "sles_15"       = data.aws_ami.exp_sles_15_ami.id
  }

  # map to EEC AMI KMS keys
  exp_ami_kms_key = {
    us-east-1      = "arn:aws:kms:us-east-1:363353661606:key/923dfe86-1e45-4ff3-a75c-f8e95e7944b0"
    us-west-2      = "arn:aws:kms:us-west-2:363353661606:key/6a611956-f586-47da-bb67-6d305a15fc74"
    ap-south-1     = "arn:aws:kms:ap-south-1:363353661606:key/b7b93891-314f-4e00-8359-4f51d0a0cd09"
    ap-southeast-1 = "arn:aws:kms:ap-southeast-1:363353661606:key/edc1a20a-de45-423c-b06e-ce7485ae3aec"
    ap-southeast-2 = "arn:aws:kms:ap-southeast-2:363353661606:key/ea938280-bcdd-40d5-9302-ced83f9dd4f0"
    ap-northeast-1 = "arn:aws:kms:ap-northeast-1:363353661606:key/4fedb0a1-71e3-4a84-962d-177093b72386"
    eu-central-1   = "arn:aws:kms:eu-central-1:363353661606:key/00424fe0-fe05-4999-9e1c-f73674b8f2fd"
    eu-west-1      = "arn:aws:kms:eu-west-1:363353661606:key/34b027d4-f2c9-4622-b7e1-7043648fb9b1"
    eu-west-2      = "arn:aws:kms:eu-west-2:363353661606:key/4e9611e2-dd2a-4b8c-b79d-1b7602d5155f"
    sa-east-1      = "arn:aws:kms:sa-east-1:363353661606:key/52ef2dd4-4fb4-4e7d-8683-930d90b9e636"
  }

  # create list of security_groups and network_interfaces
  security_groups = concat(
    length(var.security_groups) > 0 ? var.security_groups : var.launch_template_config != null ? lookup(var.launch_template_config, "security_groups", []) : [],
    var.create_security_group != null ? [module.security_group[0].id] : []
  )
  network_interfaces = length(var.network_interfaces) > 0 ? var.network_interfaces : var.launch_template_config != null ? lookup(var.launch_template_config, "network_interfaces", []) : []
}
