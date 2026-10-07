variable "module_repo" {
  type        = string
  default     = "NONE"
  description = "Repo slug for the module, for example `eits-tf-aws-nlb`"
}

variable "module_project" {
  type        = string
  default     = "EUCES"
  description = "The bitbucket project name"
}

variable "tags" {
  type        = map(string)
  default     = {} # for compatibility: if no tags variable is passed, will ignore validation
  description = "AWS resource tags. See https://experian.atlassian.net/wiki/x/swH3E for all available tags"
}
