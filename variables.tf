variable "ami_id" {
  description = "AMI ID for the EC2 instance (Ubuntu 26.04 in us-east-1)"
  type        = string
  default     = "ami-0a2b6680ef4ed0596"
}

variable "managed_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.medium"
}

variable "control_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of the SSH key pair (must already exist in AWS)"
  type        = string
}
