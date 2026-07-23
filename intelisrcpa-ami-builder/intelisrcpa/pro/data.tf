data "aws_caller_identity" "current" {}

data "aws_subnets" "private" {
  filter {
    name   = "tag:Name"
    values = ["*PrivateSubnet*"]
  }
}
