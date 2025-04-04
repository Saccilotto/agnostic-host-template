terraform {
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2.0"
    }
    dns = {
      source  = "hashicorp/dns"
      version = "~> 3.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4.0"
    }
  }
}

# Create API token file for scripts
resource "local_file" "api_token" {
  content  = var.api_token
  filename = "${path.module}/scripts/.api_token"
  file_permission = "0600"
}

# VPS provisioning
resource "null_resource" "hostinger_vps" {
  triggers = {
    server_name = "${var.app_name}-${var.environment}"
    plan_id     = var.vps_plan
    timestamp   = timestamp()  # Force recreation on apply if needed
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/provision_vps.sh ${self.triggers.server_name} ${self.triggers.plan_id}"
    environment = {
      API_TOKEN_FILE = local_file.api_token.filename
    }
  }

  # Ensure the VPS is destroyed when the resource is destroyed
  provisioner "local-exec" {
    when    = destroy
    command = "${path.module}/scripts/destroy_vps.sh ${self.triggers.server_name}"
    environment = {
      API_TOKEN_FILE = local_file.api_token.filename
    }
  }
}

# Get VPS details (IP address, etc.)
data "external" "vps_details" {
  program = ["${path.module}/scripts/get_vps_details.sh", "${null_resource.hostinger_vps.triggers.server_name}"]
  
  query = {
    api_token_file = local_file.api_token.filename
  }
  
  depends_on = [null_resource.hostinger_vps]
}

# DNS record setup
resource "null_resource" "hostinger_dns" {
  triggers = {
    domain = var.domain_name
    ip     = data.external.vps_details.result.ip_address
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/setup_dns.sh ${self.triggers.domain} ${self.triggers.ip}"
    environment = {
      API_TOKEN_FILE = local_file.api_token.filename
    }
  }

  depends_on = [data.external.vps_details]
}

# Application deployment
resource "null_resource" "app_deployment" {
  triggers = {
    server_name = null_resource.hostinger_vps.triggers.server_name
    ip_address  = data.external.vps_details.result.ip_address
    timestamp   = timestamp()  # Will redeploy on each apply
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/deploy_app.sh ${self.triggers.server_name} ${self.triggers.ip_address}"
    environment = {
      API_TOKEN_FILE = local_file.api_token.filename
      APP_ENV        = var.environment
    }
  }

  depends_on = [null_resource.hostinger_dns]
}

# Module outputs
output "public_ip" {
  description = "Public IP address of the VPS"
  value       = data.external.vps_details.result.ip_address
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

variable "api_token" {
  description = "Hostinger API token"
  type        = string
  sensitive   = true
}

variable "vps_plan" {
  description = "VPS plan ID in Hostinger"
  type        = string
}