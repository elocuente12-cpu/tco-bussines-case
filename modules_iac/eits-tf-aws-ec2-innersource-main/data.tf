### AMIs ###

data "aws_ami" "exp_win_2019" {
  count = var.ami == "windows_2019" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_windows_2019*"]
  }
}

data "aws_ami" "exp_win_2022" {
  count = var.ami == "windows_2022" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_windows_2022*"]
  }
}

data "aws_ami" "exp_win_2025" {
  count = var.ami == "windows_2025" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_windows_2025*"]
  }
}
data "aws_ami" "exp_amzn_lnx_2023" {
  count = var.ami == "amzn_lnx_2023" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_amzn_lnx_2023*"]
  }
}

data "aws_ami" "exp_eks_amzn_lnx_2023" {
  count = var.ami == "eks_amzn_lnx_2023" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_eks_amzn-lnx_2023*"]
  }
}

data "aws_ami" "exp_gpu_eks_amzn_lnx_2023" {
  count = var.ami == "gpu_eks_amzn_lnx_2023" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_gpu_nvidia_eks_amzn-lnx_2023*"]
  }
}

data "aws_ami" "exp_rhel_8" {
  count = var.ami == "rhel_8" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_rhel_8*"]
  }
}

data "aws_ami" "exp_rhel_9" {
  count = var.ami == "rhel_9" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_rhel_9*"]
  }
}

data "aws_ami" "exp_rhel_10" {
  count = var.ami == "rhel_10" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_rhel_10*"]
  }
}

data "aws_ami" "exp_sles_15" {
  count = var.ami == "sles_15" ? 1 : 0

  most_recent = true
  owners      = ["363353661606"]

  filter {
    name   = "name"
    values = ["eec_aws_sles_15*"]
  }
}

# get provider tags
data "aws_default_tags" "this" {}

### OTHER DATA SOURCES ###

# Get current region
data "aws_region" "current" {}

# Get subnet info to extract VPC ID and availability zone
data "aws_subnet" "this" {
  id = var.subnet
}

data "aws_availability_zone" "this" {
  region                 = data.aws_subnet.this.region
  name                   = data.aws_subnet.this.availability_zone
  all_availability_zones = true
}

