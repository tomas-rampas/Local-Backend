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
  
  # Generate the token and extract it
  echo "Creating service token for $SERVICE_ACCOUNT..."
  TOKEN_OUTPUT=$($ES_BIN/elasticsearch-service-tokens create "$SERVICE_ACCOUNT" "$TOKEN_NAME" 2>/dev/null)
  
  if [ $? -eq 0 ]; then
    echo "$TOKEN_OUTPUT" | grep "SERVICE_TOKEN" | cut -d'=' -f2 | tr -d ' ' > "$TOKEN_FILE"
    echo "Token created and saved to $TOKEN_FILE"
    cat "$TOKEN_FILE"
  else
    echo "Failed to create token. Output: $TOKEN_OUTPUT"
    exit 1
  fi
  
  # Keep Elasticsearch running
  wait $ES_PID
}

# Run the function
create_token_when_ready
