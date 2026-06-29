variable "ami" {
  type        = string
  default     = null
  description = <<-EOT
    The AMI from which to launch the instance. Accepts either either the AMI ID (ami-*) or one the EEC image labels (see README.md).
    Only used if `create_launch_template` is `true`.
    Note: terraform may throw an error if a resource output is provided for this variable. In which case deploy that first, and then use the aws_ami data source to pass the AMI ID."
    EOT

  validation {
    condition = (
      var.ami == null ? true : (
        length(regexall("windows_2019|windows_2022|amzn_lnx|amzn_lnx_2023|amzn_eks|rhel_8|rhel_9|sles_15|ami-*", var.ami)) > 0
      )
    )
    error_message = "The AMI must be one of the following: windows_2019, windows_2022, amzn_lnx, amzn_lnx_2023, amzn_eks, rhel_8, rhel_9, sles_15, ami-*."
  }
}

variable "block_device_mappings" {
  type = list(object({
    device_name = string
    ebs = optional(object({
      delete_on_termination = optional(bool)
      encrypted             = optional(bool)
      kms_key_id            = optional(string)
      iops                  = optional(number)
      throughput            = optional(number)
      snapshot_id           = optional(string)
      volume_size           = optional(number)
      volume_type           = optional(string)
    }))
    no_device    = optional(bool)
    virtual_name = optional(string)
  }))
  default     = []
  description = "A list of volume maps to attach to the instance besides the volumes specified by the AMI. See [Block Devices](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#block-devices). Only used if `create_launch_template` is `true`"
}

variable "capacity_rebalance" {
  type        = bool
  default     = null
  description = "Indicates whether capacity rebalance is enabled"
}

variable "capacity_reservation_specification" {
  type = object({
    capacity_reservation_preference = optional(string)
    capacity_reservation_target = optional(object({
      capacity_reservation_id                 = optional(string)
      capacity_reservation_resource_group_arn = optional(string)
    }))
  })
  default     = null
  description = "Targeting for EC2 capacity reservations. See [Capacity Reservation Specification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#capacity-reservation-specification). Only used if `create_launch_template` is `true`"
}

variable "cpu_options" {
  type = object({
    amd_sev_snp      = optional(string)
    core_count       = optional(number)
    threads_per_core = optional(number)
  })
  default     = null
  description = "The CPU options for the instance. See [CPU Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#cpu-options). Only used if `create_launch_template` is `true`"
}

variable "create_autoscaling_group" {
  type        = bool
  default     = true
  description = "Determines whether to create an autoscaling group or not. Required for the majority of module functionality, but can be set to `false` to provision just a launch template, etc, if required. If `false` then the following functionality is also disabled: target group attachment, lifecycle hooks, scheduling, scaling policies, linked service role, and alarms"
}

variable "create_launch_template" {
  type        = bool
  default     = true
  description = "Determines whether to create launch template or not. The auto scaling group will always use latest version of the created launch template. If `false` then `existing_launch_template` is required"
}

variable "create_security_group" {
  type = object({
    name        = optional(string)
    vpc_id      = string
    agent_rules = optional(string)
    ingress_rules = optional(list(object({
      description      = optional(string)
      from_port        = optional(number)
      to_port          = optional(number)
      protocol         = optional(string)
      cidr_blocks      = optional(list(string))
      ipv6_cidr_blocks = optional(list(string))
      prefix_list_ids  = optional(list(string))
      security_groups  = optional(list(string))
      self             = optional(bool, false)
      tags             = optional(map(string))
    })), [])
    egress_rules = optional(list(object({
      description      = optional(string)
      from_port        = optional(number)
      to_port          = optional(number)
      protocol         = optional(string)
      cidr_blocks      = optional(list(string))
      ipv6_cidr_blocks = optional(list(string))
      prefix_list_ids  = optional(list(string))
      security_groups  = optional(list(string))
      self             = optional(bool, false)
      tags             = optional(map(string))
    })), [])
    tags = optional(map(string), {})
  })
  default     = null
  description = <<-EOT
    Create a security group which will be added to the launch template automatically in addition to any other security groups specified. Usage:
    <pre>create_security_group = {
      name          = Name of security group, if omitted will use root "name" variable. Will be prefixed using [EEC Cloud Naming Conventions](https://pages.experian.local/display/SC/Cloud+Naming+Conventions+or+Constructs).
      vpc_id        = VPC ID where the security group will be created.
      agent_rules   = Valid values are "linux" or "windows". Add default EEC EC2 agent rules to the security group.
      ingress_rules = See type declaration fo expected variable, see [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for details.
      ingress_rules = See type declaration fo expected variable, see [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for details.
      tags          = Additional tags for the security group. Merged with root "tags" variable.
    }</pre>
    For greater detail on values please see [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse).
    EOT
}

variable "default_cooldown" {
  type        = number
  default     = null
  description = "The amount of time, in seconds, after a scaling activity completes before another scaling activity can start"
}

variable "default_instance_warmup" {
  type        = number
  default     = null
  description = "Amount of time, in seconds, until a newly launched instance can contribute to the Amazon CloudWatch metrics. See [AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-default-instance-warmup.html) for details"
}

variable "desired_capacity" {
  type        = number
  default     = null
  description = "The number of Amazon EC2 instances that should be running in the auto scaling group"
}

variable "desired_capacity_type" {
  type        = string
  default     = null
  description = "The unit of measurement for the value specified for `desired_capacity`. Supported for attribute-based instance type selection only. Valid values: `units`, `vcpu`, `memory-mib`"
}

variable "enabled_metrics" {
  type        = list(string)
  default     = []
  description = "A list of additional metrics to collect. Note that if `disable_default_alarms` is `false` then GroupInServiceCapacity is already enabled"
}

variable "existing_launch_template" {
  type = object({
    id      = optional(string)
    version = optional(string)
  })
  default     = null
  description = "Map of `id` and `version` of an existing launch template (created outside of this module). `version` value can be version number, `$Latest`, or `$Default` (default is $Default). Ignored if `create_launch_template` is `true`"
}

variable "existing_service_linked_role_arn" {
  type        = string
  default     = null
  description = "The ARN of an existing service-linked role that the ASG will use to call other AWS services. If `null` is provided, one will be created"
}

variable "health_check_type" {
  type        = string
  default     = null
  description = "`EC2` or `ELB`. Controls how health checking is done"
}

variable "health_check_grace_period" {
  type        = number
  default     = null
  description = "Time (in seconds) after instance comes into service before checking health"
}

variable "instance_maintenance_policy" {
  type = object({
    min_healthy_percentage = optional(number)
    max_healthy_percentage = optional(number)
  })
  default     = null
  description = "Add an instance maintenance policy. See [Instance Maintenance Policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#instance_maintenance_policy)"
}

variable "instance_market_options" {
  type = object({
    market_type = optional(string)
    spot_options = optional(object({
      instance_interruption_behavior = optional(string)
      max_price                      = optional(string)
      spot_instance_type             = optional(string)
      valid_until                    = optional(string)
    }))
  })
  default     = null
  description = "The market (purchasing) option for the instance. See [Market Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#market-options). Only used if `create_launch_template` is `true`"
}

variable "instance_name" {
  type        = string
  default     = ""
  description = "Name that is propagated to launched EC2 instances via a tag"
}

variable "instance_refresh" {
  type = object({
    strategy = optional(string)
    triggers = optional(list(string))
    preferences = optional(object({
      checkpoint_delay       = optional(number)
      checkpoint_percentages = optional(list(number))
      instance_warmup        = optional(number)
      max_healthy_percentage = optional(number)
      min_healthy_percentage = optional(number)
      skip_matching          = optional(bool)
      auto_rollback          = optional(bool)
      alarm_specification = optional(object({
        alarms = optional(list(string))
      }))
      scale_in_protected_instances = optional(string)
      standby_instances            = optional(string)
    }))
  })
  default     = null
  description = "Start an Instance Refresh when this ASG is updated. See [Instance Refresh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#instance_refresh)"
}

variable "launch_template_config" {
  type = object({
    instance_type           = optional(string, "t3.micro")
    instance_profile        = optional(string, "eec-aws-amifactory-sc-iam-ec2role")
    ebs_optimized           = optional(bool, true)
    user_data               = optional(string, null)
    ssh_key_pair            = optional(string, null)
    default_version         = optional(string, null)
    update_default_version  = optional(bool, null)
    disable_api_termination = optional(string, null)
    disable_api_stop        = optional(string, null)
    shutdown_behavior       = optional(string, "stop")
    kernel_id               = optional(string, null)
    ram_disk_id             = optional(string, null)
    instance_tags           = optional(map(string), {})
    volume_tags             = optional(map(string), {})
    auto_recovery           = optional(bool, true)
    license_configurations  = optional(list(string), [])
    detailed_monitoring     = optional(bool, true)
    cpu_credits             = optional(string, null)
    nitro_enclaves          = optional(bool, false)
    hibernation_enabled     = optional(bool, false)
    security_groups         = optional(list(string), [])
    network_interfaces = optional(list(
      object({
        description                  = string
        device_index                 = optional(number)
        network_card_index           = optional(number)
        network_interface_id         = optional(string)
        private_ip_address           = optional(string)
        security_groups              = optional(list(string), [])
        subnet_id                    = optional(string)
        delete_on_termination        = optional(bool)
        interface_type               = optional(string)
        associate_carrier_ip_address = optional(string)
        associate_public_ip_address  = optional(string)
        ipv4_addresses               = optional(list(string), [])
        ipv4_address_count           = optional(number)
        ipv4_prefixes                = optional(list(string), [])
        ipv4_prefix_count            = optional(number)
        ipv6_addresses               = optional(list(string), [])
        ipv6_address_count           = optional(number)
        ipv6_prefixes                = optional(list(string), [])
        ipv6_prefix_count            = optional(number)
      })
    ), [])
  })
  default     = null
  description = <<-EOT
    A map of launch template configuration, all arguments are optional, see type argument for expected type. Only used if `create_launch_template` is `true`. For greater detail of values, see [launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#argument-reference). Available arguments:
    <pre>launch_template_config = {
      instance_type                 = The type of the instance. Default is "t3.micro".
      instance_profile              = An IAM profile to attach to the instance. Default is "eec-aws-amifactory-sc-iam-ec2role".
      ebs_optimized                 = The launched EC2 instance will be EBS-optimized, defaults to "true".
      user_data                     = The Base64-encoded user data to provide when launching the instance.
      ssh_key_pair                  = SSH key pair to be provisioned on the instance.
      default_version               = Default Version of the launch template. Conflicts with update_default_version.
      update_default_version        = If "true", update Default Version each update. Conflicts with default_version.
      disable_api_termination       = If "true", enables EC2 Instance Termination Protection
      disable_api_stop              = If "true", enables EC2 Instance Stop Protection.
      shutdown_behavior             = Shutdown behavior for the instance, can be "stop" or "terminate". If spot instances are configured to terminate, is is mandatory to also set this value to "terminate". 
      kernel_id                     = The kernel ID.
      ram_disk_id                   = The ID of the RAM disk.
      instance_tags                 = Map of additional instance tags.
      volume_tags                   = Map of additional volume tags.
      auto_recovery                 = If "false", disables automatic recovery of the instance.
      license_configurations        = A list of license configuration ARNs to associate.
      detailed_monitoring           = Enable detailed monitoring, defaults to "true".
      cpu_credits                   = The credit option for CPU usage. T3 instances are "unlimited" by default, T2 as "standard".
      nitro_enclaves                = If set to "true", [Nitro Enclaves](https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave.html) will be enabled on the instance.
      hibernation_enabled           = If set to "true", the launched EC2 instance will hibernation enabled.
      security_groups               = A list of security group IDs to associate. Overridden if "launch_template_config.network_interfaces" is also supplied.
      network_interfaces            = A list of network interface maps to be attached at instance boot time. Will override "launch_template_config.security_groups". See [Network Interfaces](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#network-interfaces).
    }</pre>
    EOT
}

variable "lifecycle_hooks" {
  type = list(object({
    name                    = string
    default_result          = optional(string)
    heartbeat_timeout       = optional(number)
    lifecycle_transition    = optional(string)
    notification_metadata   = optional(string)
    notification_target_arn = optional(string)
    role_arn                = optional(string)
  }))
  default     = []
  description = "List of one or more lifecycle hook maps to attach to the ASG. See [Lifecycle Hook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook)"
}

variable "max_instance_lifetime" {
  type        = number
  default     = null
  description = "The maximum amount of time, in seconds, that an instance can be in service"

  validation {
    condition = (
      var.max_instance_lifetime == null ? true : (
        (var.max_instance_lifetime >= 86400 && var.max_instance_lifetime <= 31536000) || var.max_instance_lifetime == 0
      )
    )
    error_message = "max_instance_lifetime must be either equal to 0 or between 86400 and 31536000 seconds"
  }
}

variable "max_size" {
  type        = number
  default     = null
  description = "The maximum size of the auto scaling group. Required unless `create_autoscaling_group` is `false`"
}

variable "metadata_options" {
  type = object({
    http_endpoint               = optional(string, "enabled")
    http_tokens                 = optional(string, "required")
    http_put_response_hop_limit = optional(number, 1)
    http_protocol_ipv6          = optional(string)
    instance_metadata_tags      = optional(string, "disabled")
  })
  default     = {}
  description = "Customize the metadata options for the instance, will default to being `enabled`. See [Metadata Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#metadata-options). Only used if `create_launch_template` is `true`"
}

variable "min_size" {
  type        = number
  default     = null
  description = "The minimum size of the autoscaling group. Required unless `create_autoscaling_group` is `false`"
}

variable "name" {
  type        = string
  description = "Name of resources to be created. The actual resource name will be created as `{name_prefix}-{name}-{type}` in accordance with the [EEC Cloud Naming Conventions](https://pages.experian.com/display/SC/Cloud+Naming+Conventions+or+Constructs)"
}

variable "name_prefix" {
  type        = string
  default     = null
  description = "Used to prefix all created resources. If left `null`, a prefix will be automatically calculated based on account name in accordance with the [EEC Cloud Naming Conventions](https://pages.experian.com/display/SC/Cloud+Naming+Conventions+or+Constructs)"
}

variable "network_interfaces" {
  type = list(object({
    description                  = string
    device_index                 = optional(number)
    network_card_index           = optional(number)
    network_interface_id         = optional(string)
    private_ip_address           = optional(string)
    security_groups              = optional(list(string))
    subnet_id                    = optional(string)
    delete_on_termination        = optional(bool)
    interface_type               = optional(string)
    associate_carrier_ip_address = optional(string)
    associate_public_ip_address  = optional(string)
    ipv4_addresses               = optional(list(string))
    ipv4_address_count           = optional(number)
    ipv4_prefixes                = optional(list(string))
    ipv4_prefix_count            = optional(number)
    ipv6_addresses               = optional(list(string))
    ipv6_address_count           = optional(number)
    ipv6_prefixes                = optional(list(string))
    ipv6_prefix_count            = optional(number)
  }))
  default     = []
  description = "The same functionality as `launch_template_config.network_interfaces`, kept for backwards compatibility. This variable may be depreciated in future releases"
}

variable "network_performance_options" {
  type = object({
    bandwidth_weighting = optional(string, "default")
  })
  default     = {}
  description = "Configure network performance options for the instance. `bandwidth_weighting` configures EBS-optimized throughput vs. network bandwidth weighting. Valid values: `default`, `vpc-1`, `ebs-1`. Note: only certain instance types support this feature. The AWS API will reject unsupported combinations at Auto Scaling Group creation time with a clear error. See [Network Performance Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#network-performance-options) and [AWS Docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-bandwidth-weighting.html) for supported instance types. Only used if `create_launch_template` is `true`"

  validation {
    condition     = contains(["default", "vpc-1", "ebs-1"], var.network_performance_options.bandwidth_weighting)
    error_message = "bandwidth_weighting must be one of: 'default', 'vpc-1', 'ebs-1'."
  }
}

variable "placement" {
  type = object({
    affinity                = optional(string)
    availability_zone       = optional(string)
    group_name              = optional(string)
    host_id                 = optional(string)
    host_resource_group_arn = optional(string)
    spread_domain           = optional(string)
    tenancy                 = optional(string)
    partition_number        = optional(number)
  })
  default     = null
  description = "The placement of the instance. See [Placement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#placement). Only used if `create_launch_template` is `true`"
}

variable "placement_group" {
  description = "The name of the placement group into which you'll launch your instances, if any. See [AWS Docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html)"
  type        = string
  default     = null
}

variable "private_dns_name_options" {
  type = object({
    enable_resource_name_dns_aaaa_record = optional(bool)
    enable_resource_name_dns_a_record    = optional(bool)
    hostname_type                        = optional(string)
  })
  default     = null
  description = "The options for the instance hostname. See [Private DNS Name Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#private-dns-name-options). Only used if `create_launch_template` is `true`"
}

variable "protect_from_scale_in" {
  type        = bool
  default     = false
  description = "Allows setting instance protection. The autoscaling group will not select instances with this setting for termination during scale in events"
}

variable "root_block_device" {
  type = object({
    delete_on_termination = optional(bool)
    encrypted             = optional(bool)
    kms_key_id            = optional(string)
    iops                  = optional(number)
    throughput            = optional(number)
    snapshot_id           = optional(string)
    volume_size           = optional(number)
    volume_type           = optional(string)
  })
  default     = null
  description = "Map to customize the root block device of the instance. See [Root Block Devices](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#ebs-ephemeral-and-root-block-devices). Only used if `create_launch_template` is `true`"
}

variable "scaling_policies" {
  type = list(object({
    name                      = string
    enabled                   = optional(bool)
    adjustment_type           = optional(string)
    policy_type               = optional(string)
    estimated_instance_warmup = optional(number)
    cooldown                  = optional(number)
    min_adjustment_magnitude  = optional(number)
    metric_aggregation_type   = optional(string)
    scaling_adjustment        = optional(number)
    step_adjustment = optional(list(object({
      scaling_adjustment          = optional(number)
      metric_interval_lower_bound = optional(number)
      metric_interval_upper_bound = optional(number)
    })))
    target_tracking_configuration = optional(object({
      target_value     = optional(number)
      disable_scale_in = optional(bool)
      predefined_metric_specification = optional(object({
        predefined_metric_type = optional(string)
        resource_label         = optional(string)
      }))
      customized_metric_specification = optional(object({
        metric_name = optional(string)
        namespace   = optional(string)
        statistic   = optional(string)
        unit        = optional(string)
        metric_dimension = optional(object({
          name  = optional(string)
          value = optional(string)
        }))
        metrics = optional(list(object({
          id          = optional(string)
          expression  = optional(string)
          label       = optional(string)
          return_data = optional(bool)
          metric_stat = optional(object({
            stat = optional(string)
            unit = optional(string)
            metric = optional(object({
              metric_name = optional(string)
              namespace   = optional(string)
              dimensions = optional(list(object({
                name  = optional(string)
                value = optional(string)
              })))
            }))
          }))
        })))
      }))
    }))
    predictive_scaling_configuration = optional(object({
      max_capacity_breach_behavior = optional(string)
      max_capacity_buffer          = optional(number)
      mode                         = optional(string)
      scheduling_buffer_time       = optional(number)
      metric_specification = optional(object({
        target_value = optional(number)
        predefined_load_metric_specification = optional(object({
          predefined_metric_type = optional(string)
          resource_label         = optional(string)
        }))
        predefined_metric_pair_specification = optional(object({
          predefined_metric_type = optional(string)
          resource_label         = optional(string)
        }))
        predefined_scaling_metric_specification = optional(object({
          predefined_metric_type = optional(string)
          resource_label         = optional(string)
        }))
      }))
    }))
  }))
  default     = []
  description = "List of target scaling policies to create. See [AutoScaling Scaling Policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy#argument-reference)"
}

variable "schedules" {
  type = list(object({
    action_name      = string
    min_size         = optional(number)
    max_size         = optional(number)
    desired_capacity = optional(number)
    start_time       = optional(string)
    end_time         = optional(string)
    time_zone        = optional(string)
    recurrence       = optional(string)
  }))
  default     = []
  description = "List of autoscaling group schedules to create. See [AutoScaling Schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_schedule#argument-reference)"
}

variable "security_groups" {
  type        = list(string)
  default     = []
  description = "The same functionality as `launch_template_config.security_groups`, kept for backwards compatibility. This variable may be depreciated in future releases"
}

variable "suspended_processes" {
  type        = list(string)
  default     = []
  description = "A list of processes to suspend for the Auto Scaling Group. The allowed values are `HealthCheck`, `ReplaceUnhealthy`, `AZRebalance`, `AlarmNotification`, `ScheduledActions`, `AddToLoadBalancer`, `InstanceRefresh`"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://pages.experian.com/pages/viewpage.action?pageId=400041906) for available tags"
}

variable "target_group_arns" {
  type        = list(string)
  default     = []
  description = "List of ARNs of load balancer target groups to attach to the auto scaling group"
}

variable "termination_policies" {
  type        = list(string)
  default     = []
  description = "A list of policies to decide how the instances in the Auto Scaling Group should be terminated. The allowed values are `OldestInstance`, `NewestInstance`, `OldestLaunchConfiguration`, `ClosestToNextInstanceHour`, `OldestLaunchTemplate`, `AllocationStrategy`, `Default`"
}

variable "subnet_ids" {
  type        = list(string)
  default     = []
  description = "A list of subnet IDs to launch resources in. Subnets automatically determine which availability zones the group will reside. Required unless subnet is specified in the launch template"
}

variable "wait_for_capacity_timeout" {
  type        = string
  default     = null
  description = "A maximum duration that Terraform should wait for ASG instances to be healthy before timing out. Setting this to '0' causes Terraform to skip all Capacity Waiting behavior"
}

variable "warm_pool" {
  type = object({
    instance_reuse_policy       = optional(map(string))
    max_group_prepared_capacity = optional(number)
    min_size                    = optional(number)
    pool_state                  = optional(string)
  })
  default     = null
  description = "Add a Warm Pool to the ASG. See [Warm Pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#warm_pool)"
}

variable "availability_zone_distribution" {
  type = object({
    capacity_distribution_strategy = optional(string)
  })
  default     = null
  description = <<EOT
  The instance capacity distribution across Availability Zones.
  `capacity_distribution_strategy` - The strategy to use for distributing capacity across the Availability Zones. 
  Valid values are `balanced-only` and `balanced-best-effort`. Default is `balanced-best-effort`.
  See [TF Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#availability_zone_distribution-1) and [AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-availability-zone-balanced.html) for further information.
  EOT
}

variable "disable_default_alarms" {
  type        = bool
  default     = false
  description = "To disable the best practice AWS alarms for EC2 ASGs outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#AutoScaling)"
}

variable "alarm_sns_topics" {
  type        = list(string)
  default     = []
  description = "List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions"
}

variable "enable_all_alarm_actions" {
  type        = bool
  description = "Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions"
  default     = false
}

variable "cloudwatch_tags" {
  type        = map(string)
  default     = {}
  description = "Cloudwatch Alarm tags. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags"
}
