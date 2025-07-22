# zookeeper/Dockerfile
FROM redhat/ubi8:latest

# Install dependencies
RUN dnf update -y && \
    dnf install -y java-11-openjdk-headless wget unzip nc util-linux && \
    dnf clean all

# Download and install Kafka (which includes Zookeeper)
RUN wget https://archive.apache.org/dist/kafka/3.6.1/kafka_2.13-3.6.1.tgz && \
    tar -xzf kafka_2.13-3.6.1.tgz -C /opt/ && \
    mv /opt/kafka_2.13-3.6.1 /opt/kafka && \
    rm kafka_2.13-3.6.1.tgz

# Create a non-root user (let Docker handle volume directories)
RUN groupadd -r kafka && \
    useradd -r -g kafka kafka && \
    chown -R kafka:kafka /opt/kafka

# Create healthcheck script directly in the image
RUN echo '#!/bin/bash' > /opt/kafka/healthcheck.sh && \
    echo 'echo ruok | nc localhost 2181 | grep imok' >> /opt/kafka/healthcheck.sh && \
    chmod +x /opt/kafka/healthcheck.sh && \
    chown kafka:kafka /opt/kafka/healthcheck.sh

# Copy custom zookeeper properties and entrypoint script
COPY zookeeper/zookeeper.properties /opt/kafka/config/zookeeper.properties
COPY zookeeper/entrypoint.sh /opt/kafka/entrypoint.sh
RUN chmod +x /opt/kafka/entrypoint.sh

# Expose Zookeeper client port
EXPOSE 2181

# Set volumes
VOLUME ["/tmp/zookeeper/data", "/tmp/zookeeper/logs"]

# Add health check
HEALTHCHECK --interval=5s --timeout=5s --start-period=10s --retries=3 \
  CMD /opt/kafka/healthcheck.sh

# Start with entrypoint script (runs as root initially to fix permissions)
CMD ["/opt/kafka/entrypoint.sh"]
