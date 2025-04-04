# Set which cloud provider to use
locals {
  cloud_provider = "hostinger"  # Change to "aws" to switch providers
}

# Provider-agnostic module that delegates to the appropriate provider module
module "infrastructure" {
  source = "./modules/infrastructure"
  
  # Common parameters for all providers
  app_name        = var.app_name
  environment     = var.environment
  domain_name     = var.domain_name
  
  # Provider selection
  cloud_provider  = local.cloud_provider
  
  # Hostinger-specific parameters
  hostinger_api_token = var.hostinger_api_token
  hostinger_vps_plan  = var.hostinger_vps_plan
  
  # AWS-specific parameters
  aws_region      = var.aws_region
  aws_instance_type = var.aws_instance_type
}

# Variables for the root module
variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

# Hostinger variables
variable "hostinger_api_token" {
  description = "API token for Hostinger"
  type        = string
  sensitive   = true
}

variable "hostinger_vps_plan" {
  description = "VPS plan ID in Hostinger"
  type        = string
  default     = "vps-1"
}

# AWS variables
variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = "us-east-1"
}

variable "aws_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

# Outputs from the infrastructure module
output "public_ip" {
  description = "Public IP address of the server"
  value       = module.infrastructure.public_ip
}

output "website_url" {
  description = "URL of the deployed website"
  value       = module.infrastructure.website_url
}