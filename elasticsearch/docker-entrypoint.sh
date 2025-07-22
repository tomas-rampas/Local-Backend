#!/bin/bash
set -e

# Fix ownership of the data directory (run as root first)
chown -R elasticsearch:elasticsearch /var/lib/elasticsearch
chmod 755 /var/lib/elasticsearch

# Switch to elasticsearch user and continue with startup
exec su -s /bin/bash elasticsearch -c "/usr/local/bin/generate-token-enhanced.sh && /usr/share/elasticsearch/bin/elasticsearch"