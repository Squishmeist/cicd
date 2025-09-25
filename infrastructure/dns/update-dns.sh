#!/bin/bash

# Hetzner DNS Record Update Script
# This script updates both root (@) and wildcard (*) DNS records using the Hetzner DNS API

set -e  # Exit on any error

# Load environment variables from .env file
if [ -f ".env" ]; then
    source .env
    echo "✅ Loaded environment variables from .env"
else
    echo "❌ .env file not found! Please create it first."
    echo "💡 Use .env.example as a template"
    exit 1
fi

# Check if required variables are set
if [ -z "$HETZNER_DNS_API_TOKEN" ] || [ -z "$HETZNER_ZONE_ID" ] || [ -z "$SERVER_IP" ]; then
    echo "❌ Missing required environment variables!"
    echo "Please ensure the following are set in your .env file:"
    echo "  - HETZNER_DNS_API_TOKEN"
    echo "  - HETZNER_ZONE_ID" 
    echo "  - SERVER_IP"
    exit 1
fi

# Function to update a DNS record
update_dns_record() {
    local record_id=$1
    local record_name=$2
    local description=$3
    
    echo "🚀 Updating $description DNS record ($record_name)..."
    echo "   Record ID: $record_id"
    echo "   Server IP: $SERVER_IP"
    echo "   TTL: ${DNS_RECORD_TTL:-86400}"
    
    curl -X PUT "https://dns.hetzner.com/api/v1/records/${record_id}" \
      -H "Content-Type: application/json" \
      -H "Auth-API-Token: ${HETZNER_DNS_API_TOKEN}" \
      -d "{\"value\": \"${SERVER_IP}\",\"ttl\": ${DNS_RECORD_TTL:-86400},\"type\": \"${DNS_RECORD_TYPE:-A}\",\"name\": \"${record_name}\",\"zone_id\": \"${HETZNER_ZONE_ID}\"}"
    
    echo ""
    echo "✅ $description DNS record update completed!"
    echo ""
}

# Update root domain (@) record
update_dns_record "3a4fbbb27e8f10ecab8a6efeff3c4b76" "@" "ROOT domain"

# Update wildcard (*) record  
update_dns_record "e05780788ac0efc02f20c71a24aac971" "*" "WILDCARD"

echo "🎉 All DNS records updated successfully!"