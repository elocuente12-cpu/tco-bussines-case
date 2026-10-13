variable "access_log_bucket_id" {
  type        = string
  default     = null
  description = "The S3 bucket name to store the logs in, if `null` access logs will not be enabled"
}

variable "alarm_sns_topics" {
  type        = list(string)
  default     = []
  description = "A list of SNS topic ARNs for alarm notifications"
}

variable "enable_all_alarm_actions" {
  type        = bool
  default     = false
  description = "If true, send SNS notifications for ALARM, OK, and INSUFFICIENT_DATA states"
}

variable "disable_default_alarms" {
  type        = bool
  default     = false
  description = "If true, disables creation of the module default CloudWatch alarms"
}

variable "alarm_tcp_elb_reset_threshold" {
  type        = number
  default     = 10
  description = "Threshold for the default NLB TCP_ELB_Reset_Count alarm"
}

variable "unhealthy_host_alarm_threshold" {
  type        = number
  default     = 1
  description = "Default threshold for target group UnHealthyHostCount alarms"
}

variable "healthy_host_alarm_threshold" {
  type        = number
  default     = 0
  description = "Default threshold for target group HealthyHostCount alarms"
}

variable "desync_mitigation_mode" {
  type        = string
  default     = "defensive"
  description = "How the ALP handles HTTP desync requests. Valid values are `monitor`, `defensive`, `strictest`"
}

variable "enable_cross_zone_load_balancing" {
  type        = bool
  default     = null
  description = "A boolean flag to enable/disable cross zone load balancing. If left at the default `null`, then cross zone load balancing will be enabled for resources with an 'Environment' tag of value 'prd', but disabled automatically for other environments. This is a cost-saving measure. To override this, set specifically to either `true` or `false`"
}

variable "enable_deletion_protection" {
  type        = bool
  default     = true
  description = "A boolean flag to enable/disable deletion protection for NLB"
}

variable "nlb_name" {
  type        = string
  description = "Used to name all resources, must be unique per account"

  validation {
    condition = (
      can(regex("^[a-zA-Z0-9-]{1,28}$", var.nlb_name))
    )
    error_message = "The nlb_name variable must have a maximum of 28 alphanumerical characters"
  }
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "A list of subnet IDs to associate with NLB. Will be ignored if `subnet_mapping` is populated"
}

variable "subnet_mapping" {
  type = list(object({
    subnet_id            = optional(string)
    allocation_id        = optional(string)
    private_ipv4_address = optional(string)
  }))
  default     = []
  description = "A list of maps describing subnets to attach to network load balancer. Will override `subnet_ids` if populated"
}

variable "listeners" {
  type = list(object({
    default_target_group = optional(string)
    port                 = optional(number)
    protocol             = optional(string)
    ssl_policy           = optional(string)
    certificate_arn      = optional(string)
    additional_certs     = optional(list(string), [])
  }))
  default     = []
  description = "A list of maps describing the listeners for this NLB. Use `default_target_group` to attach listener to a target group, must match required root key from 'target_groups'. All NLB listener rules have the default forward action (NLBs are not comptible with any other action). See [lb_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener#argument-reference) for argument reference and required values"
}

variable "scheme" {
  type        = string
  default     = "internal"
  description = "The load balancer scheme, either `internet-facing` or `internal`. The nodes of an internet-facing (or 'public') load balancer have public IP addresses. The nodes of an internal load balancer have only private IP addresses. It is recommended to use an internal load balancer unless your usecase specifically requires an internet-facing one. Defaults to `internal`"
}

variable "security_groups" {
  type        = list(string)
  default     = []
  description = "A list of security group IDs to assign to the NLB. Security groups cannot be added if none are currently present, and cannot all be removed once added. Either of these conditions will force a recreation of the NLB resource"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}

variable "target_groups" {
  type = map(object({
    port                   = optional(number)
    protocol               = optional(string)
    proxy_protocol_v2      = optional(bool)
    deregistration_delay   = optional(number)
    slow_start             = optional(number)
    connection_termination = optional(bool)
    preserve_client_ip     = optional(bool)
    health_check = optional(object({
      enabled             = optional(bool)
      port                = optional(any)
      protocol            = optional(string)
      path                = optional(string)
      healthy_threshold   = optional(number)
      unhealthy_threshold = optional(number)
      interval            = optional(number)
      timeout             = optional(number)
    }))
    stickiness  = optional(bool)
    target_type = optional(string)
    target_alarm = optional(object({
      unhealthy_threshold = optional(number)
      healthy_threshold   = optional(number)
    }))
    targets = optional(list(object({
      name              = optional(string)
      target_id         = optional(string)
      port              = optional(number)
      availability_zone = optional(string)
    })), [])
  }))
  default     = {}
  description = "A map of maps for each required target group. The root map keys must be unique identifiers for each target group map, this will also be used to name the target groups. See [lb_target_group resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group#argument-reference) for valid/default values"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to associate with NLB"
}

variable "dns_record_client_routing_policy" {
  type        = string
  default     = null
  description = "How traffic is distributed among the load balancer Availability Zones. Possible values are `any_availability_zone` (default), `availability_zone_affinity`, or `partial_availability_zone_affinity`. See [AWS Docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/network-load-balancers.html#zonal-dns-affinity) for details"
}

variable "minimum_load_balancer_capacity_units" {
  type        = number
  default     = null
  description = "The minimum capacity units for the load balancer"
}

variable "secondary_ips_auto_assigned_per_subnet" {
  type        = number
  default     = null
  description = "The number of secondary IP addresses to configure for your load balancer nodes. The valid range is 0-7. WARNING: When decreased, this will force a recreation of the resource"
}
