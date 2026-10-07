locals {
  broad_private_cidrs = ["10.0.0.0/8", "192.168.0.0/16", "172.16.0.0/12"]
  sensitive_ports     = [22, 23, 3389]

  open_ingress_detected = anytrue([
    for rule in var.security_group_ingress_rules :
    anytrue([for cidr in coalesce(rule.cidr_blocks, []) : cidr == "0.0.0.0/0"])
    ]) || anytrue([
    for rule in var.security_group_ingress_rules :
    anytrue([for cidr in coalesce(rule.ipv6_cidr_blocks, []) : cidr == "::/0"])
  ])

  broad_private_cidrs_detected = anytrue([
    for rule in var.security_group_ingress_rules :
    anytrue([for cidr in coalesce(rule.cidr_blocks, []) : contains(local.broad_private_cidrs, cidr)])
  ])

  all_ports_open_detected = anytrue([
    for rule in var.security_group_ingress_rules :
    (rule.from_port == -1 && rule.to_port == -1) || (rule.from_port == 0 && rule.to_port == 65535)
  ])

  sensitive_ports_detected = anytrue([
    for rule in var.security_group_ingress_rules :
    anytrue([for port in local.sensitive_ports : (
    rule.to_port != null && rule.from_port != null ? (port >= rule.from_port && port <= rule.to_port + 1) : false)])
  ]) || local.all_ports_open_detected

}

check "open_ingress_all_ports_warning" {
  assert {
    condition     = !(local.open_ingress_detected && local.all_ports_open_detected)
    error_message = <<EOF
Warning: Open `cidr_blocks` Detected.  Wiz rule VPC-106
Security Groups are stateful and provide filtering of ingress/egress network traffic to AWS EC2 instances.
Allowing access from unrestricted sources and ports increases opportunities for malicious activity.
It is recommended to restrict inbound access and ensure only specific ports are allowed.
EOF
  }
}

check "ingress_open_cidr_sensitive_ports_warning" {
  assert {
    condition     = !(local.open_ingress_detected && local.sensitive_ports_detected)
    error_message = <<EOF
Warning: Open `cidr_blocks` Detected.  Wiz rule VPC-108
Exposing these ports to the Internet can increase opportunities for malicious activities.
It is recommended to configure the Security Group to limit ingress traffic to known and trusted IP addresses only.
EOF
  }
}

check "broad_private_cidr_blocks_warning" {
  assert {
    condition     = !local.broad_private_cidrs_detected
    error_message = <<EOF
Warning: broad private cidr detected.  Wiz rule Firewall-007
Allowing overly permissive inbound access from private networks can increase the risk for malicious activities such as brute-force and denial of service attacks. It is recommended to restrict the inbound access on the Security Group to the specific private IP addresses required.
EOF
  }
}

check "sensitive_ports_warning" {
  assert {
    condition     = !local.sensitive_ports_detected
    error_message = <<EOF
Warning: Sensitive port detected.  Wiz rule VPC-081
It is recommended to avoid using CIDR block IP ranges when granting access to sensitive ports.
EOF
  }
}


check "ingress_cidr_blocks_warning" {
  assert {
    condition     = !local.open_ingress_detected
    error_message = <<EOF
Warning: Open `cidr_blocks` Detected.  Wiz rule VPC-082
One or more ingress rules allow traffic from `0.0.0.0/0`, which exposes this security group to the public internet.
It is recommended to restrict CIDR blocks to known IP ranges to enhance security.
EOF
  }
}

check "broad_private_cidr_sensitive_ports_warning" {
  assert {
    condition     = !(local.broad_private_cidrs_detected && local.sensitive_ports_detected)
    error_message = <<EOF
Warning: Sensitive port on wide private network detected.  Wiz rule VPC-083
EC2 Security Group allowing access to a sensitive port should not be exposed to a wide private network
EOF
  }
}
