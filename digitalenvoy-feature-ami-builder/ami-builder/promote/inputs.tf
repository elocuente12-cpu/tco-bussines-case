variable "image_id" {
  description = "AMI ID to share"
  type        = string
}

variable "destination_account_id" {
  description = "AWS account to share the image with"
  type        = string
}

variable "aws_region" {
  description = "Region where the AMI exists"
  type        = string
  default     = "us-east-1"
}