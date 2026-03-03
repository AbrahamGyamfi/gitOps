terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  security_group_name = "taskflow-sg"
  key_name            = var.key_name
  public_key_path     = var.public_key_path
  admin_cidr_blocks   = var.admin_cidr_blocks
}

module "security" {
  source = "./modules/security"

  cloudtrail_bucket_name = var.cloudtrail_bucket_name
  aws_account_id         = var.aws_account_id
  ssh_private_key        = file(var.private_key_path)
}

module "compute" {
  source = "./modules/compute"

  jenkins_instance_type        = var.jenkins_instance_type
  app_instance_type            = var.app_instance_type
  key_name                     = module.networking.key_name
  security_group_name          = module.networking.security_group_name
  app_iam_instance_profile     = module.security.iam_instance_profile
  jenkins_iam_instance_profile = module.security.jenkins_instance_profile
}

module "monitoring" {
  source = "./modules/monitoring"

  ami_id               = module.compute.ami_id
  key_name             = module.networking.key_name
  security_group_name  = module.networking.security_group_name
  iam_instance_profile = module.security.iam_instance_profile
  aws_region           = var.aws_region
  app_public_ip        = ""  # Not used - app runs on ECS Fargate
  app_private_ip       = ""  # Not used - app runs on ECS Fargate
  private_key_path     = var.private_key_path
}

module "ecs" {
  source = "./modules/ecs"

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  security_group_id        = module.networking.security_group_id
  target_group_arn         = module.codedeploy.blue_target_group_arn
  backend_target_group_arn = module.codedeploy.backend_blue_target_group_arn
  monitoring_host          = module.monitoring.monitoring_private_ip
  aws_account_id           = var.aws_account_id
}

module "codedeploy" {
  source = "./modules/codedeploy"

  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  security_group_id        = module.networking.security_group_id
  aws_account_id           = var.aws_account_id
  ecs_cluster_name         = module.ecs.cluster_name
  ecs_service_name         = module.ecs.frontend_service_name
  ecs_backend_service_name = module.ecs.backend_service_name
}
