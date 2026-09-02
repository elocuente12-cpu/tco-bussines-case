output "arn" {
  value       = var.action == "import" ? aws_acm_certificate.import_cert[0].arn : aws_acm_certificate.request_cert[0].arn
  description = "The ARN of the Certificate."
}

output "domain_name" {
  value       = var.action == "import" ? aws_acm_certificate.import_cert[0].domain_name : aws_acm_certificate.request_cert[0].domain_name
  description = "The domain name of the Certificate."
}

output "status" {
  value       = var.action == "import" ? aws_acm_certificate.import_cert[0].status : aws_acm_certificate.request_cert[0].status
  description = "The status of the Certificate."
}

output "expiration" {
  value       = var.action == "import" ? aws_acm_certificate.import_cert[0].not_after : aws_acm_certificate.request_cert[0].not_after
  description = "The expiration of the Certificate."
}

output "domain_validation_options" {
  value       = var.action == "request" ? aws_acm_certificate.request_cert[0].domain_validation_options : []
  description = "The domain validation options of the Certificate."
}