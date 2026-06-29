# EITS Cloud Enablement AWS FSx for Windows File Server Module

EITS Terraform module which creates [AWS FSx for Windows File Server](https://docs.aws.amazon.com/fsx/latest/WindowsGuide/) on AWS. This module will:

- Create a Windows File Server.
- Create a default Security Group, if required.
- Create a default Cloudwatch Log Group, if required.
- Create a default KMS key, if required.

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

## EITS Security & Compliance

**Last Module Review**: 2026-03-13

See below for the date and results of our EITS security and compliance scanning.

<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-03-30 | 1.11.4 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-03-30 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-03-30 | 0.69.3 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-03-30 | 1.34.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Notes

- By default, a Security Group is created, allowing access from all the CIDRs in the selected VPC. This is created when `security_group_ids` is not provided.
- By default, a Cloudwatch Log Group is created to store `FAILURE_ONLY` file access and share audit logs. The default retention is `90` days for production environments, and `30` days for all the other environmnets. To disable this, configure `create_cloudwatch_log_group` to `false`. Note that, if you disable this, don't specify anything under `audit_log_configuration.audit_log_destination`, and don't disable the audit, AWS FSx will automatically create a Log Group called `aws/fsx/windows` with a retention setting of `Never expire`.
- By default, FSx automatic backup is enabled with a 30 days retention. It is recommended to use AWS Backup or other tools for better control.
- By default, the maintenance window is configured on Sundays at 11:30pm UTC.
- Currently, only `Self-managed Microsoft Active Directory` is supported.
- FSx deployment type is enforced to `MULTI_AZ_1` for production environment.
- A KMS CMK key is required for production environment. You can either supply your own, or have one created for you by setting `create_kms_key` to `true`.
- It is recommended to store the AD credentials in a secure store. If using AWS Secrets Manager, please check out [our module](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-secrets-manager).

## Usage

For valid values, please see the variables documentation below.
For more examples, please see the code under the [tests](tests) folder.

```hcl

module "fsx_windows" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-fsx-windows.git"
  
  name                        = "<name>"
  subnet_ids                  = [<subnet_ids>]
  throughput_capacity         = <throughput>

  self_managed_active_directory = {
    dns_ips     = [<dns_ips>]
    domain_name = "<domain_name>"
    username    = <ad_username>
    password    = <ad_password> # Don't store this in plain text!
    file_system_administrators_group = "<optional_fs_admin_group>"
    # organizational_unit_distinguished_name = "<optional_ou>"
  }
  
  tags = var.tags
}

```

## Contact

For advice or to report an issue, either email the EITS Cloud Enablement team <eitsukicloud@experian.com> or post in the [Terraform Modules Teams Channel](https://teams.microsoft.com/l/channel/19%3a8c4faa258cd54d2687caa746f71ae050%40thread.tacv2/Terraform%2520Modules?groupId=c08d819b-fd4a-44e1-98f1-225d1bb48b31&tenantId=be67623c-1932-42a6-9d24-6c359fe5ea71)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.32.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.32.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.0 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |
| <a name="module_fsx_cloudwatch_log_group"></a> [fsx\_cloudwatch\_log\_group](#module\_fsx\_cloudwatch\_log\_group) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-logs | 2.6.1 |
| <a name="module_fsx_kms"></a> [fsx\_kms](#module\_fsx\_kms) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms | 1.9.0 |
| <a name="module_fsx_security_group"></a> [fsx\_security\_group](#module\_fsx\_security\_group) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-security-group.git | 3.5.1 |

## Resources

| Name | Type |
|------|------|
| [aws_fsx_backup.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fsx_backup) | resource |
| [aws_fsx_windows_file_system.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/fsx_windows_file_system) | resource |
| [aws_default_tags.account_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/subnet) | data source |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | List of SNS topics triggered by alarm events. providing a list will automatically enable alarm actions | `list(string)` | `[]` | no |
| <a name="input_alarm_thresholds"></a> [alarm\_thresholds](#input\_alarm\_thresholds) | Threshold for the default utilization alarms (in %).<br/>  <pre>alarm\_thresholds = {<br/>    storage\_capacity\_utilization (Default 85)<br/>    network\_capacity\_utilization (Default 85)<br/>    disk\_iops\_utilization        (Default 85)<br/>    fs\_disk\_iops\_utilization     (Default 85)<br/>  }</pre> | <pre>object({<br/>    storage_capacity_utilization = optional(number, 85)<br/>    network_capacity_utilization = optional(number, 85)<br/>    disk_iops_utilization        = optional(number, 85)<br/>    fs_disk_iops_utilization     = optional(number, 85)<br/>  })</pre> | `{}` | no |
| <a name="input_aliases"></a> [aliases](#input\_aliases) | An array DNS alias names that you want to associate with the Amazon FSx file system. | `list(string)` | `[]` | no |
| <a name="input_audit_log_configuration"></a> [audit\_log\_configuration](#input\_audit\_log\_configuration) | The configuration that Amazon FSx for Windows File Server uses to audit and log user accesses of files, folders, and file shares on the file system.<br/>  <pre>audit\_log\_configuration = {<br/>    audit\_log\_destination - (Optional) The ARN for the destination of the audit logs. <br/>                            The destination can be any Amazon CloudWatch Logs log group ARN or Amazon Kinesis Data Firehose delivery stream ARN. <br/>                            Can be specified when <i>file\_access\_audit\_log\_level</i> and <i>file\_share\_access\_audit\_log\_level</i> are not set to <i>DISABLED</i>. <br/>                            The name of the Amazon CloudWatch Logs log group must begin with the <i>/aws/fsx</i> prefix. <br/>                            The name of the Amazon Kinesis Data Firehouse delivery stream must begin with the <i>aws-fsx</i> prefix. <br/>                            If you do not provide a destination in <i>audit\_log\_destionation</i>, Amazon FSx will create and use a log stream in the CloudWatch Logs <i>/aws/fsx/windows</i> log group.<br/>    file\_access\_audit\_log\_level - (Optional) Sets which attempt type is logged by Amazon FSx for file and folder accesses. <br/>                                  Valid values are <i>SUCCESS\_ONLY</i>, <i>FAILURE\_ONLY</i>, <i>SUCCESS\_AND\_FAILURE</i>, and <i>DISABLED</i>. Default value is <i>DISABLED</i>.<br/>    file\_share\_access\_audit\_log\_level - (Optional) Sets which attempt type is logged by Amazon FSx for file share accesses. <br/>                                        Valid values are <i>SUCCESS\_ONLY</i>, <i>FAILURE\_ONLY</i>, <i>SUCCESS\_AND\_FAILURE</i>, and <i>DISABLED</i>. Default value is <i>DISABLED</i>.<br/>  }</pre> | <pre>object({<br/>    audit_log_destination             = optional(string)<br/>    file_access_audit_log_level       = optional(string, "FAILURE_ONLY")<br/>    file_share_access_audit_log_level = optional(string, "FAILURE_ONLY")<br/>  })</pre> | `{}` | no |
| <a name="input_automatic_backup_retention_days"></a> [automatic\_backup\_retention\_days](#input\_automatic\_backup\_retention\_days) | The number of days to retain automatic backups. Minimum of `0` and maximum of `90`. Set to `0` to disable. | `number` | `30` | no |
| <a name="input_backup_id"></a> [backup\_id](#input\_backup\_id) | The ID of the source backup to create the filesystem from. | `string` | `null` | no |
| <a name="input_cloudwatch_log_group_retention"></a> [cloudwatch\_log\_group\_retention](#input\_cloudwatch\_log\_group\_retention) | Number of days to retain logs in the CloudWatch log group. Defaults to `90` for production and `30` for non-production environments if not specified. | `number` | `null` | no |
| <a name="input_cloudwatch_tags"></a> [cloudwatch\_tags](#input\_cloudwatch\_tags) | Cloudwatch Alarm tags. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags | `map(string)` | `{}` | no |
| <a name="input_copy_tags_to_backups"></a> [copy\_tags\_to\_backups](#input\_copy\_tags\_to\_backups) | A boolean flag indicating whether tags on the file system should be copied to backups. | `bool` | `false` | no |
| <a name="input_create_cloudwatch_log_group"></a> [create\_cloudwatch\_log\_group](#input\_create\_cloudwatch\_log\_group) | Determines whether a default log group is created. | `bool` | `true` | no |
| <a name="input_create_kms_key"></a> [create\_kms\_key](#input\_create\_kms\_key) | Determines whether a default KMS key is created. A KMS CMK key is required for production environments. | `bool` | `false` | no |
| <a name="input_daily_automatic_backup_start_time"></a> [daily\_automatic\_backup\_start\_time](#input\_daily\_automatic\_backup\_start\_time) | The preferred time (in `HH:MM` format) to take daily automatic backups, in the UTC time zone. | `string` | `null` | no |
| <a name="input_deployment_type"></a> [deployment\_type](#input\_deployment\_type) | Specifies the file system deployment type, valid values are `MULTI_AZ_1`, `SINGLE_AZ_1` and `SINGLE_AZ_2`. <br/>  Enforced to `MULTI_AZ_1` for Production environment. | `string` | `null` | no |
| <a name="input_disk_iops_configuration"></a> [disk\_iops\_configuration](#input\_disk\_iops\_configuration) | The SSD IOPS configuration for the Amazon FSx for Windows File Server file system<br/>  <pre>disk\_iops\_configuration = {<br/>    iops - (Optional) The total number of SSD IOPS provisioned for the file system.<br/>    mode - (Optional) Specifies whether the number of IOPS for the file system is using the system. <br/>           Valid values are <i>AUTOMATIC</i> and <i>USER\_PROVISIONED</i>. Default value is <i>AUTOMATIC</i>.<br/>  }</pre> | <pre>object({<br/>    iops = optional(number)<br/>    mode = optional(string)<br/>  })</pre> | `null` | no |
| <a name="input_enable_all_alarm_actions"></a> [enable\_all\_alarm\_actions](#input\_enable\_all\_alarm\_actions) | Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions, if enabled. | `bool` | `false` | no |
| <a name="input_enable_default_alarms"></a> [enable\_default\_alarms](#input\_enable\_default\_alarms) | Set to `true` to enable FSx default utilization alarms | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | ARN for the KMS Key to encrypt the file system at rest. Defaults to an AWS managed KMS Key. | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | The name of the file system. | `string` | `""` | no |
| <a name="input_preferred_subnet_id"></a> [preferred\_subnet\_id](#input\_preferred\_subnet\_id) | Specifies the subnet in which you want the preferred file server to be located. <br/>  Required for when deployment type is `MULTI_AZ_1`. | `string` | `null` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | A list of IDs for the security groups that apply to the specified network interfaces created for file system access. <br/>  These security groups will apply to all network interfaces. | `list(string)` | `[]` | no |
| <a name="input_self_managed_active_directory"></a> [self\_managed\_active\_directory](#input\_self\_managed\_active\_directory) | Configuration block that Amazon FSx uses to join the Windows File Server instance to your self-managed (including on-premises) Microsoft Active Directory.<br/>  <pre>self\_managed\_active\_directory = {<br/>    dns\_ips - (Required) A list of up to two IP addresses of DNS servers or domain controllers in the self-managed AD directory. <br/>              The IP addresses need to be either in the same VPC CIDR range as the file system or in the private IP version 4 (IPv4) address ranges as specified in [RFC 1918](https://tools.ietf.org/html/rfc1918).<br/>    domain\_name - (Required) The fully qualified domain name of the self-managed AD directory. For example, <i>uk.experian.local</i>.<br/>    username - (Required) The user name for the service account on your self-managed AD domain that Amazon FSx will use to join to your AD domain.<br/>    password - (Required) The password for the service account on your self-managed AD domain that Amazon FSx will use to join to your AD domain. <br/>               Please don't store this in plain text!<br/>    file\_system\_administrators\_group - (Optional) The name of the domain group whose members are granted administrative privileges for the file system. <br/>    Administrative privileges include taking ownership of files and folders, and setting audit controls (audit ACLs) on files and folders. <br/>    The group that you specify must already exist in your domain. Defaults to <i>Domain Admins</i>.<br/>    organizational\_unit\_distinguished\_name - (Optional) The FQDN of the organizational unit within your self-managed AD directory that the Windows File Server instance will join. <br/>    For example, <i>OU=FSx,DC=uk,DC=experian,DC=local</i>. Only accepts OU as the direct parent of the file system. <br/>    If none is provided, the FSx file system is created in the default location of your self-managed AD directory. <br/>    To learn more, see [RFC 2253](https://tools.ietf.org/html/rfc2253).<br/>  }</pre> | <pre>object({<br/>    dns_ips                                = list(string)<br/>    domain_name                            = string<br/>    file_system_administrators_group       = optional(string)<br/>    organizational_unit_distinguished_name = optional(string)<br/>    username                               = string<br/>    password                               = string<br/>  })</pre> | n/a | yes |
| <a name="input_skip_final_backup"></a> [skip\_final\_backup](#input\_skip\_final\_backup) | When enabled, will skip the default final backup taken when the file system is deleted. <br/>  This configuration must be applied separately before attempting to delete the resource to have the desired behavior. | `bool` | `false` | no |
| <a name="input_storage_capacity"></a> [storage\_capacity](#input\_storage\_capacity) | Storage capacity (GiB) of the file system. Minimum of `32` and maximum of `65536`. <br/>  If the storage type is set to HDD the minimum value is `2000`. Required when not creating filesystem for a backup. | `number` | `32` | no |
| <a name="input_storage_type"></a> [storage\_type](#input\_storage\_type) | Specifies the storage type, Valid values are `SSD` and `HDD`. <br/>  `HDD` is supported on `SINGLE_AZ_2` and `MULTI_AZ_1` Windows file system deployment types. | `string` | `"SSD"` | no |
| <a name="input_subnet_ids"></a> [subnet\_ids](#input\_subnet\_ids) | A list of IDs for the subnets that the file system will be accessible from. <br/>  To specify more than a single subnet set `deployment_type` to `MULTI_AZ_1`. | `list(string)` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | A map of tags to add to all resources. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags. | `map(string)` | `{}` | no |
| <a name="input_throughput_capacity"></a> [throughput\_capacity](#input\_throughput\_capacity) | Throughput (megabytes per second) of the file system in power of `2` increments. Minimum of `8` and maximum of `2048`. | `number` | n/a | yes |
| <a name="input_timeouts"></a> [timeouts](#input\_timeouts) | `create`, `update`, and `delete` timeout configurations for the file system.<br/>  <pre>timeouts = {<br/>    create - (Default 60m)<br/>    delete - (Default 30m)<br/>    update - (Default 45m)<br/>  }</pre> | <pre>object({<br/>    create = optional(string, "60m")<br/>    delete = optional(string, "30m")<br/>    update = optional(string, "45m")<br/>  })</pre> | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | The ID of the VPC in which the file system will be created. If not specified, the VPC will be automatically selected. <br/>  Please note that this would only work if there is only one VPC in the region. If you have multiple VPCs, you must specify the VPC ID. | `string` | `null` | no |
| <a name="input_weekly_maintenance_start_time"></a> [weekly\_maintenance\_start\_time](#input\_weekly\_maintenance\_start\_time) | The preferred start time (in `d:HH:MM` format) to perform weekly maintenance, in the UTC time zone. Defaults to `Sunday 11pm`. | `string` | `"7:23:00"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_cloudwatch_log_group_arn"></a> [cloudwatch\_log\_group\_arn](#output\_cloudwatch\_log\_group\_arn) | Arn of the created Cloudwatch Log Group. |
| <a name="output_cloudwatch_log_group_name"></a> [cloudwatch\_log\_group\_name](#output\_cloudwatch\_log\_group\_name) | Name of the created Cloudwatch Log Group. |
| <a name="output_file_system_arn"></a> [file\_system\_arn](#output\_file\_system\_arn) | Amazon Resource Name (ARN) of the file system. |
| <a name="output_file_system_dns_name"></a> [file\_system\_dns\_name](#output\_file\_system\_dns\_name) | DNS name for the file system, e.g., `fs-12345678.fsx.us-west-2.amazonaws.com` (domain name matching the Active Directory domain name). |
| <a name="output_file_system_id"></a> [file\_system\_id](#output\_file\_system\_id) | Identifier of the file system, e.g., `fs-12345678` |
| <a name="output_file_system_network_interface_ids"></a> [file\_system\_network\_interface\_ids](#output\_file\_system\_network\_interface\_ids) | Set of Elastic Network Interface identifiers from which the file system is accessible. |
| <a name="output_file_system_preferred_file_server_ip"></a> [file\_system\_preferred\_file\_server\_ip](#output\_file\_system\_preferred\_file\_server\_ip) | IP address of the primary, or preferred, file server. |
| <a name="output_file_system_remote_administration_endpoint"></a> [file\_system\_remote\_administration\_endpoint](#output\_file\_system\_remote\_administration\_endpoint) | For `MULTI_AZ_1` deployment types, use this endpoint when performing administrative tasks on the file system using Amazon FSx Remote PowerShell. For `SINGLE_AZ_1` deployment types, this is the DNS name of the file system. |
| <a name="output_security_group_arn"></a> [security\_group\_arn](#output\_security\_group\_arn) | Amazon Resource Name (ARN) of the created Security Group. |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group of the created Security Group. |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS FSx for Windows File Server
region: Global
bu: EITS
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>
  product: 
```
