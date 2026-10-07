# AWS Secrets Manaager Module

EITS Terraform module for AWS Secrets Manager. This module will:

- Allows for automation of secrets managing
- Allows for secrets rotation
- Create a secrets manager policy
- Allows the creation of replicas
- Generate a random password, if required

 See CHANGELOG.md for the list of changes for each release.
 > We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.

## EITS Security & Compliance

**Last Module Review**: 2026-08-14

See below for the date and results of our EITS security and compliance scanning.
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-08-14 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-08-14 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-08-14 | 0.72.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-08-14 | 1.59.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Notes

- When using `secret_string`, it will be set once on creation and then ignored by terraform. This uses [write-only arguments](https://developer.hashicorp.com/terraform/language/manage-sensitive-data/ephemeral#write-only-arguments), meaning the secret will no longer be held in the state file. In order to force an update you must increment `secret_string_version`, though it is recommended to rotate the secret automatically using the AWS methods rather than manage it via terraform.
- When adding `secret_users` and/or `secret_owners` they will have permission to the secret value, but the role used to create the secret will not be able to read the secret value.
- It is recommended to configure secret rotation. The [Rotate Secrets section in the Secrets Manager User Guide](https://docs.aws.amazon.com/secretsmanager/latest/userguide/rotating-secrets.html) provides additional information about deploying a prebuilt Lambda functions for supported credential rotation (e.g., RDS) or deploying a custom Lambda function.

## Usage

```hcl

module "secrets" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-secrets-manager.git?ref=<latest tag>"

  name = "eits-tf-aws-secrets-manager"
  description   = "Test for Secret Manager module"
  kms_key_id    = module.kms_key.key_id

  # it is recommended to use secure methods of passing this argument
  # for example jenkins credentials
  secret_string = "super secret string, dont do it in plain text like this"

}
```


<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.57.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.57.1 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |

## Resources

| Name | Type |
|------|------|
| [aws_secretsmanager_secret.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_policy) | resource |
| [aws_secretsmanager_secret_rotation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_rotation) | resource |
| [aws_secretsmanager_secret_version.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_session_context.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_description"></a> [description](#input\_description) | Description of the secret. | `string` | `null` | no |
| <a name="input_external_secret_rotation_metadata"></a> [external\_secret\_rotation\_metadata](#input\_external\_secret\_rotation\_metadata) | One or more metadata key/value blocks required by the external rotation partner. Used with managed external secret rotation. | <pre>list(object({<br/>    key   = string<br/>    value = string<br/>  }))</pre> | `[]` | no |
| <a name="input_external_secret_rotation_role_arn"></a> [external\_secret\_rotation\_role\_arn](#input\_external\_secret\_rotation\_role\_arn) | ARN of the IAM role to be assumed by Secrets Manager to rotate the secret via an external rotation service. Used with managed external secret rotation. | `string` | `null` | no |
| <a name="input_force_overwrite_replica_secret"></a> [force\_overwrite\_replica\_secret](#input\_force\_overwrite\_replica\_secret) | Accepts boolean value to specify whether to overwrite a secret with the same name in the destination Region | `bool` | `false` | no |
| <a name="input_generate_random_password"></a> [generate\_random\_password](#input\_generate\_random\_password) | If `true`, a random password will be generated and used as the `secret_string` value. | `bool` | `false` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | Customer Master Key Id to be used to encrypt the secrets values | `string` | `null` | no |
| <a name="input_name"></a> [name](#input\_name) | Friendly name of the new secret. The secret name can consist of uppercase letters, lowercase letters, digits, and any of the following characters: /\_+=.@-. Conflicts with `name_prefix` | `string` | `null` | no |
| <a name="input_name_prefix"></a> [name\_prefix](#input\_name\_prefix) | Name for the resource, terraform will append a random suffix. Conflicts with `name` | `string` | `null` | no |
| <a name="input_policy"></a> [policy](#input\_policy) | Removing `policy` from your configuration or setting `policy` to null or an empty string (i.e., `policy =`) will not delete the `policy` since it could have been set by `aws_secretsmanager_secret_policy`. | `string` | `null` | no |
| <a name="input_policy_override"></a> [policy\_override](#input\_policy\_override) | Override generated policy. Requires a valid JSON document representing a resource policy | `string` | `null` | no |
| <a name="input_random_password_config"></a> [random\_password\_config](#input\_random\_password\_config) | Random password configuration to use when `generate_random_password` is `true`. By default, Secrets Manager uses uppercase and lowercase letters, numbers, and [these characters in passwords](https://docs.aws.amazon.com/secretsmanager/latest/apireference/API_GetRandomPassword.html). | <pre>object({<br/>    exclude_characters         = optional(string)<br/>    exclude_lowercase          = optional(bool)<br/>    exclude_numbers            = optional(bool)<br/>    exclude_punctuation        = optional(bool)<br/>    exclude_uppercase          = optional(bool)<br/>    include_space              = optional(bool)<br/>    password_length            = optional(number)<br/>    require_each_included_type = optional(bool)<br/>  })</pre> | `{}` | no |
| <a name="input_recovery_window_in_days"></a> [recovery\_window\_in\_days](#input\_recovery\_window\_in\_days) | Number of days that AWS Secrets Manager waits before it can delete the secret | `number` | `30` | no |
| <a name="input_replicas"></a> [replicas](#input\_replicas) | Configuration block to support secret replication. Defined below.<br/>   <pre>replicas =<br/>    [{<br/>      kms\_key\_id  = (Optional) ARN, Key ID, or Alias of the `AWS KMS key` within the region secret is replicated to. If one is not specified, then Secrets Manager defaults to using the AWS account's default KMS key `(aws/secretsmanager)` in the region or creates one for use if non-existent.<br/>      region               = (Required) Region for replicating the secret.<br/>    }]<br/>   </pre> | <pre>list(object({<br/>    kms_key_id = string,<br/>    region     = string<br/>  }))</pre> | `[]` | no |
| <a name="input_rotate_immediately"></a> [rotate\_immediately](#input\_rotate\_immediately) | Specifies whether to rotate the secret immediately or wait until the next scheduled rotation window | `bool` | `null` | no |
| <a name="input_rotation_lambda_arn"></a> [rotation\_lambda\_arn](#input\_rotation\_lambda\_arn) | Specifies the ARN of the Lambda function that can rotate the secret. Must be supplied if the secret is not [Managed by AWS](https://docs.aws.amazon.com/secretsmanager/latest/userguide/service-linked-secrets.html) | `string` | `null` | no |
| <a name="input_rotation_rules"></a> [rotation\_rules](#input\_rotation\_rules) | A structure that defines the rotation configuration for this secret. Defined below.<br/>   <pre>rotation\_rules = <br/>    {<br/>      automatically\_after\_days = (Optional) Specifies the number of days between automatic scheduled rotations of the secret. Either `automatically_after_days` or `schedule_expression` must be specified.<br/>      duration                 = (Optional) The length of the rotation window in hours. For example, `3h` for a three hour window.<br/>      schedule\_expression      = (Optional) `A cron()` or `rate()` expression that defines the schedule for rotating your secret. Either `automatically_after_days` or `schedule_expression` must be specified.<br/>    }<br/>   </pre> | <pre>object({<br/>    automatically_after_days = optional(number)<br/>    duration                 = optional(string)<br/>    schedule_expression      = optional(string)<br/>  })</pre> | `{}` | no |
| <a name="input_secret_binary"></a> [secret\_binary](#input\_secret\_binary) | Specifies binary data that you want to encrypt and store in this version of the secret. This is required if `secret_string` is not set. Needs to be encoded to base64. | `string` | `null` | no |
| <a name="input_secret_owners"></a> [secret\_owners](#input\_secret\_owners) | AWS principals that are granted ownership of the secret, terraform user will automatically be added | `list(string)` | `[]` | no |
| <a name="input_secret_string"></a> [secret\_string](#input\_secret\_string) | Specifies text data that you want to encrypt and store in this version of the secret. This is required if `secret_binary` is not set. Ignored if `generate_random_password` is `true`. | `string` | `null` | no |
| <a name="input_secret_string_version"></a> [secret\_string\_version](#input\_secret\_string\_version) | Increment this value when an update to `secret_string` is required, otherwise changes will be ignored by terraform. See README for details. | `number` | `1` | no |
| <a name="input_secret_users"></a> [secret\_users](#input\_secret\_users) | AWS principals that are allowed to use the secret | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags | `map(string)` | `{}` | no |
| <a name="input_type"></a> [type](#input\_type) | Type of secret. Valid values: `AWS_OPAQUE`, `AWS_MANAGED_ROTATION`. Required when using managed external secret rotation. | `string` | `null` | no |
| <a name="input_version_stages"></a> [version\_stages](#input\_version\_stages) | Specifies a list of staging labels that are attached to this version of the secret. A staging label must be unique to a single version of the secret. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_rotation_enabled"></a> [rotation\_enabled](#output\_rotation\_enabled) | Specifies whether automatic rotation is enabled for this secret |
| <a name="output_secret_arn"></a> [secret\_arn](#output\_secret\_arn) | Amazon Resource Name (ARN) of the secret. |
| <a name="output_secret_id"></a> [secret\_id](#output\_secret\_id) | Amazon Resource Name (ARN) of the secret. |
| <a name="output_secret_replica"></a> [secret\_replica](#output\_secret\_replica) | All attributes for replica |
| <a name="output_secret_version"></a> [secret\_version](#output\_secret\_version) | The unique identifier of the version of the secret. |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS Secrets Manager
region: Global
bu: T&I
docs: https://experian.atlassian.net/wiki/x/HQ4EF
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>
```