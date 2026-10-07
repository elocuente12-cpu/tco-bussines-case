output "s3_bucket_id" {
  description = "The name of the bucket."
  value       = aws_s3_bucket.this.id
}

output "s3_bucket_arn" {
  description = "The ARN of the bucket. Will be of format arn:aws:s3:::bucketname."
  value       = aws_s3_bucket.this.arn
}

output "s3_bucket_domain_name" {
  description = "Bucket domain name. Will be of format bucketname.s3.amazonaws.com."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "The bucket region-specific domain name, including the region name."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "s3_hosted_zone" {
  description = "Route 53 Hosted Zone ID for this bucket's region."
  value       = aws_s3_bucket.this.hosted_zone_id
}

output "s3_region" {
  description = "AWS region this bucket resides in."
  value       = aws_s3_bucket.this.region
}

output "replication_iam_role_arn" {
  description = "ARN for the IAM role created for replication configuration."
  value       = try(module.replication_iam_role[0].role_arn, null)
}

output "replication_role_name" {
  description = "Name of the IAM role created for replication. Empty string when replication is disabled."
  value       = try(module.replication_iam_role[0].role_name, "")
}

output "replication_policy_json" {
  description = "Combined replication IAM policy JSON. Populated regardless of `replication_role_attach_policy_inline` so callers can attach it manually if needed. Empty string when replication is disabled."
  value       = try(data.aws_iam_policy_document.replication_combined[0].json, "")
}

output "s3_access_points" {
  description = "Map of created S3 access points and their configuration."
  value       = try(aws_s3_access_point.this, {})
}
