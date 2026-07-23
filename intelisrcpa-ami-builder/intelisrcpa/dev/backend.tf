terraform {
  backend "s3" {
    region         = "us-east-1"
    bucket         = "infrasplatam-terraform-779394371865"
    key            = "intelisrcpa/dev/ami-builder/terraform.tfstate"
    dynamodb_table = "infrasplatam-terraform-lock-779394371865"
  }
}
