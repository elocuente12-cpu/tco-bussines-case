variable "server" {
  description = "Server name for example cronscripts"
  type        = string
  default     = "digital-envoy"
}

variable "instance_types" {
  type = map(list(string))
  description = "list of instance types"
  default = {
    stage      = ["t3.large", "t3a.large", "t2.large"]
    stage_west = ["t3.large", "t3a.large", "t2.large"]
    uat        = ["t3.micro"]
    uat_west   = ["t3.micro"]
    prod       = ["t3.micro"]
    prod_west  = ["t3.micro"]
  }
}

variable "volume_size" {
  type = map(string)
  description = "list of instance types"
  default = {
    stage      = "40"
    stage_west = "40"
    uat        = "10"
    uat_west   = "10"
    prod       = "10"
    prod_west  = "10"
  }
}

variable "root_volume_size" {
  type = map(string)
  description = "root volume size for the AMI build instance"
  default = {
    stage      = "50"
    stage_west = "50"
    uat        = "50"
    uat_west   = "50"
    prod       = "50"
    prod_west  = "50"
  }
}

variable "imageBuilderComponents" {
  type = list(any)
  description = "Components used for the image builder pipeline"
  default = []
}

variable "min_size" {
  description = "Minimum number of instance should run all the time"
  type = map(string)
  default = {
    stage      = "1"
    stage_west = "1"
    uat        = "1"
    uat_west   = "1"
    prod       = "1"
    prod_west  = "1"
  }
}

variable "max_size" {
  description = "Maximum number of instance that ASG can launch"
  type = map(string)
  default = {
    stage      = "3"
    stage_west = "3"
    uat        = "3"
    uat_west   = "3"
    prod       = "3"
    prod_west  = "3"
  }
}

variable "desired_capacity" {
  description = "Initial capacity of the Auto Scaling group at the time of creation"
  type = map(string)
  default = {
    stage      = "1"
    stage_west = "1"
    uat        = "1"
    uat_west   = "1"
    prod       = "1"
    prod_west  = "1"
  }
}

variable "cpu_target_value" {
  description = "Target value at which ASG group will launch new/Additinal instance"
  type = map(string)
  default = {
    stage      = "80.0"
    stage_west = "80.0"
    uat        = "80.0"
    uat_west   = "80.0"
    prod       = "80.0"
    prod_west  = "80.0"
  }
}

variable "asg_instance_name" {
  description = "Name of instance launched by ASG, this will be prepended with the team name and have the environment as suffix"
  type = string
  default = "instance"
}

variable "user_data_path" {
  description = "Path to user data file"
  type = map(string)
  default = {
    stage      = "user-data.sh"
    stage_west = "user-data.sh"
    uat        = "user-data.sh"
    uat_west   = "user-data.sh"
    prod       = "user-data.sh"
    prod_west  = "user-data.sh"
  }
}
