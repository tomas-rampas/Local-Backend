# Generate-ServiceCertificates.ps1
# Service certificate generation script using existing CA from Windows Certificate Store
# Generates JKS, P12, and PEM certificates for Artemis Local Backend services

param(
    [string]$CaThumbprint,           # CA certificate thumbprint for lookup
    [string]$CaSubjectName = "sysSDSEnvCALocal",  # Alternative: CA subject name lookup
    [string[]]$Services = @("elasticsearch", "kafka", "kibana"),  # Services to generate certificates for
    [string]$CertPassword = "changeme",   # Password for P12 and JKS files
    [int]$ValidityDays = 365,        # Certificate validity period
    [switch]$GenerateJKS = $true,    # Generate JKS keystore and truststore
    [switch]$GenerateP12 = $true,    # Generate PKCS#12 files
    [switch]$InstallToStore = $false, # Install certificates to Windows certificate store
    [switch]$BackupExisting = $true, # Backup existing certificates
    [switch]$SkipIfExists = $false,  # Skip certificate generation if it already exists
    [string]$Organization = "Artemis", # Certificate organization
    [string]$OrganizationalUnit = "Development", # Certificate organizational unit
    [string]$Country = "US"          # Certificate country
)

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$CertsDir = $ScriptDir

# Add required .NET assemblies
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Security.Cryptography.X509Certificates

Write-Host "=== Artemis Service Certificate Generation Script ===" -ForegroundColor Green
Write-Host "Certificate directory: $CertsDir" -ForegroundColor Yellow
Write-Host "Services: $($Services -join ', ')" -ForegroundColor Yellow
Write-Host ""

# Function to check if keytool is available for JKS generation
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

# Function to create backup of existing certificates
function Backup-ExistingCertificates {
    param([string]$Directory)
    
    if (Test-Path $Directory) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupDir = Join-Path $CertsDir "backup_$timestamp"
        
        Write-Host "  Creating backup of existing certificates..." -ForegroundColor Gray
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        
        try {
            Copy-Item -Path $Directory -Destination $backupDir -Recurse -Force
            Write-Verbose "Backup created: $backupDir"
        } catch {
            Write-Warning "Failed to create backup: $($_.Exception.Message)"
        }
    }
}

# Function to find CA certificate in Windows certificate stores
function Find-CACertificate {
    param(
        [string]$Thumbprint,
        [string]$SubjectName
    )
    
    Write-Host "Step: Locating CA certificate in Windows certificate store..." -ForegroundColor Cyan
    
    # Define stores to search (Personal store first, then Root store)
    $storesToSearch = @(
        @{Location = "LocalMachine"; Name = "My"; Description = "Personal"},
        @{Location = "LocalMachine"; Name = "Root"; Description = "Trusted Root"},
        @{Location = "CurrentUser"; Name = "My"; Description = "User Personal"},
        @{Location = "CurrentUser"; Name = "Root"; Description = "User Trusted Root"}
    )
    
    foreach ($storeInfo in $storesToSearch) {
        try {
            Write-Verbose "Searching in $($storeInfo.Description) store ($($storeInfo.Location)\$($storeInfo.Name))"
            
            $store = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeInfo.Name, $storeInfo.Location)
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
            
            $foundCert = $null
            
            if ($Thumbprint) {
                # Search by thumbprint
                $foundCerts = $store.Certificates.Find(
                    [System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,
                    $Thumbprint,
                    $false
                )
                if ($foundCerts.Count -gt 0) {
                    $foundCert = $foundCerts[0]
                }
            } elseif ($SubjectName) {
                # Search by subject name - look for exact CN match
                $foundCerts = $store.Certificates.Find(
                    [System.Security.Cryptography.X509Certificates.X509FindType]::FindBySubjectName,
                    $SubjectName,
                    $false
                )
                
                Write-Verbose "Found $($foundCerts.Count) certificates matching subject name '$SubjectName' in $($storeInfo.Description)"
                
                # Filter for CA certificates (those with CA:TRUE extension) and prefer ones with private keys
                $caCandidates = @()
                foreach ($cert in $foundCerts) {
                    Write-Verbose "Checking certificate with thumbprint: $($cert.Thumbprint)"
                    
                    # Check if it has CA extensions
                    $basicConstraints = $cert.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.19" }
                    $isCA = $basicConstraints -and $basicConstraints.CertificateAuthority
                    
                    Write-Verbose "  Is CA: $isCA, Has Private Key: $($cert.HasPrivateKey)"
                    
                    if ($isCA -or (-not $basicConstraints)) {
                        # If no basic constraints extension, assume it could be a CA (some certificates don't have this properly set)
                        $caCandidates += $cert
                    }
                }
                
                # Prefer certificates with private keys
                $foundCert = $caCandidates | Where-Object { $_.HasPrivateKey } | Select-Object -First 1
                if (-not $foundCert) {
                    $foundCert = $caCandidates | Select-Object -First 1
                }
                
                if ($foundCert) {
                    Write-Verbose "Selected CA certificate with thumbprint: $($foundCert.Thumbprint)"
                }
            }
            
            if ($foundCert) {
                # Validate CA certificate and test private key access
                if (-not $foundCert.HasPrivateKey) {
                    Write-Verbose "Certificate found but no private key access in $($storeInfo.Description) store"
                    $store.Close()
                    continue
                }
                
                # Test if private key is actually accessible
                try {
                    # Try newer method first
                    $testKey = $null
                    if ($foundCert.PSObject.Methods.Name -contains "GetRSAPrivateKey") {
                        $testKey = $foundCert.GetRSAPrivateKey()
                    } else {
                        # Fallback to older method
                        $testKey = $foundCert.PrivateKey
                    }
                    
                    if ($testKey -eq $null) {
                        Write-Verbose "Certificate shows HasPrivateKey=True but private key not accessible via .NET methods"
                        Write-Warning "Certificate found but private key not accessible in $($storeInfo.Description) store"
                        $store.Close()
                        continue
                    } else {
                        Write-Verbose "Private key successfully accessed via .NET methods"
                        # Dispose if it has the method
                        if ($testKey.PSObject.Methods.Name -contains "Dispose") {
                            $testKey.Dispose()
                        }
                    }
                } catch {
                    Write-Verbose "Private key access test failed: $($_.Exception.Message)"
                    Write-Warning "Certificate found but private key access failed in $($storeInfo.Description) store"
                    $store.Close()
                    continue
                }
                
                # Check if it's a CA certificate
                $basicConstraints = $foundCert.Extensions | Where-Object { $_.Oid.Value -eq "2.5.29.19" }
                $isProperCA = $basicConstraints -and $basicConstraints.CertificateAuthority
                
                # If searching by subject name and it matches sysSDSEnvCALocal, assume it's a CA even without proper extensions
                $isCaByName = $SubjectName -and $foundCert.Subject -like "*$SubjectName*"
                
                if (-not $isProperCA -and -not $isCaByName) {
                    Write-Verbose "Certificate found but not recognized as CA certificate in $($storeInfo.Description) store"
                    $store.Close()
                    continue
                }
                
                if (-not $isProperCA -and $isCaByName) {
                    Write-Verbose "Certificate doesn't have proper CA extensions but matches CA name - proceeding anyway"
                }
                
                Write-Host "✓ CA certificate found in $($storeInfo.Description) store" -ForegroundColor Green
                Write-Host "  Subject: $($foundCert.Subject)" -ForegroundColor Gray
                Write-Host "  Thumbprint: $($foundCert.Thumbprint)" -ForegroundColor Gray
                Write-Host "  Valid from: $($foundCert.NotBefore) to $($foundCert.NotAfter)" -ForegroundColor Gray
                Write-Host "  Has Private Key: $($foundCert.HasPrivateKey)" -ForegroundColor Gray
                
                $store.Close()
                return $foundCert
            }
            
            $store.Close()
        } catch {
            Write-Verbose "Error searching in $($storeInfo.Description) store: $($_.Exception.Message)"
            if ($store) { $store.Close() }
        }
    }
    
    throw "CA certificate not found. Please ensure '$SubjectName' or thumbprint '$Thumbprint' exists in Windows certificate store with private key access."
}

# Function to generate service certificate using Windows CA
function New-ServiceCertificateWithCA {
    param(
        [string]$ServiceName,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$CaCertificate,
        [string[]]$SubjectAlternativeNames = @()
    )
    
    Write-Host "Step: Generating $ServiceName certificate using Windows CA..." -ForegroundColor Cyan
    
    $serviceDir = Join-Path $CertsDir $ServiceName.ToLower()
    
    # Service certificate files
    $serviceCrtFile = Join-Path $serviceDir "$ServiceName.crt"
    $serviceKeyFile = Join-Path $serviceDir "$ServiceName.key"
    
    if ($SkipIfExists -and (Test-Path $serviceCrtFile)) {
        Write-Host "✓ $ServiceName certificate already exists, skipping..." -ForegroundColor Green
        return Get-Content $serviceCrtFile -Raw
    }
    
    if ($BackupExisting) {
        Backup-ExistingCertificates $serviceDir
    }
    
    # Create service directory
    New-Item -ItemType Directory -Path $serviceDir -Force | Out-Null
    
    try {
        Write-Host "  Creating RSA key pair..." -ForegroundColor Gray
        
        # Create RSA key pair
        $rsa = [System.Security.Cryptography.RSA]::Create(2048)
        
        # Create certificate request
        $distinguishedName = "CN=$ServiceName, OU=$OrganizationalUnit, O=$Organization, C=$Country"
        $certRequest = [System.Security.Cryptography.X509Certificates.CertificateRequest]::new(
            $distinguishedName,
            $rsa,
            [System.Security.Cryptography.HashAlgorithmName]::SHA256,
            [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
        )
        
        Write-Host "  Adding certificate extensions..." -ForegroundColor Gray
        
        # Add Key Usage extension
        $keyUsage = [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::KeyEncipherment -bor
                   [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DataEncipherment
        $keyUsageExtension = [System.Security.Cryptography.X509Certificates.X509KeyUsageExtension]::new($keyUsage, $true)
        $certRequest.CertificateExtensions.Add($keyUsageExtension)
        
        # Add Enhanced Key Usage extension
        $ekuOids = [System.Security.Cryptography.OidCollection]::new()
        $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.1")) # Server Authentication
        $ekuOids.Add([System.Security.Cryptography.Oid]::new("1.3.6.1.5.5.7.3.2")) # Client Authentication
        $ekuExtension = [System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($ekuOids, $true)
        $certRequest.CertificateExtensions.Add($ekuExtension)
        
        # Add Subject Alternative Names if provided
        $sanList = @($ServiceName, "localhost", "127.0.0.1") + $SubjectAlternativeNames
        $sanBuilder = [System.Security.Cryptography.X509Certificates.SubjectAlternativeNameBuilder]::new()
        
        foreach ($san in $sanList) {
            if ($san -match '^\d+\.\d+\.\d+\.\d+$') {
                # IP Address
                $sanBuilder.AddIpAddress([System.Net.IPAddress]::Parse($san))
                Write-Verbose "Added IP SAN: $san"
            } else {
                # DNS Name
                $sanBuilder.AddDnsName($san)
                Write-Verbose "Added DNS SAN: $san"
            }
        }
        
        $sanExtension = $sanBuilder.Build()
        $certRequest.CertificateExtensions.Add($sanExtension)
        
        Write-Host "  Signing certificate with CA..." -ForegroundColor Gray
        
        # Generate serial number
        $serialNumber = [byte[]]::new(16)
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $rng.GetBytes($serialNumber)
        
        # Create certificate signed by CA
        $notBefore = [DateTime]::Now.AddMinutes(-5)  # 5 minutes ago to account for clock skew
        $notAfter = $notBefore.AddDays($ValidityDays)
        
        # Create certificate using the CA
        $serviceCert = $certRequest.Create($CaCertificate, $notBefore, $notAfter, $serialNumber)
        
        # Export certificate to PEM format
        Write-Host "  Exporting certificate to PEM format..." -ForegroundColor Gray
        
        $certPem = "-----BEGIN CERTIFICATE-----`n"
        $certPem += [Convert]::ToBase64String($serviceCert.RawData, [Base64FormattingOptions]::InsertLineBreaks)
        $certPem += "`n-----END CERTIFICATE-----`n"
        
        Set-Content -Path $serviceCrtFile -Value $certPem -Encoding UTF8
        
        # Export private key to PEM format
        $keyPem = "-----BEGIN PRIVATE KEY-----`n"
        $keyPem += [Convert]::ToBase64String($rsa.ExportPkcs8PrivateKey(), [Base64FormattingOptions]::InsertLineBreaks)
        $keyPem += "`n-----END PRIVATE KEY-----`n"
        
        Set-Content -Path $serviceKeyFile -Value $keyPem -Encoding UTF8
        
        Write-Host "✓ $ServiceName certificate generated successfully" -ForegroundColor Green
        Write-Host "  Certificate: $serviceCrtFile" -ForegroundColor Gray
        Write-Host "  Private Key: $serviceKeyFile" -ForegroundColor Gray
        Write-Host "  Valid from: $($serviceCert.NotBefore) to $($serviceCert.NotAfter)" -ForegroundColor Gray
        Write-Host "  Subject: $($serviceCert.Subject)" -ForegroundColor Gray
        Write-Host "  SAN: $($sanList -join ', ')" -ForegroundColor Gray
        
        # Return the certificate with private key for further processing
        $certWithKey = $serviceCert.CopyWithPrivateKey($rsa)
        return $certWithKey
        
    } catch {
        Write-Error "Failed to generate $ServiceName certificate: $($_.Exception.Message)"
        throw
    } finally {
        if ($rsa) { $rsa.Dispose() }
    }
}

# Function to export certificate to PKCS#12 format
function Export-ToPKCS12 {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$CaCertificate,
        [string]$ServiceName,
        [string]$Password
    )
    
    Write-Host "  Exporting to PKCS#12 format..." -ForegroundColor Gray
    
    $serviceDir = Join-Path $CertsDir $ServiceName.ToLower()
    $serviceP12File = Join-Path $serviceDir "$ServiceName.p12"
    
    try {
        # Create certificate collection with service cert and CA cert
        $certCollection = [System.Security.Cryptography.X509Certificates.X509Certificate2Collection]::new()
        $certCollection.Add($Certificate)
        $certCollection.Add($CaCertificate)
        
        # Export to PKCS#12 with password
        $p12Bytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $Password)
        [System.IO.File]::WriteAllBytes($serviceP12File, $p12Bytes)
        
        Write-Verbose "PKCS#12 file created: $serviceP12File"
        return $serviceP12File
        
    } catch {
        Write-Warning "Failed to create PKCS#12 file: $($_.Exception.Message)"
        return $null
    }
}

# Function to convert certificate to JKS format
function Convert-ToJKS {
    param(
        [string]$ServiceName,
        [string]$P12File,
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$CaCertificate,
        [string]$Password
    )
    
    Write-Host "  Converting to JKS format..." -ForegroundColor Gray
    
    $serviceDir = Join-Path $CertsDir $ServiceName.ToLower()
    $serviceKeystoreFile = Join-Path $serviceDir "$ServiceName.keystore.jks"
    $serviceTruststoreFile = Join-Path $serviceDir "$ServiceName.truststore.jks"
    
    if (-not (Test-Keytool)) {
        Write-Warning "Skipping JKS generation - keytool not available"
        return $false
    }
    
    try {
        # Create temporary CA certificate file for truststore
        $tempCaFile = Join-Path $serviceDir "temp_ca.crt"
        $caPem = "-----BEGIN CERTIFICATE-----`n"
        $caPem += [Convert]::ToBase64String($CaCertificate.RawData, [Base64FormattingOptions]::InsertLineBreaks)
        $caPem += "`n-----END CERTIFICATE-----`n"
        Set-Content -Path $tempCaFile -Value $caPem -Encoding UTF8
        
        Write-Verbose "Creating JKS keystore from PKCS#12..."
        
        # Create keystore from PKCS#12
        $keystoreArgs = @(
            "-importkeystore",
            "-srckeystore", "`"$P12File`"",
            "-srcstoretype", "PKCS12",
            "-destkeystore", "`"$serviceKeystoreFile`"",
            "-deststoretype", "JKS",
            "-srcstorepass", $Password,
            "-deststorepass", $Password,
            "-srcalias", "1",
            "-destalias", $ServiceName,
            "-noprompt"
        )
        
        $keystoreResult = & keytool @keystoreArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to create JKS keystore: $keystoreResult"
            return $false
        }
        
        Write-Verbose "Creating JKS truststore with CA certificate..."
        
        # Create truststore with CA certificate
        $truststoreArgs = @(
            "-import",
            "-trustcacerts",
            "-alias", "ca",
            "-file", "`"$tempCaFile`"",
            "-keystore", "`"$serviceTruststoreFile`"",
            "-storepass", $Password,
            "-noprompt"
        )
        
        $truststoreResult = & keytool @truststoreArgs 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to create JKS truststore: $truststoreResult"
            return $false
        }
        
        Write-Verbose "JKS keystore created: $serviceKeystoreFile"
        Write-Verbose "JKS truststore created: $serviceTruststoreFile"
        
        return $true
        
    } catch {
        Write-Warning "Failed to create JKS files: $($_.Exception.Message)"
        return $false
    } finally {
        # Clean up temporary CA file
        if (Test-Path $tempCaFile) {
            Remove-Item -Path $tempCaFile -Force -ErrorAction SilentlyContinue
        }
    }
}

# Function to install certificate to Windows certificate store
function Install-ServiceCertificate {
    param(
        [System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [string]$ServiceName
    )
    
    if (-not $InstallToStore) {
        return
    }
    
    Write-Host "  Installing certificate to Windows certificate store..." -ForegroundColor Gray
    
    try {
        # Install to Personal store (My)
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("My", "LocalMachine")
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $store.Add($Certificate)
        $store.Close()
        
        Write-Host "✓ Certificate installed to Personal store (LocalMachine\My)" -ForegroundColor Green
        Write-Verbose "Certificate thumbprint: $($Certificate.Thumbprint)"
        
    } catch {
        Write-Warning "Failed to install certificate to Windows store: $($_.Exception.Message)"
    }
}

# Main execution logic
try {
    Write-Host "Starting certificate generation process..." -ForegroundColor Yellow
    Write-Host ""
    
    # Step 1: Find CA certificate
    $caCert = $null
    if ($CaThumbprint) {
        Write-Verbose "Looking for CA certificate by thumbprint: $CaThumbprint"
        $caCert = Find-CACertificate -Thumbprint $CaThumbprint
    } else {
        Write-Verbose "Looking for CA certificate by subject name: $CaSubjectName"
        $caCert = Find-CACertificate -SubjectName $CaSubjectName
    }
    
    if (-not $caCert) {
        throw "CA certificate not found. Please ensure it exists in Windows certificate store."
    }
    
    Write-Host ""
    
    # Define service-specific configurations
    $serviceConfigs = @{
        "elasticsearch" = @{
            Name = "elasticsearch"
            AltNames = @("elastic", "es")
        }
        "kafka" = @{
            Name = "kafka"
            AltNames = @("kafka-broker")
        }
        "kibana" = @{
            Name = "kibana"
            AltNames = @("kibana-server")
        }
    }
    
    # Step 2: Generate certificates for each service
    $results = @()
    foreach ($serviceName in $Services) {
        $serviceName = $serviceName.ToLower()
        
        if (-not $serviceConfigs.ContainsKey($serviceName)) {
            Write-Warning "Unknown service '$serviceName'. Skipping..."
            continue
        }
        
        $serviceConfig = $serviceConfigs[$serviceName]
        $result = @{
            ServiceName = $serviceName
            Success = $false
            Certificate = $null
            P12File = $null
            JKSCreated = $false
            ErrorMessage = $null
        }
        
        try {
            # Generate service certificate
            $serviceCert = New-ServiceCertificateWithCA -ServiceName $serviceConfig.Name -CaCertificate $caCert -SubjectAlternativeNames $serviceConfig.AltNames
            $result.Certificate = $serviceCert
            
            # Export to PKCS#12 if requested
            if ($GenerateP12) {
                $p12File = Export-ToPKCS12 -Certificate $serviceCert -CaCertificate $caCert -ServiceName $serviceConfig.Name -Password $CertPassword
                $result.P12File = $p12File
                
                if ($p12File) {
                    Write-Host "  PKCS#12: $p12File" -ForegroundColor Gray
                }
            }
            
            # Convert to JKS if requested
            if ($GenerateJKS -and $result.P12File) {
                $jksSuccess = Convert-ToJKS -ServiceName $serviceConfig.Name -P12File $result.P12File -CaCertificate $caCert -Password $CertPassword
                $result.JKSCreated = $jksSuccess
                
                if ($jksSuccess) {
                    $serviceDir = Join-Path $CertsDir $serviceConfig.Name
                    Write-Host "  Keystore: $(Join-Path $serviceDir "$($serviceConfig.Name).keystore.jks")" -ForegroundColor Gray
                    Write-Host "  Truststore: $(Join-Path $serviceDir "$($serviceConfig.Name).truststore.jks")" -ForegroundColor Gray
                }
            }
            
            # Install to Windows certificate store if requested
            Install-ServiceCertificate -Certificate $serviceCert -ServiceName $serviceConfig.Name
            
            $result.Success = $true
            Write-Host ""
            
        } catch {
            $result.ErrorMessage = $_.Exception.Message
            Write-Error "Failed to generate certificate for $serviceName : $($_.Exception.Message)"
            Write-Host ""
        }
        
        $results += $result
    }
    
    # Step 3: Summary
    Write-Host "=== Certificate Generation Summary ===" -ForegroundColor Green
    Write-Host ""
    
    $successCount = ($results | Where-Object { $_.Success }).Count
    $totalCount = $results.Count
    
    Write-Host "Overall Status: $successCount/$totalCount services completed successfully" -ForegroundColor $(if ($successCount -eq $totalCount) { "Green" } else { "Yellow" })
    Write-Host ""
    
    foreach ($result in $results) {
        $status = if ($result.Success) { "✓" } else { "✗" }
        $color = if ($result.Success) { "Green" } else { "Red" }
        
        Write-Host "$status $($result.ServiceName.ToUpper())" -ForegroundColor $color
        
        if ($result.Success) {
            $serviceDir = Join-Path $CertsDir $result.ServiceName
            Write-Host "    Certificate: $(Join-Path $serviceDir "$($result.ServiceName).crt")" -ForegroundColor Gray
            Write-Host "    Private Key: $(Join-Path $serviceDir "$($result.ServiceName).key")" -ForegroundColor Gray
            
            if ($GenerateP12 -and $result.P12File) {
                Write-Host "    PKCS#12: $($result.P12File)" -ForegroundColor Gray
            }
            
            if ($GenerateJKS -and $result.JKSCreated) {
                Write-Host "    JKS Keystore: $(Join-Path $serviceDir "$($result.ServiceName).keystore.jks")" -ForegroundColor Gray
                Write-Host "    JKS Truststore: $(Join-Path $serviceDir "$($result.ServiceName).truststore.jks")" -ForegroundColor Gray
            }
            
            if ($InstallToStore) {
                Write-Host "    Installed to: LocalMachine\My certificate store" -ForegroundColor Gray
            }
        } else {
            Write-Host "    Error: $($result.ErrorMessage)" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Step 4: Additional information
    Write-Host "=== Additional Information ===" -ForegroundColor Cyan
    Write-Host "CA Certificate Used:" -ForegroundColor Yellow
    Write-Host "  Subject: $($caCert.Subject)" -ForegroundColor Gray
    Write-Host "  Thumbprint: $($caCert.Thumbprint)" -ForegroundColor Gray
    Write-Host "  Valid Until: $($caCert.NotAfter)" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Certificate Details:" -ForegroundColor Yellow
    Write-Host "  Password for P12/JKS files: $CertPassword" -ForegroundColor Gray
    Write-Host "  Validity Period: $ValidityDays days" -ForegroundColor Gray
    Write-Host "  Organization: $Organization" -ForegroundColor Gray
    Write-Host "  Organizational Unit: $OrganizationalUnit" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "Usage in Docker Compose:" -ForegroundColor Yellow
    Write-Host "  The generated certificates maintain the same file structure as the original script," -ForegroundColor Gray
    Write-Host "  so no changes to docker-compose.yml are required." -ForegroundColor Gray
    Write-Host ""
    
    if ($successCount -eq $totalCount) {
        Write-Host "✓ All certificates generated successfully!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "⚠ Some certificates failed to generate. Check the errors above." -ForegroundColor Yellow
        exit 1
    }
    
} catch {
    Write-Host ""
    Write-Host "FATAL ERROR: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Ensure you have administrator privileges" -ForegroundColor Gray
    Write-Host "2. Verify CA certificate exists in Windows certificate store" -ForegroundColor Gray
    Write-Host "3. Check that CA certificate has private key access" -ForegroundColor Gray
    Write-Host "4. For JKS generation, ensure Java JDK is installed with keytool in PATH" -ForegroundColor Gray
    Write-Host ""
    Write-Host "For CA certificate issues, run: Get-ChildItem Cert:\LocalMachine\My | Where-Object { `$_.Subject -like '*sysSDSEnvCALocal*' }" -ForegroundColor Gray
    Write-Host ""
    exit 2
}