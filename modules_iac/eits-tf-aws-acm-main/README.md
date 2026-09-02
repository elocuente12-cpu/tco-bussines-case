# EITS Terraform module for AWS ACM

EITS Terraform module for AWS Certificate Manager, designed to import an existing certificate or request a new certificate to AWS. This module provides a streamlined process for certificate management, ensuring secure and efficient handling of your AWS certificates.
This module will also create by default a Cloudwatch alarm for the certificate expiration.

See CHANGELOG.md for the list of changes for each release.
*We highly recommend that in your code you pin the version to the exact version you are using so that your infrastructure remains stable, and update versions in a systematic way so that they do not catch you by surprise.*

## EITS Security & Compliance

**Last Module Review**: 2026-07-09

See below for the date and results of our EITS security and compliance scanning.

<!-- BEGIN_BENCHMARK_TABLE -->
| Benchmark | Date | Version | Description |
| --------- | ---- | ------- | ----------- |
| ![validate](https://img.shields.io/badge/validate-passed-green) | 2026-08-19 | 1.14.8 | Validates terraform code using example test directories |
| ![tflint](https://img.shields.io/badge/tflint-passed-green) | 2026-08-19 | 0.61.0 | Enforces best practices, syntax, naming conventions |
| ![trivy](https://img.shields.io/badge/trivy-passed-green) | 2026-08-19 | 0.72.0 | Detects misconfiguration in IaC files, such as Docker, Terraform, etc |
| ![wiz](https://img.shields.io/badge/wiz.io_iac-passed-green) | 2026-08-19 | 1.59.0 | Scans tests directory plans for vulnerabilities and risks |
<!-- END_BENCHMARK_TABLE -->

## Prerequisites

### Importing a certificate

You should already have a trusted certificate (either Entrust or other), with its private key and chain.
If not, you can request one [here](https://experian.service-now.com/now/nav/ui/classic/params/target/com.glideapp.servicecatalog_cat_item_view.do%3Fv%3D1%26sysparm_id%3Da4095617db4058d00b6b1f3b4b9619ba)

### Requesting a new certificate

#### DNS domain managed by Route53

- Set `validation_method` to `DNS`, and `external_domain_validation` to `false` (default value)
- You should have the domain name you want to request a certificate for, and the **public hosted zone** name in Route53.

#### DNS domain managed externally

- Set `validation_method` to `DNS`, and set `external_domain_validation` to `true`.
- Check the `domain_validation_options` output for the details of the CNAME record to create in the external DNS domain.
- Please note that the certificate will *not* be validated by this module. It will remain in `pending validation` status in ACM until the CNAME record has been created in your external DNS domain.

## Usage

### Importing a certificate

```HCL
module "acm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-acm.git"
  action           = "import"

  import_certificate = {
    private_key      = <certificate_private_key_in_pem_format> # e.g., file("my_private_key.pem")
    certificate_body  = <certificate_body_in_pem_format> # e.g., file("my_cert.pem")
  }

  tags = {
    Environment = <environment>
    CostString  = <cost_string>
    AppID       = <app_id>
  }
}
```

### Requesting a new certificate with Route53 DNS validation

```HCL
module "acm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-acm.git"
  action           = "request"

  request_certificate = {
    domain_name       = <domain_name> # e.g., mydomain.example.experian.com
    validation_method = "DNS" 
    hosted_zone_name  = <hosted_zone_name> # e.g., experian.com
  }

  tags = {
    Environment = <environment>
    CostString  = <cost_string>
    AppID       = <app_id>
  }
}
```

### Requesting a new certificate with external DNS validation

```HCL
module "acm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-acm.git"
  action           = "request"

  request_certificate = {
    domain_name       = <domain_name> # e.g., mydomain.example.experian.com
    validation_method = "DNS" 
    hosted_zone_name  = <hosted_zone_name> # e.g., experian.com
  }
  external_domain_validation = true

  tags = {
    Environment = <environment>
    CostString  = <cost_string>
    AppID       = <app_id>
  }
}
```

### (Beta) Requesting a new certificate with EMAIL validation <span style="color:red;">(Not recommended)</span>

> **<span style="color:red;">Warning:</span>** We strongly recommend using **DNS validation** for ACM domains whenever possible. DNS validation is more secure and allows for automatic renewal of certificates. Email validation should only be used in circumstances where DNS validation is not feasible. For more information, refer to AWS best practices for DNS validation and AWS Certificate Manager best practices.

```HCL
module "acm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-acm.git"
  action           = "request"

  request_certificate = {
    domain_name       = <domain_name> # e.g., *.example.experian.com
    validation_method = "EMAIL"
    hosted_zone_name = <hosted_zone_name> # e.g., experian.com
  }

  validation_option = [
    {
      domain_name       = <domain_name> # e.g., *.example.experian.com
      validation_domain = <hosted_zone_name> # e.g., experian.com
    }
  ]


  tags = {
    Environment = <environment>
    CostString  = <cost_string>
    AppID       = <app_id>
  }
}
```

## Contributing

If you'd like to contribute to this repo, please contact the EITS Cloud Enablement team

## Contact

For advice or to report an issue, either email the EITS Cloud Enablement team <eitsukicloud@experian.com> or post in the [Terraform Modules Teams Channel](https://teams.microsoft.com/l/channel/19%3a8c4faa258cd54d2687caa746f71ae050%40thread.tacv2/Terraform%2520Modules?groupId=c08d819b-fd4a-44e1-98f1-225d1bb48b31&tenantId=be67623c-1932-42a6-9d24-6c359fe5ea71)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.51.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.51.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_alarm"></a> [alarm](#module\_alarm) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-cloudwatch-alarm.git | 1.3.0 |
| <a name="module_eits_ce_common"></a> [eits\_ce\_common](#module\_eits\_ce\_common) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git | v1 |
| <a name="module_route53"></a> [route53](#module\_route53) | git::https://code.experian.local/scm/EUCES/eits-tf-aws-route53.git | 1.7.1 |

## Resources

| Name | Type |
|------|------|
| [aws_acm_certificate.import_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate.request_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.validate_cert](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_action"></a> [action](#input\_action) | Action to perform. Valid values are 'import' and 'request' | `string` | `"import"` | no |
| <a name="input_alarm_sns_topics"></a> [alarm\_sns\_topics](#input\_alarm\_sns\_topics) | List of SNS topics triggered by alarm events. providing a list will automatically enable alarm actions | `list(string)` | `[]` | no |
| <a name="input_certificate_transparency_logging"></a> [certificate\_transparency\_logging](#input\_certificate\_transparency\_logging) | Certificate transparency logging preference, only applicable for requested certificates | `bool` | `true` | no |
| <a name="input_cloudwatch_tags"></a> [cloudwatch\_tags](#input\_cloudwatch\_tags) | Cloudwatch Alarm tags. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags | `map(string)` | `{}` | no |
| <a name="input_disable_default_alarms"></a> [disable\_default\_alarms](#input\_disable\_default\_alarms) | To disable the best practice AWS alarms as outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#CertificateManager) | `bool` | `false` | no |
| <a name="input_enable_all_alarm_actions"></a> [enable\_all\_alarm\_actions](#input\_enable\_all\_alarm\_actions) | Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions | `bool` | `false` | no |
| <a name="input_enable_route53_alarms"></a> [enable\_route53\_alarms](#input\_enable\_route53\_alarms) | Enable Route53 alarms, only applicable for requested certificates | `bool` | `false` | no |
| <a name="input_external_domain_validation"></a> [external\_domain\_validation](#input\_external\_domain\_validation) | Set to `true` if the DNS domain validation is external. See README for more details | `bool` | `false` | no |
| <a name="input_import_certificate"></a> [import\_certificate](#input\_import\_certificate) | Certificate to import in PEM format | <pre>object({<br/>    private_key       = string<br/>    certificate_body  = string<br/>    certificate_chain = optional(string, "")<br/>  })</pre> | <pre>{<br/>  "certificate_body": "",<br/>  "private_key": ""<br/>}</pre> | no |
| <a name="input_request_certificate"></a> [request\_certificate](#input\_request\_certificate) | Certificate to request | <pre>object({<br/>    hosted_zone_name  = string<br/>    domain_name       = string<br/>    validation_method = string<br/>  })</pre> | <pre>{<br/>  "domain_name": "",<br/>  "hosted_zone_name": "",<br/>  "validation_method": ""<br/>}</pre> | no |
| <a name="input_route53_recordset_overwrite"></a> [route53\_recordset\_overwrite](#input\_route53\_recordset\_overwrite) | Allow overwriting of existing Route53 record set, only applicable for requested certificates | `bool` | `true` | no |
| <a name="input_route53_recordset_ttl"></a> [route53\_recordset\_ttl](#input\_route53\_recordset\_ttl) | TTL for the Route53 record set, only applicable for requested certificates | `number` | `60` | no |
| <a name="input_subject_alternative_names"></a> [subject\_alternative\_names](#input\_subject\_alternative\_names) | Subject alternative names for the certificate, only applicable for requested certificates | `list(string)` | `[]` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for AWS resources. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags | `map(string)` | `{}` | no |
| <a name="input_validation_option"></a> [validation\_option](#input\_validation\_option) | Validation options for the certificate request | `any` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the Certificate. |
| <a name="output_domain_name"></a> [domain\_name](#output\_domain\_name) | The domain name of the Certificate. |
| <a name="output_domain_validation_options"></a> [domain\_validation\_options](#output\_domain\_validation\_options) | The domain validation options of the Certificate. |
| <a name="output_expiration"></a> [expiration](#output\_expiration) | The expiration of the Certificate. |
| <a name="output_status"></a> [status](#output\_status) | The status of the Certificate. |
<!-- END_TF_DOCS -->

## Metadata

```discoveryhub
summary: Terraform module for AWS ACM (Certificate Manager)
region: Global
bu: T&I
docs: https://pages.experian.local/spaces/CID/pages/1758429832/Terraform+Modules
contacts:
  technical: EITS UK&I Cloud Enablement Team <eitsukicloud@experian.com>          
```
