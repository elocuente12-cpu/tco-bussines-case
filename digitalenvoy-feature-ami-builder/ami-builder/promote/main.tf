//module "global_variables" {
//  source = "../../modules/variables"
//}

//module "local_variables" {
//  source = "../modules/variables"
//
//  team   = module.global_variables.team
//  region = module.global_variables.region
//}

resource "aws_ami_launch_permission" "example" {
  image_id   = var.image_id
  account_id = var.destination_account_id
}

