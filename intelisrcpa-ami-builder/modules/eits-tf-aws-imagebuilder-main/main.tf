module "eits_ce_common" {
  source = "git::https://code.experian.local/scm/EUCES/eits-tf-aws-ce-common.git?ref=v1"

  module_repo = "eits-tf-aws-imagebuilder"
  tags        = var.tags
}

##############################################
# EC2 Image Builder - Components
# Each component uses AWSTOE YAML document format
# with phases: build, validate, test
# Reference: https://docs.aws.amazon.com/imagebuilder/latest/userguide/toe-use-documents.html
##############################################

resource "aws_imagebuilder_component" "build" {
  for_each = { for idx, comp in var.build_components : comp.name => comp }

  name        = "${local.full_name}-${each.value.name}"
  platform    = local.platform
  version     = each.value.version
  description = each.value.description

  # AWSTOE document: schemaVersion 1.0, phases: build
  data = each.value.data

  supported_os_versions = each.value.supported_os_versions

  tags = merge(var.tags, {
    Name = "${local.full_name}-${each.value.name}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_imagebuilder_component" "test" {
  for_each = { for idx, comp in var.test_components : comp.name => comp }

  name        = "${local.full_name}-test-${each.value.name}"
  platform    = local.platform
  version     = each.value.version
  description = each.value.description

  # AWSTOE document: schemaVersion 1.0, phases: test
  data = each.value.data

  supported_os_versions = each.value.supported_os_versions

  tags = merge(var.tags, {
    Name = "${local.full_name}-test-${each.value.name}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

##############################################
# EC2 Image Builder - Infrastructure Configuration
# Defines WHERE the build instance runs
##############################################

resource "aws_imagebuilder_infrastructure_configuration" "this" {
  name                          = "${local.full_name}-infra"
  description                   = "Infrastructure configuration for ${local.full_name}"
  instance_types                = var.instance_types
  instance_profile_name         = var.instance_profile_name
  subnet_id                     = var.subnet_id
  security_group_ids            = var.security_group_ids
  terminate_instance_on_failure = var.terminate_instance_on_failure
  key_pair                      = var.key_pair

  dynamic "instance_metadata_options" {
    for_each = var.instance_metadata_http_tokens != null ? [1] : []
    content {
      http_tokens = var.instance_metadata_http_tokens
      http_put_response_hop_limit = var.instance_metadata_http_put_response_hop_limit
    }
  }

  dynamic "logging" {
    for_each = var.s3_log_bucket != null ? [1] : []
    content {
      s3_logs {
        s3_bucket_name = var.s3_log_bucket
        s3_key_prefix  = var.s3_log_prefix != null ? var.s3_log_prefix : "imagebuilder/${local.full_name}"
      }
    }
  }

  resource_tags = var.resource_tags

  sns_topic_arn = var.sns_topic_arn

  tags = merge(var.tags, {
    Name = "${local.full_name}-infra"
  })
}

##############################################
# EC2 Image Builder - Image Recipe
# Defines WHAT the image will contain:
#   - Parent image (Golden AMI or AWS managed image ARN)
#   - Components (ordered build + test)
#   - Block device mappings
# Best practice: use versionless parent_image ARN
# for auto-update with EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE
##############################################

resource "aws_imagebuilder_image_recipe" "this" {
  name         = "${local.full_name}-recipe"
  parent_image = var.parent_image
  version      = var.recipe_version
  description  = "Image recipe for ${local.full_name}"

  # Block device mappings
  dynamic "block_device_mapping" {
    for_each = var.block_device_mappings
    content {
      device_name  = block_device_mapping.value.device_name
      no_device    = lookup(block_device_mapping.value, "no_device", null)
      virtual_name = lookup(block_device_mapping.value, "virtual_name", null)

      dynamic "ebs" {
        for_each = block_device_mapping.value.ebs != null ? [block_device_mapping.value.ebs] : []
        content {
          delete_on_termination = lookup(ebs.value, "delete_on_termination", true)
          encrypted             = lookup(ebs.value, "encrypted", true)
          kms_key_id            = lookup(ebs.value, "kms_key_id", null)
          volume_size           = lookup(ebs.value, "volume_size", 100)
          volume_type           = lookup(ebs.value, "volume_type", "gp3")
          iops                  = lookup(ebs.value, "iops", null)
          throughput            = lookup(ebs.value, "throughput", null)
        }
      }
    }
  }

  # Build components (order matters — executed sequentially)
  dynamic "component" {
    for_each = local.all_component_arns
    content {
      component_arn = component.value

      dynamic "parameter" {
        for_each = lookup(local.component_parameters, component.value, {})
        content {
          name  = parameter.key
          value = [parameter.value]
        }
      }
    }
  }

  # Systems Manager agent is installed by default on Windows/Linux
  systems_manager_agent {
    uninstall_after_build = var.uninstall_ssm_agent_after_build
  }

  tags = merge(var.tags, {
    Name = "${local.full_name}-recipe"
  })

  lifecycle {
    create_before_destroy = true
  }
}

##############################################
# EC2 Image Builder - Distribution Configuration
# Defines WHERE the output AMI is distributed:
#   - Regions
#   - Cross-account sharing (launch permissions)
#   - AMI naming and tagging
#   - Launch template configuration (optional)
##############################################

resource "aws_imagebuilder_distribution_configuration" "this" {
  name        = "${local.full_name}-distribution"
  description = "Distribution configuration for ${local.full_name}"

  # Primary distribution (build region)
  distribution {
    region = var.region

    ami_distribution_configuration {
      name        = "${local.full_name}-{{ imagebuilder:buildDate }}"
      description = "AMI built by EC2 Image Builder for ${local.full_name}"
      kms_key_id  = var.distribution_kms_key_id

      ami_tags = merge(var.tags, var.ami_tags, {
        Name        = local.full_name
        SourceImage = var.parent_image
        BuildDate   = "{{ imagebuilder:buildDate }}"
      })

      dynamic "launch_permission" {
        for_each = length(var.ami_share_account_ids) > 0 || length(var.ami_share_org_arns) > 0 ? [1] : []
        content {
          user_ids         = length(var.ami_share_account_ids) > 0 ? var.ami_share_account_ids : null
          organization_arns = length(var.ami_share_org_arns) > 0 ? var.ami_share_org_arns : null
        }
      }
    }

    dynamic "launch_template_configuration" {
      for_each = var.launch_template_id != null ? [1] : []
      content {
        launch_template_id = var.launch_template_id
        default            = true
      }
    }
  }

  # Additional region distributions
  dynamic "distribution" {
    for_each = var.additional_distribution_regions
    content {
      region = distribution.value.region

      ami_distribution_configuration {
        name        = "${local.full_name}-${distribution.value.region}-{{ imagebuilder:buildDate }}"
        description = "AMI distributed to ${distribution.value.region}"
        kms_key_id  = lookup(distribution.value, "kms_key_id", null)

        ami_tags = merge(var.tags, var.ami_tags, {
          Name        = local.full_name
          SourceImage = var.parent_image
          BuildDate   = "{{ imagebuilder:buildDate }}"
        })

        dynamic "launch_permission" {
          for_each = length(var.ami_share_account_ids) > 0 ? [1] : []
          content {
            user_ids = var.ami_share_account_ids
          }
        }
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${local.full_name}-distribution"
  })
}

##############################################
# EC2 Image Builder - Image Pipeline
# Best practice: EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE
# ensures pipeline only builds when parent image or components update
##############################################

resource "aws_imagebuilder_image_pipeline" "this" {
  name                             = "${local.full_name}-pipeline"
  description                      = "Image pipeline for ${local.full_name}"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.this.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.this.arn
  distribution_configuration_arn   = aws_imagebuilder_distribution_configuration.this.arn
  status                           = var.pipeline_status
  enhanced_image_metadata_enabled  = var.enhanced_image_metadata_enabled

  image_tests_configuration {
    image_tests_enabled = var.image_tests_enabled
    timeout_minutes     = var.image_tests_timeout_minutes
  }

  dynamic "schedule" {
    for_each = var.schedule_expression != null ? [1] : []
    content {
      schedule_expression                = var.schedule_expression
      pipeline_execution_start_condition = var.pipeline_execution_start_condition
      timezone                           = var.schedule_timezone
    }
  }

  image_scanning_configuration {
    image_scanning_enabled = var.image_scanning_enabled

    dynamic "ecr_configuration" {
      for_each = var.image_scanning_enabled && var.ecr_repository_name != null ? [1] : []
      content {
        repository_name = var.ecr_repository_name
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${local.full_name}-pipeline"
  })

  depends_on = [
    aws_imagebuilder_component.build,
    aws_imagebuilder_component.test,
  ]
}
