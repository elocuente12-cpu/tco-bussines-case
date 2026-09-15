# test region
provider "aws" {
  region = var.region
}

# test module
module "sns" {
  source = "./../.."

  name_prefix = "test-prefix"
  name        = "eits-tf-aws-sns-with-email"

  # enforce SHA2
  signature_version = 2

  policy_allowed_aws_services = ["backup.amazonaws.com"]

  enable_secure_transport_policy = false

  subscribers = {
    emailme = {
      protocol = "email"
      endpoint = var.email_address
    }
  }

  disable_default_alarms = true

  tags = var.tags
  message_delivery_status = {
    lambda = {
      success_sample_rate = 20
    }
  }
}

