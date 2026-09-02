# test region
provider "aws" {
  region = var.region
}

# create quick temporary certificate to use for testing plan
# DO NOT DO THIS FOR ACTUAL USECASES!
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "this" {
  private_key_pem = tls_private_key.this.private_key_pem

  subject {
    common_name  = "eits-tf-aws-acm.${var.hosted_zone_name}"
    organization = "Experian Information Solutions, Inc."
  }

  validity_period_hours = 1
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "acm" {
  source = "./../.."
  action = "import"

  import_certificate = {
    private_key      = tls_private_key.this.private_key_pem
    certificate_body = tls_self_signed_cert.this.cert_pem
  }

  tags = var.tags
}
