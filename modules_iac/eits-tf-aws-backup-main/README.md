# EITS Cloud Enablement AWS Backup Module

AWS Backup Terraform module developed by the EITS Cloud Enablement team. It can be used to deploy the following AWS Backup functionalities:

- Create encrypted AWS Backup vault
- Create AWS Backup Vault Lock
- Create encrypted SNS topics for backup notifications
- Create a backup report plan
- Configure IAM roles and S3 bucket for reports
- Create AWS Backup plans (recommended to assign resources based on tags)
- Opt-in/Opt-out option to backup selected resources
- Customise trust role and default IAM policy
- Enable malware protecion, if required
- Create a Logically Air-Gapped (LAG) vault, if required

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> As of version 3.1.0 a check has been added to the iam module which denies access to assume created roles from services outside of the Experian AWS Organization.
> If this breaks your use case, disable this functionality by setting the variable `disable_org_check` to `true`.

## EITS Security & Compliance

**Last Module Review**: 2026-06-01

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-07-16 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-07-16 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-07-16 | 0.72.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-07-16 | 1.59.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## NOTES

- [AWS Backup Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html) should be configured to comply with the latest Experian backup requirements. See [EITS Storage Infrastructure Services Docs](https://pages.experian.local/display/SIS/AWS+Backup+Vault+Lock) for details. Use `vault_lock_config` map to enable and configure.
- Sometimes it might fail to create the vault if it's the first time that AWS Backup is used as it can't find the "AWSServiceRoleForBackup" service-linked role. This role is automatically created by AWS the first time AWS Backup is used.
- Malware scan support (`backup_rules[*].scan_mode`) requires AWS provider version `>= 6.25.0`.
- Before enabling malware scan, configure IAM prerequisites:
  - If this module creates the backup role (`create_backup_iam_role = true`), it automatically adds managed policy `AWSBackupServiceRolePolicyForScans` when malware scan is configured.
  - If you pass an existing backup role via `iam_role_arn`, add managed policy `AWSBackupServiceRolePolicyForScans` to that role.
  - Create a scanner role with [these permissions](https://docs.aws.amazon.com/guardduty/latest/ug/malware-protection-backup-iam-permissions.html), then use it on `scanner_role_arn`.
    - If you enable scan but don't pass that role, one will be automatically created for you by this module.
- How to configure `backup_notifications`:
  - Please refer to [the SNS module documentation](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-sns/) for the fields required for the new `subscribers` value.
  - If you omit `sns_topic_arn` argument, a new SNS topic will be created for you.
  - If you omit `backup_vault_events`, the default events `"BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED", "RESTORE_JOB_COMPLETED"` will be used. `"BACKUP_JOB_FAILED"` has been deprecated so it was removed from default events as of version 3.4.0.
  - As of 3.4.0 if you include an event type that is invalid or deprecated, you will get a warning.

### Logically Air-Gapped (LAG) vault

As of version `3.9.0`, you can create a Logically Air-Gapped (LAG) vault by setting `create_backup_lag_vault` to `true`.

- If you don't specify `lag_vault_lock_config.min_retention_days` and `lag_vault_lock_config.max_retention_days`, the default value of `7` and `30` days will be used for the LAG vault lock
- This vault can be shared with other accounts in the organization via AWS Resource Access Manager (RAM) by using `lag_vault_shared_accounts`.
- You can configure an access policy using `lag_vault_policy`.
- For enhanced security, it is recommended to integrate your LAG vault with [AWS Multi-Party Approval (MPA)](https://docs.aws.amazon.com/aws-backup/latest/devguide/multipartyapproval.html). This needs to be configured separately in Identity Center. Please reach out to EEC if you wish to implement this.
  
As of version `3.10.0`, it's possible to copy backups to LAG vaults that aren't supported to be backed up directly to LAG (e.g., EC2 with EBS volumes encrypted with `aws/ebs` key, or other resources encrypted with Amazon-managed keys (AMKs)). Please see this [ransomware protection summary](https://pages.experian.local/spaces/UCE/pages/1997848320/CPO+DPO+Capability+Summary+for+Ransomware+Recovery) for further info.
This is achieved by using an intermediate temporary vault where the recovery points are staged and then copied to the LAG vault. This is managed by 2 Eventbridge rules and 2 Lambda functions, one to copy from intermediate to LAG, and one to delete the temporary backup copy in the intermediate vault.
The flow looks like this: Main backup vault -> intermediate vault -> LAG vault.
**The recovery points retention period in the LAG vault will be set the same as it is configured in the intermediate vault copy, defaulting to `lag_vault_max_retention_days` if unable to obtain that info. Please note that the minimum retention period for the LAG vault is 7 days.**

To enable this, set `copy_to_lag` to `true`.
This will create the following resources:

- Eventbridge rules on backup copy jobs
- Lambda functions to copy backups from the intermediate vault to the LAG vault, and then delete them from the intermediate vault
- Supporting IAM role

Please note that, in order to enable this, the following pre-requisites must be in place:

- An intermediate (temporary) AWS Backup Vault:
  - `create_vault_policy` must be set to `false` for the Lambda function to delete the temporary copy, and not incur in extra costs.
  - This vault should not be immutable, for the reason above.
  - Both backup and intermediate vaults must be encrypted with a CMK (it can be the same).
- A backup job to copy the required recovery points from the main vault to the intermediate one.

You can use this module to create the vault and copy job.
See `tests/lag_vault` for an example.

Also please note that, although this copy solution was provided to us by AWS, is not yet generally available in AWS.

For more info about AWS Backup LAG vault, please refer to the [AWS developer guide](https://docs.aws.amazon.com/aws-backup/latest/devguide/logicallyairgappedvault.html).
  
## USAGE

### Create Backup Vault, pre-configure AWS Backup, and setup SNS for notifications

```hcl
module "aws_backup" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-backup.git"

  create_backup_vault    = true
  vault_name             = <vault_name>
  vault_kms_key_arn      = <vault_kms_key_arn>

  # Set this to false so it will only create the vault but no backup plan
  backup_enabled   = false

  # Create optional IAM role
  create_backup_iam_role = <true/false>
  iam_role_name          = <optional, will use default if omitted>
  iam_policy_name        = <optional, will use default if omitted>

  # Create optional backup report
  create_backup_report         = <true/false>
  backup_report_name           = <name of report>
  s3_backup_report_bucket_name = <bucket to store reports>

  # Vault lock configuration
  vault_lock_config = {
    enabled             = <true/false>      # default is false, use true to enable
    changeable_for_days = <number of days>  # be aware, if set will create a compliance mode lock
    max_retention_days  = <number of days>
    min_retention_days  = <number of days>
  }

  # Map of resources to enable (or disable) for backup (please refer to AWS Backup describe-region-settings API for full list)
  resource_type_opt_in_preference = {
    <resource>   = <true/false>
  }
  
  # Configure SNS notifications
  backup_sns_email_notification_enabled = <true/false>
  backup_sns_topic_name                 = <backup_sns_topic_name>
  backup_notifications = {
    sns_topic_arn          = <sns_topic_arn> # Omit this to create a new topic
    backup_vault_events    = ["BACKUP_JOB_STARTED", "BACKUP_JOB_COMPLETED", "BACKUP_JOB_FAILED", "RESTORE_JOB_COMPLETED"] # Remove events that are not required
    subscribers = {
      <team> = {
        protocol = "email"
        endpoint = "<email>"
        }
    }
  }
  sns_kms_key_id = <sns_kms_key>

  tags = <tags>
}
```

### Create backup plan in already existing vault

Please note the above and below examples can be combined into one module if required.

```hcl
module "aws_backup_plan" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-backup.git"

  vault_name        = <vault_name>
  backup_enabled    = true
  backup_plan_name  = <plan_name>
  iam_role_arn      = <iam_role_arn>
  backup_rules = [
    {
      rule_name         = <rule_name>
      target_vault_name = <backup_vault_name>
      schedule          = <cron_expression> # e.g., cron(0 18 ? * 2,3,4,5,6 *)
      start_window      = <minutes>
      completion_window = <minutes+start_window_minutes>
      lifecycle = {
        cold_storage_after = <days>
        delete_after       = <days>
      }
      scan_mode = "INCREMENTAL_SCAN" # or FULL_SCAN
    }
  ]

  scanner_resource_types = ["EBS", "EC2", "S3"] # or ["ALL"]
  scanner_role_arn       = "arn:aws:iam::<account_id>:role/<backup_scanner_role>"

  # Enable VSS for Windows EC2 instances
  vss_enabled = <true/false>

  # Backup selection rules
  backup_selections = [
    {
      name      = <name>
      resources = ["*"] # or list of resources
      conditions = {
        string_equals = [
          {
            key   = "aws:ResourceTag/<tag_name>
            value = <tag_value>
          }
        ]
      }
    }
  ]

  tags = <tags>

  # This module requires the Vault, so add this to ensure it's created first, if creating both at the same time
  depends_on = [module.aws_backup_plan]
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.8.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.35.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.8.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.35.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.0 |
| <a name="module_backup_events_sns"></a> [backup\_events\_sns](#module\_backup\_events\_sns) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-sns.git | 1.8.0 |
| <a name="module_bkp_iam_role"></a> [bkp\_iam\_role](#module\_bkp\_iam\_role) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git | 1.9.7 |
| <a name="module_bkp_scanner_iam_role"></a> [bkp\_scanner\_iam\_role](#module\_bkp\_scanner\_iam\_role) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git | 1.9.7 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |
| <a name="module_eventbridge_backup_cleanup_temp_vault"></a> [eventbridge\_backup\_cleanup\_temp\_vault](#module\_eventbridge\_backup\_cleanup\_temp\_vault) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git | 2.5.1 |
| <a name="module_eventbridge_backup_lag_copy"></a> [eventbridge\_backup\_lag\_copy](#module\_eventbridge\_backup\_lag\_copy) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-eventbridge.git | 2.5.1 |
| <a name="module_iam_role_lag_lambda"></a> [iam\_role\_lag\_lambda](#module\_iam\_role\_lag\_lambda) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam.git | 1.9.7 |
| <a name="module_lambda_cleanup_temp_vault"></a> [lambda\_cleanup\_temp\_vault](#module\_lambda\_cleanup\_temp\_vault) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git | 1.11.1 |
| <a name="module_lambda_copy_to_lag"></a> [lambda\_copy\_to\_lag](#module\_lambda\_copy\_to\_lag) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-lambda.git | 1.11.1 |

## Resources

| Name | Type |
|------|------|
| [aws_backup_logically_air_gapped_vault.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_logically_air_gapped_vault) | resource |
| [aws_backup_plan.bkp_plan](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_region_settings.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_region_settings) | resource |
| [aws_backup_report_plan.bkp_backup_jobs_report](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_report_plan) | resource |
| [aws_backup_selection.bkp_selection](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.bkp_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault_lock_configuration.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration) | resource |
| [aws_backup_vault_notifications.backup_events](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_notifications) | resource |
| [aws_backup_vault_policy.deny_delete](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_policy) | resource |
| [aws_backup_vault_policy.lag_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_policy) | resource |
| [aws_lambda_permission.allow_eventbridge_cleanup_temp_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_lambda_permission.allow_eventbridge_copy_to_lag](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_ram_principal_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_principal_association) | resource |
| [aws_ram_resource_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_association) | resource |
| [aws_ram_resource_share.lag_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ram_resource_share) | resource |
| [archive_file.lambda_cleanup_temp_vault_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.lambda_copy_to_lag_zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.aws_backup_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_backup_deny_deletions](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_backup_lag_lambda_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_backup_lag_lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_backup_lag_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_backup_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_backup_scanner_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.aws_backup_scanner_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | List of SNS topic ARNs triggered by alarm events. providing a list will automatically enable alarm actions. Only used if `enable_vault_alarms` is configured and `create_backup_vault` is `true` | `list(string)` | `[]` | no |
| <a name="input_backup_custom_assume_role"></a> [backup\_custom\_assume\_role](#input\_backup\_custom\_assume\_role) | JSON policy document to replace the default assume role policy, if needed. Remember to allow action 'sts:AssumeRole' for service 'backup.amazonaws.com' | `string` | `""` | no |
| <a name="input_backup_custom_policy"></a> [backup\_custom\_policy](#input\_backup\_custom\_policy) | JSON custom policy to add to the default backup policy, if needed | `string` | `""` | no |
| <a name="input_backup_ec2_pass_role_names"></a> [backup\_ec2\_pass\_role\_names](#input\_backup\_ec2\_pass\_role\_names) | List of IAM roles that the created Backup role will be allowed to pass to the EC2 service (in order to restore instances), must be in the same account as the Backup vault. Only used if `create_backup_iam_role` is `true`. By default allows the role associated with the standard EEC instance profile. | `list(string)` | <pre>[<br/>  "eec-aws-ami-factory-instance-role"<br/>]</pre> | no |
| <a name="input_backup_enabled"></a> [backup\_enabled](#input\_backup\_enabled) | Change to false to avoid deploying any AWS Backup resources | `bool` | `true` | no |
| <a name="input_backup_notifications"></a> [backup\_notifications](#input\_backup\_notifications) | Notification block which defines backup vault events and the SNS Topic ARN to send AWS Backup notifications to. Leave it empty to disable notifications | `any` | `{}` | no |
| <a name="input_backup_plan_name"></a> [backup\_plan\_name](#input\_backup\_plan\_name) | The name of the backup plan | `string` | `""` | no |
| <a name="input_backup_report_description"></a> [backup\_report\_description](#input\_backup\_report\_description) | The description of the backup report | `string` | `"Backup jobs report by Experian"` | no |
| <a name="input_backup_report_name"></a> [backup\_report\_name](#input\_backup\_report\_name) | The name of the backup report | `string` | `""` | no |
| <a name="input_backup_rules"></a> [backup\_rules](#input\_backup\_rules) | A list of rule maps. If `create_backup_vault` is `true` then `target_vault_name` will be automatically populated if omitted from the map | <pre>list(object({<br/>    rule_name                = optional(string)<br/>    target_vault_name        = optional(string)<br/>    schedule                 = optional(string)<br/>    start_window             = optional(number)<br/>    completion_window        = optional(number)<br/>    enable_continuous_backup = optional(bool)<br/>    recovery_point_tags      = optional(map(string), {})<br/>    lifecycle = optional(object({<br/>      cold_storage_after = optional(number, 0)<br/>      delete_after       = optional(number, 90)<br/>    }))<br/>    copy_actions = optional(list(object({<br/>      destination_vault_arn = optional(string)<br/>      lifecycle = optional(object({<br/>        cold_storage_after = optional(number, 0)<br/>        delete_after       = optional(number, 90)<br/>      }))<br/>    })), [])<br/>    scan_mode                                    = optional(string)<br/>    target_logically_air_gapped_backup_vault_arn = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_backup_selections"></a> [backup\_selections](#input\_backup\_selections) | A list of selection maps | `any` | `[]` | no |
| <a name="input_backup_sns_topic_name"></a> [backup\_sns\_topic\_name](#input\_backup\_sns\_topic\_name) | Name of the SNS topic | `string` | `""` | no |
| <a name="input_backup_sns_topic_name_prefix"></a> [backup\_sns\_topic\_name\_prefix](#input\_backup\_sns\_topic\_name\_prefix) | Prefix of the SNS topic. If left `null`, a prefix will be automatically calculated based on account name in accordance with the [EEC Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E) | `string` | `null` | no |
| <a name="input_copy_to_lag"></a> [copy\_to\_lag](#input\_copy\_to\_lag) | Set to `true` to create a Lambda function that copies recovery points from an intermediate backup vault to theLAG vault.<br/>  To use this, you must create a temporary intermediate vault, and configure a backup copy to that intermediate vault. The Lambda function will then copy those recovery points to the LAG vault. | `bool` | `false` | no |
| <a name="input_create_backup_iam_role"></a> [create\_backup\_iam\_role](#input\_create\_backup\_iam\_role) | Enable creation of IAM role for AWS Backup | `bool` | `false` | no |
| <a name="input_create_backup_lag_vault"></a> [create\_backup\_lag\_vault](#input\_create\_backup\_lag\_vault) | Set to `true` to create a logically air-gapped backup vault | `bool` | `false` | no |
| <a name="input_create_backup_report"></a> [create\_backup\_report](#input\_create\_backup\_report) | Enable creation of reports for AWS Backup | `bool` | `false` | no |
| <a name="input_create_backup_vault"></a> [create\_backup\_vault](#input\_create\_backup\_vault) | Enable creation of Vault for AWS Backup | `bool` | `false` | no |
| <a name="input_create_vault_policy"></a> [create\_vault\_policy](#input\_create\_vault\_policy) | If enabled, a policy that disables deleting snapshots from a vault will be created and deployed to the backup vault. | `bool` | `true` | no |
| <a name="input_disable_org_check"></a> [disable\_org\_check](#input\_disable\_org\_check) | Set this to true to remove the Deny permission in the trust policy which stops services from outside the Experian Organization from assuming the role | `bool` | `false` | no |
| <a name="input_enable_vault_alarms"></a> [enable\_vault\_alarms](#input\_enable\_vault\_alarms) | A map of backup vault alarm metrics to configure, set a metric to `true` to configure the CloudWatch alarm. Default threshold is greater than 1 within 60 minutes. Use `alarm_sns_topics` to enable alarm actions. Only used if `create_backup_vault` is `true` | <pre>object({<br/>    NumberOfBackupJobsFailed      = optional(bool, false)<br/>    NumberOfBackupJobsExpired     = optional(bool, false)<br/>    NumberOfBackupJobsAborted     = optional(bool, false)<br/>    NumberOfCopyJobsFailed        = optional(bool, false)<br/>    NumberOfRestoreJobsFailed     = optional(bool, false)<br/>    NumberOfRecoveryPointsExpired = optional(bool, false)<br/>  })</pre> | `{}` | no |
| <a name="input_iam_policy_name"></a> [iam\_policy\_name](#input\_iam\_policy\_name) | IAM policy name | `string` | `"AWSBackup"` | no |
| <a name="input_iam_role_arn"></a> [iam\_role\_arn](#input\_iam\_role\_arn) | If configured, the module will attach this role to selections, instead of creating IAM resources by itself | `string` | `null` | no |
| <a name="input_iam_role_name"></a> [iam\_role\_name](#input\_iam\_role\_name) | IAM role name | `string` | `"AWSBackup"` | no |
| <a name="input_intermediate_vault_name"></a> [intermediate\_vault\_name](#input\_intermediate\_vault\_name) | Name of the intermediate backup vault to copy recovery points from. Only used if `copy_to_lag` is `true` | `string` | `null` | no |
| <a name="input_lag_vault_encryption_key_arn"></a> [lag\_vault\_encryption\_key\_arn](#input\_lag\_vault\_encryption\_key\_arn) | KMS key ARN used to encrypt the logically air-gapped vault. It's recommended to leave this `null` so to use the AWS owned key (AOK). | `string` | `null` | no |
| <a name="input_lag_vault_lock_config"></a> [lag\_vault\_lock\_config](#input\_lag\_vault\_lock\_config) | A map to configure [AWS Backup Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html) for the LAG vault. Only used if `create_backup_lag_vault` is `true`. | <pre>object({<br/>    min_retention_days = optional(number, 7)<br/>    max_retention_days = optional(number, 30)<br/>  })</pre> | <pre>{<br/>  "max_retention_days": 30,<br/>  "min_retention_days": 7<br/>}</pre> | no |
| <a name="input_lag_vault_max_retention_days"></a> [lag\_vault\_max\_retention\_days](#input\_lag\_vault\_max\_retention\_days) | Maximum retention period that the Logically Air Gapped Backup Vault retains recovery points. Only used by the Lambda function if it's unable to obtain the retention period from the intermediate vault copy. | `number` | `null` | no |
| <a name="input_lag_vault_name"></a> [lag\_vault\_name](#input\_lag\_vault\_name) | Name of the logically air-gapped backup vault to create. Required if `create_backup_lag_vault` is `true`. | `string` | `null` | no |
| <a name="input_lag_vault_policy"></a> [lag\_vault\_policy](#input\_lag\_vault\_policy) | Optional JSON access policy to apply to the logically air-gapped vault. Only used if `create_backup_lag_vault` is `true`. If not provided, a default policy to allow copies will be applied to the LAG vault. | `string` | `null` | no |
| <a name="input_lag_vault_shared_accounts"></a> [lag\_vault\_shared\_accounts](#input\_lag\_vault\_shared\_accounts) | List of AWS account IDs that the logically air-gapped vault will be shared with. Only used if `create_backup_lag_vault` is `true` | `list(string)` | `[]` | no |
| <a name="input_manage_region_settings"></a> [manage\_region\_settings](#input\_manage\_region\_settings) | Enables management of AWS Backup Region Settings using the `resource_type_opt_in_preference` variable. To disable this in order to manage region settings outside of this module, set to `false` | `bool` | `true` | no |
| <a name="input_resource_type_opt_in_preference"></a> [resource\_type\_opt\_in\_preference](#input\_resource\_type\_opt\_in\_preference) | Resources that are enabled for AWS Backup, note that this config makes changes to AWS Backup account/region wide, not just for this vault. List can change depending on region, use `aws backup describe-region-settings` to see available resources. Only used if `manage_region_settings` is `true` | `map(bool)` | <pre>{<br/>  "Aurora": true,<br/>  "CloudFormation": false,<br/>  "DocumentDB": false,<br/>  "DynamoDB": true,<br/>  "EBS": true,<br/>  "EC2": true,<br/>  "EFS": true,<br/>  "FSx": true,<br/>  "Neptune": false,<br/>  "RDS": true,<br/>  "Redshift": false,<br/>  "S3": true,<br/>  "Storage Gateway": false,<br/>  "VirtualMachine": false<br/>}</pre> | no |
| <a name="input_s3_backup_report_bucket_name"></a> [s3\_backup\_report\_bucket\_name](#input\_s3\_backup\_report\_bucket\_name) | Name of the S3 bucket where to store the backup jobs reports | `string` | `""` | no |
| <a name="input_scanner_resource_types"></a> [scanner\_resource\_types](#input\_scanner\_resource\_types) | Resource types for malware scan setting when any backup rule configures scan\_mode. | `list(string)` | <pre>[<br/>  "ALL"<br/>]</pre> | no |
| <a name="input_scanner_role_arn"></a> [scanner\_role\_arn](#input\_scanner\_role\_arn) | IAM role ARN used for malware scans when scan\_mode is configured in any backup rule. If omitted and create\_backup\_iam\_role=true, the module-created backup role ARN is used. | `string` | `null` | no |
| <a name="input_sns_kms_key_id"></a> [sns\_kms\_key\_id](#input\_sns\_kms\_key\_id) | The server-side encryption key that is used to encrypt the SNS Topic | `string` | `"alias/aws/sns"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A mapping of tags to assign to the resource | `map(string)` | `{}` | no |
| <a name="input_vault_force_destroy"></a> [vault\_force\_destroy](#input\_vault\_force\_destroy) | A boolean that indicates that all recovery points stored in the vault are deleted so that the vault can be destroyed without error. PLEASE NOTE: This is irreversible and will delete all recovery points in the vault when destroyed! | `bool` | `false` | no |
| <a name="input_vault_kms_key_arn"></a> [vault\_kms\_key\_arn](#input\_vault\_kms\_key\_arn) | The server-side encryption key that is used to protect your backups | `string` | `null` | no |
| <a name="input_vault_lock_config"></a> [vault\_lock\_config](#input\_vault\_lock\_config) | A map to configure [AWS Backup Vault Lock](https://docs.aws.amazon.com/aws-backup/latest/devguide/vault-lock.html). To enable Vault Lock, set `enabled` to `true`, see type for default values. Only used if `create_backup_vault` is `true` | <pre>object({<br/>    enabled             = optional(bool, false)<br/>    changeable_for_days = optional(number, null)<br/>    max_retention_days  = optional(number, 180)<br/>    min_retention_days  = optional(number, 14)<br/>  })</pre> | `{}` | no |
| <a name="input_vault_name"></a> [vault\_name](#input\_vault\_name) | Name of the backup vault to create. If not given, AWS use default | `string` | `null` | no |
| <a name="input_vss_enabled"></a> [vss\_enabled](#input\_vss\_enabled) | Enable Windows VSS backup option and create a VSS Windows backup | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backup_events_sns_topic_arn"></a> [backup\_events\_sns\_topic\_arn](#output\_backup\_events\_sns\_topic\_arn) | The ARN of the backup SNS topic, if created |
| <a name="output_backup_iam_role"></a> [backup\_iam\_role](#output\_backup\_iam\_role) | IAM role ARN for AWS Backup service, if created |
| <a name="output_backup_lag_vault_arn"></a> [backup\_lag\_vault\_arn](#output\_backup\_lag\_vault\_arn) | Logically air gapped vault ARN, if created |
| <a name="output_backup_lag_vault_eventbridge_cleanup_rule_arn"></a> [backup\_lag\_vault\_eventbridge\_cleanup\_rule\_arn](#output\_backup\_lag\_vault\_eventbridge\_cleanup\_rule\_arn) | ARN of the AWS Backup LAG vault copy cleanup EventBridge rule, if created |
| <a name="output_backup_lag_vault_eventbridge_copy_rule_arn"></a> [backup\_lag\_vault\_eventbridge\_copy\_rule\_arn](#output\_backup\_lag\_vault\_eventbridge\_copy\_rule\_arn) | ARN of the AWS Backup LAG vault copy EventBridge rule, if created |
| <a name="output_backup_lag_vault_iam_role_lambda_arn"></a> [backup\_lag\_vault\_iam\_role\_lambda\_arn](#output\_backup\_lag\_vault\_iam\_role\_lambda\_arn) | IAM role ARN for AWS Backup LAG vault copy Lambda function, if created |
| <a name="output_backup_lag_vault_id"></a> [backup\_lag\_vault\_id](#output\_backup\_lag\_vault\_id) | Logically air gapped vault name, if created |
| <a name="output_backup_lag_vault_lambda_cleanup_function_arn"></a> [backup\_lag\_vault\_lambda\_cleanup\_function\_arn](#output\_backup\_lag\_vault\_lambda\_cleanup\_function\_arn) | ARN of the AWS Backup LAG vault copy cleanup Lambda function, if created |
| <a name="output_backup_lag_vault_lambda_copy_function_arn"></a> [backup\_lag\_vault\_lambda\_copy\_function\_arn](#output\_backup\_lag\_vault\_lambda\_copy\_function\_arn) | ARN of the AWS Backup LAG vault copy Lambda function, if created |
| <a name="output_backup_plan_arn"></a> [backup\_plan\_arn](#output\_backup\_plan\_arn) | The ARN of the backup plan, if created |
| <a name="output_backup_plan_id"></a> [backup\_plan\_id](#output\_backup\_plan\_id) | The ID of the backup plan, if created |
| <a name="output_backup_vault_arn"></a> [backup\_vault\_arn](#output\_backup\_vault\_arn) | Backup vault ARN, if created |
| <a name="output_backup_vault_id"></a> [backup\_vault\_id](#output\_backup\_vault\_id) | Backup vault name, if created |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS Backup
region: Global
bu: T&I
docs: https://experian.atlassian.net/wiki/x/HQ4EF
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>
```
