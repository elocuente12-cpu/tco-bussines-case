
check "tag_resource_owner" {
  assert {
    condition     = lookup(merge(local.tags, data.aws_default_tags.this.tags), "ResourceOwner", null) != null
    error_message = "The 'ResourceOwner' tag is required for EC2 instances, in accordance with EEC Cloud Tagging Strategy & Standards."
  }
}

check "tag_resource_app_role" {
  assert {
    condition     = lookup(merge(local.tags, data.aws_default_tags.this.tags), "ResourceAppRole", null) != null
    error_message = "The 'ResourceAppRole' tag is required for EC2 instances, in accordance with EEC Cloud Tagging Strategy & Standards."
  }
}

check "tag_ad_domain" {
  assert {
    condition     = lookup(merge(local.tags, data.aws_default_tags.this.tags), "adDomain", null) != null
    error_message = "The 'adDomain' tag is required for EC2 instances, in accordance with EEC Cloud Tagging Strategy & Standards."
  }
}

check "tag_ad_group" {
  assert {
    condition     = (!can(regex("win", var.ami)) && var.operating_system == "linux") || lookup(merge(local.tags, data.aws_default_tags.this.tags), "adGroup", null) != null
    error_message = "The 'adGroup' tag is required for EC2 Windows instances, in accordance with EEC Cloud Tagging Strategy & Standards."
  }
}

check "tag_centrify_unix_role" {
  assert {
    condition     = can(regex("win", var.ami)) || var.operating_system == "windows" || lookup(merge(local.tags, data.aws_default_tags.this.tags), "CentrifyUnixRole", null) != null
    error_message = "The 'CentrifyUnixRole' tag is required for EC2 Linux instances, in accordance with EEC Cloud Tagging Strategy & Standards."
  }
}

check "ec2_name_rule" {
  assert {
    condition     = length(regexall("^[A-Za-z]{2}(?i:[A])[A-Za-z]{1,2}[0-9]{1}(?i:[PGUQTDSX])[A-Za-z]{2}[WUwu][A-Za-z0-9]{2,3}[0-9]{2}$", split(".", local.resource_name)[0])) > 0
    error_message = <<EOF
    The hostname '${split(".", local.resource_name)[0]}' does not follow EEC naming convention or exceeds 15 character limit.
    Example of valid name: USAEA1PWBUAS01.
    For further guidence see https://experian.atlassian.net/wiki/spaces/SC/pages/284623566/How+to+build+EC2+instances+using+the+Experian+Golden+AMIs#%5BinlineExtension%5DGenerate-Hostname
    EOF
  }
}

check "instance_profile_missing" {
  assert {
    condition     = var.create_cloudwatch_role || (var.instance_profile != null && var.instance_profile != "")
    error_message = <<EOT
    No Instance profile defined (Wiz EC2-013)
    Amazon EC2 uses an instance profile as a container for an IAM role. Using IAM roles, the EC2 instance is assigned a role that has an appropriate permissions policy for the required access level. IAM roles reduce the risks associated with sharing and rotating credentials that can be used outside of AWS. If credentials are compromised, they can be used from outside of the AWS account. In contrast, in order to leverage role permissions, an attacker would need to gain access to a specific instance to use the privileges associated with it.
    EOT
  }
}

check "metadata_http_tokens_required" {
  assert {
    condition     = var.metadata_http_tokens_required
    error_message = <<EOT
    EC2 instance should use IMDSv2 (Wiz EC2-004)
    It is recommended to only allow the use of IMDSv2 on EC2 instances, to help protect them from attacks exploiting the older version of the service.
    EOT
  }
}

check "metadata_hop_limit_warning" {
  assert {
    condition     = var.metadata_http_put_response_hop_limit >= 1 && var.metadata_http_put_response_hop_limit <= 2
    error_message = <<EOT
    Metadata HTTP Hop Limit is too high (Wiz EC2-022)
    With IMDSv2, setting the HTTP Hop Limit to high (1 for regular servers, 2 for containers) means that requests from the EC2 instance itself will work because they're returned to the caller (on the instance) before the subtraction occurs. But if the instance has been misconfigured as an open router, layer 3 firewall, VPN, tunnel, or NAT device, the response containing the token will have its TTL reduced to zero before leaving the instance, and the packet containing the response will be discarded on its way out of the instance, preventing transport to the attacker.
    EOT
  }
}

check "instance_scheduler" {
  assert {
    condition     = contains(["stg", "uat", "prd"], local.environment) || (lookup(merge(local.tags_to_check, local.eec_instance_scheduler_tag), "Instance-Scheduler", "") != "" || lookup(local.tags_to_check, "leaseHours", "") != "")
    error_message = <<EOT
    We recommend using the Instance Scheduler to stop and start your EC2 instances in lower environments. 
    This will help reduce costs by ensuring that instances are only running when needed.
    EOT
  }
}
