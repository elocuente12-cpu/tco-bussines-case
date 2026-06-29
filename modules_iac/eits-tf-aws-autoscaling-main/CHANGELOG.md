# RELEASE NOTES

## 1.10.0 - 27th March 2026

- Added `network_performance_options` variable to support `bandwidth_weighting` configuration on `aws_launch_template`
- Added input validation for `bandwidth_weighting` to restrict values to `default`, `vpc-1`, or `ebs-1`
- Added `with_network_performance_options` test configuration

## 1.9.1 - 17th February 2026

- Updated various default values to empty strings.
- Updated AWS provider version to `6.32.1` 
- Updated terraform required version to `>= 1.9` 
- Updated review date
- Updated `eits-tf-aws-security-group` pinned version `3.5.1`

## 1.9.0 - 5th February 2026

- Added `enable_all_alarm_actions` variable
- Changed default behaviour for alarm actions. Only `ALARM` will always be enabled when `alarm_sns_topics` is specified
- Added `eitsce:parentmodule` tag to child resources

## 1.8.2 - 05th November 2025

- Update `eits-tf-aws-security-group` pinned version `3.5.0`

## 1.8.1 - 24th July 2025

- Updated review date
- Updated `.pre-commit-config.yml` to `v1.3.1`

## 1.8.0 - 24th June 2025

- Removed EOL `elastic_gpu_specifications` and `elastic_inference_accelerator` arguments from aws_launch_template
- Updated deprecated Argument in `aws_region` datasource from `name` to `region`
- Required aws provider version bumped to `v6.0.0`

## 1.7.1 - 23rd April 2025

- Updated Security Group module to bugfix version 3.3.3

## 1.7.0 - 1st April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Renamed `warnings.tf` to `checks.tf`
- Updated `pre-commit` version to `1.3.0`
- Bumped `eits-tf-aws-cloudwatch-alarm` version to `1.3.0`
- Bumped `eits-tf-aws-security-group` version to `3.3.0`

## 1.6.0 - 11th March 2025

- Raised required minimum version of terraform to 1.5 to support check blocks.
- Added warning if IMDSv2 is not required.
- Added warning if the autoscaling group is in a single availibility zone.
- Added warning if the autoscaling group does not have ELB health checks.
- Added warning `var.capacity_rebalance` is not set to `true`, and why you might want it.

## 1.5.0 - 31st January 2025

- Added `cloudwatch_tags` variable to allow adding Cloudwatch specific tagging.
- Bumped `eits-tf-aws-cloudwatch-alarm` module version to `1.2.0`.

## 1.4.0 - 17th January 2025

- Removed deprecated AMIs `sles_12` and `bottlerocket`.
- Added argument `availability_zone_distribution`.
- Added attributes `max_healthy_percentage`, `skip_matching`, and `alarm_specification` to `instance_refresh.preferences`.
- Bumped `hashicorp/aws` provider version to `5.82.1`.
- Bumped `eits-tf-aws-security-group` module version to `3.0.6`.
- Bumped `pre-commit` version to `1.2.2`.

## 1.3.0 - 22nd July 2024

- Add `create_autoscaling_group` variable to enable users to just provision a launch template, etc, if required.
- Add `null` default to a number of variables.  
- Fix issue with `launch_template_config.network_interfaces` IP arguments having incorrect types.
- Add new `name_prefix` variable to allow overwriting of the EEC prefix if required.

## 1.2.1 - 20th June 2024

- Update Security Group module to use v3.0.1.

## 1.2.0 - 14th June 2024

- Add ability to create a security group using the `create_security_group` map. This security group will be added to launch template automatically in addition to any other security groups specified.
- Modify "basic" test to create security group within module.
- Update alarm module to use v1.1.2.
- Update required aws provider to 4.0 due to security group module.

## 1.1.0 - 20th March 2024

- The following variables have been depreciated in favour of using `launch_template_config`. These variables may be removed in future releases:
  - `security_groups` -> `launch_template_config.security_groups`
  - `network_interfaces` -> `launch_template_config.network_interfaces`

## 1.0.1 - 26th February 2024

- Fix Trivy issue: Updated test as a best practice example when using predefined launch templates
- Added pre-commit config

## 1.0.0 - 15th December 2023

- Initial release
