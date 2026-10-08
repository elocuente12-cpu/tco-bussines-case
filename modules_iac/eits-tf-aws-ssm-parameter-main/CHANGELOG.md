# RELEASE NOTES

## 1.5.2 - 14th September 2026

- Updated confluence document links

## 1.5.1 - 27th April 2026

- Update cda.json with new schema
- Update `pre-commit` version to `1.4.0`

## 1.5.0 - 20th April 2026

- Updated `aws_ssm_parameter` resource to use `value_wo` and `value_wo_version` attributes
- Added `value_wo` variable as a write-only alternative to `value`, preventing sensitive data from being stored in Terraform state or plan files
- Added `value_wo_version` variable to trigger updates when using `value_wo`
- Updated required Terraform version to `>= 1.11.0` to support write-only attributes

## 1.4.3 - 10th April 2026

- Updated Terraform required version to `>= 1.9.0` 
- Updated AWS provider version to `>= 6.26.0`

## 1.4.2 - 9th April 2026

- Fix `parameter_value` output so it outputs insecure values, as well as secure ones.

## 1.4.1 - 28th JUly 2025

- Updated `.pre-commit-config.yml` from 1.3.0 to 1.3.1
- Updated review date

## 1.4.0 - 27th March 2025

- Converted warnings to check type (also renamed `warnings.tf` to `checks.tf`)
- Updated required Terraform version to 1.5
- Migrated to use newer ce-common module instead of vars
- Added descriptions to tests to give good example

## 1.3.0 - 27th Feburary 2025

- Added `tlkamp/validation` provider for doing validation warnings.
- Added validation warning for empty description.
- Added warning to detect potential secrets being stored as plaintext and notify.

## 1.2.1 - 2nd September 2024

- Bi-annual review:
  - Bumped provider version to fix a provider bug (see [terraform-provider-aws CHANGELOG](https://github.com/hashicorp/terraform-provider-aws/blob/main/CHANGELOG.md))
  - Enhanced variables description
- Added pre-commit hook

## 1.2.0 - 13th May 2024

- Add default `alias/aws/ssm` KMS key for SecureString type

## 1.1.2 - 1st November 2023

- Add CONTRIBUTING.md

## 1.1.1 - 26th October 2023

- Add benchmark table to README.md

## 1.1.0 - 26th September 2023

- Add tests directory with Jenkinsfile for pull request testing
- Merge functionality of vars and tagging modules
- Update README with source/argument corrections

## 1.0.1 - 15th August 2023

- Adding Standard EITS tags to enable usage monitoring

## 1.0.0 - 8th August 2023

- Initial release
