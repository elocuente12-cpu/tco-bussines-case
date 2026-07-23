##############################################
# General
##############################################

variable "environment" {
  type        = string
  description = "Environment name (e.g., dev, uat, prod)."
}

variable "prefix" {
  type        = string
  description = "Prefix for the naming convention."
  default     = null
}

variable "app_name" {
  type        = string
  description = "The name of the application."
}

variable "ResourceOwner" {
  type        = string
  description = "The ResourceOwner of the application."
}

variable "region" {
  type        = string
  description = "AWS region."
  default     = "us-east-1"
}

variable "appId" {
  type        = string
  description = "AppId on Gear."
}

variable "costString" {
  type        = string
  description = "Cost Center Code."
}

variable "tagenv" {
  type        = string
  description = "Tag for Environment."
}

variable "assume_role_arn" {
  type        = string
  description = "Assume Role ARN."
}

variable "assume_role_external_id" {
  type        = string
  description = "Assume Role external id."
}

##############################################
# Image Builder
##############################################

variable "imagebuilder_identifier" {
  type        = string
  description = "Identifier suffix for the Image Builder pipeline."
}

variable "parent_image_ami" {
  type        = string
  description = "AMI ID of the Golden AMI (parent image)."
}

variable "recipe_version" {
  type        = string
  description = "Semantic version of the image recipe."
  default     = "1.0.0"
}

variable "instance_types" {
  type        = list(string)
  description = "Instance types for the build instance."
  default     = ["m5.large"]
}

variable "root_volume_size" {
  type        = number
  description = "Root volume size in GB for the built AMI."
  default     = 100
}

variable "s3_log_bucket" {
  type        = string
  description = "S3 bucket for Image Builder logs."
}

variable "ami_share_account_ids" {
  type        = list(string)
  description = "AWS Account IDs to share the output AMI with."
  default     = []
}

##############################################
# KMS
##############################################

variable "kms_deletion_window_in_days" {
  type        = number
  description = "KMS key deletion window in days."
  default     = 30
}

variable "kms_enable_key_rotation" {
  type        = bool
  description = "Enable KMS key rotation."
  default     = true
}
