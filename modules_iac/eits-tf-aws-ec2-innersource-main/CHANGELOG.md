# CHANGE LOG

## 4.3.2 - 29th September 2026

- Updated EC2 naming convention and metadata hops checks
- Removed deprecated checks
- Bumped `eits-tf-aws-security-group` version to `3.8.1`
- Bumped `eits-tf-aws-cloudwatch-alarm` version to `1.3.1`
- Bumped `eits-tf-aws-iam` version to `1.9.8`

## 4.3.1 - 14th September 2026

- Updated confluence document links

## 4.3.0 - 14th September 2026

- Added support for RHEL10

## 4.2.3 - 19th August 2026

- Added validation for Dynatrace tags
- Fixed condition for `ec2_agent_rules`

## 4.2.2 - 4th August 2026

- Dependency update: Updated security module to version 3.7.0 **NOTE: This improves the Tanium rules and restricts them to specific ranges which causes expected resource removals and additions in existing deployed infrastructure. See the [Security Group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) module for more information. These rules are controlled by the existing `exclude_default_security_group` variable in this module**

## 4.2.1 - 20th July 2026

- Dependency update: Updated Security Group module to version 3.6.0 **NOTE: This update contains extra default security rules for Cyberark and Bladelogic. See the [Security Group](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-security-group/browse) module for more information. These rules are controlled by the existing `exclude_default_security_group` variable in this module**
- Dependency update: Updated IAM module to version 1.9.7
- Updated pre-commit config to version 1.4.0

## 4.2.0 - 13th April 2026

- Added `windows_2025` AMI
- Whitelisted new Instance Scheduler tags `IS-LastAction` and `IS-ManagedBy`

## 4.1.0 - 2nd February 2026

- Added `enable_all_alarm_actions` variable
- Changed default behaviour for alarm actions. Only `ALARM` will always be enabled when `alarm_sns_topics` is specified

## 4.0.2 - 18th December 2025

- Excluded more `eitsce:` AWS Backup tags used by managed AWS Backup solution

## 4.0.1 - 10th December 2025

- Updated `eits-tf-aws-iam` module to version `1.9.2`

## 4.0.0 - 1st October 2025

*** THIS IS A BREAKING UPDATE ONLY IF USING ADDITIONAL ENIS AS IT HAS CHANGED HOW MULTIPLE ENI ARE ADDED.

- Added `additional_enis` variable
- Added `multiple_network_interfaces` output
- Added `all_network_interface_ids` output
- Modified `aws_network_interface` resource
- Removed `private_ips` variable
- Removed `private_ips_count` variable
- Removed `private_ips_list` variable

## 3.4.1 - 2nd October 2025

- Fix instance_scheduler check

## 3.4.0 - 24th September 2025

- Removed `amzn_lnx` AMI ahead of its deprecation
- Replaced `amzn_eks` AMI with `eks_amzn_lnx_2023`
- Added `gpu_eks_amzn_lnx_2023` AMI
- Removed `amazon_linux_2_deprecation` check
- Added `tags` output

## 3.3.1 - 8th September 2025

- Updated pinned version for `eits-tf-aws-iam`

## 3.3.0 - 26th August 2025

- Added check to warn about Amazon Linux 2 upcoming deprecation.
- Added `ami_id` output.

## 3.2.0 - 24th July 2025

- Added support for `gp2` volume types in local zones.
- Added `aws_availability_zone` data resource.
- Removed count from `aws_subnet` data resource. ^
- Bumped pre-commit hook version to `1.3.1`.
- Bumped `hashicorp/aws` provider version to `>= 6.0.0` to support `region` subnet argument.
- Replaced deprecated `name` attribute in `aws_region` data source.

^ *Note that you might notice data resources being destroyed by Terraform.*

## 3.1.1 - 2nd July 2025

- Removed duplicate `i-` on ec2 id within default alarms alarm name.

## 3.1.0 - 7th May 2025

- Added check for instance scheduler or lease tag in lower environment, for cost-optimization purposes

## 3.0.4 - 6th May 2025

- Bumped minimum required Terraform version to `1.9` to support cross-object referencing for input variable validations

## 3.0.3 - 28th April 2025

- Fixed checks for Windows AMIs

## 3.0.2 - 23rd April 2025

- Removed `data.aws_ami.ec2` as it was causing failures when data was not known before apply
- Added variable `operating_system` to specify the OS when the default security group rules are required, and a specific AMI ID is specified

## 3.0.1 - 17th April 2025

- Bumped `eits-tf-aws-security-group` version to `3.3.3`

## 3.0.0 - 15th April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Renamed `warnings.tf` to `checks.tf`
- Added check for IMDSv2
- Bumped `eits-tf-aws-cloudwatch-alarm` version to `1.3.0`
- Bumped `eits-tf-aws-iam` version to `1.7.1`
- Bumped `eits-tf-aws-security-group` version to `3.3.1`, and updated its logic and arguments ^
- Removed default security group rules, as they're now handled by the security group module. The OS is obtained from the AMI
- Renamed `data` for Experian AMI
- Updated `metadata_hop_limit_warning` check causing cycle errors when referencing to the module's output

^ ***This is a breaking change because new resources are used in `eits-tf-aws-security-group` v2+. Therefore, if you're using this module's default security group, and get an error saying that a security group rule already exist, you need to remove it first. You can choose between one of the following options:***

1) Move the security group configuration outside of the EC2 module, as described in the `eits-tf-aws-security-group` module documentation: Set the EC2 variable `exclude_default_security_group` to `true`, remove both `security_group_ingress_rules` and `security_group_egress_rules`, and use `security_groups` instead to reference a group created using `eits-tf-aws-security-group`
2) Remove the existing rules manually via CLI
3) Follow the below steps:

- Set the `exclude_default_security_group` variable to `true`, and remove or set to `[]` both `security_group_ingress_rules` and `security_group_egress_rules` variables. *Note that you must have at least one security group attached to the instance. If you don't have any after you do this step, please attach a dummy security group using the `security_groups` variable.
- Apply the Terraform configuration
- Remove or set to `false` the `exclude_default_security_group` variable, and recofigure the rules, if needed
- Apply the Terraform configuration again

## 2.12.0 - 13th March 2025

- Added warning if `var.instance_profile` is left empty.
- Added warning if `var.metadata_http_put_response_hop_limit` is > 1 (2 for containers).
- Added warning if ebs volumes are not given KMS keys for encryption and environment is production. (Root volume or additional)

## 2.11.0 - 12th March 2025

- Added count to `aws_ami` data to reduce the number of resources created, and avoid issues if a non-used AMI is not available. ^
- Added count to `aws_subnet` data to only check if a VPC is not specified. ^
- Converted `validation_warning` data to `check`, and removed `tlkamp/validation` provider. ^
- Bumped `pre-commit` to version `1.3.0`.
- Bumped Terraform required version to `1.5.0`.
- Set `associate_public_ip_address` to `false` to comply with Wiz policy experian_egso_iac_audit_cicd_policy

^ *Note that you might notice data resources being destroyed by Terraform.*

## 2.10.2 - 3rd March 2025

- Added `AWSEC2VssSnapshotPolicy` policy to the `EC2CloudWatchIntegration` role to allow AWS Backup VSS-enabled backups.

## 2.10.1 - 7th February 2025

- Fixed tags order for EBS volumes.

## 2.10.0 - 5th February 2025

- Added `lifecycle` to `aws_instance` to ignore changes to tags managed outside Terraform.

## 2.9.0 - 31st January 2025

- Added `cloudwatch_tags` variable to allow adding Cloudwatch specific tagging.
- Reconfigured Cloudwatch alarm tagging to `cloudwatch_tags` and `non_instance_tags` ony.
- Bumped `eits-tf-aws-cloudwatch-alarm` module version to `1.2.0`.

## 2.8.1 - 23rd January 2025

- Updated review date
- Updated aws provider version

## 2.8.0 - 13th January 2025

- Modified default `instance_type` to `t3a.small`. This is due to the standard EEC agent suite. ***This will reboot the instance if you have left instance_type as the default***
- Added ability to setup CloudWatch Agent with `enable_cloudwatch_agent` on instances built with an EEC AMI.
- Added following variables to support CloudWatch Agent configuration:
  - `enable_cloudwatch_agent`
  - `create_cloudwatch_role`
  - `cloudwatch_log_retention`
  - `cloudwatch_role_policies`
- Removed ec2 instance only tags from other resources (security group, network interface, ebs volumes), see `locals.tf` for full list.

## 2.7.3 - 6th January 2025

- Removed deprecated AMIs SLES 12 and Bottlerocket.

## 2.7.2 - 13th November 2024

- Added check and configuration fully qualified domain name for `ResourceName` tag.

## 2.7.1 - 30th October 2024

- Added EC2 instance `validation_warning` check with EEC naming convention standard.

## 2.7.0 - 19th June 2024

- Added validation to prevent volumes being created as type `gp2`. This is a cost saving measure. - ***Please see migration information below if you have gp2 type volumes***
- Change default values of `detailed_monitoring` and `termination_protection` to `null`.
- If `detailed_monitoring` is left at the default `null`, then this will automatically be set to `true` for resources with an "Environment" tag of value "prd", and set to `false` for other environments. This is a cost-saving measure. To override this, set a specific boolean value for `detailed_monitoring`.
- Automatically enable [EC2 Instance Termination Protection](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/terminating-instances.html#Using_ChangingDisableAPITermination) for instances with an "Environment" tag of value "prd". To override this, set a specific boolean value for `termination_protection`.
- Tidied up and added additional examples to README.

### Migration to v2.7.0

- If you need to migrate a volume from gp2 to gp3, modifying the terraform config to `gp3` will cause terraform to migrate the volume to the new type.
- Be aware that if there is no value passed to `root_volume_type` or `ebs_block_device.volume_type` then it will default to `gp3`, and may cause a type migration.

## 2.6.0 - 4th June 2024

- Automatically add the [EEC AWS Instance Scheduler](https://experian.atlassian.net/wiki/x/yxL3E) "Instance-Scheduler" tag for instances deployed in a sandbox (sbx) environment only. It will set the value of the tag to the local aws region (for example eu-west-2 will be "uk-london-office-hours"). To disable this behaviour set `disable_instance_scheduler` to `true`. - ***Please note if you already configure the "Instance-Scheduler" tag on your instances then also disable this otherwise it may override your configuration.***
- If `vpc_id` is not supplied, `subnet` will now be used to get the relevant vpc id.
- Change default value of `vpc_id` to `null`.
- Removed `availability_zone` as not been used since v2.1.3.
- EBS volume is now encrypted by default.
- Allow `snapshot_id` and `kms_key_id` to be passed in `ebs_block_device` map. - ***Note: Terraform must have the GenerateDataKeyWithoutPlaintext permission on the KMS key to prevent a volume from being created and immediately deleted.***
- Fully define variable types for:
  - `ebs_block_device`
  - `security_group_ingress_rules`
  - `security_group_egress_rules`

### Migrating to v2.6.0
- If you receive an error stating "availability_zone is not expected", remove the `availability_zone` argument from the module block as it is now depreciated.
- If you already configure the "Instance-Scheduler" tag please set `disable_instance_scheduler` to `true`.

## 2.5.0 - 27th February 2024

- Added `user_data_replace_on_change` argument. This requires Terraform AWS Provider v4.7.0+

## 2.4.1 - 22th February 2024

- Updated README with cost optimisation reference
- Added validation for required EEC compute tags

## 2.4.0 - 5th February 2024

- Update alarm module to use v1.1.1
- Fix default iops and throughput values for gp3 volumes
- Added pre-commit config
- Removed .terraform.lock.hcl file
- Changed default outbound access to 0.0.0.0/0

## 2.3.1 - 3rd January 2024

- Fix issue with `ResourceOwner` validation not taking into account default provider tags

## 2.3.0 - 2nd January 2024

- Updated EEC AMI list - ***When upgrading from 2.2.1 or below, `rhel_7` and `sles` values for `ami` will need to be updated*** 
  - Removed `rhel_7`
  - Replaced `sles` with `sles_12` and `sles_15`
- Tidy up README.md examples
- Added validation check for `ResourceOwner` tag
- Rename providers.tf to versions.tf 

## 2.2.1 - 12th December 2023

- Updated version of alarm module used

## 2.2.0 - 6th December 2023

- Added default alarms - ***Please be aware that adding the default alarms may increase the cost of the ec2 instance by $0.20 per month. To disable the creation of these alarms, please set the variable `disable_default_alarms` to true***

## 2.1.4 - 4th December 2023

- Pinned the security group module to version 1.1.2
- Recreated var `availability_zone` for backward compatibility
- Repointed all previous v2 versions to this version to prevent potential breaking changes with the security groups

## 2.1.3 - 24th November 2023

- Removed availability_zone variable, this was only used for ebs volumes and is is now automatically calculated based on instance az to avoid misconfigurations - ***Please be aware that, if you're upgrading to this version from 2.1.2 or below you may get an error stating availability_zone is not expected, simply remove the argument from the module block***

## 2.1.2 - 1st November 2023

- Add CONTRIBUTING.md

## 2.1.1 - 26th October 2023

- Add benchmark table to README.md

## 2.1.0 - 28th September 2023

- Enhanced EC2 module to allow private IPs, secondary private IPs, and attaching external network interfaces

## 2.0.1 - 18th September 2023

- Merge functionality of vars, tagging and label modules

## 2.0.0 - 23rd August 2023

- Refactored so not to use the CloudPosse module anymore
- Fixed an issue with default security group not adding the new rules, and improved its functionality
- Added more options for the EC2 instance and root volume
- Added support for Metadata v2
- Changed default root volume type to gp3
- Added _private_dns_ output

## 1.2.1 - 15th August 2023

- Added EITS vars module

## 1.2.0 - 31st July 2023

- Updated CloudPosse module to v1.0.0
- Refactored security groups so they can accept other security groups and endpoints as source (using new module)
  - This is a breaking change as the CloudPosse variables ("name", "environment", "namespace", "stage") are no longer present, and security groups are now managed by the 'eits-tf-aws-security-group' module rather than CloudPosse
- Added new default rules for Tanium agent
- Added tags validation
- Leveraged EITS label module to name extra resources created by the CloudPosse module (e.g., CloudWatch alarm)
- Added option for termination protection
- Added private IP output
- Added Amazon Linux 2023 AMI
- Added option to set IOPS and throughput for EBS volumes

## 1.1.0 - 27th June 2023

- Enforced required tags (as per https://experian.atlassian.net/wiki/x/swH3E)
- Updated README.md 

## 1.0.1 - 13th June 2023

- Added support for user_data

## 1.0.0 - 15th March 2023

- Initial release
