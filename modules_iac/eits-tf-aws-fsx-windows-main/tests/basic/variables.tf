variable "region" {
  type        = string
  description = "AWS region to provision into"
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://pages.experian.com/pages/viewpage.action?pageId=400041906) for available tags"
}

variable "subnet_ids" {
  type        = list(string)
  description = "A list of subnet IDs to launch the FSx file system in"
}

variable "ad_username" {
  type        = string
  description = "Username for the Active Directory user used to join the file system to the domain"
  default     = "joiner"
  sensitive   = true
}

variable "ad_password" {
  type        = string
  description = "value of the password for the Active Directory user used to join the file system to the domain"
  default     = "don't store me like this!"
  sensitive   = true
}