#!/bin/bash

# This script deploys the application to the Hostinger VPS

SERVER_NAME=$1
IP_ADDRESS=$2
APP_ENV=${APP_ENV:-production}

echo "Deploying application to $SERVER_NAME ($IP_ADDRESS) in $APP_ENV environment"

# Wait for SSH to be available
echo "Waiting for SSH to be available..."
for i in {1..30}; do
  if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@$IP_ADDRESS echo "SSH is ready"; then
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "Timeout waiting for SSH to be ready" >&2
    exit 1
  fi
  
  echo "SSH not ready yet. Waiting..."
  sleep 10
done

# Deploy basic web server and sample application
ssh -o StrictHostKeyChecking=no root@$IP_ADDRESS << EOF
  # Update system
  apt-get update
  apt-get upgrade -y
  
  # Install web server
  apt-get install -y nginx
  
  # Configure sample application
  cat > /var/www/html/index.html << 'ENDHTML'
  <!DOCTYPE html>
  <html>
  <head>
    <title>Deployed with Terraform on Hostinger</title>
    <style>
      body { font-family: Arial, sans-serif; max-width: 800px; margin: 0 auto; padding: 20px; }
      .container { border: 1px solid #ddd; padding: 20px; border-radius: 5px; }
      .success { color: green; font-weight: bold; }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>Successfully Deployed!</h1>
      <p class="success">Your application is running on Hostinger VPS</p>
      <p>Server: $SERVER_NAME</p>
      <p>Environment: $APP_ENV</p>
      <p>Deployment time: $(date)</p>
    </div>
  </body>
  </html>
  ENDHTML
  
  # Ensure nginx is running
  systemctl enable nginx
  systemctl restart nginx
  
  echo "Application deployed successfully!"
EOF

exit 0