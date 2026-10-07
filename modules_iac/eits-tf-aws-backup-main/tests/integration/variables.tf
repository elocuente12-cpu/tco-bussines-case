variable "region" {
  type        = string
  description = "AWS region to provision into"
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}

variable "access_logging_bucket" {
  type        = string
  description = "Defines the target bucket for logging."
}

variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnet IDs to associate with test EC2"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to associate with EC2"
}
