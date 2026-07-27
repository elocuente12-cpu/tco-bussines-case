# Stub module for local validation only (replaces eits-tf-aws-kms-innersource)
variable "name" { type = string }
variable "description" { type = string; default = "" }
variable "deletion_window_in_days" { type = number; default = 30 }
variable "enable_key_rotation" { type = bool; default = true }
variable "tags" { type = map(string); default = {} }

output "key_arn" { value = "arn:aws:kms:us-east-1:123456789012:key/stub-key-id" }
output "key_id" { value = "stub-key-id" }
