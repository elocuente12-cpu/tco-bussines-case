terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn     = var.assume_role_arn
    external_id  = var.assume_role_external_id
    session_name = "terraform"
  }
  default_tags {
    tags = {
      AppID       = var.appId
      CostString  = var.costString
      Environment = var.tagenv
      ManagedBy   = "Terraform"
      Application = "InteliSrcPA"
    }
  }
}
