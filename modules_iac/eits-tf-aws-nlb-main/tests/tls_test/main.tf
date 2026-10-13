# test region
provider "aws" {
  region = var.region
}

# create ec2 to use for testing load balancer
module "test_ec2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ec2-innersource.git"

  ec2_name         = "eits-tf-aws-nlb-tls"
  ami              = "amzn_lnx_2023"
  instance_type    = "t3.micro"
  vpc_id           = var.vpc_id
  subnet           = var.subnet_ids[0]
  root_volume_type = "gp3"
  root_volume_size = "50"

  security_group_name        = "eits-tf-aws-nlb-tls"
  security_group_description = "eits-tf-aws-nlb-tls"

  security_group_ingress_rules = [
    {
      description = "https"
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["10.0.0.0/8"]
    }
  ]
  security_group_egress_rules = [
    {
      type        = "egress"
      from_port   = "0"
      to_port     = "0"
      protocol    = "-1"
      cidr_blocks = ["10.0.0.0/8"]
      description = "Allow outbound traffic to Experian network"
    }
  ]

  disable_default_alarms = true

  tags = var.tags
}

# create quick temporary certificate to use for testing plan
# DO NOT DO THIS FOR ACTUAL USECASES!
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "tls_self_signed_cert" "this" {
  private_key_pem       = tls_private_key.this.private_key_pem
  ip_addresses          = [module.test_ec2.private_ip]
  validity_period_hours = 1
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "client_auth",
  ]
}

module "acm" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-acm.git"

  import_certificate = {
    private_key      = tls_private_key.this.private_key_pem
    certificate_body = tls_self_signed_cert.this.cert_pem
  }
  tags = var.tags
}

# duplicate cert just so we can test additional_certs key
module "acm_2" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-acm.git"

  import_certificate = {
    private_key      = tls_private_key.this.private_key_pem
    certificate_body = tls_self_signed_cert.this.cert_pem
  }

  tags = var.tags
}

# test module
module "nlb" {
  source = "./../.."

  nlb_name        = "eits-tf-aws-nlb-tls"
  vpc_id          = var.vpc_id
  subnet_ids      = [var.subnet_ids[0]]
  security_groups = module.test_ec2.security_group_ids

  enable_cross_zone_load_balancing = true
  enable_deletion_protection       = false

  target_groups = {
    eits-tf-aws-nlb = {
      port     = 443
      protocol = "TLS"
      health_check = {
        enabled = true
        port    = "traffic-port"
      }
      target_type = "instance"
      targets = [
        {
          name      = "eits-tf-aws-nlb"
          target_id = module.test_ec2.id
        }
      ]
    }
  }

  listeners = [
    {
      port                 = 443
      protocol             = "TLS"
      default_target_group = "eits-tf-aws-nlb"
      ssl_policy           = "ELBSecurityPolicy-TLS13-1-2-2021-06"
      certificate_arn      = module.acm.arn
      additional_certs     = [module.acm_2.arn]
    }
  ]

  tags = var.tags
}
