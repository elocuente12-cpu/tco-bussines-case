terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "infrasplatam-terraform-274193347839"
    key            = "intelisrcpa/pro/ami-builder/terraform.tfstate"
    dynamodb_table = "infrasplatam-terraform-lock-274193347839"
  }
}
