# Troubleshooting Guide - Artemis Backend Tests

This guide addresses common issues encountered when running the diagnostic and test scripts.

## 🔍 Common Issues and Solutions

### MongoDB Test Failures

#### Issue: "Cannot index into a null array"
**Root Cause**: MongoDB command output parsing fails when results are empty or null.

**Fix Applied**: 
- Enhanced error handling in `Invoke-MongoCommand` function
- Safe array indexing in document counting and database listing
- Null-safe output parsing throughout the script

**Verification**: Run `./doctor/Test-MongoDB.ps1` to confirm fix.

### SQL Server Test Failures

#### Issue: Multiple test failures with command execution errors
**Root Cause**: Complex SQL queries with nested quotes cause command parsing issues.

**Fix Applied**:
- Implemented temporary file approach for complex queries
- Proper escaping of passwords and query content
- Enhanced error handling with meaningful messages
- Cross-platform compatible file handling

**Verification**: Run `./doctor/Test-SqlServer.ps1` to confirm fix.

### Kafka Test Issues

#### Issue: AccessDeniedException during topic deletion
**Root Cause**: Kafka internal cleanup processes and file system permissions.

**Error Messages**:
```
java.nio.file.AccessDeniedException: /var/lib/kafka/data/topic-name
Failed atomic move of topic directory
```

**Fix Applied**:
- Added delay before cleanup to allow Kafka to finalize operations
- Implemented retry logic for topic deletion (3 attempts)
- Enhanced error messages with guidance about automatic cleanup
- Graceful handling of partial cleanup success

**Verification**: Run `./doctor/Test-Kafka.ps1` to confirm fix.

## 🛠️ General Troubleshooting Steps

### 1. Container Status Check
```bash
docker-compose ps
```
Ensure all containers are running and healthy.

### 2. Service Logs Examination
```bash
# Check specific service logs
docker-compose logs elasticsearch
docker-compose logs mongodb
docker-compose logs kafka
docker-compose logs sqlserver

# Check recent logs with timestamps
docker-compose logs --tail=50 -t [service-name]
```

### 3. Network Connectivity
```bash
# Test if services are accessible
docker-compose exec mongodb mongosh --eval "db.adminCommand('ping')"
docker-compose exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '@rt3m1sD3v' -Q "SELECT 1"
docker-compose exec kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

### 4. Docker Resources
```bash
# Check Docker system resources
docker system df
docker system prune  # Clean up if needed

# Check container resource usage
docker stats
```

### 5. Environment Variables
Verify environment variables are properly set:
```bash
echo $LOCAL_BACKEND_BOOTSTRAP_PASSWORD
echo $SQLSERVER_SA_PASSWORD
echo $KIBANA_ENCRYPTION_KEY
```

## 🔧 Platform-Specific Issues

### Linux/WSL Issues

#### Docker Permission Denied
```bash
# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Or run with sudo (not recommended for production)
sudo docker-compose up
```

#### Script Permission Denied
```bash
# Make scripts executable
chmod +x doctor/*.ps1
```

#### PowerShell Not Found
```bash
# Install PowerShell 7
# Ubuntu/Debian:
sudo apt-get install -y powershell

# Verify installation
pwsh --version
```

### Windows Issues

#### PowerShell Execution Policy
```powershell
# Allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

#### Container Startup Issues
- Ensure Docker Desktop is running
- Check available memory (at least 8GB recommended)
- Verify WSL2 is enabled for better performance

## 🚨 Service-Specific Troubleshooting

### Elasticsearch
```bash
# Check cluster health
curl -k -u elastic:changeme https://localhost:9200/_cluster/health

# Check node status
curl -k -u elastic:changeme https://localhost:9200/_nodes/stats

# Common fixes:
# 1. Restart if yellow/red status
docker-compose restart elasticsearch

# 2. Clear data if corrupted (WARNING: destroys data)
docker-compose down
docker volume rm artemis_elasticsearch-data
docker-compose up -d
```

### MongoDB
```bash
# Test connection
docker-compose exec mongodb mongosh --eval "db.runCommand('ping')"

# Check database status
docker-compose exec mongodb mongosh --eval "db.stats()"

# Common fixes:
# 1. Restart if connection issues
docker-compose restart mongodb

# 2. Check disk space
docker-compose exec mongodb df -h
```

### Kafka
```bash
# List topics
docker-compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

# Check broker status
docker-compose exec kafka /opt/kafka/bin/kafka-broker-api-versions.sh --bootstrap-server localhost:9092

# Common fixes:
# 1. Restart Kafka and Zookeeper together
docker-compose restart zookeeper kafka

# 2. Clean up old topics (if test cleanup failed)
docker-compose exec kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --delete --topic [topic-name]
```

### SQL Server
```bash
# Test connection
docker-compose exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '@rt3m1sD3v' -Q "SELECT @@VERSION"

# Check database status
docker-compose exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '@rt3m1sD3v' -Q "SELECT name FROM sys.databases"

# Common fixes:
# 1. Restart if connection issues
docker-compose restart sqlserver

# 2. Check SQL Server logs
docker-compose logs sqlserver | grep -i error
```

## 📋 Best Practices

### Before Running Tests
1. Ensure all containers are healthy: `docker-compose ps`
2. Wait for services to fully initialize (30-60 seconds after startup)
3. Check available disk space and memory
4. Verify environment variables are set

### During Testing
1. Run individual service tests first to isolate issues
2. Use `-Verbose` flag for detailed output
3. Use `-SkipCleanup` to inspect test data after failures

### After Test Failures
1. Check service logs immediately: `docker-compose logs [service]`
2. Verify service is still running: `docker-compose ps`
3. Test basic connectivity manually
4. Review test output for specific error messages

### Regular Maintenance
1. Clean up test data periodically
2. Restart services if they become unresponsive
3. Update Docker images regularly
4. Monitor disk space usage

## 📞 Getting Additional Help

### Log Collection
When reporting issues, collect:
```bash
# System information
uname -a
docker version
docker-compose version
pwsh --version

# Service status
docker-compose ps
docker-compose logs --tail=100 [failing-service]

# Test output
./doctor/Test-[Service].ps1 -Verbose > test-output.log 2>&1
```

### Useful Commands for Debugging
```bash
# Interactive service access
docker-compose exec mongodb mongosh
docker-compose exec sqlserver /opt/mssql-tools/bin/sqlcmd -S localhost -U sa
docker-compose exec kafka bash
docker-compose exec elasticsearch bash

# Network inspection
docker network inspect artemis-network

# Volume inspection
docker volume ls | grep artemis
docker volume inspect artemis_[service]-data
```

## 🔄 Recovery Procedures

### Complete Reset
If all else fails, perform a complete reset:
```bash
# Stop all services
docker-compose down

# Remove all data volumes (WARNING: destroys all data)
docker-compose down -v

# Remove any orphaned containers
docker-compose down --remove-orphans

# Rebuild and restart
docker-compose up -d --build

# Wait for services to initialize, then run tests
sleep 60
./doctor/Run-AllTests.ps1
```

### Selective Reset
Reset specific services:
```bash
# Example: Reset MongoDB
docker-compose stop mongodb
docker volume rm artemis_mongodb-data
docker-compose up -d mongodb
```