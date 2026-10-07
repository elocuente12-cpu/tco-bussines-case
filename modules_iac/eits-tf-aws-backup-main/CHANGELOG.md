# RELEASE NOTES

## 3.10.2 - 14th September 2026

- Updated confluence document links

## 3.10.1 - 16th July 2026

- Dependency update: Updated IAM module to version 1.9.7
- Dependency update: Updated Lambda module to version 1.11.1
- Dependency update: Updated Eventbridge module to version 2.5.1
- Dependency update: Updated SNS module to version 1.8.0

## 3.10.0 - 24th June 2026

- Added support for LAG vault copy. Please see [README](./README.md#logically-air-gapped-lag-vault) for further details.
- Bumped `pre-commit` to version `1.4.0`

## 3.9.0 - 12th June 2026

- Added LAG vault support, with the option to share the vault with other accounts in the organization using AWS Resource Access Manager (RAM)
- Added the following variables: `lag_vault_name`, `lag_vault_min_retention_days`, `lag_vault_max_retention_days`, `lag_vault_encryption_key_arn`, `lag_vault_policy`, `lag_vault_shared_accounts`
- Bumped AWS provider version to `6.35.0`
- Bumped minimum Terraform version to `1.9.0` to support input variable validation of other variables
- Added `eitsce:parentmodule` tag to alarms

## 3.8.0 - 10th June 2026

- Added malware scan support for backup plans with new rule argument `backup_rules[*].scan_mode` and plan variables `scanner_resource_types` and `scanner_role_arn`.
- Added backup scanner IAM role, if required.
- Updated minimum supported AWS provider version to `>= 6.25.0`, which is required for AWS Backup malware scan arguments.

## 3.7.1 - 27th January 2026

- Added permissions to allow restores from API

## 3.7.0 - 3rd December 2025

- Added `manage_region_settings` variable. This disables AWS Backup Region Settings in order to manage these settings outside of the module.
- Bumped `eits-tf-aws-iam` version to `1.9.2`.

## 3.6.0 - 24th November 2025

- Added `iam:PassRole` permission (EC2 service only) to the created Backup role, in order to fix issues when restoring EC2 backups. Defaults to allowing the role associated with the standard EEC instance profile, if you are not using this role please set the `backup_ec2_pass_role_names` variable with a list of applicable roles.
- Bumped `eits-tf-aws-sns` version to `1.7.1`.

## 3.5.1 - 8th September 2025

- Updated pinned version for `eits-tf-aws-iam`
- Updated `pre-commit` version to `1.3.1`

## 3.5.0 - 1st April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Renamed `warnings.tf` to `checks.tf`
- Updated `pre-commit` version to `1.3.0`
- Bumped `eits-tf-aws-cloudwatch-alarm` version to `1.3.0`
- Bumped `eits-tf-aws-iam` version to `1.7.1`
- Bumped `eits-tf-aws-sns` version to `1.7.0`
- Renamed `data.aws_iam_policy_document.aws_backup_allow_tagging` to `data.aws_iam_policy_document.aws_backup_role`
- Moved `backup_custom_policy` to `data.aws_iam_policy_document.aws_backup_role` as `source_policy_documents` to avoid issues with empty policies in IAM module policy checks

## 3.4.0 - 10 March 2025

- Added a policy to the vault that denies `backup:DeleteRecoveryPoint` globally.
- Added warning if KMS key is not specified.
- Added warning if the `backup_vault_events` in `backup_notifications` contain deprecated events.

## 3.3.0 - 10 July 2024

- Add AWS Backup Vault Lock to comply with the latest Experian backup requirements. Use `vault_lock_config` map to enable and configure.
- Add `vault_force_destroy` variable.
- Add `backup_sns_topic_name_prefix` variable.
- Update IAM module to use v1.3.3.
- Update SNS module to use v1.2.0.
- Modify Terraform version requirement to >=1.8 to avoid the use of depends_on when deploying the full backup stack (s3, etc).
- Modify AWS provider version to >=4.50 due to new functionality and re-apply bug fix.
- Fix tests to work with latest version of s3 module.

## 3.2.1 - 30 April 2024

- Fixed SNS topic that was created even if the ARN of an existing topic was provided

## 3.2.0 - 4th April 2024

- Add the following variables to enable optional CloudWatch alarms on created vaults:
  - `enable_vault_alarms`
  - `alarm_sns_topics`
- Default to using created backup vault (or "Default" if no vault is created) if `backup_rules.*.target_vault_name` is not provided.
- Add detailed type declaration for `backup_rules`.
- Add new outputs:
  - `backup_plan_arn`
  - `backup_vault_id`
  - `backup_vault_arn`
- Update SNS module to version 1.1.0.
- Update test directory to work on apply, and create ec2 for testing.
- Add depends_on for aws_backup_vault_notifications resource when creating backup vault.

## 3.1.0 - 5th March 2024

- Updated IAM module to version 1.3.2. Please see Jira ticket [UKICLOENA-1511](https://agile.experian.com/browse/UKICLOENA-1511) for more information.

## 3.0.2 - 26th February 2024

- Fix TFLint issue: Removed lookup, replacing with an index expression
- Add pre-commit config

## 3.0.1 - 16th November 2023

- Fixed default value for `backup_sns_topic_name`

## 3.0.0 - 10th November 2023

- Leveraging eits-tf-aws-sns module for SNS notifications to allow for more flexibility and multiple recipients - ***Breaking change, will recreate the SNS topic and subscriptions, which will need to be validated again***
- Pinned SNS and IAM modules

## 2.0.2 - 1st November 2023

- Add CONTRIBUTING.md

## 2.0.1 - 26th October 2023

- Add benchmark table to README.md

## 2.0.0 - 12th October 2023

- Removed boundary from IAM role as no longer required
- Switched to using the `eits-tf-aws-iam` module to create the IAM role and policy - **This will recreate all the associated IAM roles and policies if updating from an older version**
- Added option to override assume role policy
- Added option to add custom policies to the IAM role used for backup

## 1.1.0 - 19th September 2023

- Add tests directory with Jenkinsfile for pull request testing
- Merge functionality of vars, tagging and label modules
- Updated .gitignore
- Remove .lock.hcl file
- Fix tflint recommendations:
  - Add versions file
  - Add output descriptions
  - List items should be accessed using square brackets
- Remove unused variable:
  - rule_name
  - rule_schedule
  - rule_start_window
  - rule_completion_window
  - rule_recovery_point_tags
  - rule_lifecycle_cold_storage_after
  - rule_lifecycle_delete_after
  - rule_copy_action_lifecycle
  - rule_copy_action_destination_vault_arn
  - rule_enable_continuous_backup
  - backup_selection_name
  - backup_selection_resources
  - backup_selection_not_resources
  - backup_selection_conditions
  - backup_selection_tags

## 1.0.1 - 14th August 2023

- Add standard EITS CE tags using eits_vars module
- Add tags to iam and sns

## 1.0.0 - 17th May 2023

- Initial release
