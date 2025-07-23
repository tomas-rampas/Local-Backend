#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Cross-Platform Utility Functions for Artemis Backend Tests
    
.DESCRIPTION
    Provides platform detection and utility functions to ensure consistent
    behavior across Windows PowerShell 5.x, PowerShell 7 on Windows, and
    PowerShell 7 on Linux/macOS systems.
    
.NOTES
    This script is designed to be dot-sourced by other test scripts:
    . $PSScriptRoot/Platform-Utilities.ps1
#>

# Platform detection functions
function Get-CurrentPlatform {
    <#
    .SYNOPSIS
    Returns the current platform information
    #>
    $platform = @{
        IsWindows = $false
        IsLinux = $false
        IsMacOS = $false
        IsWSL = $false
        PowerShellVersion = $PSVersionTable.PSVersion
        IsWindowsPowerShell = $PSVersionTable.PSEdition -eq 'Desktop'
        IsPowerShellCore = $PSVersionTable.PSEdition -eq 'Core'
        OSDescription = ""
    }
    
    # PowerShell 7+ has built-in platform variables
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        $platform.IsWindows = $IsWindows
        $platform.IsLinux = $IsLinux
        $platform.IsMacOS = $IsMacOS
    } else {
        # Windows PowerShell 5.x (Windows only)
        $platform.IsWindows = $true
    }
    
    # Detect WSL
    if ($platform.IsLinux) {
        try {
            $wslInfo = Get-Content "/proc/version" -ErrorAction SilentlyContinue
            if ($wslInfo -match "microsoft|Microsoft|WSL") {
                $platform.IsWSL = $true
            }
        } catch {
            # Ignore errors
        }
    }
    
    # Get OS description
    if ($platform.IsWindows) {
        $platform.OSDescription = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption
        if (-not $platform.OSDescription) {
            $platform.OSDescription = "Windows (version unknown)"
        }
    } elseif ($platform.IsLinux) {
        try {
            $osRelease = Get-Content "/etc/os-release" -ErrorAction SilentlyContinue | 
                ForEach-Object { if ($_ -match '^PRETTY_NAME="?([^"]*)"?') { $matches[1] } }
            $platform.OSDescription = $osRelease | Select-Object -First 1
            if (-not $platform.OSDescription) {
                $platform.OSDescription = "Linux (distribution unknown)"
            }
        } catch {
            $platform.OSDescription = "Linux"
        }
    } elseif ($platform.IsMacOS) {
        $platform.OSDescription = "macOS"
    }
    
    return $platform
}

function Write-PlatformBanner {
    <#
    .SYNOPSIS
    Displays platform information banner
    #>
    $platform = Get-CurrentPlatform
    
    Write-Host ""
    Write-Host "🔧 Platform Information:" -ForegroundColor Blue
    Write-Host "  OS: $($platform.OSDescription)" -ForegroundColor Gray
    Write-Host "  PowerShell: $($platform.PowerShellVersion) ($($platform.PSVersionTable.PSEdition))" -ForegroundColor Gray
    
    if ($platform.IsWSL) {
        Write-Host "  Environment: Windows Subsystem for Linux (WSL)" -ForegroundColor Gray
    }
    
    Write-Host ""
}

function Get-DockerCommand {
    <#
    .SYNOPSIS
    Returns the appropriate docker command for the current platform
    #>
    param(
        [string]$Command,
        [string[]]$Arguments = @()
    )
    
    $platform = Get-CurrentPlatform
    
    # Docker commands are the same across platforms
    # But we might need to handle permissions differently on Linux
    $dockerCmd = "docker"
    if ($Command) {
        $dockerCmd += " $Command"
    }
    if ($Arguments) {
        $dockerCmd += " " + ($Arguments -join " ")
    }
    
    return $dockerCmd
}

function Get-DockerComposeCommand {
    <#
    .SYNOPSIS
    Returns the appropriate docker-compose command for the current platform
    #>
    param(
        [string]$Command,
        [string[]]$Arguments = @()
    )
    
    # Try docker compose (v2) first, fall back to docker-compose (v1)
    $composeCmd = "docker-compose"
    
    try {
        $null = Invoke-Expression "docker compose version" 2>$null
        if ($LASTEXITCODE -eq 0) {
            $composeCmd = "docker compose"
        }
    } catch {
        # Fall back to docker-compose
    }
    
    if ($Command) {
        $composeCmd += " $Command"
    }
    if ($Arguments) {
        $composeCmd += " " + ($Arguments -join " ")
    }
    
    return $composeCmd
}

function Test-DockerAvailability {
    <#
    .SYNOPSIS
    Tests if Docker is available and accessible
    #>
    try {
        $result = Invoke-Expression "docker version" 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Test-DockerComposeAvailability {
    <#
    .SYNOPSIS
    Tests if Docker Compose is available and accessible
    #>
    try {
        # Try docker compose (v2) first
        $result = Invoke-Expression "docker compose version" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return @{ Available = $true; Version = "v2"; Command = "docker compose" }
        }
        
        # Try docker-compose (v1)
        $result = Invoke-Expression "docker-compose version" 2>$null
        if ($LASTEXITCODE -eq 0) {
            return @{ Available = $true; Version = "v1"; Command = "docker-compose" }
        }
        
        return @{ Available = $false; Version = $null; Command = $null }
    } catch {
        return @{ Available = $false; Version = $null; Command = $null }
    }
}

function Invoke-CrossPlatformCommand {
    <#
    .SYNOPSIS
    Executes a command with cross-platform compatibility
    #>
    param(
        [string]$Command,
        [string[]]$Arguments = @(),
        [int]$TimeoutSeconds = 30,
        [switch]$IgnoreExitCode
    )
    
    try {
        $platform = Get-CurrentPlatform
        
        # Build full command
        $fullCommand = $Command
        if ($Arguments) {
            $fullCommand += " " + ($Arguments -join " ")
        }
        
        Write-Verbose "Executing: $fullCommand"
        
        # Execute command
        if ($platform.IsWindows -and $platform.IsWindowsPowerShell) {
            # Windows PowerShell 5.x
            $result = Invoke-Expression $fullCommand 2>&1
        } else {
            # PowerShell 7 (any platform)
            $result = Invoke-Expression $fullCommand 2>&1
        }
        
        $success = $IgnoreExitCode -or ($LASTEXITCODE -eq 0)
        
        return @{
            Success = $success
            Output = $result
            ExitCode = $LASTEXITCODE
        }
    } catch {
        return @{
            Success = $false
            Output = $null
            ExitCode = -1
            Error = $_.Exception.Message
        }
    }
}

function Get-EnvironmentVariable {
    <#
    .SYNOPSIS
    Gets environment variable with cross-platform compatibility
    #>
    param(
        [string]$Name,
        [string]$DefaultValue = ""
    )
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not $value) {
        # Try alternative method for getting environment variable
        try {
            $value = Get-ChildItem env: | Where-Object { $_.Name -eq $Name } | Select-Object -ExpandProperty Value -First 1
        } catch {
            # Ignore errors
        }
    }
    
    if (-not $value) {
        return $DefaultValue
    }
    
    return $value
}

function Write-CrossPlatformWarning {
    <#
    .SYNOPSIS
    Displays warnings specific to the current platform
    #>
    $platform = Get-CurrentPlatform
    
    if ($platform.IsLinux) {
        # Check if user is in docker group
        try {
            $groups = Invoke-Expression "groups" 2>$null
            if ($groups -notmatch "docker") {
                Write-Host "⚠️  Warning: Current user may not be in 'docker' group." -ForegroundColor Yellow
                Write-Host "   If Docker commands fail, run: sudo usermod -aG docker `$USER" -ForegroundColor Yellow
                Write-Host "   Then log out and back in." -ForegroundColor Yellow
            }
        } catch {
            # Ignore errors
        }
    }
    
    if ($platform.IsWindowsPowerShell) {
        Write-Host "ℹ️  Note: Running on Windows PowerShell 5.x." -ForegroundColor Cyan
        Write-Host "   Consider upgrading to PowerShell 7 for better cross-platform compatibility." -ForegroundColor Cyan
    }
}

function Get-DefaultServiceCredentials {
    <#
    .SYNOPSIS
    Gets default service credentials with environment variable fallbacks
    #>
    param()
    
    return @{
        ElasticsearchPassword = Get-EnvironmentVariable "LOCAL_BACKEND_BOOTSTRAP_PASSWORD" "changeme"
        SqlServerPassword = Get-EnvironmentVariable "SQLSERVER_SA_PASSWORD" "@rt3m1sD3v"
        KibanaEncryptionKey = Get-EnvironmentVariable "KIBANA_ENCRYPTION_KEY" "a7f5d3e8b9c2f1e4d6a8b3c5e7f9d2a4b6c8e1f3d5a7b9c2e4f6a8b1c3d5e7f9"
    }
}

function Test-RequiredTools {
    <#
    .SYNOPSIS
    Tests if all required tools are available
    #>
    $results = @{
        Docker = Test-DockerAvailability
        DockerCompose = Test-DockerComposeAvailability
        PowerShell = $true  # Obviously available if we're running
        Platform = Get-CurrentPlatform
    }
    
    return $results
}

# Export functions (not necessary in PowerShell, but good for clarity)
Export-ModuleMember -Function @(
    'Get-CurrentPlatform',
    'Write-PlatformBanner', 
    'Get-DockerCommand',
    'Get-DockerComposeCommand',
    'Test-DockerAvailability',
    'Test-DockerComposeAvailability',
    'Invoke-CrossPlatformCommand',
    'Get-EnvironmentVariable',
    'Write-CrossPlatformWarning',
    'Get-DefaultServiceCredentials',
    'Test-RequiredTools'
)

# Display platform information when script is dot-sourced
if ($MyInvocation.InvocationName -eq '.') {
    Write-Verbose "Platform utilities loaded"
}