# Install-CACertificate.ps1
# Script to install CA certificate to local machine's Trusted Root Certification Authorities

param(
    [Parameter(Mandatory=$true)]
    [string]$CaCertPath,
    
    [Parameter(Mandatory=$true)]
    [string]$CaCn
)

Write-Host "Installing CA certificate to local machine's Trusted Root Certification Authorities..."

try {
    # Check if running as administrator
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    
    if (-not $isAdmin) {
        Write-Warning "Administrator privileges required to install CA certificate to machine store."
        Write-Host "Please run this script as Administrator to install the CA certificate, or install it manually:"
        Write-Host "1. Open 'certmgr.msc' as Administrator"
        Write-Host "2. Navigate to 'Trusted Root Certification Authorities' -> 'Certificates'"
        Write-Host "3. Right-click -> 'All Tasks' -> 'Import'"
        Write-Host "4. Select the '$CaCertPath' file"
        Write-Host ""
        Write-Host "Alternatively, run this command as Administrator:"
        Write-Host "Import-Certificate -FilePath '$CaCertPath' -CertStoreLocation 'Cert:\LocalMachine\Root'"
        return $false
    } else {
        # Check if certificate file exists
        if (-not (Test-Path $CaCertPath)) {
            Write-Error "CA certificate file not found: $CaCertPath"
            return $false
        }
        
        # Import the CA certificate to the Trusted Root store
        $cert = Import-Certificate -FilePath $CaCertPath -CertStoreLocation "Cert:\LocalMachine\Root"
        Write-Host "✓ CA certificate successfully added to Trusted Root Certification Authorities" -ForegroundColor Green
        Write-Host "  Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Gray
        Write-Host "  Subject: $($cert.Subject)" -ForegroundColor Gray
        Write-Host ""
        Write-Host "You can now access Elasticsearch at https://localhost:9200 without certificate warnings!" -ForegroundColor Green
        return $true
    }
} catch {
    Write-Error "Failed to install CA certificate: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Manual installation instructions:"
    Write-Host "1. Open 'certmgr.msc' as Administrator"
    Write-Host "2. Navigate to 'Trusted Root Certification Authorities' -> 'Certificates'"
    Write-Host "3. Right-click -> 'All Tasks' -> 'Import'"
    Write-Host "4. Select the '$CaCertPath' file"
    return $false
}
