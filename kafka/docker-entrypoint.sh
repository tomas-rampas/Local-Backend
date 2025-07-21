#!/bin/bash

# This script runs as root to fix permissions, then switches to kafka user

# Fix ownership of the data directory
if [ -d "/var/lib/kafka/data" ]; then
    echo "Fixing permissions for /var/lib/kafka/data..."
    chown -R kafka:kafka /var/lib/kafka/data
    chmod -R 755 /var/lib/kafka/data
    echo "Permissions fixed."
fi

# Clean up any problematic files from previous runs
if [ -f "/var/lib/kafka/data/.kafka_cleanshutdown" ]; then
    echo "Removing old .kafka_cleanshutdown file..."
    rm -f /var/lib/kafka/data/.kafka_cleanshutdown
fi

# Now switch to kafka user and run the actual start script
echo "Starting Kafka as kafka user..."
exec su -s /bin/bash kafka -c "/opt/kafka/start-kafka.sh"