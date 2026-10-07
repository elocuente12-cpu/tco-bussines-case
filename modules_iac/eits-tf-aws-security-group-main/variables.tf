variable "ec2_agent_rules" {
  type        = string
  description = "Valid values are `linux` or `windows`. Whether to add default EEC EC2 agent rules to the security group. If set, the security group will allow inbound traffic on a number of agent and support related ports. Please see README for more information"
  default     = null

  validation {
    condition     = var.ec2_agent_rules == null || var.ec2_agent_rules == "linux" || var.ec2_agent_rules == "windows"
    error_message = "ec2_agent_rules must be set to `linux`, `windows`, or left null"
  }
}

variable "cyberark_sia_rules" {
  type        = string
  description = "Set to `windows` or `linux` to add CyberArk SIA related rules to the security group. This is automatically configured if `ec2_agent_rules` is set. Set it to `no` to exclude them."
  default     = null

  validation {
    condition     = var.cyberark_sia_rules == null || var.cyberark_sia_rules == "linux" || var.cyberark_sia_rules == "windows" || var.cyberark_sia_rules == "no"
    error_message = "cyberark_sia_rules must be set to `linux`, `windows`, `no`, or left null"
  }
}

variable "prefix" {
  type        = string
  description = "Used for naming the security group (see `security_group_name` for details). If left null, a prefix will be automatically calculated based on the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E)"
  default     = null
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the security group will be created. Required for EEC accounts as the default VPC is not in use"
}

variable "security_group_name" {
  type        = string
  description = "Used for naming the security group. To comply with EEC standards, the security group name will be computed as followed: `<prefix>-<security_group_name>-sg-<random_string>`. The random string is added by Terraform to ensure that, in case the group needs to be recreated, it can be created before deleting the old one to avoid downtime"
}

variable "security_group_description" {
  type        = string
  description = "Security group description. Cannot be an empty string. This maps to the AWS GroupDescription attribute, for which there is no Update API. If you'd like to classify your security groups in a way that can be updated, use tags"
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
    tags             = optional(map(string))
  }))
  description = <<EOT
    A list of Security Group INGRESS rule objects. Each ingress object supports the following fields: 
    <pre>security_group_ingress_rules = [
      {
        description      = (Optional) Description of this ingress rule.
        from_port        = (Optional) Start port (or ICMP type number if protocol is icmp or icmpv6).
        to_port          = (Optional) End range port (or ICMP code if protocol is icmp).
        protocol         = (Required) Protocol. If you select a protocol of -1 you must either omit from_port and to_port or set them to 0.
        cidr_blocks      = (Optional) List of CIDR blocks.
        ipv6_cidr_blocks = (Optional) List of IPv6 CIDR blocks.
        prefix_list_ids  = (Optional) List of Prefix List IDs.
        security_groups  = (Optional) List of security groups. A group name can be used relative to the default VPC. Otherwise, group ID.
        self             = (Optional) Whether the security group itself will be added as a source to this ingress rule.
        tags             = (Optional) A map of tags for the rule.
      }
    ]</pre>
    Although `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, `self`, and `security_groups` are all marked as optional, you must provide one of them in order to configure the destination of the traffic.
    The `from_port` and `to_port` arguments are required unless `protocol` is set to `-1` or `icmpv6`.
    See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule for further details
    EOT
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
    tags             = optional(map(string))
  }))
  description = <<EOT
    A list of Security Group EGRESS rule objects. Each egress object supports the following fields: 
    <pre>security_group_egress_rules = [
      {
        description      = (Optional) Description of this ingress rule.
        from_port        = (Optional) Start port (or ICMP type number if protocol is icmp or icmpv6).
        to_port          = (Optional) End range port (or ICMP code if protocol is icmp).
        protocol         = (Required) Protocol. If you select a protocol of -1 you must either omit from_port and to_port or set them to 0.
        cidr_blocks      = (Optional) List of CIDR blocks.
        ipv6_cidr_blocks = (Optional) List of IPv6 CIDR blocks.
        prefix_list_ids  = (Optional) List of Prefix List IDs.
        security_groups  = (Optional) List of security groups. A group name can be used relative to the default VPC. Otherwise, group ID.
        self             = (Optional) Whether the security group itself will be added as a source to this ingress rule.
        tags             = (Optional) A map of tags for the rule.
      }
    ]</pre>
    Although `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, `self`, and `security_groups` are all marked as optional, you must provide one of them in order to configure the destination of the traffic.
    The `from_port` and `to_port` arguments are required unless `protocol` is set to `-1` or `icmpv6`.
    See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule for further details
    EOT
  default     = []
}

variable "sleep_timeout" {
  type        = number
  description = "Time in seconds to wait before creating security group rules."
  default     = 5
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
  default     = {}
}
