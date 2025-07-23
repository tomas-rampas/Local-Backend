# Use Red Hat UBI 8 Minimal as the base image
FROM registry.access.redhat.com/ubi8/ubi-minimal:latest

# Install required packages
# Use proper package names for UBI minimal and handle errors
RUN microdnf update -y && \
    microdnf install -y curl ca-certificates && \
    # Try to install networking tools with fallbacks
    microdnf install -y procps-ng hostname && \
    # For ping
    microdnf install -y iputils || echo "iputils not available" && \
    # For nslookup/dig
    microdnf install -y bind-utils || echo "bind-utils not available" && \
    # For ifconfig/netstat
    microdnf install -y iproute || echo "iproute not available" && \
    # Clean up
    microdnf clean all

# Create a test script to check network connectivity
RUN echo '#!/bin/sh' > /usr/local/bin/test-network.sh && \
    echo 'echo "Host information:"' >> /usr/local/bin/test-network.sh && \
    echo 'hostname -I' >> /usr/local/bin/test-network.sh && \
    echo 'echo "Network routes:"' >> /usr/local/bin/test-network.sh && \
    echo 'ip route' >> /usr/local/bin/test-network.sh && \
    echo 'echo "Testing connection to elasticsearch:"' >> /usr/local/bin/test-network.sh && \
    echo 'getent hosts elasticsearch || echo "Cannot resolve elasticsearch"' >> /usr/local/bin/test-network.sh && \
    chmod +x /usr/local/bin/test-network.sh

# No CMD or ENTRYPOINT needed, as the command will be provided
# by docker-compose.yml at runtime.