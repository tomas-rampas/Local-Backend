# Elasticsearch Token Generation for Kibana

This directory contains scripts for automatically generating Elasticsearch service tokens for Kibana authentication on every container start.

## Files

- `generate-token.sh` - Modified original script that always generates new tokens
- `generate-token-enhanced.sh` - Enhanced version with configurable options
- `TOKEN-GENERATION-README.md` - This documentation file

## How It Works

### Current Setup (generate-token.sh)
The modified `generate-token.sh` script now:
1. **Always generates a new token** on container start (removed the existing token check)
2. **Cleans up old tokens** to prevent accumulation in Elasticsearch
3. **Uses timestamped token names** (`kibana-token-<timestamp>`) for uniqueness
4. **Saves the token** to `/shared/kibana_service_token.txt` for Kibana to read

### Enhanced Version (generate-token-enhanced.sh)
The enhanced script provides additional configuration options through environment variables:

#### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `FORCE_NEW_TOKEN` | `true` | Set to `false` to reuse existing valid tokens |
| `CLEANUP_OLD_TOKENS` | `true` | Set to `false` to keep old tokens |
| `MAX_TOKEN_AGE_DAYS` | `7` | Clean tokens older than this many days |

#### Usage Examples

**Default behavior (always generate new token):**
```yaml
elasticsearch:
  # ... other config
  environment:
    ELASTIC_PASSWORD: ${LOCAL_BACKEND_BOOTSTRAP_PASSWORD}
    # FORCE_NEW_TOKEN defaults to true
```

**Reuse existing tokens if available:**
```yaml
elasticsearch:
  # ... other config
  environment:
    ELASTIC_PASSWORD: ${LOCAL_BACKEND_BOOTSTRAP_PASSWORD}
    FORCE_NEW_TOKEN: "false"
```

**Custom token cleanup settings:**
```yaml
elasticsearch:
  # ... other config
  environment:
    ELASTIC_PASSWORD: ${LOCAL_BACKEND_BOOTSTRAP_PASSWORD}
    CLEANUP_OLD_TOKENS: "true"
    MAX_TOKEN_AGE_DAYS: "3"  # Clean tokens older than 3 days
```

## Switching to Enhanced Version

To use the enhanced version, update your Dockerfile CMD:

```dockerfile
# Current
CMD ["/bin/sh", "-c", "/usr/local/bin/generate-token.sh && /usr/share/elasticsearch/bin/elasticsearch"]

# Enhanced
CMD ["/bin/sh", "-c", "/usr/local/bin/generate-token-enhanced.sh && /usr/share/elasticsearch/bin/elasticsearch"]
```

## How Kibana Uses the Token

The Kibana container waits for the token file to be created and then:
1. Reads the token from `/shared/kibana_service_token.txt`
2. Updates its `kibana.yml` configuration with the new token
3. Starts Kibana with the fresh authentication token

## Benefits

### Security
- **Fresh tokens on restart**: Each container restart gets a new authentication token
- **Automatic cleanup**: Old tokens are removed to prevent accumulation
- **No manual token management**: Fully automated process

### Reliability
- **Consistent authentication**: Kibana always has a valid token
- **Container restart resilience**: Works seamlessly with Docker Compose restarts
- **Shared volume coordination**: Uses Docker volumes for secure token sharing

### Flexibility
- **Configurable behavior**: Environment variables control token generation
- **Development vs Production**: Different settings for different environments
- **Backward compatibility**: Original script still available

## Troubleshooting

### Token Generation Issues
1. Check Elasticsearch logs for token creation errors
2. Verify the `/shared` volume is properly mounted
3. Ensure `ELASTIC_PASSWORD` environment variable is set

### Kibana Connection Issues
1. Check if token file exists: `/shared/kibana_service_token.txt`
2. Verify token file is not empty
3. Check Kibana logs for authentication errors

### Container Startup Order
The setup relies on proper container dependencies:
1. Elasticsearch starts and generates token
2. Kibana waits for token file and then starts
3. Docker Compose `depends_on` ensures proper ordering

## Token Lifecycle

```
Container Start
    ↓
Remove old token file
    ↓
Start Elasticsearch
    ↓
Wait for ES to be ready
    ↓
Clean up old tokens (optional)
    ↓
Generate new service token
    ↓
Save token to shared file
    ↓
Kibana reads token and starts
```

## Security Considerations

- Tokens are stored in a shared Docker volume (not on host filesystem)
- Old tokens are automatically cleaned up
- Token names include timestamps for uniqueness
- Service account permissions are limited to Kibana's needs

## Migration from Manual Token Management

If you were previously managing tokens manually:
1. Remove any hardcoded tokens from configuration files
2. Ensure the shared volume is properly configured
3. Update container startup commands to use the token generation scripts
4. Test the full container restart cycle
