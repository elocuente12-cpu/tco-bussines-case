variable "aws_region" {
  type = map(string)
  description = "Region where resources are created."
  default = {
    stage = "us-east-1"
    uat   = "us-east-1"
    prod  = "us-east-1"
    stage_west = "us-west-2"
    uat_west   = "us-west-2"
    prod_west  = "us-west-2"
  }
}

variable "vpc_cidr" {
  type = map(string)
  description = "VPC CIDR where servers will be created"
  default = {
    stage = "10.4.156.0/24"
    uat   = "10.4.156.0/24"
    prod  = "10.4.156.0/24"
    stage_west = "10.3.61.0/24"
  }
}

variable "team" {
  description = "Team name"
  type        = string
  default     = "nada-digital-envoy"
}

variable "kmskey" {
  description = "KMS Key alias to be used for AMIs being built"
  type        = string
  default     = "digital_envoy_ami_sharing_key"
}

locals {
  region = lookup(var.aws_region, terraform.workspace)
}
