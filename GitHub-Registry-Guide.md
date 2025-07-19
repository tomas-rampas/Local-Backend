# GitHub Container Registry Upload Guide

This guide shows you exactly how to upload your Docker images to GitHub Container Registry (ghcr.io).

## 🚀 Quick Start (Easiest Method)

### Step 1: Run the GitHub Registry Script
```powershell
.\push-to-github-registry.ps1 -GitHubUsername "your-github-username"
```

That's it! The script will:
- Prompt you to login to GitHub Container Registry
- Build all your images
- Push them to `ghcr.io/your-username/artemis-*`

## 📋 Prerequisites

### 1. Create a GitHub Personal Access Token
1. Go to https://github.com/settings/tokens
2. Click **"Generate new token (classic)"**
3. Give it a name like "Docker Registry Access"
4. Select these scopes:
   - ✅ `write:packages` (to push images)
   - ✅ `read:packages` (to pull images)
5. Click **"Generate token"**
6. **Copy the token immediately** (you won't see it again!)

### 2. Make Sure Docker is Running
- Ensure Docker Desktop is running on your machine

## 🔧 Manual Method (Step by Step)

If you prefer to do it manually:

### Step 1: Login to GitHub Container Registry
```powershell
docker login ghcr.io -u your-github-username
# When prompted for password, paste your Personal Access Token
```

### Step 2: Set Environment Variables
```powershell
$env:REGISTRY_PREFIX = "ghcr.io/your-github-username"
$env:IMAGE_TAG = "latest"  # or "v1.0", etc.
```

### Step 3: Build and Push
```powershell
# Build all images
docker-compose build

# Push all images
docker-compose push
```

## 📦 What Gets Uploaded

Your images will be uploaded as:
- `ghcr.io/your-username/artemis-elasticsearch:latest`
- `ghcr.io/your-username/artemis-kibana:latest`
- `ghcr.io/your-username/artemis-elasticsearch-user-setup:latest`
- `ghcr.io/your-username/artemis-mongodb:latest`
- `ghcr.io/your-username/artemis-kafka:latest`
- `ghcr.io/your-username/artemis-zookeeper:latest`
- `ghcr.io/your-username/artemis-sqlserver:latest`

## 🔍 View Your Images

After uploading, you can see your images at:
**https://github.com/your-username?tab=packages**

## 📥 Using Images on Another Machine

### Method 1: Using the Script Parameters
```powershell
# On the target machine, set environment variables
$env:REGISTRY_PREFIX = "ghcr.io/your-github-username"
$env:IMAGE_TAG = "latest"

# Login to GitHub Container Registry
docker login ghcr.io -u your-github-username

# Pull and run
docker-compose pull
docker-compose up -d
```

### Method 2: Using .env File
Create a `.env` file in your project directory:
```
REGISTRY_PREFIX=ghcr.io/your-github-username
IMAGE_TAG=latest
LOCAL_BACKEND_BOOTSTRAP_PASSWORD=changeme
```

Then:
```bash
docker login ghcr.io -u your-github-username
docker-compose pull
docker-compose up -d
```

## 🛠️ Script Options

The `push-to-github-registry.ps1` script supports these options:

```powershell
# Basic usage
.\push-to-github-registry.ps1 -GitHubUsername "your-username"

# With specific version tag
.\push-to-github-registry.ps1 -GitHubUsername "your-username" -ImageTag "v1.0"

# Skip building (use existing images)
.\push-to-github-registry.ps1 -GitHubUsername "your-username" -BuildFirst:$false

# Provide token directly (for automation)
.\push-to-github-registry.ps1 -GitHubUsername "your-username" -PersonalAccessToken "ghp_xxxxxxxxxxxx"
```

## 🔒 Privacy Settings

By default, your images will be **private**. To make them public:

1. Go to https://github.com/your-username?tab=packages
2. Click on an image package
3. Go to **"Package settings"**
4. Scroll down to **"Danger Zone"**
5. Click **"Change visibility"** → **"Public"**

## ❗ Troubleshooting

### "Authentication Required" Error
- Make sure your Personal Access Token has `write:packages` scope
- Try logging out and back in: `docker logout ghcr.io && docker login ghcr.io`

### "Access Denied" Error
- Ensure you're using your GitHub username (not email)
- Check that your token hasn't expired

### "Image Not Found" When Pulling
- Make sure the image is public, or you're logged in with proper permissions
- Verify the image name format: `ghcr.io/username/image-name:tag`

## 💡 Pro Tips

1. **Use Version Tags**: Instead of `latest`, use `v1.0`, `v1.1`, etc.
2. **Keep Tokens Secure**: Never commit Personal Access Tokens to your repository
3. **Private by Default**: GitHub Container Registry images are private by default
4. **Free for Public**: Public images are free, private images count against your storage quota

## 🎯 Example Complete Workflow

```powershell
# 1. Upload to GitHub Container Registry
.\push-to-github-registry.ps1 -GitHubUsername "tomas-rampas" -ImageTag "v1.0"

# 2. On another machine, create .env file:
# REGISTRY_PREFIX=ghcr.io/tomas-rampas
# IMAGE_TAG=v1.0
# LOCAL_BACKEND_BOOTSTRAP_PASSWORD=changeme

# 3. Pull and run
docker login ghcr.io -u tomas-rampas
docker-compose pull
docker-compose up -d
```

That's it! Your Docker images are now stored in GitHub Container Registry and can be reused anywhere.
