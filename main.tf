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

# Security Group for the control node: SSH access from your laptop
resource "aws_security_group" "control" {
  name        = "minecraft-control-sg"
  description = "Control node: SSH only"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
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
    Name = "minecraft-control-sg"
  }
}

# Security Group for the managed node: SSH from control node only, HTTP from anywhere
resource "aws_security_group" "managed" {
  name        = "minecraft-managed-sg"
  description = "Managed node: SSH from control node, HTTP from anywhere"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description     = "SSH from control node"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.control.id]
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

# Control node: you SSH into this instance from your laptop
resource "aws_instance" "control" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.control.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = "minecraft-control"
  }
}

# Managed node: the server that will run the application
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
