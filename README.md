# Artemis Local Backend

A comprehensive Docker-based local development environment providing a complete backend infrastructure stack with Elasticsearch, Kibana, MongoDB, Kafka, Zookeeper, and SQL Server.

## 🏗️ Architecture Overview

This project provides a containerized backend infrastructure stack designed for local development and testing. All services are orchestrated using Docker Compose and can be easily deployed, scaled, and distributed.

### Services Included

| Service | Port | Description | Image |
|---------|------|-------------|-------|
| **Elasticsearch** | 9200, 9300 | Search and analytics engine with security enabled | `artemis-elasticsearch` |
| **Kibana** | 5601 | Data visualization and management for Elasticsearch | `artemis-kibana` |
| **MongoDB** | 27017 | NoSQL document database | `artemis-mongodb` |
| **Apache Kafka** | 9094 | Distributed streaming platform | `artemis-kafka` |
| **Zookeeper** | 2181 | Coordination service for Kafka | `artemis-zookeeper` |
| **SQL Server** | 1433 | Microsoft SQL Server database | `artemis-sqlserver` |

## 🚀 Quick Start

### Prerequisites

- Docker Desktop installed and running
- Docker Compose v3.8 or higher
- PowerShell (for Windows automation scripts)
- At least 8GB RAM available for containers

### 1. Clone and Setup

```bash
git clone https://github.com/tomas-rampas/Local-Backend.git
cd Local-Backend
```

### 2. Environment Configuration

Create a `.env` file in the project root:

```env
# Registry Configuration
REGISTRY_PREFIX=tomasrampas
IMAGE_TAG=latest

# Security Configuration
LOCAL_BACKEND_BOOTSTRAP_PASSWORD=changeme123!
```

### 3. Start Services

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### 4. Access Services

- **Elasticsearch**: https://localhost:9200 (elastic/changeme123!)
- **Kibana**: http://localhost:5601
- **MongoDB**: mongodb://localhost:27017
- **Kafka**: localhost:9094
- **SQL Server**: localhost:1433 (sa/@rt3m1sD3v)

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REGISTRY_PREFIX` | `tomasrampas` | Docker registry prefix for images |
| `IMAGE_TAG` | `latest` | Version tag for Docker images |
| `LOCAL_BACKEND_BOOTSTRAP_PASSWORD` | - | Master password for Elasticsearch and other services |

### Security Features

#### SSL/TLS Certificates
- **Elasticsearch**: Full SSL/TLS encryption with custom CA
- **Kibana**: SSL-enabled communication with Elasticsearch
- **Kafka**: SSL keystore and truststore configuration
- **Certificate Management**: Automated certificate generation and management

#### Authentication
- **Elasticsearch**: Built-in security with user management
- **Kibana**: Service token-based authentication
- **Automatic User Setup**: Dedicated container for user provisioning

## 📦 Docker Images

### Building Images

```powershell
# Build all images locally
.\build-and-push-images.ps1

# Build with custom registry
.\build-and-push-images.ps1 -RegistryPrefix "your-username" -ImageTag "v1.0"

# Build and push to registry
.\build-and-push-images.ps1 -RegistryPrefix "your-username" -PushImages
```

### Using Pre-built Images

```bash
# Pull images from registry
docker-compose pull

# Start with pulled images
docker-compose up -d
```

## 🌐 Distribution and Deployment

### GitHub Container Registry

Upload your images to GitHub Container Registry for easy distribution:

```powershell
# Quick upload to GitHub Container Registry
.\push-to-github-registry.ps1 -GitHubUsername "your-github-username"

# With specific version
.\push-to-github-registry.ps1 -GitHubUsername "your-username" -ImageTag "v1.0"
```

### Using Distributed Images

On target machines:

```bash
# Set environment variables
export REGISTRY_PREFIX=ghcr.io/your-username
export IMAGE_TAG=v1.0
export LOCAL_BACKEND_BOOTSTRAP_PASSWORD=your-secure-password

# Login to registry
docker login ghcr.io -u your-username

# Deploy
docker-compose pull
docker-compose up -d
```

## 🔍 Service Details

### Elasticsearch

- **Version**: Latest with security features
- **Features**: 
  - SSL/TLS encryption
  - User authentication
  - Automatic token generation for Kibana
  - Health checks
  - Data persistence
- **Memory Limit**: 2GB
- **Certificates**: Custom CA with client certificates

### Kibana

- **Features**:
  - Automatic Elasticsearch integration
  - Service token authentication
  - SSL communication
  - Data visualization
- **Dependencies**: Waits for Elasticsearch health check

### MongoDB

- **Configuration**:
  - Authentication disabled for development
  - WiredTiger cache: 512MB
  - Data persistence enabled
- **Memory Limit**: 1GB

### Kafka & Zookeeper

- **Kafka Features**:
  - Multiple listener configuration
  - SSL support (configurable)
  - External access on port 9094
  - Health checks
- **Zookeeper**: Coordination service with health monitoring

### SQL Server

- **Configuration**:
  - Developer edition
  - SA authentication
  - Data and backup persistence
  - EULA acceptance automated

## 🛠️ Development Features

### Health Checks

All services include comprehensive health checks:
- **Elasticsearch**: Cluster health monitoring
- **Kafka**: Broker API version checks
- **Zookeeper**: Custom health check script

### Data Persistence

All service data is persisted using Docker volumes:
- Elasticsearch data and logs
- MongoDB data and config
- Kafka and Zookeeper data
- SQL Server data and backups
- Kibana configuration

### Networking

- **Custom Bridge Network**: `artemis-network`
- **Service Discovery**: All services accessible by name
- **Aliases**: Multiple network aliases for flexibility

## 🔐 Security Configuration

### Certificate Management

The project includes comprehensive SSL/TLS certificate management:

```
certs/
├── ca.crt                    # Certificate Authority
├── ca.key                    # CA Private Key
├── elasticsearch.crt         # Elasticsearch Certificate
├── elasticsearch.key         # Elasticsearch Private Key
├── elasticsearch.p12         # PKCS#12 format
├── kibana.crt               # Kibana Certificate
├── kibana.key               # Kibana Private Key
├── kafka.keystore.jks       # Kafka Keystore
└── kafka.truststore.jks     # Kafka Truststore
```

### PowerShell Certificate Scripts

- `Create-Ceritifcatesp12.ps1`: Generate PKCS#12 certificates
- `Create-Jks.ps1`: Create Java KeyStore files
- `Install-CACertificate.ps1`: Install CA certificate on Windows

### Elasticsearch Security

- **Built-in Security**: X-Pack security enabled
- **User Management**: Automated user creation
- **Service Tokens**: Automatic token generation for Kibana
- **Role-based Access**: Configurable user roles

## 📋 Management Scripts

### Build and Push Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `build-and-push-images.ps1` | Build and optionally push all images | `.\build-and-push-images.ps1 -PushImages` |
| `push-to-github-registry.ps1` | Upload to GitHub Container Registry | `.\push-to-github-registry.ps1 -GitHubUsername "user"` |

### Certificate Management

| Script | Purpose | Location |
|--------|---------|----------|
| `Create-Ceritifcatesp12.ps1` | Generate PKCS#12 certificates | `certs/` |
| `Create-Jks.ps1` | Create Java KeyStore files | `certs/` |
| `Install-CACertificate.ps1` | Install CA on Windows | `certs/` |

## 🚨 Troubleshooting

### Common Issues

#### Services Won't Start
```bash
# Check Docker daemon
docker info

# Check available resources
docker system df

# View service logs
docker-compose logs [service-name]
```

#### Elasticsearch Connection Issues
```bash
# Check Elasticsearch health
curl -k -u elastic:your-password https://localhost:9200/_cluster/health

# Verify certificates
docker-compose exec elasticsearch ls -la /etc/elasticsearch/certs/
```

#### Kibana Authentication Problems
```bash
# Check token file
docker-compose exec kibana cat /shared/kibana_service_token.txt

# Restart Elasticsearch to regenerate token
docker-compose restart elasticsearch
```

#### Memory Issues
```bash
# Check container resource usage
docker stats

# Increase Docker Desktop memory allocation
# Docker Desktop → Settings → Resources → Memory
```

### Port Conflicts

If ports are already in use, modify `docker-compose.yml`:

```yaml
services:
  elasticsearch:
    ports:
      - "9201:9200"  # Change external port
```

### Performance Optimization

#### For Development
```yaml
# Reduce memory limits in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 1g  # Reduce from 2g
```

#### For Production
- Increase memory limits
- Use external volumes for data persistence
- Configure proper backup strategies

## 📊 Monitoring and Logging

### Log Locations

All logs are persisted to the host filesystem:

```
elasticsearch/logs/    # Elasticsearch logs
zookeeper/logs/       # Zookeeper logs
kibana/data/          # Kibana logs and data
```

### Monitoring Endpoints

- **Elasticsearch Health**: `GET https://localhost:9200/_cluster/health`
- **Elasticsearch Stats**: `GET https://localhost:9200/_cluster/stats`
- **Kafka Topics**: Use Kafka CLI tools or Kibana

### Log Analysis

Use Kibana to analyze logs from all services:
1. Access Kibana at http://localhost:5601
2. Create index patterns for your data
3. Use Discover and Visualize features

## 🔄 Backup and Recovery

### Data Backup

```bash
# Stop services
docker-compose down

# Backup data directories
tar -czf backup-$(date +%Y%m%d).tar.gz \
  elasticsearch/data \
  mongodb/data \
  kafka/data \
  sqlserver/data

# Restart services
docker-compose up -d
```

### Configuration Backup

```bash
# Backup certificates and configuration
tar -czf config-backup-$(date +%Y%m%d).tar.gz \
  certs/ \
  elasticsearch/elasticsearch.yml \
  kibana/kibana.yml \
  docker-compose.yml \
  .env
```

## 🚀 Production Deployment

### Simplified Production Compose

For production deployment, create a simplified `docker-compose.prod.yml`:

```yaml
version: '3.8'
services:
  elasticsearch:
    image: ${REGISTRY_PREFIX}/artemis-elasticsearch:${IMAGE_TAG}
    ports:
      - "9200:9200"
    environment:
      ELASTIC_PASSWORD: ${ELASTIC_PASSWORD}
    volumes:
      - es-data:/usr/share/elasticsearch/data
    networks:
      - artemis-network

  # ... other services (simplified)

volumes:
  es-data:
  mongo-data:
  kafka-data:

networks:
  artemis-network:
```

### Environment Variables for Production

```env
REGISTRY_PREFIX=ghcr.io/your-org
IMAGE_TAG=v1.0.0
ELASTIC_PASSWORD=secure-production-password
```

## 🤝 Contributing

### Development Setup

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with `docker-compose up -d`
5. Submit a pull request

### Adding New Services

1. Create service directory with Dockerfile
2. Add service to `docker-compose.yml`
3. Update build scripts
4. Add documentation
5. Test integration

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🆘 Support

### Documentation

- [Docker Images Guide](README-Docker-Images.md)
- [GitHub Registry Guide](GitHub-Registry-Guide.md)
- [Elasticsearch Token Generation](elasticsearch/TOKEN-GENERATION-README.md)

### Getting Help

1. Check the troubleshooting section above
2. Review service logs: `docker-compose logs [service]`
3. Open an issue on GitHub
4. Check Docker and service-specific documentation

### Useful Commands

```bash
# View all containers
docker-compose ps

# Follow logs for all services
docker-compose logs -f

# Restart a specific service
docker-compose restart elasticsearch

# Scale a service
docker-compose up -d --scale kafka=2

# Remove all containers and volumes
docker-compose down -v

# Rebuild and restart
docker-compose up -d --build
```

---

**Project Repository**: https://github.com/tomas-rampas/Local-Backend

**Maintainer**: Tomas Rampas

**Last Updated**: January 2025
