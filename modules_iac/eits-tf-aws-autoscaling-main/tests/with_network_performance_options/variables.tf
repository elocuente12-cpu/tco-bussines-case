variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://pages.experian.com/pages/viewpage.action?pageId=400041906) for available tags"
}

variable "region" {
  type        = string
  description = "AWS region to provision into"
}

variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnet IDs to launch resources in"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the security group will be created"
}
