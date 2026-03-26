# ============================================
# TERRAFORM CONFIGURATION
# ============================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.29.0"  # AWS provider version - using latest stable
    }
  }
}

# Configure AWS Provider with region from variables
provider "aws" {
  region = var.aws_region
}

# ============================================
# NETWORKING - VPC & SUBNETS
# ============================================
# Creates VPC with public and private subnets across 3 Availability Zones
# NAT Gateway enables private instances to access internet for updates
# Public subnets host ALB, Private subnets host EC2 instances

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "dona-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs  # EC2 instances (no direct internet)
  public_subnets  = var.public_subnet_cidrs   # ALB and NAT Gateway

  enable_nat_gateway = true      # Allow private instances to reach internet
  single_nat_gateway = true      # Cost optimization - use one NAT gateway
  enable_vpn_gateway = false
  
  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

# ============================================
# SECURITY GROUPS - ALB
# ============================================
# Controls traffic to/from Application Load Balancer

resource "aws_security_group" "alb_sg" {
  name        = "alb_sg"
  description = "alb_sg inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "alb_sg"
  }
}

# Allow HTTP traffic from anywhere (internet)
resource "aws_vpc_security_group_ingress_rule" "alb_sg_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"  # Allow all IPv4 internet traffic
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}

# Allow all outbound traffic from ALB
resource "aws_vpc_security_group_egress_rule" "alb_sg_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"  # All protocols
}

# Allow all IPv6 outbound traffic
resource "aws_vpc_security_group_egress_rule" "alb_sg_ipv6" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv6         = "::/0"
  ip_protocol       = "-1"
}

# ============================================
# SECURITY GROUPS - EC2 Instances
# ============================================
# Controls traffic to/from web servers

resource "aws_security_group" "ec2_sg" {
  name        = "ec2_sg"
  description = "ec2_sg inbound traffic and all outbound traffic"
  vpc_id      = module.vpc.vpc_id

  tags = {
    Name = "ec2_sg"
  }
}

# Allow HTTP traffic ONLY from ALB (not directly from internet)
resource "aws_vpc_security_group_ingress_rule" "ec2_sg_http" {
  security_group_id               = aws_security_group.ec2_sg.id
  referenced_security_group_id    = aws_security_group.alb_sg.id  # Only ALB can talk to EC2
  from_port                       = 80
  ip_protocol                     = "tcp"
  to_port                         = 80
}

# Allow SSH access from my IP only (admin access)
resource "aws_vpc_security_group_ingress_rule" "ec2_sg_ssh" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = var.ssh_allowed_ip  # Only my public IP
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

# Allow all outbound traffic (to internet via NAT, to ALB)
resource "aws_vpc_security_group_egress_rule" "ec2_sg_outbound" {
  security_group_id = aws_security_group.ec2_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ============================================
# APPLICATION LOAD BALANCER
# ============================================
# Distributes incoming traffic across healthy EC2 instances
# Internet-facing, listens on port 80

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 8.0"

  name               = "dona-alb"
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets  # ALB in public subnets
  security_groups    = [aws_security_group.alb_sg.id]

  target_groups = [
    {
      name_prefix      = "dona-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
      # No targets specified - Auto Scaling will register instances
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = "dev"
  }
}

# ============================================
# AUTO SCALING GROUP
# ============================================
# Manages EC2 instances: min 2, max 6, starts with 2
# Automatically registers instances with ALB target group

module "asg" {
  source = "terraform-aws-modules/autoscaling/aws"

  name = "dona-asg"

  min_size                  = 2      # Always keep at least 2 for high availability
  max_size                  = 6      # Cost control - never exceed 6
  desired_capacity          = 2      # Start with 2 instances
  wait_for_capacity_timeout = 0
  health_check_type         = "ELB"  # Use ALB health checks
  vpc_zone_identifier       = module.vpc.private_subnets  # EC2 in private subnets
  key_name                  = var.key_name  # SSH key for access

  # Connect ASG to ALB target group
  traffic_source_attachments = {
    alb_attachment = {
      traffic_source_identifier = module.alb.target_group_arns[0]
      traffic_source_type       = "elbv2"
    }
  }

  # Launch template - blueprint for EC2 instances
  launch_template_name        = "dona-asg"
  launch_template_description = "dona autoscaling"
  update_default_version      = true

  image_id          = var.ami_id           # Ubuntu 24.04
  instance_type     = var.instance_type    # t3.micro
  security_groups   = [aws_security_group.ec2_sg.id]
  ebs_optimized     = true
  enable_monitoring = true  # CloudWatch detailed monitoring

  # User data script runs on instance launch
  # Installs Apache web server and creates test page
  user_data = base64encode(<<-EOF
    #!/bin/bash
    apt update -y
    apt install -y apache2
    systemctl start apache2
    systemctl enable apache2
    echo "<h1>Hello from $(hostname -f) in $(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)</h1>" > /var/www/html/index.html
  EOF
  )

  tags = {
    Environment = var.environment
    Project     = "megasecret"
  }
}

# ============================================
# AUTO SCALING POLICIES
# ============================================
# Define what actions to take when alarms trigger

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "scale-out"
  scaling_adjustment     = 1                # Add 1 instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300              # Wait 5 minutes before next scaling
  autoscaling_group_name = module.asg.autoscaling_group_name
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "scale-in"
  scaling_adjustment     = -1               # Remove 1 instance
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = module.asg.autoscaling_group_name
}

# ============================================
# CLOUDWATCH ALARMS
# ============================================
# Monitor CPU usage and trigger scaling actions

# Scale out when CPU > 70% for 2 consecutive periods (4 minutes)
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "high-cpu-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120                 # 2 minutes per period
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Scale out when CPU > 70% for 2 periods"

  dimensions = {
    AutoScalingGroupName = module.asg.autoscaling_group_name
  }

  alarm_actions = [aws_autoscaling_policy.scale_out.arn]
}

# Scale in when CPU < 30% for 2 consecutive periods (4 minutes)
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "low-cpu-alarm"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30
  alarm_description   = "Scale in when CPU < 30% for 2 periods"

  dimensions = {
    AutoScalingGroupName = module.asg.autoscaling_group_name
  }

  alarm_actions = [aws_autoscaling_policy.scale_in.arn]
}

# ============================================
# BASTION HOST
# ============================================
# Secure jump box in public subnet for SSH access to private EC2 instances

# Security group for bastion - only allows SSH from my IP
resource "aws_security_group" "bastion_sg" {
  name        = "bastion_sg"
  description = "Allow SSH from my IP only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_ip]  # Only my IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Allow SSH from bastion to EC2 instances
resource "aws_vpc_security_group_ingress_rule" "ec2_sg_ssh_bastion" {
  security_group_id            = aws_security_group.ec2_sg.id
  referenced_security_group_id = aws_security_group.bastion_sg.id  # Bastion can SSH in
  from_port                    = 22
  ip_protocol                  = "tcp"
  to_port                      = 22
}

# Bastion EC2 instance in public subnet
resource "aws_instance" "bastion" {
  ami                    = var.ami_id                    # Ubuntu 24.04
  instance_type          = "t3.micro"
  subnet_id              = module.vpc.public_subnets[0]  # First public subnet
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  key_name               = var.key_name

  associate_public_ip_address = true  # Needed for SSH access

  tags = {
    Name = "bastion-host"
  }
}