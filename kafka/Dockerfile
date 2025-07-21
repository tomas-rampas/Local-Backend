# kafka/Dockerfile
FROM redhat/ubi8:latest
ARG CERT_DIR

RUN dnf update -y && \
    dnf install -y java-11-openjdk-headless wget unzip nc && \
    dnf clean all

RUN wget https://archive.apache.org/dist/kafka/3.6.1/kafka_2.13-3.6.1.tgz && \
    tar -xzf kafka_2.13-3.6.1.tgz -C /opt/ && \
    mv /opt/kafka_2.13-3.6.1 /opt/kafka && \
    rm kafka_2.13-3.6.1.tgz

# Create a non-root user and directories
RUN groupadd -r kafka && \
    useradd -r -g kafka kafka && \
    mkdir -p /var/lib/kafka/data && \
    chown -R kafka:kafka /opt/kafka /var/lib/kafka

# Create startup script that handles environment variables
COPY kafka/start-kafka.sh /opt/kafka/start-kafka.sh
RUN chmod +x /opt/kafka/start-kafka.sh && \
    chown kafka:kafka /opt/kafka/start-kafka.sh

# Copy entrypoint script
COPY kafka/docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

EXPOSE 9092 9093 9094

# Don't switch to kafka user here - entrypoint will handle it
# USER kafka

# Set volumes
VOLUME ["/var/lib/kafka/data"]

# Use entrypoint to fix permissions before starting
ENTRYPOINT ["/docker-entrypoint.sh"]
