# Certificate Management

This directory contains all SSL/TLS certificates for the Artemis Local Backend services.

## Directory Structure

```
certs/
├── Generate-AllCertificates.ps1    # Master certificate generation script
├── Install-CACertificate.ps1        # CA installation script for Windows
├── README.md                        # This file
├── ca/                              # Certificate Authority
│   ├── ca.crt                       # CA certificate
│   ├── ca.key                       # CA private key
│   └── ca.srl                       # CA serial number file
├── elasticsearch/                   # Elasticsearch certificates
│   ├── elasticsearch.crt            # Service certificate
│   ├── elasticsearch.key            # Service private key
│   ├── elasticsearch.p12            # PKCS#12 format
│   ├── elasticsearch.keystore.jks   # Java keystore
│   └── elasticsearch.truststore.jks # Java truststore
├── kibana/                         # Kibana certificates
│   ├── kibana.crt                  # Service certificate
│   ├── kibana.key                  # Service private key
│   └── kibana.p12                  # PKCS#12 format
└── kafka/                          # Kafka certificates
    ├── kafka.keystore.jks          # Java keystore
    └── kafka.truststore.jks        # Java truststore
```

## Usage

### Prerequisites

Before running the certificate scripts, ensure you have:

1. **OpenSSL**: Download and install from https://slproweb.com/products/Win32OpenSSL.html
   - Add OpenSSL to your Windows PATH
   - Test with: `openssl version`

2. **Java JDK** (for JKS keystores): Download from https://www.oracle.com/java/technologies/downloads/
   - Add `keytool` to your Windows PATH (usually in `%JAVA_HOME%\bin`)
   - Test with: `keytool -help`
   - **Note**: JKS generation will be skipped if keytool is not available

### Generate All Certificates

Run the master PowerShell script to generate all certificates:

```powershell
# Basic generation with defaults (requires Administrator for CA installation)
.\Generate-AllCertificates.ps1

# Custom CA name and passwords
.\Generate-AllCertificates.ps1 -CaName "MyCompanyCA" -CaKeyPassword "SecurePass123" -CertPassword "ServicePass456"

# Skip CA installation to Windows trust store
.\Generate-AllCertificates.ps1 -InstallCA:$false

# Skip generation if certificates already exist
.\Generate-AllCertificates.ps1 -SkipIfExists

# Generate without backups (faster)
.\Generate-AllCertificates.ps1 -BackupExisting:$false
```

### Clean All Certificates

Use the cleanup script to remove all certificate files:

```powershell
# Preview what would be removed (dry run)
.\Clean-AllCertificates.ps1 -WhatIf

# Clean all certificates (with confirmation prompt)
.\Clean-AllCertificates.ps1

# Clean all certificates and remove CA from Windows trust store
.\Clean-AllCertificates.ps1 -UninstallCA

# Force cleanup without confirmation prompts
.\Clean-AllCertificates.ps1 -Force

# Complete cleanup including CA uninstall
.\Clean-AllCertificates.ps1 -UninstallCA -Force
```

### Manual CA Installation

If you need to install the CA certificate manually:

```powershell
.\Install-CACertificate.ps1 -CaCertPath ".\ca\ca.crt" -CaCn "ArtemisLocalCA"
```

## Certificate Details

### Certificate Authority
- **Common Name**: ArtemisLocalCA (configurable)
- **Validity**: 10 years (3650 days)
- **Key Size**: 2048-bit RSA
- **Algorithm**: SHA-256

### Service Certificates
- **Validity**: 1 year (365 days)
- **Key Size**: 2048-bit RSA
- **Algorithm**: SHA-256
- **Subject Alternative Names**: Includes localhost, 127.0.0.1, service names, and Docker container names

### Supported Formats
- **PEM**: `.crt` and `.key` files for standard SSL/TLS
- **PKCS#12**: `.p12` files for Java applications and browsers
- **JKS**: Java KeyStore format for Elasticsearch, Kafka, and other Java services

## Service Integration

The certificates are automatically used by Docker services:

- **Elasticsearch**: Uses JKS keystore and truststore for SSL/TLS
- **Kibana**: Uses PKCS#12 certificate for connecting to Elasticsearch
- **Kafka**: Uses JKS keystore and truststore for SSL (if enabled)

## Security Notes

- Default password for all certificates is `changeme` - **change this in production**
- Private keys are stored with appropriate file permissions
- CA certificate is automatically installed to Windows Trusted Root store (if run as Administrator)
- Old certificates are backed up before regeneration

## Troubleshooting

### Common Issues

1. **Permission denied errors**: Run PowerShell as Administrator
2. **OpenSSL not found**: Install OpenSSL and add to PATH
3. **keytool not found**: Install Java JDK and add to PATH
4. **Certificate warnings in browser**: Ensure CA certificate is installed in Windows trust store

### Manual Certificate Verification

```bash
# Verify certificate details
openssl x509 -in elasticsearch/elasticsearch.crt -text -noout

# Test certificate chain
openssl verify -CAfile ca/ca.crt elasticsearch/elasticsearch.crt
```

## Certificate Verification and Troubleshooting Scripts

### Quick Certificate Store Verification

```powershell
# Check all sysSDSEnv certificates in Root store (trusted certificates)
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnv*" } | Format-List Subject,Thumbprint,HasPrivateKey

# Check CA certificate specifically
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnvCALocal*" } | Format-List Subject,Thumbprint,HasPrivateKey,NotAfter

# Check environment certificate specifically  
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnvLocal*" } | Format-List Subject,Thumbprint,HasPrivateKey,NotAfter

# Check certificates with private keys in Personal store (for development signing)
Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*sysSDSEnv*" } | Format-List Subject,Thumbprint,HasPrivateKey,NotAfter
```

### Certificate Thumbprint Retrieval for Configuration

```powershell
# Get CA certificate thumbprint for signing purposes (local.json configuration)
$caThumbprint = (Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnvCALocal*" }).Thumbprint
Write-Host "CA Certificate Thumbprint (for SIGNING): $caThumbprint" -ForegroundColor Cyan

# Get environment certificate thumbprint  
$envThumbprint = (Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnvLocal*" }).Thumbprint
Write-Host "Environment Certificate Thumbprint: $envThumbprint" -ForegroundColor Cyan

# Copy thumbprints to clipboard (requires manual selection)
Write-Host "CA Thumbprint: $caThumbprint" 
Write-Host "Env Thumbprint: $envThumbprint"
```

### Certificate Capability Verification

```powershell
# Verify CA certificate has proper extensions for certificate signing
$caCert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnvCALocal*" }
if ($caCert) {
    Write-Host "CA Certificate Extensions:" -ForegroundColor Yellow
    $caCert.Extensions | ForEach-Object { 
        Write-Host "  $($_.Oid.FriendlyName): $($_.Format($false))" -ForegroundColor Gray
    }
    Write-Host "Can Issue Certificates: $($caCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Basic Constraints' -and $_.Format($false) -like '*Subject Type=CA*' } | Measure-Object | Select-Object -ExpandProperty Count)" -ForegroundColor $(if ($caCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Basic Constraints' -and $_.Format($false) -like '*Subject Type=CA*' }) { 'Green' } else { 'Red' })
}

# Verify environment certificate cannot be used for signing
$envCert = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnvLocal*" }
if ($envCert) {
    Write-Host "Environment Certificate Extensions:" -ForegroundColor Yellow
    $envCert.Extensions | ForEach-Object { 
        Write-Host "  $($_.Oid.FriendlyName): $($_.Format($false))" -ForegroundColor Gray
    }
    $canSign = $envCert.Extensions | Where-Object { $_.Oid.FriendlyName -eq 'Key Usage' -and $_.Format($false) -like '*Digital Signature*' }
    Write-Host "Can Sign: $(if ($canSign) { 'YES (Security Issue!)' } else { 'NO (Correct)' })" -ForegroundColor $(if ($canSign) { 'Red' } else { 'Green' })
}
```

### ASP.NET Development Verification

```powershell
# Check if CA certificate is available for ASP.NET signing (Personal store with private key)
$caPersonal = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*sysSDSEnvCALocal*" -and $_.HasPrivateKey }
if ($caPersonal) {
    Write-Host "✓ CA certificate available for ASP.NET signing" -ForegroundColor Green
    Write-Host "  Thumbprint: $($caPersonal.Thumbprint)" -ForegroundColor Cyan
    Write-Host "  Private Key: $($caPersonal.HasPrivateKey)" -ForegroundColor Gray
    Write-Host "  Store Location: Cert:\LocalMachine\My" -ForegroundColor Gray
} else {
    Write-Host "✗ CA certificate not available for ASP.NET signing" -ForegroundColor Red
    Write-Host "  Run: .\Generate-AllCertificates.ps1 -InstallWithPrivateKey" -ForegroundColor Yellow
}

# Verify certificate can be loaded in ASP.NET application
try {
    $cert = Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*sysSDSEnvCALocal*" } | Select-Object -First 1
    if ($cert -and $cert.HasPrivateKey) {
        Write-Host "✓ Certificate ready for ASP.NET X509Certificate2 loading" -ForegroundColor Green
        Write-Host "  Code: new X509Certificate2().LoadFromStore(StoreLocation.LocalMachine, StoreName.My, `"$($cert.Thumbprint)`")" -ForegroundColor Gray
    }
} catch {
    Write-Host "✗ Certificate verification failed: $($_.Exception.Message)" -ForegroundColor Red
}
```

### Common Troubleshooting Commands

```powershell
# List all certificates in Root store
Get-ChildItem Cert:\LocalMachine\Root | Format-Table Subject, Thumbprint, NotAfter -AutoSize

# List all certificates in Personal store
Get-ChildItem Cert:\LocalMachine\My | Format-Table Subject, Thumbprint, HasPrivateKey, NotAfter -AutoSize

# Check certificate expiration
Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnv*" } | ForEach-Object {
    $daysLeft = ($_.NotAfter - (Get-Date)).Days
    Write-Host "$($_.Subject): $daysLeft days remaining" -ForegroundColor $(if ($daysLeft -lt 30) { 'Red' } elseif ($daysLeft -lt 90) { 'Yellow' } else { 'Green' })
}

# Remove certificates if needed (use with caution)
# Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Subject -like "*sysSDSEnvCALocal*" } | Remove-Item -Force
# Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -like "*sysSDSEnvCALocal*" } | Remove-Item -Force

# Test certificate file integrity
if (Test-Path ".\ca\ca.crt") {
    $fileContent = Get-Content ".\ca\ca.crt" -Raw
    if ($fileContent -match "-----BEGIN CERTIFICATE-----" -and $fileContent -match "-----END CERTIFICATE-----") {
        Write-Host "✓ CA certificate file format valid" -ForegroundColor Green
    } else {
        Write-Host "✗ CA certificate file format invalid" -ForegroundColor Red
    }
}

# Verify certificate chain locally
if (Test-Path ".\ca\ca.crt" -and Test-Path ".\env\sysSDSEnvLocal.crt") {
    try {
        & openssl verify -CAfile ".\ca\ca.crt" ".\env\sysSDSEnvLocal.crt"
        Write-Host "✓ Certificate chain verification passed" -ForegroundColor Green
    } catch {
        Write-Host "✗ Certificate chain verification failed" -ForegroundColor Red
    }
}
```

### Docker Integration Verification

```powershell
# Check if certificates are accessible to Docker containers
docker-compose exec -T elasticsearch ls -la /usr/share/elasticsearch/config/certs/ 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Certificates accessible to Elasticsearch container" -ForegroundColor Green
} else {
    Write-Host "✗ Certificates not accessible to containers" -ForegroundColor Red
}

# Test certificate mounting in Docker
docker-compose exec -T kibana ls -la /shared/ 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Shared certificate directory accessible to Kibana" -ForegroundColor Green
} else {
    Write-Host "✗ Shared certificate directory not accessible" -ForegroundColor Red
}
```

## Integration with Docker

The certificates are mounted into containers via:
- Docker Compose volume mounts: `./certs:/certs:ro`
- Dockerfile COPY commands referencing organized subdirectories

## Backup and Recovery

The script automatically creates timestamped backups before regenerating certificates:
- Backup location: `./backup_YYYYMMDD_HHMMSS/`
- Includes all certificates and keys
- Manual backup: Copy entire `certs/` directory

## Recommended Workflow

### First Time Setup

1. **Install Prerequisites**:
   ```powershell
   # Verify OpenSSL is available
   openssl version
   
   # Verify Java/keytool is available (optional for JKS)
   keytool -help
   ```

2. **Generate Fresh Certificates**:
   ```powershell
   # Run as Administrator for CA installation
   .\Generate-AllCertificates.ps1
   ```

3. **Build and Run Docker Services**:
   ```bash
   docker-compose up -d --build
   ```

### Regular Development

If you need to regenerate certificates (e.g., after expiry or configuration changes):

1. **Clean Existing Certificates**:
   ```powershell
   .\Clean-AllCertificates.ps1 -Force
   ```

2. **Generate New Certificates**:
   ```powershell
   .\Generate-AllCertificates.ps1 -SkipIfExists:$false
   ```

3. **Rebuild Docker Services**:
   ```bash
   docker-compose down
   docker-compose up -d --build
   ```

### Troubleshooting

- **"OpenSSL not found"**: Install OpenSSL and add to PATH
- **"keytool not found"**: Install Java JDK, or use `-GenerateJKS:$false` for services that don't require JKS
- **CA installation fails**: Run PowerShell as Administrator
- **Docker build fails with certificate errors**: Ensure all required certificate files exist, especially JKS files for Elasticsearch and Kafka

## Environment Variables

You can customize certificate generation via `.env` file:
- `LOCAL_BACKEND_BOOTSTRAP_PASSWORD`: Default password for certificates
- `KIBANA_ENCRYPTION_KEY`: Kibana encryption key (separate from certificates)