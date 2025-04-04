# Application Integration Guide

This guide explains how to integrate your application with the Terraform multi-cloud template.

## Approach Options

There are three main ways to deploy your application:

1. **Custom Application Module**: Add a new module that defines application-specific resources
2. **Enhanced Deployment Scripts**: Extend the existing deployment scripts  
3. **External CI/CD Integration**: Use the Terraform setup for infrastructure and a separate CI/CD pipeline for application deployment

## Option 1: Custom Application Module

### Step 1: Create Application Module Structure

```plaintext
modules/
└── application/
    ├── main.tf       # Application-specific infrastructure
    ├── variables.tf  # Input variables
    ├── outputs.tf    # Output variables
    └── files/        # Application files (configs, etc.)
```

### Step 2: Define Module Interface

```hcl
# modules/application/variables.tf
variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "provider_type" {
  description = "Cloud provider type (hostinger or aws)"
  type        = string
}

variable "server_ip" {
  description = "IP address of the server"
  type        = string
}

variable "domain_name" {
  description = "Domain name"
  type        = string
}

variable "additional_config" {
  description = "Additional configuration specific to the application"
  type        = map(string)
  default     = {}
}
```

### Step 3: Create Application-Specific Resources

```hcl
# modules/application/main.tf
resource "null_resource" "app_deployment" {
  triggers = {
    server_ip  = var.server_ip
    app_name   = var.app_name
    environment = var.environment
    timestamp  = timestamp()  # Forces redeploy on apply
  }

  # Provision application based on provider
  provisioner "local-exec" {
    command = "${path.module}/deploy_${var.provider_type}.sh ${var.server_ip} ${var.app_name} ${var.environment}"
  }
}
```

### Step 4: Call Application Module from Root

```hcl
# In main.tf (root)
module "application" {
  source = "./modules/application"
  
  app_name     = var.app_name
  environment  = var.environment
  provider_type = local.cloud_provider
  server_ip    = module.infrastructure.public_ip
  domain_name  = var.domain_name
  
  additional_config = {
    db_name = "appdb"
    cache_size = "512m"
    # Other app-specific settings
  }
  
  depends_on = [module.infrastructure]
}
```

## Option 2: Enhancing Deployment Scripts

The template already includes basic deployment scripts. You can enhance these to deploy your specific application:

### For NodeJS Application

Create `modules/providers/hostinger/files/deploy-nodejs.sh`:

```bash
#!/bin/bash
# Deploy Node.js application to server

APP_NAME=$1
SERVER_IP=$2
REPO_URL=$3  # Git repository URL

ssh -o StrictHostKeyChecking=no root@$SERVER_IP << EOF
  # Install Node.js
  curl -sL https://deb.nodesource.com/setup_16.x | bash -
  apt-get install -y nodejs

  # Clone application repository
  mkdir -p /var/www/$APP_NAME
  git clone $REPO_URL /var/www/$APP_NAME
  
  # Install dependencies and build
  cd /var/www/$APP_NAME
  npm install
  npm run build
  
  # Setup PM2 for process management
  npm install -g pm2
  pm2 start npm --name "$APP_NAME" -- start
  pm2 startup
  pm2 save
  
  # Configure Nginx as reverse proxy
  cat > /etc/nginx/sites-available/$APP_NAME << 'NGINX'
  server {
      listen 80;
      server_name \$hostname;
      
      location / {
          proxy_pass http://localhost:3000;
          proxy_http_version 1.1;
          proxy_set_header Upgrade \$http_upgrade;
          proxy_set_header Connection 'upgrade';
          proxy_set_header Host \$host;
          proxy_cache_bypass \$http_upgrade;
      }
  }
  NGINX
  
  ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
  systemctl restart nginx
EOF
```

Update the application deployment in your main script to call this specialized script.

## Option 3: External CI/CD Integration

Use the Terraform setup for infrastructure only, and integrate with CI/CD tools:

1. **Output Server Information**:

   ```hcl
   # In outputs.tf
   output "server_ssh_details" {
     value = {
       ip     = module.infrastructure.public_ip
       user   = "root"  # or appropriate user
       domain = var.domain_name
     }
     sensitive = true
   }
   ```

2. **Use CI/CD Pipeline**:
   - GitHub Actions, GitLab CI, Jenkins, or other CI tools
   - Pass the Terraform outputs to the deployment stage
   - Use standard deployment scripts in your pipeline

### Example GitHub Actions Workflow

```yaml
name: Deploy Application

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Get infrastructure details
        id: infra
        run: |
          cd terraform
          terraform init
          terraform output -json server_ssh_details > server.json
          
      - name: Deploy application
        uses: appleboy/ssh-action@master
        with:
          host: ${{ fromJson(steps.infra.outputs.server_ssh_details).ip }}
          username: root
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            git clone https://github.com/your-org/your-app.git
            cd your-app
            ./deploy.sh
```

## Database Integration

For applications requiring a database:

### On Hostinger VPS

```hcl
# In modules/providers/hostinger/main.tf
resource "null_resource" "database_setup" {
  # ... resource definition ...
  
  provisioner "local-exec" {
    command = "${path.module}/scripts/setup_database.sh ${data.external.vps_details.result.ip_address} ${var.app_name}"
  }
  
  depends_on = [null_resource.hostinger_vps]
}
```

With corresponding script:

```bash
#!/bin/bash
# setup_database.sh
SERVER_IP=$1
DB_NAME=$2

ssh -o StrictHostKeyChecking=no root@$SERVER_IP << EOF
  # Install MySQL
  apt-get update
  apt-get install -y mysql-server
  
  # Secure installation
  mysql_secure_installation --use-default
  
  # Create database and user
  mysql -e "CREATE DATABASE IF NOT EXISTS ${DB_NAME};"
  mysql -e "CREATE USER IF NOT EXISTS '${DB_NAME}_user'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';"
  mysql -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_NAME}_user'@'localhost';"
  mysql -e "FLUSH PRIVILEGES;"
EOF
```

### On AWS

Use RDS resources in the AWS provider module:

```hcl
resource "aws_db_instance" "database" {
  allocated_storage    = 10
  engine               = "mysql"
  engine_version       = "5.7"
  instance_class       = "db.t3.micro"
  name                 = "${var.app_name}db"
  username             = "admin"
  password             = random_password.db_password.result
  parameter_group_name = "default.mysql5.7"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name  = aws_db_subnet_group.default.name
}
```

## Environment Configuration

Create environment-specific configuration:

```bash
# modules/providers/hostinger/scripts/create_env_file.sh
SERVER_IP=$1
APP_NAME=$2
ENVIRONMENT=$3
DB_NAME="${APP_NAME}db"
DB_USER="${APP_NAME}_user"
DB_PASSWORD=$4

ssh -o StrictHostKeyChecking=no root@$SERVER_IP << EOF
  cat > /var/www/$APP_NAME/.env << ENVFILE
NODE_ENV=$ENVIRONMENT
DB_HOST=localhost
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
API_URL=https://$DOMAIN_NAME/api
ENVFILE
EOF
```

## Final Notes

1. **Security Considerations**:
   - Store sensitive data (passwords, tokens) in Terraform encrypted variables
   - Implement proper firewalls and security groups
   - Use SSH keys instead of passwords

2. **Monitoring & Logging**:
   - Consider adding monitoring resources (CloudWatch for AWS)
   - Install monitoring agents on Hostinger VPS

3. **Backup Strategy**:
   - Implement database backups
   - Configure file system backups

4. **Scaling Considerations**:
   - For AWS: Use Auto Scaling Groups
   - For Hostinger: Manual scaling or migration to cloud provider with better scaling options
