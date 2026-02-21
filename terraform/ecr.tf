module "ecr_backend" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-backend"
  image_count     = 10

  tags = {
    Name        = "${var.project_name}-backend"
    Project     = var.project_name
    Environment = var.environment
  }
}

module "ecr_frontend" {
  source = "./modules/ecr"

  repository_name = "${var.project_name}-frontend"
  image_count     = 10

  tags = {
    Name        = "${var.project_name}-frontend"
    Project     = var.project_name
    Environment = var.environment
  }
}
