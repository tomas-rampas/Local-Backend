#!/bin/bash

# Fix permissions for mounted volumes
chown -R kafka:kafka /tmp/zookeeper/data /tmp/zookeeper/logs
chmod -R 755 /tmp/zookeeper

# Switch to kafka user and start ZooKeeper
exec runuser -u kafka -- /opt/kafka/bin/zookeeper-server-start.sh /opt/kafka/config/zookeeper.properties
