check "email_validation_warning" {
  assert {
    condition     = var.request_certificate.validation_method == "DNS"
    error_message = <<EOF
AWS Best Practice recommends using `DNS` validation instead of `EMAIL` validation. 
Email validation can be considered a security risk.
EOF
  }
}