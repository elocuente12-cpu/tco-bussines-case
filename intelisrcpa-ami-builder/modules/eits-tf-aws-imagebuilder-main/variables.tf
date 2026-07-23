############################
# General
############################

variable "name_prefix" {
  type        = string
  description = "Prefix for resource naming (e.g. eec-aws-us-eits-intelisrcpa)."
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. dev, tst, uat, prd)."
}

variable "identifier" {
  type        = string
  description = "Image Builder pipeline identifier suffix (e.g. windows-iis, linux-nginx). Full name: {name_prefix}-{environment}-imagebuilder-{identifier}"
}

variable "region" {
  type        = string
  description = "AWS region for the primary distribution."
  default     = "us-east-1"
}

variable "os_family" {
  type        = string
  description = "Operating system family: 'windows' or 'linux'. Determines platform for components."
  default     = "windows"

  validation {
    condition     = contains(["windows", "linux"], var.os_family)
    error_message = "os_family must be 'windows' or 'linux'."
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags for all AWS resources created by this module."
}

############################
# Infrastructure Configuration
############################

variable "instance_types" {
  type        = list(string)
  description = "Instance types for the Image Builder build instance. First available will be used."
  default     = ["m5.large"]
}

variable "instance_profile_name" {
  type        = string
  description = "IAM instance profile name for the build instance. Must have EC2InstanceProfileForImageBuilder and AmazonSSMManagedInstanceCore policies."
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the build instance will be launched. Must have internet access (NAT or IGW) for component downloads."
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security group IDs to attach to the build instance. Recommend: egress-only SG."
}

variable "terminate_instance_on_failure" {
  type        = bool
  description = "Whether to terminate the build instance on failure. Set to false for debugging."
  default     = true
}

variable "key_pair" {
  type        = string
  description = "EC2 key pair for SSH/RDP access to the build instance (for debugging). Null disables."
  default     = null
}

variable "instance_metadata_http_tokens" {
  type        = string
  description = "IMDSv2 enforcement: 'required' (recommended) or 'optional'. Null uses default."
  default     = "required"

  validation {
    condition     = var.instance_metadata_http_tokens == null || contains(["required", "optional"], var.instance_metadata_http_tokens)
    error_message = "instance_metadata_http_tokens must be 'required', 'optional', or null."
  }
}

variable "instance_metadata_http_put_response_hop_limit" {
  type        = number
  description = "HTTP PUT response hop limit for IMDSv2."
  default     = 1
}

variable "s3_log_bucket" {
  type        = string
  description = "S3 bucket name for Image Builder build logs. Null disables S3 logging."
  default     = null
}

variable "s3_log_prefix" {
  type        = string
  description = "S3 key prefix for logs. Defaults to 'imagebuilder/{full_name}' if null."
  default     = null
}

variable "resource_tags" {
  type        = map(string)
  description = "Tags to apply to resources created during the build (build instance, volumes). Separate from module tags."
  default     = null
}

variable "sns_topic_arn" {
  type        = string
  description = "SNS topic ARN for pipeline notifications (build started, succeeded, failed). Null disables."
  default     = null
}

############################
# Image Recipe
############################

variable "parent_image" {
  type        = string
  description = <<-EOT
    Parent image for the recipe. Accepts:
    - AMI ID: ami-0123456789abcdef0
    - Image Builder managed image ARN (versionless recommended for auto-updates):
      arn:aws:imagebuilder:us-east-1:aws:image/windows-server-2022-english-full-base-x86/x.x.x
    Best practice: use versionless ARN with EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE.
  EOT
}

variable "recipe_version" {
  type        = string
  description = "Semantic version of the image recipe (e.g. 1.0.0). Increment when changing components or parent image."
  default     = "1.0.0"
}

variable "block_device_mappings" {
  type = list(object({
    device_name  = string
    no_device    = optional(bool)
    virtual_name = optional(string)
    ebs = optional(object({
      delete_on_termination = optional(bool, true)
      encrypted             = optional(bool, true)
      kms_key_id            = optional(string)
      volume_size           = optional(number, 100)
      volume_type           = optional(string, "gp3")
      iops                  = optional(number)
      throughput            = optional(number)
    }))
  }))
  description = "Block device mappings for the image recipe. Defines volumes on the output AMI."
  default = [
    {
      device_name = "/dev/sda1"
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 100
        volume_type           = "gp3"
      }
    }
  ]
}

variable "uninstall_ssm_agent_after_build" {
  type        = bool
  description = "Whether to uninstall the SSM agent after the build completes. Typically false for Windows."
  default     = false
}

############################
# Components - Build
############################

variable "build_components" {
  type = list(object({
    name                  = string
    description           = optional(string, "")
    version               = optional(string, "1.0.0")
    data                  = string  # AWSTOE YAML document content
    supported_os_versions = optional(list(string))
    parameters            = optional(map(string), {})
  }))
  description = <<-EOT
    Build components to create and include in the recipe.
    Each component is an AWSTOE YAML document with phases: build, validate.
    'data' must be a valid AWSTOE document (schemaVersion: 1.0, phases with steps).
    Components execute in the order defined here.
  EOT
  default = []
}

variable "external_component_arns" {
  type        = list(string)
  description = <<-EOT
    Pre-existing component ARNs to include in the recipe (e.g. AWS managed components).
    These are appended after build_components and before test_components.
    Example: ["arn:aws:imagebuilder:us-east-1:aws:component/amazon-cloudwatch-agent-windows/1.0.1/1"]
  EOT
  default = []
}

variable "external_component_parameters" {
  type        = map(map(string))
  description = "Parameters for external components. Map of component_arn => { param_name => param_value }."
  default     = {}
}

############################
# Components - Test
############################

variable "test_components" {
  type = list(object({
    name                  = string
    description           = optional(string, "")
    version               = optional(string, "1.0.0")
    data                  = string  # AWSTOE YAML document with phase: test
    supported_os_versions = optional(list(string))
  }))
  description = <<-EOT
    Test components to validate the image after snapshot.
    Each component is an AWSTOE YAML document with phase: test.
    Image Builder only distributes if all tests pass.
  EOT
  default = []
}

############################
# Distribution Configuration
############################

variable "ami_tags" {
  type        = map(string)
  description = "Additional tags to apply to the output AMI (merged with module tags)."
  default     = {}
}

variable "ami_share_account_ids" {
  type        = list(string)
  description = "List of AWS account IDs to share the output AMI with via launch permissions."
  default     = []
}

variable "ami_share_org_arns" {
  type        = list(string)
  description = "List of AWS Organization ARNs to share the output AMI with."
  default     = []
}

variable "distribution_kms_key_id" {
  type        = string
  description = "KMS key ID/ARN for encrypting the distributed AMI. Null uses default EBS encryption."
  default     = null
}

variable "launch_template_id" {
  type        = string
  description = "Launch template ID to associate with the distributed AMI. Null disables."
  default     = null
}

variable "additional_distribution_regions" {
  type = list(object({
    region     = string
    kms_key_id = optional(string)
  }))
  description = "Additional regions to distribute the AMI to (beyond the build region)."
  default     = []
}

############################
# Pipeline Configuration
############################

variable "pipeline_status" {
  type        = string
  description = "Status of the pipeline: ENABLED or DISABLED."
  default     = "ENABLED"

  validation {
    condition     = contains(["ENABLED", "DISABLED"], var.pipeline_status)
    error_message = "pipeline_status must be ENABLED or DISABLED."
  }
}

variable "enhanced_image_metadata_enabled" {
  type        = bool
  description = "Enable enhanced image metadata collection (recommended)."
  default     = true
}

variable "image_tests_enabled" {
  type        = bool
  description = "Whether to run image tests after building. Best practice: always true."
  default     = true
}

variable "image_tests_timeout_minutes" {
  type        = number
  description = "Timeout in minutes for image tests (max 1440 = 24h)."
  default     = 60
}

variable "schedule_expression" {
  type        = string
  description = "Cron or rate expression for pipeline schedule. Null = manual execution only. Example: 'cron(0 3 ? * SUN *)'."
  default     = null
}

variable "pipeline_execution_start_condition" {
  type        = string
  description = <<-EOT
    When to execute the pipeline:
    - EXPRESSION_MATCH_ONLY: always run on schedule
    - EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE: only when parent image or components have updates (recommended)
  EOT
  default = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"

  validation {
    condition = contains([
      "EXPRESSION_MATCH_ONLY",
      "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
    ], var.pipeline_execution_start_condition)
    error_message = "Must be EXPRESSION_MATCH_ONLY or EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE."
  }
}

variable "schedule_timezone" {
  type        = string
  description = "IANA timezone for the schedule (e.g. 'America/Panama', 'UTC')."
  default     = "UTC"
}

############################
# Image Scanning (Inspector)
############################

variable "image_scanning_enabled" {
  type        = bool
  description = "Enable Amazon Inspector vulnerability scanning on the output image."
  default     = false
}

variable "ecr_repository_name" {
  type        = string
  description = "ECR repository name for container vulnerability scanning results. Only for container images."
  default     = null
}
