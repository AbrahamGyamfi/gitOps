# ── Service Discovery (Cloud Map) ─────────────────────────────────────────────
# Private DNS namespace: taskflow.local
resource "aws_service_discovery_private_dns_namespace" "taskflow" {
  name        = "taskflow.local"
  description = "Private DNS namespace for TaskFlow ECS services"
  vpc         = var.vpc_id

  tags = {
    Name    = "taskflow-namespace"
    Project = "TaskFlow"
  }
}

# Service registry entry for backend → resolves as taskflow-backend.taskflow.local
resource "aws_service_discovery_service" "backend" {
  name = "taskflow-backend"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.taskflow.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name    = "taskflow-backend-sd"
    Project = "TaskFlow"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/ecs/taskflow-backend"
  retention_in_days = 30

  tags = {
    Name    = "taskflow-backend-logs"
    Project = "TaskFlow"
  }
}

resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/ecs/taskflow-frontend"
  retention_in_days = 30

  tags = {
    Name    = "taskflow-frontend-logs"
    Project = "TaskFlow"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "taskflow-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name    = "taskflow-cluster"
    Project = "TaskFlow"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_execution" {
  name = "taskflow-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "taskflow-ecs-execution-role"
    Project = "TaskFlow"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Role for ECS Tasks (runtime)
resource "aws_iam_role" "ecs_task" {
  name = "taskflow-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name    = "taskflow-ecs-task-role"
    Project = "TaskFlow"
  }
}

# Backend Task Definition
resource "aws_ecs_task_definition" "backend" {
  family                   = "taskflow-backend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "taskflow-backend"
    image = "${var.aws_account_id}.dkr.ecr.eu-west-1.amazonaws.com/taskflow-backend:latest"
    portMappings = [{
      containerPort = 5000
      protocol      = "tcp"
    }]
    environment = [
      {
        name  = "NODE_ENV"
        value = "production"
      },
      {
        name  = "PORT"
        value = "5000"
      },
      {
        name  = "OTEL_SERVICE_NAME"
        value = "taskflow-backend"
      },
      {
        name  = "OTEL_EXPORTER_OTLP_ENDPOINT"
        value = "http://${var.monitoring_host}:4318"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.backend.name
        "awslogs-region"        = "eu-west-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name    = "taskflow-backend-task"
    Project = "TaskFlow"
  }
}

# Frontend Task Definition
resource "aws_ecs_task_definition" "frontend" {
  family                   = "taskflow-frontend"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "taskflow-frontend"
    image = "${var.aws_account_id}.dkr.ecr.eu-west-1.amazonaws.com/taskflow-frontend:latest"
    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]
    environment = [
      {
        name  = "BACKEND_URL"
        value = "http://taskflow-backend.taskflow.local:5000"
      }
    ]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.frontend.name
        "awslogs-region"        = "eu-west-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = {
    Name    = "taskflow-frontend-task"
    Project = "TaskFlow"
  }
}

# Backend ECS Service (internal, deployed via standard ECS rolling update)
resource "aws_ecs_service" "backend" {
  name            = "taskflow-backend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.backend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  # Also register with Cloud Map — frontend reaches backend internally via
  # taskflow-backend.taskflow.local:5000 (faster than going through ALB)
  service_registries {
    registry_arn = aws_service_discovery_service.backend.arn
  }

  load_balancer {
    target_group_arn = var.backend_target_group_arn
    container_name   = "taskflow-backend"
    container_port   = 5000
  }

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }

  tags = {
    Name    = "taskflow-backend-service"
    Project = "TaskFlow"
  }
}

# Frontend ECS Service (blue/green deployment via CodeDeploy + ALB)
resource "aws_ecs_service" "frontend" {
  name            = "taskflow-frontend"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.frontend.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = true
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "taskflow-frontend"
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }

  tags = {
    Name    = "taskflow-frontend-service"
    Project = "TaskFlow"
  }
}
