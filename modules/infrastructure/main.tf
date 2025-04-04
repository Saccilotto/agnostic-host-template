# This module acts as a facade that delegates to provider-specific modules
# based on the cloud_provider variable

# AWS implementation
module "aws" {
  source = "../providers/aws"
  
  app_name      = var.app_name
  environment   = var.environment
  domain_name   = var.domain_name
  region        = var.aws_region
  instance_type = var.aws_instance_type
}

module "hostinger" {
  source = "../providers/hostinger"
  
  app_name    = var.app_name
  environment = var.environment
  domain_name = var.domain_name
  api_token   = var.hostinger_api_token
  vps_plan    = var.hostinger_vps_plan
}

# Forward outputs from the selected provider using locals
locals {
  selected_provider = var.cloud_provider
  
  outputs = {
    aws = {
      public_ip   = module.aws.public_ip
      website_url = module.aws.website_url
    }
    
    hostinger = {
      public_ip   = module.hostinger.public_ip
      website_url = module.hostinger.website_url
    }
  }
}

output "public_ip" {
  description = "Public IP address of the server"
  value       = local.outputs[local.selected_provider].public_ip
}

output "website_url" {
  description = "URL of the deployed website"
  value       = local.outputs[local.selected_provider].website_url
}

# Variables for the infrastructure module
variable "cloud_provider" {
  description = "Cloud provider to use (aws or hostinger)"
  type        = string
  
  validation {
    condition     = contains(["aws", "hostinger"], var.cloud_provider)
    error_message = "The cloud_provider must be either 'aws' or 'hostinger'."
  }
}

variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

# Hostinger-specific variables
variable "hostinger_api_token" {
  description = "API token for Hostinger"
  type        = string
  sensitive   = true
  default     = ""
}

variable "hostinger_vps_plan" {
  description = "VPS plan ID in Hostinger"
  type        = string
  default     = ""
}

# AWS-specific variables
variable "aws_region" {
  description = "AWS region to deploy to"
  type        = string
  default     = ""
}

variable "aws_instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = ""
}