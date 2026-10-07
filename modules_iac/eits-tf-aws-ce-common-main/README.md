# EITS Cloud Enablement Standard AWS Variables and Checks

This module has a number of standard checks and variables that are used across multiple other EITS Cloud Enablement modules:

- generate standard EITS Cloud Enablement tags
- check for EEC standard tags
- generate account label prefixes for naming resource

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

> ## Notes on tagging
> 
> Due to the impact changes can have on all of the Terraform modules created by the Cloud Enablement team, we are looking to only update tags when there is a major change to the functionality which will be felt by consumers. To this end, any minor or bugfix changes should have the current tag reapplied to them. Therefore tag versioning on the repo will take the form `v1`, `v2`, etc... whilst the changelog will continue with proper semantic versioning. `v1` tag will correspond to the latest `1.x.x` version, `v2` will correspond to the latest `2.x.x` version, etc...

## EITS Security & Compliance

**Last Module Review**: 2025-10-29

See below for the date and results of our EITS security and compliance scanning.

<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-failed-red) | 2026-02-04 | 1.11.4 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-02-04 | 0.60.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-02-04 | 0.68.2 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-02-04 | 0.107.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## EEC Tag Validation

This module validates the required tags in AWS EEC account. 3 tags are required from 1st September 2023 (as per https://experian.atlassian.net/wiki/x/swH3E):

| Tag | Description |
|-----|-------------|
| CostString | Cost String used for tag-based cost reports, budgets, cost-tracking, etc. |
| AppID | Experian standard “AppID” (also known as a GEARR “App ID” ) is a unique global identification number assigned to each business application registered in APM. |
| Environment | One of: prd, stg, uat, tst, dev, sbx |

If the tags are not correct then the module will error. If no tags variable is passed to the module it will switch off validation - this is to enable compatibility with modules that do not use tags.

## Standard EITS Cloud Enablement Tags

The module generates two tags that are used in reporting:

| Tag | Description |
|-----|-------------|
| eitsce:modulename | name of module used to deploy resource |
| eitsce:moduleversion | version of repo used |

## EEC Account Label Prefix

This module will use the account name (alias) to build a consistent prefix for every AWS resource. The prefix label will be **"<_country_code_>-<_product_name_>-<_environment_>"** (For example, by default the prefix label for account "_eec-aws-uk-eits-cloudenablement-sandbox_" will be "_uk-cloudenablement-sbx_")

### Disclaimer
As this module computes the resources labels from the account name, the account name format should be in this format **'eec-aws-<_country_code_>-<_bu_>-<_product_name_>-<_environment_>'** (as per https://experian.atlassian.net/wiki/x/XwH3E)".
If the account name is not compliant with the standard (an thus is missing some information), then please ensure that the generated prefix is correct. 
If the generated output is incorrect or you need a different prefix label, then please manually provide the label, without using this module.

### Notes
- We strip out any "-" from the product name (so "_product-name_" would become "_productname_")
- We shorten the environment to 3 characters, which matches the naming convention for the "Environment" tag
- We use this module to name every resource created by our modules

## Usage

Within a module:

```hcl
module "eits_ce_common" {
  source  = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = <repo name, for example eits-tf-aws-nlb>
  tags        = var.tags
}

locals {
  tags         = merge(var.tags, module.eits_ce_common.tags)
  label_prefix = module.eits_ce_common.prefix
}
```

This module can also be invoked at the root of a project. This allows for removing the duplication of warnings on failed tag checks when multiple CE modules are used as long as the following set-up is used and subsequent modules are passed `local.tags` as the tags variable.

```hcl
module "eits_ce_common" {
  source  = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  tags        = var.tags
}

locals {
  tags         = merge(var.tags, module.eits_ce_common.tags)
  label_prefix = module.eits_ce_common.prefix
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 3.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | >= 3.4.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 3.0 |
| <a name="provider_http"></a> [http](#provider\_http) | >= 3.4.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_default_tags.account_tags](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/default_tags) | data source |
| [aws_iam_account_alias.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_account_alias) | data source |
| [http_http.get_tags](https://registry.terraform.io/providers/hashicorp/http/latest/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_module_project"></a> [module\_project](#input\_module\_project) | The bitbucket project name | `string` | `"EUCES"` | no |
| <a name="input_module_repo"></a> [module\_repo](#input\_module\_repo) | Repo slug for the module, for example `eits-tf-aws-nlb` | `string` | `"NONE"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | AWS resource tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_prefix"></a> [prefix](#output\_prefix) | Prefix label |
| <a name="output_tags"></a> [tags](#output\_tags) | Map of standard EITS CE tags |
<!-- END_TF_DOCS -->
