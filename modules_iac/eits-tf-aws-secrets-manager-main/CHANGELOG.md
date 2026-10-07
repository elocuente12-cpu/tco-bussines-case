# RELEASE NOTES

## 2.1.1 - 14th September 2026

- Updated confluence document links

## 2.1.0 - 14th August 2026

- Add `type` argument to `aws_secretsmanager_secret` in support of managed external secrets.
- Add `external_secret_rotation_role_arn` and `external_secret_rotation_metadata` arguments to `aws_secretsmanager_secret_rotation` in support of managed external secrets.
- Add `lifecycle` `ignore_changes` on `secret_string` to allow switching to `secret_string_wo` without resource recreation.
- BUGFIX: Changed incorrect variable type for `rotate_immediately` from `string` to `bool`
- Updated required AWS provider version to `6.57.1` to support new `type` argument on `aws_secretsmanager_secret`.

## 2.0.0 - 3rd December 2025

- Change `secret_string` to a Write-Only value, see below for warning.
- Add ability to generate a random password with `generate_random_password`.
- Updated required Terraform version to `1.11` due to new resources.
- Updated required AWS provider version to `5.88.0` due to new resources.
- Updated `pre-commit` version to `1.3.1`.

### Migrating from v1 to v2

- Be aware that from v2 a `secret_string` will be set once on creation and then ignored by terraform. This now uses [write-only arguments](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral#write-only-arguments), meaning the secret will no longer be held in the state file. In order to force an update you must increment `secret_string_version`, though it is recommended to rotate the secret automatically using the AWS methods rather than manage it via terraform.

## 1.2.1 - 28th May 2025

- Updated review date
- Increased aws provider version to `5.82` to fix bug in `automatically_after_days`

## 1.2.0 - 1st April 2025

- Removed `tlkamp/validation` provider
- Renamed `warnings.tf` to `checks.tf`
- Changed warnings to use check blocks
- Updated `eits_vars` to `eits_ce_common`

## 1.1.0 - 26th Feburary 2025

- Added `tlkamp/validation` provider
- Added warnings for empty `description`, `kms_key_id`, `rotation_lambda_arn`, and `rotation_rules`

## 1.0.0 - 7th October 2024

- Initial release
