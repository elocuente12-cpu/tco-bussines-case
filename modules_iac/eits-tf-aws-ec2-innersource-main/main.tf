### EITS CE Modules ###

module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-ec2-innersource"
  tags        = var.tags
}

### EC2 INSTANCE ###

# Migrate resources from the old CloudPosse module to this new resource
moved {
  from = module.ec2_instance.aws_instance.default[0]
  to   = aws_instance.default
}

resource "aws_instance" "default" {
  # checkov:skip=CKV_AWS_79: IMDSv2 enabled by default but using a bool variable so Checkov is not detecting this
  ami                     = local.ami
  instance_type           = var.instance_type
  subnet_id               = var.network_interface != null ? null : var.subnet # mutually exclusive with network_interface
  key_name                = var.ssh_key_pair
  iam_instance_profile    = var.create_cloudwatch_role ? module.cloudwatch_role[0].instance_profile : var.instance_profile
  disable_api_termination = var.termination_protection != null ? var.termination_protection : local.has_prod_tag ? true : false
  monitoring              = var.detailed_monitoring != null ? var.detailed_monitoring : local.has_prod_tag ? true : false
  ebs_optimized           = var.ebs_optimized

  vpc_security_group_ids = var.network_interface != null ? null : local.security_groups # mutually exclusive with network_interface

  dynamic "network_interface" {
    for_each = var.network_interface != null ? var.network_interface : []

    content {
      device_index         = network_interface.value.device_index
      network_interface_id = lookup(network_interface.value, "network_interface_id", null)
    }
  }

  private_ip                  = var.network_interface != null ? null : var.private_ip
  secondary_private_ips       = var.network_interface != null ? null : var.secondary_private_ips
  associate_public_ip_address = false # Adding this to comply with Wiz policy experian_egso_iac_audit_cicd_policy, mutually exclusive with network_interface

  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    iops                  = contains(["io1", "io2", "gp3"], var.root_volume_type) ? local.root_volume_iops : null
    throughput            = var.root_volume_type == "gp3" ? local.root_volume_throughput : null
    delete_on_termination = var.delete_on_termination
    encrypted             = true
    kms_key_id            = var.root_volume_kms_key_id
    tags                  = merge(local.required_tags, local.tags, var.ebs_volume_tags)
  }

  user_data                   = var.user_data
  user_data_base64            = var.user_data_base64
  user_data_replace_on_change = var.user_data_replace_on_change

  # Metadata options (for IMDSv2)
  metadata_options {
    http_endpoint               = var.metadata_http_endpoint_enabled ? "enabled" : "disabled"
    instance_metadata_tags      = var.metadata_tags_enabled ? "enabled" : "disabled"
    http_put_response_hop_limit = var.metadata_http_put_response_hop_limit
    http_tokens                 = var.metadata_http_tokens_required ? "required" : "optional"
  }

  tags = merge(local.required_tags, local.tags, local.eec_instance_scheduler_tag, local.cloudwatch_agent_tags)

  # Ignore tags that are managed elsewhere
  lifecycle {
    ignore_changes = [
      tags["eitsce:AWSBackupStatus"],
      tags["eitsce:AWSBackupLastTimeStamp"],
      tags["eitsce:AWSBackupPlanID"],
      tags["Instance-Scheduler-Status"],
      tags["IS-LastAction"],
      tags["IS-ManagedBy"]
    ]
  }
}

### SECURITY GROUP ###

module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git?ref=3.8.1"
  count  = local.create_ec2_security_group ? 1 : 0

  security_group_name          = var.security_group_name != null ? var.security_group_name : local.instance_name
  security_group_description   = var.security_group_description != null ? var.security_group_description : "Security group for instance ${local.instance_name}"
  vpc_id                       = var.vpc_id != null ? var.vpc_id : data.aws_subnet.this.vpc_id
  ec2_agent_rules              = var.exclude_default_security_group ? null : local.agents_os
  security_group_ingress_rules = var.security_group_ingress_rules
  security_group_egress_rules  = var.security_group_egress_rules

  tags = merge(local.required_sg_tags, local.non_instance_tags, var.security_group_tags, { "eitsce:parentmodule" = "eits-tf-aws-ec2-innersource" })

}

### EBS VOLUMES ###

resource "aws_ebs_volume" "this" {
  # checkov:skip=CKV2_AWS_2: EBS volumes encrypted by default
  # checkov:skip=CKV_AWS_3: EBS volumes encrypted by default
  # checkov:skip=CKV_AWS_189: EBS volumes encrypted by default
  for_each = { for ebs in var.ebs_block_device : ebs.device_name => ebs }

  availability_zone = aws_instance.default.availability_zone
  size              = each.value.volume_size
  type              = each.value.volume_type
  iops              = contains(["io1", "io2", "gp3"], each.value.volume_type) ? each.value.iops : null
  throughput        = each.value.volume_type == "gp3" ? each.value.throughput : null
  encrypted         = true
  snapshot_id       = each.value.snapshot_id
  kms_key_id        = each.value.kms_key_id

  lifecycle {
    ignore_changes = [
      tags["CreatedOn"]
    ]
  }
  tags = merge(local.required_tags, local.non_instance_tags, var.ebs_volume_tags)
}

resource "aws_volume_attachment" "this" {
  for_each = { for ebs in var.ebs_block_device : ebs.device_name => ebs }

  device_name = each.value.device_name
  volume_id   = aws_ebs_volume.this[each.key].id
  instance_id = aws_instance.default.id
}

### ADDITIONAL ENIs ###

# Multiple ENIs support
resource "aws_network_interface" "multiple" {
  for_each = { for eni in var.additional_enis : eni.device_index => eni }

  subnet_id       = coalesce(each.value.subnet_id, var.subnet)
  security_groups = coalesce(each.value.security_groups, var.additional_eni_security_groups, local.security_groups)
  description     = each.value.description

  private_ips             = each.value.private_ip_list == null && each.value.private_ips_count == null ? each.value.private_ips : null
  private_ips_count       = each.value.private_ip_list == null && each.value.private_ips == null ? each.value.private_ips_count : null
  private_ip_list         = each.value.private_ip_list
  private_ip_list_enabled = each.value.private_ip_list != null

  attachment {
    instance     = aws_instance.default.id
    device_index = each.value.device_index
  }

  tags = merge(local.required_tags, local.non_instance_tags, each.value.tags)
}

### CLOUDWATCH INTEGRATION ROLE ###
# see: https://experian.atlassian.net/wiki/x/zgL3E#FAQBuildingEC2instancesinAWS-CloudWatchAgent

data "aws_iam_policy_document" "cloudwatch_role_policy" {
  count = var.create_cloudwatch_role ? 1 : 0

  statement {
    sid = "EC2ReadTagsOnly"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeTags"
    ]
    resources = ["*"]
  }

  statement {
    sid = "ListAccountInformationPolicy"
    actions = [
      "iam:ListAccountAliases",
      "sts:GetCallerIdentity"
    ]
    resources = ["*"]
  }

  statement {
    sid = "LogsRetentionPolicy"
    actions = [
      "logs:PutRetentionPolicy",
      "ssm:PutParameter",
      "ssm:GetParameter"
    ]
    resources = ["*"]
  }

  statement {
    sid = "GetStandardAgentsS3Bucket"
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::eec-aws-standard-agents-*-bucket",
      "arn:aws:s3:::eec-aws-standard-agents-*-bucket/*"
    ]
  }

  statement {
    sid       = "PublishCyberarkTopicSNS"
    actions   = ["sns:Publish"]
    resources = ["arn:aws:sns:*:363353661606:eec-aws-cyberark-onboarding-sns"]
  }
}

data "aws_iam_policy_document" "cloudwatch_trust_policy" {
  count = var.create_cloudwatch_role ? 1 : 0

  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

module "cloudwatch_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam?ref=1.9.8"
  count  = var.create_cloudwatch_role ? 1 : 0

  instance_profile_enabled = true
  role_name                = "EC2CloudWatchIntegration"
  role_description         = "Instance role for CloudWatch agent"
  policy_name              = "EC2CloudWatchIntegration"
  policy_description       = "Instance role policy for CloudWatch agent"
  assume_role_policy       = data.aws_iam_policy_document.cloudwatch_trust_policy[0].json
  policy_documents         = concat([data.aws_iam_policy_document.cloudwatch_role_policy[0].json], var.cloudwatch_role_policies)
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/AWSEC2VssSnapshotPolicy"
  ]
  disable_org_check = true

  tags = merge(local.non_instance_tags, { "eitsce:parentmodule" = "eits-tf-aws-ec2-innersource" })
}
