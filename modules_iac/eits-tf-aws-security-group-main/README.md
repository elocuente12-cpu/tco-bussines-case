# EITS Terraform module for AWS Security Groups

EITS Terraform module to create AWS VPC Security Groups.

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

## EITS Security & Compliance

**Last Module Review**: 2025-01-06

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-08-24 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-08-24 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-08-24 | 0.72.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-08-24 | 1.59.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Notes

- To comply with EEC standards, the security group name will be computed as followed: `<prefix>-<security_group_name>-sg-<random_string>`. The random string is added by Terraform to ensure that, in case the group needs to be recreated, it can be created before deleting the old one (as `create_before_destroy` is set to `true`), to avoid downtime.
- As per security best practices, please don't use `0.0.0.0/0` in CIDR inbound rules, there will be a warning if one is found.
- v1.1.2 of this module is called by the `eits-tf-aws-ec2-innersource` module to generate security groups for the EC2 instance
- from v2, it's possible to tag individual rules, and change the description without recreating the rule
- ***If migrating from v1.x.x, you first need to comment/remove `security_group_ingress_rules` and `security_group_egress_rules`, run the code, then add them back. This is because a new resource is used behind the scene, which is unable to update the existing rules. Running this without this workaround first would cause an error as the rules already exist. Alternatively, you can also remove the rules via CLI/Console before running this code.***

## EEC Default Rules for EC2

- Setting the `ec2_agent_rules` variable to either `linux` or `windows` will add relevant default EEC EC2 ingress rules to the security group. If set, the security group will allow inbound traffic on a number of agent and support related ports. See see `locals.tf` for the full list of rules for each OS.
  - From version `3.6.1`, `cyberark_sia_rules` has been added to help with [CyberArk SIA pre-requisites](https://experian.sharepoint.com/sites/globalsecurityadministration/GSA%20Sharing%20with%20Business/PAM/SitePages/How-to-comply-with-Pre-requisites-to-access-servers-via-CyberArk-SIA-.aspx#aws-pre-requisites). Should you still need to use the old PSM method, please add the rules manually for it, and set `cyberark_sia_rules` to `no` if not required.
  - If `ec2_agent_rules` is configured, it will automatically add rules for SNOW, Tanium, and CyberArk CPM and SIA. Set this variable to `no` to exclude them all.
  - The region is automatically detected. It defaults to `us` (North America) if it's a new or unconfigured region.

## Usage

```HCL
module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git?ref=3.8.0"

  security_group_name          = <security_group_name>
  security_group_description   = <security_group_description>
  vpc_id                       = <vpc_id>
  security_group_ingress_rules = <ingress_rules> 
  security_group_egress_rules  = <egress_rules>

  tags = {
    Environment = <environment>
    CostString  = <cost_string>
    AppID       = <app_id>
    <key>       = <value>
  }
}
```

## Example

```HCL
module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git"

  security_group_name          = "example_sg"
  security_group_description   = "This is an example"
  vpc_id                       = data.aws_vpc.ec2_vpc.id
  security_group_ingress_rules = [
    {
      description     = "SSH"
      from_port       = 22
      to_port         = 22
      protocol        = "tcp"
      security_groups = [module.ec2.security_group_id]
      tags            = {Name="MyRule"}
    },
    {
      description     = "Ping"
      from_port       = -1
      to_port         = -1
      protocol        = "icmp"
      cidr_blocks     = ["10.0.0.0/8"]
    },
    {
      description     = "Heartbeat"
      from_port       = 8443
      to_port         = 7443
      protocol        = "tcp"
      self            = true
    }
  ]
  security_group_egress_rules  = [
    {
      description     = "All Outbound"
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      cidr_blocks     = ["10.0.0.0/8"]
    }
  ]

  tags = {
    Environment = <environment>
    CostString  = <cost_string>
    AppID       = <app_id>
    Name        = "Example"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.73.0 |
| <a name="requirement_time"></a> [time](#requirement\_time) | >= 0.13.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.73.0 |
| <a name="provider_time"></a> [time](#provider\_time) | >= 0.13.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |

## Resources

| Name | Type |
|------|------|
| [aws_security_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.cidr_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.eec_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.ipv6_cidr_blocks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.prefix_list_ids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.security_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_egress_rule.self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.cidr_ipv4](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.cyberark_sia](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.eec_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.ipv6_cidr_blocks](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.prefix_list_ids](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.security_groups](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.self](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [time_sleep.sg_rule_wait](https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/sleep) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cyberark_sia_rules"></a> [cyberark\_sia\_rules](#input\_cyberark\_sia\_rules) | Set to `windows` or `linux` to add CyberArk SIA related rules to the security group. This is automatically configured if `ec2_agent_rules` is set. Set it to `no` to exclude them. | `string` | `null` | no |
| <a name="input_ec2_agent_rules"></a> [ec2\_agent\_rules](#input\_ec2\_agent\_rules) | Valid values are `linux` or `windows`. Whether to add default EEC EC2 agent rules to the security group. If set, the security group will allow inbound traffic on a number of agent and support related ports. Please see README for more information | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Used for naming the security group (see `security_group_name` for details). If left null, a prefix will be automatically calculated based on the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E) | `string` | `null` | no |
| <a name="input_security_group_description"></a> [security\_group\_description](#input\_security\_group\_description) | Security group description. Cannot be an empty string. This maps to the AWS GroupDescription attribute, for which there is no Update API. If you'd like to classify your security groups in a way that can be updated, use tags | `string` | n/a | yes |
| <a name="input_security_group_egress_rules"></a> [security\_group\_egress\_rules](#input\_security\_group\_egress\_rules) | A list of Security Group EGRESS rule objects. Each egress object supports the following fields: <br/>    <pre>security\_group\_egress\_rules = [<br/>      {<br/>        description      = (Optional) Description of this ingress rule.<br/>        from\_port        = (Optional) Start port (or ICMP type number if protocol is icmp or icmpv6).<br/>        to\_port          = (Optional) End range port (or ICMP code if protocol is icmp).<br/>        protocol         = (Required) Protocol. If you select a protocol of -1 you must either omit from\_port and to\_port or set them to 0.<br/>        cidr\_blocks      = (Optional) List of CIDR blocks.<br/>        ipv6\_cidr\_blocks = (Optional) List of IPv6 CIDR blocks.<br/>        prefix\_list\_ids  = (Optional) List of Prefix List IDs.<br/>        security\_groups  = (Optional) List of security groups. A group name can be used relative to the default VPC. Otherwise, group ID.<br/>        self             = (Optional) Whether the security group itself will be added as a source to this ingress rule.<br/>        tags             = (Optional) A map of tags for the rule.<br/>      }<br/>    ]</pre><br/>    Although `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, `self`, and `security_groups` are all marked as optional, you must provide one of them in order to configure the destination of the traffic.<br/>    The `from_port` and `to_port` arguments are required unless `protocol` is set to `-1` or `icmpv6`.<br/>    See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule for further details | <pre>list(object({<br/>    description      = optional(string)<br/>    from_port        = optional(number)<br/>    to_port          = optional(number)<br/>    protocol         = string<br/>    cidr_blocks      = optional(list(string))<br/>    ipv6_cidr_blocks = optional(list(string))<br/>    prefix_list_ids  = optional(list(string))<br/>    security_groups  = optional(list(string))<br/>    self             = optional(bool, false)<br/>    tags             = optional(map(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_security_group_ingress_rules"></a> [security\_group\_ingress\_rules](#input\_security\_group\_ingress\_rules) | A list of Security Group INGRESS rule objects. Each ingress object supports the following fields: <br/>    <pre>security\_group\_ingress\_rules = [<br/>      {<br/>        description      = (Optional) Description of this ingress rule.<br/>        from\_port        = (Optional) Start port (or ICMP type number if protocol is icmp or icmpv6).<br/>        to\_port          = (Optional) End range port (or ICMP code if protocol is icmp).<br/>        protocol         = (Required) Protocol. If you select a protocol of -1 you must either omit from\_port and to\_port or set them to 0.<br/>        cidr\_blocks      = (Optional) List of CIDR blocks.<br/>        ipv6\_cidr\_blocks = (Optional) List of IPv6 CIDR blocks.<br/>        prefix\_list\_ids  = (Optional) List of Prefix List IDs.<br/>        security\_groups  = (Optional) List of security groups. A group name can be used relative to the default VPC. Otherwise, group ID.<br/>        self             = (Optional) Whether the security group itself will be added as a source to this ingress rule.<br/>        tags             = (Optional) A map of tags for the rule.<br/>      }<br/>    ]</pre><br/>    Although `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, `self`, and `security_groups` are all marked as optional, you must provide one of them in order to configure the destination of the traffic.<br/>    The `from_port` and `to_port` arguments are required unless `protocol` is set to `-1` or `icmpv6`.<br/>    See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule for further details | <pre>list(object({<br/>    description      = optional(string)<br/>    from_port        = optional(number)<br/>    to_port          = optional(number)<br/>    protocol         = string<br/>    cidr_blocks      = optional(list(string))<br/>    ipv6_cidr_blocks = optional(list(string))<br/>    prefix_list_ids  = optional(list(string))<br/>    security_groups  = optional(list(string))<br/>    self             = optional(bool, false)<br/>    tags             = optional(map(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_security_group_name"></a> [security\_group\_name](#input\_security\_group\_name) | Used for naming the security group. To comply with EEC standards, the security group name will be computed as followed: `<prefix>-<security_group_name>-sg-<random_string>`. The random string is added by Terraform to ensure that, in case the group needs to be recreated, it can be created before deleting the old one to avoid downtime | `string` | n/a | yes |
| <a name="input_sleep_timeout"></a> [sleep\_timeout](#input\_sleep\_timeout) | Time in seconds to wait before creating security group rules. | `number` | `5` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the security group will be created. Required for EEC accounts as the default VPC is not in use | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The created Security Group ARN |
| <a name="output_egress_rules"></a> [egress\_rules](#output\_egress\_rules) | A map of all the egress rules created for the security group |
| <a name="output_id"></a> [id](#output\_id) | The created or target Security Group ID |
| <a name="output_ingress_rules"></a> [ingress\_rules](#output\_ingress\_rules) | A map of all the ingress rules created for the security group |
| <a name="output_name"></a> [name](#output\_name) | The created Security Group Name |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | The VPC ID where the security group is created |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: EITS Terraform module for AWS Security Group
region: Global
bu: EITS
contacts:
  technical: EITS Cloud Enablement team <eitsukicloud@experian.com>
```
