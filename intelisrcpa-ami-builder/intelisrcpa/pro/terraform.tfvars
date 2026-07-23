##############################################
# General
##############################################
environment   = "prd"
prefix        = "aws-latam"
app_name      = "intelisrcpa"
ResourceOwner = "Fernando Hidalgo"
appId         = "22272"
costString    = "1850.PA.135.601000"
tagenv        = "prd"

##############################################
# Image Builder
##############################################
imagebuilder_identifier = "windows-iis"
parent_image_ami        = "ami-08552a347fc5fd803" # eec_aws_windows_2025
recipe_version          = "1.0.0"
instance_types          = ["m5.large"]
root_volume_size        = 100
s3_log_bucket           = "infrasplatam-terraform-274193347839"

# Pro no necesita compartir AMI (es el destino final)
ami_share_account_ids = []
