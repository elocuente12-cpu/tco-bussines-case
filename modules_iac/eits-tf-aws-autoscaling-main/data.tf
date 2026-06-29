# EEC AMIs
data "aws_ami" "exp_win_2019_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_windows_2019*"]
  }
}

data "aws_ami" "exp_win_2022_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_windows_2022*"]
  }
}

data "aws_ami" "exp_amzn_lnx_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_amzn-lnx*"]
  }
}

data "aws_ami" "exp_amzn_lnx_2023_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_amzn_lnx_2023*"]
  }
}

data "aws_ami" "exp_amzn_eks_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_eks_amzn-lnx*"]
  }
}

data "aws_ami" "exp_rhel_8_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_rhel_8*"]
  }
}

data "aws_ami" "exp_rhel_9_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_rhel_9*"]
  }
}

data "aws_ami" "exp_sles_15_ami" {
  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_sles_15*"]
  }
}

# get chosen ami data
data "aws_ami" "current" {
  count = local.ami_id != null ? 1 : 0

  filter {
    name   = "image-id"
    values = [local.ami_id]
  }
}

# get default tags from provider, as asg doesnt get them automatically
data "aws_default_tags" "current" {}
