locals {
  instance_name = lookup(var.tags, "Name", var.ec2_name)
  resource_temp = lookup(var.tags, "ResourceName", local.instance_name)
  resource_name = length(regexall("\\.", local.resource_temp)) == 0 ? "${local.resource_temp}.${lookup(local.eec_resourcename_regions, data.aws_region.current.region, "us")}.experian.eeca" : local.resource_temp
  tags          = merge(var.tags, module.eits_ce_common.tags)
  tags_to_check = merge(data.aws_default_tags.this.tags, var.tags)
  environment   = lookup(local.tags_to_check, "Environment", "")
  is_local_zone = data.aws_availability_zone.this.zone_type == "local-zone"

  # List of tags that should be on the ec2 instance only
  ec2_only_keys = [
    "adDomain",
    "adGroup",
    "adOU",
    "CentrifyUnixRole",
    "Instance-Scheduler",
    "ResourceName",
    "ResourceAppRole",
    "monitoring",
    "HostGroup",
    "InfraOnly",
    "DynatraceRegion",
    "ProductID",
    "Rapid7Tag",
    "PCI",
    "proxy",
    "ProxyUrl",
    "NoProxy",
    "PatchInstance",
    "cliTag",
    "CustomAMI",
    "ServiceAcceptance",
    "sysprep"
  ]
  non_instance_tags = { for k, v in local.tags : k => v if !contains(local.ec2_only_keys, k) }
  cloudwatch_tags   = merge(local.non_instance_tags, var.cloudwatch_tags)

  # Required tags (https://experian.atlassian.net/wiki/x/swH3E)
  required_tags = {
    Name         = local.instance_name
    ResourceName = local.resource_name
  }

  required_sg_tags = {
    Name         = lookup(var.tags, "Name", var.security_group_name)
    ResourceName = lookup(var.tags, "ResourceName", var.security_group_name)
  }

  root_volume_iops       = var.root_volume_iops < 3000 && var.root_volume_type == "gp3" ? 3000 : var.root_volume_iops
  root_volume_throughput = var.root_volume_throughput < 125 && var.root_volume_type == "gp3" ? 125 : var.root_volume_throughput

  create_ec2_security_group = var.exclude_default_security_group && length(var.security_group_egress_rules) == 0 && length(var.security_group_ingress_rules) == 0 ? false : true
  security_groups           = concat(var.security_groups, local.create_ec2_security_group ? [module.security_group[0].id] : [])
  agents_os                 = strcontains(var.ami, "ami-") ? var.operating_system : strcontains(var.ami, "windows") ? "windows" : "linux"

  # Map to EEC AMIs
  exp_ami = {
    "windows_2019"          = try(data.aws_ami.exp_win_2019[0].id, "")
    "windows_2022"          = try(data.aws_ami.exp_win_2022[0].id, "")
    "windows_2025"          = try(data.aws_ami.exp_win_2025[0].id, "")
    "amzn_lnx_2023"         = try(data.aws_ami.exp_amzn_lnx_2023[0].id, "")
    "eks_amzn_lnx_2023"     = try(data.aws_ami.exp_eks_amzn_lnx_2023[0].id, "")
    "gpu_eks_amzn_lnx_2023" = try(data.aws_ami.exp_gpu_eks_amzn_lnx_2023[0].id, "")
    "rhel_8"                = try(data.aws_ami.exp_rhel_8[0].id, "")
    "rhel_9"                = try(data.aws_ami.exp_rhel_9[0].id, "")
    "rhel_10"               = try(data.aws_ami.exp_rhel_10[0].id, "")
    "sles_15"               = try(data.aws_ami.exp_sles_15[0].id, "")
  }
  ami = length(regexall("ami-", var.ami)) > 0 ? var.ami : local.exp_ami[var.ami]

  # Region to Instance-Scheduler tag mapping
  eec_instance_scheduler_tag_regions = {
    "us-east-1"      = "us-east-office-hours"
    "us-east-2"      = "us-east-office-hours"
    "us-west-1"      = "us-west-office-hours"
    "us-west-2"      = "us-west-office-hours"
    "af-south-1"     = "de-frankfurt-office-hours"
    "ap-south-1"     = "in-mumbai-office-hours"
    "ap-south-2"     = "in-mumbai-office-hours"
    "ap-east-1"      = "sg-singapore-office-hours"
    "ap-northeast-1" = "sg-singapore-office-hours"
    "ap-northeast-2" = "sg-singapore-office-hours"
    "ap-northeast-3" = "sg-singapore-office-hours"
    "ap-southeast-1" = "sg-singapore-office-hours"
    "ap-southeast-2" = "au-sydney-office-hours"
    "ca-central-1"   = "ca-vancouver-office-hours"
    "ca-central-2"   = "ca-vancouver-office-hours"
    "eu-central-1"   = "de-frankfurt-office-hours"
    "eu-west-1"      = "ie-dublin-office-hours"
    "eu-west-2"      = "uk-london-office-hours"
    "eu-west-3"      = "de-frankfurt-office-hours"
    "eu-south-1"     = "de-frankfurt-office-hours"
    "eu-south-2"     = "de-frankfurt-office-hours"
    "eu-north-1"     = "de-frankfurt-office-hours"
    "sa-east-1"      = "br-saopaulo-office-hours"
  }

  # AWS regions to EEC regions mapping - only non-US regions are included

  eec_resourcename_regions = {
    "ap-south-1"     = "in"
    "ap-south-2"     = "in"
    "ap-east-1"      = "ap"
    "ap-northeast-1" = "ap"
    "ap-northeast-2" = "ap"
    "ap-northeast-3" = "ap"
    "ap-southeast-1" = "ap"
    "ap-southeast-2" = "ap"
    "eu-central-1"   = "uk"
    "eu-west-1"      = "uk"
    "eu-west-2"      = "uk"
    "eu-west-3"      = "uk"
    "eu-south-1"     = "uk"
    "eu-south-2"     = "uk"
    "eu-north-1"     = "uk"
    "sa-east-1"      = "br"
  }

  # Configures Instance-Scheduler tag based on region if Environment tag is sandbox and not disabled
  has_prod_tag    = local.environment == "prd"
  has_sandbox_tag = local.environment == "sbx"
  eec_instance_scheduler_tag = (
    var.disable_instance_scheduler ? {} : lookup(local.tags_to_check, "Instance-Scheduler", "") != "" ? {} :
    local.has_sandbox_tag ? { Instance-Scheduler = lookup(local.eec_instance_scheduler_tag_regions, data.aws_region.current.region, "uk-london-office-hours") } : {}
  )

  # CloudWatch Agent
  cloudwatch_agent_tags = var.enable_cloudwatch_agent ? { CWAgentInstall = "true", CWRetentionDays = var.cloudwatch_log_retention } : {}
}
