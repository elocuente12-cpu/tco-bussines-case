locals {
  # Full resource name: {name_prefix}-{environment}-imagebuilder-{identifier}
  full_name = "${var.name_prefix}-${var.environment}-imagebuilder-${var.identifier}"

  # Platform derivation from OS family (used for components)
  platform = var.os_family == "windows" ? "Windows" : "Linux"

  # Merge all component ARNs in order:
  # 1. Custom build components (created by this module)
  # 2. External component ARNs (pre-existing, e.g. AWS managed)
  # 3. Custom test components (created by this module)
  build_component_arns = [for name, comp in aws_imagebuilder_component.build : comp.arn]
  test_component_arns  = [for name, comp in aws_imagebuilder_component.test : comp.arn]

  all_component_arns = concat(
    local.build_component_arns,
    var.external_component_arns,
    local.test_component_arns
  )

  # Component parameters map: component_arn => { param_name => param_value }
  component_parameters = merge(
    { for name, comp in aws_imagebuilder_component.build :
      comp.arn => lookup(
        { for c in var.build_components : c.name => c.parameters }[name],
        name, {}
      )
    },
    var.external_component_parameters
  )
}
