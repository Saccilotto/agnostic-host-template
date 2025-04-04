# Terraform Agnostic Host Template Guide

This template provides a modular approach to deploying applications on either Hostinger or AWS with minimal code changes.

## Project Structure

```plaintext
.agnostic-host-template
├── main.tf                           # Root configuration file
├── terraform.tfvars                  # Variable values
├── modules/
│   ├── infrastructure/               # Provider-agnostic facade
│   │   └── main.tf                   
│   └── providers/
│       ├── hostinger/                # Hostinger implementation
│       │   ├── main.tf
│       │   └── scripts/              # Custom scripts for Hostinger API
│       │       ├── provision_vps.sh
│       │       ├── get_vps_details.sh
│       │       ├── setup_dns.sh
│       │       ├── deploy_app.sh
│       │       └── destroy_vps.sh
│       └── aws/                      # AWS implementation
│           ├── main.tf
│           └── ssh/                  # SSH keys for AWS
│               └── deployer.pub
```

## Getting Started

### Prerequisites

1. Terraform installed (v1.0.0+)
2. For Hostinger: API token with necessary permissions
3. For AWS: AWS CLI configured with proper credentials
4. SSH key pair (for AWS deployment)

### Initial Setup

1. Create an SSH key pair for AWS:

   ```bash
   mkdir -p modules/providers/aws/ssh
   ssh-keygen -t rsa -b 2048 -f modules/providers/aws/ssh/deployer
   ```

2. Create a `terraform.tfvars` file:

   ```hcl
   app_name = "my-application"
   environment = "dev"
   domain_name = "example.com"
   
   # Hostinger-specific
   hostinger_api_token = "your-api-token"
   hostinger_vps_plan = "vps-1"
   
   # AWS-specific
   aws_region = "us-east-1"
   aws_instance_type = "t3.micro"
   ```

### Switching Between Providers

To switch between providers, simply change the `cloud_provider` local variable in `main.tf`:

```hcl
locals {
  cloud_provider = "hostinger"  # Change to "aws" to switch providers
}
```

### Deployment Steps

1. Initialize Terraform:

   ```bash
   terraform init
   ```

2. Create a deployment plan:

   ```bash
   terraform plan
   ```

3. Apply the configuration:

   ```bash
   terraform apply
   ```

4. To destroy resources:

   ```bash
   terraform destroy
   ```

## Customization

### Adding a New Provider

1. Create a new module under `modules/providers/`
2. Implement the same outputs (`public_ip`, `website_url`)
3. Add the module to `modules/infrastructure/main.tf`

### Modifying Application Deployment

- For Hostinger: Edit `modules/providers/hostinger/scripts/deploy_app.sh`
- For AWS: Modify the `user_data` section in `modules/providers/aws/main.tf`

## API Endpoints

### Hostinger API Notes

The template uses the following actual Hostinger API endpoints:

- `GET /v1/server` - List all VPS instances
- `POST /v1/server` - Create a new VPS
- `GET /v1/server/{id}` - Get VPS details
- `DELETE /v1/server/{id}` - Delete a VPS
- `GET /v1/domains` - List all domains
- `POST /v1/domains/{id}/dns` - Create/update DNS records

These endpoints are based on Hostinger's Cloud API. The API may require proper authentication using an API token that you can generate from your Hostinger control panel.

For the latest API documentation and complete details, please refer to Hostinger's official API documentation portal or contact Hostinger support.

## Security Considerations

1. Store sensitive values (API tokens, credentials) in a secure backend like Terraform Cloud or AWS S3 with encryption
2. Restrict SSH access to specific IP addresses in production
3. Consider using variables for script paths to make the configuration more secure
4. Rotate API tokens and credentials regularly

## Extending The Template

- Add a monitoring module that works across providers
- Implement SSL certificate management
- Add database provisioning
- Configure CI/CD integration
