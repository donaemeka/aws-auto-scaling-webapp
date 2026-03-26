# AWS Region - where all resources will be created
variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}
variable "ami_id" {
  description = "AMI ID for EC2 instances (Ubuntu 24.04 in eu-west-2)"
  type        = string
  default     = "ami-09dbc7ce74870d573"
}
# VPC IP range - the address space for your entire network
variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

# Availability Zones - the data centers to use (need 3 for high availability)
variable "availability_zones" {
  description = "List of Availability Zones"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

# Public Subnets - where the Load Balancer sits (one per AZ)
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

# Private Subnets - where your EC2 instances sit (one per AZ)
variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# EC2 Instance Type - size of your web servers
variable "instance_type" {
  description = "EC2 instance type for web servers"
  type        = string
  default     = "t3.micro"
}

# Your IP Address - for SSH access (only you can connect)
variable "ssh_allowed_ip" {
  description = "Your public IP address for SSH access (with /32)"
  type        = string
  sensitive   = true
  # No default - user MUST provide their own IP
}

# SSH Key Pair Name - the key you created in AWS Console
variable "key_name" {
  description = "Name of existing EC2 key pair for SSH access"
  type        = string
  sensitive   = true
  # No default - user MUST provide their key name
}

# Environment Tag - helps identify resources (dev, prod, etc.)
variable "environment" {
  description = "Environment tag (dev, staging, prod)"
  type        = string
  default     = "dev"
}
variable "bastion_instance_type" {
  description = "Instance type for bastion host"
  type        = string
  default     = "t3.micro"
}