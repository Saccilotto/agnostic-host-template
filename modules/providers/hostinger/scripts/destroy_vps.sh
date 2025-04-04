#!/bin/bash

# This script destroys a Hostinger VPS

SERVER_NAME=$1
API_TOKEN=$(cat $API_TOKEN_FILE)

echo "Destroying Hostinger VPS: $SERVER_NAME"

# Get VPS ID from name
VPS_LIST=$(curl -s -H "Authorization: Bearer $API_TOKEN" \
  "https://api.hostinger.com/v1/vps")

VPS_ID=$(echo $VPS_LIST | grep -o "\"id\":\"[^\"]*\",\"name\":\"$SERVER_NAME\"" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

if [ -z "$VPS_ID" ]; then
  echo "VPS $SERVER_NAME not found, nothing to destroy"
  exit 0
fi

# Delete VPS instance using actual Hostinger Cloud API
RESPONSE=$(curl -s -X DELETE \
  -H "Authorization: Bearer $API_TOKEN" \
  "https://api.hostinger.com/v1/server/$VPS_ID")

echo "VPS destruction response: $RESPONSE"

exit 0