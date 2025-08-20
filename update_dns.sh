#!/bin/bash

set -e

# open the script directory
cd "$(dirname "$0")" || exit 1

# Load .env file if exists
[ -f .env ] && export $(grep -v '^#' .env | xargs)

# Configuration Variables
CF_API_TOKEN="${CF_API_TOKEN:?Cloudflare API TOKEN is required}"
ZONE_NAME="${ZONE_NAME:?Cloudflare Zone Name is required}"

CONF_FILE="./config.conf"

CF_API_URL="https://api.cloudflare.com/client/v4"
AUTH_HEADER="Authorization: Bearer $CF_API_TOKEN"

# Determine sudo (if available)
SUDO=''
if command -v sudo >/dev/null; then
  SUDO='sudo'
fi

# Check and install jq if missing
if ! command -v jq >/dev/null; then
  echo "⚠️  jq is not installed. This script requires jq to function."

  if [[ "$AUTO_INSTALL_JQ" == "true" ]]; then
    answer=Y
  else
    read -p "Would you like to install jq now? [Y/n] " answer
    answer=${answer:-Y}
  fi

  if [[ "$answer" =~ ^[Yy]$ ]]; then
    if command -v apt >/dev/null; then
      echo "Installing jq via apt..."
      $SUDO apt update && $SUDO apt install -y jq || { echo "Failed to install jq."; exit 1; }
    elif command -v yum >/dev/null; then
      echo "Installing jq via yum..."
      $SUDO yum install -y epel-release && $SUDO yum install -y jq || { echo "Failed to install jq."; exit 1; }
    else
      echo "Unsupported package manager. Please install jq manually."
      exit 1
    fi
  else
    echo "jq is required. Exiting."
    exit 1
  fi
fi

# Get Current Public IP Addresses
IPV4=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com)
IPV6=$(curl -s https://api6.ipify.org || curl -s https://ipv6.icanhazip.com)

[[ -z "$IPV4" && -z "$IPV6" ]] && { echo "Unable to obtain IP addresses."; exit 1; }
echo "Current IPv4: $IPV4"
echo "Current IPv6: $IPV6"

# Retrieve Zone ID from Cloudflare API
ZONE_ID=$(curl -s -X GET "$CF_API_URL/zones?name=$ZONE_NAME" -H "$AUTH_HEADER" | jq -r '.result[0].id')
if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "null" ]; then
  echo "Error: Zone ID not found for zone name '$ZONE_NAME'."
  exit 1
fi

# Process Each Record Block in the Config File
parse_records() {
  # Read config blocks separated by blank lines, processing each block terminated by a null character.
  awk -v RS= -v ORS='\0' 'NF' "$CONF_FILE" | while IFS= read -r -d '' block; do
    echo "📄 Parsing block:"
    echo "$block"

    TYPE=$(echo "$block" | grep -i "^Type:" | cut -d: -f2- | xargs)
    NAME=$(echo "$block" | grep -i "^Name:" | cut -d: -f2- | xargs)
    RULE=$(echo "$block" | grep -i "^Content_Rule:" | cut -d: -f2- | xargs)

    echo "🔍 Parsed TYPE=$TYPE NAME=$NAME RULE=$RULE"

    if [[ -z "$TYPE" || -z "$NAME" || -z "$RULE" ]]; then
      echo "⚠️  Skipping invalid block (missing TYPE, NAME, or RULE)"
      continue
    fi

    CONTENT="${RULE//\{IPV4\}/$IPV4}"
    CONTENT="${CONTENT//\{IPV6\}/$IPV6}"
    
		# Check if NAME is @ to correctly handle root domain
		if [[ "$NAME" == "@" ]]; then
      FQDN="$ZONE_NAME"
    else
      FQDN="$NAME.$ZONE_NAME"
    fi

    echo "🔍 Processing $TYPE record for $FQDN..."

    RECORD_JSON=$(curl -s -H "$AUTH_HEADER" "$CF_API_URL/zones/$ZONE_ID/dns_records?type=$TYPE&name=$FQDN")
    RECORD_ID=$(echo "$RECORD_JSON" | jq -r '.result[0].id')
    OLD_CONTENT=$(echo "$RECORD_JSON" | jq -r '.result[0].content')
    OLD_TTL=$(echo "$RECORD_JSON" | jq -r '.result[0].ttl')
    OLD_PROXIED=$(echo "$RECORD_JSON" | jq -r '.result[0].proxied')

    if [[ -z "$RECORD_ID" || "$RECORD_ID" == "null" ]]; then
      echo "⚠️  Record $TYPE for $FQDN not found. Skipping."
      continue
    fi

    if [[ "$OLD_CONTENT" == "$CONTENT" ]]; then
      echo "✅ $TYPE record for $FQDN is up to date."
    else
      echo "📝 Updating $TYPE record for $FQDN → $CONTENT"
      curl -s -X PUT "$CF_API_URL/zones/$ZONE_ID/dns_records/$RECORD_ID" \
        -H "$AUTH_HEADER" -H "Content-Type: application/json" \
        --data "{\"type\":\"$TYPE\",\"name\":\"$FQDN\",\"content\":\"$CONTENT\",\"ttl\":$OLD_TTL,\"proxied\":$OLD_PROXIED}" >/dev/null
    fi
  done
}

# Main Execution
if [[ -f "$CONF_FILE" ]]; then
  echo "🔧 Starting DNS record update..."
  parse_records
  echo "✅ All DNS records have been processed."
else
  echo "❌ Config file $CONF_FILE not found. Please check the path."
  exit 1
fi
