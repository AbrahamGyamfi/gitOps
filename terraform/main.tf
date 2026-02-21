locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

module "security_group" {
  source = "./modules/ec2"

  instance_name              = "placeholder"
  instance_type              = "t2.micro"
  key_name                   = var.key_name
  security_group_id          = ""
  role                       = "placeholder"
  security_group_name        = "${var.project_name}-sg"
  security_group_description = "Security group for TaskFlow application"
  vpc_id                     = data.aws_vpc.default.id

  ingress_rules = [
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allowed_ssh_cidr]
    },
    {
      description = "HTTP"
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Jenkins"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      description = "Backend API"
      from_port   = 5000
      to_port     = 5000
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]

  tags = local.common_tags
}

module "jenkins" {
  source = "./modules/ec2"

  instance_name              = "${var.project_name}-jenkins-server"
  instance_type              = var.jenkins_instance_type
  key_name                   = var.key_name
  security_group_id          = module.security_group.security_group_id
  user_data_file             = "${path.module}/../jenkins-userdata.sh"
  role                       = "jenkins"
  security_group_name        = "unused"
  security_group_description = "unused"
  vpc_id                     = data.aws_vpc.default.id
  ingress_rules              = []
  tags                       = local.common_tags
}

module "app" {
  source = "./modules/ec2"

  instance_name              = "${var.project_name}-app-server"
  instance_type              = var.app_instance_type
  key_name                   = var.key_name
  security_group_id          = module.security_group.security_group_id
  user_data_file             = "${path.module}/../app-userdata.sh"
  role                       = "application"
  security_group_name        = "unused"
  security_group_description = "unused"
  vpc_id                     = data.aws_vpc.default.id
  ingress_rules              = []
  tags                       = local.common_tags
}

module "iam" {
  source = "./modules/iam"

  project_name = var.project_name
  tags         = local.common_tags
}

module "ecr_backend" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-backend"
  image_count     = 10
  tags            = local.common_tags
}

module "ecr_frontend" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-frontend"
  image_count     = 10
  tags            = local.common_tags
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

  environment_variables = [
    { name = "BACKEND_HOST", value = module.alb.alb_dns_name }
  ]

  tags = local.common_tags
}
