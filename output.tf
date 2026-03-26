# Load Balancer DNS Name - where to visit your website
output "alb_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.alb.lb_dns_name
}

# Auto Scaling Group Name - needed for CloudWatch alarms
output "asg_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.asg.autoscaling_group_name
}

# VPC ID - for reference
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}
output "bastion_ssh_command" {
  description = "SSH command to connect to bastion"
  value       = "ssh -i ${var.key_name} ubuntu@${aws_instance.bastion.public_ip}"
  sensitive   = true
}