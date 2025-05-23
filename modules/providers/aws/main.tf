# Network resources
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.app_name}-vpc-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name        = "${var.app_name}-public-subnet-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.app_name}-igw-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.app_name}-public-rt-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group
resource "aws_security_group" "web" {
  name        = "${var.app_name}-sg-${var.environment}"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # In production, restrict this to your IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.app_name}-sg-${var.environment}"
    Environment = var.environment
  }
}

# EC2 instance
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Create local file for storing SSH key 
resource "local_file" "ssh_key" {
  count    = fileexists("${path.module}/ssh/deployer.pub") ? 0 : 1
  content  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCxO27JE5uXiHmzTcIHzjGT+5OHaW/t/+5SsLGcS4AXD6hU5hLHgxKfiCLPHP/ckBBZTXGjEEjO7uDdEjCz4cX1Es7mBqSIyJBY8IRhUaP8gqHlL7ABD4GVlIaGIEFSyRiOitwlHLJTn4XvPUXOn5HpyXR6R9lxgjlQI3tLMSgcRXYBxDXTSjHdkGvq6cQaKDSyzcLvPWbP/QNkB9YYO3kbqDfuK/k8ZY5jJsm0TYx7Vwa9VcGa+ayWDYQxJTLXulsBGdvQzGRTXOKnONP7QAQ8IJIlzZBCKhNRFEFADIKZrGz67n/nh6AwXbvLNBYDDEJJxJKyGtlIlsX8uL8dD1TadDnX test-key"
  filename = "${path.module}/ssh/deployer.pub"
  file_permission = "0600"
}

resource "aws_key_pair" "deployer" {
  key_name   = "${var.app_name}-deployer-key-${var.environment}"
  public_key = file("${path.module}/ssh/deployer.pub")
  
  depends_on = [local_file.ssh_key]
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web.id]
  key_name               = aws_key_pair.deployer.key_name

  tags = {
    Name        = "${var.app_name}-${var.environment}"
    Environment = var.environment
  }

  # Application deployment script
  user_data = <<-EOF
              #!/bin/bash
              apt-get update
              apt-get install -y nginx
              echo "<h1>Deployed with Terraform on AWS</h1><p>App: ${var.app_name}</p><p>Environment: ${var.environment}</p>" > /var/www/html/index.html
              systemctl enable nginx
              systemctl start nginx
              EOF
}

# Output values
output "public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "website_url" {
  description = "URL of the deployed website"
  value       = "https://${var.domain_name}"
}

# Variables 
variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "region" {
  description = "AWS region to deploy to"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}