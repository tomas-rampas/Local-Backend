# Docker Compose Configuration Improvements

This document outlines the improvements made to the Docker Compose configuration for the Artemis Backend Services Stack.

## Key Improvements

### 1. **Extension Fields for Reusability**
- Added `x-common-variables` for shared environment variables
- Added `x-resource-limits` for consistent resource management
- Added `x-healthcheck-defaults` for standardized health checks
- These reduce duplication and make maintenance easier

### 2. **Named Volumes Instead of Bind Mounts**
```yaml
# Before (bind mount):
volumes:
  - ./sqlserver/backup:/var/opt/mssql/backup

# After (named volume):
volumes:
  - sqlserver-backup:/var/opt/mssql/backup
```

**Benefits:**
- Better portability across different environments
- Improved performance on Windows and macOS
- Easier backup and migration
- Docker manages permissions automatically
- Volumes persist even if containers are removed

### 3. **Environment Variable Configuration**
- All hardcoded values replaced with environment variables
- Default values provided for all variables
- Sensitive data (passwords) moved to environment variables
- Port numbers configurable to avoid conflicts

### 4. **Enhanced Volume Configuration**
```yaml
volumes:
  shared-volume:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${SHARED_VOLUME_PATH:-./shared}
```
- Explicit driver configuration
- Configurable paths via environment variables
- Clear separation between shared and service-specific volumes

### 5. **Improved Network Configuration**
```yaml
networks:
  artemis-network:
    driver: bridge
    # Custom subnet is optional - uncomment if needed
    # ipam:
    #   driver: default
    #   config:
    #     - subnet: ${NETWORK_SUBNET:-172.28.0.0/16}
    #       gateway: ${NETWORK_GATEWAY:-172.28.0.1}
    driver_opts:
      com.docker.network.bridge.name: artemis_bridge
      com.docker.network.bridge.enable_icc: "true"
      com.docker.network.bridge.enable_ip_masquerade: "true"
```
- Custom subnet configuration is optional to avoid conflicts
- By default, Docker will automatically assign a non-conflicting subnet
- Named bridge for easier identification
- Explicit inter-container communication settings
- If you need a custom subnet, uncomment the IPAM section and set it in your .env file

### 6. **Resource Management**
- Added memory limits and reservations for all services
- Prevents services from consuming all available memory
- Ensures minimum resources are available for each service

### 7. **Health Checks**
- Added health checks for MongoDB and SQL Server
- Standardized health check intervals and timeouts
- Better dependency management between services

### 8. **Security Improvements**
- Read-only volume mounts where write access isn't needed (`:ro`)
- Removed hardcoded passwords
- Better isolation between services

### 9. **Additional Service Improvements**

#### SQL Server:
- Added logs volume for better debugging
- Added health check using sqlcmd
- Configurable SQL Server edition
- Proper resource limits for SQL Server requirements

#### MongoDB:
- Added health check using mongosh
- Resource reservations to ensure stable operation

#### All Services:
- Consistent stop grace periods
- Better error handling in setup scripts
- Configurable ports to avoid conflicts

## Usage Instructions

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and set your passwords and configuration:
   ```bash
   # Edit the file and set secure passwords
   nano .env
   ```

3. Create the shared volume directory:
   ```bash
   mkdir -p ./shared
   ```

4. Start the services:
   ```bash
   docker-compose -f docker-compose-improved.yml up -d
   ```

## Migration from Old Configuration

If migrating from the old configuration:

1. **Backup existing data** from bind mount directories
2. **Stop all services**: `docker-compose down`
3. **Create named volumes** and restore data if needed
4. **Update environment variables** in `.env`
5. **Start services** with new configuration

## Best Practices Implemented

1. **12-Factor App Principles**: Configuration via environment variables
2. **Immutable Infrastructure**: Named volumes separate data from containers
3. **Security**: No hardcoded credentials, least privilege access
4. **Scalability**: Resource limits prevent resource exhaustion
5. **Maintainability**: DRY principle with extension fields
6. **Monitoring**: Comprehensive health checks for all services
7. **Portability**: Works consistently across different environments

## Performance Considerations

- Named volumes provide better I/O performance than bind mounts on non-Linux systems
- Resource limits prevent memory exhaustion and improve stability
- Health checks ensure services are ready before dependent services start
- Proper network configuration reduces overhead

## Troubleshooting

If you encounter issues:

1. Check logs: `docker-compose -f docker-compose-improved.yml logs [service-name]`
2. Verify environment variables: `docker-compose -f docker-compose-improved.yml config`
3. Check volume permissions: Named volumes handle this automatically
4. Ensure ports are not already in use: Configure different ports in `.env`
5. Verify network connectivity: Use the custom subnet if default conflicts
