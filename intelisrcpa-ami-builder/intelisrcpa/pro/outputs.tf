output "image_pipeline_arn" {
  description = "ARN del Image Builder pipeline para ejecutar builds."
  value       = module.imagebuilder.pipeline_arn
}

output "kms_key_arn" {
  description = "ARN de la KMS key para cifrado de AMIs."
  value       = module.kms_imagebuilder.key_arn
}
