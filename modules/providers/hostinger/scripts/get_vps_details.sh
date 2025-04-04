#!/bin/bash

# This script retrieves the details of a Hostinger VPS

SERVER_NAME=$1
API_TOKEN=$(cat $2)

# Get VPS ID from name using actual Hostinger Cloud API
VPS_LIST=$(curl -s -H "Authorization: Bearer $API_TOKEN" \
  "https://api.hostinger.com/v1/server")

VPS_ID=$(echo $VPS_LIST | jq -r ".data[] | select(.name==\"$SERVER_NAME\") | .id")

if [ -z "$VPS_ID" ]; then
  echo "Error: Could not find VPS with name $SERVER_NAME" >&2
  # Return a default value for Terraform to consume
  echo "{\"ip_address\": \"0.0.0.0\", \"status\": \"not_found\"}"
  exit 0
fi

# Get VPS details using actual Hostinger Cloud API
VPS_DETAILS=$(curl -s -H "Authorization: Bearer $API_TOKEN" \
  "https://api.hostinger.com/v1/server/$VPS_ID")

# Extract IP and status
IP_ADDRESS=$(echo $VPS_DETAILS | grep -o '"ip":"[^"]*"' | cut -d'"' -f4)
STATUS=$(echo $VPS_DETAILS | grep -o '"status":"[^"]*"' | cut -d'"' -f4)

# Return JSON for Terraform to consume
echo "{\"ip_address\": \"$IP_ADDRESS\", \"status\": \"$STATUS\", \"id\": \"$VPS_ID\"}"

exit 0