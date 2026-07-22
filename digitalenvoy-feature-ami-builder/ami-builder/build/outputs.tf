output "image_pipeline_arn" {
  value = module.imagebuilder.image_pipeline_arn
}

output "kms_key_arn_east" {
  description = "KMS key ARN in us-east-1"
  value       = local.is_west_workspace ? data.aws_kms_alias.digital_envoy_ami_sharing_key_east[0].target_key_arn : aws_kms_key.digital_envoy_ami_sharing_key[0].arn
}

output "kms_key_arn_west" {
  description = "KMS replica key ARN in us-west-2"
  value       = local.is_west_workspace ? data.aws_kms_alias.digital_envoy_ami_sharing_key_west[0].target_key_arn : aws_kms_replica_key.digital_envoy_ami_sharing_key_west[0].arn
}
