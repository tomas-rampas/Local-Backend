# mongodb/Dockerfile
FROM redhat/ubi8:latest

RUN dnf update -y

# Add MongoDB repository
RUN cat <<EOF > /etc/yum.repos.d/mongodb-org-6.0.repo
[mongodb-org-6.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/8/mongodb-org/6.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-6.0.asc
EOF

# Install MongoDB (let Docker handle volume directories)
RUN dnf install -y mongodb-org

# Remove the systemctl line since it won't work in Docker

# Set up a non-root user (MongoDB's default is 999)
RUN useradd -u 999 -r -g 999 -s /sbin/nologin mongodb || echo "User mongodb already exists"

# MongoDB data volume
VOLUME ["/data/db", "/data/configdb"]

# MongoDB port
EXPOSE 27017

# Set entrypoint to mongod binary
# ENTRYPOINT ["mongod"]
CMD ["/usr/bin/mongod", "--bind_ip_all"]

# Default command (can be overridden by docker-compose.yml)
# CMD ["--bind_ip_all"]