# RELEASE NOTES

## 1.5.0 - 30th March 2026

- Added `cloudwatch_log_group_retention` variable to configure the retention for the Cloudwatch log group created by the module.

## 1.4.1 - 13th March 2026

- Updated `eits-tf-aws-cloudwatch-logs` module to version `2.6.1`
- Updated `eits-tf-aws-security-group` module to version `3.5.1`

## 1.4.0 - 23rd February 2026

- Added `alarms.tf` with FSx utilization alarms
- Added `alarm_sns_topics`, `enable_default_alarms`, `enable_all_alarm_actions`, `alarm_thresholds` and `cloudwatch_tags` variables

## 1.3.4 - 10th December 2025

- Updated `eits-tf-aws-cloudwatch-logs` module to version `2.6.0`

## v1.3.3 - 19th November 2025

- Updated `eits-tf-aws-kms` module to version `1.9.0`

## 1.3.2 - 5th November 2025

- Update `eits-tf-aws-security-group` pinned version `3.5.0`

## 1.3.1 - 16th September 2025

- Updated `eits-tf-aws-kms` pinned version to `1.8.1`

## 1.3.0 - 28th July 2025

- Added `vpc_id` variable to specify VPC ID if multiple VPCs are present
- Updated `aws_vpc` data resource to use the new `vpc_id` variable
- Added `Name` tag for `aws_fsx_windows_file_system`

## 1.2.2 - 19th June 2025

- Module biannual review
- Bumped pre-commit hooks version to `1.3.1`
- Added `eitsce:parentmodule` tag to dependent `fsx_security_group`,`fsx_cloudwatch_log_group` and `fsx_kms` modules

## 1.2.1 - 23rd April 2025

- Updated Security Group module to bugix version 3.3.3
- Updated Cloudwatch Log module to bugfix version 2.5.1

## 1.2.0 - 10th April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Renamed `warnings.tf` to `checks.tf`
- Converted warnings to `check` type
- Updated `pre-commit` version to `1.3.0`
- Bumped `eits-tf-aws-cloudwatch-logs` version to `2.5.0`
- Bumped `eits-tf-aws-security-group` version to `3.3.1`
- Bumped `eits-tf-aws-kms` version to `1.8.0`
- Removed `tlkamp\validation` provider

## 1.1.0 - 24th March 2025

- Increased required version of terraform from `1.3` to `1.5`.
- Applied latest security enhancements specific to Wiz findings.

## 1.0.0 - 7th November 2024

- Initial release
