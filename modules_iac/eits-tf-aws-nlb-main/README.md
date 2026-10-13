# EITS Cloud Enablement AWS NLB Module

EITS Terraform module for AWS Network Load Balancer. This module will:

- Create an NLB
- Create target groups and associated listeners based on map
- Setup access logging to an s3 bucket if provided
- Configure multiple listeners

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

## EITS Security & Compliance

**Last Module Review**: 2025-12-11

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-09-23 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-09-23 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-09-23 | 0.72.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-09-23 | 1.59.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Resource naming

Due to name character contraints be aware there is a 28 alphanumeric character limit on the `nlb_name` variable. This will automatically be suffixed with '-nlb'.

## Using NLBs for HTTP/HTTPS

Unlike an Application Load Balancer, a Network Load Balancer can't have application layer (layer 7) HTTP or HTTPS listeners. It only supports transport layer (layer 4) TCP listeners. HTTP and HTTPS traffic can be routed to your environment over TCP. To establish secure HTTPS connections install a certificate on the environment's instances, and configure the instances to listen on the appropriate port (typically 443) and terminate HTTPS connections. Pass this port and certificate_arn in the `target_groups` map.

## Other notes

- All new ELBs are internal in accordance with EEC guidelines
- IPv6 is not supported in this module, if it is actually required we can easily add it
- If `enable_cross_zone_load_balancing` is left at the default `null`, then cross zone load balancing will be enabled for resources with an "Environment" tag of value "prd", but disabled automatically for other environments. This is a cost-saving measure. To override this, configure `enable_cross_zone_load_balancing`to either `true` or `false`.
- NLBs do not support listener rules beyond the default forward action
- The `targets` attribute in `target_groups` require the attribute `name` so that the target is uniquely identified, and won't be removed if other targets are added or removed. **This must be a static value, it can't be dynamically generated**
- The value of `stickiness` in `target_groups` is a boolean, set to `true` to enable sticky source_ip. This is the only option available for NLB.
- The `additional_certs` attribute in `listeners` allows you to attach a list of ACM certificate ARNS to the listener.
- Adding or removing `security_groups` to an already existing NLB will cause the resource to be recreated

## Usage

### Example of TCP NLB with IP Address Targets

```hcl
module "nlb" {
  source  = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-nlb.git"

  nlb_name             = "<used for naming resources>"
  vpc_id               = "<vpc id to associate with nlb>"
  subnet_ids           = [ <list of subnet IDs> ]
  access_log_bucket_id = "<optional s3 bucket id for logging>"

  # a map of maps for each required target group. the root key of each map will be used for naming resources
  target_groups = {
    tg1 = {
      port        = 5432
      protocol    = "TCP"
      target_type = "ip"

      # a list of maps for each target
      targets = [
        {
          name              = "<target_name>"
          target_id         = "<ip address>"
          availability_zone = "<required if ip is not in local vpc>"
        }
      ]
    }
  }

  # use root key from target_groups for default_target_group
  listeners = [
    {
      port                 = 5432
      protocol             = "TCP"
      default_target_group = "tg1"
    }
  ]

  # note: name tag is automatically added
  tags = {
    Environment = <env>
    CostString  = <CostString>
    AppID       = <AppID>
  }
}
```

### Example of TLS NLB with EC2 Instance Targets

```hcl
module "nlb" {
  source  = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-nlb.git"

  nlb_name   = "<used for naming resources>"
  vpc_id     = "<vpc id to associate with nlb>"
  subnet_ids = [ <list of subnet IDs> ]

  # a map of maps for each required target group. the root key of each map will be used for naming resources
  target_groups = {
    tg1 = {
      port        = 443
      protocol    = "TLS"
      target_type = "instance"

      # health_check is an optional map
      health_check = {
        enabled  = true
        port     = "traffic-port"
      }

      # a list of maps for each target
      targets = [
        {
          name      = "<target_name>"
          target_id = "<ec2 instance id>"
        }
      ]
    }
  }

  # use root key from target_groups for default_target_group
  listeners = [
    {
      port                 = 443
      protocol             = "TLS"
      default_target_group = "tg1"
      ssl_policy           = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      certificate_arn      = "arn:aws:iam::123456789012:server-certificate/cert_name"
      additional_certs     = [ <list of acm arns for additional certificates> ]
    }
  ]

  # note: name tag is automatically added
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
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.11.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.11.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.1 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |

## Resources

| Name | Type |
|------|------|
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener_certificate.additional](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener_certificate) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_lb_target_group_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group_attachment) | resource |
| [aws_default_tags.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_access_log_bucket_id"></a> [access\_log\_bucket\_id](#input\_access\_log\_bucket\_id) | The S3 bucket name to store the logs in, if `null` access logs will not be enabled | `string` | `null` | no |
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | A list of SNS topic ARNs for alarm notifications | `list(string)` | `[]` | no |
| <a name="input_alarm_tcp_elb_reset_threshold"></a> [alarm\_tcp\_elb\_reset\_threshold](#input\_alarm\_tcp\_elb\_reset\_threshold) | Threshold for the default NLB TCP\_ELB\_Reset\_Count alarm | `number` | `10` | no |
| <a name="input_desync_mitigation_mode"></a> [desync\_mitigation\_mode](#input\_desync\_mitigation\_mode) | How the ALP handles HTTP desync requests. Valid values are `monitor`, `defensive`, `strictest` | `string` | `"defensive"` | no |
| <a name="input_disable_default_alarms"></a> [disable\_default\_alarms](#input\_disable\_default\_alarms) | If true, disables creation of the module default CloudWatch alarms | `bool` | `false` | no |
| <a name="input_dns_record_client_routing_policy"></a> [dns\_record\_client\_routing\_policy](#input\_dns\_record\_client\_routing\_policy) | How traffic is distributed among the load balancer Availability Zones. Possible values are `any_availability_zone` (default), `availability_zone_affinity`, or `partial_availability_zone_affinity`. See [AWS Docs](https://docs.aws.amazon.com/elasticloadbalancing/latest/network/network-load-balancers.html#zonal-dns-affinity) for details | `string` | `null` | no |
| <a name="input_enable_all_alarm_actions"></a> [enable\_all\_alarm\_actions](#input\_enable\_all\_alarm\_actions) | If true, send SNS notifications for ALARM, OK, and INSUFFICIENT\_DATA states | `bool` | `false` | no |
| <a name="input_enable_cross_zone_load_balancing"></a> [enable\_cross\_zone\_load\_balancing](#input\_enable\_cross\_zone\_load\_balancing) | A boolean flag to enable/disable cross zone load balancing. If left at the default `null`, then cross zone load balancing will be enabled for resources with an 'Environment' tag of value 'prd', but disabled automatically for other environments. This is a cost-saving measure. To override this, set specifically to either `true` or `false` | `bool` | `null` | no |
| <a name="input_enable_deletion_protection"></a> [enable\_deletion\_protection](#input\_enable\_deletion\_protection) | A boolean flag to enable/disable deletion protection for NLB | `bool` | `true` | no |
| <a name="input_healthy_host_alarm_threshold"></a> [healthy\_host\_alarm\_threshold](#input\_healthy\_host\_alarm\_threshold) | Default threshold for target group HealthyHostCount alarms | `number` | `0` | no |
| <a name="input_listeners"></a> [listeners](#input\_listeners) | A list of maps describing the listeners for this NLB. Use `default_target_group` to attach listener to a target group, must match required root key from 'target\_groups'. All NLB listener rules have the default forward action (NLBs are not comptible with any other action). See [lb\_listener](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener#argument-reference) for argument reference and required values | <pre>list(object({<br/>    default_target_group = optional(string)<br/>    port                 = optional(number)<br/>    protocol             = optional(string)<br/>    ssl_policy           = optional(string)<br/>    certificate_arn      = optional(string)<br/>    additional_certs     = optional(list(string), [])<br/>  }))</pre> | `[]` | no |
| <a name="input_minimum_load_balancer_capacity_units"></a> [minimum\_load\_balancer\_capacity\_units](#input\_minimum\_load\_balancer\_capacity\_units) | The minimum capacity units for the load balancer | `number` | `null` | no |
| <a name="input_nlb_name"></a> [nlb\_name](#input\_nlb\_name) | Used to name all resources, must be unique per account | `string` | n/a | yes |
| <a name="input_scheme"></a> [scheme](#input\_scheme) | The load balancer scheme, either `internet-facing` or `internal`. The nodes of an internet-facing (or 'public') load balancer have public IP addresses. The nodes of an internal load balancer have only private IP addresses. It is recommended to use an internal load balancer unless your usecase specifically requires an internet-facing one. Defaults to `internal` | `string` | `"internal"` | no |
| <a name="input_secondary_ips_auto_assigned_per_subnet"></a> [secondary\_ips\_auto\_assigned\_per\_subnet](#input\_secondary\_ips\_auto\_assigned\_per\_subnet) | The number of secondary IP addresses to configure for your load balancer nodes. The valid range is 0-7. WARNING: When decreased, this will force a recreation of the resource | `number` | `null` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | A list of security group IDs to assign to the NLB. Security groups cannot be added if none are currently present, and cannot all be removed once added. Either of these conditions will force a recreation of the NLB resource | `list(string)` | `[]` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | A list of subnet IDs to associate with NLB. Will be ignored if `subnet_mapping` is populated | `list(string)` | `[]` | no |
| <a name="input_subnet_mapping"></a> [subnet\_mapping](#input\_subnet\_mapping) | A list of maps describing subnets to attach to network load balancer. Will override `subnet_ids` if populated | <pre>list(object({<br/>    subnet_id            = optional(string)<br/>    allocation_id        = optional(string)<br/>    private_ipv4_address = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags | `map(string)` | `{}` | no |
| <a name="input_target_groups"></a> [target\_groups](#input\_target\_groups) | A map of maps for each required target group. The root map keys must be unique identifiers for each target group map, this will also be used to name the target groups. See [lb\_target\_group resource](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group#argument-reference) for valid/default values | <pre>map(object({<br/>    port                   = optional(number)<br/>    protocol               = optional(string)<br/>    proxy_protocol_v2      = optional(bool)<br/>    deregistration_delay   = optional(number)<br/>    slow_start             = optional(number)<br/>    connection_termination = optional(bool)<br/>    preserve_client_ip     = optional(bool)<br/>    health_check = optional(object({<br/>      enabled             = optional(bool)<br/>      port                = optional(any)<br/>      protocol            = optional(string)<br/>      path                = optional(string)<br/>      healthy_threshold   = optional(number)<br/>      unhealthy_threshold = optional(number)<br/>      interval            = optional(number)<br/>      timeout             = optional(number)<br/>    }))<br/>    stickiness  = optional(bool)<br/>    target_type = optional(string)<br/>    target_alarm = optional(object({<br/>      unhealthy_threshold = optional(number)<br/>      healthy_threshold   = optional(number)<br/>    }))<br/>    targets = optional(list(object({<br/>      name              = optional(string)<br/>      target_id         = optional(string)<br/>      port              = optional(number)<br/>      availability_zone = optional(string)<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_unhealthy_host_alarm_threshold"></a> [unhealthy\_host\_alarm\_threshold](#input\_unhealthy\_host\_alarm\_threshold) | Default threshold for target group UnHealthyHostCount alarms | `number` | `1` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID to associate with NLB | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_listener_arns"></a> [listener\_arns](#output\_listener\_arns) | A list of all the listener ARNs |
| <a name="output_nlb_arn"></a> [nlb\_arn](#output\_nlb\_arn) | The ARN of the NLB |
| <a name="output_nlb_dns_name"></a> [nlb\_dns\_name](#output\_nlb\_dns\_name) | DNS name of NLB |
| <a name="output_nlb_name"></a> [nlb\_name](#output\_nlb\_name) | The ARN suffix of the NLB |
| <a name="output_nlb_zone_id"></a> [nlb\_zone\_id](#output\_nlb\_zone\_id) | The ID of the zone which NLB is provisioned |
| <a name="output_target_group_arns"></a> [target\_group\_arns](#output\_target\_group\_arns) | A list of all the target group ARNs |
| <a name="output_target_group_names"></a> [target\_group\_names](#output\_target\_group\_names) | A list of all the target group names |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS Network Load Balancer (NLB)
region: Global
bu: T&I
docs: https://experian.atlassian.net/wiki/x/HQ4EF
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>
```
