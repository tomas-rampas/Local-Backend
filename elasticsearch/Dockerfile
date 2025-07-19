# elasticsearch/Dockerfile
FROM redhat/ubi8:latest

ARG CERT_DIR

RUN dnf update -y && \
    dnf install -y wget rpm

RUN rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch && \
    cat <<EOF > /etc/yum.repos.d/elasticsearch.repo
[elasticsearch-8.x]
name=Elasticsearch repository for 8.x packages
baseurl=https://artifacts.elastic.co/packages/8.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF

RUN dnf install -y elasticsearch

RUN usermod -p '$6$8ocVSChH4XIUpsnO$nQM6IdvdXI7FxclsX6gWi8chALtUCIpu3sHCT7bbBFD9FUpfYBYMEK5jk3.xsoekQAwu.ixuGKSHxddUMbg4O0' elasticsearch

COPY certs/elasticsearch.keystore.jks /etc/elasticsearch/certs/elasticsearch.keystore.jks
COPY certs/elasticsearch.truststore.jks /etc/elasticsearch/certs/elasticsearch.truststore.jks
COPY certs/ca.crt /etc/elasticsearch/certs/ca.crt
COPY elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
COPY generate-token.sh /usr/local/bin/generate-token.sh
RUN chmod +x /usr/local/bin/generate-token.sh

# RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN chown -R elasticsearch:elasticsearch /etc/elasticsearch/
RUN chown elasticsearch:elasticsearch /etc/elasticsearch/certs/elasticsearch.truststore.jks
RUN chown elasticsearch:elasticsearch /usr/local/bin/generate-token.sh

EXPOSE 9200

# Ensure the /shared directory exists
RUN mkdir -p /shared

# Set ownership to elasticsearch user
RUN chown elasticsearch:elasticsearch /shared

# Set permissions: writable by elasticsearch, readable by everyone
RUN chmod 755 /shared

# Switch to the elasticsearch user
USER elasticsearch

ARG ELASTIC_PASSWORD

RUN echo "y" | /usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.http.ssl.keystore.secure_password
RUN echo "$ELASTIC_PASSWORD" | /usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.http.ssl.keystore.secure_password
RUN echo "$ELASTIC_PASSWORD" | /usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.http.ssl.truststore.secure_password
RUN echo "y" | /usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.transport.ssl.keystore.secure_password
RUN echo "y" | /usr/share/elasticsearch/bin/elasticsearch-keystore remove xpack.security.transport.ssl.truststore.secure_password
RUN echo "$ELASTIC_PASSWORD" | /usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.transport.ssl.keystore.secure_password
RUN echo "$ELASTIC_PASSWORD" | /usr/share/elasticsearch/bin/elasticsearch-keystore add xpack.security.transport.ssl.truststore.secure_password
RUN echo "$ELASTIC_PASSWORD" | /usr/share/elasticsearch/bin/elasticsearch-keystore add bootstrap.password -x

CMD ["/bin/sh", "-c", "/usr/local/bin/generate-token.sh && /usr/share/elasticsearch/bin/elasticsearch"]

