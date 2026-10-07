terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.0"
    }

    http = {
      source  = "hashicorp/http"
      version = ">= 3.4.0"
    }
  }

}
