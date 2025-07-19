#!/bin/bash

# Wait for the token file to be available
TOKEN_FILE="/shared/kibana_service_token.txt"
echo "Waiting for service token file..."

# Wait up to 5 minutes for the token file to be created
for i in {1..60}; do
  if [ -f "$TOKEN_FILE" ]; then
    echo "Token file found!"
    break
  fi
  echo "Waiting for token file... (attempt $i/60)"
  sleep 5
done

# Read the token from the shared file
if [ -f "$TOKEN_FILE" ]; then
  ELASTICSEARCH_SERVICEACCOUNTTOKEN=$(cat "$TOKEN_FILE")
  echo "Loaded service token from $TOKEN_FILE"
  
  if [ -n "$ELASTICSEARCH_SERVICEACCOUNTTOKEN" ]; then
    echo "Populating elasticsearch.serviceAccountToken in kibana.yml"
    sed -i "s|elasticsearch.serviceAccountToken:.*|elasticsearch.serviceAccountToken: \"$ELASTICSEARCH_SERVICEACCOUNTTOKEN\"|" /etc/kibana/kibana.yml
    echo "Token successfully configured in kibana.yml"
  else
    echo "Token file is empty!"
    exit 1
  fi
else
  echo "Token file $TOKEN_FILE not found after waiting. Kibana cannot connect to Elasticsearch."
  exit 1
fi

# Start Kibana
echo "Starting Kibana..."
exec /usr/share/kibana/bin/kibana
