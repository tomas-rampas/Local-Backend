# Clean-AllCertificates.ps1
# Cleanup script for all certificates in Artemis Local Backend
# Removes all certificate files and optionally uninstalls CA from Windows trust store

param(
    [string]$CaName = "sysSDSEnvCALocal",
    [string]$EnvLocalName = "sysSDSEnvLocal",
    [switch]$UninstallCA = $false,
    [switch]$UninstallEnvLocal = $false,
    [switch]$Force = $false,
    [switch]$WhatIf = $false
)

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CertsDir = $ScriptDir

Write-Host "=== Artemis Certificate Cleanup Script ===" -ForegroundColor Red
Write-Host "Certificate directory: $CertsDir" -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "WHAT-IF MODE: No actual changes will be made" -ForegroundColor Cyan
}

Write-Host ""

# Function to remove CA from Windows trust store
function Remove-CAFromTrustStore {
    param([string]$CaCommonName)
    
    try {
        if ($WhatIf) {
            Write-Host "WHAT-IF: Would search for CA '$CaCommonName' in Windows trust store" -ForegroundColor Cyan
            return
        }
        
        $certs = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Subject -like "*CN=$CaCommonName*" }
        
        if ($certs.Count -eq 0) {
            Write-Host "✓ CA '$CaCommonName' not found in Windows trust store" -ForegroundColor Green
            return
        }
        
        Write-Host "Found $($certs.Count) CA certificate(s) in Windows trust store" -ForegroundColor Yellow
        
        foreach ($cert in $certs) {
            Write-Host "  Removing CA certificate: $($cert.Thumbprint)" -ForegroundColor Gray
            Remove-Item -Path "Cert:\LocalMachine\Root\$($cert.Thumbprint)" -Force
        }
        
        Write-Host "✓ CA '$CaCommonName' removed from Windows trust store" -ForegroundColor Green
        
    } catch {
        Write-Warning "Failed to remove CA from trust store: $($_.Exception.Message)"
        Write-Host "You may need to run this script as Administrator to modify the trust store" -ForegroundColor Yellow
    }
}

# Function to remove certificate files
function Remove-CertificateFiles {
    param([string]$Directory, [string]$ServiceName = "")
    
    if (-not (Test-Path $Directory)) {
        if ($ServiceName) {
            Write-Host "✓ $ServiceName certificate directory does not exist" -ForegroundColor Green
        }
        return
    }
    
    # Certificate file extensions to remove
    $extensions = @("*.crt", "*.key", "*.p12", "*.pfx", "*.jks", "*.csr", "*.srl", "*.pem", "*.der", "*.cer")
    
    $filesToRemove = @()
    foreach ($ext in $extensions) {
        $files = Get-ChildItem -Path $Directory -Filter $ext -File -ErrorAction SilentlyContinue
        $filesToRemove += $files
    }
    
    if ($filesToRemove.Count -eq 0) {
        if ($ServiceName) {
            Write-Host "✓ No $ServiceName certificate files found to remove" -ForegroundColor Green
        }
        return
    }
    
    if ($ServiceName) {
        Write-Host "Removing $ServiceName certificate files..." -ForegroundColor Cyan
    }
    
    foreach ($file in $filesToRemove) {
        if ($WhatIf) {
            Write-Host "  WHAT-IF: Would remove $($file.FullName)" -ForegroundColor Cyan
        } else {
            Write-Host "  Removing: $($file.Name)" -ForegroundColor Gray
            Remove-Item -Path $file.FullName -Force
        }
    }
    
    if ($ServiceName -and -not $WhatIf) {
        Write-Host "✓ $ServiceName certificate files removed" -ForegroundColor Green
    }
}

# Function to remove backup directories
function Remove-BackupDirectories {
    $backupDirs = Get-ChildItem -Path $CertsDir -Directory | Where-Object { $_.Name -match "^backup_\d{8}_\d{6}$" }
    
    if ($backupDirs.Count -eq 0) {
        Write-Host "✓ No backup directories found" -ForegroundColor Green
        return
    }
    
    Write-Host "Found $($backupDirs.Count) backup directories" -ForegroundColor Yellow
    
    if (-not $Force -and -not $WhatIf) {
        $response = Read-Host "Remove backup directories? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Keeping backup directories" -ForegroundColor Yellow
            return
        }
    }
    
    foreach ($dir in $backupDirs) {
        if ($WhatIf) {
            Write-Host "  WHAT-IF: Would remove backup directory $($dir.Name)" -ForegroundColor Cyan
        } else {
            Write-Host "  Removing backup directory: $($dir.Name)" -ForegroundColor Gray
            Remove-Item -Path $dir.FullName -Recurse -Force
        }
    }
    
    if (-not $WhatIf) {
        Write-Host "✓ Backup directories removed" -ForegroundColor Green
    }
}

# Main execution
try {
    # Confirmation prompt (unless -Force or -WhatIf)
    if (-not $Force -and -not $WhatIf) {
        Write-Host "This will remove ALL certificate files from the following directories:" -ForegroundColor Yellow
        Write-Host "  - CA: $CertsDir\ca\" -ForegroundColor Gray
        Write-Host "  - Elasticsearch: $CertsDir\elasticsearch\" -ForegroundColor Gray
        Write-Host "  - Kibana: $CertsDir\kibana\" -ForegroundColor Gray
        Write-Host "  - Kafka: $CertsDir\kafka\" -ForegroundColor Gray
        Write-Host "  - MongoDB: $CertsDir\mongodb\" -ForegroundColor Gray
        Write-Host "  - SQL Server: $CertsDir\sqlserver\" -ForegroundColor Gray
        Write-Host "  - Zookeeper: $CertsDir\zookeeper\" -ForegroundColor Gray
        Write-Host "  - Environment: $CertsDir\env\" -ForegroundColor Gray
        
        if ($UninstallCA) {
            Write-Host "  - CA '$CaName' will be removed from Windows trust store" -ForegroundColor Red
        }
        
        if ($UninstallEnvLocal) {
            Write-Host "  - Certificate '$EnvLocalName' will be removed from Windows trust store" -ForegroundColor Red
        }
        
        Write-Host ""
        $response = Read-Host "Are you sure you want to proceed? (y/N)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Write-Host "Operation cancelled" -ForegroundColor Yellow
            exit 0
        }
    }
    
    Write-Host ""
    Write-Host "Starting certificate cleanup..." -ForegroundColor Cyan
    Write-Host ""
    
    # Remove CA from trust store if requested
    if ($UninstallCA) {
        Write-Host "Step 1: Removing CA from Windows trust store..." -ForegroundColor Cyan
        Remove-CAFromTrustStore $CaName
        Write-Host ""
    }
    
    # Remove sysSDSEnvLocal certificate from trust store if requested
    if ($UninstallEnvLocal) {
        Write-Host "Step 2: Removing sysSDSEnvLocal certificate from Windows trust store..." -ForegroundColor Cyan
        Remove-CAFromTrustStore $EnvLocalName
        Write-Host ""
    }
    
    # Remove certificate files from each service directory
    $services = @(
        @{ Name = "CA"; Dir = Join-Path $CertsDir "ca" },
        @{ Name = "Elasticsearch"; Dir = Join-Path $CertsDir "elasticsearch" },
        @{ Name = "Kibana"; Dir = Join-Path $CertsDir "kibana" },
        @{ Name = "Kafka"; Dir = Join-Path $CertsDir "kafka" },
        @{ Name = "MongoDB"; Dir = Join-Path $CertsDir "mongodb" },
        @{ Name = "SQL Server"; Dir = Join-Path $CertsDir "sqlserver" },
        @{ Name = "Zookeeper"; Dir = Join-Path $CertsDir "zookeeper" },
        @{ Name = "Environment"; Dir = Join-Path $CertsDir "env" }
    )
    
    foreach ($service in $services) {
        Remove-CertificateFiles -Directory $service.Dir -ServiceName $service.Name
    }
    
    # Remove any loose certificate files in the root certs directory
    Write-Host ""
    Write-Host "Cleaning root certificate directory..." -ForegroundColor Cyan
    Remove-CertificateFiles -Directory $CertsDir
    
    # Remove backup directories
    Write-Host ""
    Write-Host "Checking for backup directories..." -ForegroundColor Cyan
    Remove-BackupDirectories
    
    Write-Host ""
    Write-Host "=== Certificate Cleanup Complete ===" -ForegroundColor Green
    Write-Host ""
    
    if ($WhatIf) {
        Write-Host "WHAT-IF MODE: No actual changes were made" -ForegroundColor Cyan
        Write-Host "Run without -WhatIf to perform the actual cleanup" -ForegroundColor Cyan
    } else {
        Write-Host "✓ All certificate files have been removed!" -ForegroundColor Green
        
        if ($UninstallCA) {
            Write-Host "✓ CA '$CaName' removed from Windows trust store" -ForegroundColor Green
        }
        
        if ($UninstallEnvLocal) {
            Write-Host "✓ Certificate '$EnvLocalName' removed from Windows trust store" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "You can now run Generate-AllCertificates.ps1 to create fresh certificates" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Certificate cleanup failed: $($_.Exception.Message)"
    exit 1
}