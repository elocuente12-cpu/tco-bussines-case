# move bucket policy from count - v2.3.0
moved {
  from = aws_s3_bucket_policy.source_documents[0]
  to   = aws_s3_bucket_policy.this
}
