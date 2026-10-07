# EITS Cloud Enablement AWS IAM module

EITS Terraform module to create IAM roles and policies. With this module is possible to:

- Create an IAM role with a custom IAM policy and/or managed IAM policies attached to it
- Create an instance profile role

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> As of version 1.3.0 a check has been added to the Assume Role Policy to deny access to assume the role from services outside of the organization. If this breaks your use case, disable this functionality by setting the variable `disable_org_check` to `true`.

## EITS Security & Compliance

**Last Module Review**: 2026-02-26

See below for the date and results of our EITS security and compliance scanning.
 
<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-04-27 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-04-27 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-04-27 | 0.69.3 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-04-27 | 1.34.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Notes

- It's possible to specify a custom trust policy with multiple different principals with their own actions/conditions.
- Unless the 'override_role_name' and 'override_policy_name' variables are set to true, the prefix 'BURoleFor' will be added as a prefix to the role name, and 'BUPolicyFor' for the policy name (as per the [EEC recommended naming convention](https://experian.atlassian.net/wiki/x/XwH3E)).
- Should you need to assign a new policy to an existing role, please import the role resource into Terraform first.
- All policies should be assigned to an IAM role (assuming roles is preferred to using IAM users and groups).
- Please refer to this [EEC guide](https://pages.experian.local/display/SC/How+to+enable+third-party+access+to+AWS+via+cross-account+roles) before creating an IAM role to enable third party access.
- As of version `1.9.0`, if you need your role to only be assumed by one AWS service (e.g., `ec2`), you can use the `trusted_service` variable to automatically create a trust policy for it. You still have the ability to specify your own trust policy, or add both.

## USAGE

### Create IAM role for a specific AWS service with custom and managed policies attached

```hcl
module "iam_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam" # we recommend to pin this to a specific version

  role_name           = "<role_name>"
  role_description    = "<role_description>"
  policy_name         = "<policy_name>"                   # optional, required if policy_documents is not empty
  policy_description  = "<policy_description"             # optional, required if policy_documents is not empty
  trusted_service     = "<service>"                       # e.g., "ec2"
  policy_documents    = [<list_of_json_policy_documents>] # e.g., [data.aws_iam_policy_document.example.json]
  managed_policy_arns = [<list_of_arns>]                  # e.g., "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"

  tags = {
    Environment = "<env>"
    CostString  = "<cost_string>"
    AppID       = "<app_id>"
  }
}

```

### Create IAM role with custom and managed policies attached

```hcl
module "iam_role" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-iam" # we recommend to pin this to a specific version

  role_name           = "<role_name>"
  role_description    = "<role_description>"
  policy_name         = "<policy_name>"                   # optional, required if policy_documents is not empty
  policy_description  = "<policy_description"             # optional, required if policy_documents is not empty
  assume_role_policy  = "json_policy_documents"           # e.g., data.aws_iam_policy_document.assume_role_example.json
  policy_documents    = [<list_of_json_policy_documents>] # e.g., [data.aws_iam_policy_document.example.json]
  managed_policy_arns = [<list_of_arns>]                  # e.g., "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"

  tags = {
    Environment = "<env>"
    CostString  = "<cost_string>"
    AppID       = "<app_id>"
  }
}

```

### Example of IAM policy documents

```hcl
# Policy document to list bucket on a specific resource
data "aws_iam_policy_document" "example" {
  statement {
    sid = "ListBucket"

    actions = [
      "s3:ListBucket"
    ]

    resources = ["arn:aws:s3:::bucketname"]
    effect    = "Allow"
  }
}

# Trust policy for EC2
data "aws_iam_policy_document" "assume_role_example" {
  statement {
    sid = "AssumeRoleEC2Test"

    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
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
| [aws_iam_instance_profile.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_policy.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.principal_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assume_role_policy"></a> [assume\_role\_policy](#input\_assume\_role\_policy) | JSON IAM policy for assume role (either this or `trusted_service` is mandatory. Both can be specified) | `string` | `null` | no |
| <a name="input_create_role"></a> [create\_role](#input\_create\_role) | Set to True to create IAM role (Default: true) | `string` | `true` | no |
| <a name="input_disable_org_check"></a> [disable\_org\_check](#input\_disable\_org\_check) | Set this to true to disable the Deny permission in the trust policy which stops services from outside the Experian Organization from assuming the role | `bool` | `false` | no |
| <a name="input_instance_profile_enabled"></a> [instance\_profile\_enabled](#input\_instance\_profile\_enabled) | Create EC2 Instance Profile for the role (Default: false) | `bool` | `false` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | List of managed policies to attach to created role | `set(string)` | `[]` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | The maximum session duration (in seconds) for the role. Can have a value from 1 hour (3600 seconds) to 12 hours (43200 seconds) | `number` | `3600` | no |
| <a name="input_override_policy_name"></a> [override\_policy\_name](#input\_override\_policy\_name) | Set to TRUE to override the policy name. By default, 'BUPolicyFor' is added as a prefix as per https://experian.atlassian.net/wiki/x/XwH3E | `bool` | `false` | no |
| <a name="input_override_role_name"></a> [override\_role\_name](#input\_override\_role\_name) | Set to TRUE to override the role name. By default, 'BURoleFor' is added as a prefix as per https://experian.atlassian.net/wiki/x/XwH3E | `bool` | `false` | no |
| <a name="input_path"></a> [path](#input\_path) | Path to the role and policy. See [IAM Identifiers](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_identifiers.html) for more information.  (Default: '/') | `string` | `"/"` | no |
| <a name="input_permissions_boundary"></a> [permissions\_boundary](#input\_permissions\_boundary) | ARN of the policy that is used to set the permissions boundary for the role | `string` | `null` | no |
| <a name="input_policy_description"></a> [policy\_description](#input\_policy\_description) | The description of the IAM policy that is visible in the IAM policy manager (required if `policy_documents` is not empty) | `string` | `null` | no |
| <a name="input_policy_documents"></a> [policy\_documents](#input\_policy\_documents) | List of JSON IAM policy documents | `list(string)` | `[]` | no |
| <a name="input_policy_name"></a> [policy\_name](#input\_policy\_name) | The name of the IAM policy that is visible in the IAM policy manager (required if `policy_documents` is not empty) | `string` | `""` | no |
| <a name="input_role_description"></a> [role\_description](#input\_role\_description) | The description of the IAM role that is visible in the IAM role manager | `string` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role (mandatory) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS Resources. See https://experian.atlassian.net/wiki/x/swH3E for all available tags. 'CostString', 'AppID' and 'Environment' are required | `map(string)` | `{}` | no |
| <a name="input_trusted_service"></a> [trusted\_service](#input\_trusted\_service) | Name of the AWS service (e.g., `ec2`) that can assume the role (either this or `assume_role_policy` is mandatory. Both can be specified) | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_profile"></a> [instance\_profile](#output\_instance\_profile) | Name of the ec2 profile (if enabled) |
| <a name="output_role_arn"></a> [role\_arn](#output\_role\_arn) | The Amazon Resource Name (ARN) specifying the role |
| <a name="output_role_id"></a> [role\_id](#output\_role\_id) | The stable and unique string identifying the role |
| <a name="output_role_name"></a> [role\_name](#output\_role\_name) | The name of the IAM role created |
| <a name="output_role_policy"></a> [role\_policy](#output\_role\_policy) | Role policy document in json format. Outputs always, independent of `enabled` variable |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for IAM roles and policies
region: Global
bu: T&I
docs: https://experian.atlassian.net/wiki/x/HQ4EF
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>          
```
