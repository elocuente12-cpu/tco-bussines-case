# EITS Cloud Enablement AWS KMS module

EITS Terraform module for AWS KMS CMKs.  This module will:

- Create a single-region KMS key from AWS generated key material that automatically rotates every 365 days.
- Optionally create an external key instead with imported key material.
- Create a key policy with multiple permission sets including:
  - Key Owner
  - Key Admin
  - Key Users
  - More permission sets are detailed below, links to AWS documentation is also included for more information.
- Specify the alias name (while adhering with naming convention)

> **_NOTE:_** The **BUAdministratorAccessRole** and the role executing the Terraform code will automatically be added as Key Admins

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

## EITS Security & Compliance

**Last Module Review**: 2026-05-19

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-04-27 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-04-27 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-04-27 | 0.69.3 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-04-27 | 1.34.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Resource naming

This module automatically computes the alias' for your KMS Key, in accordance with the [Cloud Naming Conventions](https://experian.atlassian.net/wiki/x/XwH3E).

According to the documention, KMS resources should be named as follows: 

`{account_naming_construct}-{type}-kms`

We recommend you refer to the [documentation above](https://experian.atlassian.net/wiki/x/XwH3E) to understand `account_naming_construct` in full but for simplicitly we will refer to it as `prefix`.  The prefix value is computed by this module through use of the [label module](https://code.experian.local/projects/EUCES/repos/eits-tf-aws-label/browse) in the following format `countrycode-productname-env`, e.g `uk-myproduct-sbx`.

You also have the option to create multiple [aliases](https://docs.aws.amazon.com/kms/latest/developerguide/kms-alias.html) for your key if using it for more than one AWS service.  
Aliases are constructed by the module and follow the [Cloud Platform Engineering Naming Convention](https://experian.atlassian.net/wiki/x/XwH3E).
Starting from v1.3.0, the module will then create aliases that look like the below:

- If `aliases` is specified, then an alias for each element of the list will be built in this format: `alias/<prefix>-<alias>-kms`. For example, if `aliases = ["mykey"]`, then the alias will be `alias/<prefix>-mykey-kms`. You can have multiple aliases this way.
- If `aliases` is *not* specified, then the one single alias will be created in the following format: `alias/<prefix>-<services>-kms`. For example, if `key_services = ["backup", "sns"]`, then the alias will be `alias/<prefix>-backup-sns-kms`.
- If neither `aliases` and `key_services` are configured, the key will be created without an alias.

> **_NOTE:_** 
If your AWS account name is not in the standard format, you may get unpredictable results from the prefix generation. If this is the case you can manually override it using the **prefix** input variable.

The option to create multiple [KMS Grants](https://docs.aws.amazon.com/kms/latest/developerguide/grants.html) is also available, using the input format [below](#usage)

If creating grants and using the `external_key` option, please note that you must provide the `key_material_base64` variable too otherwise the information in the `grants` variable will be ignored.

## Providing Key Policies

There are a number of module variables, prefixed with 'key_', that generate a key policy for the kms key. See Inputs below for details. The user running terraform is required to have permission to manage the kms key, this is automatically added.

Additional policy can also be added via the `policy` variable. These will be merged with any configuraton supplied using the key_* arguments. This must be a valid policy JSON document, and the statements defined here must have unique SIDs to the ones already supplied in the module (avoid SIDs prefxed with 'Key'). The json ouput from an aws_iam_policy_document resource, in the form that designates a principal, can be used. For more information about building policy documents with Terraform, see the [AWS IAM Policy Document Guide](https://learn.hashicorp.com/terraform/aws/iam-policy).

## USAGE

### Standard key using AWS key material

```hcl
module "kms" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  aliases                 = [<list_of_aliases>]
  description             = <description>
  key_administrators      = [ <list of ARNs to grant Admin Permissions> ]
  key_owners              = [ <list of ARNs to grant Admin Permissions> ]
  key_services            = [ <list of AWS services in shortform, e.g ec2, rds, s3> ]
  key_users               = [ <list of ARNs to grant Admin Permissions> ]

  grants = {
    lambda = {
      grantee_principal = "arn:aws:iam::############:role/<roleName>"
      operations        = ["Encrypt", "Decrypt", "GenerateDataKey"]
      constraints = {
        encryption_context_equals = {
          Constraint1 = <<value>>
        }
      }
    }
  }

  tags = {
    CostString = <cost_string>
    AppID = <app_id>
    Environment = <environment>
  }
}
```

### External key using imported key material

```hcl
module "kms" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms.git"

  external_key            = true
  aliases                 = [<list_of_aliases>]
  description             = <description>
  key_administrators      = [ <list of ARNs to grant Admin Permissions> ]
  key_owners              = [ <list of ARNs to grant Admin Permissions> ]
  key_services            = [ <list of AWS services in shortform, e.g ec2, rds, s3> ]
  key_users               = [ <list of ARNs to grant Admin Permissions> ]

  tags = {
    CostString = <cost_string>
    AppID = <app_id>
    Environment = <environment>
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.34.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.34.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |

## Resources

| Name | Type |
|------|------|
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_external_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_external_key) | resource |
| [aws_kms_grant.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_grant) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_session_context.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_session_context) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aliases"></a> [aliases](#input\_aliases) | A list of aliases.<br/>  If configured, an alias for each element of the list will be built in this format: alias/{local.prefix}-{alias}-kms<br/>  If not configured, one single alias will be built in this format: alias/{local.prefix}-{dash-separated-services-from-key\_services}-kms | `list(string)` | `[]` | no |
| <a name="input_custom_key_store_id"></a> [custom\_key\_store\_id](#input\_custom\_key\_store\_id) | ID of the KMS Custom Key Store where the key will be stored instead of KMS. This variable is ignored if `external_key` is true. | `string` | `null` | no |
| <a name="input_customer_master_key_spec"></a> [customer\_master\_key\_spec](#input\_customer\_master\_key\_spec) | Specifies the type of KMS key to create. Defaults to `SYMMETRIC_DEFAULT`. For a list of valid values and help with choosing a key spec, see the [AWS KMS Developer Guide](https://docs.aws.amazon.com/kms/latest/developerguide/symm-asymm-choose.html). This variable is ignored if `external_key` is true. | `string` | `"SYMMETRIC_DEFAULT"` | no |
| <a name="input_deletion_window_in_days"></a> [deletion\_window\_in\_days](#input\_deletion\_window\_in\_days) | The window you have to restore a disabled KMS key before it is gone forever | `number` | `30` | no |
| <a name="input_description"></a> [description](#input\_description) | The description of the key as viewed in AWS console | `string` | `null` | no |
| <a name="input_external_key"></a> [external\_key](#input\_external\_key) | Whether the created key is external | `bool` | `false` | no |
| <a name="input_grants"></a> [grants](#input\_grants) | A map of grant definitions to create, see type definition and [Terraform docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_grant) for details. Note that grants will not be created if `external_key` is true and `key_material_base64` is not provided, as the key must have key material to be able to create grants | <pre>map(object({<br/>    name              = optional(string)<br/>    grantee_principal = string<br/>    operations        = list(string)<br/>    constraints = optional(map(object({<br/>      encryption_context_equals = optional(map(string))<br/>      encryption_context_subset = optional(map(string))<br/>    })), {})<br/>    retiring_principal    = optional(string)<br/>    grant_creation_tokens = optional(list(string))<br/>    retire_on_delete      = optional(bool)<br/>  }))</pre> | `{}` | no |
| <a name="input_is_enabled"></a> [is\_enabled](#input\_is\_enabled) | Specifies whether the key is enabled. Defaults to `true`. | `bool` | `true` | no |
| <a name="input_key_administrators"></a> [key\_administrators](#input\_key\_administrators) | A list of IAM ARNs for [key administrators](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-administrators) | `list(string)` | `[]` | no |
| <a name="input_key_asymmetric_public_encryption_users"></a> [key\_asymmetric\_public\_encryption\_users](#input\_key\_asymmetric\_public\_encryption\_users) | A list of IAM ARNs for [key asymmetric public encryption users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto) | `list(string)` | `[]` | no |
| <a name="input_key_asymmetric_sign_verify_users"></a> [key\_asymmetric\_sign\_verify\_users](#input\_key\_asymmetric\_sign\_verify\_users) | A list of IAM ARNs for [key asymmetric sign and verify users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto) | `list(string)` | `[]` | no |
| <a name="input_key_hmac_users"></a> [key\_hmac\_users](#input\_key\_hmac\_users) | A list of IAM ARNs for [key HMAC users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto) | `list(string)` | `[]` | no |
| <a name="input_key_material_base64"></a> [key\_material\_base64](#input\_key\_material\_base64) | Provide the base64 key material for key imports. This will create an external key if provided, and a regular KMS key if not. See https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_external_key for more details | `string` | `null` | no |
| <a name="input_key_owners"></a> [key\_owners](#input\_key\_owners) | A list of IAM ARNs for those who will have full key permissions (`kms:*`) | `list(string)` | `[]` | no |
| <a name="input_key_service_users"></a> [key\_service\_users](#input\_key\_service\_users) | A list of IAM ARNs for [key service users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-service-integration) | `list(string)` | `[]` | no |
| <a name="input_key_services"></a> [key\_services](#input\_key\_services) | A list of AWS services for [key users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-users) | `list(string)` | `[]` | no |
| <a name="input_key_statements"></a> [key\_statements](#input\_key\_statements) | A map of IAM policy [statements](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document#statement) for custom permission usage | `any` | `{}` | no |
| <a name="input_key_symmetric_encryption_users"></a> [key\_symmetric\_encryption\_users](#input\_key\_symmetric\_encryption\_users) | A list of IAM ARNs for [key symmetric encryption users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-users-crypto) | `list(string)` | `[]` | no |
| <a name="input_key_usage"></a> [key\_usage](#input\_key\_usage) | Specifies the intended use of the key. Valid values: `ENCRYPT_DECRYPT`,`SIGN_VERIFY`, or `GENERATE_VERIFY_MAC`. Defaults to `ENCRYPT_DECRYPT` | `string` | `"ENCRYPT_DECRYPT"` | no |
| <a name="input_key_users"></a> [key\_users](#input\_key\_users) | A list of IAM ARNs for [key users](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html#key-policy-default-allow-users) | `list(string)` | `[]` | no |
| <a name="input_multi_region"></a> [multi\_region](#input\_multi\_region) | Indicates whether the KMS key is a multi-Region (true) or regional (false) key. Defaults to `false`. | `bool` | `false` | no |
| <a name="input_policy"></a> [policy](#input\_policy) | A valid policy JSON document, will be merged with any configuration supplied to the key\_* variables, Although this is a key policy, not an IAM policy, an `aws_iam_policy_document`, in the form that designates a principal, can be used | `string` | `null` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Used for naming your cloud resources. The KMS alias will be 'alias/{local.prefix}-{alias}-kms' | `string` | `""` | no |
| <a name="input_rotation_period_in_days"></a> [rotation\_period\_in\_days](#input\_rotation\_period\_in\_days) | Custom period of time between each rotation date. Must be a number between 90 and 2560. This variable is ignored if `external_key` is true. | `number` | `365` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | KMS key tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags | `map(string)` | `{}` | no |
| <a name="input_xks_key_id"></a> [xks\_key\_id](#input\_xks\_key\_id) | Identifies the external key that serves as key material for the KMS key in an external key store.  This variable is ignored if `external_key` is true. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aliases"></a> [aliases](#output\_aliases) | A map of aliases created and their attributes |
| <a name="output_grants"></a> [grants](#output\_grants) | A map of grants created and their attributes |
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | The Amazon Resource Name (ARN) of the key |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | The globally unique identifier for the key |
| <a name="output_key_policy"></a> [key\_policy](#output\_key\_policy) | The IAM resource policy set on the key |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS KMS CMKs
region: Global
bu: T&I
docs: https://experian.atlassian.net/wiki/x/HQ4EF
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>
```
