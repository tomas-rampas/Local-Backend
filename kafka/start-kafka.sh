#!/bin/bash

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

# Log settings
num.network.threads=3
num.io.threads=8
socket.send.buffer.bytes=102400
socket.receive.buffer.bytes=102400
socket.request.max.bytes=104857600

# Log retention
log.retention.hours=168
log.segment.bytes=1073741824
log.retention.check.interval.ms=300000

# Internal topic settings
offsets.topic.replication.factor=1
transaction.state.log.replication.factor=1
transaction.state.log.min.isr=1

# Group coordinator settings
group.initial.rebalance.delay.ms=0
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
