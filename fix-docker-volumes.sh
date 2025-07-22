#!/bin/bash
# Fix Docker volume mounting issues for Artemis Local Backend

echo "=== Fixing Docker Volume Issues ==="
echo "This script will clean and recreate all service directories"
echo ""

# Function to clean and recreate a directory
recreate_dir() {
    local dir=$1
    echo "Processing: $dir"
    
    # Remove directory if it exists (requires sudo for root-owned files)
    if [ -d "$dir" ]; then
        echo "  - Removing existing directory..."
        sudo rm -rf "$dir"
    fi
    
    # Create directory with current user ownership
    echo "  - Creating directory..."
    mkdir -p "$dir"
    
    # Add .gitkeep file
    touch "$dir/.gitkeep"
    
    # Ensure proper permissions
    chmod 755 "$dir"
    echo "  ✓ Done"
}

# Stop any running containers
echo "Stopping any running containers..."
docker-compose down 2>/dev/null || true

# Clean up Docker volumes
echo ""
echo "Cleaning Docker volumes..."
docker volume prune -f 2>/dev/null || true

# List of all directories that need to be recreated
directories=(
    "elasticsearch/data"
    "elasticsearch/logs"
    "kibana/data"
    "kibana/logs"
    "mongodb/data"
    "mongodb/configdb"
    "kafka/data"
    "kafka/logs"
    "zookeeper/data"
    "zookeeper/logs"
    "sqlserver/data"
    "sqlserver/backup"
    "sqlserver/logs"
    "shared"
)

# Recreate all directories
echo ""
echo "Recreating all service directories..."
for dir in "${directories[@]}"; do
    recreate_dir "$dir"
done

echo ""
echo "=== Fix Complete ==="
echo ""
echo "You can now start the services with:"
echo "  docker-compose up -d"
echo ""
echo "Note: If you still have issues, try running this command from WSL2 terminal instead of PowerShell"