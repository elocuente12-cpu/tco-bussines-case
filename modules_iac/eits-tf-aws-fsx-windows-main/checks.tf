check "fsx_windows_cmk_required" {
  assert {
    condition     = aws_fsx_windows_file_system.this.kms_key_id != null && aws_fsx_windows_file_system.this.kms_key_id != "aws/fsx"
    error_message = "FSx Windows File System must be encrypted with a customer-managed key (CMK). The 'kms_key_id' attribute must be defined and not set to the AWS-managed key alias 'aws/fsx'."
  }
}

# KMS CMK key must be used for production environments
check "eits_validation" {
  assert {
    condition     = !(local.environment == "prd" && var.create_kms_key == false && (var.kms_key_arn == null || var.kms_key_arn == "aws/fsx"))
    error_message = "A KMS CMK key must be used for production environments to comply with Experian security standards."
  }
}