# kafka/Dockerfile
FROM redhat/ubi8:latest
ARG CERT_DIR

RUN dnf update -y && \
    dnf install -y java-11-openjdk-headless wget unzip

RUN wget https://archive.apache.org/dist/kafka/3.6.1/kafka_2.13-3.6.1.tgz && \
    tar -xzf kafka_2.13-3.6.1.tgz -C /opt/ && \
    mv /opt/kafka_2.13-3.6.1 /opt/kafka && \
    rm kafka_2.13-3.6.1.tgz

EXPOSE 9092 9093

CMD ["/opt/kafka/bin/kafka-server-start.sh", "/opt/kafka/config/server.properties"]