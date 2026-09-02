variable "hosted_zone_name" {
  type        = string
  description = "Name of the hosted zone to contain this record"
}

variable "tags" {
  type        = map(string)
  description = "Tags for AWS resources. See [Cloud Tagging Strategy & Standards](https://pages.experian.com/pages/viewpage.action?pageId=400041906) for available tags"
}

variable "region" {
  type        = string
  description = "AWS region to provision into"
}
