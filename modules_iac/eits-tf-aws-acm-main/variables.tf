variable "action" {
  type    = string
  default = "import"
  validation {
    condition     = contains(["import", "request"], var.action)
    error_message = "Invalid value for 'action'. Valid values are 'import' and 'request'."
  }
  description = "Action to perform. Valid values are 'import' and 'request'"
}

variable "import_certificate" {
  type = object({
    private_key       = string
    certificate_body  = string
    certificate_chain = optional(string, "")
  })
  default = {
    private_key      = ""
    certificate_body = ""
  }
  description = "Certificate to import in PEM format"
}

variable "request_certificate" {
  type = object({
    hosted_zone_name  = string
    domain_name       = string
    validation_method = string
  })
  default = {
    hosted_zone_name  = ""
    domain_name       = ""
    validation_method = ""
  }
  validation {
    condition     = can(contains(["DNS", "EMAIL", ""], var.request_certificate.validation_method)) ? contains(["DNS", "EMAIL", ""], var.request_certificate.validation_method) : true
    error_message = "Invalid value for 'validation_method'. Valid values are 'DNS' and 'EMAIL'."
  }
  description = "Certificate to request"
}

variable "certificate_transparency_logging" {
  type        = bool
  default     = true
  description = "Certificate transparency logging preference, only applicable for requested certificates"
}

variable "subject_alternative_names" {
  type        = list(string)
  default     = []
  description = "Subject alternative names for the certificate, only applicable for requested certificates"
}

variable "enable_route53_alarms" {
  type        = bool
  default     = false
  description = "Enable Route53 alarms, only applicable for requested certificates"
}

variable "route53_recordset_overwrite" {
  type        = bool
  default     = true
  description = "Allow overwriting of existing Route53 record set, only applicable for requested certificates"
}

variable "route53_recordset_ttl" {
  type        = number
  default     = 60
  description = "TTL for the Route53 record set, only applicable for requested certificates"
}

variable "validation_option" {
  type        = any
  default     = {}
  description = "Validation options for the certificate request"
}

variable "external_domain_validation" {
  type        = bool
  default     = false
  description = "Set to `true` if the DNS domain validation is external. See README for more details"
}

variable "disable_default_alarms" {
  type        = bool
  description = "To disable the best practice AWS alarms as outlined here in [AWS Best Practices](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Best_Practice_Recommended_Alarms_AWS_Services.html#CertificateManager)"
  default     = false
}

variable "alarm_sns_topics" {
  type        = list(string)
  description = "List of SNS topics triggered by alarm events. providing a list will automatically enable alarm actions"
  default     = []
}

variable "enable_all_alarm_actions" {
  type        = bool
  description = "Set to `true` to enable alarm actions for `INSUFFICIENT_DATA` and `OK` state for all default alarms. By default, only `ALARM` states will trigger actions"
  default     = false
}

variable "cloudwatch_tags" {
  type        = map(string)
  default     = {}
  description = "Cloudwatch Alarm tags. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for AWS resources. See https://pages.experian.com/pages/viewpage.action?pageId=400041906 for all available tags"
}
