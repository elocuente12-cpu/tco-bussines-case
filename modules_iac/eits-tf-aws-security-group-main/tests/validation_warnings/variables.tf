variable "region" {
  type        = string
  description = "AWS region to provision into"
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to associate with NLB"
}
