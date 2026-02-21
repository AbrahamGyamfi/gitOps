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
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.jenkins_instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.taskflow.id]
  user_data              = file("${path.module}/../jenkins-userdata.sh")

  tags = {
    Name        = "${var.project_name}-jenkins-server"
    Project     = var.project_name
    Environment = var.environment
    Role        = "jenkins"
  }
}

resource "aws_instance" "app" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = var.app_instance_type
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.taskflow.id]
  user_data              = file("${path.module}/../app-userdata.sh")

  tags = {
    Name        = "${var.project_name}-app-server"
    Project     = var.project_name
    Environment = var.environment
    Role        = "application"
  }
}
