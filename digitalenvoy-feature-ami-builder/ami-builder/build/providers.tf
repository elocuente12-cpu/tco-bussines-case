terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.24"
    }
  }
}

# Default provider - inherits region from module.local_variables
provider "aws" {
  region = module.local_variables.region
  default_tags {
    tags = module.local_variables.common_tags
  }
}

# East provider - always us-east-1 (for primary KMS key, regardless of active workspace)
provider "aws" {
  alias  = "east"
  region = "us-east-1"
  default_tags {
    tags = module.local_variables.common_tags
  }
}

# West provider - always us-west-2 (for KMS replica and west resources)
provider "aws" {
  alias  = "west"
  region = "us-west-2"
  default_tags {
    tags = module.local_variables.common_tags
  }
}

