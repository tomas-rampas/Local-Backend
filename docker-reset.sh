#!/bin/bash
# Docker volume reset script - uses Docker to avoid permission issues

echo "=== Docker Volume Reset ==="
echo "Stopping containers and cleaning volumes..."

# Stop all containers
docker-compose down -v 2>/dev/null || echo "No containers running"

# Remove any orphaned containers
docker container prune -f 2>/dev/null || echo "No orphaned containers"

# Remove all volumes (including orphaned ones)
docker volume prune -f 2>/dev/null || echo "No volumes to prune"

# Use Docker to clean directories (avoids permission issues)
echo "Cleaning data directories using Docker..."

# Run a temporary Alpine container to clean directories
docker run --rm \
  -v "$(pwd)":/workspace \
  -w /workspace \
  alpine:latest sh -c '
    echo "Cleaning all service directories..."
    find . -name "data" -o -name "logs" -o -name "backup" -o -name "configdb" | while read dir; do
      if [ -d "$dir" ]; then
        echo "  Cleaning: $dir"
        rm -rf "$dir"/*
        touch "$dir/.gitkeep"
      fi
    done
    
    # Clean shared directory
    if [ -d "shared" ]; then
      echo "  Cleaning: shared"
      rm -rf shared/*
      touch shared/.gitkeep
    fi
    
    echo "All directories cleaned successfully!"
  '

echo ""
echo "=== Reset Complete ==="
echo "You can now start services with: docker-compose up -d"