variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnet IDs to associate with NLB"
  default     = ["subnet-0007176f4041512f4", "subnet-07f7f119f8527be21"]
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://experian.atlassian.net/wiki/x/swH3E) for available tags"
  default     = {}
}

variable "vpc_id" {
  type        = string
  description = "VPC ID to associate with NLB"
  default     = "vpc-044f838833610a3f6"
}

variable "region" {
  type        = string
  description = "AWS region to provision into"
  default     = "eu-west-2"
}

variable "ec2_name" {
  type        = string
  description = "EC2 instance name for the alarms test target"
  default     = "eits-tf-aws-nlb-alarms"

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.ec2_name))
    error_message = "ec2_name must contain only alphanumeric characters and hyphens."
  }
}
