# Artemis Backend Testing & Diagnostics Suite

This directory contains comprehensive testing and diagnostic scripts for the Artemis Local Backend infrastructure. These PowerShell scripts help validate service functionality, diagnose issues, and ensure system reliability.

## 🌐 Cross-Platform Support

These scripts are designed to run on **Windows**, **Linux**, and **macOS** using PowerShell 7. The scripts automatically detect the current platform and adapt their behavior accordingly.

### 📦 PowerShell 7 Installation

#### Windows
PowerShell 7 can be installed alongside Windows PowerShell 5.x:

```powershell
# Using winget
winget install --id Microsoft.Powershell --source winget

# Using Chocolatey
choco install powershell

# Direct download from GitHub releases
# https://github.com/PowerShell/PowerShell/releases
```

#### Linux (Ubuntu/Debian)
```bash
# Method 1: Microsoft Repository (Recommended)
sudo apt-get update
sudo apt-get install -y wget apt-transport-https software-properties-common

# Add Microsoft repository
wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"
sudo dpkg -i packages-microsoft-prod.deb
sudo apt-get update

# Install PowerShell 7
sudo apt-get install -y powershell

# Method 2: Direct package download
wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.11/powershell_7.4.11-1.deb_amd64.deb
sudo dpkg -i powershell*.deb
sudo apt-get install -f

# Verify installation
pwsh --version
```

#### Windows Subsystem for Linux (WSL)
```bash
# Install WSL and Ubuntu (from Windows PowerShell as Administrator)
wsl --install

# Or install specific distribution
wsl --install -d Ubuntu-24.04

# Then follow Linux installation steps above
```

#### macOS
```bash
# Using Homebrew
brew install --cask powershell

# Using MacPorts
sudo port install powershell

# Verify installation
pwsh --version
```

### 🚀 Cross-Platform Usage

#### From Windows PowerShell/Command Prompt
```cmd
# Start PowerShell 7
pwsh

# Run scripts directly
pwsh -File .\doctor\Run-AllTests.ps1
```

#### From Linux/macOS Terminal
```bash
# Make scripts executable (one-time setup)
chmod +x doctor/*.ps1

# Start PowerShell 7
pwsh

# Run scripts directly from bash/zsh
./doctor/Run-AllTests.ps1

# Or run with pwsh
pwsh -File ./doctor/Run-AllTests.ps1
```

### 🐳 Docker Configuration

#### Linux Docker Access
```bash
# Add current user to docker group
sudo usermod -aG docker $USER

# Log out and back in, or run:
newgrp docker

# Verify Docker access
docker version
docker compose version  # or docker-compose version
```

#### WSL Docker Integration
- Install Docker Desktop for Windows with WSL integration enabled
- Or install Docker CE directly in WSL distribution

## 📁 Script Overview

### 🩺 Diagnostic Scripts
- **`Check-BackendHealth.ps1`** - Master health diagnostic script that analyzes all services

### ⚙️ Setup and Utility Scripts
- **`Install-PowerShell7.ps1`** - Interactive PowerShell 7 installation guide and environment setup
- **`Platform-Utilities.ps1`** - Cross-platform utility functions (dot-sourced by other scripts)

### 🧪 Individual Service Test Scripts  
- **`Test-Elasticsearch.ps1`** - Elasticsearch functionality tests
- **`Test-Kibana.ps1`** - Kibana functionality tests  
- **`Test-MongoDB.ps1`** - MongoDB functionality tests
- **`Test-Kafka.ps1`** - Kafka functionality tests
- **`Test-SqlServer.ps1`** - SQL Server functionality tests

### 🎯 Master Test Runner
- **`Run-AllTests.ps1`** - Orchestrates all tests and provides comprehensive reporting

## 🚀 Quick Start

### First-Time Setup
```bash
# Interactive setup guide (recommended for new users)
./doctor/Install-PowerShell7.ps1

# Or run specific setup steps
./doctor/Install-PowerShell7.ps1 -ShowInstructions    # Installation guide
./doctor/Install-PowerShell7.ps1 -VerifyInstallation # Check environment
./doctor/Install-PowerShell7.ps1 -SetupEnvironment   # Configure permissions
```

### Run All Tests
```powershell
# Basic execution - runs all services
.\Run-AllTests.ps1

# Test specific services only
.\Run-AllTests.ps1 -IncludeServices "elasticsearch,mongodb"

# Exclude specific services
.\Run-AllTests.ps1 -ExcludeServices "kibana"

# Skip cleanup to inspect test data
.\Run-AllTests.ps1 -SkipCleanup

# Export results to JSON
.\Run-AllTests.ps1 -OutputFormat JSON -OutputFile "results.json"

# Export results to HTML report
.\Run-AllTests.ps1 -OutputFormat HTML -OutputFile "report.html"
```

### Run Health Diagnostics Only
```powershell
# Basic health check
.\Check-BackendHealth.ps1

# Verbose output with detailed logs
.\Check-BackendHealth.ps1 -Verbose -LogLines 100
```

### Run Individual Service Tests
```powershell
# Test Elasticsearch
.\Test-Elasticsearch.ps1

# Test with custom parameters
.\Test-Elasticsearch.ps1 -ElasticsearchUrl "https://localhost:9200" -Username "elastic"

# Keep test data for inspection
.\Test-MongoDB.ps1 -SkipCleanup

# Test SQL Server with custom connection
.\Test-SqlServer.ps1 -ServerHost "localhost" -Username "sa" -Password "MyPassword"
```

## 📊 What Each Service Test Covers

### Elasticsearch Tests
- Cluster health verification
- Index creation and management
- Document CRUD operations
- Search functionality
- Aggregation queries
- Bulk operations
- Index cleanup

**Sample Operations:**
- Creates test index with mapping
- Inserts sample documents
- Performs text searches
- Tests aggregations
- Updates documents
- Bulk operations

### Kibana Tests  
- Service status verification
- Index pattern creation
- Saved objects management
- Visualization creation
- Dashboard creation
- API connectivity tests

**Sample Operations:**
- Creates index patterns
- Tests visualization APIs
- Creates test dashboards
- Validates saved objects

### MongoDB Tests
- Connection verification
- Database and collection creation
- Document insertion (CRUD operations)
- Query operations (find, conditional, range, array)
- Aggregation pipelines
- Index creation and management
- Text search capabilities

**Sample Operations:**
- Creates employee database
- Inserts test employee records
- Tests various query types
- Creates indexes
- Aggregation statistics

### Kafka Tests
- Broker connectivity
- Topic creation (single & multi-partition)
- Message production and consumption
- Consumer group functionality
- Topic configuration management
- Cluster information retrieval

**Sample Operations:**
- Creates test topics
- Produces text and JSON messages
- Tests consumer groups
- Multi-partition messaging

### SQL Server Tests
- Connection and authentication
- Database creation
- Table creation with multiple column types
- Data insertion and querying
- Complex queries and joins
- Stored procedure creation
- Transaction management
- JSON data handling
- Index creation

**Sample Operations:**
- Creates test database
- Creates employee table (10 columns)
- Inserts sample employee data
- Tests CRUD operations
- Creates stored procedures
- Transaction testing

## 🎛️ Command-Line Parameters

### Run-AllTests.ps1
| Parameter | Description | Example |
|-----------|-------------|---------|
| `-IncludeServices` | Comma-separated services to test | `"elasticsearch,mongodb"` |
| `-ExcludeServices` | Comma-separated services to exclude | `"kibana,kafka"` |
| `-SkipDiagnostics` | Skip initial health check | Switch parameter |
| `-SkipCleanup` | Keep test data after completion | Switch parameter |
| `-Parallel` | Run tests in parallel (experimental) | Switch parameter |
| `-OutputFormat` | Output format: Console, JSON, HTML | `"JSON"` |
| `-OutputFile` | File path for export | `"results.json"` |
| `-Verbose` | Show detailed output | Switch parameter |

### Check-BackendHealth.ps1
| Parameter | Description | Default |
|-----------|-------------|---------|
| `-LogLines` | Number of log lines to analyze | `50` |
| `-Verbose` | Show detailed diagnostic info | Switch parameter |

### Individual Test Scripts
All test scripts support these common parameters:
- `-SkipCleanup` - Preserve test data for inspection
- Service-specific connection parameters (host, port, credentials)

## 📈 Output Formats

### Console Output (Default)
- Color-coded status indicators
- Real-time progress updates  
- Detailed test results
- Summary statistics
- Failed test details

### JSON Export
```json
{
  "TestSuite": "Artemis Backend Full Test Suite",
  "StartTime": "2024-01-15T10:00:00",
  "Duration": "00:02:30",
  "OverallStatus": "SUCCESS",
  "Statistics": {
    "TotalServices": 5,
    "SuccessfulServices": 5,
    "TotalTests": 47,
    "SuccessfulTests": 47,
    "SuccessRate": 100
  },
  "ServiceTests": { ... }
}
```

### HTML Report
- Professional formatted report
- Color-coded status indicators
- Expandable test details
- Export timestamps
- Browser-friendly format

## 🔧 Troubleshooting

### Common Issues

1. **Docker not running**
   ```
   Error: Docker is not available or not running
   Solution: Start Docker Desktop or Docker daemon
   ```

2. **Service not responding**
   ```
   Error: Connection refused
   Solution: Ensure all services are running with docker-compose up -d
   ```

3. **Authentication failures**
   ```
   Error: Authentication failed
   Solution: Check environment variables for passwords
   ```

4. **Permission errors**
   ```
   Error: Access denied
   Solution: Run PowerShell as Administrator (Windows)
   ```

### Environment Variables
The scripts use these environment variables for configuration:
- `LOCAL_BACKEND_BOOTSTRAP_PASSWORD` - Elasticsearch password
- `SQLSERVER_SA_PASSWORD` - SQL Server SA password
- `KIBANA_ENCRYPTION_KEY` - Kibana encryption key

### Prerequisites
- Docker and Docker Compose running
- All Artemis services started (`docker-compose up -d`)
- PowerShell 5.1 or PowerShell Core 6+
- Network access to service ports

## 📝 Test Data Management

### Cleanup Behavior
- **Default**: All test data is automatically cleaned up
- **Skip Cleanup**: Use `-SkipCleanup` to preserve data for inspection
- **Test Data**: Each script creates uniquely named test objects with timestamps

### Test Data Examples
- **Elasticsearch**: `artemis-test-20240115-143022` (indices)
- **MongoDB**: `artemis_test_20240115_143022` (databases)
- **Kafka**: `artemis-test-20240115-143022-messages` (topics)
- **SQL Server**: `artemis_test_20240115_143022` (databases)

## 🔍 Exit Codes

| Code | Status | Description |
|------|--------|-------------|
| 0 | SUCCESS | All tests passed |
| 1 | WARNING | Tests passed but with warnings |
| 2 | FAILURE | One or more tests failed |
| 3 | UNKNOWN | Unexpected error occurred |

## 🔧 Platform-Specific Considerations

### Windows vs. Linux Differences

#### File Paths
- **Windows**: Uses backslashes `\` (but PowerShell accepts both)
- **Linux/macOS**: Uses forward slashes `/`
- **Scripts**: Already use cross-platform compatible path handling

#### Case Sensitivity
- **Windows**: File names are case-insensitive
- **Linux/macOS**: File names are case-sensitive
- **Docker**: Container names and commands are case-sensitive on all platforms

#### Permissions
- **Windows**: Run PowerShell as Administrator if needed
- **Linux/macOS**: Use `sudo` for privileged operations, add user to `docker` group

#### Environment Variables
- Scripts automatically detect and use platform-appropriate environment variables
- Default credentials are used if environment variables are not set

### Performance Differences

#### Execution Speed
- **Linux/WSL2**: Generally faster for Docker operations
- **Windows native**: Better integration with Windows services
- **WSL1**: Slower file I/O, use WSL2 when possible

#### Memory Usage
- **PowerShell 7**: More memory efficient than Windows PowerShell 5.x
- **Cross-platform**: Similar memory footprint across platforms

### Platform Detection Features

The scripts automatically detect:
- Operating system (Windows, Linux, macOS)
- PowerShell version and edition
- WSL environment
- Docker and Docker Compose availability
- Available system resources

### Troubleshooting Platform Issues

#### "Permission Denied" on Linux
```bash
# Make scripts executable
chmod +x doctor/*.ps1

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### "Docker not found" in WSL
```bash
# Install Docker in WSL or enable Docker Desktop WSL integration
# Check Docker availability
docker version
which docker
```

#### "PowerShell not recognized"
```bash
# Verify PowerShell 7 installation
pwsh --version

# Add to PATH if necessary
echo 'export PATH="/opt/microsoft/powershell/7:$PATH"' >> ~/.bashrc
```

## 📋 Best Practices

### Regular Testing
```powershell
# Daily health check
.\Check-BackendHealth.ps1

# Weekly comprehensive test  
.\Run-AllTests.ps1 -OutputFormat JSON -OutputFile "weekly-$(Get-Date -Format 'yyyy-MM-dd').json"

# Before deployment
.\Run-AllTests.ps1 -Verbose
```

### Development Workflow
```powershell
# Test specific service after changes
.\Test-Elasticsearch.ps1 -SkipCleanup

# Full regression test
.\Run-AllTests.ps1 -ExcludeServices "kibana" -SkipCleanup
```

### CI/CD Integration
```powershell
# Automated testing with JSON output
.\Run-AllTests.ps1 -OutputFormat JSON -OutputFile "ci-results.json"
# Check exit code for build status
```

## 📚 Additional Resources

- **Main Documentation**: See project README.md
- **Service Logs**: `docker-compose logs [service-name]`
- **Health Endpoints**: Individual service health check URLs
- **CLAUDE.md**: Development guidelines and architecture notes

---

**Note**: These scripts are designed to work with the Artemis Local Backend Docker Compose environment. Ensure all services are running before executing tests.