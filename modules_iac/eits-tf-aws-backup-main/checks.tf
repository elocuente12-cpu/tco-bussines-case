check "vault_kms_key_arn" {
  assert {
    condition     = var.vault_kms_key_arn != null
    error_message = <<EOF
Wiz Security Warning - BackupService-021
Encrypting data at rest is a critical security measure to protect sensitive data from unauthorized access. Using a KMS CMK for encryption provides additional security controls and auditing capabilities, ensuring that only authorized users and services can decrypt the data.
EOF
  }
}

check "unsupported_notification_events_warning" {
  assert {
    condition     = alltrue([for e in lookup(var.backup_notifications, "backup_vault_events", []) : contains(local.allowed_events, e)])
    error_message = <<EOF
Wiz Security Warning - BackupService-003
While having event notifications configured that are no longer supported does not impose a security risk, having the Backup Vault configured with such configurations may make you seem to believe that such notifications for events will be sent when in practice they will not.
It is recommended to remove the deprecated event notifications and only use those that are supported.

Allowed Events: ${join(", ", local.allowed_events)}
TEST
EOF
  }
}