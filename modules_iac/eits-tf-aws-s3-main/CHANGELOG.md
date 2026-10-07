# RELEASE NOTES

## 2.19.2 - 14th September 2026

- Updated confluence document links

## 2.19.1 - 30th June 2026

- Updated aws provider version to 6.46.0 bug fix.
- Updated `eits-tf-aws-iam` module to 1.9.7

## 2.19.0 - 4th May 2026

- Added `prefix` variable to support optional bucket name prefix. When set, the bucket name is constructed as `{prefix}-{bucket_name}-s3`.
- Added `replication_role_name` variable to allow specifying a custom IAM role/policy name for replication (auto-generated as `BURoleForReplication-{bucket_name}` when null).
- Added `permissions_boundary` variable to support IAM permissions boundaries on the replication role.
- Added `replication_role_attach_policy_inline` variable. When `true`, the replication policy is attached as an inline role policy instead of a managed policy.
- Added `aws_iam_role_policy.replication_inline` resource to attach an inline policy when `replication_role_attach_policy_inline = true`.
- Added `data.aws_iam_policy_document.replication_combined` to consolidate source, source KMS, and replica KMS policy documents.
- Added `replication_role_name` output exposing the IAM role name created for replication.
- Added `replication_policy_json` output exposing the combined replication IAM policy JSON.
- Updated `main.tf` to use `local.bucket_name` instead of `var.bucket_name` to support the new `prefix` variable.

## 2.18.0 - 23rd February 2026

- Removed `validation` provider and moved error checks into variable validation.
- Updated aws provider minimum version to `6.31.0`.
- Updated minimum Terraform version to `1.9.0`.
- Removed deprecated `expected_bucket_owner` variable. ***Note that if you made use of this variable, you will now need to remove it from your configuration. Thesetting was redundant as the bucket owner will always be the owning account id***

## 2.17.0 - 05th February 2026

- Fixed: Hardcoded the `replication_time` value to 15 for RTC to comply with AWS S3 requirements and prevent invalid configuration errors.

## 2.16.0 - 4th February 2026

- Added `enable_all_alarm_actions` variable
- Changed default behaviour for alarm actions. Only `ALARM` will always be enabled when `alarm_sns_topics` is specified
- Added `eitsce:parentmodule` tag to child resources

## 2.15.2 - 10th December 2025

- Updated `eits-tf-aws-iam` module to version `1.9.2`

## 2.15.1 - 12th November 2025

- Change to required AWS provider version to `>= 6.15.0`to incorporate lifecycle bug fix
- Updated review date

## 2.15.0 - 30th September 2025

- Added new variable to set the `target_object_key_format` for logging
- `target_object_key_format` defaults to standard `simple_prefix` if not set

## 2.14.1 - 8th September 2025

- Updated pinned version for `eits-tf-aws-iam`

## 2.14.0 - 17th July 2025

- Added default lifecycle rule to abort incomplete multipart uploads
- Replaced deprecated `name` attribute in `aws_region` data source
- New variables: `enable_abort_incomplete_multipart_upload`,
  `default_abort_incomplete_multipart_upload_days`
- Change to required AWS provider version to `>= 6.0.0`

## 2.13.3 - 17th July 2025

- Fixed `restrict_overly_permissive_bucket_policy` check

## 2.13.2 - 26th June 2025

- fixed erroneous warning when `lifecycle.filter` was not set.
- updated aws provider version
- removed unneeded https check, as this is already enforced

## 2.13.1 - 2nd May 2025

- Fixed `restrict_overly_permissive_bucket_policy` check

## 2.13.0 - 30th April 2025

- Added `restrict_overly_permissive_bucket_policy` check to `checks.tf`

## 2.12.1 - 29th April 2025

- Added VPC endpoints for `ap-south-1` and `sa-east-1` regions
- Fixed error where VPC endpoint policy was failing if the region was not found in the endpoint list

## 2.12.0 - 22nd April 2025

- Added ability to create S3 Access Points using new `access_points` variable.
- Added `s3_access_points` output.

## 2.11.1 - 10th April 2025

- Updated IAM module to 1.7.1
- Updated AWS provider to 5.94.1 (from 5.63.0). The breaking change introduced in 5.90.0 has been accounted for as both `rule.noncurrent_version_expiration.noncurrent_days` and `rule.noncurrent_version_transition.noncurrent_days` are used

## 2.11.0 - 1st April 2025

- Updated pre-commit config to 1.3.0
- Updated IAM module to 1.7.0
- Updated Cloudwatch Alarm module to 1.3.0
- Updated `eits_vars` to `eits_ce_common`
- Renamed `warnings.tf` to `checks.tf`

## 2.10.0 - 17th March 2025

- Raised required version of terraform from `1.0` to `1.5.0`
- Added a check that the bucket policy should deny HTTP requests.
- Added a check that the bucket has all public access settings beng blocked.
- Added a check that if `var.disable_source_ip_check` is set to `true` it issues a warning about the risks involved.
- Added a warning should `var.object_ownership` not be set to `BucketOwnerEnforced`
- Added a warning should `var.disable_default_alarms` be disabled. 

## 2.9.1 - 24th February 2025

- Added SkyHigh proxy static IPs.

## 2.9.0 - 31st January 2025

- Added `cloudwatch_tags` variable to allow adding Cloudwatch specific tagging.
- Bumped `eits-tf-aws-cloudwatch-alarm` module version to `1.2.0`.

## 2.8.0 - 8th October 2024

- Set `bucket_key_enabled` to `true` for all types of encryption, not just KMS.

## 2.7.0 - 24th September 2024

- Added AWS Provider locked to greater than `5.63.0` to incorporate provider bug fixes.

## 2.6.0 - 24th September 2024

- Added `aws_s3_bucket_object_lock_configuration` resource to allow S3 object locking

## 2.5.1 - 30th August 2024

- Added new conditions in the default bucket policy:
  - Added CIDRs for new SkyHigh proxy
  - Added `aws:CalledVia` and `aws:PrincipalIsAWSService` to allow access to AWS services

## 2.5.0 - 20th May 2024

- Added default bucket policy that denies any access to source IPs not originating from the EEC approved CIDR list. You may disable this behaviour with the `disable_source_ip_check` variable, though the `"eitsce:sourceipcheck":"disabled"` tag will be added for report exclusion purposes.
- Added the following new variables related to above policy, see input descriptions for details:
  - `disable_source_ip_check`
  - `disable_source_vpce_check`
  - `allowed_source_vpce_ids`
- Added `bucket_regional_domain_name` output.
- Fully defined `lifecycle_rules`, `intelligent_tiering` and `acl_grants` variable types.
- Refactor lifecycle rules resource and some other conditions.
- Fix `lifecycle_rules.transition` bug where it would ignore multiples.
- Updated IAM module to version 1.3.3.
- Updated Cloudwatch Alarms module to version 1.1.2.

### Migrating to v2.5.0

- Confirm that any `lifecycle_rules` arguments still match the new variable definition. ***Please be aware number of `days` arguments have been renamed `noncurrent_days` to match the terraform resource arguments.***
- If you receive a `no matching EC2 VPC Endpoint found` error when applying, set `disable_source_vpce_check` to `true`. This is due to non-EEC VPC endpoint configurations.
- A number of conditions have been refactored, please check any apply to make sure resources are recreated/unchanged.

## 2.4.1 - 22nd March 2024

- Fix interpolation-only expressions, as these are deprecated.

## 2.4.0 - 5th March 2024

- Updated IAM module to version 1.3.2. Please see Jira ticket [UKICLOENA-1511](https://agile.experian.com/browse/UKICLOENA-1511) for more information.
- This version of the IAM module adds a default policy to deny assume role access to roles outside of the organization. You may disable this functionality by setting the variable `disable_org_check` to `true`. Note the IAM role is only created if `replication_config` is enabled.

## 2.3.0 - 20th February 2024

- Added optional replication config and iam role creation
- Create default CloudWatch alarms if replication is enabled
- Update required aws provider version to >= 5.0 due to replication resource
- Enforce SecureTransport and TLS 1.2 policy for object uploads
- Merge both `bucket_policy` and `source_policy_documents` policies, allowing either/both to be supplied
- Delete "SSE-S3_MultiplePolicies" test directory as superfluous
- Modify "SSE-KMS_PolicyFile" test policy file to be templated, and more relevant
- Modify "SSE-S3_PolicyData" test to use `source_policy_documents`

### Migrating to v2.3.0
- The terraform migration.tf will move some S3 policy resources, however you may still find policy gets recreated. Please double-check the terraform plan to make sure the bucket is not left without a policy.
- New policy configuration will restrict non-secure access to buckets, please test current access methods post-migration.

## 2.2.1 - 31st January 2024

- Added default request metrics - ***Please be aware that adding the request metrics will increase the cost of the bucket (see README.md). To disable the creation of these metrics, please set the variable `disable_default_alarms` to true***

## 2.2.0 - 9th January 2024

- Added default alarms - ***Please be aware that adding the default alarms will increase the cost of the bucket (see README.md). To disable the creation of these alarms, please set the variable `disable_default_alarms` to true***

## 2.1.2 - 1st November 2023

- Add CONTRIBUTING.md

## 2.1.1 - 26th October 2023

- Add benchmark table to README.md

## 2.1.0 - 6th October 2023

- Allow multiple IAM policy documents to be passed using source_policy_documents

## 2.0.1 - 3rd October 2023

- Fix fileexists error

## 2.0.0 - 15th September 2023

- Add tests directory with Jenkinsfile for pull request testing
- Add test terraform configuration for both types of encryption and 2 ways of adding policy
- Formatted terraform with fmt
- Versioning now defaults to true, and is now boolean controlled
- SSE is now enforced, defaulting to SSE-S3/AES256, KMS key can be configured if required.
- Update gitignore file
- Added tfsec exception for false postive
- Fix logging prefix
- Public access blocking is now hidden away in a new optional map
- Policy can now be passed either as a file or json string
- Add ability to set ACLs if required (default to disabled)
- Renamed (to match tf arguments) and pruned some input variables, alphabetised file
- Added required versions file
- Add additional outputs (mostly for route53 record creation)
- Add EITS CE tag validation

## 1.0.1 - 16th August 2023

- Add standard EITS CE tags using eits_vars module 

## v1.0.0 - 24th February 2023

- Initial release