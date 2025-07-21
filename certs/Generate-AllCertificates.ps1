# Generate-AllCertificates.ps1
# Master certificate generation script for Artemis Local Backend
# Generates CA and all service certificates in organized structure

param(
    [string]$CaName = "ArtemisLocalCA",
    [string]$CaKeyPassword = "changeme",
    [string]$CertPassword = "changeme", 
    [int]$CaValidityDays = 3650,
    [int]$CertValidityDays = 365,
    [string]$Organization = "Artemis",
    [string]$OrganizationalUnit = "Development",
    [string]$Country = "US",
    [switch]$InstallCA = $true,
    [switch]$BackupExisting = $true,
    [switch]$SkipIfExists = $false
)

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CertsDir = $ScriptDir

Write-Host "=== Artemis Certificate Generation Script ===" -ForegroundColor Green
Write-Host "Certificate directory: $CertsDir" -ForegroundColor Yellow
Write-Host ""

# Function to check if OpenSSL is available
function Test-OpenSSL {
    try {
        $null = Get-Command openssl -ErrorAction Stop
        return $true
    } catch {
        Write-Error "OpenSSL is required but not found in PATH. Please install OpenSSL first."
        Write-Host "Download from: https://slproweb.com/products/Win32OpenSSL.html"
        return $false
    }
}

# Function to check if keytool is available  
function Test-Keytool {
    try {
        $null = Get-Command keytool -ErrorAction Stop
        return $true
    } catch {
        Write-Warning "keytool not found in PATH. JKS keystores will be skipped."
        Write-Host "To generate JKS files, install Java JDK and add keytool to PATH" -ForegroundColor Yellow
        Write-Host "Download JDK from: https://www.oracle.com/java/technologies/downloads/" -ForegroundColor Yellow
        return $false
    }
}

# Function to backup existing certificates
function Backup-ExistingCerts {
    param([string]$BackupDir)
    
    if (Test-Path $BackupDir) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupPath = Join-Path $CertsDir "backup_$timestamp"
        Write-Host "Backing up existing certificates to: $backupPath" -ForegroundColor Yellow
        
        Copy-Item -Path $BackupDir -Destination $backupPath -Recurse -Force
        Write-Host "✓ Backup completed" -ForegroundColor Green
    }
}

# Function to check if CA exists in Windows trust store
function Test-CAInTrustStore {
    param([string]$CaCommonName)
    try {
        $certs = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Subject -like "*CN=$CaCommonName*" }
        return ($certs.Count -gt 0)
    } catch {
        return $false
    }
}

# Function to generate CA certificate
function New-CACertificate {
    Write-Host "Step 1: Generating Certificate Authority (CA)..." -ForegroundColor Cyan
    
    $caDir = Join-Path $CertsDir "ca"
    $caKeyFile = Join-Path $caDir "ca.key"
    $caCrtFile = Join-Path $caDir "ca.crt"
    
    # Check if CA certificate file already exists
    if ($SkipIfExists -and (Test-Path $caCrtFile)) {
        Write-Host "✓ CA certificate file already exists, skipping generation..." -ForegroundColor Green
        return
    }
    
    # Check if CA exists in Windows trust store
    if (Test-CAInTrustStore $CaName) {
        Write-Host "✓ CA '$CaName' already exists in Windows trust store" -ForegroundColor Green
        if (-not (Test-Path $caCrtFile)) {
            Write-Host "  Note: CA certificate file missing but exists in trust store" -ForegroundColor Yellow
            Write-Host "  You may need to regenerate the certificate files" -ForegroundColor Yellow
        }
    }
    
    if ($BackupExisting) {
        Backup-ExistingCerts $caDir
    }
    
    # Create CA directory
    New-Item -ItemType Directory -Path $caDir -Force | Out-Null
    
    # Generate CA private key
    Write-Host "  Generating CA private key..." -ForegroundColor Gray
    & openssl genrsa -aes256 -out $caKeyFile -passout "pass:$CaKeyPassword" 2048
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate CA private key" }
    
    # Generate CA certificate
    Write-Host "  Generating CA certificate..." -ForegroundColor Gray
    $subject = "/C=$Country/O=$Organization/OU=$OrganizationalUnit/CN=$CaName"
    & openssl req -x509 -new -nodes -key $caKeyFile -passin "pass:$CaKeyPassword" -sha256 -days $CaValidityDays -out $caCrtFile -subj $subject
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate CA certificate" }
    
    Write-Host "✓ CA certificate generated successfully" -ForegroundColor Green
    Write-Host "  CA Certificate: $caCrtFile" -ForegroundColor Gray
    Write-Host "  CA Private Key: $caKeyFile" -ForegroundColor Gray
}

# Function to generate service certificate
function New-ServiceCertificate {
    param(
        [string]$ServiceName,
        [string[]]$AltNames = @(),
        [switch]$GenerateJKS = $false,
        [switch]$GenerateP12 = $true
    )
    
    Write-Host "Step: Generating $ServiceName certificate..." -ForegroundColor Cyan
    
    $serviceDir = Join-Path $CertsDir $ServiceName.ToLower()
    $caDir = Join-Path $CertsDir "ca"
    $caKeyFile = Join-Path $caDir "ca.key"
    $caCrtFile = Join-Path $caDir "ca.crt"
    
    # Service certificate files
    $serviceKeyFile = Join-Path $serviceDir "$ServiceName.key"
    $serviceCsrFile = Join-Path $serviceDir "$ServiceName.csr" 
    $serviceCrtFile = Join-Path $serviceDir "$ServiceName.crt"
    $serviceP12File = Join-Path $serviceDir "$ServiceName.p12"
    $serviceKeystoreFile = Join-Path $serviceDir "$ServiceName.keystore.jks"
    $serviceTruststoreFile = Join-Path $serviceDir "$ServiceName.truststore.jks"
    
    if ($SkipIfExists -and (Test-Path $serviceCrtFile)) {
        Write-Host "✓ $ServiceName certificate already exists, skipping..." -ForegroundColor Green
        return
    }
    
    if ($BackupExisting) {
        Backup-ExistingCerts $serviceDir
    }
    
    # Create service directory
    New-Item -ItemType Directory -Path $serviceDir -Force | Out-Null
    
    # Generate service private key
    Write-Host "  Generating $ServiceName private key..." -ForegroundColor Gray
    & openssl genrsa -out $serviceKeyFile 2048
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate $ServiceName private key" }
    
    # Create certificate configuration with SAN
    $configFile = Join-Path $serviceDir "$ServiceName-cert.cnf"
    $sanList = @($ServiceName, "localhost", "127.0.0.1") + $AltNames
    $sanString = ($sanList | ForEach-Object { if ($_ -match '^\d+\.\d+\.\d+\.\d+$') { "IP:$_" } else { "DNS:$_" } }) -join ","
    
    $configContent = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = $Country
O = $Organization
OU = $OrganizationalUnit
CN = $ServiceName

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
$(($sanList | ForEach-Object -Begin { $i = 1 } -Process { if ($_ -match '^\d+\.\d+\.\d+\.\d+$') { "IP.$i = $_" } else { "DNS.$i = $_" }; $i++ }) -join "`n")
"@
    
    Set-Content -Path $configFile -Value $configContent -Encoding UTF8
    
    # Generate certificate signing request
    Write-Host "  Generating $ServiceName CSR..." -ForegroundColor Gray
    & openssl req -new -key $serviceKeyFile -out $serviceCsrFile -config $configFile
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate $ServiceName CSR" }
    
    # Sign certificate with CA
    Write-Host "  Signing $ServiceName certificate..." -ForegroundColor Gray
    & openssl x509 -req -in $serviceCsrFile -CA $caCrtFile -CAkey $caKeyFile -passin "pass:$CaKeyPassword" -CAcreateserial -out $serviceCrtFile -days $CertValidityDays -extensions v3_req -extfile $configFile
    if ($LASTEXITCODE -ne 0) { throw "Failed to sign $ServiceName certificate" }
    
    # Generate PKCS#12 file if requested
    if ($GenerateP12) {
        Write-Host "  Generating $ServiceName PKCS#12 file..." -ForegroundColor Gray
        & openssl pkcs12 -export -out $serviceP12File -inkey $serviceKeyFile -in $serviceCrtFile -certfile $caCrtFile -passout "pass:$CertPassword"
        if ($LASTEXITCODE -ne 0) { throw "Failed to generate $ServiceName PKCS#12 file" }
    }
    
    # Generate JKS files if requested
    if ($GenerateJKS) {
        Write-Host "  Generating $ServiceName JKS keystore..." -ForegroundColor Gray
        
        # Create keystore from PKCS#12
        & keytool -importkeystore -srckeystore $serviceP12File -srcstoretype PKCS12 -destkeystore $serviceKeystoreFile -deststoretype JKS -srcstorepass $CertPassword -deststorepass $CertPassword -srcalias 1 -destalias $ServiceName -noprompt
        if ($LASTEXITCODE -ne 0) { throw "Failed to generate $ServiceName keystore" }
        
        # Create truststore with CA certificate
        Write-Host "  Generating $ServiceName JKS truststore..." -ForegroundColor Gray
        & keytool -import -trustcacerts -alias ca -file $caCrtFile -keystore $serviceTruststoreFile -storepass $CertPassword -noprompt
        if ($LASTEXITCODE -ne 0) { throw "Failed to generate $ServiceName truststore" }
    }
    
    Write-Host "✓ $ServiceName certificate generated successfully" -ForegroundColor Green
    Write-Host "  Certificate: $serviceCrtFile" -ForegroundColor Gray
    Write-Host "  Private Key: $serviceKeyFile" -ForegroundColor Gray
    if ($GenerateP12) { Write-Host "  PKCS#12: $serviceP12File" -ForegroundColor Gray }
    if ($GenerateJKS) { 
        Write-Host "  Keystore: $serviceKeystoreFile" -ForegroundColor Gray
        Write-Host "  Truststore: $serviceTruststoreFile" -ForegroundColor Gray
    }
    
    # Clean up temporary files
    Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
}

# Main execution
try {
    # Check prerequisites
    if (-not (Test-OpenSSL)) { exit 1 }
    
    # Check if Java/keytool is available for JKS generation
    $canGenerateJKS = Test-Keytool
    
    # Generate CA certificate
    New-CACertificate
    
    # Generate service certificates
    Write-Host ""
    if ($canGenerateJKS) {
        New-ServiceCertificate -ServiceName "elasticsearch" -AltNames @("artemis-elasticsearch", "es", "elastic") -GenerateJKS -GenerateP12
    } else {
        New-ServiceCertificate -ServiceName "elasticsearch" -AltNames @("artemis-elasticsearch", "es", "elastic") -GenerateP12
        Write-Warning "Elasticsearch JKS keystores not generated - keytool not available"
    }
    
    Write-Host ""
    New-ServiceCertificate -ServiceName "kibana" -AltNames @("artemis-kibana", "ki") -GenerateP12
    
    Write-Host ""
    if ($canGenerateJKS) {
        New-ServiceCertificate -ServiceName "kafka" -AltNames @("artemis-kafka", "broker") -GenerateJKS
    } else {
        New-ServiceCertificate -ServiceName "kafka" -AltNames @("artemis-kafka", "broker") -GenerateP12
        Write-Warning "Kafka JKS keystores not generated - keytool not available"
    }
    
    Write-Host ""
    Write-Host "=== Certificate Generation Complete ===" -ForegroundColor Green
    Write-Host ""
    
    # Install CA certificate if requested
    if ($InstallCA) {
        $caCertPath = Join-Path $CertsDir "ca\ca.crt"
        $installScript = Join-Path $CertsDir "Install-CACertificate.ps1"
        
        if (Test-CAInTrustStore $CaName) {
            Write-Host "✓ CA '$CaName' already installed in Windows trust store, skipping installation" -ForegroundColor Green
        } elseif (Test-Path $installScript) {
            Write-Host "Installing CA certificate to Windows trust store..." -ForegroundColor Cyan
            & $installScript -CaCertPath $caCertPath -CaCn $CaName
        } else {
            Write-Warning "Install-CACertificate.ps1 not found, skipping CA installation"
        }
    }
    
    Write-Host ""
    Write-Host "Certificate Summary:" -ForegroundColor Yellow
    Write-Host "- CA: $CaName (valid for $CaValidityDays days)" -ForegroundColor Gray
    Write-Host "- Service certificates valid for $CertValidityDays days" -ForegroundColor Gray
    Write-Host "- Certificate password: $CertPassword" -ForegroundColor Gray
    Write-Host "- All certificates stored in: $CertsDir" -ForegroundColor Gray
    Write-Host ""
    Write-Host "✓ All certificates generated successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "Certificate generation failed: $($_.Exception.Message)"
    exit 1
}