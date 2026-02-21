locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  tags         = local.common_tags
}

module "alb" {
  source = "./modules/alb"

  project_name = var.project_name
  vpc_id       = data.aws_vpc.default.id
  subnet_ids   = data.aws_subnets.default.ids
  tags         = local.common_tags
}

module "cloudwatch_backend" {
  source = "./modules/cloudwatch"

  project_name = var.project_name
  service_name = "backend"
  cluster_name = module.ecs_backend.cluster_name
  tags         = local.common_tags
}

module "cloudwatch_frontend" {
  source = "./modules/cloudwatch"

  project_name = var.project_name
  service_name = "frontend"
  cluster_name = module.ecs_frontend.cluster_name
  tags         = local.common_tags
}

module "ecs_backend" {
  source = "./modules/ecs"

  project_name          = var.project_name
  service_name          = "backend"
  cpu                   = "256"
  memory                = "512"
  desired_count         = 1
  container_port        = 5000
  ecr_repository_url    = module.ecr_backend.repository_url
  execution_role_arn    = module.iam.ecs_execution_role_arn
  task_role_arn         = module.iam.ecs_task_role_arn
  vpc_id                = data.aws_vpc.default.id
  subnet_ids            = data.aws_subnets.default.ids
  target_group_arn      = module.alb.backend_target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  lb_listener_arn       = module.alb.backend_target_group_arn
  log_group_name        = module.cloudwatch_backend.log_group_name
  aws_region            = var.aws_region

  environment_variables = [
    { name = "NODE_ENV", value = "production" },
    { name = "PORT", value = "5000" }
  ]

  health_check = {
    command     = ["CMD-SHELL", "wget -q --spider http://localhost:5000/health || exit 1"]
    interval    = 30
    timeout     = 5
    retries     = 3
    startPeriod = 60
  }

  tags = local.common_tags
}

module "ecs_frontend" {
  source = "./modules/ecs"

  project_name          = var.project_name
  service_name          = "frontend"
  cpu                   = "256"
  memory                = "512"
  desired_count         = 1
  container_port        = 80
  ecr_repository_url    = module.ecr_frontend.repository_url
  execution_role_arn    = module.iam.ecs_execution_role_arn
  task_role_arn         = module.iam.ecs_task_role_arn
  vpc_id                = data.aws_vpc.default.id
  subnet_ids            = data.aws_subnets.default.ids
  target_group_arn      = module.alb.frontend_target_group_arn
  alb_security_group_id = module.alb.alb_security_group_id
  lb_listener_arn       = module.alb.frontend_target_group_arn
  log_group_name        = module.cloudwatch_frontend.log_group_name
  aws_region            = var.aws_region

  tags = local.common_tags
}
