module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-autoscaling"
  tags        = var.tags
}

# create auto scaling group
resource "aws_autoscaling_group" "this" {
  count = var.create_autoscaling_group ? 1 : 0

  name                      = format("%s-%s-asg", local.name_prefix, var.name)
  vpc_zone_identifier       = length(var.subnet_ids) > 0 ? var.subnet_ids : null
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  desired_capacity_type     = var.desired_capacity_type
  capacity_rebalance        = var.capacity_rebalance
  wait_for_capacity_timeout = var.wait_for_capacity_timeout
  default_cooldown          = var.default_cooldown
  default_instance_warmup   = var.default_instance_warmup
  protect_from_scale_in     = var.protect_from_scale_in
  placement_group           = var.placement_group
  health_check_type         = var.health_check_type
  health_check_grace_period = var.health_check_grace_period
  termination_policies      = var.termination_policies
  suspended_processes       = var.suspended_processes
  max_instance_lifetime     = var.max_instance_lifetime
  service_linked_role_arn   = var.existing_service_linked_role_arn == null ? aws_iam_service_linked_role.this[0].arn : var.existing_service_linked_role_arn

  # enable alarm metrics
  enabled_metrics = concat(var.disable_default_alarms != true ? ["GroupInServiceCapacity"] : [], var.enabled_metrics)

  # use created launch template if required
  launch_template {
    id      = var.create_launch_template ? aws_launch_template.this[0].id : lookup(var.existing_launch_template, "id", null)
    version = var.create_launch_template ? aws_launch_template.this[0].latest_version : lookup(var.existing_launch_template, "version", null)
  }

  # maintenance policy
  dynamic "instance_maintenance_policy" {
    for_each = var.instance_maintenance_policy != null ? [var.instance_maintenance_policy] : []

    content {
      min_healthy_percentage = try(instance_maintenance_policy.value.min_healthy_percentage, null)
      max_healthy_percentage = try(instance_maintenance_policy.value.max_healthy_percentage, null)
    }
  }

  # instance refresh
  dynamic "instance_refresh" {
    for_each = var.instance_refresh != null ? [var.instance_refresh] : []

    content {
      strategy = try(instance_refresh.value.strategy, "Rolling")
      triggers = try(instance_refresh.value.triggers, null)

      dynamic "preferences" {
        for_each = try([instance_refresh.value.preferences], [])

        content {
          checkpoint_delay             = try(preferences.value.checkpoint_delay, null)
          checkpoint_percentages       = try(preferences.value.checkpoint_percentages, null)
          instance_warmup              = try(preferences.value.instance_warmup, null)
          max_healthy_percentage       = try(preferences.value.max_healthy_percentage, null)
          min_healthy_percentage       = try(preferences.value.min_healthy_percentage, null)
          skip_matching                = try(preferences.value.skip_matching, null)
          auto_rollback                = try(preferences.value.auto_rollback, null)
          scale_in_protected_instances = try(preferences.value.scale_in_protected_instances, null)
          standby_instances            = try(preferences.value.standby_instances, null)
          dynamic "alarm_specification" {
            for_each = try([preferences.value.alarm_specification], [])
            content {
              alarms = try(alarm_specification.value.alarms, null)
            }
          }
        }
      }
    }
  }

  # warm pool
  dynamic "warm_pool" {
    for_each = var.warm_pool != null ? [var.warm_pool] : []

    content {
      pool_state                  = try(warm_pool.value.pool_state, null)
      min_size                    = try(warm_pool.value.min_size, null)
      max_group_prepared_capacity = try(warm_pool.value.max_group_prepared_capacity, null)

      dynamic "instance_reuse_policy" {
        for_each = try([warm_pool.value.instance_reuse_policy], [])

        content {
          reuse_on_scale_in = try(instance_reuse_policy.value.reuse_on_scale_in, null)
        }
      }
    }
  }

  dynamic "availability_zone_distribution" {
    for_each = var.availability_zone_distribution != null ? [var.availability_zone_distribution] : []

    content {
      capacity_distribution_strategy = try(availability_zone_distribution.value.capacity_distribution_strategy, null)
    }
  }

  # set tags for created resources
  dynamic "tag" {
    for_each = local.asg_tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  depends_on = [time_sleep.wait_for_role]
}

# attach elb target group if required
resource "aws_autoscaling_attachment" "this" {
  for_each = var.create_autoscaling_group ? toset(var.target_group_arns) : []

  autoscaling_group_name = aws_autoscaling_group.this[0].id
  lb_target_group_arn    = each.value
}

# attach autoscaling lifecycle hook if required
resource "aws_autoscaling_lifecycle_hook" "this" {
  for_each = var.create_autoscaling_group ? { for hook in var.lifecycle_hooks : hook.name => hook } : {}

  name                    = each.value.name
  autoscaling_group_name  = aws_autoscaling_group.this[0].name
  default_result          = lookup(each.value, "default_result", null)
  heartbeat_timeout       = lookup(each.value, "heartbeat_timeout", null)
  lifecycle_transition    = lookup(each.value, "lifecycle_transition", null)
  notification_metadata   = lookup(each.value, "notification_metadata", null)
  notification_target_arn = lookup(each.value, "notification_target_arn", null)
  role_arn                = lookup(each.value, "role_arn", null)
}

# create schedule if required
resource "aws_autoscaling_schedule" "this" {
  for_each = var.create_autoscaling_group ? { for schedule in var.schedules : schedule.action_name => schedule } : {}

  scheduled_action_name  = each.value.action_name
  autoscaling_group_name = aws_autoscaling_group.this[0].name

  min_size         = try(each.value.min_size, null)
  max_size         = try(each.value.max_size, null)
  desired_capacity = try(each.value.desired_capacity, null)
  start_time       = try(each.value.start_time, null)
  end_time         = try(each.value.end_time, null)
  time_zone        = try(each.value.time_zone, null)
  recurrence       = try(each.value.recurrence, null)
}

# create security grpup
module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git?ref=3.5.1"
  count  = var.create_security_group != null ? 1 : 0

  security_group_name          = var.create_security_group.name != null ? var.create_security_group.name : var.name
  security_group_description   = "Security group for auto scaling group ${local.name_prefix}-${var.name}-asg"
  vpc_id                       = var.create_security_group.vpc_id
  ec2_agent_rules              = var.create_security_group.agent_rules
  security_group_ingress_rules = var.create_security_group.ingress_rules
  security_group_egress_rules  = var.create_security_group.egress_rules

  tags = merge(local.tags, var.create_security_group.tags, { "eitsce:parentmodule" = "eits-tf-aws-autoscaling" })
}

# create launch template
resource "aws_launch_template" "this" {
  count = var.create_launch_template ? 1 : 0

  name                    = format("%s-%s-lt", local.name_prefix, var.name)
  description             = "Launch template for auto scaling group ${local.name_prefix}-${var.name}-asg"
  image_id                = local.ami_id
  ebs_optimized           = lookup(var.launch_template_config, "ebs_optimized", true)
  instance_type           = lookup(var.launch_template_config, "instance_type", null)
  key_name                = lookup(var.launch_template_config, "ssh_key_pair", null)
  user_data               = lookup(var.launch_template_config, "user_data", null)
  default_version         = lookup(var.launch_template_config, "default_version", null)
  update_default_version  = lookup(var.launch_template_config, "update_default_version", null)
  disable_api_termination = lookup(var.launch_template_config, "disable_api_termination", null)
  disable_api_stop        = lookup(var.launch_template_config, "disable_api_stop", null)
  kernel_id               = lookup(var.launch_template_config, "kernel_id", null)
  ram_disk_id             = lookup(var.launch_template_config, "ram_disk_id", null)

  instance_initiated_shutdown_behavior = lookup(var.launch_template_config, "shutdown_behavior", null)

  # networking
  vpc_security_group_ids = length(local.network_interfaces) > 0 ? [] : local.security_groups

  # instance profile
  iam_instance_profile {
    name = lookup(var.launch_template_config, "instance_profile", "eec-aws-amifactory-sc-iam-ec2role")
  }

  # instance tags
  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.tags, lookup(var.launch_template_config, "instance_tags", {}))
  }

  # volume tags
  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.tags, lookup(var.launch_template_config, "volume_tags", {}))
  }

  # detailed monitoring
  monitoring {
    enabled = lookup(var.launch_template_config, "detailed_monitoring", true)
  }

  # auto recovery
  maintenance_options {
    auto_recovery = lookup(var.launch_template_config, "auto_recovery", true) ? "default" : "disabled"
  }

  # nitro enclaves 
  enclave_options {
    enabled = lookup(var.launch_template_config, "nitro_enclaves", false)
  }

  # hibernation
  hibernation_options {
    configured = lookup(var.launch_template_config, "hibernation_enabled", false)
  }

  # metadata
  metadata_options {
    http_endpoint               = lookup(var.metadata_options, "http_endpoint", "enabled")
    http_tokens                 = lookup(var.metadata_options, "http_tokens", "required")
    http_put_response_hop_limit = lookup(var.metadata_options, "http_put_response_hop_limit", 1)
    http_protocol_ipv6          = lookup(var.metadata_options, "http_protocol_ipv6", null)
    instance_metadata_tags      = lookup(var.metadata_options, "instance_metadata_tags", "disabled")
  }

  # cpu credits
  dynamic "credit_specification" {
    for_each = lookup(var.launch_template_config, "cpu_credits", null) != null ? [lookup(var.launch_template_config, "cpu_credits", null)] : []

    content {
      cpu_credits = credit_specification.value
    }
  }

  # license specification
  dynamic "license_specification" {
    for_each = lookup(var.launch_template_config, "license_configurations", [])

    content {
      license_configuration_arn = license_specification.value
    }
  }

  # network_interfaces
  dynamic "network_interfaces" {
    for_each = { for interface in local.network_interfaces : interface.description => interface }

    content {
      description                  = network_interfaces.value.description
      associate_carrier_ip_address = try(network_interfaces.value.associate_carrier_ip_address, "")
      associate_public_ip_address  = try(network_interfaces.value.associate_public_ip_address, "")
      delete_on_termination        = try(network_interfaces.value.delete_on_termination, "")
      device_index                 = try(network_interfaces.value.device_index, null)
      interface_type               = try(network_interfaces.value.interface_type, null)
      ipv4_prefix_count            = try(network_interfaces.value.ipv4_prefix_count, null)
      ipv4_prefixes                = try(network_interfaces.value.ipv4_prefixes, [])
      ipv4_addresses               = try(network_interfaces.value.ipv4_addresses, [])
      ipv4_address_count           = try(network_interfaces.value.ipv4_address_count, null)
      ipv6_prefix_count            = try(network_interfaces.value.ipv6_prefix_count, null)
      ipv6_prefixes                = try(network_interfaces.value.ipv6_prefixes, [])
      ipv6_addresses               = try(network_interfaces.value.ipv6_addresses, [])
      ipv6_address_count           = try(network_interfaces.value.ipv6_address_count, null)
      network_interface_id         = try(network_interfaces.value.network_interface_id, null)
      network_card_index           = try(network_interfaces.value.network_card_index, null)
      private_ip_address           = try(network_interfaces.value.private_ip_address, null)
      security_groups              = compact(concat(try(network_interfaces.value.security_groups, []), local.security_groups))
      subnet_id                    = try(network_interfaces.value.subnet_id, null)
    }
  }

  # root and volume block device mappings
  dynamic "block_device_mappings" {
    for_each = { for device in local.block_device_mappings : device.device_name => device }

    content {
      device_name  = block_device_mappings.value.device_name
      no_device    = try(block_device_mappings.value.no_device, null)
      virtual_name = try(block_device_mappings.value.virtual_name, null)

      dynamic "ebs" {
        for_each = flatten([try(block_device_mappings.value.ebs, [])])
        content {
          delete_on_termination = try(ebs.value.delete_on_termination, "")
          encrypted             = try(ebs.value.encrypted, "")
          kms_key_id            = try(ebs.value.kms_key_id, null)
          iops                  = try(ebs.value.iops, null)
          throughput            = try(ebs.value.throughput, null)
          snapshot_id           = try(ebs.value.snapshot_id, null)
          volume_size           = try(ebs.value.volume_size, null)
          volume_type           = try(ebs.value.volume_type, null)
        }
      }
    }
  }

  # capacity reservation specification
  dynamic "capacity_reservation_specification" {
    for_each = var.capacity_reservation_specification != null ? [var.capacity_reservation_specification] : []
    content {
      capacity_reservation_preference = try(capacity_reservation_specification.value.capacity_reservation_preference, null)

      dynamic "capacity_reservation_target" {
        for_each = try([capacity_reservation_specification.value.capacity_reservation_target], [])
        content {
          capacity_reservation_id                 = try(capacity_reservation_target.value.capacity_reservation_id, null)
          capacity_reservation_resource_group_arn = try(capacity_reservation_target.value.capacity_reservation_resource_group_arn, null)
        }
      }
    }
  }

  # cpu options
  dynamic "cpu_options" {
    for_each = var.cpu_options != null ? [var.cpu_options] : []
    content {
      core_count       = cpu_options.value.core_count
      threads_per_core = cpu_options.value.threads_per_core
    }
  }

  # instance market options
  dynamic "instance_market_options" {
    for_each = var.instance_market_options != null ? [var.instance_market_options] : []
    content {
      market_type = instance_market_options.value.market_type

      dynamic "spot_options" {
        for_each = try([instance_market_options.value.spot_options], [])
        content {
          instance_interruption_behavior = try(spot_options.value.instance_interruption_behavior, null)
          max_price                      = try(spot_options.value.max_price, null)
          spot_instance_type             = try(spot_options.value.spot_instance_type, null)
          valid_until                    = try(spot_options.value.valid_until, null)
        }
      }
    }
  }

  # placement
  dynamic "placement" {
    for_each = var.placement != null ? [var.placement] : []
    content {
      affinity                = try(placement.value.affinity, null)
      availability_zone       = try(placement.value.availability_zone, null)
      group_name              = try(placement.value.group_name, null)
      host_id                 = try(placement.value.host_id, null)
      host_resource_group_arn = try(placement.value.host_resource_group_arn, null)
      spread_domain           = try(placement.value.spread_domain, null)
      tenancy                 = try(placement.value.tenancy, null)
      partition_number        = try(placement.value.partition_number, null)
    }
  }

  # network performance options
  network_performance_options {
    bandwidth_weighting = var.network_performance_options.bandwidth_weighting
  }

  # private dns name options
  dynamic "private_dns_name_options" {
    for_each = var.private_dns_name_options != null ? [var.private_dns_name_options] : []
    content {
      enable_resource_name_dns_aaaa_record = try(private_dns_name_options.value.enable_resource_name_dns_aaaa_record, null)
      enable_resource_name_dns_a_record    = try(private_dns_name_options.value.enable_resource_name_dns_a_record, null)
      hostname_type                        = try(private_dns_name_options.value.hostname_type, null)
    }
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = local.tags
}

# create service linked role if non supplied
resource "aws_iam_service_linked_role" "this" {
  count = var.create_autoscaling_group && var.existing_service_linked_role_arn == null ? 1 : 0

  aws_service_name = "autoscaling.amazonaws.com"
  description      = "A service linked role for autoscaling"
  custom_suffix    = var.name
}

# wait for role to be provisioned otherwise we get an error
resource "time_sleep" "wait_for_role" {
  count = var.create_autoscaling_group && var.existing_service_linked_role_arn == null ? 1 : 0

  depends_on      = [aws_iam_service_linked_role.this]
  create_duration = "10s"
}

# grant access to eec ami kms keys to service linked roles
# will only be created if var.ami is not null, and is an EEC ami
data "aws_region" "current" {}
resource "aws_kms_grant" "this" {
  count = var.ami == null ? 0 : var.create_autoscaling_group && length(regexall("eec_aws_", data.aws_ami.current[0].name)) > 0 ? 1 : 0

  name              = "GrantAutoScalingRoleAccessToAMI"
  key_id            = local.exp_ami_kms_key[data.aws_region.current.region]
  grantee_principal = var.existing_service_linked_role_arn == null ? aws_iam_service_linked_role.this[0].arn : var.existing_service_linked_role_arn
  operations = [
    "Encrypt",
    "Decrypt",
    "ReEncryptFrom",
    "ReEncryptTo",
    "GenerateDataKey",
    "GenerateDataKeyWithoutPlaintext",
    "DescribeKey",
    "CreateGrant"
  ]

  depends_on = [time_sleep.wait_for_role]
}

# create autoscaling Policy if required
resource "aws_autoscaling_policy" "this" {
  for_each = var.create_autoscaling_group ? { for policy in var.scaling_policies : policy.name => policy } : {}

  name                   = each.value.name
  autoscaling_group_name = aws_autoscaling_group.this[0].name

  enabled                   = try(each.value.enabled, true)
  adjustment_type           = try(each.value.adjustment_type, null)
  policy_type               = try(each.value.policy_type, null)
  estimated_instance_warmup = try(each.value.estimated_instance_warmup, null)
  cooldown                  = try(each.value.cooldown, null)
  min_adjustment_magnitude  = try(each.value.min_adjustment_magnitude, null)
  metric_aggregation_type   = try(each.value.metric_aggregation_type, null)
  scaling_adjustment        = try(each.value.scaling_adjustment, null)

  dynamic "step_adjustment" {
    for_each = each.value.step_adjustment != null ? each.value.step_adjustment : []
    content {
      scaling_adjustment          = step_adjustment.value.scaling_adjustment
      metric_interval_lower_bound = try(step_adjustment.value.metric_interval_lower_bound, null)
      metric_interval_upper_bound = try(step_adjustment.value.metric_interval_upper_bound, null)
    }
  }

  dynamic "target_tracking_configuration" {
    for_each = each.value.target_tracking_configuration != null ? [each.value.target_tracking_configuration] : []
    content {
      target_value     = target_tracking_configuration.value.target_value
      disable_scale_in = try(target_tracking_configuration.value.disable_scale_in, null)

      dynamic "predefined_metric_specification" {
        for_each = target_tracking_configuration.value.predefined_metric_specification != null ? [target_tracking_configuration.value.predefined_metric_specification] : []
        content {
          predefined_metric_type = predefined_metric_specification.value.predefined_metric_type
          resource_label         = try(predefined_metric_specification.value.resource_label, null)
        }
      }

      dynamic "customized_metric_specification" {
        for_each = target_tracking_configuration.value.customized_metric_specification != null ? [target_tracking_configuration.value.customized_metric_specification] : []

        content {
          dynamic "metric_dimension" {
            for_each = customized_metric_specification.value.metric_dimension != null ? [customized_metric_specification.value.metric_dimension] : []

            content {
              name  = metric_dimension.value.name
              value = metric_dimension.value.value
            }
          }

          metric_name = try(customized_metric_specification.value.metric_name, null)

          dynamic "metrics" {
            for_each = customized_metric_specification.value.metrics != null ? customized_metric_specification.value.metrics : []

            content {
              expression = try(metrics.value.expression, null)
              id         = metrics.value.id
              label      = try(metrics.value.label, null)

              dynamic "metric_stat" {
                for_each = metrics.value.metric_stat != null ? [metrics.value.metric_stat] : []

                content {
                  dynamic "metric" {
                    for_each = metric_stat.value.metric != null ? [metric_stat.value.metric] : []

                    content {
                      dynamic "dimensions" {
                        for_each = metric.value.dimensions != null ? metric.value.dimensions : []

                        content {
                          name  = dimensions.value.name
                          value = dimensions.value.value
                        }
                      }

                      metric_name = metric.value.metric_name
                      namespace   = metric.value.namespace
                    }
                  }

                  stat = metric_stat.value.stat
                  unit = try(metric_stat.value.unit, null)
                }
              }

              return_data = try(metrics.value.return_data, null)
            }
          }

          namespace = try(customized_metric_specification.value.namespace, null)
          statistic = try(customized_metric_specification.value.statistic, null)
          unit      = try(customized_metric_specification.value.unit, null)
        }
      }
    }
  }

  dynamic "predictive_scaling_configuration" {
    for_each = each.value.predictive_scaling_configuration != null ? [each.value.predictive_scaling_configuration] : []
    content {
      max_capacity_breach_behavior = try(predictive_scaling_configuration.value.max_capacity_breach_behavior, null)
      max_capacity_buffer          = try(predictive_scaling_configuration.value.max_capacity_buffer, null)
      mode                         = try(predictive_scaling_configuration.value.mode, null)
      scheduling_buffer_time       = try(predictive_scaling_configuration.value.scheduling_buffer_time, null)

      dynamic "metric_specification" {
        for_each = predictive_scaling_configuration.value.metric_specification != null ? [predictive_scaling_configuration.value.metric_specification] : []
        content {
          target_value = metric_specification.value.target_value

          dynamic "predefined_load_metric_specification" {
            for_each = metric_specification.value.predefined_load_metric_specification != null ? [metric_specification.value.predefined_load_metric_specification] : []
            content {
              predefined_metric_type = predefined_load_metric_specification.value.predefined_metric_type
              resource_label         = predefined_load_metric_specification.value.resource_label
            }
          }

          dynamic "predefined_metric_pair_specification" {
            for_each = metric_specification.value.predefined_metric_pair_specification != null ? [metric_specification.value.predefined_metric_pair_specification] : []
            content {
              predefined_metric_type = predefined_metric_pair_specification.value.predefined_metric_type
              resource_label         = predefined_metric_pair_specification.value.resource_label
            }
          }

          dynamic "predefined_scaling_metric_specification" {
            for_each = metric_specification.value.predefined_scaling_metric_specification != null ? [metric_specification.value.predefined_scaling_metric_specification] : []
            content {
              predefined_metric_type = predefined_scaling_metric_specification.value.predefined_metric_type
              resource_label         = predefined_scaling_metric_specification.value.resource_label
            }
          }
        }
      }
    }
  }
}
