terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Use the default aws credentials
provider "aws" {
  region = "us-east-1"
}

# Use the default VPC instead of creating a new one
data "aws_vpc" "default" {
  default = true
}

# Security Group for the managed node
resource "aws_security_group" "managed" {
  name        = "minecraft-managed-sg"
  description = "Managed node: SSH from control node, HTTP from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "SSH from control node"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    cidr_blocks     = ["${var.my_ip}/32"]
  }

  ingress {
    description = "minecraft"
    from_port   = 25565
    to_port     = 25565
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "minecraft RCON"
    from_port   = 25575
    to_port     = 25575
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "minecraft-managed-sg"
  }
}

resource "aws_instance" "managed" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.managed.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = "minecraft-managed"
  }
}

# ECR repository for the CI/CD pipeline
resource "aws_ecr_repository" "minecraft" {
  name                 = "minecraft-ecr"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = false
  }
}

resource "null_resource" "configure" {
  depends_on = [aws_instance.managed, local_file.inventory]

  provisioner "local-exec" {
    command = <<-EOF
      sleep 30 && \
      ANSIBLE_HOST_KEY_CHECKING=False \
      ansible-playbook -i inventory configure.yml \
      --private-key ~/.ssh/minecraft-key.pem
      --extra-vars "image_tag=${var.image_tag}"
    EOF
  }

  triggers = {
    managed_id = aws_instance.managed.id
    image_tag  = var.image_tag
  }
}

resource "local_file" "inventory" {
  content = <<-EOF
    [minecraft_group]
    minecraft ansible_host=${aws_instance.managed.public_ip} \
    ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/minecraft-key.pem
  EOF
  filename = "inventory"
}
