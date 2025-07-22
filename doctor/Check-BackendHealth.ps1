#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Artemis Local Backend Health Diagnostic Script
    
.DESCRIPTION
    Examines all backend services logs and performs health checks to provide 
    a comprehensive status report of the Artemis Local Backend infrastructure.
    
.PARAMETER LogLines
    Number of log lines to examine from each service (default: 50)
    
.PARAMETER Verbose
    Show detailed log analysis and additional debugging information
    
.EXAMPLE
    .\Check-BackendHealth.ps1
    .\Check-BackendHealth.ps1 -LogLines 100 -Verbose
#>

param(
    [int]$LogLines = 50,
    [switch]$Verbose
)

# Color functions for better output formatting
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    
    $colorMap = @{
        "Green" = [System.ConsoleColor]::Green
        "Red" = [System.ConsoleColor]::Red
        "Yellow" = [System.ConsoleColor]::Yellow
        "Blue" = [System.ConsoleColor]::Blue
        "Cyan" = [System.ConsoleColor]::Cyan
        "Magenta" = [System.ConsoleColor]::Magenta
        "White" = [System.ConsoleColor]::White
        "Gray" = [System.ConsoleColor]::Gray
    }
    
    if ($colorMap.ContainsKey($Color)) {
        Write-Host $Message -ForegroundColor $colorMap[$Color]
    } else {
        Write-Host $Message
    }
}

function Write-StatusBadge {
    param(
        [string]$Status,
        [string]$Message = ""
    )
    
    switch ($Status.ToUpper()) {
        "HEALTHY" { 
            Write-Host "[" -NoNewline
            Write-Host "✓ HEALTHY" -ForegroundColor Green -NoNewline
            Write-Host "]" -NoNewline
            if ($Message) { Write-Host " $Message" } else { Write-Host "" }
        }
        "WARNING" { 
            Write-Host "[" -NoNewline
            Write-Host "⚠ WARNING" -ForegroundColor Yellow -NoNewline
            Write-Host "]" -NoNewline
            if ($Message) { Write-Host " $Message" } else { Write-Host "" }
        }
        "UNHEALTHY" { 
            Write-Host "[" -NoNewline
            Write-Host "✗ UNHEALTHY" -ForegroundColor Red -NoNewline
            Write-Host "]" -NoNewline
            if ($Message) { Write-Host " $Message" } else { Write-Host "" }
        }
        "UNKNOWN" { 
            Write-Host "[" -NoNewline
            Write-Host "? UNKNOWN" -ForegroundColor Gray -NoNewline
            Write-Host "]" -NoNewline
            if ($Message) { Write-Host " $Message" } else { Write-Host "" }
        }
    }
}

function Test-DockerService {
    try {
        $null = docker version 2>$null
        return $true
    } catch {
        return $false
    }
}

function Get-ContainerStatus {
    param([string]$ContainerName)
    
    try {
        $status = docker inspect --format='{{.State.Status}}' $ContainerName 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $status.Trim()
        }
    } catch {
        return "not found"
    }
    return "not found"
}

function Get-ContainerHealth {
    param([string]$ContainerName)
    
    try {
        $health = docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' $ContainerName 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $health.Trim()
        }
    } catch {
        return "unknown"
    }
    return "unknown"
}

function Test-ServiceEndpoint {
    param(
        [string]$Url,
        [pscredential]$Credential = $null,
        [int]$TimeoutSec = 10,
        [switch]$SkipCertificateCheck
    )
    
    try {
        $params = @{
            Uri = $Url
            TimeoutSec = $TimeoutSec
            ErrorAction = 'Stop'
        }
        
        if ($Credential) {
            $params['Credential'] = $Credential
        }
        
        if ($SkipCertificateCheck) {
            $params['SkipCertificateCheck'] = $true
        }
        
        $response = Invoke-WebRequest @params
        return @{
            Success = $true
            StatusCode = $response.StatusCode
            Response = $response.Content
        }
    } catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode } else { "N/A" }
        }
    }
}

function Get-ServiceLogs {
    param(
        [string]$ServiceName,
        [int]$Lines = 50
    )
    
    try {
        $logs = docker-compose logs --tail=$Lines $ServiceName 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $logs
        }
    } catch {
        return "Unable to retrieve logs"
    }
    return "No logs available"
}

function Analyze-ElasticsearchLogs {
    param([string]$Logs)
    
    $issues = @()
    $warnings = @()
    
    # Check for common Elasticsearch issues
    if ($Logs -match "OutOfMemoryError|java.lang.OutOfMemoryError") {
        $issues += "Out of memory errors detected"
    }
    
    if ($Logs -match "ElasticsearchSecurityException") {
        $issues += "Security/authentication errors found"
    }
    
    if ($Logs -match "cluster_block_exception") {
        $issues += "Cluster is blocked (possibly read-only)"
    }
    
    if ($Logs -match "not_master_exception|master_not_discovered_exception") {
        $warnings += "Master node issues detected"
    }
    
    if ($Logs -match "high disk watermark") {
        $warnings += "Disk space warnings present"
    }
    
    return @{
        Issues = $issues
        Warnings = $warnings
        HasStarted = $Logs -match "started|recovered"
    }
}

function Analyze-KibanaLogs {
    param([string]$Logs)
    
    $issues = @()
    $warnings = @()
    
    if ($Logs -match "Unable to connect to Elasticsearch") {
        $issues += "Cannot connect to Elasticsearch"
    }
    
    if ($Logs -match "Service Unavailable") {
        $issues += "Kibana service unavailable"
    }
    
    if ($Logs -match "deprecation") {
        $warnings += "Deprecation warnings found"
    }
    
    return @{
        Issues = $issues
        Warnings = $warnings
        HasStarted = $Logs -match "Server running at|Kibana is now available"
    }
}

function Analyze-MongoLogs {
    param([string]$Logs)
    
    $issues = @()
    $warnings = @()
    
    if ($Logs -match "WiredTiger error|Storage engine error") {
        $issues += "Storage engine errors detected"
    }
    
    if ($Logs -match "connection refused|network error") {
        $issues += "Network connectivity issues"
    }
    
    if ($Logs -match "warning|WARNING") {
        $warnings += "General warnings present in logs"
    }
    
    return @{
        Issues = $issues
        Warnings = $warnings
        HasStarted = $Logs -match "waiting for connections|MongoDB starting"
    }
}

function Analyze-KafkaLogs {
    param([string]$Logs)
    
    $issues = @()
    $warnings = @()
    
    if ($Logs -match "Connection to.*failed|Failed to connect") {
        $issues += "Connection failures detected"
    }
    
    if ($Logs -match "Leader not available") {
        $issues += "Kafka leader election issues"
    }
    
    if ($Logs -match "warn|WARN") {
        $warnings += "Warnings detected in Kafka logs"
    }
    
    return @{
        Issues = $issues
        Warnings = $warnings
        HasStarted = $Logs -match "started.*KafkaServer|Kafka Server started"
    }
}

function Analyze-SqlServerLogs {
    param([string]$Logs)
    
    $issues = @()
    $warnings = @()
    
    if ($Logs -match "Login failed|Authentication failed") {
        $issues += "Authentication issues detected"
    }
    
    if ($Logs -match "Database.*cannot be opened") {
        $issues += "Database access issues"
    }
    
    if ($Logs -match "warning|Warning") {
        $warnings += "Warnings found in SQL Server logs"
    }
    
    return @{
        Issues = $issues
        Warnings = $warnings
        HasStarted = $Logs -match "SQL Server is now ready|Database ready"
    }
}

# Main execution starts here
Clear-Host
Write-ColorOutput "════════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "           ARTEMIS LOCAL BACKEND HEALTH DIAGNOSTIC            " "Cyan"
Write-ColorOutput "════════════════════════════════════════════════════════════" "Cyan"
Write-Host ""

# Check if Docker is available
Write-ColorOutput "→ Checking Docker availability..." "Blue"
if (-not (Test-DockerService)) {
    Write-StatusBadge "UNHEALTHY" "Docker is not available or not running"
    Write-ColorOutput "Please ensure Docker is installed and running." "Red"
    exit 1
} else {
    Write-StatusBadge "HEALTHY" "Docker is available"
}

Write-Host ""

# Define services to check
$services = @(
    @{ Name = "elasticsearch"; Container = "artemis-elasticsearch"; Port = 9200; Protocol = "https"; HasAuth = $true },
    @{ Name = "kibana"; Container = "artemis-kibana"; Port = 5601; Protocol = "http"; HasAuth = $false },
    @{ Name = "mongodb"; Container = "artemis-mongodb"; Port = 27017; Protocol = "tcp"; HasAuth = $false },
    @{ Name = "kafka"; Container = "artemis-kafka"; Port = 9094; Protocol = "tcp"; HasAuth = $false },
    @{ Name = "zookeeper"; Container = "artemis-zookeeper"; Port = 2181; Protocol = "tcp"; HasAuth = $false },
    @{ Name = "sqlserver"; Container = "artemis-sqlserver"; Port = 1433; Protocol = "tcp"; HasAuth = $true }
)

$overallHealth = @()

foreach ($service in $services) {
    Write-ColorOutput "────────────────────────────────────────────────────────────" "Gray"
    Write-ColorOutput "🔍 ANALYZING: $($service.Name.ToUpper())" "Blue"
    Write-ColorOutput "────────────────────────────────────────────────────────────" "Gray"
    
    # Check container status
    $containerStatus = Get-ContainerStatus $service.Container
    $containerHealth = Get-ContainerHealth $service.Container
    
    Write-Host "Container Status: " -NoNewline
    switch ($containerStatus) {
        "running" { Write-ColorOutput "RUNNING" "Green" }
        "exited" { Write-ColorOutput "EXITED" "Red" }
        "created" { Write-ColorOutput "CREATED" "Yellow" }
        "not found" { Write-ColorOutput "NOT FOUND" "Red" }
        default { Write-ColorOutput $containerStatus.ToUpper() "Yellow" }
    }
    
    Write-Host "Health Status: " -NoNewline
    switch ($containerHealth) {
        "healthy" { Write-ColorOutput "HEALTHY" "Green" }
        "unhealthy" { Write-ColorOutput "UNHEALTHY" "Red" }
        "starting" { Write-ColorOutput "STARTING" "Yellow" }
        "no healthcheck" { Write-ColorOutput "NO HEALTHCHECK" "Gray" }
        default { Write-ColorOutput $containerHealth.ToUpper() "Yellow" }
    }
    
    # Analyze logs
    Write-Host ""
    Write-ColorOutput "📋 Log Analysis (last $LogLines lines):" "Blue"
    
    $logs = Get-ServiceLogs $service.Name $LogLines
    $analysis = $null
    
    switch ($service.Name) {
        "elasticsearch" { $analysis = Analyze-ElasticsearchLogs $logs }
        "kibana" { $analysis = Analyze-KibanaLogs $logs }
        "mongodb" { $analysis = Analyze-MongoLogs $logs }
        "kafka" { $analysis = Analyze-KafkaLogs $logs }
        "zookeeper" { $analysis = Analyze-KafkaLogs $logs }  # Similar analysis to Kafka
        "sqlserver" { $analysis = Analyze-SqlServerLogs $logs }
    }
    
    if ($analysis) {
        if ($analysis.HasStarted) {
            Write-ColorOutput "  ✓ Service appears to have started successfully" "Green"
        } else {
            Write-ColorOutput "  ⚠ Service startup not clearly indicated in logs" "Yellow"
        }
        
        if ($analysis.Issues.Count -gt 0) {
            Write-ColorOutput "  🚨 ISSUES FOUND:" "Red"
            foreach ($issue in $analysis.Issues) {
                Write-ColorOutput "    • $issue" "Red"
            }
        }
        
        if ($analysis.Warnings.Count -gt 0) {
            Write-ColorOutput "  ⚠ WARNINGS:" "Yellow"
            foreach ($warning in $analysis.Warnings) {
                Write-ColorOutput "    • $warning" "Yellow"
            }
        }
        
        if ($analysis.Issues.Count -eq 0 -and $analysis.Warnings.Count -eq 0) {
            Write-ColorOutput "  ✓ No significant issues detected in logs" "Green"
        }
    }
    
    # Endpoint testing for HTTP services
    if ($service.Protocol -in @("http", "https")) {
        Write-Host ""
        Write-ColorOutput "🌐 Endpoint Testing:" "Blue"
        
        $url = "$($service.Protocol)://localhost:$($service.Port)"
        if ($service.Name -eq "elasticsearch") {
            $url += "/_cluster/health"
            # Create credentials for Elasticsearch
            $password = $env:LOCAL_BACKEND_BOOTSTRAP_PASSWORD
            if (-not $password) { $password = "changeme" }  # Default password
            $securePassword = ConvertTo-SecureString $password -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential("elastic", $securePassword)
            
            $result = Test-ServiceEndpoint -Url $url -Credential $credential -SkipCertificateCheck -TimeoutSec 5
        } else {
            $result = Test-ServiceEndpoint -Url $url -TimeoutSec 5
        }
        
        if ($result.Success) {
            Write-ColorOutput "  ✓ Endpoint accessible (Status: $($result.StatusCode))" "Green"
            if ($Verbose -and $result.Response) {
                Write-ColorOutput "  Response preview: $($result.Response.Substring(0, [Math]::Min(200, $result.Response.Length)))" "Gray"
            }
        } else {
            Write-ColorOutput "  ✗ Endpoint not accessible: $($result.Error)" "Red"
        }
    }
    
    # Determine overall service health
    $serviceHealth = "UNKNOWN"
    if ($containerStatus -eq "running") {
        if ($containerHealth -eq "healthy" -or $containerHealth -eq "no healthcheck") {
            if ($analysis -and $analysis.Issues.Count -eq 0) {
                $serviceHealth = if ($analysis.Warnings.Count -gt 0) { "WARNING" } else { "HEALTHY" }
            } else {
                $serviceHealth = if ($analysis -and $analysis.Issues.Count -gt 0) { "UNHEALTHY" } else { "WARNING" }
            }
        } else {
            $serviceHealth = "UNHEALTHY"
        }
    } else {
        $serviceHealth = "UNHEALTHY"
    }
    
    Write-Host ""
    Write-Host "Overall Service Status: " -NoNewline
    Write-StatusBadge $serviceHealth
    
    $overallHealth += @{
        Service = $service.Name
        Status = $serviceHealth
        Container = $containerStatus
        Health = $containerHealth
    }
    
    Write-Host ""
    
    # Show verbose logs if requested
    if ($Verbose) {
        Write-ColorOutput "📜 Recent logs:" "Blue"
        Write-ColorOutput $logs "Gray"
        Write-Host ""
    }
}

# Summary
Write-ColorOutput "════════════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "                            SUMMARY                           " "Cyan"  
Write-ColorOutput "════════════════════════════════════════════════════════════" "Cyan"

$healthyCount = ($overallHealth | Where-Object { $_.Status -eq "HEALTHY" }).Count
$warningCount = ($overallHealth | Where-Object { $_.Status -eq "WARNING" }).Count
$unhealthyCount = ($overallHealth | Where-Object { $_.Status -eq "UNHEALTHY" }).Count
$totalServices = $overallHealth.Count

Write-Host ""
foreach ($serviceHealth in $overallHealth) {
    Write-Host "$($serviceHealth.Service.PadRight(15)): " -NoNewline
    Write-StatusBadge $serviceHealth.Status
}

Write-Host ""
Write-ColorOutput "Services Status:" "Blue"
Write-ColorOutput "  ✓ Healthy:   $healthyCount/$totalServices" "Green"
Write-ColorOutput "  ⚠ Warning:   $warningCount/$totalServices" "Yellow"  
Write-ColorOutput "  ✗ Unhealthy: $unhealthyCount/$totalServices" "Red"

Write-Host ""

# Overall system health
if ($unhealthyCount -eq 0 -and $warningCount -eq 0) {
    Write-StatusBadge "HEALTHY" "All systems operational"
    $exitCode = 0
} elseif ($unhealthyCount -eq 0) {
    Write-StatusBadge "WARNING" "Some issues detected but services are running"
    $exitCode = 1
} else {
    Write-StatusBadge "UNHEALTHY" "Critical issues detected"
    $exitCode = 2
}

Write-Host ""
Write-ColorOutput "Diagnostic completed at $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" "Gray"
Write-ColorOutput "════════════════════════════════════════════════════════════" "Cyan"

exit $exitCode