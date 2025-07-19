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
COPY start-kafka.sh /opt/kafka/start-kafka.sh
RUN chmod +x /opt/kafka/start-kafka.sh && \
    chown kafka:kafka /opt/kafka/start-kafka.sh

EXPOSE 9092 9093 9094

# Use non-root user
USER kafka

# Set volumes
VOLUME ["/var/lib/kafka/data"]

CMD ["/opt/kafka/start-kafka.sh"]
