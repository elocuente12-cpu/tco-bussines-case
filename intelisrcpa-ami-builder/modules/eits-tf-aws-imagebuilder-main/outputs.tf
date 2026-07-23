output "pipeline_arn" {
  description = "The ARN of the Image Builder pipeline. Use this to trigger builds via AWS CLI or Jenkins."
  value       = aws_imagebuilder_image_pipeline.this.arn
}

output "pipeline_name" {
  description = "The name of the Image Builder pipeline."
  value       = aws_imagebuilder_image_pipeline.this.name
}

output "recipe_arn" {
  description = "The ARN of the Image Builder image recipe."
  value       = aws_imagebuilder_image_recipe.this.arn
}

output "infrastructure_configuration_arn" {
  description = "The ARN of the infrastructure configuration."
  value       = aws_imagebuilder_infrastructure_configuration.this.arn
}

output "distribution_configuration_arn" {
  description = "The ARN of the distribution configuration."
  value       = aws_imagebuilder_distribution_configuration.this.arn
}

output "build_component_arns" {
  description = "Map of build component name => ARN."
  value       = { for name, comp in aws_imagebuilder_component.build : name => comp.arn }
}

output "test_component_arns" {
  description = "Map of test component name => ARN."
  value       = { for name, comp in aws_imagebuilder_component.test : name => comp.arn }
}
