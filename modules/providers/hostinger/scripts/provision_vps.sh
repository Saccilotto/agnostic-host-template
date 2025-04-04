#!/bin/bash

# This script provisions a VPS on Hostinger

SERVER_NAME=$1
PLAN_ID=$2
API_TOKEN=$(cat $API_TOKEN_FILE)

echo "Provisioning Hostinger VPS: $SERVER_NAME with plan $PLAN_ID"

# Check if VPS already exists
EXISTING_VPS=$(curl -s -H "Authorization: Bearer $API_TOKEN" \
  "https://api.hostinger.com/v1/server" | grep -c "$SERVER_NAME")

if [ $EXISTING_VPS -gt 0 ]; then
  echo "VPS $SERVER_NAME already exists, skipping creation"
  exit 0
fi

# Create VPS instance - using actual Hostinger Cloud API endpoint
RESPONSE=$(curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"$SERVER_NAME\",
    \"image\": \"ubuntu-20-04\",
    \"region\": \"eu-central-1\",
    \"plan\": \"$PLAN_ID\",
    \"ssh_keys\": [\"default\"]
  }" \
  "https://api.hostinger.com/v1/server")

# Extract VPS ID from response
VPS_ID=$(echo $RESPONSE | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$VPS_ID" ]; then
  echo "Error creating VPS: $RESPONSE" >&2
  exit 1
fi

echo "VPS created with ID: $VPS_ID"

# Wait for VPS to be ready
echo "Waiting for VPS to be ready..."
for i in {1..30}; do
  STATUS=$(curl -s -H "Authorization: Bearer $API_TOKEN" \
    "https://api.hostinger.com/v1/vps/$VPS_ID" | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
  
  if [ "$STATUS" == "running" ]; then
    echo "VPS is now running!"
    break
  fi
  
  if [ $i -eq 30 ]; then
    echo "Timeout waiting for VPS to be ready" >&2
    exit 1
  fi
  
  echo "VPS status: $STATUS. Waiting..."
  sleep 10
done

exit 0