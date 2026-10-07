# EITS Terraform module for EC2 instances

EITS Terraform module for EC2 instance. This module will:

- Automatically select the latest EEC-approved AMI based on the required OS.
- Automatically configure the security group to allow traffic from CyberArk, CMDB, and security agents.
- Create an EC2 instance and, optionally, create and attach EBS volumes (as changes in *ebs_block_device* argument will be ignored using the *ec2-instance* AWS module, so  *aws_volume_attachment* resource is used instead - see the [HashiCorp documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance.html#volume_type)).
- Validate tags.
- Add additional ENIs to the EC2 instance, with the ability of specifying the security groups attached to the new ENIs. Now supports multiple additional ENIs with flexible configuration.
- Check if the EC2 instance hostname complies with [EEC naming convention](https://experian.atlassian.net/wiki/x/zgL3E#HowtobuildEC2instancesusingtheExperianGoldenAMIs-EC2instanceNamingconvention), and warn if not.
- Installs CloudWatch agent and creates the `BURoleForEC2CloudWatchIntegration` role, if required.

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> **IMPORTANT:**
> As of version `4.0.0`, the adding of additional ENISs has changed if additional ENIs have been added pre `4.0.0` it will be updated when `terraform apply` is run if the `migration.tf` has been configured. To configure `migration.tf` set the to match the `device_index` of the additional ENIs.

> As of version `3.3.0`, the handling of the default security group has changed. Please refer to the change logs of both this module and the Security Group module for further information on how to use the default security groups and migrate it, if required.
If you're migrating, and want to use an external security group instead of the one provided with the module, please refer to code in the `tests\external_sg` folder.

> As of version `2.7.1`, Check if the EC2 instance hostname complies with [EEC naming convention](https://experian.atlassian.net/wiki/x/zgL3E#HowtobuildEC2instancesusingtheExperianGoldenAMIs-EC2instanceNamingconvention), and warn if not by `validation_warning`. Currently this will be a warning but will change to an error on 1st of February.

> As of version `2.6.0` the module automatically adds the [EEC AWS Instance Scheduler](https://experian.atlassian.net/wiki/x/yxL3E) "Instance-Scheduler" tag for instances deployed in a **sandbox** (sbx) environment only. It will set the value of the tag to the local aws region (for example eu-west-2 will be "uk-london-office-hours"). To disable this behaviour set `disable_instance_scheduler` to `true`. Please note if you already configure the "Instance-Scheduler" tag on your instances then also disable this otherwise it may override your configuration.

> As of version `2.2.0`, default alarms based on [AWS best practice](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html) will be automatically created. This may incur an extra charge of $0.20 per month for each EC2 instance. To disable the creation of these alarms, please set the variable `disable_default_alarms` to true.

## EITS Security & Compliance

**Last Module Review**: 2025-01-26

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-09-30 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-09-30 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-09-30 | 0.72.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-09-30 | 1.59.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Notes

- Volume encryption is enabled by default.
- The EEC instance profile ("eec-aws-amifactory-sc-iam-ec2role") is added by default, to override this use `instance_profile`.
- EBS volumes are created as EBS resources, and attached to the instance, so they can be managed via Terraform.
  - Changes in *ebs_block_device* argument will be ignored using the *ec2-instance* AWS module, so *aws_volume_attachment* resource is used instead - see the [HashiCorp documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance.html#volume_type)
- [EC2 Instance Termination Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html#Using_ChangingDisableAPITermination) is automatically set to `true` for instances with an "Environment" tag of value "prd".
- Can either attach existing security groups or create a new one inline (or both).
- To create an SSH key pair, please use the [eits-tf-aws-key-pair](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-key-pair/browse) module.
- To add an additional ENI, configure one of the following: `var.private_ips`, `var.private_ips_count`, `var.private_ip_list`. They are mutually exclusive. `private_ip_list_enabled` is automatically set to `true` if `private_ip_list` is configured.
- For multiple additional ENIs, use the `var.additional_enis` list variable. Each ENI can have its own subnet, security groups, and private IP configuration. This provides more flexibility than the single ENI variables above.
- Each of the `network_interface` blocks attach a network interface to an EC2 Instance during boot time. However, because the network interface is attached at boot-time, replacing/modifying the network interface **WILL** trigger a recreation of the EC2 Instance. If you should need at any point to detach/modify/re-attach a network interface to the instance, use the `aws_network_interface` or `aws_network_interface_attachment` resources instead.
- For cost optimisation recommendations, including instance scheduling, please visit [our EC2 service offering page](https://pages.experian.local/display/UCE/EC2+Service+Offering#EC2ServiceOffering-CostOptimisation).
- Starting with the [Security group module v3.0.0](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse?at=refs%2Ftags%2F3.0.0), there is an option to create one security group with all the default Experian Linux or Windows rules. If you use that, you can the set `exclude_default_security_group` to `true`, and attach that new security group to the EC2 instance.
- SLES 12 and Bottlerocket AMIs have been deprecated, and are no longer available in the AMI catalog.
- From version `3.0.2`, if you require the default security groups, and specify a custom AMI ID, then please use the `operating_system` variable to assign the correct rules. If you are getting Terraform errors related to `data.aws_ami.ec2` or `Invalid for_each argument - for_each = var.ec2_agent_rules` using module version `3.0.0` and `3.0.1`, please consider upgrading to at least `3.0.2`.

## Variables

- AMI must be one of the following values: `windows_2019|windows_2022|amzn_lnx_2023|eks_amzn_lnx_2023|gpu_eks_amzn_lnx_2023|rhel_8|rhel_9|rhel_10|sles_15|ami-*` (Unless the ID of a custom AMI is specified, the module automatically selects the latest available EEC AMI for the specified OS). Please note that, if the custom AMI has not been approved by EEC, the deployment will fail.
- Security groups: Attach existing security groups, add a new one (with or without default rules), or both.
- Tags: `Environment, CostString, AppID, ResourceName, ResourceOwner, ResourceAppRole, adDomain, adGroup` (for Windows), and `CentrifyUnixRole` (for Linux) are required tags for any EC2 resource (see the [EEC tagging standards](https://experian.atlassian.net/wiki/x/swH3E) for more tags details and accepted values). The EC2 module will automatically check and add those tags based on these variables. `Name` and `ResourceName` tags are automatically computed if omitted.

## CloudWatch Agent Configuration

The module has the ability to install the CloudWatch Agent on instances built with an EEC AMI. To do this set `enable_cloudwatch_agent` to `true`. It is also required to set `create_cloudwatch_role` to `true` in order to create and associate the "BURoleForEC2CloudWatchIntegration" role, unless this role already exists. If this role already exists you will receive a "Role with name BURoleForEC2CloudWatchIntegration already exists" error, and must set `instance_profile` to `BURoleForEC2CloudWatchIntegration` to attach the already created role. An example of creating instances within a loop, while still creating and associating the role, can be found in "./tests/cloudwatch_agent".

EEC managed scripts inside the instance will configure the CloudWatch Agent and create a configuration file in "/opt/aws/amazon-cloudwatch-agent/bin/config.json" with standard configuration, this file is also uploaded during the installation to the ssm parameter "/eecamifactory/cwagentconfig". If you would like to customize this file, please consult this [AWS guide](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/CloudWatch-Agent-Configuration-File-Details.html). By default this configuration sends the agent logs to the EEC managed "eec-aws-ec2-cloudwatch-agent" CloudWatch log group, and the metrics to the eec-aws-ec2-cloudwatch-metrics namespace".

For more details, see [EEC CloudWatch Agent](https://experian.atlassian.net/wiki/x/zgL3E#FAQBuildingEC2instancesinAWS-CloudWatchAgent).

## Usage

```HCL
module "ec2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ec2-innersource.git?ref=4.2.1"

  # Mandatory
  ami    = "<ami short name or ID>"
  subnet = "<subnet id>"

  # All variables below (except for tags) are optional
  # see Inputs for descriptions, and default values if omitted

  # Miscellaneous optional variables
  ec2_name               = "<ec2 name>"
  instance_type          = "<instance type>"
  instance_profile       = "<name of iam role to attach>"
  ssh_key_pair           = "<key pair name>"
  user_data              = "<user data to use when launching>"
  ebs_optimized          = <true/false>
  delete_on_termination  = <true/false>
  termination_protection = <true/false>
  detailed_monitoring    = <true/false>
  private_ip             = "<ip address>"
  secondary_private_ips  = [<list of ip addresses>]

  # Security Group configuration
  security_group_name          = "<security group name>"
  security_group_description   = "<security group description>"
  security_group_ingress_rules = [{<ingress rules>}]
  security_group_egress_rules  = [{<egress rules>}]

  exclude_default_security_group = <true/false>
  security_groups = [<list of existing groups to associate>]

  # Metadata configuration
  metadata_http_tokens_required        = <true/false>
  metadata_http_endpoint_enabled       = <true/false>
  metadata_tags_enabled                = <true/false>
  metadata_http_put_response_hop_limit = <number>

  # Root volume configuration
  root_volume_type       = "<volume type>"
  root_volume_size       = <number in GiB>
  root_volume_iops       = <number>
  root_volume_throughput = <number>
  root_volume_kms_key_id = "<kms key id>"

  # EBS volume configuration
  ebs_block_device = [
    {
      device_name = "<device name>"
      volume_size = <number in GiB>
      volume_type ="<volume type>"
      iops        = <number>
      throughput  = <number>
      snapshot_id = "<snapshot id>"
      kms_key_id  = "<kms key id>"
    }
  ]

  # Alarm configuration
  disable_default_alarms = <true/false>
  alarm_sns_topics       = [<list of sns topics>]

  # CloudWatch Agent configuration
  enable_cloudwatch_agent  = <true/false>
  create_cloudwatch_role   = <true/false>
  cloudwatch_log_retention = <number>
  cloudwatch_role_policies = [<list of json policies>]

  # Mandatory tags
  tags = {
    Name            = "<ec2 name>"
    ResourceName    = "<ec2 name>"
    ResourceOwner   = "<email>"
    ResourceAppRole = "<app | db | web | misc>"
    Environment     = "<environment>"
    CostString      = "<cost string>"
    AppID           = "<app id>"
  }
}
```

## Examples

### Standard Instance

```HCL
module "ec2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ec2-innersource.git?ref=4.2.1"

  ec2_name      = "example_ec2"
  ami           = "amzn_lnx_2023"
  instance_type = "t3a.small"
  subnet        = data.aws_subnets.vpc_subnets.ids[0]

  # Security Group configuration 
  # Note that default rules are added unless exclude_default_security_group is false
  security_group_name          = "example_sg"
  security_group_description   = "example sg"
  security_group_ingress_rules = [
    {
      description = "ssh"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    },
    {
      description     = "ping"
      from_port       = -1
      to_port         = -1
      protocol        = "icmp"
      security_groups = [module.ec2_source.security_group_id]
    }
  ]
  security_group_egress_rules  = [
    {
      type        = "egress"
      from_port   = "0"
      to_port     = "0"
      protocol    = "-1"
      cidr_blocks = ["10.0.0.0/8"]
      description = "Allow outbound traffic to Experian network"
    }
  ]
  security_groups = ["sg-xxx"]

  # Root volume configuration 
  root_volume_type = "gp3"
  root_volume_size = "60"

  # Additional EBS volumes
  ebs_block_device = [
    {
      device_name = "/dev/sde"
      volume_size = "30"
      volume_type = "gp3"
    },
    {
      device_name = "/dev/sdh"
      volume_size = "10"
      volume_type = "io1"
      iops        = 100
    }
  ]

  # Mandatory tags
  tags = {
    Name             = "example_ec2"
    ResourceName     = "USAEA1PWBUAS01"
    ResourceOwner    = "owner@email.com"
    ResourceAppRole  = "app"
    Environment      = "sbx"
    CostString       = "1234.CC.123.123456"
    AppID            = "12345"
    adDomain         = "gdc.local"
    CentrifyUnixRole = "UNX-ADM_example_ec2_servers"
  }
}
```

### Instance with external network interface

```HCL
resource "aws_network_interface" "example" {
  subnet_id   = "subnet-xxx"
  private_ips = ["10.11.12.13"]
    security_groups = ["sg-xxx"]
}

module "ec2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ec2-innersource.git?ref=4.2.1"

  ec2_name      = "example_ec2"
  ami           = "amzn_lnx_2023"
  instance_type = "t3a.small"
  subnet        = "subnet-xxx"

  # Additional Network Interface
  network_interface = [
    {
      delete_on_termination = true
      device_index = 0
      network_interface_id = aws_network_interface.example.id
    }
  ]

  # Mandatory tags
  tags = {
    Name             = "example_ec2"
    ResourceName     = "USAEA1PWBUAS01"
    ResourceOwner    = "owner@email.com"
    ResourceAppRole  = "app"
    Environment      = "sbx"
    CostString       = "1234.CC.123.123456"
    AppID            = "12345"
    adDomain         = "gdc.local"
    CentrifyUnixRole = "UNX-ADM_example_ec2_servers"
  }
}
```

### Instance with Multiple Additional ENIs

```HCL
module "ec2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ec2-innersource.git?ref=4.2.1"

  ec2_name      = "example_ec2"
  ami           = "amzn_lnx_2023"
  instance_type = "t3a.medium"  # Supports up to 4 ENIs total
  subnet        = "subnet-xxx"

  # Multiple additional ENIs - all must be in same AZ as main instance
  additional_enis = [
    {
      # ENI for management traffic - same subnet (same AZ)
      subnet_id         = "subnet-xxx"
      device_index      = 1
      private_ips_count = 2
      description       = "Management ENI"
      tags = {
        Purpose = "Management"
        Tier    = "Control"
      }
    },
    {
      # ENI for application traffic - different subnet in SAME AZ with custom security groups
      subnet_id       = "subnet-yyy"  # Must be in same AZ as subnet-xxx
      device_index      = 2
      private_ips_count = 1
      security_groups = ["sg-app-xxx"]
      description     = "Application ENI"
      tags = {
        Purpose = "Application"
        Tier    = "App"
      }
    },
    {
      # ENI for database traffic - same subnet with specific IPs
      subnet_id = "subnet-xxx"
      device_index      = 3
      private_ip_list = ["10.0.1.100", "10.0.1.101"]
      description = "Database ENI"
      tags = {
        Purpose = "Database"
        Tier    = "Data"
      }
    }
  ]

  # Security Group configuration
  security_group_name          = "example_sg"
  security_group_description   = "example sg"
  security_group_ingress_rules = [
    {
      description = "ssh"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]

  tags = {
    Name             = "example_ec2"
    ResourceName     = "USAEA1PWBUAS01"
    ResourceOwner    = "owner@email.com"
    ResourceAppRole  = "app"
    Environment      = "sbx"
    CostString       = "1234.CC.123.123456"
    AppID            = "12345"
    adDomain         = "gdc.local"
    CentrifyUnixRole = "UNX-ADM_example_ec2_servers"
  }
}
```

### Instance with Shared Security Group

This example is the recommended way of having multiple instances share a single security group.

```HCL
module "security_group" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git"

  security_group_name        = "example_sg"
  security_group_description = "Security group for example_ec2"
  vpc_id                     = "<VPC ID>"

  # Set this to "linux" or "windows" to configure default EC2 agent rules
  ec2_agent_rules = "linux"

  security_group_ingress_rules = [<ingress_rules>]
  security_group_egress_rules  = [<egress rules>]

  tags = {
    Environment = "sbx"
    CostString  = "1234.CC.123.123456"
    AppID       = "12345"
  }
}

module "ec2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ec2-innersource.git?ref=4.2.1"

  ec2_name      = "example_ec2"
  ami           = "amzn_lnx_2023"
  instance_type = "t3a.small"
  subnet        = "subnet-xxx"

  # Use created security group
  exclude_default_security_group = true
  security_groups = [module.security_group.id]

  # Mandatory tags
  tags = {
    Name             = "example_ec2"
    ResourceName     = "USAEA1PWBUAS01"
    ResourceOwner    = "owner@email.com"
    ResourceAppRole  = "app"
    Environment      = "sbx"
    CostString       = "1234.CC.123.123456"
    AppID            = "12345"
    adDomain         = "gdc.local"
    CentrifyUnixRole = "UNX-ADM_example_ec2_servers"
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0.0 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.1 |
| <a name="module_cloudwatch_role"></a> [cloudwatch\_role](#module\_cloudwatch\_role) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam | 1.9.8 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |
| <a name="module_security_group"></a> [security\_group](#module\_security\_group) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git | 3.8.1 |

## Resources

| Name | Type |
|------|------|
| [aws_ebs_volume.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) | resource |
| [aws_instance.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_network_interface.multiple](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_interface) | resource |
| [aws_volume_attachment.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/volume_attachment) | resource |
| [aws_ami.exp_amzn_lnx_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_eks_amzn_lnx_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_gpu_eks_amzn_lnx_2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_rhel_10](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_rhel_8](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_rhel_9](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_sles_15](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_win_2019](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_win_2022](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ami.exp_win_2025](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zone.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zone) | data source |
| [aws_default_tags.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_iam_policy_document.cloudwatch_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.cloudwatch_trust_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_additional_eni_security_groups"></a> [additional\_eni\_security\_groups](#input\_additional\_eni\_security\_groups) | A list of Security Group IDs to associate with the additional ENIs. | `list(string)` | `null` | no |
| <a name="input_additional_enis"></a> [additional\_enis](#input\_additional\_enis) | (Optional) List of additional ENIs to create and attach to the instance.<br/>    Each ENI can be configured with:<br/>    - subnet\_id: Subnet ID where the ENI will be created (defaults to main instance subnet)<br/>    - security\_groups: List of security group IDs (defaults to instance security groups)<br/>    - private\_ips: List of private IPs to assign without regard to order<br/>    - private\_ips\_count: Number of secondary private IPs to assign to the ENI. The total number of private IPs will be 1 + private\_ips\_count, as a primary private IP will be assigned to an ENI by default.<br/>    - private\_ip\_list: List of private IPs in sequential order<br/>    - description: Description for the ENI<br/>    - tags: Additional tags for the ENI<br/><br/>    Note:<br/>    - If migrating from previous modules the `device_index` must be 1 for existing ENI to be preserved<br/>    - Only one of `private_ips`, `private_ips_count`, or `private_ip_list` can be set per ENI (mutually exclusive).<br/>    - Additional ENIs must have a greater than 0 `device_index`.<br/>    - All ENIs must be in subnets within the same Availability Zone as the main instance.<br/>    - Instance type limits the total number of ENIs (https://docs.aws.amazon.com/ec2/latest/instancetypes/gp.html#gp_network.) | <pre>list(object({<br/>    device_index      = number<br/>    subnet_id         = optional(string)<br/>    security_groups   = optional(list(string))<br/>    private_ips       = optional(list(string))<br/>    private_ips_count = optional(number)<br/>    private_ip_list   = optional(list(string))<br/>    description       = optional(string)<br/>    tags              = optional(map(string), {})<br/>  }))</pre> | `[]` | no |
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | List of SNS topics triggered by alarm events. providing a list will automatically enable alarm actions | `list(string)` | `[]` | no |
| <a name="input_ami"></a> [ami](#input\_ami) | The AMI to use for the instance | `string` | n/a | yes |
| <a name="input_cloudwatch_log_retention"></a> [cloudwatch\_log\_retention](#input\_cloudwatch\_log\_retention) | The number of days for log retention. Only used if `enable_cloudwatch_agent` is set to `true` | `number` | `14` | no |
| <a name="input_cloudwatch_role_policies"></a> [cloudwatch\_role\_policies](#input\_cloudwatch\_role\_policies) | List of additional JSON IAM policy documents to attach to the created `BURoleForEC2CloudWatchIntegration` role. Only used if `enable_cloudwatch_agent` is set to `true` | `list(string)` | `[]` | no |
| <a name="input_cloudwatch_tags"></a> [cloudwatch\_tags](#input\_cloudwatch\_tags) | Cloudwatch Alarm tags (in addition to the `non_instance_tags`). See https://experian.atlassian.net/wiki/x/swH3E for all available tags | `map(string)` | `{}` | no |
| <a name="input_create_cloudwatch_role"></a> [create\_cloudwatch\_role](#input\_create\_cloudwatch\_role) | Create and associate the `BURoleForEC2CloudWatchIntegration` role with the instance. Required if `enable_cloudwatch_agent` is set to `true` and `instance_profile` has not been set to `BURoleForEC2CloudWatchIntegration` or another role with the required permissions | `bool` | `false` | no |
| <a name="input_delete_on_termination"></a> [delete\_on\_termination](#input\_delete\_on\_termination) | Whether the volume should be destroyed on instance termination | `bool` | `true` | no |
| <a name="input_detailed_monitoring"></a> [detailed\_monitoring](#input\_detailed\_monitoring) | If `true`, the launched EC2 instance will have detailed monitoring enabled. If left at the default `null`, then this will automatically be set to `true` for resources with an 'Environment' tag of value 'prd', and set to `false` for other environments. This is a cost-saving measure | `bool` | `null` | no |
| <a name="input_disable_default_alarms"></a> [disable\_default\_alarms](#input\_disable\_default\_alarms) | To disable the best practice AWS alarms for EC2 instances outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#EC2) | `bool` | `false` | no |
| <a name="input_disable_instance_scheduler"></a> [disable\_instance\_scheduler](#input\_disable\_instance\_scheduler) | To disable the automatic configuring of [EEC AWS Instance Scheduler](https://experian.atlassian.net/wiki/x/yxL3E) Instance-Scheduler tag. Note that only those instances that are tagged as sandbox will get this configured currently, though it may be rolled out to other environments later | `bool` | `false` | no |
| <a name="input_ebs_block_device"></a> [ebs\_block\_device](#input\_ebs\_block\_device) | Additional EBS block devices to attach to the instance. <br/>    Note if `kms_key_id` is used then Terraform must have the GenerateDataKeyWithoutPlaintext permission on the KMS key to prevent a volume from being created and immediately deleted. See [aws\_ebs\_volume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ebs_volume) for details on values).<br/>    `iops` must be specified if type is `io1` or `io2`. Minimum value is 100.<br/>    - For `io1`, maximum value is 64000.<br/>    - For `io2`, volumes greater than 16 TiB or 64K IOPS or 500:1 IOPS:GB ratio are only supported on instances compatible with io2 Block Express.<br/>    For `gp3`:<br/>    - `throughput` value must be between 125 and 1000 (Optional. If omitted, default is 125).<br/>    - `iops` value must be between 100 and 16000 (Optional. If omitted, the default value is 3000). | <pre>list(object({<br/>    device_name = string<br/>    volume_size = number<br/>    volume_type = optional(string, "gp3")<br/>    iops        = optional(number)<br/>    throughput  = optional(number)<br/>    snapshot_id = optional(string)<br/>    kms_key_id  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_ebs_optimized"></a> [ebs\_optimized](#input\_ebs\_optimized) | Launched EC2 instance will be EBS-optimized | `bool` | `true` | no |
| <a name="input_ebs_volume_tags"></a> [ebs\_volume\_tags](#input\_ebs\_volume\_tags) | EBS volume(s) tags (root volume and any additional one(s)). See https://experian.atlassian.net/wiki/x/swH3E for all available tags | `map(string)` | `{}` | no |
| <a name="input_ec2_name"></a> [ec2\_name](#input\_ec2\_name) | Name of the EC2 instance (to populate tags if missing). Please read [EC2 Instance Naming Convention](https://experian.atlassian.net/wiki/x/zgL3E#HowtobuildEC2instancesusingtheExperianGoldenAMIs-EC2instanceNamingconvention) for guidance. | `string` | `""` | no |
| <a name="input_enable_all_alarm_actions"></a> [enable\_all\_alarm\_actions](#input\_enable\_all\_alarm\_actions) | Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions | `bool` | `false` | no |
| <a name="input_enable_cloudwatch_agent"></a> [enable\_cloudwatch\_agent](#input\_enable\_cloudwatch\_agent) | To enable the CloudWatch agent on an instance built with an EEC AMI. Please see README.md for more details | `bool` | `false` | no |
| <a name="input_exclude_default_security_group"></a> [exclude\_default\_security\_group](#input\_exclude\_default\_security\_group) | If set to `true`, default Experian security group rules will not be added. Note that this could break communication with security agents, potentially triggering security alerts! | `bool` | `false` | no |
| <a name="input_instance_profile"></a> [instance\_profile](#input\_instance\_profile) | A pre-defined profile to attach to the instance (default is 'eec-aws-amifactory-sc-iam-ec2role') | `string` | `"eec-aws-amifactory-sc-iam-ec2role"` | no |
| <a name="input_instance_type"></a> [instance\_type](#input\_instance\_type) | The type of the instance. By default it is `t3a.small` | `string` | `"t3a.small"` | no |
| <a name="input_metadata_http_endpoint_enabled"></a> [metadata\_http\_endpoint\_enabled](#input\_metadata\_http\_endpoint\_enabled) | Whether the metadata service is available | `bool` | `true` | no |
| <a name="input_metadata_http_put_response_hop_limit"></a> [metadata\_http\_put\_response\_hop\_limit](#input\_metadata\_http\_put\_response\_hop\_limit) | The desired HTTP PUT response hop limit (between 1 and 64) for instance metadata requests. | `number` | `1` | no |
| <a name="input_metadata_http_tokens_required"></a> [metadata\_http\_tokens\_required](#input\_metadata\_http\_tokens\_required) | Whether or not the metadata service requires session tokens, also referred to as Instance Metadata Service Version 2. | `bool` | `true` | no |
| <a name="input_metadata_tags_enabled"></a> [metadata\_tags\_enabled](#input\_metadata\_tags\_enabled) | Whether the tags are enabled in the metadata service. | `bool` | `false` | no |
| <a name="input_network_interface"></a> [network\_interface](#input\_network\_interface) | Customize network interfaces to be attached at instance boot time | `list(map(string))` | `null` | no |
| <a name="input_operating_system"></a> [operating\_system](#input\_operating\_system) | The operating system of the instance. <br/>  If you set the `ami` variable with a specific AMI ID, and omit or set `exclude_default_security_group` to `false`, then you must set this to either `linux` or `windows` | `string` | `""` | no |
| <a name="input_private_ip"></a> [private\_ip](#input\_private\_ip) | Private IP address to associate with the instance in the VPC | `string` | `null` | no |
| <a name="input_root_volume_iops"></a> [root\_volume\_iops](#input\_root\_volume\_iops) | Amount of provisioned IOPS for the Root volume. This must be set if root\_volume\_type is set of `io1`, `io2` or `gp3` | `number` | `0` | no |
| <a name="input_root_volume_kms_key_id"></a> [root\_volume\_kms\_key\_id](#input\_root\_volume\_kms\_key\_id) | KMS key ID used to encrypt the root volume. Modifying this value requires resource replacement | `string` | `null` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Size of the root volume in gigabytes | `number` | `null` | no |
| <a name="input_root_volume_throughput"></a> [root\_volume\_throughput](#input\_root\_volume\_throughput) | Amount of throughput for the Root volume. This must be set if root\_volume\_type is set to `gp3` | `number` | `0` | no |
| <a name="input_root_volume_type"></a> [root\_volume\_type](#input\_root\_volume\_type) | Type of root volume. Can be `standard`, `gp2`*, `gp3`, `io1` or `io2`. *Only in local zones where `gp3` is not supported. | `string` | `"gp3"` | no |
| <a name="input_secondary_private_ips"></a> [secondary\_private\_ips](#input\_secondary\_private\_ips) | List of secondary private IP addresses to associate with the instance in the VPC | `list(string)` | `null` | no |
| <a name="input_security_group_description"></a> [security\_group\_description](#input\_security\_group\_description) | The Security Group description. | `string` | `"EC2 Security Group"` | no |
| <a name="input_security_group_egress_rules"></a> [security\_group\_egress\_rules](#input\_security\_group\_egress\_rules) | A list of Security Group EGRESS rule objects. The `self` key dictates whether the security group itself will be added as a source to the rule. Although `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, and `security_groups` are all marked as optional, you must provide at least ne of them in order to configure the source of the traffic. See [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for details on values | <pre>list(object({<br/>    description      = optional(string)<br/>    from_port        = optional(number)<br/>    to_port          = optional(number)<br/>    protocol         = string<br/>    cidr_blocks      = optional(list(string))<br/>    ipv6_cidr_blocks = optional(list(string))<br/>    prefix_list_ids  = optional(list(string))<br/>    security_groups  = optional(list(string))<br/>    self             = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_security_group_ingress_rules"></a> [security\_group\_ingress\_rules](#input\_security\_group\_ingress\_rules) | A list of Security Group INGRESS rule objects. The `self` key dictates whether the security group itself will be added as a source to the rule. Although `cidr_blocks`, `ipv6_cidr_blocks`, `prefix_list_ids`, and `security_groups` are all marked as optional, you must provide at least ne of them in order to configure the source of the traffic. See [eits-tf-aws-security-group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) for details on values | <pre>list(object({<br/>    description      = optional(string)<br/>    from_port        = optional(number)<br/>    to_port          = optional(number)<br/>    protocol         = string<br/>    cidr_blocks      = optional(list(string))<br/>    ipv6_cidr_blocks = optional(list(string))<br/>    prefix_list_ids  = optional(list(string))<br/>    security_groups  = optional(list(string))<br/>    self             = optional(bool, false)<br/>  }))</pre> | `[]` | no |
| <a name="input_security_group_name"></a> [security\_group\_name](#input\_security\_group\_name) | Name of the security group. It must be unique. If omitted, Terraform will assign a random, unique name. | `string` | `null` | no |
| <a name="input_security_group_tags"></a> [security\_group\_tags](#input\_security\_group\_tags) | Security group tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags | `map(string)` | `{}` | no |
| <a name="input_security_groups"></a> [security\_groups](#input\_security\_groups) | A list of Security Group IDs to associate with EC2 instance. | `list(string)` | `[]` | no |
| <a name="input_ssh_key_pair"></a> [ssh\_key\_pair](#input\_ssh\_key\_pair) | SSH key pair to be provisioned on the instance | `string` | `null` | no |
| <a name="input_subnet"></a> [subnet](#input\_subnet) | VPC Subnet ID the instance is launched in | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | EC2 instance tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags | `map(string)` | `{}` | no |
| <a name="input_termination_protection"></a> [termination\_protection](#input\_termination\_protection) | If `true`, enable termination protection for the EC2 instance. See [EC2 Instance Termination Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html#Using_ChangingDisableAPITermination). If left at the default `null`, then this will automatically be set to `true` for resources with an 'Environment' tag of value 'prd', and set to `false` for other environments | `bool` | `null` | no |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | The user data to provide when launching the instance. Do not pass gzip-compressed data via this argument; use `user_data_base64` instead | `string` | `null` | no |
| <a name="input_user_data_base64"></a> [user\_data\_base64](#input\_user\_data\_base64) | Can be used instead of `user_data` to pass base64-encoded binary data directly. Use this instead of `user_data` whenever the value is not a valid UTF-8 string. For example, gzip-encoded user data must be base64-encoded and passed via this argument to avoid corruption | `string` | `null` | no |
| <a name="input_user_data_replace_on_change"></a> [user\_data\_replace\_on\_change](#input\_user\_data\_replace\_on\_change) | When used in combination with `user_data` or `user_data_base64` will trigger a destroy and recreate when set to true. Defaults to false if not set. | `bool` | `false` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the VPC that the instance security group belongs to. If not supplied will automatically get the VPC ID from `subnet` variable | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_ami_id"></a> [ami\_id](#output\_ami\_id) | ID of the AMI used to create the instance |
| <a name="output_arn"></a> [arn](#output\_arn) | ARN of the instance |
| <a name="output_id"></a> [id](#output\_id) | Disambiguated ID of the instance |
| <a name="output_multiple_network_interfaces"></a> [multiple\_network\_interfaces](#output\_multiple\_network\_interfaces) | Map of additional network interfaces with their IDs and private DNS names |
| <a name="output_name"></a> [name](#output\_name) | Instance name |
| <a name="output_private_dns"></a> [private\_dns](#output\_private\_dns) | Private DNS of instance |
| <a name="output_private_ip"></a> [private\_ip](#output\_private\_ip) | Private IP of instance |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group created for the EC2 instance |
| <a name="output_security_group_ids"></a> [security\_group\_ids](#output\_security\_group\_ids) | IDs on the AWS Security Groups associated with the instance |
| <a name="output_ssh_key_pair"></a> [ssh\_key\_pair](#output\_ssh\_key\_pair) | Name of the SSH key pair provisioned on the instance |
| <a name="output_tags"></a> [tags](#output\_tags) | Map of tags assigned to the resource, including those inherited from the provider `default_tags` configuration block |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS EC2 instances
region: Global
bu: EITS
docs: https://experian.atlassian.net/wiki/x/HQ4EF
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>
```
