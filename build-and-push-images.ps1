# build-and-push-images.ps1
# Script to build, tag, and push all Docker images from docker-compose

param(
    [string]$RegistryPrefix = "artlockend",
    [string]$ImageTag = "latest",
    [switch]$PushImages = $false,
    [switch]$BuildOnly = $false
)

Write-Host "=== Docker Compose Image Build and Push Script ===" -ForegroundColor Green
Write-Host "Registry Prefix: $RegistryPrefix" -ForegroundColor Yellow
Write-Host "Image Tag: $ImageTag" -ForegroundColor Yellow
Write-Host ""

# Set environment variables for docker-compose
$env:REGISTRY_PREFIX = $RegistryPrefix
$env:IMAGE_TAG = $ImageTag

try {
    # Step 1: Build all images
    Write-Host "Step 1: Building all images..." -ForegroundColor Cyan
    docker-compose build
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build images. Exiting."
        exit 1
    }
    
    Write-Host "✓ All images built successfully!" -ForegroundColor Green
    Write-Host ""
    
    # Step 2: List the created images
    Write-Host "Step 2: Listing created images..." -ForegroundColor Cyan
    $images = @(
        "$RegistryPrefix/artemis-elasticsearch:$ImageTag",
        "$RegistryPrefix/artemis-kibana:$ImageTag",
        "$RegistryPrefix/artemis-elasticsearch-user-setup:$ImageTag",
        "$RegistryPrefix/artemis-mongodb:$ImageTag",
        "$RegistryPrefix/artemis-kafka:$ImageTag",
        "$RegistryPrefix/artemis-zookeeper:$ImageTag",
        "$RegistryPrefix/artemis-sqlserver:$ImageTag"
    )
    
    foreach ($image in $images) {
        $exists = docker images --format "table {{.Repository}}:{{.Tag}}" | Select-String -Pattern $image -Quiet
        if ($exists) {
            Write-Host "✓ $image" -ForegroundColor Green
        } else {
            Write-Host "✗ $image (not found)" -ForegroundColor Red
        }
    }
    Write-Host ""
    
    # Step 3: Push images (if requested)
    if ($PushImages -and -not $BuildOnly) {
        Write-Host "Step 3: Pushing images to registry..." -ForegroundColor Cyan
        
        # Check if user is logged in to Docker registry
        Write-Host "Checking Docker registry authentication..." -ForegroundColor Yellow
        
        foreach ($image in $images) {
            Write-Host "Pushing $image..." -ForegroundColor Yellow
            docker push $image
            
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "Failed to push $image. You may need to login first:"
                Write-Host "  docker login" -ForegroundColor Gray
                Write-Host "  or for GitHub Container Registry:" -ForegroundColor Gray
                Write-Host "  docker login ghcr.io" -ForegroundColor Gray
            } else {
                Write-Host "✓ Successfully pushed $image" -ForegroundColor Green
            }
        }
        Write-Host ""
    } elseif (-not $BuildOnly) {
        Write-Host "Step 3: Skipping push (use -PushImages to push)" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To push images later, run:" -ForegroundColor Cyan
        Write-Host "  docker-compose push" -ForegroundColor Gray
        Write-Host "  or" -ForegroundColor Gray
        Write-Host "  .\build-and-push-images.ps1 -PushImages" -ForegroundColor Gray
        Write-Host ""
    }
    
    # Step 4: Show usage instructions
    if (-not $BuildOnly) {
        Write-Host "=== Usage Instructions ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "To use these images on another machine:" -ForegroundColor Cyan
        Write-Host "1. Set environment variables:" -ForegroundColor White
        Write-Host "   `$env:REGISTRY_PREFIX = '$RegistryPrefix'" -ForegroundColor Gray
        Write-Host "   `$env:IMAGE_TAG = '$ImageTag'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Pull images:" -ForegroundColor White
        Write-Host "   docker-compose pull" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. Run services:" -ForegroundColor White
        Write-Host "   docker-compose up -d" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Or create a .env file with:" -ForegroundColor White
        Write-Host "   REGISTRY_PREFIX=$RegistryPrefix" -ForegroundColor Gray
        Write-Host "   IMAGE_TAG=$ImageTag" -ForegroundColor Gray
        Write-Host ""
    }
    
    Write-Host "=== Build Complete! ===" -ForegroundColor Green
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
