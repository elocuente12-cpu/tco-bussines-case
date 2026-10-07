locals {
  # Handle Singapore prefix `sg-` by replacing with `sgp-` because a security group name cannot begin with `sg-`
  raw_prefix = var.prefix != null ? var.prefix : module.eits_ce_common.prefix
  prefix     = startswith(lower(local.raw_prefix), "sg-") ? replace(local.raw_prefix, "/^[Ss][Gg]-/", "sgp-") : local.raw_prefix
  sg_name    = format("%s%s%s-sg", local.prefix, local.prefix == "" ? "" : "-", var.security_group_name)
  tags = merge({
    Name = local.sg_name
  }, var.tags, module.eits_ce_common.tags)
  region        = data.aws_region.current.region
  region_prefix = split("-", local.region)[0]

  # Cyberark SIA, see https://experian.sharepoint.com/sites/globalsecurityadministration/GSA%20Sharing%20with%20Business/PAM/SitePages/Cloud-Servers-Implementation-Steps.aspx?csf=1&web=1&e=FguBUm&CID=2e418abe-9cd7-4223-97d7-3b67b9549f55#eec-aws-pre-requisites
  # In the above link, the CIDRs for the individual subnets are listed, so we're using the VPC CIDRs instead to reduce the number of rules
  cyberark_cpm_cidrs_map = {
    "ap" = ["10.153.51.48/28", "10.153.51.112/28"]
    "eu" = ["10.232.129.96/28", "10.232.129.224/28"]
    "sa" = ["10.121.53.176/28", "10.121.53.240/28"]
    "us" = ["10.3.21.96/28", "10.3.21.224/28", "10.4.199.96/28", "10.4.199.224/28"]
  }
  cyberark_sia_cidrs_map = {
    "ap" = ["10.152.192.64/26", "10.152.5.64/26"]
    "eu" = ["10.232.152.0/26", "10.233.81.128/26"]
    "sa" = ["10.121.84.128/26"]
    "us" = ["10.64.6.64/26", "10.3.113.0/26"]
  }
  cyberark_region    = contains(keys(local.cyberark_sia_cidrs_map), local.region_prefix) ? local.region_prefix : "us"
  cyberark_cpm_cidrs = local.cyberark_cpm_cidrs_map[local.cyberark_region]
  cyberark_sia_cidrs = local.cyberark_sia_cidrs_map[local.cyberark_region]
  cyberark_sia_rules = var.cyberark_sia_rules != null ? var.cyberark_sia_rules : var.ec2_agent_rules != null ? var.ec2_agent_rules : null

  # https://experian.atlassian.net/wiki/spaces/SC/pages/284623566/How+to+build+EC2+instances+using+the+Experian+Golden+AMIs#%F0%9F%94%90-Security-Group-Rules
  snow_cidrs_map = {
    "ap-south-1"     = "10.152.149.64/26"
    "ap-south-2"     = "10.155.11.64/26"
    "ap-southeast-1" = "10.153.4.0/27"
    "ap-southeast-2" = "10.152.16.96/27"
    "eu-central-1"   = "10.233.65.128/27"
    "eu-west-1"      = "10.233.0.0/27"
    "eu-west-2"      = "10.229.161.0/25"
    "sa-east-1"      = "10.99.8.192/26"
    "us-east-1"      = "10.5.74.128/26"
    "us-west-2"      = "10.31.24.192/27"
  }
  snow_region = contains(keys(local.snow_cidrs_map), local.region) ? local.region : "us-east-1"
  snow_cidr   = local.snow_cidrs_map[local.snow_region]

  routable_cidrs      = [for association in data.aws_vpc.this.cidr_block_associations : association.cidr_block if startswith(association.cidr_block, "10.")]
  tanium_server_cidrs = ["10.2.89.224/28", "10.64.31.64/26", "10.2.89.240/28", "10.64.31.0/26"]

  # Default egress rules
  eec_egress_rules = {
    eec_egress_all = {
      from_port   = null
      to_port     = null
      ip_protocol = "-1"
      cidr_ipv4   = "0.0.0.0/0"
      description = "Allow outbound traffic"
    }
  }

  # SNOW rules
  snow_rules_win = merge({
    eec_cmdb_135_a = {
      from_port   = "135"
      to_port     = "135"
      ip_protocol = "tcp"
      cidr_ipv4   = local.snow_cidr
      description = "CMDB Asset discovery for ${local.snow_region} region"
    },
    eec_cmdb_445_a = {
      from_port   = "445"
      to_port     = "445"
      ip_protocol = "tcp"
      cidr_ipv4   = local.snow_cidr
      description = "CMDB Asset discovery for ${local.snow_region} region"
    },
    eec_snow_eph_a = {
      from_port   = "49152"
      to_port     = "65535"
      ip_protocol = "tcp"
      cidr_ipv4   = local.snow_cidr
      description = "CMDB Asset discovery for ${local.snow_region} region"
    }
  })
  snow_rules_lin = {
    eec_cmdb_22_a = {
      from_port   = "22"
      to_port     = "22"
      ip_protocol = "tcp"
      cidr_ipv4   = local.snow_cidr
      description = "CMDB Asset discovery for ${local.snow_region} region"
    }
  }

  # Cyberark CPM rules
  cyberark_cpm_rules_win = merge(
    {
      for cidr in local.cyberark_cpm_cidrs : "eec_cyberark_cpm_rpc_${cidr}" => {
        from_port   = "139"
        to_port     = "139"
        ip_protocol = "tcp"
        cidr_ipv4   = cidr
        description = "CyberArk CPM RPC access for ${local.cyberark_region} region"
      }
    },
    {
      for cidr in local.cyberark_cpm_cidrs : "eec_cyberark_cpm_smb_${cidr}" => {
        from_port   = "445"
        to_port     = "445"
        ip_protocol = "tcp"
        cidr_ipv4   = cidr
        description = "CyberArk CPM SMB access for ${local.cyberark_region} region"
      }
    }
  )
  cyberark_cpm_rules_lin = {
    for cidr in local.cyberark_cpm_cidrs : "eec_cyberark_cpm_ssh_${cidr}" => {
      from_port   = "22"
      to_port     = "22"
      ip_protocol = "tcp"
      cidr_ipv4   = cidr
      description = "CyberArk CPM SSH access for ${local.cyberark_region} region"
    }
  }

  # Cyberark SIA rules
  cyberark_sia_rules_win = merge(
    {
      for cidr in local.cyberark_sia_cidrs : "eec_cyberark_sia_rdp_${cidr}" => {
        from_port   = "3389"
        to_port     = "3389"
        ip_protocol = "tcp"
        cidr_ipv4   = cidr
        description = "CyberArk SIA RDP access for ${local.cyberark_region} region"
      }
    },
    {
      for cidr in local.cyberark_sia_cidrs : "eec_cyberark_sia_smb_${cidr}" => {
        from_port   = "445"
        to_port     = "445"
        ip_protocol = "tcp"
        cidr_ipv4   = cidr
        description = "CyberArk SIA SMB access for ${local.cyberark_region} region"
      }
    }
  )
  cyberark_sia_rules_lin = {
    for cidr in local.cyberark_sia_cidrs : "eec_cyberark_sia_ssh_${cidr}" => {
      from_port   = "22"
      to_port     = "22"
      ip_protocol = "tcp"
      cidr_ipv4   = cidr
      description = "CyberArk SIA SSH access for ${local.cyberark_region} region"
    }
  }

  # Tanium client rules
  tanium_cidr_rules = {
    for cidr in concat(local.routable_cidrs, local.tanium_server_cidrs) : "eec_tanium_17472_${cidr}" => {
      from_port   = "17472"
      to_port     = "17472"
      ip_protocol = "tcp"
      cidr_ipv4   = cidr
      description = contains(local.routable_cidrs, cidr) ? "Tanium P2P client" : "Tanium client"
    }
  }

  # Agents default ingress rules
  eec_ingress_rules_win = merge(local.snow_rules_win, local.cyberark_cpm_rules_win, local.tanium_cidr_rules)
  eec_ingress_rules_lin = merge(local.snow_rules_lin, local.cyberark_cpm_rules_lin, local.tanium_cidr_rules)

  ## INGRESS/EGRESS RULES
  # Create locals for each type of rules so that users can still use lists in their code, meaning that they don't need to change anything

  # IPv4 CIDR
  sg_ingress_rule_ipv4cidr = merge([
    for sgrule in var.security_group_ingress_rules : {
      for cidr in sgrule.cidr_blocks : "${cidr}_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
        from_port   = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
        to_port     = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
        ip_protocol = sgrule.protocol
        description = sgrule.description
        cidr_ipv4   = cidr
        tags        = sgrule.tags
      }
    } if sgrule.cidr_blocks != null
  ]...)
  sg_egress_rule_ipv4cidr = merge([
    for sgrule in var.security_group_egress_rules : {
      for cidr in sgrule.cidr_blocks : "${cidr}_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
        from_port   = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
        to_port     = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
        ip_protocol = sgrule.protocol
        description = sgrule.description
        cidr_ipv4   = cidr
        tags        = sgrule.tags
      }
    } if sgrule.cidr_blocks != null
  ]...)

  # IPv6 CIDR
  sg_ingress_rule_ipv6cidr = merge([
    for sgrule in var.security_group_ingress_rules : {
      for cidr in sgrule.ipv6_cidr_blocks : "${cidr}_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
        from_port   = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
        to_port     = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
        ip_protocol = sgrule.protocol
        description = sgrule.description
        cidr_ipv6   = cidr
        tags        = sgrule.tags
      }
    } if sgrule.ipv6_cidr_blocks != null
  ]...)

  sg_egress_rule_ipv6cidr = merge([
    for sgrule in var.security_group_egress_rules : {
      for cidr in sgrule.ipv6_cidr_blocks : "${cidr}_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
        from_port   = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
        to_port     = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
        ip_protocol = sgrule.protocol
        description = sgrule.description
        cidr_ipv6   = cidr
        tags        = sgrule.tags
      }
    } if sgrule.ipv6_cidr_blocks != null
  ]...)

  # Prefix lists
  sg_ingress_rule_pl = merge([
    for sgrule in var.security_group_ingress_rules : {
      for pefix_id in sgrule.prefix_list_ids : "${pefix_id}_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
        from_port      = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
        to_port        = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
        ip_protocol    = sgrule.protocol
        description    = sgrule.description
        prefix_list_id = pefix_id
        tags           = sgrule.tags
      }
    } if sgrule.prefix_list_ids != null
  ]...)

  sg_egress_rule_pl = merge([
    for sgrule in var.security_group_egress_rules : {
      for pefix_id in sgrule.prefix_list_ids : "${pefix_id}_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
        from_port      = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
        to_port        = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
        ip_protocol    = sgrule.protocol
        description    = sgrule.description
        prefix_list_id = pefix_id
        tags           = sgrule.tags
      }
    } if sgrule.prefix_list_ids != null
  ]...)

  # Security groups
  sg_ingress_rule_sg = merge([
    for sgrule in var.security_group_ingress_rules : {
      for group_id in sgrule.security_groups : "${group_id}_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
        from_port                    = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
        to_port                      = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
        ip_protocol                  = sgrule.protocol
        description                  = sgrule.description
        referenced_security_group_id = group_id
        tags                         = sgrule.tags
      }
    } if sgrule.security_groups != null
  ]...)

  sg_egress_rule_sg = merge([
    for sgrule in var.security_group_egress_rules : {
      for group_id in sgrule.security_groups : "${group_id}_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
        from_port                    = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
        to_port                      = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
        ip_protocol                  = sgrule.protocol
        description                  = sgrule.description
        referenced_security_group_id = group_id
        tags                         = sgrule.tags
      }
    } if sgrule.security_groups != null
  ]...)

  # Self - To replicate the "self" option that was available on `aws_security_group` but it's not on the newer `aws_vpc_security_group_ingress_rule`
  sg_ingress_rule_self = {
    for sg, sgrule in var.security_group_ingress_rules : "self_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
      from_port                    = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
      to_port                      = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
      ip_protocol                  = sgrule.protocol
      description                  = sgrule.description
      referenced_security_group_id = aws_security_group.this.id
    } if sgrule.self
  }

  sg_egress_rule_self = {
    for sg, sgrule in var.security_group_egress_rules : "self_${sgrule.protocol}_${sgrule.from_port != null ? sgrule.from_port : "0"}" => {
      from_port                    = sgrule.from_port == 0 && sgrule.protocol == "-1" ? null : sgrule.from_port
      to_port                      = sgrule.to_port == 0 && sgrule.protocol == "-1" ? null : sgrule.to_port
      ip_protocol                  = sgrule.protocol
      description                  = sgrule.description
      referenced_security_group_id = aws_security_group.this.id
    } if sgrule.self
  }
}
