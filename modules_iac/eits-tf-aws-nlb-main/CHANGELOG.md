# RELEASE NOTES

## 3.8.2 - 22nd September 2026

- BUGFIX: Changed logic on alarm conditions to work with newer TF versions and how they handle resolving elements in a condition
- Updated module `cloudwatch-alarm` to version `1.3.1`

## 3.8.1 - 14th September 2026

- Updated confluence document links

## 3.8.0 - 2nd July 2026

- Added NLB CloudWatch alarms in `alarms.tf`, including:
  - default `TCP_ELB_Reset_Count` alarm
  - per-target-group `UnHealthyHostCount` alarm
  - per-target-group `HealthyHostCount` alarm
- Added `target_groups.target_alarm` for per-target-group alarm settings (`healthy_threshold` and `unhealthy_threshold`)
- Added alarm threshold variables: `alarm_tcp_elb_reset_threshold`, `healthy_host_alarm_threshold`, and `unhealthy_host_alarm_threshold`

## 3.7.0 - 11th December 2025

- Added the following new variables:
  - `dns_record_client_routing_policy`
  - `minimum_load_balancer_capacity_units`
  - `secondary_ips_auto_assigned_per_subnet`
- Updated pre commit version to `1.3.1`.
- Updated minimum AWS provider to `6.11` due to new features.

## 3.6.1 - 28th May 2025

- Updated review date
- Updated aws provider version to `5.98` for bug fixs to `aws_lb`

## 3.6.0 - 1st April 2025

- Updated `eits_vars` to `eits_ce_common`
- Renamed `warnings.tf` to `checks.tf`

## 3.5.0 - 7th March 2025

- Upgraded required terraform version to minimum 1.5 to support `strcontains`.
- Added `.pre-commit-config.yaml` targeting version 1.3.0.
- Added a warning if the protocol is not `TLS` to confirm this is intended and that no encryption will be handled by the Load Balancer with this setting. (Wiz ELB-047 )
- Added a warning if logging is not set up (Wiz VPC-040)
- If the protocol is `TLS`, added warnings for insecure protocols being used (TLS < 1.2, etc), or if certificate is not specified.

## 3.4.0 - 18th June 2024

- Change default value for `enable_cross_zone_load_balancing` to `null`.
- If `enable_cross_zone_load_balancing` is left at the default `null`, then it will automatically be set to `true` for resources with an "Environment" tag of value "prd", and set to `false` for other environments. This is a cost-saving measure. To override this, configure `enable_cross_zone_load_balancing`to either `true` or `false`.
- Fix acm module error (due to new version) in test directory

## 3.3.0 - 8th May 2024

- Variable types for `listeners`, `target_groups` and `subnet_mapping` have been defined in full.
- Fixed bug that was preventing targets registration.
- Fixed bugs with additional certificates not being applied.
- A number of arguments have moved map variables from `target_groups` to `listeners`, see below.
- Tidied up some default values and conditions.
- Updated variable descriptions.

### Migrating to v3.3.0

- The following arguments have been moved from `target_groups` to `listeners`:
  - `additional_certs`
  - `ssl_policy`
  - `certificate_arn`
- The default value for `access_log_bucket_id` is now `null` instead of `""`.
- The default value for `subnet_ids` is now `[]` instead of `null`.
- Listener certificate attachment has been modified, and may cause existing certificates to be re-deployed to listeners.

## 3.2.0 - 8th April 2024

- Allow a target group to be created without targets.
- Add new output `target_group_names`.

## 3.1.0 - 22nd March 2024

- Add `scheme` variable, allowing the ability to deploy an internet-facing load balancer.
- Add `security_groups` variable to allow assigning of security groups. ***Note: Adding or removing `security_groups` to an already existing NLB will cause the resource to be recreated.***
- Update required AWS provider version to [5.13.0](https://github.com/hashicorp/terraform-provider-aws/blob/main/CHANGELOG.md#5130-august-18-2023) due to new `security_groups` parameter.

## 3.0.0 - 5th December 2023

- Fixed issue with target group attachments that were recreated at every change by moving from `count` to `for_each`, and adding a `name` attribute in `targets` to be used as key - ***Please be aware that, if you're upgrading to this version from a previous one, the first time it runs, it will recerate the target attachments!***

## 2.0.4 - 2nd November 2023

- Fix insecure SSL policy in tests and readme

## 2.0.3 - 1st November 2023

- Add CONTRIBUTING.md

## 2.0.2 - 26th October 2023

- Add benchmark table to README.md

## 2.0.1 - 18th September 2023

- Merge functionality of vars, tagging and label modules

## 2.0.0 - 12th September 2023

- Separated listeners creation from target group (fixing an issue where it was creating one listener per target group. This allows to create a listener with multiple rules and target groups)

## 1.2.0 - 22nd August 2023

- Add tests directory with Jenkinsfile for pull request testing
- Add two test terraform configurations for tls and tcp
- Update cert_list condition to use length as recommended by tflint
- Fix nlb_name validation

## 1.1.0 - 9th August 2023

- Add standard EITS CE tags using eits_vars module

## 1.0.0 - 27th July 2023

- Initial release
