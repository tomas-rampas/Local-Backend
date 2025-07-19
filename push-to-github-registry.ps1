# push-to-github-registry.ps1
# Script to build and push Docker images to GitHub Container Registry (ghcr.io)

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername,
    
    [string]$ImageTag = "latest",
    [string]$PersonalAccessToken = "",
    [switch]$BuildFirst
)

Write-Host "=== GitHub Container Registry Push Script ===" -ForegroundColor Green
Write-Host "GitHub Username: $GitHubUsername" -ForegroundColor Yellow
Write-Host "Image Tag: $ImageTag" -ForegroundColor Yellow
Write-Host ""

# Set environment variables for docker-compose
$env:REGISTRY_PREFIX = "ghcr.io/$GitHubUsername"
$env:IMAGE_TAG = $ImageTag

try {
    # Step 1: Login to GitHub Container Registry
    Write-Host "Step 1: Logging into GitHub Container Registry..." -ForegroundColor Cyan
    
    if ($PersonalAccessToken) {
        Write-Host "Using provided Personal Access Token..." -ForegroundColor Yellow
        echo $PersonalAccessToken | docker login ghcr.io -u $GitHubUsername --password-stdin
    } else {
        Write-Host "Please enter your GitHub Personal Access Token when prompted..." -ForegroundColor Yellow
        Write-Host "If you don't have one, create it at: https://github.com/settings/tokens" -ForegroundColor Gray
        Write-Host "Required scopes: write:packages, read:packages" -ForegroundColor Gray
        docker login ghcr.io -u $GitHubUsername
    }
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to login to GitHub Container Registry. Please check your credentials."
        Write-Host ""
        Write-Host "To create a Personal Access Token:" -ForegroundColor Cyan
        Write-Host "1. Go to https://github.com/settings/tokens" -ForegroundColor White
        Write-Host "2. Click 'Generate new token (classic)'" -ForegroundColor White
        Write-Host "3. Select scopes: 'write:packages' and 'read:packages'" -ForegroundColor White
        Write-Host "4. Copy the token and use it as password when logging in" -ForegroundColor White
        exit 1
    }
    
    Write-Host "✓ Successfully logged into GitHub Container Registry!" -ForegroundColor Green
    Write-Host ""
    
    # Step 2: Build images (if requested)
    if ($BuildFirst) {
        Write-Host "Step 2: Building all images..." -ForegroundColor Cyan
        docker-compose build
        
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Failed to build images. Exiting."
            exit 1
        }
        
        Write-Host "✓ All images built successfully!" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host "Step 2: Skipping build (using existing images)" -ForegroundColor Yellow
        Write-Host ""
    }
    
    # Step 3: List the images that will be pushed
    Write-Host "Step 3: Images to be pushed..." -ForegroundColor Cyan
    $images = @(
        "ghcr.io/$GitHubUsername/artemis-elasticsearch:$ImageTag",
        "ghcr.io/$GitHubUsername/artemis-kibana:$ImageTag",
        "ghcr.io/$GitHubUsername/artemis-elasticsearch-user-setup:$ImageTag",
        "ghcr.io/$GitHubUsername/artemis-mongodb:$ImageTag",
        "ghcr.io/$GitHubUsername/artemis-kafka:$ImageTag",
        "ghcr.io/$GitHubUsername/artemis-zookeeper:$ImageTag",
        "ghcr.io/$GitHubUsername/artemis-sqlserver:$ImageTag"
    )
    
    foreach ($image in $images) {
        Write-Host "  → $image" -ForegroundColor Gray
    }
    Write-Host ""
    
    # Step 4: Push all images
    Write-Host "Step 4: Pushing images to GitHub Container Registry..." -ForegroundColor Cyan
    
    $successCount = 0
    $failCount = 0
    
    foreach ($image in $images) {
        Write-Host "Pushing $image..." -ForegroundColor Yellow
        docker push $image
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✓ Successfully pushed $image" -ForegroundColor Green
            $successCount++
        } else {
            Write-Host "✗ Failed to push $image" -ForegroundColor Red
            $failCount++
        }
    }
    
    Write-Host ""
    Write-Host "=== Push Summary ===" -ForegroundColor Green
    Write-Host "Successfully pushed: $successCount images" -ForegroundColor Green
    Write-Host "Failed to push: $failCount images" -ForegroundColor $(if ($failCount -gt 0) { "Red" } else { "Green" })
    Write-Host ""
    
    if ($successCount -gt 0) {
        Write-Host "=== Usage Instructions ===" -ForegroundColor Green
        Write-Host ""
        Write-Host "Your images are now available at:" -ForegroundColor Cyan
        Write-Host "https://github.com/$($GitHubUsername)?tab=packages" -ForegroundColor Gray
        Write-Host ""
        Write-Host "To use these images on another machine:" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. Login to GitHub Container Registry:" -ForegroundColor White
        Write-Host "   docker login ghcr.io -u $GitHubUsername" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. Set environment variables:" -ForegroundColor White
        Write-Host "   `$env:REGISTRY_PREFIX = 'ghcr.io/$GitHubUsername'" -ForegroundColor Gray
        Write-Host "   `$env:IMAGE_TAG = '$ImageTag'" -ForegroundColor Gray
        Write-Host ""
        Write-Host "3. Pull and run:" -ForegroundColor White
        Write-Host "   docker-compose pull" -ForegroundColor Gray
        Write-Host "   docker-compose up -d" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Or create a .env file with:" -ForegroundColor White
        Write-Host "   REGISTRY_PREFIX=ghcr.io/$GitHubUsername" -ForegroundColor Gray
        Write-Host "   IMAGE_TAG=$ImageTag" -ForegroundColor Gray
        Write-Host "   LOCAL_BACKEND_BOOTSTRAP_PASSWORD=changeme" -ForegroundColor Gray
        Write-Host ""
    }
    
    if ($failCount -gt 0) {
        Write-Host "Some images failed to push. Common solutions:" -ForegroundColor Yellow
        Write-Host "1. Ensure your Personal Access Token has 'write:packages' scope" -ForegroundColor White
        Write-Host "2. Check if the repository exists and you have push permissions" -ForegroundColor White
        Write-Host "3. Try logging out and logging back in: docker logout ghcr.io && docker login ghcr.io" -ForegroundColor White
    }
    
} catch {
    Write-Error "An error occurred: $($_.Exception.Message)"
    exit 1
}
