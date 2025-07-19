# Docker Images Build and Push Guide

This guide explains how to build, tag, and push all Docker images from your docker-compose setup for reuse across different environments.

## Overview

Your docker-compose.yml has been updated to support automatic image tagging. All services now have `image` properties that use environment variables for flexible naming:

- **REGISTRY_PREFIX**: Your Docker Hub username, GitHub username, or registry URL (default: `tomasrampas`)
- **IMAGE_TAG**: Version tag for your images (default: `latest`)

## Quick Start

### 1. Build All Images

```powershell
# Build with default settings (tomasrampas/artemis-*:latest)
.\build-and-push-images.ps1

# Build with custom registry prefix
.\build-and-push-images.ps1 -RegistryPrefix "your-username"

# Build with specific version tag
.\build-and-push-images.ps1 -RegistryPrefix "your-username" -ImageTag "v1.0"
```

### 2. Build and Push to Registry

```powershell
# Build and push to Docker Hub
.\build-and-push-images.ps1 -RegistryPrefix "your-dockerhub-username" -PushImages

# Build and push to GitHub Container Registry
.\build-and-push-images.ps1 -RegistryPrefix "ghcr.io/your-github-username" -PushImages
```

## Manual Commands

### Using Docker Compose Directly

```bash
# Set environment variables
export REGISTRY_PREFIX=your-username
export IMAGE_TAG=v1.0

# Build all images
docker-compose build

# Push all images
docker-compose push

# Pull all images (on target machine)
docker-compose pull
```

### Using PowerShell

```powershell
# Set environment variables
$env:REGISTRY_PREFIX = "your-username"
$env:IMAGE_TAG = "v1.0"

# Build all images
docker-compose build

# Push all images
docker-compose push
```

## Registry Options

### Docker Hub (Public)
```powershell
# Login to Docker Hub
docker login

# Build and push
.\build-and-push-images.ps1 -RegistryPrefix "your-dockerhub-username" -PushImages
```

### GitHub Container Registry (Private/Public)
```powershell
# Login to GitHub Container Registry
docker login ghcr.io -u your-github-username

# Build and push
.\build-and-push-images.ps1 -RegistryPrefix "ghcr.io/your-github-username" -PushImages
```

### Azure Container Registry
```powershell
# Login to Azure Container Registry
az acr login --name your-registry-name

# Build and push
.\build-and-push-images.ps1 -RegistryPrefix "your-registry-name.azurecr.io" -PushImages
```

## Created Images

The following images will be created:

1. `{REGISTRY_PREFIX}/artemis-elasticsearch:{IMAGE_TAG}`
2. `{REGISTRY_PREFIX}/artemis-kibana:{IMAGE_TAG}`
3. `{REGISTRY_PREFIX}/artemis-elasticsearch-user-setup:{IMAGE_TAG}`
4. `{REGISTRY_PREFIX}/artemis-mongodb:{IMAGE_TAG}`
5. `{REGISTRY_PREFIX}/artemis-kafka:{IMAGE_TAG}`
6. `{REGISTRY_PREFIX}/artemis-zookeeper:{IMAGE_TAG}`
7. `{REGISTRY_PREFIX}/artemis-sqlserver:{IMAGE_TAG}`

## Using Images on Another Machine

### Method 1: Environment Variables
```powershell
# Set environment variables
$env:REGISTRY_PREFIX = "your-username"
$env:IMAGE_TAG = "v1.0"

# Pull and run
docker-compose pull
docker-compose up -d
```

### Method 2: .env File
Create a `.env` file in your project directory:
```
REGISTRY_PREFIX=your-username
IMAGE_TAG=v1.0
LOCAL_BACKEND_BOOTSTRAP_PASSWORD=changeme
```

Then run:
```bash
docker-compose pull
docker-compose up -d
```

### Method 3: Override at Runtime
```bash
REGISTRY_PREFIX=your-username IMAGE_TAG=v1.0 docker-compose pull
REGISTRY_PREFIX=your-username IMAGE_TAG=v1.0 docker-compose up -d
```

## Script Parameters

The `build-and-push-images.ps1` script supports the following parameters:

- `-RegistryPrefix`: Registry prefix/username (default: "tomasrampas")
- `-ImageTag`: Image tag/version (default: "latest")
- `-PushImages`: Push images to registry after building
- `-BuildOnly`: Only build images, skip push and usage instructions

### Examples

```powershell
# Build only (no push)
.\build-and-push-images.ps1 -BuildOnly

# Build and push with version tag
.\build-and-push-images.ps1 -RegistryPrefix "mycompany" -ImageTag "v2.1" -PushImages

# Build for GitHub Container Registry
.\build-and-push-images.ps1 -RegistryPrefix "ghcr.io/myusername" -ImageTag "latest" -PushImages
```

## Troubleshooting

### Authentication Issues
If you get authentication errors when pushing:

```bash
# For Docker Hub
docker login

# For GitHub Container Registry
docker login ghcr.io

# For Azure Container Registry
az acr login --name your-registry-name
```

### Image Not Found
If images aren't found after building, check:

1. Environment variables are set correctly
2. Docker daemon is running
3. Build completed without errors

### Push Failures
Common solutions:
1. Ensure you're logged into the correct registry
2. Check repository permissions (for private registries)
3. Verify the registry URL format

## Best Practices

1. **Use Version Tags**: Instead of `latest`, use semantic versioning like `v1.0`, `v1.1`, etc.
2. **Private Registries**: For production, use private registries like GitHub Container Registry or Azure Container Registry
3. **Multi-Architecture**: Consider building for multiple architectures if needed
4. **Image Size**: Optimize Dockerfiles to reduce image sizes
5. **Security**: Regularly update base images and scan for vulnerabilities

## Integration with CI/CD

You can integrate this into your CI/CD pipeline:

```yaml
# GitHub Actions example
- name: Build and Push Images
  run: |
    $env:REGISTRY_PREFIX = "ghcr.io/${{ github.repository_owner }}"
    $env:IMAGE_TAG = "${{ github.ref_name }}"
    .\build-and-push-images.ps1 -PushImages
```

This setup allows you to easily build, tag, and distribute your Docker images across different environments while maintaining consistency and flexibility.
