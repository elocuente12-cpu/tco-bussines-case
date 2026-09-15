# RELEASE NOTES

## 1.8.1 - 14th September 2026

- Updated confluence document links

## 1.8.0 - 4th February 2026

- Added `enable_all_alarm_actions` variable
- Changed default behaviour for alarm actions. Only `ALARM` will always be enabled when `alarm_sns_topics` is specified
- Added `eitsce:parentmodule` tag to child resources
- Bumped pre-commit to `1.3.1`

## 1.7.1 - 30th July 2025

- Added `topic_name` to outputs

## 1.7.0 - 1st April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Updated required Terraform version to `1.5`
- Converted warnings to `check` type
- Renamed `warnings.tf` to `checks.tf`
- Updated `pre-commit` version to `1.3.0`
- Bumped `eits-tf-aws-cloudwatch-alarm` version to `1.3.0`

## 1.6.0 - 07th February 2025

- Create `validation_warning` for CMK encryption
- Add SNS Topic delivery status logging default policy for success_sample_rate
- Add warnings to use a CMK for SNS topic encryption

## 1.5.0 - 31st January 2025

- Added `cloudwatch_tags` variable to allow adding Cloudwatch specific tagging.
- Bumped `eits-tf-aws-cloudwatch-alarm` module version to `1.2.0`.

## 1.4.1 - 24th January 2025

- Updated `hashicorp/aws` provider required version to to 5.46.0

## 1.4.0 - 10th October 2024

- Add default policy to deny insecure communications on publish
- Add ability to enable insecure communications on publish for edge cases
- Add warning if an incoming policy contains either `"Principal": ""` or `"Principal": "*"`
- Add pre-commit config

## 1.3.0 - 16th July 2024

- Add `archive_policy` argument and `beginning_archive_time` output to support [message archiving](https://docs.aws.amazon.com/sns/latest/dg/fifo-message-archiving-replay.html).
- Add `replay_policy` key to `subscribers` argument.
- Add `signature_version` argument.
- Add `tracing_config` argument.
- Add `message_delivery_status` argument to enable delivery logging.
- Update required AWS provider version to [5.25.0](https://github.com/hashicorp/terraform-provider-aws/blob/main/CHANGELOG.md#5250-november-10-2023) due to new arguments.

## 1.2.0 - 10th July 2024

- Add new `name_prefix` variable to allow overwriting of the EEC prefix if required.
- Upgrade CloudWatch Alarms module to version 1.1.2.

## 1.1.0 - 18th December 2023

- Added default alarms - ***Please be aware that adding the default alarms may increase the cost of the topic between $0.40 and $0.90 per month. To disable the creation of these alarms, please set the variable `disable_default_alarms` to true***

## 1.0.0 - 30th October 2023

- Initial release
