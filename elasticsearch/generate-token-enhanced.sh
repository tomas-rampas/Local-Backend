#!/bin/bash

# Variables
TOKEN_NAME="kibana-token-$(date +%s)"  # Add timestamp to make token name unique
SERVICE_ACCOUNT="elastic/kibana"
ES_BIN="/usr/share/elasticsearch/bin"
OUTPUT_DIR="/shared"  # Shared volume directory

# Configuration - can be overridden by environment variables
FORCE_NEW_TOKEN=${FORCE_NEW_TOKEN:-true}  # Set to false to keep existing tokens
CLEANUP_OLD_TOKENS=${CLEANUP_OLD_TOKENS:-true}  # Set to false to keep old tokens
MAX_TOKEN_AGE_DAYS=${MAX_TOKEN_AGE_DAYS:-7}  # Clean tokens older than this many days

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

TOKEN_FILE="$OUTPUT_DIR/kibana_service_token.txt"

# Check if we should generate a new token
if [ "$FORCE_NEW_TOKEN" = "true" ]; then
  echo "Generating new service token for container start (FORCE_NEW_TOKEN=true)..."
  
  # Remove old token file if it exists
  if [ -f "$TOKEN_FILE" ]; then
    echo "Removing existing token file: $TOKEN_FILE"
    rm -f "$TOKEN_FILE"
  fi
else
  # Check if token already exists and is valid
  if [ -f "$TOKEN_FILE" ] && [ -s "$TOKEN_FILE" ]; then
    echo "Token file exists and FORCE_NEW_TOKEN=false. Checking if token is still valid..."
    
    # Optional: Add token validation here
    # For now, we'll assume existing token is valid
    echo "Using existing token from $TOKEN_FILE"
    
    # Still start Elasticsearch normally
    echo "Starting Elasticsearch..."
    exec /usr/share/elasticsearch/bin/elasticsearch
  else
    echo "No valid token file found. Creating new token..."
  fi
fi

# Function to clean up old tokens based on age
cleanup_old_tokens() {
  if [ "$CLEANUP_OLD_TOKENS" = "true" ]; then
    echo "Cleaning up tokens older than $MAX_TOKEN_AGE_DAYS days..."
    
    # Get current timestamp
    current_time=$(date +%s)
    cutoff_time=$((current_time - (MAX_TOKEN_AGE_DAYS * 24 * 3600)))
    
    # List and clean old tokens
    $ES_BIN/elasticsearch-service-tokens list "$SERVICE_ACCOUNT" 2>/dev/null | grep "kibana-token-" | while read -r old_token_name; do
      # Extract timestamp from token name
      token_timestamp=$(echo "$old_token_name" | sed 's/kibana-token-//')
      
      # Check if it's a valid timestamp and if it's old enough
      if [[ "$token_timestamp" =~ ^[0-9]+$ ]] && [ "$token_timestamp" -lt "$cutoff_time" ]; then
        echo "Removing old token: $old_token_name (created: $(date -d @$token_timestamp 2>/dev/null || echo 'unknown'))"
        $ES_BIN/elasticsearch-service-tokens delete "$SERVICE_ACCOUNT" "$old_token_name" 2>/dev/null || true
      fi
    done
  fi
}

# Function to create token after ES is running
create_token_when_ready() {
  echo "Starting Elasticsearch in background..."
  /usr/share/elasticsearch/bin/elasticsearch &
  ES_PID=$!
  
  echo "Waiting for Elasticsearch to be ready..."
  # Wait for Elasticsearch to be ready (up to 2 minutes)
  for i in {1..24}; do
    if curl -s -k --cacert /etc/elasticsearch/certs/ca.crt -u "elastic:${ELASTIC_PASSWORD}" "https://localhost:9200/_cluster/health" > /dev/null 2>&1; then
      echo "Elasticsearch is ready!"
      break
    fi
    echo "Waiting for Elasticsearch... (attempt $i/24)"
    sleep 5
  done
  
  # Clean up old tokens
  cleanup_old_tokens
  
  # Generate the new token and extract it
  echo "Creating service token for $SERVICE_ACCOUNT with name: $TOKEN_NAME..."
  TOKEN_OUTPUT=$($ES_BIN/elasticsearch-service-tokens create "$SERVICE_ACCOUNT" "$TOKEN_NAME" 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "$TOKEN_OUTPUT" | grep "SERVICE_TOKEN" | cut -d'=' -f2 | tr -d ' ' > "$TOKEN_FILE"
    echo "New token created and saved to $TOKEN_FILE"
    echo "Token creation timestamp: $(date)"
    
    # Verify token was written correctly
    if [ -s "$TOKEN_FILE" ]; then
      echo "Token file verification: OK ($(wc -c < "$TOKEN_FILE") bytes)"
    else
      echo "ERROR: Token file is empty!"
      exit 1
    fi
  else
    echo "Failed to create token. Output: $TOKEN_OUTPUT"
    exit 1
  fi
  
  # Keep Elasticsearch running
  wait $ES_PID
}

# Run the function
create_token_when_ready
