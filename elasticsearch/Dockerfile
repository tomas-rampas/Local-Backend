# elasticsearch/Dockerfile
FROM redhat/ubi8:latest

ARG CERT_DIR

RUN dnf update -y && \
    dnf install -y wget rpm curl

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

COPY certs/elasticsearch/elasticsearch.keystore.jks /etc/elasticsearch/certs/elasticsearch.keystore.jks
COPY certs/elasticsearch/elasticsearch.truststore.jks /etc/elasticsearch/certs/elasticsearch.truststore.jks
COPY certs/ca/ca.crt /etc/elasticsearch/certs/ca.crt
COPY elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml
COPY elasticsearch/generate-token.sh /usr/local/bin/generate-token.sh
COPY elasticsearch/generate-token-enhanced.sh /usr/local/bin/generate-token-enhanced.sh
RUN chmod +x /usr/local/bin/generate-token.sh
RUN chmod +x /usr/local/bin/generate-token-enhanced.sh

# RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN chown -R elasticsearch:elasticsearch /etc/elasticsearch/
RUN chown elasticsearch:elasticsearch /etc/elasticsearch/certs/elasticsearch.truststore.jks
RUN chown elasticsearch:elasticsearch /usr/local/bin/generate-token.sh
RUN chown elasticsearch:elasticsearch /usr/local/bin/generate-token-enhanced.sh

EXPOSE 9200

# Ensure the /shared directory exists
RUN mkdir -p /shared

# Set ownership to elasticsearch user
RUN chown elasticsearch:elasticsearch /shared

# Set permissions: writable by elasticsearch, readable by everyone
RUN chmod 755 /shared

# Ensure the Elasticsearch data directory exists with correct permissions
RUN mkdir -p /var/lib/elasticsearch
RUN chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
RUN chmod 755 /var/lib/elasticsearch

# Copy and set up the entrypoint script
COPY elasticsearch/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Switch to elasticsearch user for keystore operations
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

# Switch back to root for the entrypoint script to handle permissions
USER root

CMD ["/usr/local/bin/docker-entrypoint.sh"]
