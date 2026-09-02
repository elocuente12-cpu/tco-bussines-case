# test region
provider "aws" {
  region = var.region
}

module "acm" {
  source = "./../.."

  action = "request"

  request_certificate = {
    domain_name       = "*.eits-tf-aws-acm.${var.hosted_zone_name}"
    validation_method = "DNS"
    hosted_zone_name  = var.hosted_zone_name
  }

  tags = var.tags
}
