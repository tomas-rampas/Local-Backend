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

# Create a non-root user (let Docker handle volume directories)  
RUN groupadd -r kafka && \
    useradd -r -g kafka kafka && \
    chown -R kafka:kafka /opt/kafka

# Optimize OS settings for Kafka performance
RUN echo "vm.swappiness=1" >> /etc/sysctl.conf && \
    echo "net.core.somaxconn=1024" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_max_syn_backlog=1024" >> /etc/sysctl.conf && \
    echo "net.core.netdev_max_backlog=2000" >> /etc/sysctl.conf && \
    echo "net.ipv4.tcp_fin_timeout=30" >> /etc/sysctl.conf

# Copy unified startup script
COPY kafka/kafka-startup.sh /kafka-startup.sh
RUN chmod +x /kafka-startup.sh

EXPOSE 9092 9093 9094

# Don't switch to kafka user here - entrypoint will handle it
# USER kafka

# Set volumes
# VOLUME ["/var/lib/kafka/data"]

# Use the unified startup script
ENTRYPOINT ["/kafka-startup.sh"]
