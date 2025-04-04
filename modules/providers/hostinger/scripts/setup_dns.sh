#!/bin/bash

# This script sets up DNS records for the application
DOMAIN=$1
IP_ADDRESS=$2
API_TOKEN=$(cat $API_TOKEN_FILE)

echo "Setting up DNS for domain $DOMAIN pointing to $IP_ADDRESS"

# Check if domain exists in Hostinger account using actual Hostinger API
DOMAIN_LIST=$(curl -s -H "Authorization: Bearer $API_TOKEN" \
  "https://api.hostinger.com/v1/domains")

DOMAIN_ID=$(echo $DOMAIN_LIST | jq -r ".data[] | select(.name==\"$DOMAIN\") | .id")

if [ -z "$DOMAIN_ID" ]; then
  echo "Warning: Domain $DOMAIN not found in Hostinger account. Please add it manually."
  exit 0
fi

# Create/Update A records using actual Hostinger DNS API
# First create/update main A record
RESPONSE1=$(curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"A\",
    \"name\": \"@\",
    \"content\": \"$IP_ADDRESS\",
    \"ttl\": 300
  }" \
  "https://api.hostinger.com/v1/domains/$DOMAIN_ID/dns")

# Then create/update www A record
RESPONSE2=$(curl -s -X POST \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"type\": \"A\",
    \"name\": \"www\",
    \"content\": \"$IP_ADDRESS\",
    \"ttl\": 300
  }" \
  "https://api.hostinger.com/v1/domains/$DOMAIN_ID/dns")

echo "DNS setup responses: $RESPONSE1 $RESPONSE2"

echo "DNS setup response: $RESPONSE"

exit 0