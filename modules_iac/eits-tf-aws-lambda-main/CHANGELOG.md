# RELEASE NOTES

## 1.11.1 - 1st July 2026

- Updated `eits-tf-aws-iam` to version `1.9.7`
- Updated `eits-tf-aws-cloudwatch-logs` to version `2.6.1`
- Updated `pre-commit` to version `1.4.0`
- Updated aws provider version to `6.48.0` for bugfixs

## 1.11.0 - 11th March 2026

- Added `permissions_boundary` variable
- Passed `permissions_boundary` through to the `eits-tf-aws-iam` submodule when creating the role

## 1.10.0 - 4th February 2026

- Added `enable_all_alarm_actions` variable
- Changed default behaviour for alarm actions. Only `ALARM` will always be enabled when `alarm_sns_topics` is specified
- Added `eitsce:parentmodule` tag to child resources

## 1.9.1 - 5th January 2026

- Added support for overriding the created Lambda IAM role name via `override_role_name` and `role_name`.

## 1.9.0 - 23rd December 2025

- Added feature to specify a Cloudwatch Log Group if required
- Updated min Terraform version to `1.9` to support sub modules

## 1.8.5 - 10th December 2025

- Updated `eits-tf-aws-cloudwatch-logs` module to version `2.6.0`
- Updated `eits-tf-aws-iam` module to version `1.9.2`

## 1.8.4 - 8th November 2025

- Updated aws provider version to `6.21.0` for bugfix and enhancements
  - Adds support for `java25`, `nidejs24.x` and `python3.14` `runtime`
- Add `source_kms_key_arn` attribute
- Updated review date

## 1.8.3 - 8th September 2025

- Update pinned version of `eits-tf-aws-iam` to `1.9.1`

## 1.8.2 - 19th August 2025

- Removed `deprecated_variable_warning` check for `lambda_environment`

## 1.8.1 - 28th July 2025

- Changed deprecated reference on aws_region data source.
- Updated aws provider version to 6.0.0

## 1.8.0 - 27th May 2025

- Deprecated `lambda_environment` in favour of new `environment_variables` variable:
  - ***Please see CHANGELOG for migration details***
  - Renamed `lambda_environment` to `environment_variables` for clarify.
  - Removed requirement for nested `variables` object.
  - Changed default from `null` to `{}`.
  - Changed type to `map(string)`.
  - Automatically add `NO_PROXY` environment variables if not supplied and both `HTTP_PROXY` and `vpc_config` are set.
- Added the following new variables:
  - `provisioned_concurrent_executions` to support provisioned concurrency.
  - `alias_name` for alias creation.
  - `function_url` for creation of a dedicated HTTP endpoint.
- Added the following new outputs:
  - `code_sha256`
  - `qualified_invoke_arn`
  - `version`
  - `function_url`
- Changed default value for `source_code_hash` and `kms_key_arn` to `null`.
- Add policy description to fix IAM module check warning.
- Updated minimum AWS provider version to `5.94.0` in order to support the latest runtimes (`ruby3.4`, `nodejs22.x`, `python3.13`, etc).
- Updated IAM module version to `1.8.0`.
- Updated pre-commit version to `1.3.1`.

### Migrating to 1.8 and above

Any `lambda_environment` variables in the old format:

```hcl
lambda_environment = {
  variables = {
    key = "value"
  }
}
```

Must be renamed, and migrated to the new `environment_variables` map:

```hcl
environment_variables = {
  key = "value"
}
```

## 1.7.1 - 23rd April 2025

- Updated Cloudwatch Logs module to bugfix version 2.5.1

## 1.7.0 - 9th April 2025

- Migrated to use newer `ce-common` module instead of `vars`
- Renamed `warnings.tf` to `checks.tf`
- Bumped `eits-tf-aws-cloudwatch-alarm` version to `1.3.0`
- Bumped `eits-tf-aws-cloudwatch-logs` version to `2.5.0`
- Bumped `eits-tf-aws-iam` version to `1.7.1`

## 1.6.0 - 11th March 2025

- Updated pre-commit comfig to `1.3.0`
- Added warning for if Lambda is getting `lambda_environment` without `kms_key_arn` being set also.
- Changed default for `reserved_concurrent_executions` from `-1` (no limits) to `5`.  This can still be manually set to -1 if needed but a warning will result.

## 1.5.0 - 31st January 2025

- Added `cloudwatch_tags` variable to allow adding Cloudwatch specific tagging.
- Bumped `eits-tf-aws-cloudwatch-alarm` module version to `1.2.0`.
- Bumped `pre-commit` version to `1.2.2`.

## 1.4.0 - 7th October 2024

- Added Support for Lambda advanced logging configurations
- Added Support for recursion config
- Updated aws provider version to >= 5.67.0  to allow support of the latest aws lambda runtimes and fix provider bugs
- Upgrade IAM module to version 1.3.3
- Upgrade CloudWatch Logs module to version 2.3.0

## 1.3.1 - 9th August 2024

- Updated alarm module to fix tag validation errors

## 1.3.0 - 5th March 2024

- Updated IAM module to version 1.3.2. Please see Jira ticket [UKICLOENA-1511](https://agile.experian.com/browse/UKICLOENA-1511) for more information.

## 1.2.0 - 13th February 2024

- Replaced the CloudPosse CloudWatch Logs module with the EITS one ***Please see notes below on how to migrate the existing CloudWatch Logs Log Group***
- Added default CloudWatch alarms

### Migrating from 1.1.x to 1.2

Versions 1.1.3 and below were leveraging CloudPosse module to manage the CloudWatch Logs log group. However, they were also creating a log group ending in `-logs`, which was not used by Lambda as its log group name must match the function name.
Therefore, when migrating to 1.2.0 and above, the existing CloudWatch Logs log group called `/aws/lambda/<function_name>-logs` will be deleted. This log group should be empty (please verify this before proceeding) as Lambda would have created a new log group called `/aws/lambda/<function_name>`.
To import the existing log group, please add the following `import` block in your code:

```hcl
import {
  to = module.<your_module_name>.module.cloudwatch_log_group.aws_cloudwatch_log_group.this
  id = "/aws/lambda/<function_name>"
}
```

## 1.1.3 - 26th October 2023

- Add benchmark table to README.md

## 1.1.2 - 13th October 2023

- Add ability to pass in a pre-existing role for the Lambda
- Add extra test for existing role vs. creating one
- Added CONTRIBUTING.md guide

## 1.1.1 - 18th September 2023

- Merge functionality of vars, tagging and label modules

## 1.1.0 - 11th September 2023

- Add tests directory with Jenkinsfile for pull request testing
- Add test terraform configuration and lambda source archive

## 1.0.1 - 15th August 2023

- Added EITS vars module

## 1.0.0 - 27th June 2023

- Initial release
