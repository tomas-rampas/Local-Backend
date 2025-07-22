#!/bin/bash

# This script runs as root to fix permissions, then switches to kafka user

# Fix ownership of the data directory - ensure all subdirectories can be managed
if [ -d "/var/lib/kafka/data" ]; then
    echo "Fixing permissions for /var/lib/kafka/data..."
    
    # Create the directory if it doesn't exist
    mkdir -p /var/lib/kafka/data
    
    # Change ownership recursively with force
    chown -R kafka:kafka /var/lib/kafka/data
    
    # Set proper permissions - kafka user needs full write access for rename/delete operations
    chmod -R 755 /var/lib/kafka/data
    
    # Clean up any existing problematic topic directories that might cause issues
    rm -rf /var/lib/kafka/data/artemis-test-* 2>/dev/null || true
    
    # Ensure kafka user has full control over the data directory
    chmod 755 /var/lib/kafka/data
    
    echo "Data directory permissions setup completed."
    echo "Kafka user: $(id kafka)"
    echo "Data directory ownership: $(ls -ld /var/lib/kafka/data)"
fi

# Fix ownership of the logs directory 
if [ -d "/opt/kafka/logs" ]; then
    echo "Fixing permissions for /opt/kafka/logs..."
    chown -R kafka:kafka /opt/kafka/logs 2>/dev/null || echo "Note: Could not change ownership (bind mount)"
    chmod -R 755 /opt/kafka/logs 2>/dev/null || echo "Note: Could not change permissions (bind mount)"
    echo "Logs directory permissions setup completed."
fi

# Clean up any problematic files from previous runs
if [ -f "/var/lib/kafka/data/.kafka_cleanshutdown" ]; then
    echo "Removing old .kafka_cleanshutdown file..."
    rm -f /var/lib/kafka/data/.kafka_cleanshutdown
fi

# Set a proper umask to ensure new directories have correct permissions
umask 022

# Now switch to kafka user and run the actual start script
echo "Starting Kafka as kafka user..."
exec su -s /bin/bash kafka -c "umask 022 && /opt/kafka/start-kafka.sh"