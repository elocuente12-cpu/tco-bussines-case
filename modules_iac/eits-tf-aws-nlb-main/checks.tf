check "no_tls_warning" {
  assert {
    condition = !anytrue([
      for listener in var.listeners :
      listener.protocol != "TLS"
    ])
    error_message = <<EOF
Without TLS enabled, encryption (if any) must be handled by the backend server.  Make sure this is your intention.
EOF
  }
}

check "no_acm_certificate_warning" {
  assert {
    condition = !anytrue([
      for listener in var.listeners :
      listener.protocol == "TLS" &&
      listener.certificate_arn == null
    ])
    error_message = <<EOF
Warning: No ACM Certificate Defined.  Wiz rule ELB-056
It is recommended to use ACM certificates for Application and Network Load Balancer listeners to ensure proper certificate management and enhanced security for your load balancer's HTTPS connections.
EOF
  }
}

check "no_logging_warning" {
  assert {
    condition = var.access_log_bucket_id != null || !anytrue([
      for listener in var.listeners :
      listener.protocol == "TLS"
    ])
    error_message = <<EOF
Warning: Logging not enabled.  Wiz rule VPC-040
Access logs contain information such as the time the request was received, the client IP address, latencies, request paths, and server response data. The access logs can be used to analyze traffic patterns and troubleshoot issues. The logs are stored in an S3 bucket as compressed files.
EOF
  }
}


check "tls10_warning" {
  assert {
    condition = !anytrue([
      for listener in var.listeners :
      listener.protocol == "TLS" && try(
        strcontains(listener.ssl_policy, "2015-05") ||
        strcontains(listener.ssl_policy, "2016-08") ||
      strcontains(listener.ssl_policy, "TLS13-1-0"), false)
    ])
    error_message = <<EOF
Warning: TLS 1.0 Detected.  Wiz rule ELB-015
Outdated TLS protocols are considered insecure as they might be vulnerable to man-in-the-middle exploits, allowing an attacker to decrypt and access encrypted data.
It is recommended to make sure that all NLB TLS listeners' security policies do not support TLS versions that are lower than 1.2.
EOF
  }
}

check "tls_less_than_12_warning" {
  assert {
    condition = !anytrue([
      for listener in var.listeners :
      listener.protocol == "TLS" && try(
        strcontains(listener.ssl_policy, "2015-05") ||
        strcontains(listener.ssl_policy, "2016-08") ||
        strcontains(listener.ssl_policy, "TLS-1-1") ||
        strcontains(listener.ssl_policy, "TLS13-1-0") ||
      strcontains(listener.ssl_policy, "TLS13-1-1"), false)
    ])
    error_message = <<EOF
Warning: TLS < 1.2 Detected.  Wiz rule ELB-011
Outdated TLS protocols are considered insecure as they might be vulnerable to man-in-the-middle exploits, allowing an attacker to decrypt and access encrypted data.
It is recommended to make sure that all NLB TLS listeners' security policies do not support TLS versions that are lower than 1.2.
EOF
  }
}
