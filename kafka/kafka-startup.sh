#!/bin/bash
set -e

echo "========================================="
echo "Kafka Startup Script"
echo "========================================="

# This script runs as root to fix permissions, then switches to kafka user

# Create and fix ownership of the data directory
echo "Setting up Kafka directories..."
mkdir -p /var/lib/kafka/data
mkdir -p /opt/kafka/logs

# CRITICAL FIX: Remove ALL test directories and prevent recreation
echo "Cleaning up problematic test directories..."
# Remove any directory that might cause deletion issues
find /var/lib/kafka/data -name "*test*" -type d -exec rm -rf {} + 2>/dev/null || true
find /var/lib/kafka/data -name "artemis-test*" -type d -exec rm -rf {} + 2>/dev/null || true
find /var/lib/kafka/data -name "final-test*" -type d -exec rm -rf {} + 2>/dev/null || true
# Also remove any previously failed delete attempts
find /var/lib/kafka/data -name "*-delete" -type d -exec rm -rf {} + 2>/dev/null || true

# Remove meta.properties to force clean start if needed
rm -f /var/lib/kafka/data/meta.properties 2>/dev/null || true

# Change ownership and set permissions
echo "Setting ownership and permissions..."
chown -R kafka:kafka /var/lib/kafka/data /opt/kafka/logs

# Fix permissions on directories and files - use more permissive settings for Kafka operations
# This ensures Kafka can create, rename, and delete directories/files as needed
chmod 775 /var/lib/kafka/data
find /var/lib/kafka/data -type d -exec chmod 775 {} \; 2>/dev/null || true
find /var/lib/kafka/data -type f -exec chmod 664 {} \; 2>/dev/null || true

# Ensure kafka user can write to parent directory
chmod 775 /var/lib/kafka
chown kafka:kafka /var/lib/kafka

# Set umask for new files to be more permissive (allow group write)
umask 002

echo "Kafka data directory setup completed."
echo "Kafka user: $(id kafka)"
echo "Data directory: $(ls -ld /var/lib/kafka/data)"

# Now switch to kafka user for the actual Kafka startup
echo "Switching to kafka user and starting Kafka..."
exec su -s /bin/bash kafka -c '
set -e

# Ensure umask is consistent with root settings (allow group write)
umask 002

# Export JVM options if set
if [ -n "$KAFKA_HEAP_OPTS" ]; then
    export KAFKA_HEAP_OPTS
fi
if [ -n "$KAFKA_JVM_PERFORMANCE_OPTS" ]; then
    export KAFKA_JVM_PERFORMANCE_OPTS
fi

# Wait for ZooKeeper to be available
echo "Waiting for ZooKeeper to be available..."
ZK_HOST=$(echo $KAFKA_ZOOKEEPER_CONNECT | cut -d: -f1)
ZK_PORT=$(echo $KAFKA_ZOOKEEPER_CONNECT | cut -d: -f2)

while ! nc -z $ZK_HOST $ZK_PORT; do
  echo "ZooKeeper is not available yet. Waiting..."
  sleep 2
done
echo "ZooKeeper is available!"

# Generate server.properties from environment variables
echo "Generating Kafka configuration..."
cat > /opt/kafka/config/server.properties << EOL
# Basic Kafka configuration
broker.id=1
log.dirs=/var/lib/kafka/data

# ZooKeeper connection
zookeeper.connect=${KAFKA_ZOOKEEPER_CONNECT}
zookeeper.connection.timeout.ms=18000

# Network and listeners
listeners=${KAFKA_LISTENERS}
advertised.listeners=${KAFKA_ADVERTISED_LISTENERS}
listener.security.protocol.map=${KAFKA_LISTENER_SECURITY_PROTOCOL_MAP}
inter.broker.listener.name=${KAFKA_INTER_BROKER_LISTENER_NAME}

# Performance optimizations
num.network.threads=8
num.io.threads=8
socket.send.buffer.bytes=1048576
socket.receive.buffer.bytes=1048576
socket.request.max.bytes=104857600

# Compression
compression.type=lz4
min.compressible.fetch.rate=1000

# Replication performance
num.replica.fetchers=4
replica.fetch.max.bytes=1048576
replica.fetch.wait.max.ms=500

# Log retention
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

# Enable log cleaner for compaction
log.cleaner.enable=true
log.cleaner.threads=2
log.cleaner.io.buffer.size=524288
log.cleanup.policy=delete
log.retention.ms=604800000

# Producer defaults for better batching
producer.linger.ms=100
producer.batch.size=32768
producer.buffer.memory=67108864

# Prevent broker shutdown on log directory failures - more robust settings
log.dir.failure.timeout.ms=60000
log.flush.interval.messages=1000000
log.flush.interval.ms=60000

# Topic deletion settings - handle failures gracefully
delete.topic.enable=true
controlled.shutdown.enable=false
log.cleaner.delete.retention.ms=86400000

# More robust log directory handling for testing environments  
log.dirs.recovery.timeout.ms=30000
log.retention.check.interval.ms=600000
log.cleanup.interval.ms=600000

# Reduce log segment size for faster cleanup during testing
log.segment.bytes=104857600

# Make broker more resilient to filesystem issues
unclean.leader.election.enable=false
min.insync.replicas=1

# Internal topic settings
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1

# Group coordinator settings
group.initial.rebalance.delay.ms=0

# Consumer performance settings
fetch.min.bytes=1
fetch.max.wait.ms=500
max.poll.records=500
max.poll.interval.ms=300000

# Request timeout settings
request.timeout.ms=30000
replica.lag.time.max.ms=10000

# Consumer fetch settings
replica.fetch.min.bytes=1
replica.fetch.wait.max.ms=500

# Session timeout for consumers
group.min.session.timeout.ms=6000
group.max.session.timeout.ms=300000

# Reduce metadata refresh interval for faster topic discovery
metadata.max.age.ms=300000

# Network request settings
connections.max.idle.ms=540000
EOL

# Add SSL configuration if keystore exists
if [ -n "${KAFKA_SSL_KEYSTORE_LOCATION}" ] && [ -f "${KAFKA_SSL_KEYSTORE_LOCATION}" ]; then
cat >> /opt/kafka/config/server.properties << EOL

# SSL Configuration
ssl.keystore.location=${KAFKA_SSL_KEYSTORE_LOCATION}
ssl.keystore.password=${KAFKA_SSL_KEYSTORE_PASSWORD}
ssl.truststore.location=${KAFKA_SSL_TRUSTSTORE_LOCATION}
ssl.truststore.password=${KAFKA_SSL_TRUSTSTORE_PASSWORD}
EOL
fi

echo "Starting Kafka with generated configuration..."
exec /opt/kafka/bin/kafka-server-start.sh /opt/kafka/config/server.properties
'