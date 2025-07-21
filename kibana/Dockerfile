# kibana/Dockerfile
FROM redhat/ubi8:latest

ARG CERT_DIR

RUN dnf update -y && \
    dnf install -y wget rpm sudo

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

RUN dnf install -y kibana

RUN usermod -p '$6$8ocVSChH4XIUpsnO$nQM6IdvdXI7FxclsX6gWi8chALtUCIpu3sHCT7bbBFD9FUpfYBYMEK5jk3.xsoekQAwu.ixuGKSHxddUMbg4O0' kibana

COPY kibana.yml /etc/kibana/kibana.yml
COPY certs/kibana.p12 /etc/kibana/kibana.p12
COPY certs/ca.crt /etc/kibana/ca.crt

COPY kibana-entrypoint.sh /usr/local/bin/kibana-entrypoint.sh
RUN chmod +x /usr/local/bin/kibana-entrypoint.sh

# Change ownership of Kibana directories
RUN chown -R kibana:kibana /etc/kibana

# Create the data directory and ensure proper permissions
RUN mkdir -p /usr/share/kibana/data && \
    chown -R kibana:kibana /usr/share/kibana/data && \
    chmod -R 755 /usr/share/kibana/data

EXPOSE 5601

# Don't switch to kibana user yet - we'll do it in the entrypoint after fixing permissions
# USER kibana

ARG KIBANA_PASSWORD

# SSL is disabled, so we don't need to set the keystore password
# RUN echo "$KIBANA_PASSWORD" | /usr/share/kibana/bin/kibana-keystore add server.ssl.keystore.password -x


CMD ["/usr/local/bin/kibana-entrypoint.sh"]
