terraform {
  backend "s3" {
    bucket               = "eec-aws-us-nada-sharedservices-sandbox-tfstate"
    workspace_key_prefix = "ami/nada-digital-envoy/digital-envoy/promote"
    key                  = "terraform.tfstate"
    region               = "us-east-1"
  }
}