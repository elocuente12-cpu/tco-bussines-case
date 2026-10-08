# EITS Cloud Enablement AWS SSM Parameter Store Module

EITS Terraform module which creates [AWS SSM Parameters](https://docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html) on AWS. This module will:

- Create parameters in SSM parameter store
- Is able to assert parameter type without explicitly specifying

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

As of v1.3.0 A check for potential secrets being stored in plaintext has been added, this will result in a warning if detected.  Sensitive data can stil be stored in Parameter Store as long as it's done as a SecureString to ensure it is encrypted at rest and in transit.

## EITS Security & Compliance

**Last Module Review**: 2026-04-10

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-04-27 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-04-27 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-04-27 | 0.69.3 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-04-27 | 1.34.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Usage

### Parameter as String

```hcl
module "string" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ssm-parameter.git"

  name        = "my-parameter"
  value       = "some-value"
  description = "Some description"
}
```

### Parameter as SecureString with CMK

```hcl
module "kms" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  description  = "KMS Key for parameter store"
  key_services = ["ssm"]
  description  = "Some description"

}

module "secret" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ssm-parameter.git"

  name        = "my-secret-token"
  value       = "secret123123!!!"
  secure_type = true
  key_id      = module.kms.key_id
  description = "Some description"
}
```

### Parameter as StringList

```hcl
module "list" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ssm-parameter.git"

  name        = "my-list-parameter"
  values      = ["item1", "item2"] # "values" not "value"
  description = "Some description"
}
```

### Parameter with ignored value changes

```hcl
module "list" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ssm-parameter.git"

  ignore_value_changes = true

  name        = "my-parameter-ignore-value-changes"
  value       = "some-value"
  description = "Some description"
}
```

### Multiple parameters

```hcl
locals {
  parameters = {
    #########
    # String
    #########
    "string_simple" = {
      value       = "string_value123"
      description = "Some description"
    }
    "string" = {
      type            = "String"
      value           = "string_value123"
      tier            = "Intelligent-Tiering"
      allowed_pattern = "[a-z0-9_]+"
      description     = "Some description"
    }

    ###############
    # SecureString
    ###############
    "secure" = {
      type        = "SecureString"
      value       = "secret123123!!!"
      tier        = "Advanced"
      description = "My awesome password!"
    }
    "secure_encrypted_true" = {
      secure_type = true
      value       = "secret123123!!!"
      key_id      = "c938de44-1c09-4c91-89fd-b5881f06f317"
      description = "Some description"
    }

    #############
    # StringList
    #############
    "list_as_autoguess_type" = {
      values      = ["item1", "item2"]
      description = "Some description"
    }
    "list_as_jsonencoded_string" = {
      type        = "StringList"
      value       = jsonencode(["item1", "item2"])
      description = "Some description"
    }
    "list_as_plain_string" = {
      type        = "StringList"
      value       = "item1,item2"
      description = "Some description"
    }
    "list_as_autoconvert_values" = {
      type        = "StringList"
      values      = ["item1", "item2"]
      description = "Some description"
    }
    "list_empty_as_jsonencoded_string" = {
      type        = "StringList"
      value       = jsonencode([])
      description = "Some description"
    }
  }
}

module "multiple" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ssm-parameter.git"

  for_each = local.parameters

  name            = try(each.value.name, each.key)
  value           = try(each.value.value, null)
  values          = try(each.value.values, [])
  type            = try(each.value.type, null)
  secure_type     = try(each.value.secure_type, null)
  description     = try(each.value.description, null)
  tier            = try(each.value.tier, null)
  key_id          = try(each.value.key_id, null)
  allowed_pattern = try(each.value.allowed_pattern, null)
  data_type       = try(each.value.data_type, null)

  tags = {
      Environment  = <env>
      CostString   = <CostString>
      AppID        = <AppID>
  }
}
```

## Examples

- [Complete](https://github.com/terraform-aws-modules/terraform-aws-ssm-parameter/tree/master/examples/complete) - shows all possible ways to create parameters.

## Contact

For advice or to report an issue, either email the EITS Cloud Enablement team <eitsukicloud@experian.com> or post in the [Terraform Modules Teams Channel](https://teams.microsoft.com/l/channel/19%3a8c4faa258cd54d2687caa746f71ae050%40thread.tacv2/Terraform%2520Modules?groupId=c08d819b-fd4a-44e1-98f1-225d1bb48b31&tenantId=be67623c-1932-42a6-9d24-6c359fe5ea71)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.26.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.26.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common | v1 |

## Resources

| Name | Type |
|------|------|
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_allowed_pattern"></a> [allowed\_pattern](#input\_allowed\_pattern) | Regular expression used to validate the parameter value. | `string` | `null` | no |
| <a name="input_data_type"></a> [data\_type](#input\_data\_type) | Data type of the parameter. Valid values: `text`, `aws:ssm:integration` and `aws:ec2:image` for AMI format. | `string` | `null` | no |
| <a name="input_description"></a> [description](#input\_description) | Description of the parameter | `string` | `null` | no |
| <a name="input_key_id"></a> [key\_id](#input\_key\_id) | KMS key ID or ARN for encrypting a parameter (when type is `SecureString`). By default `SecureString` will use the default AWS KMS key `alias/aws/ssm`, but it is recommended to use a customer managed key if possible. | `string` | `"alias/aws/ssm"` | no |
| <a name="input_name"></a> [name](#input\_name) | Name of SSM parameter | `string` | `null` | no |
| <a name="input_secure_type"></a> [secure\_type](#input\_secure\_type) | Whether the type of the value should be considered as secure or not | `bool` | `false` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See the [Experian Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) | `map(string)` | `{}` | no |
| <a name="input_tier"></a> [tier](#input\_tier) | Parameter tier to assign to the parameter. If not specified, will use the default parameter tier for the region. Valid tiers are `Standard`, `Advanced`, and `Intelligent-Tiering`. Downgrading an `Advanced` tier parameter to `Standard` will recreate the resource. For more information on parameter tiers, see the [AWS SSM Parameter tier comparison and guide](https://docs.aws.amazon.com/systems-manager/latest/userguide/parameter-store-advanced-parameters.html). | `string` | `null` | no |
| <a name="input_type"></a> [type](#input\_type) | Type of the parameter. Valid types are `String`, `StringList` and `SecureString`. | `string` | `null` | no |
| <a name="input_value"></a> [value](#input\_value) | Value of the parameter | `string` | `null` | no |
| <a name="input_value_wo"></a> [value\_wo](#input\_value\_wo) | Write-only alternative to `value`. Sets the parameter value without storing it in Terraform state or plan files. Requires Terraform v1.11.0 or later. Primarily intended for sensitive data, especially `SecureString` parameters. Mutually exclusive with `value` and `values`. | `string` | `null` | no |
| <a name="input_value_wo_version"></a> [value\_wo\_version](#input\_value\_wo\_version) | Version number used to trigger updates to `value_wo`. Increment this value to force a re-write of the parameter when `value_wo` is used. | `number` | `null` | no |
| <a name="input_values"></a> [values](#input\_values) | List of values of the parameter (will be jsonencoded to store as string natively in SSM) | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_parameter_value"></a> [parameter\_value](#output\_parameter\_value) | Secure value of the parameter |
| <a name="output_secure_type"></a> [secure\_type](#output\_secure\_type) | Whether SSM parameter is a SecureString or not |
| <a name="output_ssm_parameter_arn"></a> [ssm\_parameter\_arn](#output\_ssm\_parameter\_arn) | The ARN of the parameter |
| <a name="output_ssm_parameter_name"></a> [ssm\_parameter\_name](#output\_ssm\_parameter\_name) | Name of the parameter |
| <a name="output_ssm_parameter_tags_all"></a> [ssm\_parameter\_tags\_all](#output\_ssm\_parameter\_tags\_all) | All tags used for the parameter |
| <a name="output_ssm_parameter_type"></a> [ssm\_parameter\_type](#output\_ssm\_parameter\_type) | Type of the parameter |
| <a name="output_ssm_parameter_version"></a> [ssm\_parameter\_version](#output\_ssm\_parameter\_version) | Version of the parameter |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS SSM Parameter Store
region: Global
bu: EITS
contacts:
  technical: EITS UK&I Cloud Enablement Team eitsukicloud@experian.com
  product: 
```
