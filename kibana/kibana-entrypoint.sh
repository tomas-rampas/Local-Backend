#!/bin/bash

# Read the token from the shared file
TOKEN_FILE="/shared/kibana_service_token.txt"
if [ -f "$TOKEN_FILE" ]; then
  export ELASTICSEARCH_SERVICEACCOUNTTOKEN=$(cat "$TOKEN_FILE")
  echo "Loaded service token from $TOKEN_FILE"
else
  echo "Token file $TOKEN_FILE not found. Kibana may fail to connect."
fi

# Read the token from the environment variable
if [ -z "$ELASTICSEARCH_SERVICEACCOUNTTOKEN" ]; then
  echo "Environment variable ELASTICSEARCH_SERVICEACCOUNTTOKEN is not set. Kibana may fail to connect."
else
  echo "Populating elasticsearch.serviceAccountToken in kibana.yml"
  sed -i "s|elasticsearch.serviceAccountToken:.*|elasticsearch.serviceAccountToken: \"$ELASTICSEARCH_SERVICEACCOUNTTOKEN\"|" /etc/kibana/kibana.yml
fi

# Start Kibana
exec /usr/share/kibana/bin/kibana