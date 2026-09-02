module "eits_ce_common" {
  source      = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"
  module_repo = "eits-tf-aws-acm"

  tags = var.tags
}

locals {
  tags               = merge(var.tags, module.eits_ce_common.tags)
  cloudwatch_tags    = merge(local.tags, var.cloudwatch_tags)
  validation_options = flatten(aws_acm_certificate.request_cert[*].domain_validation_options)
  domain_names = distinct(
    [for s in concat([var.request_certificate.domain_name], var.subject_alternative_names) : replace(s, "*.", "")]
  )
}

resource "aws_acm_certificate" "import_cert" {
  count             = var.action == "import" ? 1 : 0
  private_key       = var.import_certificate.private_key
  certificate_body  = var.import_certificate.certificate_body
  certificate_chain = var.import_certificate.certificate_chain

  tags = local.tags
}

resource "aws_acm_certificate" "request_cert" {
  count                     = var.action == "request" ? 1 : 0
  domain_name               = var.request_certificate.domain_name
  subject_alternative_names = var.subject_alternative_names
  validation_method         = var.request_certificate.validation_method
  options {
    certificate_transparency_logging_preference = var.certificate_transparency_logging ? "ENABLED" : "DISABLED"
  }

  dynamic "validation_option" {
    for_each = var.validation_option
    content {
      domain_name       = try(validation_option.value["domain_name"], validation_option.key)
      validation_domain = validation_option.value["validation_domain"]
    }
  }

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "validate_cert" {
  count                   = var.request_certificate.validation_method == "DNS" && !var.external_domain_validation ? length(aws_acm_certificate.request_cert) : 0
  certificate_arn         = aws_acm_certificate.request_cert[count.index].arn
  validation_record_fqdns = [for record in module.route53 : record.record_fqdn]
}

module "route53" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-route53.git?ref=1.7.1"
  count  = var.request_certificate.validation_method == "DNS" && !var.external_domain_validation ? length(local.domain_names) : 0

  disable_default_alarms = var.enable_route53_alarms
  allow_overwrite        = var.route53_recordset_overwrite
  record_name            = local.validation_options[count.index]["resource_record_name"]
  record_type            = local.validation_options[count.index]["resource_record_type"]
  hosted_zone_name       = var.request_certificate.hosted_zone_name
  # Hosted Zone needs to be public to allow the validation and renewal of the certificate
  hosted_zone_private = false
  ttl                 = var.route53_recordset_ttl
  records             = [local.validation_options[count.index]["resource_record_value"]]
  tags                = merge(local.tags, { "eitsce:parentmodule" = "eits-tf-aws-acm" })
}
