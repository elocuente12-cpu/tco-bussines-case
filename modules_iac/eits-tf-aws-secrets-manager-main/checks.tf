check "description_warning" {
  assert {
    condition     = var.description != null
    error_message = "AWS Best Practice recommends providing a useful description."
  }
}

check "kms_key_id_warning" {
  assert {
    condition     = var.kms_key_id != null
    error_message = "Wiz recommends specifying a KMS key to use for secrets encryption. (Secret-003)"
  }
}

check "secret_rotation_warning" {
  assert {
    condition     = var.rotation_lambda_arn != null && (var.rotation_rules.automatically_after_days != null || var.rotation_rules.schedule_expression != null)
    error_message = "Wiz recommends using automatic secret rotation (Secret-002)"
  }
}