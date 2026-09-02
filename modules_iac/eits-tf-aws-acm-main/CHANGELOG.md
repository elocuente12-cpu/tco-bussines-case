# CHANGE LOG

## 2.3.3 - 19th August 2026

- Bugfix: Updated route53 module to version `1.7.1` to support new Service catalog product version

## 2.3.2 - 9th July 2026

- Update `route53` pinned version to `1.7.0`
- Update `terraform` version to `1.9.0`
- Updated `aws` provider version to `6.51.0`

## 2.3.1 - 24th April 2026

- Update cda.json with new schema
- Update `pre-commit` version to `1.4.0`

## 2.3.0 - 5th February 2026

- Added `enable_all_alarm_actions` variable
- Changed default behaviour for alarm actions. Only `ALARM` will always be enabled when `alarm_sns_topics` is specified
- Added `eitsce:parentmodule` tag to child resources

## 2.2.2 - 10th December 2025

- Updated `eits-tf-aws-route53` module to version `1.6.0`

## 2.2.1 - 16th June 2025

- Module biannual review
- Bumped `pre-commit` version to `1.3.1`
- Bumped `eits-tf-aws-route53` version to `1.5.1`
- Added `eitsce:parentmodule` tag to child modules

## 2.2.0 - 7th April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Updated required Terraform version to `1.5`
- Converted warnings to `check` type
- Renamed `warnings.tf` to `checks.tf`
- Updated `pre-commit` version to `1.3.0`
- Bumped `eits-tf-aws-cloudwatch-alarm` version to `1.3.0`
- Bumped `eits-tf-aws-route53` version to `1.5.0`

## 2.1.0 - 31st January 2025

- Support creation of Amazon certificates validated on external DNS domains
- Added Cloudwatch Alarm for certificate expiration
- Added `external_domain_validation` variable
- Added `domain_validation_options` output

## 2.0.1 - 4th November 2024

- Updated the hashicorp/aws provider to version 5.67.0
- Updated route53 pinned version to 1.3.1

## 2.0.0 - 12th June 2024

> :warning: **NOTE: THIS IS A BREAKING CHANGE, REVIEW README FOR UPDATED USAGE**

- Refactored terraform variables to support the import and request of certificates
- Support creation of ACM certificates with DNS validation
- Support creation of ACM certificates with EMAIL validation, this is a beta feature

## 1.1.2 - 1st November 2023

- Add CONTRIBUTING.md

## 1.1.1 - 26th October 2023

- Add benchmark table to README.md

## 1.1.0 - 21st September 2023

- Add tests directory with Jenkinsfile for pull request testing
- Merge functionality of vars, tagging and label modules
- Update .gitignore file
- Add versions file

## 1.0.1 - 14th August 2023

- Added tracking tags from eits-tf-aws-vars module

## 1.0.0 - 20th July 2023

- Initial release
