# RELEASE NOTES

## 1.9.8 - 14th September 2026

- Updated confluence document links

## 1.9.7 - 27th April 2026

- Update cda.json with new schema
- Update `pre-commit` version to `1.4.0`

## 1.9.6 - 3rd March 2026

- Added tags to instance profile resource to resolve Wiz scan failures

## 1.9.5 - 23rd February 2026

- Updated AWS provider version to `6.34.0`
- Updated review date

## 1.9.4 - 5th February 2026

- Added additional EEC tags to ignore in lifecycle

## 1.9.3 - 15th December 2025

- Bugfix: Updated check iam146 to stop reporting false positives on `Deny` statements in assumeRole policies

## 1.9.2 - 24th November 2025

- Removed `"eitsce:orgcheck":"disabled"` tag when `disable_org_check` is `true`

## 1.9.1 - 9th September 2025

- Bumped required Terraform provider to `1.9` to support cross-object variable validation

## 1.9.0 - 28th August 2025

- Added `trusted_service` variable
- Made `assume_role_policy` not mandatory, and added validation for trust policy
- Updated README

## 1.8.1 - 10th July 2025

- Fix "condition could not be evaluated at this time" check spam by merging 24 checks into 1
- Fix IAM-057 false positive on the ExternalID check where anything with an "AssumeRole" action was flagging
- Fix IAM-146 check so it actually checks trust policy, also fixed the logic
- Fix IAM-197 check so it checks for all wildcards, not just action specific ones
- Modify the following variables default values to `null` instead of `""`:
  - `permissions_boundary`
  - `role_description`
  - `policy_description`
- Remove both description related checks
- Automatically generate both role and policy descriptions if `null`
- Remove unnecessary validation from the following variables:
  - `role_name`
  - `assume_role_policy`
- Add additional EEC tags to ignore in lifecycle
- Updated pre-commit to version `1.3.1`

## 1.8.0 - 13th May 2025

- Module biannual review
- Added checks for Wiz Rules `IAM-025` and `IAM-197`

## 1.7.1 - 2nd April 2025

- Fixed checks failing if `resources` was not defined in a statement
- Moved policy statements loop to a local to reduce code in checks

## 1.7.0 - 1st April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Renamed `warnings.tf` to `checks.tf`

## 1.6.0 - 18th March 2025

- Added a plethora of warnings for various unsafe IAM policy patterns.

## 1.5.0 - 12th March 2025

- Added validations for `policy_name`, `role_description`, and `policy_description`.
- Bumped Terraform required version to `1.5.0`.

## 1.4.0 - 5th February 2025

- Added `lifecycle` metadata to `aws_iam_role` to ignore changes to the `eec:` tags for 3rd party access (see the [EEC doc](https://pages.experian.local/display/SC/How+to+enable+third-party+access+to+AWS+via+cross-account+roles#HowtoenablethirdpartyaccesstoAWSviacrossaccountroles-Terraformbestpractices))
- Bumped `pre-commit` version to 1.3.0

## 1.3.3 - 13th May 2024

- Add additional EEC recommended PrincipalOrgIDs to "DenyNonExperianAccountAccess" trust policy
- Add `"eitsce:orgcheck":"disabled"` tag when `disable_org_check` is `true` for report exclusion purposes
- Tidy up README.md

## 1.3.2 - 7th March 2024

- Reverted Deny behaviour and included extra condition to allow AWS services assume role ability.

## 1.3.1 - 6th March 2024 *(USE WITH CAUTION)*

> **IMPORTANT UPDATE:** This build will work, but if the `enable_org_check` variable is set to true it could cause issues with AWS services using any role created with this version. Please use version `1.3.2` or greater to ensure full compatibility.

- **BUGFIX** Changed Deny behaviour

## 1.3.0 - 4th March 2024 *(BROKEN, DO NOT USE)*

> **IMPORTANT UPDATE:** This build is broken and could cause issues with AWS services using any role created with this version. Please use version `1.3.2` or greater.
- Added explicit Deny on Assume Role Trust policy to deny access to any service not originating in the Experian Organization. Please see Jira ticket [UKICLOENA-1511](https://agile.experian.com/browse/UKICLOENA-1511) for more information.
- Added pre-commit config

## 1.2.2 - 1st November 2023

- Add CONTRIBUTING.md

## 1.2.1 - 26th October 2023

- Add benchmark table to README.md

## 1.2.0 - 21st September 2023

- Add tests directory with Jenkinsfile for pull request testing
- Merge functionality of vars, tagging and label modules
- Update .gitignore file
- Fix tflint recommendations:
  - Add versions file
  - List items should be accessed using square brackets

## 1.1.2 - 25th August 2023

- Made `policy_name` variable no longer mandatory

## 1.1.1 - 14th August 2023

- Added EITS vars module

## 1.1.0 - 27th July 2023

- Added tag validation via eits-tf-aws-tagging module

## 1.0.1 - 07th July 2023

- Fixed issue with empty policy documents

## 1.0.0 - 27th June 2023

- Initial release