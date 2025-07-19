#!/bin/bash

# Variables
TOKEN_NAME="kibana-token"
SERVICE_ACCOUNT="elastic/kibana"
ES_BIN="/usr/share/elasticsearch/bin"
OUTPUT_DIR="/shared"  # Shared volume directory

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Check if token already exists
TOKEN_FILE="$OUTPUT_DIR/kibana_service_token.txt"
if [ -f "$TOKEN_FILE" ]; then
  echo "Token already exists at $TOKEN_FILE. Skipping creation."
  exit 0
fi

# Generate the token and extract it
echo "Creating service token for $SERVICE_ACCOUNT..."
$ES_BIN/elasticsearch-service-tokens create "$SERVICE_ACCOUNT" "$TOKEN_NAME" | grep "SERVICE_TOKEN" | cut -d'=' -f2 | tr -d ' ' > "$TOKEN_FILE"

if [ $? -eq 0 ]; then
  echo "Token created and saved to $TOKEN_FILE:"
  cat "$TOKEN_FILE"
else
  echo "Failed to create token."
  exit 1
fi