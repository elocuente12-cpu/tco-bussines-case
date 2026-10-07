### Base ###

variable "additional_enis" {
  type = list(object({
    device_index      = number
    subnet_id         = optional(string)
    security_groups   = optional(list(string))
    private_ips       = optional(list(string))
    private_ips_count = optional(number)
    private_ip_list   = optional(list(string))
    description       = optional(string)
    tags              = optional(map(string), {})
  }))
  description = <<EOF
    (Optional) List of additional ENIs to create and attach to the instance.
    Each ENI can be configured with:
    - subnet_id: Subnet ID where the ENI will be created (defaults to main instance subnet)
    - security_groups: List of security group IDs (defaults to instance security groups)
    - private_ips: List of private IPs to assign without regard to order
    - private_ips_count: Number of secondary private IPs to assign to the ENI. The total number of private IPs will be 1 + private_ips_count, as a primary private IP will be assigned to an ENI by default.
    - private_ip_list: List of private IPs in sequential order
    - description: Description for the ENI
    - tags: Additional tags for the ENI

    Note:
    - If migrating from previous modules the `device_index` must be 1 for existing ENI to be preserved
    - Only one of `private_ips`, `private_ips_count`, or `private_ip_list` can be set per ENI (mutually exclusive).
    - Additional ENIs must have a greater than 0 `device_index`.
    - All ENIs must be in subnets within the same Availability Zone as the main instance.
    - Instance type limits the total number of ENIs (https://docs.aws.amazon.com/ec2/latest/instancetypes/gp.html#gp_network.)
  EOF
  default     = []

  validation {
    condition = alltrue([
      for eni in var.additional_enis :
      length(compact([
        eni.private_ips != null ? "private_ips" : null,
        eni.private_ips_count != null ? "private_ips_count" : null,
        eni.private_ip_list != null ? "private_ip_list" : null
      ])) <= 1
    ])
    error_message = "Only one of 'private_ips', 'private_ips_count', or 'private_ip_list' can be specified per ENI. These options are mutually exclusive."
  }

  validation {
    condition = alltrue([
      for eni in var.additional_enis : eni.device_index > 0
    ])
    error_message = "Each additional ENI must have a 'device_index' greater than 0."
  }
}

variable "ec2_name" {
  type        = string
  description = "Name of the EC2 instance (to populate tags if missing). Please read [EC2 Instance Naming Convention](https://experian.atlassian.net/wiki/x/zgL3E#HowtobuildEC2instancesusingtheExperianGoldenAMIs-EC2instanceNamingconvention) for guidance."
  default     = ""
}

### EC2 ###

variable "ami" {
  type        = string
  description = "The AMI to use for the instance"

  validation {
    condition     = length(regexall("windows_2019|windows_2022|windows_2025|amzn_lnx_2023|eks_amzn_lnx_2023|gpu_eks_amzn_lnx_2023|rhel_8|rhel_9|rhel_10|sles_15|ami-*", var.ami)) > 0
    error_message = "The AMI must be one of the following: windows_2019, windows_2022, windows_2025, amzn_lnx_2023, eks_amzn_lnx_2023, gpu_eks_amzn_lnx_2023, rhel_8, rhel_9, rhel_10, sles_15, ami-*."
  }
}

variable "instance_type" {
  type        = string
  description = "The type of the instance. By default it is `t3a.small`"
  default     = "t3a.small"
}

# tflint-ignore: terraform_unused_declarations
variable "vpc_id" {
  type        = string
  description = "The ID of the VPC that the instance security group belongs to. If not supplied will automatically get the VPC ID from `subnet` variable"
  default     = null
}

variable "subnet" {
  type        = string
  description = "VPC Subnet ID the instance is launched in"
}

variable "ssh_key_pair" {
  type        = string
  description = "SSH key pair to be provisioned on the instance"
  default     = null
}

variable "user_data" {
  type        = string
  description = "The user data to provide when launching the instance. Do not pass gzip-compressed data via this argument; use `user_data_base64` instead"
  default     = null
}

variable "user_data_base64" {
  type        = string
  description = "Can be used instead of `user_data` to pass base64-encoded binary data directly. Use this instead of `user_data` whenever the value is not a valid UTF-8 string. For example, gzip-encoded user data must be base64-encoded and passed via this argument to avoid corruption"
  default     = null
}

variable "user_data_replace_on_change" {
  type        = bool
  description = "When used in combination with `user_data` or `user_data_base64` will trigger a destroy and recreate when set to true. Defaults to false if not set."
  default     = false
}

variable "root_volume_type" {
  type        = string
  description = "Type of root volume. Can be `standard`, `gp2`*, `gp3`, `io1` or `io2`. *Only in local zones where `gp3` is not supported."
  default     = "gp3"

  validation {
    condition     = contains(["standard", "gp3", "io1", "io2"], var.root_volume_type) || (var.root_volume_type == "gp2" && local.is_local_zone)
    error_message = "The root volume type must be one of the following: `standard`, `gp2`*, `gp3`, `io1` or `io2`. *Only in local zones where `gp3` is not supported."
  }
}

variable "root_volume_size" {
  type        = number
  description = "Size of the root volume in gigabytes"
  default     = null
}

variable "root_volume_iops" {
  type        = number
  description = "Amount of provisioned IOPS for the Root volume. This must be set if root_volume_type is set of `io1`, `io2` or `gp3`"
  default     = 0
}

variable "root_volume_throughput" {
  type        = number
  description = "Amount of throughput for the Root volume. This must be set if root_volume_type is set to `gp3`"
  default     = 0
}

variable "root_volume_kms_key_id" {
  type        = string
  description = "KMS key ID used to encrypt the root volume. Modifying this value requires resource replacement"
  default     = null
}

variable "ebs_optimized" {
  type        = bool
  description = "Launched EC2 instance will be EBS-optimized"
  default     = true
}

variable "delete_on_termination" {
  type        = bool
  description = "Whether the volume should be destroyed on instance termination"
  default     = true
}

variable "detailed_monitoring" {
  type        = bool
  description = "If `true`, the launched EC2 instance will have detailed monitoring enabled. If left at the default `null`, then this will automatically be set to `true` for resources with an 'Environment' tag of value 'prd', and set to `false` for other environments. This is a cost-saving measure"
  default     = null
}

variable "instance_profile" {
  type        = string
  description = "A pre-defined profile to attach to the instance (default is 'eec-aws-amifactory-sc-iam-ec2role')"
  default     = "eec-aws-amifactory-sc-iam-ec2role"
}

variable "termination_protection" {
  type        = bool
  description = "If `true`, enable termination protection for the EC2 instance. See [EC2 Instance Termination Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html#Using_ChangingDisableAPITermination). If left at the default `null`, then this will automatically be set to `true` for resources with an 'Environment' tag of value 'prd', and set to `false` for other environments"
  default     = null
}

variable "metadata_http_tokens_required" {
  type        = bool
  description = "Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2."
  default     = true
}

variable "metadata_http_endpoint_enabled" {
  type        = bool
  description = "Whether the metadata service is available"
  default     = true
}

variable "metadata_tags_enabled" {
  type        = bool
  description = "Whether the tags are enabled in the metadata service."
  default     = false
}

variable "metadata_http_put_response_hop_limit" {
  type        = number
  description = "The desired HTTP PUT response hop limit (between 1 and 64) for instance metadata requests."
  default     = 1
}

variable "network_interface" {
  description = "Customize network interfaces to be attached at instance boot time"
  type        = list(map(string))
  default     = null
}

variable "private_ip" {
  type        = string
  description = "Private IP address to associate with the instance in the VPC"
  default     = null
}

variable "secondary_private_ips" {
  type        = list(string)
  description = "List of secondary private IP addresses to associate with the instance in the VPC"
  default     = null
}

variable "operating_system" {
  type        = string
  description = <<EOT
  The operating system of the instance. 
  If you set the `ami` variable with a specific AMI ID, and omit or set `exclude_default_security_group` to `false`, then you must set this to either `linux` or `windows`
  EOT
  default     = ""

  validation {
    condition     = !var.exclude_default_security_group && strcontains(var.ami, "ami-") ? contains(["linux", "windows"], var.operating_system) : true
    error_message = "The operating system must be one of the following: `linux` or `windows`"
  }
}

# SECURITY GROUP #

variable "security_group_name" {
  type        = string
  description = "Name of the security group. It must be unique. If omitted, Terraform will assign a random, unique name."
  default     = null
}

variable "security_group_description" {
  type        = string
  default     = "EC2 Security Group"
  description = "The Security Group description."
}

variable "security_groups" {
  description = "A list of Security Group IDs to associate with EC2 instance."
  type        = list(string)
  default     = []
}

variable "security_group_ingress_rules" {
  type = list(object({
    description      = optional(string)
    from_port        = optional(number)
    to_port          = optional(number)
    protocol         = string
    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    prefix_list_ids  = optional(list(string))
    security_groups  = optional(list(string))
    self             = optional(bool, false)
  }))
  description = "A list of Security Group INGRESS rule objects. The `self` key dictates whether the security group itself will be added as a source to the rule. Although `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, and `security_groups` are all marked as optional, you must provide at least ne of them in order to configure the source of the traffic. See [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for details on values"
  default     = []
}

variable "security_group_egress_rules" {
  type = list(object({
    description      = optional(string)
    from_port        = optional(number)
    to_port          = optional(number)
    protocol         = string
    cidr_blocks      = optional(list(string))
    ipv6_cidr_blocks = optional(list(string))
    prefix_list_ids  = optional(list(string))
    security_groups  = optional(list(string))
    self             = optional(bool, false)
  }))
  description = "A list of Security Group EGRESS rule objects. The `self` key dictates whether the security group itself will be added as a source to the rule. Although `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, and `security_groups` are all marked as optional, you must provide at least ne of them in order to configure the source of the traffic. See [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for details on values"
  default     = []
}

variable "exclude_default_security_group" {
  type        = bool
  description = "If set to `true`, default Experian security group rules will not be added. Note that this could break communication with security agents, potentially triggering security alerts!"
  default     = false
}

# TAGS #

variable "tags" {
  type        = map(string)
  default     = {}
  description = "EC2 instance tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags"
  # Dynatrace tags
  validation {
    condition     = !(contains(keys(var.tags), "monitoring")) || ((contains(keys(var.tags), "monitoring") && contains(keys(var.tags), "HostGroup")))
    error_message = "If the `monitoring` tag is provided, then `HostGroup` tags must also be provided, otherwise Dynatrace installation will fail."
  }
}

variable "security_group_tags" {
  type        = map(string)
  default     = {}
  description = "Security group tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags"
}

variable "ebs_volume_tags" {
  type        = map(string)
  default     = {}
  description = "EBS volume(s) tags (root volume and any additional one(s)). See https://experian.atlassian.net/wiki/x/swH3E for all available tags"
}

variable "cloudwatch_tags" {
  type        = map(string)
  default     = {}
  description = "Cloudwatch Alarm tags (in addition to the `non_instance_tags`). See https://experian.atlassian.net/wiki/x/swH3E for all available tags"
}

### EBS ###

variable "ebs_block_device" {
  type = list(object({
    device_name = string
    volume_size = number
    volume_type = optional(string, "gp3")
    iops        = optional(number)
    throughput  = optional(number)
    snapshot_id = optional(string)
    kms_key_id  = optional(string)
  }))
  description = <<EOT
    Additional EBS block devices to attach to the instance. 
    Note if `kms_key_id` is used then Terraform must have the GenerateDataKeyWithoutPlaintext permission on the KMS key to prevent a volume from being created and immediately deleted. See [aws_ebs_volume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) for details on values).
    `iops` must be specified if type is `io1` or `io2`. Minimum value is 100.
    - For `io1`, maximum value is 64000.
    - For `io2`, volumes greater than 16 TiB or 64K IOPS or 500:1 IOPS:GB ratio are only supported on instances compatible with io2 Block Express.
    For `gp3`:
    - `throughput` value must be between 125 and 1000 (Optional. If omitted, default is 125).
    - `iops` value must be between 100 and 16000 (Optional. If omitted, the default value is 3000). 
  EOT
  default     = []

  validation {
    condition = length([
      for device in var.ebs_block_device : true
      if contains(["standard", "gp3", "io1", "io2", "sc1", "st1"], device.volume_type) || (device.volume_type == "gp2" && local.is_local_zone)
    ]) == length(var.ebs_block_device)
    error_message = "The ebs volume type must be one of the following: `standard`, `gp2`*, `gp3`, `io1`, `io2`, `sc1`, `st1`. *Only in local zones where `gp3` is not supported."
  }
}

### ENI ###

variable "additional_eni_security_groups" {
  description = "A list of Security Group IDs to associate with the additional ENIs."
  type        = list(string)
  default     = null
}

### CLOUDWATCH AGENT ###

variable "enable_cloudwatch_agent" {
  type        = bool
  description = "To enable the CloudWatch agent on an instance built with an EEC AMI. Please see README.md for more details"
  default     = false
}

variable "create_cloudwatch_role" {
  type        = bool
  description = "Create and associate the `BURoleForEC2CloudWatchIntegration` role with the instance. Required if `enable_cloudwatch_agent` is set to `true` and `instance_profile` has not been set to `BURoleForEC2CloudWatchIntegration` or another role with the required permissions"
  default     = false
}

variable "cloudwatch_log_retention" {
  type        = number
  description = "The number of days for log retention. Only used if `enable_cloudwatch_agent` is set to `true`"
  default     = 14
}

variable "cloudwatch_role_policies" {
  type        = list(string)
  description = "List of additional JSON IAM policy documents to attach to the created `BURoleForEC2CloudWatchIntegration` role. Only used if `enable_cloudwatch_agent` is set to `true`"
  default     = []
}

### ALARMS ###

variable "disable_default_alarms" {
  type        = bool
  description = "To disable the best practice AWS alarms for EC2 instances outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#EC2)"
  default     = false
}

variable "enable_all_alarm_actions" {
  type        = bool
  description = "Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions"
  default     = false
}

variable "alarm_sns_topics" {
  type        = list(string)
  description = "List of SNS topics triggered by alarm events. providing a list will automatically enable alarm actions"
  default     = []
}

### INSTANCE SCHEDULER ###

variable "disable_instance_scheduler" {
  type        = bool
  description = "To disable the automatic configuring of [EEC AWS Instance Scheduler](https://experian.atlassian.net/wiki/x/yxL3E) Instance-Scheduler tag. Note that only those instances that are tagged as sandbox will get this configured currently, though it may be rolled out to other environments later"
  default     = false
}
