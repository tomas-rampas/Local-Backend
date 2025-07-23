# Generate-AllCertificates.ps1
# Master certificate generation script for Artemis Local Backend
# Generates CA and all service certificates in organized structure

param(
    [string]$CaName = "sysSDSEnvCALocal",
    [string]$CaKeyPassword = "changeme",
    [string]$CertPassword = "changeme", 
    [int]$CaValidityDays = 3650,
    [int]$CertValidityDays = 365,
    [string]$Organization = "Artemis",
    [string]$OrganizationalUnit = "Development",
    [string]$Country = "US",
    [switch]$InstallCA = $true,
    [switch]$InstallEnvLocal = $true,
    [switch]$InstallWithPrivateKey = $true,
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

# Function to get certificate thumbprint from Windows trust store
function Get-CertThumbprintFromTrustStore {
    param([string]$CaCommonName)
    try {
        $cert = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Subject -like "*CN=$CaCommonName*" } | Select-Object -First 1
        if ($cert) {
            return $cert.Thumbprint
        }
        return $null
    } catch {
        return $null
    }
}

# Function to install certificate with private key to Personal store (for development use)
function Install-CertificateWithPrivateKey {
    param(
        [string]$PfxPath,
        [string]$CertPassword,
        [string]$CertificateName
    )
    
    try {
        if (-not (Test-Path $PfxPath)) {
            Write-Warning "PFX file not found: $PfxPath"
            return $false
        }
        
        # Check if running as administrator
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-Warning "Administrator privileges required to install certificate with private key to machine store."
            Write-Host "Please run this script as Administrator to install certificates with private keys." -ForegroundColor Yellow
            return $false
        }
        
        # Import certificate with private key to Personal store
        $securePwd = ConvertTo-SecureString -String $CertPassword -Force -AsPlainText
        $cert = Import-PfxCertificate -FilePath $PfxPath -CertStoreLocation "Cert:\LocalMachine\My" -Password $securePwd -Exportable
        
        Write-Host "✓ $CertificateName certificate with private key installed to Personal store" -ForegroundColor Green
        Write-Host "  Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
        Write-Host "  Store Location: Cert:\LocalMachine\My" -ForegroundColor Gray
        Write-Host "  Private Key Available: $($cert.HasPrivateKey)" -ForegroundColor Gray
        
        return $cert.Thumbprint
        
    } catch {
        Write-Warning "Failed to install certificate with private key: $($_.Exception.Message)"
        Write-Host "Manual installation may be required for development certificate access." -ForegroundColor Yellow
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
    
    # Create CA configuration file with proper CA extensions
    Write-Host "  Creating CA configuration..." -ForegroundColor Gray
    $caConfigFile = Join-Path $caDir "ca.cnf"
    $caConfigContent = @"
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = $Country
O = $Organization
OU = $OrganizationalUnit
CN = $CaName

[v3_ca]
basicConstraints = critical,CA:TRUE
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer:always
"@
    
    Set-Content -Path $caConfigFile -Value $caConfigContent -Encoding UTF8
    
    # Generate CA certificate with proper CA extensions
    Write-Host "  Generating CA certificate with CA extensions..." -ForegroundColor Gray
    $subject = "/C=$Country/O=$Organization/OU=$OrganizationalUnit/CN=$CaName"
    & openssl req -x509 -new -nodes -key $caKeyFile -passin "pass:$CaKeyPassword" -sha256 -days $CaValidityDays -out $caCrtFile -subj $subject -config $caConfigFile -extensions v3_ca
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate CA certificate" }
    
    # Generate CA PFX file for development use (contains both certificate and private key)
    Write-Host "  Generating CA PFX file for development..." -ForegroundColor Gray
    $caPfxFile = Join-Path $caDir "ca.pfx"
    & openssl pkcs12 -export -out $caPfxFile -inkey $caKeyFile -in $caCrtFile -passin "pass:$CaKeyPassword" -passout "pass:$CertPassword"
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate CA PFX file" }
    
    # Clean up CA config file
    Remove-Item -Path $caConfigFile -Force -ErrorAction SilentlyContinue
    
    Write-Host "✓ CA certificate generated successfully with proper CA extensions" -ForegroundColor Green
    Write-Host "  CA Certificate: $caCrtFile" -ForegroundColor Gray
    Write-Host "  CA Private Key: $caKeyFile" -ForegroundColor Gray
    Write-Host "  CA PFX (Development): $caPfxFile" -ForegroundColor Gray
    Write-Host "  Extensions: CA:TRUE, keyCertSign, cRLSign (can issue certificates)" -ForegroundColor Gray
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
    Write-Host "  Extensions: keyEncipherment, dataEncipherment, serverAuth, clientAuth" -ForegroundColor Gray
    
    # Clean up temporary files
    Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
}

# Function to generate environment certificate (for development purposes)
function New-EnvironmentCertificate {
    param(
        [string]$ServiceName,
        [string[]]$AltNames = @()
    )
    
    Write-Host "Step: Generating $ServiceName environment certificate (development)..." -ForegroundColor Cyan
    
    $envDir = Join-Path $CertsDir "env"
    $caDir = Join-Path $CertsDir "ca"
    $caKeyFile = Join-Path $caDir "ca.key"
    $caCrtFile = Join-Path $caDir "ca.crt"
    
    # Environment certificate files
    $envKeyFile = Join-Path $envDir "$ServiceName.key"
    $envCsrFile = Join-Path $envDir "$ServiceName.csr" 
    $envCrtFile = Join-Path $envDir "$ServiceName.crt"
    $envPfxFile = Join-Path $envDir "$ServiceName.pfx"
    
    if ($SkipIfExists -and (Test-Path $envCrtFile)) {
        Write-Host "✓ $ServiceName environment certificate already exists, skipping..." -ForegroundColor Green
        return
    }
    
    if ($BackupExisting) {
        Backup-ExistingCerts $envDir
    }
    
    # Create environment directory
    New-Item -ItemType Directory -Path $envDir -Force | Out-Null
    
    # Generate environment private key
    Write-Host "  Generating $ServiceName private key..." -ForegroundColor Gray
    & openssl genrsa -out $envKeyFile 2048
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate $ServiceName private key" }
    
    # Create certificate configuration with SAN
    $configFile = Join-Path $envDir "$ServiceName-cert.cnf"
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
    & openssl req -new -key $envKeyFile -out $envCsrFile -config $configFile
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate $ServiceName CSR" }
    
    # Sign certificate with CA
    Write-Host "  Signing $ServiceName certificate..." -ForegroundColor Gray
    & openssl x509 -req -in $envCsrFile -CA $caCrtFile -CAkey $caKeyFile -passin "pass:$CaKeyPassword" -CAcreateserial -out $envCrtFile -days $CertValidityDays -extensions v3_req -extfile $configFile
    if ($LASTEXITCODE -ne 0) { throw "Failed to sign $ServiceName certificate" }
    
    # Generate PFX file for development
    Write-Host "  Generating $ServiceName PFX file for development..." -ForegroundColor Gray
    & openssl pkcs12 -export -out $envPfxFile -inkey $envKeyFile -in $envCrtFile -certfile $caCrtFile -passout "pass:$CertPassword"
    if ($LASTEXITCODE -ne 0) { throw "Failed to generate $ServiceName PFX file" }
    
    Write-Host "✓ $ServiceName environment certificate generated successfully" -ForegroundColor Green
    Write-Host "  Certificate: $envCrtFile" -ForegroundColor Gray
    Write-Host "  Private Key: $envKeyFile" -ForegroundColor Gray
    Write-Host "  PFX (Development): $envPfxFile" -ForegroundColor Gray
    Write-Host "  Extensions: keyEncipherment, dataEncipherment (CANNOT be used for signing)" -ForegroundColor Gray
    
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
    
    # Generate sysSDSEnvLocal certificate for development (stored in env/ subdirectory)
    Write-Host ""
    New-EnvironmentCertificate -ServiceName "sysSDSEnvLocal" -AltNames @("localhost", "127.0.0.1")
    
    Write-Host ""
    Write-Host "=== Certificate Generation Complete ===" -ForegroundColor Green
    Write-Host ""
    
    # Install CA certificate if requested
    if ($InstallCA) {
        $caCertPath = Join-Path $CertsDir "ca\ca.crt"
        $caPfxPath = Join-Path $CertsDir "ca\ca.pfx"
        $installScript = Join-Path $CertsDir "Install-CACertificate.ps1"
        
        # Install to trusted root store (public certificate only)
        if (Test-CAInTrustStore $CaName) {
            Write-Host "✓ CA '$CaName' already installed in Windows trust store, skipping trust store installation" -ForegroundColor Green
        } elseif (Test-Path $installScript) {
            Write-Host "Installing CA certificate to Windows trust store..." -ForegroundColor Cyan
            & $installScript -CaCertPath $caCertPath -CaCn $CaName
        } else {
            Write-Warning "Install-CACertificate.ps1 not found, skipping CA trust store installation"
        }
        
        # Install to personal store with private key (for development certificate signing)
        if ($InstallWithPrivateKey -and (Test-Path $caPfxPath)) {
            Write-Host "Installing CA certificate with private key to Personal store for development..." -ForegroundColor Cyan
            $caThumbprintFromPersonal = Install-CertificateWithPrivateKey -PfxPath $caPfxPath -CertPassword $CertPassword -CertificateName "CA ($CaName)"
        } else {
            Write-Host "  Skipping CA private key installation (use -InstallWithPrivateKey to enable)" -ForegroundColor Gray
        }
    }
    
    # Install sysSDSEnvLocal certificate if requested
    if ($InstallEnvLocal) {
        $envLocalCertPath = Join-Path $CertsDir "env\sysSDSEnvLocal.crt"
        $envLocalPfxPath = Join-Path $CertsDir "env\sysSDSEnvLocal.pfx"
        $installScript = Join-Path $CertsDir "Install-CACertificate.ps1"
        
        # Install to trusted root store (public certificate only)
        if (Test-CAInTrustStore "sysSDSEnvLocal") {
            Write-Host "✓ sysSDSEnvLocal certificate already installed in Windows trust store, skipping trust store installation" -ForegroundColor Green
        } elseif (Test-Path $installScript) {
            Write-Host "Installing sysSDSEnvLocal certificate to Windows trust store..." -ForegroundColor Cyan
            & $installScript -CaCertPath $envLocalCertPath -CaCn "sysSDSEnvLocal"
        } else {
            Write-Warning "Install-CACertificate.ps1 not found, skipping sysSDSEnvLocal trust store installation"
        }
        
        # Install to personal store with private key (for development use)
        if ($InstallWithPrivateKey -and (Test-Path $envLocalPfxPath)) {
            Write-Host "Installing sysSDSEnvLocal certificate with private key to Personal store for development..." -ForegroundColor Cyan
            $envLocalThumbprintFromPersonal = Install-CertificateWithPrivateKey -PfxPath $envLocalPfxPath -CertPassword $CertPassword -CertificateName "Environment (sysSDSEnvLocal)"
        } else {
            Write-Host "  Skipping sysSDSEnvLocal private key installation (use -InstallWithPrivateKey to enable)" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "Certificate Summary:" -ForegroundColor Yellow
    Write-Host "- CA: $CaName (valid for $CaValidityDays days)" -ForegroundColor Gray
    Write-Host "- Service certificates valid for $CertValidityDays days" -ForegroundColor Gray
    Write-Host "- Environment certificate (sysSDSEnvLocal) generated in env/ subdirectory" -ForegroundColor Gray
    Write-Host "- Certificate password: $CertPassword" -ForegroundColor Gray
    Write-Host "- All certificates stored in: $CertsDir" -ForegroundColor Gray
    if ($InstallWithPrivateKey) {
        Write-Host "- Certificates installed with private keys to Personal store for development" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "✓ All certificates generated successfully!" -ForegroundColor Green
    
    # Display important certificate thumbprint information
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "║" -ForegroundColor Red -NoNewline
    Write-Host "                          ⚠️  IMPORTANT INFORMATION  ⚠️                        " -ForegroundColor Yellow -NoNewline
    Write-Host "║" -ForegroundColor Red
    Write-Host "║" -ForegroundColor Red -NoNewline
    Write-Host "                            DO NOT OVERLOOK THIS!                              " -ForegroundColor Yellow -NoNewline
    Write-Host "║" -ForegroundColor Red
    Write-Host "╠═══════════════════════════════════════════════════════════════════════════════╣" -ForegroundColor Red
    Write-Host "║" -ForegroundColor Red -NoNewline
    Write-Host "                                                                               " -NoNewline
    Write-Host "║" -ForegroundColor Red
    
    # Get certificate thumbprints
    $caThumbprint = Get-CertThumbprintFromTrustStore $CaName
    $envLocalThumbprint = Get-CertThumbprintFromTrustStore "sysSDSEnvLocal"
    
    if ($caThumbprint -and $envLocalThumbprint) {
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host " Before you run any service, please update your local.json configuration:      " -ForegroundColor White -NoNewline
        Write-Host "║" -ForegroundColor Red
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host "                                                                               " -NoNewline
        Write-Host "║" -ForegroundColor Red
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host " 1. Set your certificate with purpose SIGNING to this thumbprint:              " -ForegroundColor White -NoNewline
        Write-Host "║" -ForegroundColor Red
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host "    $caThumbprint                                   " -ForegroundColor Cyan -NoNewline
        Write-Host "║" -ForegroundColor Red
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host "                                                                               " -NoNewline
        Write-Host "║" -ForegroundColor Red
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host " 2. Set the environment purpose certificate to this thumbprint:                " -ForegroundColor White -NoNewline
        Write-Host "║" -ForegroundColor Red
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host "    $envLocalThumbprint                                   " -ForegroundColor Cyan -NoNewline
        Write-Host "║" -ForegroundColor Red
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host "                                                                               " -NoNewline
        Write-Host "║" -ForegroundColor Red
    } else {
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host " Certificate thumbprints could not be retrieved from Windows trust store.      " -ForegroundColor Yellow -NoNewline
        Write-Host "║" -ForegroundColor Red
        Write-Host "║" -ForegroundColor Red -NoNewline
        Write-Host " Please verify certificates are installed correctly and check manually.        " -ForegroundColor Yellow -NoNewline
        Write-Host "║" -ForegroundColor Red
    }
    
    Write-Host "║" -ForegroundColor Red -NoNewline
    Write-Host "                                                                               " -NoNewline
    Write-Host "║" -ForegroundColor Red
    Write-Host "╚═══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""    
} catch {
    Write-Error "Certificate generation failed: $($_.Exception.Message)"
    exit 1
}