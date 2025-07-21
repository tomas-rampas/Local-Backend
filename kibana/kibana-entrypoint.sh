#!/bin/bash

# Fix permissions for the data directory (needed when volume is mounted)
# This runs as root before switching to kibana user
if [ -d "/usr/share/kibana/data" ]; then
    echo "Fixing permissions for /usr/share/kibana/data..."
    chown -R kibana:kibana /usr/share/kibana/data
    chmod -R 755 /usr/share/kibana/data
    echo "Permissions fixed for data directory"
fi

# Fix permissions for the shared volume
if [ -d "/shared" ]; then
    echo "Fixing permissions for /shared..."
    chown -R kibana:kibana /shared
    chmod -R 755 /shared
fi

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
    
    # Update encryption key if provided via environment variable
    echo "Checking for KIBANA_ENCRYPTION_KEY environment variable..."
    echo "KIBANA_ENCRYPTION_KEY value: ${KIBANA_ENCRYPTION_KEY:-NOT SET}"
    if [ -n "$KIBANA_ENCRYPTION_KEY" ]; then
      echo "Setting xpack.encryptedSavedObjects.encryptionKey from environment variable"
      sed -i "s|xpack.encryptedSavedObjects.encryptionKey:.*|xpack.encryptedSavedObjects.encryptionKey: \"$KIBANA_ENCRYPTION_KEY\"|" /etc/kibana/kibana.yml
      echo "Encryption key has been set in kibana.yml"
    else
      echo "KIBANA_ENCRYPTION_KEY environment variable is not set"
    fi
  else
    echo "Token file is empty!"
    exit 1
  fi
else
  echo "Token file $TOKEN_FILE not found after waiting. Kibana cannot connect to Elasticsearch."
  exit 1
fi

# Start Kibana as kibana user
echo "Starting Kibana as kibana user..."
exec sudo -u kibana /usr/share/kibana/bin/kibana
