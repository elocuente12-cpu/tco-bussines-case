variable "region" {
  description = "AWS region for the test"
  type        = string
  default     = "eu-west-2"
}

variable "subnet_ids" {
  description = "List of subnet IDs for the test"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for the test"
  type        = string
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}