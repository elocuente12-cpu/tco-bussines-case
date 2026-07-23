##############################################
# General
# NOTA: assume_role_arn y assume_role_external_id los
# inyecta el pipeline (Jenkins), no se definen aqui.
##############################################
environment   = "dev"
prefix        = "aws-latam"
app_name      = "intelisrcpa"
ResourceOwner = "Fernando Hidalgo"
appId         = "22272"
costString    = "1850.PA.135.601000"
tagenv        = "dev"

##############################################
# Image Builder
##############################################
imagebuilder_identifier = "windows-iis"
parent_image_ami        = "ami-08552a347fc5fd803" # eec_aws_windows_2025
recipe_version          = "1.0.0"
instance_types          = ["m5.large"]
root_volume_size        = 100
s3_log_bucket           = "infrasplatam-terraform-779394371865"

# Cada ambiente construye su propia AMI, no se comparte entre cuentas
ami_share_account_ids = []
