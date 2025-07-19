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

RUN dnf install -y mongodb-org-server

RUN systemctl enable mongod

EXPOSE 27017

CMD ["/usr/bin/mongod", "--bind_ip_all"]