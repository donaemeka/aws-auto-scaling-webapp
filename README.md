# AWS Multi-AZ Auto Scaling Web Application

A production-ready, highly available web application infrastructure on AWS that automatically scales based on CPU usage. Built entirely with Terraform as Infrastructure as Code.

**Live Demo:** [http://dona-alb-1689052785.eu-west-2.elb.amazonaws.com](http://dona-alb-1689052785.eu-west-2.elb.amazonaws.com)

---

## Architecture Diagram

![Architecture](screenshots/1-architecture-diagram.jpeg)

---

## Screenshots

### Live Website
![Website](screenshots/2-website-live.png)

### Load Balancing Across Availability Zones
![Load Balancing](screenshots/3-load-balancing-demo.png)

### Auto Scaling Group
![ASG](screenshots/4-asg-healthy.png)

### Target Group Health Checks
![Target Group](screenshots/5-target-group-healthy.png)

### CloudWatch Alarms
![CloudWatch](screenshots/6-cloudwatch-alarms.png)

### Terraform Deployment
![Terraform](screenshots/7-terraform-apply.png)

### Bastion Host SSH Access
![Bastion SSH](screenshots/8-bastion-ssh.png)

### GitHub Repository Structure
![GitHub Code](screenshots/9-github-code.png)

---

## Technologies Used

| Category | Technology |
|----------|------------|
| Cloud Provider | AWS |
| Infrastructure as Code | Terraform |
| Compute | EC2 (t3.micro) |
| Networking | VPC, Subnets, NAT Gateway, Internet Gateway |
| Load Balancing | Application Load Balancer (ALB) |
| Auto Scaling | Auto Scaling Groups (ASG) |
| Monitoring | CloudWatch Alarms |
| Operating System | Ubuntu 24.04 LTS |
| Web Server | Apache2 |

---

## Auto Scaling Configuration

| Setting | Value |
|---------|-------|
| Minimum Instances | 2 |
| Maximum Instances | 6 |
| Desired Instances | 2 |
| Scale Out Threshold | CPU > 70% for 2 periods (4 minutes) |
| Scale In Threshold | CPU < 30% for 2 periods (4 minutes) |
| Cooldown Period | 300 seconds |
| Health Check Type | ELB |

---

## Security Features

| Layer | Implementation |
|-------|----------------|
| Network Isolation | EC2 instances in private subnets (no public IPs) |
| Bastion Host | Secure jump box in public subnet for SSH access |
| ALB Security Group | HTTP (80) from anywhere |
| EC2 Security Group | HTTP (80) from ALB only |
| EC2 Security Group | SSH (22) from bastion only |
| Bastion Security Group | SSH (22) from my IP only |
| NAT Gateway | Outbound internet for private instances |

---

## Project Structure

```
aws-auto-scaling-webapp/
├── main.tf                      # Main Terraform configuration
├── variables.tf                 # Variable definitions
├── outputs.tf                   # Output definitions
├── terraform.tfvars.example     # Example variable values
├── .gitignore                   # Git ignore rules
├── README.md                    # Project documentation
└── screenshots/                 # Project screenshots (9 images)
    ├── 1-architecture-diagram.jpeg
    ├── 2-website-live.png
    ├── 3-load-balancing-demo.png
    ├── 4-asg-healthy.png
    ├── 5-target-group-healthy.png
    ├── 6-cloudwatch-alarms.png
    ├── 7-terraform-apply.png
    ├── 8-bastion-ssh.png
    └── 9-github-code.png
```

---

## How to Deploy

### Prerequisites

- AWS account with appropriate permissions
- Terraform installed (>= 1.5.7)
- AWS CLI configured
- SSH key pair in your AWS account

### Deployment Steps

**1. Clone the repository**

```bash
git clone https://github.com/donaemeka/aws-auto-scaling-webapp.git
cd aws-auto-scaling-webapp
```

**2. Configure variables**

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your values:

```hcl
ssh_allowed_ip = "YOUR_IP/32"
key_name       = "YOUR_KEY_NAME"
```

**3. Initialize Terraform**

```bash
terraform init
```

**4. Review the plan**

```bash
terraform plan
```

**5. Apply the configuration**

```bash
terraform apply
```

Type `yes` when prompted.

**6. Get your website URL**

```bash
terraform output alb_dns_name
```

---

## How to Connect to Private Instances

### Option 1: SSH via Bastion

```bash
ssh -i your-key.pem ubuntu@$(terraform output bastion_public_ip)
ssh -i your-key.pem ubuntu@<private-instance-ip>
```

### Option 2: SSH Jump (One-Liner)

```bash
ssh -J ubuntu@$(terraform output bastion_public_ip) -i your-key.pem ubuntu@<private-ip>
```

### Option 3: AWS Systems Manager Session Manager

1. Go to AWS Console → Systems Manager → Session Manager
2. Click **Start session**
3. Select your private instance

---

## Testing Auto Scaling

**1. SSH into a private instance**

```bash
ssh -i your-key.pem ubuntu@<private-ip>
```

**2. Install stress tool**

```bash
sudo apt update && sudo apt install stress -y
```

**3. Generate CPU load**

```bash
stress --cpu 2 --timeout 300 &
```

**4. Monitor CloudWatch Alarms**

- Go to CloudWatch → Alarms
- Watch `high-cpu-alarm` change from OK → ALARM

**5. Check Auto Scaling Group**

- Go to EC2 → Auto Scaling Groups
- New instance will launch, desired capacity increases to 3

---

## Challenges and Solutions

| Challenge | Solution |
|-----------|----------|
| t2.micro not free tier eligible | Changed to t3.micro |
| Health checks failing | Added `health_check_grace_period = 300` |
| Private instances no internet | Enabled NAT Gateway |
| EC2 couldn't reach internet | Added outbound rule `0.0.0.0/0` |
| Invalid AMI ID | Used data source to find latest AMI |
| Instance metadata not working | Used token-based IMDSv2 |
| SSH key not on instances | Added `key_name` to ASG module |
| SSH from bastion denied | Added rule allowing SSH from bastion SG |
| Provider version conflicts | Updated to `>= 6.29.0` |

---

## Key Learnings

- **VPC Design:** Public/private subnets across multiple AZs
- **NAT Gateway:** Enables private instances to reach internet
- **Auto Scaling:** Min/max/desired with launch templates
- **CloudWatch Alarms:** CPU thresholds with evaluation periods
- **Security Groups:** Least privilege access rules
- **Bastion Host:** Secure SSH access to private instances
- **Terraform Modules:** Using and configuring registry modules
- **User Data:** Automating software installation on launch

---

## Cost Considerations

| Resource | Estimated Monthly Cost |
|----------|------------------------|
| EC2 (t3.micro) × 2 | ~$15 |
| NAT Gateway | ~$32 |
| Application Load Balancer | ~$16 |
| Data Transfer | ~$5-10 |
| **Total** | **~$70-80** |

To avoid charges: Run `terraform destroy` when not using.

---

## Clean Up

```bash
terraform destroy
```

Type `yes` when prompted.

---

## Contact

**Author:** Donatus Emeka Anyalebechi

**GitHub:** [@donaemeka](https://github.com/donaemeka)

**LinkedIn:** [www.linkedin.com/in/donatus-devops](https://www.linkedin.com/in/donatus-devops)

**Email:** donaemeka92@gmail.com

---

© 2026 Donatus Emeka