locals {
  # True when running the west workspace (e.g. stage_west, uat_west, prod_west)
  is_west_workspace = length(regexall("_west$", terraform.workspace)) > 0
}

# ---------------------------------------------------------------------------
# IAM Role - global, created only in east workspace
# ---------------------------------------------------------------------------
resource "aws_iam_role" "digital_envoy_ami_sharing_role" {
  count              = local.is_west_workspace ? 0 : 1
  name               = "DigitalEnvoy_Stage_AMI_Sharing_Role"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

# Data source - used by west workspace to reference the existing role
data "aws_iam_role" "digital_envoy_ami_sharing_role" {
  count = local.is_west_workspace ? 1 : 0
  name  = "DigitalEnvoy_Stage_AMI_Sharing_Role"
}

# ---------------------------------------------------------------------------
# KMS Primary Key (us-east-1) - created only in east workspace
# ---------------------------------------------------------------------------
resource "aws_kms_key" "digital_envoy_ami_sharing_key" {
  count                   = local.is_west_workspace ? 0 : 1
  provider                = aws.east
  description             = "Digital Envoy AMI Sharing Key"
  deletion_window_in_days = 7
  multi_region            = true
  policy                  = file("${path.module}/policies/de_ami_kms_policy.json")
}

# Data source - west workspace looks up the existing east KMS alias to get key ARN
data "aws_kms_alias" "digital_envoy_ami_sharing_key_east" {
  count    = local.is_west_workspace ? 1 : 0
  provider = aws.east
  name     = "alias/digital_envoy_ami_sharing_key"
}

# KMS Key Alias (us-east-1) - created only in east workspace
resource "aws_kms_alias" "digital_envoy_ami_sharing_key_alias" {
  count         = local.is_west_workspace ? 0 : 1
  provider      = aws.east
  name          = "alias/digital_envoy_ami_sharing_key"
  target_key_id = aws_kms_key.digital_envoy_ami_sharing_key[0].id
}

# ---------------------------------------------------------------------------
# KMS Replica Key (us-west-2) - created only in east workspace
# (primary key lives in east state; west workspace references it via data source)
# ---------------------------------------------------------------------------
resource "aws_kms_replica_key" "digital_envoy_ami_sharing_key_west" {
  count                   = local.is_west_workspace ? 0 : 1
  provider                = aws.west
  description             = "Digital Envoy AMI Sharing Key - West Replica"
  deletion_window_in_days = 7
  primary_key_arn         = aws_kms_key.digital_envoy_ami_sharing_key[0].arn
  policy                  = file("${path.module}/policies/de_ami_kms_policy.json")
}

# Data source - west workspace looks up the existing west KMS alias to get replica key ARN
data "aws_kms_alias" "digital_envoy_ami_sharing_key_west" {
  count    = local.is_west_workspace ? 1 : 0
  provider = aws.west
  name     = "alias/digital_envoy_ami_sharing_key"
}

# KMS Key Alias (us-west-2) - created only in east workspace
resource "aws_kms_alias" "digital_envoy_ami_sharing_key_alias_west" {
  count         = local.is_west_workspace ? 0 : 1
  provider      = aws.west
  name          = "alias/digital_envoy_ami_sharing_key"
  target_key_id = aws_kms_replica_key.digital_envoy_ami_sharing_key_west[0].id
}
