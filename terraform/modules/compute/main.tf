data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "jenkins" {
  ami                  = data.aws_ami.amazon_linux_2.id
  instance_type        = var.jenkins_instance_type
  key_name             = var.key_name
  security_groups      = [var.security_group_name]
  iam_instance_profile = var.jenkins_iam_instance_profile
  user_data            = file("${path.root}/../userdata/jenkins-userdata.sh")

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  tags = {
    Name        = "TaskFlow-Jenkins-Server"
    Project     = "TaskFlow"
    Environment = "Production"
  }
}

# App instance removed - using ECS Fargate instead
# resource "aws_instance" "app" {
#   ami                  = data.aws_ami.amazon_linux_2.id
#   instance_type        = var.app_instance_type
#   key_name             = var.key_name
#   security_groups      = [var.security_group_name]
#   iam_instance_profile = var.app_iam_instance_profile
#   user_data            = file("${path.root}/../userdata/app-userdata.sh")
#
#   tags = {
#     Name        = "TaskFlow-App-Server"
#     Project     = "TaskFlow"
#     Environment = "Production"
#   }
# }
