##############################################
# KMS - Image Builder AMI Encryption
##############################################

module "kms_imagebuilder" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-kms-innersource.git?ref=2.0.3"

  name                    = "${local.naming_construct}-imagebuilder-kms"
  description             = "KMS key for EC2 Image Builder AMI encryption"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = var.kms_enable_key_rotation

  tags = {
    Name = "${local.naming_construct}-imagebuilder-kms"
  }
}
