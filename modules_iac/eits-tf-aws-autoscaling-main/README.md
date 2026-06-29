# EITS Cloud Enablement AWS EC2 Auto Scaling

EITS Terraform module to provision AWS EC2 Auto Scaling Groups (ASG) and Launch Templates.

- Automatically select the latest EEC-approved AMI based on the required OS
- Create AutoScaling Group (ASG)
- Create AutoScaling Service Linked Role
- Create KMS grant for AMI decryption, if EEC AMI
- Create launch template, by default
- Create AutoScaling Policies, if required
- Attach ELB target groups, if required
- Create AutoScaling schedule, if required
- Create CloudWatch alarms, by default
- Create Security Group and add to launch template, if required

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> **IMPORTANT:**
> Default alarms based on [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#AutoScaling) will be automatically created. This may incur an extra charge of $0.10 per month for each EC2 Auto Scaling Group. To disable the creation of these alarms, please set the variable `disable_default_alarms` to `true`.

## EITS Security & Compliance

**Last Module Review**: 2026-02-17

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-03-27 | 1.11.4 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-03-27 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-03-27 | 0.69.3 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-03-27 | 1.34.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Auto Scaling Resource Naming

This module attempts to adhere to the [EEC Cloud Naming Conventions](https://pages.experian.com/display/SC/Cloud+Naming+Conventions+or+Constructs):

```hcl
# Auto scaling groups
{account_naming_construct}-{'name' variable}-asg

# Launch templates
{account_naming_construct}-{'name' variable}-lt

# IAM service role
AWSServiceRoleForAutoScaling_{'name' variable}

# Security groups
{account_naming_construct}-{'name' variable}-sg
```

## Launch Templates, Launch Configurations amd Mixed Instances Policy

This module only supports the use of Launch Templates. Launch Configurations are deprecated as of 31st December 2022.

It does not currently support Mixed Instances Policies in order to launch multiple instance types.

## EEC and non-EEC AMIs

The launch template `ami` variable accepts either a specific ami id (e.g. "ami-*"), or one of the following EEC ami labels:

- windows_2019
- windows_2022
- amzn_lnx
- amzn_lnx_2023
- amzn_eks
- rhel_8
- rhel_9
- sles_15

Using one of those labels will automatically select the latest version of the EEC AMI.

The module will create a KMS grant for the AutoScaling Service Linked Role when using an EEC AMI. See [Building instances using AutoScaling Groups - Experian  Golden AMIs](https://pages.experian.local/display/SC/How+to+build+EC2+instances+using+the+Experian+Golden+AMIs#HowtobuildEC2instancesusingtheExperianGoldenAMIs-BuildinginstancesusingAutoScalingGroups-ExperianGoldenAMIs). Even if `create_launch_template` is `false`, it is worth populating `ami` when using an EEC AMI because of this. If `ami` is `null` the KMS grant will not be created.

Please note that if a custom AMI is used, and it has not been approved by EEC, the deployment will fail. In addition, if the AMI volume is encrypted you will need to create a grant for the KMS key separately to allow the AutoScaling Service Linked Role to decrypt it, see [aws_kms_grant](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_grant).

## Usage

### Create ASG, Launch Template, Schedules, and Instant Refresh

Example of a basic ASG and launch template with some configuration. There are many more options available, see Inputs  below.

```hcl
module "autoscaling" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-autoscaling.git"

    name       = "<name, see Naming above for details>"
    ami        = "<ami, see AMIs above for details>"
    min_size   = <number>
    max_size   = <number>
    subnet_ids = ["<list of subnet IDs>"]

    # create launch template
    launch_template_config = {
        instance_type          = "<size of instance>"
        security_groups        = ["<list of security group IDs>"]
        update_default_version = true
        instance_tags = {
            adDomain = "<AD domain>"
            adGroup  = "<AD group for centrify server access>"
        }
    }

    # add new EBS volume
    block_device_mappings = [
        {
            device_name = "<volume path>"
            ebs = {
                delete_on_termination = true
                volume_size           = <size in gb>
                volume_type           = "gp3"
            }
        }
    ]

    # example of instance refresh config
    instance_refresh = {
        strategy = "Rolling"
        preferences = {
            checkpoint_delay             = 600
            checkpoint_percentages       = [35, 70, 100]
            instance_warmup              = 300
            min_healthy_percentage       = 50
            auto_rollback                = true
            scale_in_protected_instances = "Refresh"
            standby_instances            = "Terminate"
        }
    }

    # example of a schedule to auto scale up and down
    schedules = [
        {
            action_name      = "scale_down"
            min_size         = 0
            max_size         = 0
            desired_capacity = 0
            recurrence       = "0 20 * * *" # 8pm
        },
        {
            action_name      = "scale_up"
            min_size         = 1
            max_size         = 2
            desired_capacity = 1
            recurrence       = "0 6 * * *" # 6am
        }
    ]

    tags = {
        Environment = <env>
        CostString  = <CostString>
        AppID       = <AppID>
    }
}
```


### Create ASG with Existing Launch Template

Using an existing launch template when creating the ASG:

```hcl
module "autoscaling" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-autoscaling.git"

    name       = "<name, see Naming above for details>"
    min_size   = <number>
    max_size   = <number>
    subnet_ids = ["<list of subnet IDs>"]

    # if this is an EEC AMI, we should pass the id even though we're not creating launch template
    # as the module will detect it as an EEC ami and create the KMS grant for us
    ami = "<ami ID>"

    # use existing template
    create_launch_template = false
    existing_launch_template = {
        id      = "<launch template id>"
        version = "<launch template version>"
    }

    tags = {
        Environment = <env>
        CostString  = <CostString>
        AppID       = <AppID>
    }
}
```

### Create ASG, Launch Template with Custom KMS Key

In order to encrypt the AMI volumes with a custom KMS key, you need to grant access to the autoscaling service role:

```hcl
module "kms_key" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

    ... other kms config (see tests directory for example) ...

    key_users = ["arn:aws:iam::${<account id>}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling_${<name variable>}"]
    key_service_users = ["arn:aws:iam::${<account id>}:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling_${<name variable>}"]

    tags = var.tags
}

module "autoscaling" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-autoscaling.git"

    name       = "<name, see Naming above for details>"
    ami        = "<ami, see AMIs above for details>"
    min_size   = <number>
    max_size   = <number>
    subnet_ids = ["<list of subnet IDs>"]

    # create launch template
    launch_template_config = {
        instance_type          = "<size of instance>"
        security_groups        = ["<list of security group IDs>"]
        update_default_version = true
        instance_tags = {
            adDomain = "<AD domain>"
            adGroup  = "<AD group for centrify server access>"
        }
    }

    # encrypt root volume with custom key
    root_block_device = {
        encrypted  = true
        kms_key_id = module.kms_key.key_arn
    }

    # add new EBS volume with custom key
    block_device_mappings = [
        {
            device_name = "/dev/sde"
            ebs = {
                encrypted             = true
                kms_key_id            = module.kms_key.key_arn
                delete_on_termination = true
                volume_size           = 30
                volume_type           = "gp3"
            }
        }
    ]

    tags = {
        Environment = <env>
        CostString  = <CostString>
        AppID       = <AppID>
    }
}
```

### Create ASG with Scaling Policies

The `scaling_policies` variable has a complex type structure, see Inputs section below for details. For greater details see [autoscaling_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy).

```hcl
module "autoscaling" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-autoscaling.git"

    name       = "<name, see Naming above for details>"
    ami        = "<ami, see AMIs above for details>"
    min_size   = <number>
    max_size   = <number>
    subnet_ids = ["<list of subnet IDs>"]

    # create launch template
    ... see above examples ...

    # a couple of examples of creating scaling policy
    # check below for scaling_policies variable type specification
    scaling_policies = [
        {
            name        = "CPU Tracking Policy"
            policy_type = "TargetTrackingScaling"
            target_tracking_configuration = {
                predefined_metric_specification = {
                    predefined_metric_type = "ASGAverageCPUUtilization"
                }
                target_value = 50.0
            }
        },
        {
            name                      = "Step Scaling Policy"
            policy_type               = "StepScaling"
            adjustment_type           = "PercentChangeInCapacity"
            estimated_instance_warmup = 300
            step_adjustment = [
                {
                    scaling_adjustment          = 20
                    metric_interval_lower_bound = 0
                    metric_interval_upper_bound = 5
                },
                {
                    scaling_adjustment          = 25
                    metric_interval_lower_bound = 5
                    metric_interval_upper_bound = 15
                },
                {
                    scaling_adjustment          = 50
                    metric_interval_lower_bound = 15
                }
            ]
        }
    ]

    tags = {
        Environment = <env>
        CostString  = <CostString>
        AppID       = <AppID>
    }
}
```

### Create ASG, Security Group and Launch Template

If the `create_security_group` map is provided, then a security group will be created and attached to the launch template automatically. Use `create_security_group.agent_rules` to add the standard set of EEC EC2 agent rules to the security group. See [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for more information on values.

```hcl
module "autoscaling" {
    source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-autoscaling.git"

    name     = "<name, see Naming above for details>"
    ami      = "<ami, see AMIs above for details>"
    min_size = <number>
    max_size = <number>

    # create security group with example rules
    create_security_group = {
        vpc_id        = "<vpc id, where the security group will be created>"
        agent_rules   = "either <linux> or <windows> to add EEC standard rules"
        ingress_rules = [
            {
                description = "Ping"
                from_port   = -1
                to_port     = -1
                protocol    = "icmp"
                cidr_blocks = ["10.0.0.0/8"]
            },
            {
                description = "Internal SSH"
                from_port   = 22
                to_port     = 22
                protocol    = "tcp"
                self        = true
            }
        ]
        egress_rules = [
            {
                description = "All Outbound"
                from_port   = 0
                to_port     = 0
                protocol    = "-1"
                cidr_blocks = ["10.0.0.0/8"]
            }
        ]
    }

    # create launch template
    ... see above examples ...

    tags = {
        Environment = <env>
        CostString  = <CostString>
        AppID       = <AppID>
    }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.32.1 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.9.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.32.1 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.9.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.0 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |
| <a name="module_security_group"></a> [security\_group](#module\_security\_group) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git | 3.5.1 |

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_attachment) | resource |
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_lifecycle_hook.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_autoscaling_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_autoscaling_schedule.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_schedule) | resource |
| [aws_iam_service_linked_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_service_linked_role) | resource |
| [aws_kms_grant.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_grant) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [time_sleep.wait_for_role](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_ami.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_amzn_eks_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_amzn_lnx_2023_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_amzn_lnx_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_rhel_8_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_rhel_9_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_sles_15_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_win_2019_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_win_2022_ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_default_tags.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions | `list(string)` | `[]` | no |
| <a name="input_ami"></a> [ami](#input\_ami) | The AMI from which to launch the instance. Accepts either either the AMI ID (ami-*) or one the EEC image labels (see README.md).<br/>Only used if `create_launch_template` is `true`.<br/>Note: terraform may throw an error if a resource output is provided for this variable. In which case deploy that first, and then use the aws\_ami data source to pass the AMI ID." | `string` | `null` | no |
| <a name="input_availability_zone_distribution"></a> [availability\_zone\_distribution](#input\_availability\_zone\_distribution) | The instance capacity distribution across Availability Zones.<br/>  `capacity_distribution_strategy` - The strategy to use for distributing capacity across the Availability Zones. <br/>  Valid values are `balanced-only` and `balanced-best-effort`. Default is `balanced-best-effort`.<br/>  See [TF Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#availability_zone_distribution-1) and [AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-availability-zone-balanced.html) for further information. | <pre>object({<br/>    capacity_distribution_strategy = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_block_device_mappings"></a> [block\_device\_mappings](#input\_block\_device\_mappings) | A list of volume maps to attach to the instance besides the volumes specified by the AMI. See [Block Devices](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#block-devices). Only used if `create_launch_template` is `true` | <pre>list(object({<br/>    device_name = string<br/>    ebs = optional(object({<br/>      delete_on_termination = optional(bool)<br/>      encrypted             = optional(bool)<br/>      kms_key_id            = optional(string)<br/>      iops                  = optional(number)<br/>      throughput            = optional(number)<br/>      snapshot_id           = optional(string)<br/>      volume_size           = optional(number)<br/>      volume_type           = optional(string)<br/>    }))<br/>    no_device    = optional(bool)<br/>    virtual_name = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_capacity_rebalance"></a> [capacity\_rebalance](#input\_capacity\_rebalance) | Indicates whether capacity rebalance is enabled | `bool` | `null` | no |
| <a name="input_capacity_reservation_specification"></a> [capacity\_reservation\_specification](#input\_capacity\_reservation\_specification) | Targeting for EC2 capacity reservations. See [Capacity Reservation Specification](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#capacity-reservation-specification). Only used if `create_launch_template` is `true` | <pre>object({<br/>    capacity_reservation_preference = optional(string)<br/>    capacity_reservation_target = optional(object({<br/>      capacity_reservation_id                 = optional(string)<br/>      capacity_reservation_resource_group_arn = optional(string)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_cloudwatch_tags"></a> [cloudwatch\_tags](#input\_cloudwatch\_tags) | Cloudwatch Alarm tags. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags | `map(string)` | `{}` | no |
| <a name="input_cpu_options"></a> [cpu\_options](#input\_cpu\_options) | The CPU options for the instance. See [CPU Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#cpu-options). Only used if `create_launch_template` is `true` | <pre>object({<br/>    amd_sev_snp      = optional(string)<br/>    core_count       = optional(number)<br/>    threads_per_core = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_create_autoscaling_group"></a> [create\_autoscaling\_group](#input\_create\_autoscaling\_group) | Determines whether to create an autoscaling group or not. Required for the majority of module functionality, but can be set to `false` to provision just a launch template, etc, if required. If `false` then the following functionality is also disabled: target group attachment, lifecycle hooks, scheduling, scaling policies, linked service role, and alarms | `bool` | `true` | no |
| <a name="input_create_launch_template"></a> [create\_launch\_template](#input\_create\_launch\_template) | Determines whether to create launch template or not. The auto scaling group will always use latest version of the created launch template. If `false` then `existing_launch_template` is required | `bool` | `true` | no |
| <a name="input_create_security_group"></a> [create\_security\_group](#input\_create\_security\_group) | Create a security group which will be added to the launch template automatically in addition to any other security groups specified. Usage:<br/><pre>create\_security\_group = {<br/>  name          = Name of security group, if omitted will use root "name" variable. Will be prefixed using [EEC Cloud Naming Conventions](https://pages.experian.local/display/SC/Cloud+Naming+Conventions+or+Constructs).<br/>  vpc\_id        = VPC ID where the security group will be created.<br/>  agent\_rules   = Valid values are "linux" or "windows". Add default EEC EC2 agent rules to the security group.<br/>  ingress\_rules = See type declaration fo expected variable, see [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for details.<br/>  ingress\_rules = See type declaration fo expected variable, see [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for details.<br/>  tags          = Additional tags for the security group. Merged with root "tags" variable.<br/>}</pre><br/>For greater detail on values please see [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse). | <pre>object({<br/>    name        = optional(string)<br/>    vpc_id      = string<br/>    agent_rules = optional(string)<br/>    ingress_rules = optional(list(object({<br/>      description      = optional(string)<br/>      from_port        = optional(number)<br/>      to_port          = optional(number)<br/>      protocol         = optional(string)<br/>      cidr_blocks      = optional(list(string))<br/>      ipv6_cidr_blocks = optional(list(string))<br/>      prefix_list_ids  = optional(list(string))<br/>      security_groups  = optional(list(string))<br/>      self             = optional(bool, false)<br/>      tags             = optional(map(string))<br/>    })), [])<br/>    egress_rules = optional(list(object({<br/>      description      = optional(string)<br/>      from_port        = optional(number)<br/>      to_port          = optional(number)<br/>      protocol         = optional(string)<br/>      cidr_blocks      = optional(list(string))<br/>      ipv6_cidr_blocks = optional(list(string))<br/>      prefix_list_ids  = optional(list(string))<br/>      security_groups  = optional(list(string))<br/>      self             = optional(bool, false)<br/>      tags             = optional(map(string))<br/>    })), [])<br/>    tags = optional(map(string), {})<br/>  })</pre> | `null` | no |
| <a name="input_default_cooldown"></a> [default\_cooldown](#input\_default\_cooldown) | The amount of time, in seconds, after a scaling activity completes before another scaling activity can start | `number` | `null` | no |
| <a name="input_default_instance_warmup"></a> [default\_instance\_warmup](#input\_default\_instance\_warmup) | Amount of time, in seconds, until a newly launched instance can contribute to the Amazon CloudWatch metrics. See [AWS Docs](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-default-instance-warmup.html) for details | `number` | `null` | no |
| <a name="input_desired_capacity"></a> [desired\_capacity](#input\_desired\_capacity) | The number of Amazon EC2 instances that should be running in the auto scaling group | `number` | `null` | no |
| <a name="input_desired_capacity_type"></a> [desired\_capacity\_type](#input\_desired\_capacity\_type) | The unit of measurement for the value specified for `desired_capacity`. Supported for attribute-based instance type selection only. Valid values: `units`, `vcpu`, `memory-mib` | `string` | `null` | no |
| <a name="input_disable_default_alarms"></a> [disable\_default\_alarms](#input\_disable\_default\_alarms) | To disable the best practice AWS alarms for EC2 ASGs outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#AutoScaling) | `bool` | `false` | no |
| <a name="input_enable_all_alarm_actions"></a> [enable\_all\_alarm\_actions](#input\_enable\_all\_alarm\_actions) | Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions | `bool` | `false` | no |
| <a name="input_enabled_metrics"></a> [enabled\_metrics](#input\_enabled\_metrics) | A list of additional metrics to collect. Note that if `disable_default_alarms` is `false` then GroupInServiceCapacity is already enabled | `list(string)` | `[]` | no |
| <a name="input_existing_launch_template"></a> [existing\_launch\_template](#input\_existing\_launch\_template) | Map of `id` and `version` of an existing launch template (created outside of this module). `version` value can be version number, `$Latest`, or `$Default` (default is $Default). Ignored if `create_launch_template` is `true` | <pre>object({<br/>    id      = optional(string)<br/>    version = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_existing_service_linked_role_arn"></a> [existing\_service\_linked\_role\_arn](#input\_existing\_service\_linked\_role\_arn) | The ARN of an existing service-linked role that the ASG will use to call other AWS services. If `null` is provided, one will be created | `string` | `null` | no |
| <a name="input_health_check_grace_period"></a> [health\_check\_grace\_period](#input\_health\_check\_grace\_period) | Time (in seconds) after instance comes into service before checking health | `number` | `null` | no |
| <a name="input_health_check_type"></a> [health\_check\_type](#input\_health\_check\_type) | `EC2` or `ELB`. Controls how health checking is done | `string` | `null` | no |
| <a name="input_instance_maintenance_policy"></a> [instance\_maintenance\_policy](#input\_instance\_maintenance\_policy) | Add an instance maintenance policy. See [Instance Maintenance Policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#instance_maintenance_policy) | <pre>object({<br/>    min_healthy_percentage = optional(number)<br/>    max_healthy_percentage = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_instance_market_options"></a> [instance\_market\_options](#input\_instance\_market\_options) | The market (purchasing) option for the instance. See [Market Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#market-options). Only used if `create_launch_template` is `true` | <pre>object({<br/>    market_type = optional(string)<br/>    spot_options = optional(object({<br/>      instance_interruption_behavior = optional(string)<br/>      max_price                      = optional(string)<br/>      spot_instance_type             = optional(string)<br/>      valid_until                    = optional(string)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Name that is propagated to launched EC2 instances via a tag | `string` | `""` | no |
| <a name="input_instance_refresh"></a> [instance\_refresh](#input\_instance\_refresh) | Start an Instance Refresh when this ASG is updated. See [Instance Refresh](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#instance_refresh) | <pre>object({<br/>    strategy = optional(string)<br/>    triggers = optional(list(string))<br/>    preferences = optional(object({<br/>      checkpoint_delay       = optional(number)<br/>      checkpoint_percentages = optional(list(number))<br/>      instance_warmup        = optional(number)<br/>      max_healthy_percentage = optional(number)<br/>      min_healthy_percentage = optional(number)<br/>      skip_matching          = optional(bool)<br/>      auto_rollback          = optional(bool)<br/>      alarm_specification = optional(object({<br/>        alarms = optional(list(string))<br/>      }))<br/>      scale_in_protected_instances = optional(string)<br/>      standby_instances            = optional(string)<br/>    }))<br/>  })</pre> | `null` | no |
| <a name="input_launch_template_config"></a> [launch\_template\_config](#input\_launch\_template\_config) | A map of launch template configuration, all arguments are optional, see type argument for expected type. Only used if `create_launch_template` is `true`. For greater detail of values, see [launch\_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#argument-reference). Available arguments:<br/><pre>launch\_template\_config = {<br/>  instance\_type                 = The type of the instance. Default is "t3.micro".<br/>  instance\_profile              = An IAM profile to attach to the instance. Default is "eec-aws-amifactory-sc-iam-ec2role".<br/>  ebs\_optimized                 = The launched EC2 instance will be EBS-optimized, defaults to "true".<br/>  user\_data                     = The Base64-encoded user data to provide when launching the instance.<br/>  ssh\_key\_pair                  = SSH key pair to be provisioned on the instance.<br/>  default\_version               = Default Version of the launch template. Conflicts with update\_default\_version.<br/>  update\_default\_version        = If "true", update Default Version each update. Conflicts with default\_version.<br/>  disable\_api\_termination       = If "true", enables EC2 Instance Termination Protection<br/>  disable\_api\_stop              = If "true", enables EC2 Instance Stop Protection.<br/>  shutdown\_behavior             = Shutdown behavior for the instance, can be "stop" or "terminate". If spot instances are configured to terminate, is is mandatory to also set this value to "terminate". <br/>  kernel\_id                     = The kernel ID.<br/>  ram\_disk\_id                   = The ID of the RAM disk.<br/>  instance\_tags                 = Map of additional instance tags.<br/>  volume\_tags                   = Map of additional volume tags.<br/>  auto\_recovery                 = If "false", disables automatic recovery of the instance.<br/>  license\_configurations        = A list of license configuration ARNs to associate.<br/>  detailed\_monitoring           = Enable detailed monitoring, defaults to "true".<br/>  cpu\_credits                   = The credit option for CPU usage. T3 instances are "unlimited" by default, T2 as "standard".<br/>  nitro\_enclaves                = If set to "true", [Nitro Enclaves](https://docs.aws.amazon.com/enclaves/latest/user/nitro-enclave.html) will be enabled on the instance.<br/>  hibernation\_enabled           = If set to "true", the launched EC2 instance will hibernation enabled.<br/>  security\_groups               = A list of security group IDs to associate. Overridden if "launch\_template\_config.network\_interfaces" is also supplied.<br/>  network\_interfaces            = A list of network interface maps to be attached at instance boot time. Will override "launch\_template\_config.security\_groups". See [Network Interfaces](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#network-interfaces).<br/>}</pre> | <pre>object({<br/>    instance_type           = optional(string, "t3.micro")<br/>    instance_profile        = optional(string, "eec-aws-amifactory-sc-iam-ec2role")<br/>    ebs_optimized           = optional(bool, true)<br/>    user_data               = optional(string, null)<br/>    ssh_key_pair            = optional(string, null)<br/>    default_version         = optional(string, null)<br/>    update_default_version  = optional(bool, null)<br/>    disable_api_termination = optional(string, null)<br/>    disable_api_stop        = optional(string, null)<br/>    shutdown_behavior       = optional(string, "stop")<br/>    kernel_id               = optional(string, null)<br/>    ram_disk_id             = optional(string, null)<br/>    instance_tags           = optional(map(string), {})<br/>    volume_tags             = optional(map(string), {})<br/>    auto_recovery           = optional(bool, true)<br/>    license_configurations  = optional(list(string), [])<br/>    detailed_monitoring     = optional(bool, true)<br/>    cpu_credits             = optional(string, null)<br/>    nitro_enclaves          = optional(bool, false)<br/>    hibernation_enabled     = optional(bool, false)<br/>    security_groups         = optional(list(string), [])<br/>    network_interfaces = optional(list(<br/>      object({<br/>        description                  = string<br/>        device_index                 = optional(number)<br/>        network_card_index           = optional(number)<br/>        network_interface_id         = optional(string)<br/>        private_ip_address           = optional(string)<br/>        security_groups              = optional(list(string), [])<br/>        subnet_id                    = optional(string)<br/>        delete_on_termination        = optional(bool)<br/>        interface_type               = optional(string)<br/>        associate_carrier_ip_address = optional(string)<br/>        associate_public_ip_address  = optional(string)<br/>        ipv4_addresses               = optional(list(string), [])<br/>        ipv4_address_count           = optional(number)<br/>        ipv4_prefixes                = optional(list(string), [])<br/>        ipv4_prefix_count            = optional(number)<br/>        ipv6_addresses               = optional(list(string), [])<br/>        ipv6_address_count           = optional(number)<br/>        ipv6_prefixes                = optional(list(string), [])<br/>        ipv6_prefix_count            = optional(number)<br/>      })<br/>    ), [])<br/>  })</pre> | `null` | no |
| <a name="input_lifecycle_hooks"></a> [lifecycle\_hooks](#input\_lifecycle\_hooks) | List of one or more lifecycle hook maps to attach to the ASG. See [Lifecycle Hook](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | <pre>list(object({<br/>    name                    = string<br/>    default_result          = optional(string)<br/>    heartbeat_timeout       = optional(number)<br/>    lifecycle_transition    = optional(string)<br/>    notification_metadata   = optional(string)<br/>    notification_target_arn = optional(string)<br/>    role_arn                = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_max_instance_lifetime"></a> [max\_instance\_lifetime](#input\_max\_instance\_lifetime) | The maximum amount of time, in seconds, that an instance can be in service | `number` | `null` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | The maximum size of the auto scaling group. Required unless `create_autoscaling_group` is `false` | `number` | `null` | no |
| <a name="input_metadata_options"></a> [metadata\_options](#input\_metadata\_options) | Customize the metadata options for the instance, will default to being `enabled`. See [Metadata Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#metadata-options). Only used if `create_launch_template` is `true` | <pre>object({<br/>    http_endpoint               = optional(string, "enabled")<br/>    http_tokens                 = optional(string, "required")<br/>    http_put_response_hop_limit = optional(number, 1)<br/>    http_protocol_ipv6          = optional(string)<br/>    instance_metadata_tags      = optional(string, "disabled")<br/>  })</pre> | `{}` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | The minimum size of the autoscaling group. Required unless `create_autoscaling_group` is `false` | `number` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of resources to be created. The actual resource name will be created as `{name_prefix}-{name}-{type}` in accordance with the [EEC Cloud Naming Conventions](https://pages.experian.com/display/SC/Cloud+Naming+Conventions+or+Constructs) | `string` | n/a | yes |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Used to prefix all created resources. If left `null`, a prefix will be automatically calculated based on account name in accordance with the [EEC Cloud Naming Conventions](https://pages.experian.com/display/SC/Cloud+Naming+Conventions+or+Constructs) | `string` | `null` | no |
| <a name="input_network_interfaces"></a> [network\_interfaces](#input\_network\_interfaces) | The same functionality as `launch_template_config.network_interfaces`, kept for backwards compatibility. This variable may be depreciated in future releases | <pre>list(object({<br/>    description                  = string<br/>    device_index                 = optional(number)<br/>    network_card_index           = optional(number)<br/>    network_interface_id         = optional(string)<br/>    private_ip_address           = optional(string)<br/>    security_groups              = optional(list(string))<br/>    subnet_id                    = optional(string)<br/>    delete_on_termination        = optional(bool)<br/>    interface_type               = optional(string)<br/>    associate_carrier_ip_address = optional(string)<br/>    associate_public_ip_address  = optional(string)<br/>    ipv4_addresses               = optional(list(string))<br/>    ipv4_address_count           = optional(number)<br/>    ipv4_prefixes                = optional(list(string))<br/>    ipv4_prefix_count            = optional(number)<br/>    ipv6_addresses               = optional(list(string))<br/>    ipv6_address_count           = optional(number)<br/>    ipv6_prefixes                = optional(list(string))<br/>    ipv6_prefix_count            = optional(number)<br/>  }))</pre> | `[]` | no |
| <a name="input_network_performance_options"></a> [network\_performance\_options](#input\_network\_performance\_options) | Configure network performance options for the instance. `bandwidth_weighting` configures EBS-optimized throughput vs. network bandwidth weighting. Valid values: `default`, `vpc-1`, `ebs-1`. Note: only certain instance types support this feature. The AWS API will reject unsupported combinations at Auto Scaling Group creation time with a clear error. See [Network Performance Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#network-performance-options) and [AWS Docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/configure-bandwidth-weighting.html) for supported instance types. Only used if `create_launch_template` is `true` | <pre>object({<br/>    bandwidth_weighting = optional(string, "default")<br/>  })</pre> | `{}` | no |
| <a name="input_placement"></a> [placement](#input\_placement) | The placement of the instance. See [Placement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#placement). Only used if `create_launch_template` is `true` | <pre>object({<br/>    affinity                = optional(string)<br/>    availability_zone       = optional(string)<br/>    group_name              = optional(string)<br/>    host_id                 = optional(string)<br/>    host_resource_group_arn = optional(string)<br/>    spread_domain           = optional(string)<br/>    tenancy                 = optional(string)<br/>    partition_number        = optional(number)<br/>  })</pre> | `null` | no |
| <a name="input_placement_group"></a> [placement\_group](#input\_placement\_group) | The name of the placement group into which you'll launch your instances, if any. See [AWS Docs](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/placement-groups.html) | `string` | `null` | no |
| <a name="input_private_dns_name_options"></a> [private\_dns\_name\_options](#input\_private\_dns\_name\_options) | The options for the instance hostname. See [Private DNS Name Options](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template#private-dns-name-options). Only used if `create_launch_template` is `true` | <pre>object({<br/>    enable_resource_name_dns_aaaa_record = optional(bool)<br/>    enable_resource_name_dns_a_record    = optional(bool)<br/>    hostname_type                        = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_protect_from_scale_in"></a> [protect\_from\_scale\_in](#input\_protect\_from\_scale\_in) | Allows setting instance protection. The autoscaling group will not select instances with this setting for termination during scale in events | `bool` | `false` | no |
| <a name="input_root_block_device"></a> [root\_block\_device](#input\_root\_block\_device) | Map to customize the root block device of the instance. See [Root Block Devices](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance#ebs-ephemeral-and-root-block-devices). Only used if `create_launch_template` is `true` | <pre>object({<br/>    delete_on_termination = optional(bool)<br/>    encrypted             = optional(bool)<br/>    kms_key_id            = optional(string)<br/>    iops                  = optional(number)<br/>    throughput            = optional(number)<br/>    snapshot_id           = optional(string)<br/>    volume_size           = optional(number)<br/>    volume_type           = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_scaling_policies"></a> [scaling\_policies](#input\_scaling\_policies) | List of target scaling policies to create. See [AutoScaling Scaling Policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy#argument-reference) | <pre>list(object({<br/>    name                      = string<br/>    enabled                   = optional(bool)<br/>    adjustment_type           = optional(string)<br/>    policy_type               = optional(string)<br/>    estimated_instance_warmup = optional(number)<br/>    cooldown                  = optional(number)<br/>    min_adjustment_magnitude  = optional(number)<br/>    metric_aggregation_type   = optional(string)<br/>    scaling_adjustment        = optional(number)<br/>    step_adjustment = optional(list(object({<br/>      scaling_adjustment          = optional(number)<br/>      metric_interval_lower_bound = optional(number)<br/>      metric_interval_upper_bound = optional(number)<br/>    })))<br/>    target_tracking_configuration = optional(object({<br/>      target_value     = optional(number)<br/>      disable_scale_in = optional(bool)<br/>      predefined_metric_specification = optional(object({<br/>        predefined_metric_type = optional(string)<br/>        resource_label         = optional(string)<br/>      }))<br/>      customized_metric_specification = optional(object({<br/>        metric_name = optional(string)<br/>        namespace   = optional(string)<br/>        statistic   = optional(string)<br/>        unit        = optional(string)<br/>        metric_dimension = optional(object({<br/>          name  = optional(string)<br/>          value = optional(string)<br/>        }))<br/>        metrics = optional(list(object({<br/>          id          = optional(string)<br/>          expression  = optional(string)<br/>          label       = optional(string)<br/>          return_data = optional(bool)<br/>          metric_stat = optional(object({<br/>            stat = optional(string)<br/>            unit = optional(string)<br/>            metric = optional(object({<br/>              metric_name = optional(string)<br/>              namespace   = optional(string)<br/>              dimensions = optional(list(object({<br/>                name  = optional(string)<br/>                value = optional(string)<br/>              })))<br/>            }))<br/>          }))<br/>        })))<br/>      }))<br/>    }))<br/>    predictive_scaling_configuration = optional(object({<br/>      max_capacity_breach_behavior = optional(string)<br/>      max_capacity_buffer          = optional(number)<br/>      mode                         = optional(string)<br/>      scheduling_buffer_time       = optional(number)<br/>      metric_specification = optional(object({<br/>        target_value = optional(number)<br/>        predefined_load_metric_specification = optional(object({<br/>          predefined_metric_type = optional(string)<br/>          resource_label         = optional(string)<br/>        }))<br/>        predefined_metric_pair_specification = optional(object({<br/>          predefined_metric_type = optional(string)<br/>          resource_label         = optional(string)<br/>        }))<br/>        predefined_scaling_metric_specification = optional(object({<br/>          predefined_metric_type = optional(string)<br/>          resource_label         = optional(string)<br/>        }))<br/>      }))<br/>    }))<br/>  }))</pre> | `[]` | no |
| <a name="input_schedules"></a> [schedules](#input\_schedules) | List of autoscaling group schedules to create. See [AutoScaling Schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_schedule#argument-reference) | <pre>list(object({<br/>    action_name      = string<br/>    min_size         = optional(number)<br/>    max_size         = optional(number)<br/>    desired_capacity = optional(number)<br/>    start_time       = optional(string)<br/>    end_time         = optional(string)<br/>    time_zone        = optional(string)<br/>    recurrence       = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | The same functionality as `launch_template_config.security_groups`, kept for backwards compatibility. This variable may be depreciated in future releases | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | A list of subnet IDs to launch resources in. Subnets automatically determine which availability zones the group will reside. Required unless subnet is specified in the launch template | `list(string)` | `[]` | no |
| <a name="input_suspended_processes"></a> [suspended\_processes](#input\_suspended\_processes) | A list of processes to suspend for the Auto Scaling Group. The allowed values are `HealthCheck`, `ReplaceUnhealthy`, `AZRebalance`, `AlarmNotification`, `ScheduledActions`, `AddToLoadBalancer`, `InstanceRefresh` | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://pages.experian.com/pages/viewpage.action?pageId=400041906) for available tags | `map(string)` | `{}` | no |
| <a name="input_target_group_arns"></a> [target\_group\_arns](#input\_target\_group\_arns) | List of ARNs of load balancer target groups to attach to the auto scaling group | `list(string)` | `[]` | no |
| <a name="input_termination_policies"></a> [termination\_policies](#input\_termination\_policies) | A list of policies to decide how the instances in the Auto Scaling Group should be terminated. The allowed values are `OldestInstance`, `NewestInstance`, `OldestLaunchConfiguration`, `ClosestToNextInstanceHour`, `OldestLaunchTemplate`, `AllocationStrategy`, `Default` | `list(string)` | `[]` | no |
| <a name="input_wait_for_capacity_timeout"></a> [wait\_for\_capacity\_timeout](#input\_wait\_for\_capacity\_timeout) | A maximum duration that Terraform should wait for ASG instances to be healthy before timing out. Setting this to '0' causes Terraform to skip all Capacity Waiting behavior | `string` | `null` | no |
| <a name="input_warm_pool"></a> [warm\_pool](#input\_warm\_pool) | Add a Warm Pool to the ASG. See [Warm Pool](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group#warm_pool) | <pre>object({<br/>    instance_reuse_policy       = optional(map(string))<br/>    max_group_prepared_capacity = optional(number)<br/>    min_size                    = optional(number)<br/>    pool_state                  = optional(string)<br/>  })</pre> | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_asg_arn"></a> [asg\_arn](#output\_asg\_arn) | The ARN for this AutoScaling Group |
| <a name="output_asg_availability_zones"></a> [asg\_availability\_zones](#output\_asg\_availability\_zones) | The availability zones of the autoscale group |
| <a name="output_asg_capacity_rebalance"></a> [asg\_capacity\_rebalance](#output\_asg\_capacity\_rebalance) | Whether capacity rebalancing is enabled |
| <a name="output_asg_default_cooldown"></a> [asg\_default\_cooldown](#output\_asg\_default\_cooldown) | Time between a scaling activity and the succeeding scaling activity |
| <a name="output_asg_desired_capacity"></a> [asg\_desired\_capacity](#output\_asg\_desired\_capacity) | The number of Amazon EC2 instances that should be running in the group |
| <a name="output_asg_health_check_type"></a> [asg\_health\_check\_type](#output\_asg\_health\_check\_type) | Health check type used by the ASG (should be 'ELB') |
| <a name="output_asg_id"></a> [asg\_id](#output\_asg\_id) | The autoscaling group id |
| <a name="output_asg_max_size"></a> [asg\_max\_size](#output\_asg\_max\_size) | The maximum size of the autoscale group |
| <a name="output_asg_min_size"></a> [asg\_min\_size](#output\_asg\_min\_size) | The minimum size of the autoscale group |
| <a name="output_asg_name"></a> [asg\_name](#output\_asg\_name) | The autoscaling group name |
| <a name="output_asg_target_group_arns"></a> [asg\_target\_group\_arns](#output\_asg\_target\_group\_arns) | ARNs of the target groups associated with the ASG |
| <a name="output_asg_vpc_zone_identifier"></a> [asg\_vpc\_zone\_identifier](#output\_asg\_vpc\_zone\_identifier) | The VPC zone identifier (subnets used by the ASG) |
| <a name="output_kms_grant_id"></a> [kms\_grant\_id](#output\_kms\_grant\_id) | The unique identifier for the KMS grant |
| <a name="output_launch_template_arn"></a> [launch\_template\_arn](#output\_launch\_template\_arn) | The ARN of the launch template |
| <a name="output_launch_template_default_version"></a> [launch\_template\_default\_version](#output\_launch\_template\_default\_version) | The default version of the launch template |
| <a name="output_launch_template_http_tokens"></a> [launch\_template\_http\_tokens](#output\_launch\_template\_http\_tokens) | IMDSv2 HttpTokens setting (should be 'required') |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | The ID of the launch template |
| <a name="output_launch_template_latest_version"></a> [launch\_template\_latest\_version](#output\_launch\_template\_latest\_version) | The latest version of the launch template |
| <a name="output_launch_template_name"></a> [launch\_template\_name](#output\_launch\_template\_name) | The name of the launch template |
| <a name="output_scaling_policy_adjustment_type"></a> [scaling\_policy\_adjustment\_type](#output\_scaling\_policy\_adjustment\_type) | Scaling policy's adjustment type |
| <a name="output_scaling_policy_arn"></a> [scaling\_policy\_arn](#output\_scaling\_policy\_arn) | ARN assigned by AWS to the scaling policy |
| <a name="output_scaling_policy_name"></a> [scaling\_policy\_name](#output\_scaling\_policy\_name) | Scaling policy's name |
| <a name="output_scaling_policy_policy_type"></a> [scaling\_policy\_policy\_type](#output\_scaling\_policy\_policy\_type) | Scaling policy's type |
| <a name="output_schedule_arn"></a> [schedule\_arn](#output\_schedule\_arn) | ARN assigned by AWS to the autoscaling schedule |
| <a name="output_service_linked_role_arn"></a> [service\_linked\_role\_arn](#output\_service\_linked\_role\_arn) | ARN specifying the IAM service-linked role |
<!-- END_TF_DOCS -->

## Metadata
```discoveryhub
summary: Terraform module for AWS EC2 Auto Scaling Groups and Launch Templates
region: Global
bu: EITS
contacts:
  technical: EITS UK&I Cloud Enablement Team eitsukicloud@experian.com
  product: 
```
