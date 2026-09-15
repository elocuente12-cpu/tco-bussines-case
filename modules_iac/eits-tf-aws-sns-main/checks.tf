check "public_topic" {
  assert {
    condition     = try((length(lookup(jsondecode(var.policy_json), "Statement", [])) > 0 ? anytrue([for v in jsondecode(var.policy_json).Statement : (v.Effect == "Allow" && values(v.Principal) == ["*"] ? false : true)]) : true), true)
    error_message = <<EOT
Unless you explicitly require anyone on the internet to be able to read or write to your Amazon SNS topic, you should ensure that your topic isn't publicly accessible (accessible by everyone in the world or by any authenticated AWS user).

* Avoid creating policies with Principal set to "".
* Avoid using a wildcard (*). Instead, name a specific user or users.

More information: https://docs.aws.amazon.com/sns/latest/dg/sns-security-best-practices.html#ensure-topics-not-publicly-accessible
EOT
  }
}

check "cmk_encryption" {
  assert {
    condition     = var.kms_master_key_id != "alias/aws/sns"
    error_message = <<EOT
    SECURITY REQUIREMENT
    -------------------
    This SNS Topic should be encrypted with a customer-managed KMS key (CMK).
    Benefits of using CMK over AWS managed keys:
    - Full control over key rotation and deletion 
    - Ability to audit key usage through CloudTrail
    - Fine-grained access control through key policies
    - Cross-account access management
    - Compliance with security requirements 
  EOT
  }
}

check "no_subscribers" {
  assert {
    condition     = length(var.subscribers) > 0
    error_message = <<EOT
This SNS Topic does not have any subscribers. Ensure that your SNS topics have at least one subscriber to receive messages.

More information: https://docs.aws.amazon.com/sns/latest/dg/sns-subscription-types.html
EOT
  }
}
