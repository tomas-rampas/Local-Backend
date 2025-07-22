#!/usr/bin/env pwsh
<#
.SYNOPSIS
    PowerShell 7 Installation Guide and Setup Script
    
.DESCRIPTION
    Provides platform-specific installation instructions and performs basic setup
    for PowerShell 7 cross-platform development with the Artemis Backend test suite.
    
.PARAMETER ShowInstructions
    Display installation instructions for the current platform
    
.PARAMETER VerifyInstallation
    Verify PowerShell 7 and Docker are properly installed and configured
    
.PARAMETER SetupEnvironment
    Configure environment for cross-platform development
    
.EXAMPLE
    .\Install-PowerShell7.ps1 -ShowInstructions
    .\Install-PowerShell7.ps1 -VerifyInstallation
    .\Install-PowerShell7.ps1 -SetupEnvironment
#>

param(
    [switch]$ShowInstructions,
    [switch]$VerifyInstallation,
    [switch]$SetupEnvironment
)

# Load platform utilities if available
try {
    . $PSScriptRoot/Platform-Utilities.ps1
} catch {
    # Define minimal platform detection if utilities aren't available
    function Get-CurrentPlatform {
        $platform = @{
            IsWindows = $false
            IsLinux = $false
            IsMacOS = $false
            IsWSL = $false
        }
        
        if ($PSVersionTable.PSVersion.Major -ge 6) {
            $platform.IsWindows = $IsWindows
            $platform.IsLinux = $IsLinux
            $platform.IsMacOS = $IsMacOS
        } else {
            $platform.IsWindows = $true
        }
        
        return $platform
    }
}

function Show-InstallationInstructions {
    $platform = Get-CurrentPlatform
    
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "           POWERSHELL 7 INSTALLATION GUIDE                   " -ForegroundColor Cyan  
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    if ($platform.IsWindows) {
        Write-Host "🪟 Windows Installation:" -ForegroundColor Blue
        Write-Host ""
        Write-Host "Method 1: Windows Package Manager (Recommended)" -ForegroundColor Yellow
        Write-Host "winget install --id Microsoft.Powershell --source winget" -ForegroundColor Green
        Write-Host ""
        Write-Host "Method 2: Chocolatey" -ForegroundColor Yellow
        Write-Host "choco install powershell" -ForegroundColor Green
        Write-Host ""
        Write-Host "Method 3: Direct Download" -ForegroundColor Yellow
        Write-Host "https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Green
        Write-Host "Download and run the .msi installer" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Method 4: Microsoft Store" -ForegroundColor Yellow
        Write-Host "Search for 'PowerShell' in Microsoft Store" -ForegroundColor Green
        
    } elseif ($platform.IsLinux) {
        Write-Host "🐧 Linux Installation:" -ForegroundColor Blue
        Write-Host ""
        Write-Host "Ubuntu/Debian (Recommended):" -ForegroundColor Yellow
        Write-Host "# Update package list" -ForegroundColor Gray
        Write-Host "sudo apt-get update" -ForegroundColor Green
        Write-Host "sudo apt-get install -y wget apt-transport-https software-properties-common" -ForegroundColor Green
        Write-Host ""
        Write-Host "# Add Microsoft repository" -ForegroundColor Gray
        Write-Host 'wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"' -ForegroundColor Green
        Write-Host "sudo dpkg -i packages-microsoft-prod.deb" -ForegroundColor Green
        Write-Host "sudo apt-get update" -ForegroundColor Green
        Write-Host ""
        Write-Host "# Install PowerShell 7" -ForegroundColor Gray
        Write-Host "sudo apt-get install -y powershell" -ForegroundColor Green
        Write-Host ""
        Write-Host "Alternative - Direct Package:" -ForegroundColor Yellow
        Write-Host "wget https://github.com/PowerShell/PowerShell/releases/download/v7.4.11/powershell_7.4.11-1.deb_amd64.deb" -ForegroundColor Green
        Write-Host "sudo dpkg -i powershell*.deb" -ForegroundColor Green
        Write-Host "sudo apt-get install -f" -ForegroundColor Green
        
    } elseif ($platform.IsMacOS) {
        Write-Host "🍎 macOS Installation:" -ForegroundColor Blue
        Write-Host ""
        Write-Host "Method 1: Homebrew (Recommended)" -ForegroundColor Yellow
        Write-Host "brew install --cask powershell" -ForegroundColor Green
        Write-Host ""
        Write-Host "Method 2: MacPorts" -ForegroundColor Yellow
        Write-Host "sudo port install powershell" -ForegroundColor Green
        Write-Host ""
        Write-Host "Method 3: Direct Download" -ForegroundColor Yellow
        Write-Host "https://github.com/PowerShell/PowerShell/releases" -ForegroundColor Green
        Write-Host "Download and install the .pkg file" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "📋 Post-Installation Steps:" -ForegroundColor Blue
    Write-Host "1. Verify installation: pwsh --version" -ForegroundColor Gray
    Write-Host "2. Start PowerShell 7: pwsh" -ForegroundColor Gray
    if ($platform.IsLinux -or $platform.IsMacOS) {
        Write-Host "3. Make test scripts executable: chmod +x doctor/*.ps1" -ForegroundColor Gray
        Write-Host "4. Configure Docker access (Linux): sudo usermod -aG docker `$USER" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "🔍 Verification:" -ForegroundColor Blue
    Write-Host "Run: .\Install-PowerShell7.ps1 -VerifyInstallation" -ForegroundColor Green
}

function Test-PowerShellInstallation {
    Write-Host "🔍 Verifying PowerShell 7 Installation..." -ForegroundColor Blue
    Write-Host ""
    
    $results = @{
        PowerShell7Available = $false
        Version = $null
        Edition = $null
        Platform = $null
        DockerAvailable = $false
        DockerComposeAvailable = $false
        ScriptsExecutable = $false
        OverallStatus = "UNKNOWN"
    }
    
    # Check PowerShell version
    try {
        $results.Version = $PSVersionTable.PSVersion
        $results.Edition = $PSVersionTable.PSEdition
        $results.Platform = $PSVersionTable.Platform
        $results.PowerShell7Available = $PSVersionTable.PSVersion.Major -ge 7
        
        if ($results.PowerShell7Available) {
            Write-Host "✓ PowerShell 7 detected" -ForegroundColor Green
            Write-Host "  Version: $($results.Version)" -ForegroundColor Gray
            Write-Host "  Edition: $($results.Edition)" -ForegroundColor Gray
            Write-Host "  Platform: $($results.Platform)" -ForegroundColor Gray
        } else {
            Write-Host "✗ PowerShell 7 not detected" -ForegroundColor Red
            Write-Host "  Current Version: $($results.Version)" -ForegroundColor Yellow
            Write-Host "  Please install PowerShell 7 for full compatibility" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "✗ Unable to determine PowerShell version" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Check Docker availability
    Write-Host "🐳 Checking Docker availability..." -ForegroundColor Blue
    try {
        $null = Invoke-Expression "docker version" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $results.DockerAvailable = $true
            Write-Host "✓ Docker is available" -ForegroundColor Green
        } else {
            Write-Host "✗ Docker is not available or not accessible" -ForegroundColor Red
        }
    } catch {
        Write-Host "✗ Docker is not available" -ForegroundColor Red
    }
    
    # Check Docker Compose
    try {
        $null = Invoke-Expression "docker compose version" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $results.DockerComposeAvailable = $true
            Write-Host "✓ Docker Compose v2 is available" -ForegroundColor Green
        } else {
            $null = Invoke-Expression "docker-compose version" 2>$null
            if ($LASTEXITCODE -eq 0) {
                $results.DockerComposeAvailable = $true
                Write-Host "✓ Docker Compose v1 is available" -ForegroundColor Green
            } else {
                Write-Host "✗ Docker Compose is not available" -ForegroundColor Red
            }
        }
    } catch {
        Write-Host "✗ Docker Compose is not available" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Check script executability (Linux/macOS)
    $platform = Get-CurrentPlatform
    if ($platform.IsLinux -or $platform.IsMacOS) {
        Write-Host "📜 Checking script permissions..." -ForegroundColor Blue
        $testScript = Join-Path $PSScriptRoot "Run-AllTests.ps1"
        if (Test-Path $testScript) {
            try {
                $permissions = Invoke-Expression "ls -la '$testScript'" 2>$null
                if ($permissions -match "x.*Run-AllTests.ps1") {
                    $results.ScriptsExecutable = $true
                    Write-Host "✓ Scripts have executable permissions" -ForegroundColor Green
                } else {
                    Write-Host "⚠ Scripts may not have executable permissions" -ForegroundColor Yellow
                    Write-Host "  Run: chmod +x doctor/*.ps1" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "? Unable to check script permissions" -ForegroundColor Gray
                $results.ScriptsExecutable = $true  # Assume OK if we can't check
            }
        } else {
            Write-Host "⚠ Test scripts not found in expected location" -ForegroundColor Yellow
        }
    } else {
        $results.ScriptsExecutable = $true  # Not applicable on Windows
    }
    
    # Determine overall status
    if ($results.PowerShell7Available -and $results.DockerAvailable -and $results.DockerComposeAvailable -and $results.ScriptsExecutable) {
        $results.OverallStatus = "READY"
        Write-Host ""
        Write-Host "🎉 Environment is ready for Artemis Backend testing!" -ForegroundColor Green
        Write-Host "   You can now run: ./doctor/Run-AllTests.ps1" -ForegroundColor Green
    } elseif ($results.PowerShell7Available -and ($results.DockerAvailable -or $results.DockerComposeAvailable)) {
        $results.OverallStatus = "PARTIAL"
        Write-Host ""
        Write-Host "⚠ Environment is partially ready" -ForegroundColor Yellow
        Write-Host "  Some features may not work correctly" -ForegroundColor Yellow
    } else {
        $results.OverallStatus = "NOT_READY"
        Write-Host ""
        Write-Host "❌ Environment setup incomplete" -ForegroundColor Red
        Write-Host "   Please install missing components" -ForegroundColor Red
    }
    
    return $results
}

function Set-DevelopmentEnvironment {
    Write-Host "⚙️ Configuring Development Environment..." -ForegroundColor Blue
    Write-Host ""
    
    $platform = Get-CurrentPlatform
    
    # Make scripts executable on Linux/macOS
    if ($platform.IsLinux -or $platform.IsMacOS) {
        Write-Host "Setting script permissions..." -ForegroundColor Yellow
        try {
            Invoke-Expression "chmod +x $PSScriptRoot/*.ps1"
            Write-Host "✓ Scripts are now executable" -ForegroundColor Green
        } catch {
            Write-Host "✗ Failed to set script permissions" -ForegroundColor Red
            Write-Host "  Run manually: chmod +x doctor/*.ps1" -ForegroundColor Yellow
        }
        Write-Host ""
    }
    
    # Docker group check (Linux only)
    if ($platform.IsLinux) {
        Write-Host "Checking Docker group membership..." -ForegroundColor Yellow
        try {
            $groups = Invoke-Expression "groups" 2>$null
            if ($groups -match "docker") {
                Write-Host "✓ User is in docker group" -ForegroundColor Green
            } else {
                Write-Host "⚠ User is not in docker group" -ForegroundColor Yellow
                Write-Host "  Run: sudo usermod -aG docker `$USER" -ForegroundColor Yellow
                Write-Host "  Then log out and back in" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "? Unable to check docker group membership" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # Environment variables check
    Write-Host "Checking environment variables..." -ForegroundColor Yellow
    $envVars = @{
        "LOCAL_BACKEND_BOOTSTRAP_PASSWORD" = "changeme"
        "SQLSERVER_SA_PASSWORD" = "@rt3m1sD3v"
        "KIBANA_ENCRYPTION_KEY" = "a7f5d3e8b9c2f1e4d6a8b3c5e7f9d2a4b6c8e1f3d5a7b9c2e4f6a8b1c3d5e7f9"
    }
    
    foreach ($var in $envVars.Keys) {
        $value = [Environment]::GetEnvironmentVariable($var)
        if ($value) {
            Write-Host "✓ $var is set" -ForegroundColor Green
        } else {
            Write-Host "⚠ $var not set (will use default: $($envVars[$var]))" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "✓ Environment configuration completed" -ForegroundColor Green
    Write-Host "  Run verification: .\Install-PowerShell7.ps1 -VerifyInstallation" -ForegroundColor Gray
}

# Main execution
Clear-Host

if (-not $ShowInstructions -and -not $VerifyInstallation -and -not $SetupEnvironment) {
    # Default behavior - show menu
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "         ARTEMIS BACKEND - POWERSHELL 7 SETUP TOOL           " -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Select an option:" -ForegroundColor Blue
    Write-Host "1. Show installation instructions for your platform" -ForegroundColor Yellow
    Write-Host "2. Verify current installation" -ForegroundColor Yellow
    Write-Host "3. Setup development environment" -ForegroundColor Yellow
    Write-Host "4. Exit" -ForegroundColor Yellow
    Write-Host ""
    
    do {
        $choice = Read-Host "Enter choice (1-4)"
        switch ($choice) {
            "1" { Show-InstallationInstructions; break }
            "2" { Test-PowerShellInstallation; break }
            "3" { Set-DevelopmentEnvironment; break }
            "4" { Write-Host "Goodbye!" -ForegroundColor Green; exit }
            default { Write-Host "Invalid choice. Please enter 1-4." -ForegroundColor Red }
        }
    } while ($choice -notin @("1", "2", "3", "4"))
    
} else {
    # Handle parameters
    if ($ShowInstructions) {
        Show-InstallationInstructions
    }
    
    if ($VerifyInstallation) {
        Test-PowerShellInstallation
    }
    
    if ($SetupEnvironment) {
        Set-DevelopmentEnvironment
    }
}

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════" -ForegroundColor Cyan