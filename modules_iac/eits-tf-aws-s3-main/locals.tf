locals {
  bucket_name = var.prefix != null ? "${var.prefix}-${var.bucket_name}-s3" : var.bucket_name

  tags = merge(var.tags, module.eits_ce_common.tags)

  acl_grants = var.acl_grants == null ? [] : flatten([
    for grant in var.acl_grants : [
      for permission in grant.permissions : {
        id         = lookup(grant, "id", null)
        type       = grant.type
        permission = permission
        uri        = lookup(grant, "uri", null)
      }
    ]
  ])

  experian_source_ips = [
    "167.107.0.0/16",
    "205.174.32.0/20",
    "200.245.207.0/24",
    "200.234.240.0/20",
    "84.246.168.0/24",
    "18.231.70.159/32",
    "34.200.128.151/32",
    "13.212.56.186/32",
    "3.25.208.9/32",
    "13.235.74.213/32",
    "199.96.232.0/22",
    "54.207.188.124/32",
    "54.94.89.48/32",
    "54.207.206.229/32",
    "200.192.106.16/32",
    "204.199.78.170/29",
    "194.60.163.222/32",
    "200.46.229.2/32",
    "77.95.152.0/24",
    # Begin SkyHigh proxy CIDRs (shared pools)
    "161.69.16.0/21",
    "161.69.32.0/22",
    "161.69.36.0/23",
    "161.69.40.0/21",
    "161.69.48.0/20",
    "161.69.64.0/18",
    "52.52.221.153/32",
    "15.236.59.65/32",
    "35.172.57.133/32",
    "52.9.179.186/32",
    "185.221.68.0/22",
    "185.212.104.0/22",
    "120.138.17.53/32",
    "120.138.17.54/32",
    "184.75.215.242/32",
    "184.75.215.98/32",
    "185.125.224.0/22",
    "52.201.126.139/32",
    "52.38.193.184/32",
    "208.81.67.37/32",  # Static IP Europe
    "185.221.69.37/32", # Static IP Europe
    "208.65.145.37/32", # Static IP North America
    "208.81.70.37/32",  # Static IP North America
    "185.221.71.37/32"  # Static IP Latin America
    # End SkyHigh proxy CIDRs
  ]

  eec_shared_vpce = {
    "ap-south-1"     = "vpce-031e188e711c74b71"
    "ap-southeast-1" = "vpce-0ce6782d9c351e9c3"
    "ap-southeast-2" = "vpce-005b4eb8917cb779b"
    "eu-central-1"   = "vpce-0ac118c92f6a39a62"
    "eu-west-1"      = "vpce-048fbba0aa982b902"
    "eu-west-2"      = "vpce-0133002bb1e6c3aad"
    "sa-east-1"      = "vpce-02edcb17d3afae092"
    "us-east-1"      = "vpce-06a776b80c8f99ea8"
    "us-west-2"      = "vpce-00eb906d42bee3b64"
  }

  default_multipart_uploads = var.enable_abort_incomplete_multipart_upload ? [{
    id                                     = "default-abort-incomplete-uploads"
    status                                 = "Enabled"
    abort_incomplete_multipart_upload_days = var.default_abort_incomplete_multipart_upload_days
    filter                                 = {}
    expiration                             = null
    transition                             = []
    noncurrent_version_expiration          = null
    noncurrent_version_transition          = []
  }] : []

  lifecycle_rules = concat(local.default_multipart_uploads, var.lifecycle_rules)
}