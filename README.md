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
- **PowerShell 7** (for cross-platform automation scripts and testing)
  - Windows: `winget install Microsoft.Powershell`
  - macOS: `brew install --cask powershell`
  - Linux: See installation guide in Testing section below
- **OpenSSL** (for certificate generation)
- **Java JDK** (optional, for JKS keystore generation)
- At least 8GB RAM available for containers

### 1. Clone and Setup

```bash
git clone https://github.com/your-username/Local-Backend.git
cd Local-Backend
```

### 2. Environment Configuration

Copy the example environment file and adjust values as needed:

```bash
cp .env_example .env
```

Edit the `.env` file with your configuration:

```env
# Artemis Backend Environment Configuration
# Copy this file to .env and adjust values as needed

# Registry Configuration
REGISTRY_PREFIX=ghcr.io/%user-name%
IMAGE_TAG=v1.2

# Security Configuration
LOCAL_BACKEND_BOOTSTRAP_PASSWORD=changeme
SQLSERVER_SA_PASSWORD=%PASSWORD%
KIBANA_ENCRYPTION_KEY=%ENCRYPTYION_KEY%

# Service Ports (customize if needed to avoid conflicts)
ELASTICSEARCH_PORT=9200
ELASTICSEARCH_TRANSPORT_PORT=9300
KIBANA_PORT=5601
MONGODB_PORT=27017
KAFKA_EXTERNAL_PORT=9094
ZOOKEEPER_PORT=2181
SQLSERVER_PORT=1433

# Elasticsearch User Configuration
ES_NEW_USER_NAME=artemis
ES_NEW_USER_ROLES='["logstash_admin", "kibana_user"]'

# MongoDB Configuration
MONGODB_ENABLE_AUTHENTICATION=false

# SQL Server Configuration
SQLSERVER_EDITION=Developer  # Options: Express, Developer, Standard, Enterprise

# Volume Configuration
SHARED_VOLUME_PATH=./shared

# Network Configuration (uncomment if you need custom subnet)
# NETWORK_SUBNET=172.28.0.0/16
# NETWORK_GATEWAY=172.28.0.1
# Alternative subnets if the above conflicts:
# - 10.100.0.0/16
# - 192.168.100.0/24
# - 172.30.0.0/16
```

**Important**: Replace the following placeholders:
- `%user-name%` - Your GitHub username or registry namespace
- `%PASSWORD%` - A secure password for SQL Server SA account
- `%ENCRYPTYION_KEY%` - A 32-byte encryption key for Kibana (you can generate one with: `openssl rand -hex 32`)

### 3. Generate Certificates (First Time)

```powershell
# Generate all SSL/TLS certificates
.\certs\Generate-AllCertificates.ps1

# For Linux/macOS
./certs/generate-all-certificates.sh
```

### 4. Start Services

```bash
# Build images and start all services (first time or when Dockerfiles change)
docker-compose up -d --build

# This command:
# - Builds all Docker images from source
# - Creates and starts all containers
# - Runs in detached mode (-d)

# Start services when images are already built
docker-compose up -d

# This command:
# - Uses existing built images
# - Creates and starts all containers
# - Faster than --build option

# Stop all services
docker-compose down

# This command:
# - Stops all running containers
# - Removes containers and networks
# - Preserves volumes and data

# Stop services and remove all data (DESTRUCTIVE!)
docker-compose down -v

# This command with -v flag:
# - Stops all running containers
# - Removes containers and networks
# - DELETES all volumes and persistent data
# - Use with caution - all data will be lost!

# View logs
docker-compose logs -f

# Check service status
docker-compose ps

# Run health tests (optional)
pwsh ./doctor/Run-AllTests.ps1
```

### 5. Access Services

- **Elasticsearch**: https://localhost:9200 (elastic/changeme)
- **Kibana**: http://localhost:5601
- **MongoDB**: mongodb://localhost:27017 (no auth in dev mode)
- **Kafka**: localhost:9094 (EXTERNAL listener)
- **SQL Server**: localhost:1433 (sa/[YOUR_PASSWORD])

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `REGISTRY_PREFIX` | `ghcr.io/%user-name%` | Docker registry prefix for images |
| `IMAGE_TAG` | `v1.2` | Version tag for Docker images |
| `LOCAL_BACKEND_BOOTSTRAP_PASSWORD` | `changeme` | Bootstrap password for Elasticsearch |
| `SQLSERVER_SA_PASSWORD` | `%PASSWORD%` | SQL Server SA password (must be set) |
| `KIBANA_ENCRYPTION_KEY` | `%ENCRYPTYION_KEY%` | Kibana encryption key (generate with `openssl rand -hex 32`) |
| `ES_NEW_USER_NAME` | `artemis` | New Elasticsearch user name |
| `ES_NEW_USER_ROLES` | `["logstash_admin", "kibana_user"]` | Roles for new Elasticsearch user |
| `MONGODB_ENABLE_AUTHENTICATION` | `false` | MongoDB authentication setting |
| `SQLSERVER_EDITION` | `Developer` | SQL Server edition (Express, Developer, Standard, Enterprise) |
| `SHARED_VOLUME_PATH` | `./shared` | Path for shared volume between services |

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

The project includes comprehensive SSL/TLS certificate management with automated generation:

```
certs/
├── Generate-AllCertificates.ps1  # Master certificate generation script
├── Clean-AllCertificates.ps1     # Certificate cleanup script
├── Install-CACertificate.ps1     # CA installation for Windows
├── README.md                     # Comprehensive certificate documentation
├── ca/                           # Certificate Authority
│   ├── ca.crt                   # CA certificate (sysSDSEnvCALocal)
│   ├── ca.key                   # CA private key
│   └── ca.pfx                   # CA PFX for development signing
├── elasticsearch/               # Elasticsearch certificates
│   ├── elasticsearch.crt        # Service certificate
│   ├── elasticsearch.key        # Service private key
│   ├── elasticsearch.p12        # PKCS#12 format
│   ├── elasticsearch.keystore.jks  # Java keystore
│   └── elasticsearch.truststore.jks # Java truststore
├── kibana/                      # Kibana certificates
│   ├── kibana.crt              # Service certificate
│   ├── kibana.key              # Service private key
│   └── kibana.p12              # PKCS#12 format
├── kafka/                       # Kafka certificates
│   ├── kafka.keystore.jks      # Java keystore
│   └── kafka.truststore.jks    # Java truststore
└── env/                         # Environment certificates (development)
    ├── sysSDSEnvLocal.crt      # Environment certificate
    ├── sysSDSEnvLocal.key      # Environment private key
    └── sysSDSEnvLocal.pfx      # PFX for development use
```

### Certificate Generation and Management

```powershell
# Generate all certificates with default settings
.\certs\Generate-AllCertificates.ps1

# Custom CA name and certificate passwords  
.\certs\Generate-AllCertificates.ps1 -CaName "MyCompanyCA" -CertPassword "SecurePass123"

# Skip CA installation to Windows trust store
.\certs\Generate-AllCertificates.ps1 -InstallCA:$false

# Clean all certificates (preview mode)
.\certs\Clean-AllCertificates.ps1 -WhatIf

# Force clean all certificates and remove CA from trust store
.\certs\Clean-AllCertificates.ps1 -Force -UninstallCA
```

### Cross-Platform Certificate Support

For Linux/macOS development:
```bash
# Linux/Unix certificate generation
./certs/generate-all-certificates.sh

# Make scripts executable
chmod +x certs/*.ps1
```

### ASP.NET Development Features

The certificate system supports ASP.NET development with certificate signing capabilities:

- **CA Certificate**: `sysSDSEnvCALocal` with proper CA extensions for certificate issuance
- **Environment Certificate**: `sysSDSEnvLocal` for local development (cannot be used for signing)
- **Windows Integration**: Automatic installation to both Root and Personal certificate stores
- **Development Signing**: CA certificate available with private key for ASP.NET certificate signing

See `certs/README.md` for comprehensive PowerShell verification scripts and troubleshooting commands.

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

### Certificate Management Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `Generate-AllCertificates.ps1` | Master certificate generation script | `.\certs\Generate-AllCertificates.ps1` |
| `Clean-AllCertificates.ps1` | Certificate cleanup and removal | `.\certs\Clean-AllCertificates.ps1 -Force` |
| `Install-CACertificate.ps1` | Install CA certificate on Windows | `.\certs\Install-CACertificate.ps1` |
| `generate-all-certificates.sh` | Linux/macOS certificate generation | `./certs/generate-all-certificates.sh` |

### Testing and Validation Suite

The `doctor/` directory contains comprehensive cross-platform testing scripts:

| Script | Purpose | Usage |
|--------|---------|-------|
| `Run-AllTests.ps1` | Complete test suite for all services | `pwsh ./doctor/Run-AllTests.ps1` |
| `Check-BackendHealth.ps1` | System diagnostics and health checks | `pwsh ./doctor/Check-BackendHealth.ps1` |
| `Test-Elasticsearch.ps1` | Elasticsearch functional tests | `pwsh ./doctor/Test-Elasticsearch.ps1` |
| `Test-MongoDB.ps1` | MongoDB functional tests | `pwsh ./doctor/Test-MongoDB.ps1` |
| `Test-Kafka.ps1` | Kafka functional tests | `pwsh ./doctor/Test-Kafka.ps1` |
| `Test-SqlServer.ps1` | SQL Server functional tests | `pwsh ./doctor/Test-SqlServer.ps1` |

#### Cross-Platform Testing Requirements

**PowerShell 7 Installation:**
```bash
# Linux (Ubuntu/Debian)
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update && sudo apt-get install -y powershell

# macOS
brew install --cask powershell

# Windows
winget install --id Microsoft.Powershell --source winget
```

**Running Tests:**
```bash
# Cross-platform execution
pwsh -File ./doctor/Run-AllTests.ps1

# With options
pwsh ./doctor/Run-AllTests.ps1 -IncludeServices "elasticsearch,mongodb"
pwsh ./doctor/Run-AllTests.ps1 -OutputFormat JSON -OutputFile "results.json"
pwsh ./doctor/Run-AllTests.ps1 -Parallel  # Experimental parallel execution
```

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
curl -k -u elastic:changeme https://localhost:9200/_cluster/health

# Verify certificates are properly mounted
docker-compose exec elasticsearch ls -la /usr/share/elasticsearch/config/certs/

# Test SSL connection
curl -k --cert-type P12 --cert /path/to/elasticsearch.p12:changeme https://localhost:9200
```

#### Kibana Authentication Problems
```bash
# Check token file exists
docker-compose exec kibana cat /shared/kibana_service_token.txt

# Restart Elasticsearch to regenerate token
docker-compose restart elasticsearch

# Check Kibana logs
docker-compose logs kibana
```

#### Certificate Issues
```powershell
# Verify certificates are installed in Windows store
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnv*" }

# Check certificate thumbprints for configuration
$caThumbprint = (Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnvCALocal*" }).Thumbprint
Write-Host "CA Thumbprint: $caThumbprint"

# Test certificate file integrity
if (Test-Path ".\certs\ca\ca.crt") {
    openssl x509 -in .\certs\ca\ca.crt -text -noout
}

# Regenerate certificates if corrupted
.\certs\Clean-AllCertificates.ps1 -Force
.\certs\Generate-AllCertificates.ps1
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

## 🔧 Test Script Fixes and Improvements

### Known Issues Resolved

#### MongoDB Test Script Issues
**Problem**: "Cannot index into a null array" errors
**Solution**: Added null-safe array operations and safe counting:
```powershell
# Safe array operations
$countMatches = $countResult.Output -split "`n" | Where-Object { $_ -match '^\d+$' }
$count = if ($countMatches) { $countMatches[0] } else { "0" }

# Safe join operations  
$error = if ($result) { $result -join "`n" } else { "Command failed with exit code $LASTEXITCODE" }
```

#### SQL Server Test Script Issues
**Problem**: Complex SQL queries with nested quotes causing parsing failures
**Solution**: Implemented temporary file method for complex queries:
```powershell
# Temporary file approach for complex queries
if ($Query) {
    $tempFile = [System.IO.Path]::GetTempFileName()
    $Query | Out-File -FilePath $tempFile -Encoding ASCII
    $dockerCommand = "cat '$tempFile' | docker-compose exec -T sqlserver /opt/mssql-tools/bin/sqlcmd -S $ServerHost,$ServerPort -U $Username -P '$Password' -d $Database -t $TimeoutSeconds"
}
```

#### Kafka Test Script Issues
**Problem**: AccessDeniedException during topic deletion and cleanup failures
**Solution**: Added retry logic with proper wait times:
```powershell
# Enhanced cleanup with retry logic
Write-Host "Waiting for Kafka to finalize operations..." -ForegroundColor Gray
Start-Sleep -Seconds 8

foreach ($topic in $topics) {
    $attempts = 0
    $maxAttempts = 3
    while ($attempts -lt $maxAttempts -and -not $deleteSuccess) {
        $attempts++
        # Attempt deletion with timeout and retry
        $deleteResult = Invoke-KafkaCommand -TimeoutSeconds 30
        if ($deleteResult.Success) {
            $deleteSuccess = $true
        } else {
            Start-Sleep -Seconds 5  # Wait before retry
        }
    }
}
```

### General Improvements Applied

#### Error Handling Patterns
All test scripts now follow consistent error handling:
- **Null-safe operations**: Always check for null before array operations
- **Explicit error handling**: Provide meaningful error messages  
- **Resource cleanup**: Proper cleanup of temporary files and resources
- **Timeout handling**: Prevent hanging operations
- **Retry logic**: Handle transient failures gracefully

#### Cross-Platform Compatibility
- **File path handling**: Use cross-platform compatible methods
- **Command escaping**: Proper escaping for different shells
- **Temporary file handling**: Safe creation and cleanup of temp files

### Testing the Fixes

Before running tests:
```bash
# Ensure all containers are running
docker-compose ps

# Wait for services to fully initialize (30-60 seconds)
sleep 60

# Check logs for any startup issues
docker-compose logs
```

Run individual service tests:
```bash
# Test each service individually
pwsh ./doctor/Test-MongoDB.ps1
pwsh ./doctor/Test-SqlServer.ps1  
pwsh ./doctor/Test-Kafka.ps1
pwsh ./doctor/Test-Elasticsearch.ps1
```

Run complete test suite:
```bash
# Run full test suite
pwsh ./doctor/Run-AllTests.ps1

# Run with verbose output for debugging
pwsh ./doctor/Run-AllTests.ps1 -Verbose

# Run with cleanup skipped to inspect test data
pwsh ./doctor/Run-AllTests.ps1 -SkipCleanup
```

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
- [Certificate Management Guide](certs/README.md) - Comprehensive certificate documentation with PowerShell verification scripts
- [Testing and Diagnostics Guide](doctor/README.md) - Cross-platform testing suite documentation
- [Elasticsearch Token Generation](elasticsearch/TOKEN-GENERATION-README.md)
- [CLAUDE.md](CLAUDE.md) - Complete project instructions and configuration guide

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

# Rebuild and restart a specific service
docker-compose up -d --build elasticsearch

# Recreate containers without rebuilding images
docker-compose up -d --force-recreate

# Run comprehensive health tests
pwsh ./doctor/Run-AllTests.ps1

# Check individual service health
pwsh ./doctor/Test-Elasticsearch.ps1
pwsh ./doctor/Test-MongoDB.ps1
pwsh ./doctor/Test-Kafka.ps1
pwsh ./doctor/Test-SqlServer.ps1

# Generate fresh certificates
.\certs\Generate-AllCertificates.ps1

# Monitor resource usage
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
```

---

**Project Repository**: https://github.com/tomas-rampas/Local-Backend

**Maintainer**: Tomas Rampas

**Last Updated**: January 2025
