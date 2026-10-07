# Check: S3 Bucket versioning should be enabled
check "versioning_enabled" {
  assert {
    condition     = var.versioning_enabled == true || var.replication_config.enabled == true
    error_message = "S3 Bucket versioning is not enabled, risking data loss from overwrites. Mitigation: Set `versioning_enabled = true` in your module configuration."
  }
}

# Check: S3 Bucket should have all 'Block Public Access' settings enabled
check "all_block_public_access_enabled" {
  assert {
    condition     = lookup(var.public_access_config, "block_public_acls", true) == true && lookup(var.public_access_config, "block_public_policy", true) == true && lookup(var.public_access_config, "ignore_public_acls", true) == true && lookup(var.public_access_config, "restrict_public_buckets", true) == true
    error_message = "S3 Bucket does not have all 'Block Public Access' settings enabled, risking public exposure. Mitigation: Ensure `public_access_config` is unset (defaults to all `true`) or explicitly set with all values as `true`."
  }
}

# Check: S3 Bucket policy should restrict access to approved source IPs
check "restrict_access_to_approved_ips" {
  assert {
    condition     = var.disable_source_ip_check == false
    error_message = "S3 Bucket policy does not restrict access to approved source IPs, risking unauthorized access from untrusted networks. Mitigation: Keep `disable_source_ip_check = false` to enforce IP-based restrictions."
  }
}

# Check: S3 Bucket ACL should not allow global access (READ, WRITE, READ_ACP, WRITE_ACP)
check "no_global_acl_access" {
  assert {
    condition     = var.object_ownership == "BucketOwnerEnforced"
    error_message = "S3 Bucket ACL may allow global access (READ, WRITE, READ_ACP, WRITE_ACP), risking unauthorized access. Mitigation: Keep `object_ownership = 'BucketOwnerEnforced'` to disable ACLs and enforce bucket policies."
  }
}

# Check: CloudWatch Alarm should monitor S3 buckets
check "cloudwatch_alarms_enabled" {
  assert {
    condition     = var.disable_default_alarms == false
    error_message = "CloudWatch Alarms for S3 buckets are disabled, reducing monitoring capabilities. Mitigation: Keep `disable_default_alarms = false` to enable default alarms."
  }
}

#Check: S3 Bucket policy should not allow overly permissive actions, principals, or missing conditions
check "restrict_overly_permissive_bucket_policy" {
  assert {
    condition = alltrue(flatten([
      for statement in jsondecode(data.aws_iam_policy_document.source_documents.json).Statement :
      !(
        statement.Effect == "Allow" &&
        (
          anytrue([
            contains(can(tolist(statement.Action)) ? tolist(statement.Action) : tolist(flatten([statement.Action])), "*"),
            contains(can(tolist(statement.Action)) ? tolist(statement.Action) : tolist(flatten([statement.Action])), "s3:*"),
            anytrue([for action in(can(tolist(statement.Action)) ? tolist(statement.Action) : tolist(flatten([statement.Action]))) : startswith(action, "s3:List")]),
            anytrue([for action in(can(tolist(statement.Action)) ? tolist(statement.Action) : tolist(flatten([statement.Action]))) : startswith(action, "s3:Delete")]),
            anytrue([for action in(can(tolist(statement.Action)) ? tolist(statement.Action) : tolist(flatten([statement.Action]))) : startswith(action, "s3:Put")]),
            anytrue([for action in(can(tolist(statement.Action)) ? tolist(statement.Action) : tolist(flatten([statement.Action]))) : startswith(action, "s3:Get")])
          ])
        ) &&
        (
          contains(
            can(tolist(statement.Principal.AWS)) ? tolist(statement.Principal.AWS) : try(tolist(statement.Principal.AWS), []), "*"
          ) ||
          contains(
            can(tolist(statement.Principal)) ? tolist(statement.Principal) : tolist([statement.Principal]), "AWS:*"
          )
        ) &&
        try(statement.Condition, null) == null
      )
    ]))
    error_message = <<EOT
The S3 Bucket policy is overly permissive:
- It allows actions with wildcards (*, s3:*, or s3:List*, s3:Delete*, s3:Put*, s3:Get*).
- It allows principals with wildcards (* or AWS:*).
- It has an "Allow" effect without any conditions.
Mitigation: Ensure the bucket policy is more restrictive by removing wildcards, specifying principals explicitly, and adding conditions.
EOT
  }
}