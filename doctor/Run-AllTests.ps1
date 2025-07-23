#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Artemis Backend Master Test Runner
    
.DESCRIPTION
    Orchestrates all individual service tests and provides a comprehensive report
    of the entire Artemis Local Backend infrastructure. Runs diagnostic checks
    followed by functional tests for each service.
    
.PARAMETER IncludeServices
    Comma-separated list of services to test (default: all)
    Valid services: elasticsearch, kibana, mongodb, kafka, sqlserver
    
.PARAMETER ExcludeServices  
    Comma-separated list of services to exclude from testing
    
.PARAMETER SkipDiagnostics
    Skip the initial health diagnostic check
    
.PARAMETER SkipCleanup
    Skip cleanup of test data after all tests complete
    
.PARAMETER Parallel
    Run service tests in parallel (experimental)
    
.PARAMETER OutputFormat
    Output format: Console, JSON, HTML (default: Console)
    
.PARAMETER OutputFile
    File path for JSON or HTML output (optional)
    
.PARAMETER Verbose
    Show detailed output from individual test scripts
    
.EXAMPLE
    .\Run-AllTests.ps1
    .\Run-AllTests.ps1 -IncludeServices "elasticsearch,mongodb"
    .\Run-AllTests.ps1 -ExcludeServices "kibana" -SkipCleanup
    .\Run-AllTests.ps1 -OutputFormat JSON -OutputFile "test-results.json"
    .\Run-AllTests.ps1 -Parallel -Verbose
#>

param(
    [string]$IncludeServices = "",
    [string]$ExcludeServices = "",
    [switch]$SkipDiagnostics,
    [switch]$SkipCleanup,
    [switch]$Parallel,
    [ValidateSet("Console", "JSON", "HTML")]
    [string]$OutputFormat = "Console",
    [string]$OutputFile = "",
    [switch]$Verbose
)

# Load cross-platform utilities
try {
    . $PSScriptRoot/Platform-Utilities.ps1
    Write-Verbose "Platform utilities loaded successfully"
} catch {
    Write-Warning "Failed to load platform utilities: $($_.Exception.Message)"
    Write-Warning "Some cross-platform features may not work correctly"
}

# Master test configuration
$AllServices = @("elasticsearch", "kibana", "mongodb", "kafka", "sqlserver")
$TestResults = @{
    TestSuite = "Artemis Backend Full Test Suite"
    StartTime = Get-Date
    EndTime = $null
    Duration = $null
    DiagnosticResults = $null
    ServiceTests = @{}
    OverallStatus = "UNKNOWN"
    Summary = ""
    Statistics = @{
        TotalServices = 0
        TestedServices = 0
        SuccessfulServices = 0
        WarningServices = 0
        FailedServices = 0
        TotalTests = 0
        SuccessfulTests = 0
        SuccessRate = 0
    }
}

# Determine which services to test
$ServicesToTest = $AllServices
if ($IncludeServices) {
    $ServicesToTest = $IncludeServices.Split(',') | ForEach-Object { $_.Trim().ToLower() }
}
if ($ExcludeServices) {
    $excludeList = $ExcludeServices.Split(',') | ForEach-Object { $_.Trim().ToLower() }
    $ServicesToTest = $ServicesToTest | Where-Object { $_ -notin $excludeList }
}

# Validate services
$ServicesToTest = $ServicesToTest | Where-Object { $_ -in $AllServices }
$TestResults.Statistics.TotalServices = $AllServices.Count
$TestResults.Statistics.TestedServices = $ServicesToTest.Count

function Write-Header {
    param([string]$Text, [string]$Color = "Cyan")
    
    $border = "═" * 63
    Write-Host $border -ForegroundColor $Color
    Write-Host $Text.PadLeft(($Text.Length + 63) / 2).PadRight(63) -ForegroundColor $Color
    Write-Host $border -ForegroundColor $Color
}

function Write-Section {
    param([string]$Text, [string]$Color = "Blue")
    
    $border = "─" * 63
    Write-Host ""
    Write-Host $border -ForegroundColor Gray
    Write-Host "🔍 $Text" -ForegroundColor $Color
    Write-Host $border -ForegroundColor Gray
}

function Write-StatusBadge {
    param(
        [string]$Status,
        [string]$Message = ""
    )
    
    switch ($Status.ToUpper()) {
        "SUCCESS" { 
            Write-Host "[" -NoNewline
            Write-Host "✓ SUCCESS" -ForegroundColor Green -NoNewline
            Write-Host "]" -NoNewline
            if ($Message) { Write-Host " $Message" } else { Write-Host "" }
        }
        "WARNING" { 
            Write-Host "[" -NoNewline
            Write-Host "⚠ WARNING" -ForegroundColor Yellow -NoNewline
            Write-Host "]" -NoNewline
            if ($Message) { Write-Host " $Message" } else { Write-Host "" }
        }
        "FAILURE" { 
            Write-Host "[" -NoNewline
            Write-Host "✗ FAILURE" -ForegroundColor Red -NoNewline
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

function Get-TestScriptPath {
    param([string]$Service)
    
    $scriptMap = @{
        "elasticsearch" = "Test-Elasticsearch.ps1"
        "kibana" = "Test-Kibana.ps1"
        "mongodb" = "Test-MongoDB.ps1"
        "kafka" = "Test-Kafka.ps1"
        "sqlserver" = "Test-SqlServer.ps1"
    }
    
    $scriptName = $scriptMap[$Service.ToLower()]
    if ($scriptName) {
        return Join-Path $PSScriptRoot $scriptName
    }
    return $null
}

function Invoke-ServiceTest {
    param(
        [string]$Service,
        [switch]$SkipCleanup,
        [switch]$Verbose
    )
    
    $scriptPath = Get-TestScriptPath $Service
    if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
        return @{
            ServiceName = $Service
            OverallStatus = "FAILURE"
            Summary = "Test script not found"
            Tests = @()
            Duration = [TimeSpan]::Zero
        }
    }
    
    try {
        Write-Host "  Starting $($Service.ToUpper()) tests..." -ForegroundColor Yellow
        
        $params = @{}
        if ($SkipCleanup) { $params['SkipCleanup'] = $true }
        if ($Verbose) { $params['Verbose'] = $true }
        
        $startTime = Get-Date
        $result = & $scriptPath @params
        $endTime = Get-Date
        
        if ($result) {
            $result.Duration = $endTime - $startTime
            return $result
        } else {
            return @{
                ServiceName = $service
                OverallStatus = "FAILURE"
                Summary = "Test script returned no results"
                Tests = @()
                Duration = $endTime - $startTime
            }
        }
    }
    catch {
        return @{
            ServiceName = $service
            OverallStatus = "FAILURE"
            Summary = "Test script execution failed: $($_.Exception.Message)"
            Tests = @()
            Duration = [TimeSpan]::Zero
        }
    }
}

function Write-ServiceSummaryTable {
    param(
        [array]$ServicesToTest,
        [hashtable]$ServiceResults,
        [hashtable]$Statistics
    )
    
    if (-not $ServicesToTest -or $ServicesToTest.Count -eq 0) {
        Write-Host "No services to display" -ForegroundColor Gray
        return
    }
    
    # Calculate column widths
    $maxServiceWidth = ($ServicesToTest | Measure-Object -Maximum Length).Maximum
    $maxServiceWidth = [Math]::Max($maxServiceWidth, 12)
    
    # Table structure
    $headerLine = "┌" + ("─" * ($maxServiceWidth + 2)) + "┬" + ("─" * 12) + "┬" + ("─" * 12) + "┬" + ("─" * 12) + "┬" + ("─" * 16) + "┐"
    $separatorLine = "├" + ("─" * ($maxServiceWidth + 2)) + "┼" + ("─" * 12) + "┼" + ("─" * 12) + "┼" + ("─" * 12) + "┼" + ("─" * 16) + "┤"
    $footerLine = "└" + ("─" * ($maxServiceWidth + 2)) + "┴" + ("─" * 12) + "┴" + ("─" * 12) + "┴" + ("─" * 12) + "┴" + ("─" * 16) + "┘"
    
    Write-Host ""
    Write-Host $headerLine -ForegroundColor Gray
    
    # Calculate total width by creating a sample row and measuring it
    $sampleRow = "│ " + "".PadRight($maxServiceWidth) + " │ " + "".PadRight(10) + " │ " + "".PadRight(10) + " │ " + "".PadRight(10) + " │ " + "".PadRight(14) + " │"
    $totalInnerWidth = $sampleRow.Length - 2  # Subtract the border characters
    $headerText = "SERVICE PERFORMANCE SUMMARY"
    $padding = [Math]::Max(0, ($totalInnerWidth - $headerText.Length) / 2)
    $leftPadding = [Math]::Floor($padding)
    $rightPadding = $totalInnerWidth - $headerText.Length - $leftPadding
    $centeredHeader = "│" + (" " * $leftPadding) + $headerText + (" " * $rightPadding) + "│"
    
    Write-Host $centeredHeader -ForegroundColor White
    Write-Host $separatorLine -ForegroundColor Gray
    Write-Host ("│ " + "Service".PadRight($maxServiceWidth) + " │ " + "Status".PadRight(10) + " │ " + "Tests".PadRight(10) + " │ " + "Duration".PadRight(10) + " │ " + "Success Rate".PadRight(14) + " │") -ForegroundColor Yellow
    Write-Host $separatorLine -ForegroundColor Gray
    
    # Service rows
    foreach ($service in $ServicesToTest) {
        if ($ServiceResults.ContainsKey($service)) {
            $result = $ServiceResults[$service]
            
            # Status with icon
            $statusIcon = switch ($result.OverallStatus) {
                "SUCCESS" { "✓" }
                "WARNING" { "⚠" }
                "FAILURE" { "✗" }
                default { "?" }
            }
            $statusStr = "$statusIcon $($result.OverallStatus)"
            $statusColor = switch ($result.OverallStatus) {
                "SUCCESS" { "Green" }
                "WARNING" { "Yellow" }
                "FAILURE" { "Red" }
                default { "Gray" }
            }
            
            # Tests
            if ($result.Tests) {
                $passed = ($result.Tests | Where-Object { $_.Success }).Count
                $total = $result.Tests.Count
                $testsStr = "$passed/$total"
                $successRate = if ($total -gt 0) { [math]::Round(($passed / $total) * 100, 0) } else { 0 }
                $rateStr = "$successRate%"
            } else {
                $testsStr = "0/0"
                $rateStr = "N/A"
                $successRate = 0
            }
            
            # Duration
            $durationStr = Format-Duration $result.Duration
            
            $rateColor = if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 75) { "Yellow" } else { "Red" }
            
            Write-Host ("│ " + $service.PadRight($maxServiceWidth) + " │ ") -ForegroundColor Gray -NoNewline
            Write-Host $statusStr.PadRight(10) -ForegroundColor $statusColor -NoNewline
            Write-Host " │ " -ForegroundColor Gray -NoNewline
            Write-Host $testsStr.PadRight(10) -ForegroundColor Blue -NoNewline
            Write-Host " │ " -ForegroundColor Gray -NoNewline
            Write-Host $durationStr.PadRight(10) -ForegroundColor Cyan -NoNewline
            Write-Host " │ " -ForegroundColor Gray -NoNewline
            Write-Host $rateStr.PadRight(14) -ForegroundColor $rateColor -NoNewline
            Write-Host " │" -ForegroundColor Gray
        } else {
            Write-Host ("│ " + $service.PadRight($maxServiceWidth) + " │ ") -ForegroundColor Gray -NoNewline
            Write-Host "? UNKNOWN".PadRight(10) -ForegroundColor Gray -NoNewline
            Write-Host " │ " -ForegroundColor Gray -NoNewline
            Write-Host "N/A".PadRight(10) -ForegroundColor Gray -NoNewline
            Write-Host " │ " -ForegroundColor Gray -NoNewline
            Write-Host "N/A".PadRight(10) -ForegroundColor Gray -NoNewline
            Write-Host " │ " -ForegroundColor Gray -NoNewline
            Write-Host "N/A".PadRight(14) -ForegroundColor Gray -NoNewline
            Write-Host " │" -ForegroundColor Gray
        }
    }
    
    # Overall summary row
    Write-Host $separatorLine -ForegroundColor Gray
    
    $overallStatus = if ($Statistics.FailedServices -eq 0 -and $Statistics.WarningServices -eq 0) {
        "✓ SUCCESS"
    } elseif ($Statistics.FailedServices -eq 0) {
        "⚠ WARNING"
    } else {
        "✗ FAILURE"
    }
    
    $overallStatusColor = if ($Statistics.FailedServices -eq 0 -and $Statistics.WarningServices -eq 0) {
        "Green"
    } elseif ($Statistics.FailedServices -eq 0) {
        "Yellow"
    } else {
        "Red"
    }
    
    $overallTestsStr = "$($Statistics.SuccessfulTests)/$($Statistics.TotalTests)"
    $overallRateStr = "$($Statistics.SuccessRate)%"
    $overallRateColor = if ($Statistics.SuccessRate -eq 100) { "Green" } elseif ($Statistics.SuccessRate -ge 75) { "Yellow" } else { "Red" }
    
    Write-Host ("│ " + "OVERALL".PadRight($maxServiceWidth) + " │ ") -ForegroundColor White -NoNewline
    Write-Host $overallStatus.PadRight(10) -ForegroundColor $overallStatusColor -NoNewline
    Write-Host " │ " -ForegroundColor Gray -NoNewline
    Write-Host $overallTestsStr.PadRight(10) -ForegroundColor Blue -NoNewline
    Write-Host " │ " -ForegroundColor Gray -NoNewline
    Write-Host "Multiple".PadRight(10) -ForegroundColor Cyan -NoNewline
    Write-Host " │ " -ForegroundColor Gray -NoNewline
    Write-Host $overallRateStr.PadRight(14) -ForegroundColor $overallRateColor -NoNewline
    Write-Host " │" -ForegroundColor Gray
    
    # Add footer note section that connects properly to the table
    $footerText = "⬆ Scroll up to see detailed test results and performance analysis"
    $footerLeftPadding = 2  # Small left margin
    $footerRightPadding = $totalInnerWidth - $footerText.Length - $footerLeftPadding
    $leftAlignedFooter = "│" + (" " * $footerLeftPadding) + $footerText + (" " * $footerRightPadding) + "│"
    
    # Use the same separator structure as the table
    $footerSeparatorLine = "├" + ("─" * ($maxServiceWidth + 2)) + "┼" + ("─" * 12) + "┼" + ("─" * 12) + "┼" + ("─" * 12) + "┼" + ("─" * 16) + "┤"
    
    Write-Host $footerSeparatorLine -ForegroundColor Gray
    Write-Host $leftAlignedFooter -ForegroundColor Yellow
    Write-Host $footerLine -ForegroundColor Gray
    Write-Host ""
}

function Write-DetailedTestBreakdown {
    param(
        [array]$ServicesToTest,
        [hashtable]$ServiceResults
    )
    
    if (-not $ServicesToTest -or $ServicesToTest.Count -eq 0) {
        return
    }
    
    Write-Host ""
    Write-Host "📊 DETAILED TEST PERFORMANCE BREAKDOWN" -ForegroundColor Yellow
    Write-Host ""
    
    foreach ($service in $ServicesToTest) {
        if (-not $ServiceResults.ContainsKey($service)) {
            continue
        }
        
        $result = $ServiceResults[$service]
        if (-not $result.Tests -or $result.Tests.Count -eq 0) {
            continue
        }
        
        # Service header
        $serviceHeader = "$($service.ToUpper()) SERVICE - INDIVIDUAL TEST RESULTS"
        Write-Host $serviceHeader -ForegroundColor Cyan
        Write-Host ("─" * $serviceHeader.Length) -ForegroundColor Gray
        
        # Sort tests by duration (slowest first) and group by category
        $sortedTests = $result.Tests | Sort-Object DurationSeconds -Descending
        $testsByCategory = $sortedTests | Group-Object Category | Sort-Object Name
        
        foreach ($category in $testsByCategory) {
            $categoryPassed = ($category.Group | Where-Object { $_.Success }).Count
            $categoryTotal = $category.Group.Count
            $categoryAvgTime = [math]::Round(($category.Group | Measure-Object DurationSeconds -Average).Average, 2)
            
            Write-Host "  📂 $($category.Name) " -ForegroundColor Blue -NoNewline
            Write-Host "($categoryPassed/$categoryTotal passed, avg: ${categoryAvgTime}s)" -ForegroundColor Gray
            
            foreach ($test in $category.Group) {
                $statusIcon = if ($test.Success) { "✓" } else { "✗" }
                $statusColor = if ($test.Success) { "Green" } else { "Red" }
                $durationStr = if ($test.DurationSeconds -lt 1) { "$($test.DurationMs)ms" } else { "$($test.DurationSeconds)s" }
                
                Write-Host "    [$statusIcon] " -ForegroundColor $statusColor -NoNewline
                Write-Host "$($test.TestName.PadRight(35)) " -NoNewline
                Write-Host "($durationStr)" -ForegroundColor Cyan -NoNewline
                
                if ($test.Details) {
                    Write-Host " - $($test.Details)" -ForegroundColor Gray
                } else {
                    Write-Host ""
                }
                
                if (-not $test.Success -and $test.ErrorMessage) {
                    Write-Host "        ⚠ Error: $($test.ErrorMessage)" -ForegroundColor Red
                }
            }
            Write-Host ""
        }
        
        # Service summary statistics
        $servicePassed = ($result.Tests | Where-Object { $_.Success }).Count
        $serviceTotal = $result.Tests.Count
        $serviceDuration = Format-Duration $result.Duration
        $slowestTest = $sortedTests | Select-Object -First 1
        $fastestTest = $sortedTests | Sort-Object DurationSeconds | Select-Object -First 1
        
        Write-Host "  📈 Service Statistics:" -ForegroundColor Yellow
        Write-Host "    • Total Tests: $serviceTotal" -ForegroundColor Gray
        Write-Host "    • Passed: $servicePassed" -ForegroundColor Gray
        Write-Host "    • Total Duration: $serviceDuration" -ForegroundColor Gray
        if ($slowestTest) {
            $slowestTime = if ($slowestTest.DurationSeconds -lt 1) { "$($slowestTest.DurationMs)ms" } else { "$($slowestTest.DurationSeconds)s" }
            Write-Host "    • Slowest Test: $($slowestTest.TestName) ($slowestTime)" -ForegroundColor Gray
        }
        if ($fastestTest -and $fastestTest.TestName -ne $slowestTest.TestName) {
            $fastestTime = if ($fastestTest.DurationSeconds -lt 1) { "$($fastestTest.DurationMs)ms" } else { "$($fastestTest.DurationSeconds)s" }
            Write-Host "    • Fastest Test: $($fastestTest.TestName) ($fastestTime)" -ForegroundColor Gray
        }
        Write-Host ""
    }
}

function Format-Duration {
    param([TimeSpan]$Duration)
    
    if ($Duration.TotalSeconds -lt 60) {
        return "$([math]::Round($Duration.TotalSeconds, 1))s"
    } elseif ($Duration.TotalMinutes -lt 60) {
        return "$([math]::Round($Duration.TotalMinutes, 1))m"
    } else {
        return "$([math]::Round($Duration.TotalHours, 1))h"
    }
}

function Export-Results {
    param(
        [hashtable]$Results,
        [string]$Format,
        [string]$FilePath
    )
    
    switch ($Format.ToUpper()) {
        "JSON" {
            $jsonOutput = $Results | ConvertTo-Json -Depth 10
            if ($FilePath) {
                $jsonOutput | Out-File -FilePath $FilePath -Encoding UTF8
                Write-Host "Results exported to: $FilePath" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "JSON Results:" -ForegroundColor Cyan
                Write-Host $jsonOutput
            }
        }
        "HTML" {
            # Create a basic HTML report
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Artemis Backend Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #007acc; color: white; padding: 20px; border-radius: 5px; }
        .summary { background-color: #f0f0f0; padding: 15px; margin: 20px 0; border-radius: 5px; }
        .service { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .success { background-color: #d4edda; border-color: #c3e6cb; }
        .warning { background-color: #fff3cd; border-color: #ffeaa7; }
        .failure { background-color: #f8d7da; border-color: #f5c6cb; }
        .test-list { margin: 10px 0; }
        .test-item { padding: 5px; margin: 2px 0; }
        .test-pass { color: #155724; }
        .test-fail { color: #721c24; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Artemis Backend Test Results</h1>
        <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>
    
    <div class="summary">
        <h2>Summary</h2>
        <p><strong>Overall Status:</strong> $($Results.OverallStatus)</p>
        <p><strong>Duration:</strong> $(Format-Duration $Results.Duration)</p>
        <p><strong>Services Tested:</strong> $($Results.Statistics.TestedServices)/$($Results.Statistics.TotalServices)</p>
        <p><strong>Success Rate:</strong> $($Results.Statistics.SuccessRate)%</p>
    </div>
"@

            foreach ($service in $Results.ServiceTests.Keys) {
                $serviceResult = $Results.ServiceTests[$service]
                $cssClass = switch ($serviceResult.OverallStatus) {
                    "SUCCESS" { "success" }
                    "WARNING" { "warning" }
                    "FAILURE" { "failure" }
                    default { "" }
                }
                
                $html += @"
    <div class="service $cssClass">
        <h3>$($serviceResult.ServiceName)</h3>
        <p><strong>Status:</strong> $($serviceResult.OverallStatus)</p>
        <p><strong>Duration:</strong> $(Format-Duration $serviceResult.Duration)</p>
        <p><strong>Summary:</strong> $($serviceResult.Summary)</p>
"@
                
                if ($serviceResult.Tests -and $serviceResult.Tests.Count -gt 0) {
                    $html += "<div class='test-list'><h4>Test Results:</h4>"
                    foreach ($test in $serviceResult.Tests) {
                        $testClass = if ($test.Success) { "test-pass" } else { "test-fail" }
                        $testIcon = if ($test.Success) { "✓" } else { "✗" }
                        $html += "<div class='test-item $testClass'>$testIcon $($test.TestName)</div>"
                    }
                    $html += "</div>"
                }
                
                $html += "</div>"
            }
            
            $html += @"
</body>
</html>
"@

            if ($FilePath) {
                $html | Out-File -FilePath $FilePath -Encoding UTF8
                Write-Host "HTML report exported to: $FilePath" -ForegroundColor Green
            } else {
                Write-Host ""
                Write-Host "HTML Results saved to temp file for viewing" -ForegroundColor Cyan
                $tempFile = Join-Path $env:TEMP "artemis-test-results.html"
                $html | Out-File -FilePath $tempFile -Encoding UTF8
                Write-Host "Temp file: $tempFile" -ForegroundColor Gray
            }
        }
    }
}

# Start execution
Clear-Host
Write-Header "ARTEMIS BACKEND COMPREHENSIVE TEST SUITE"

# Display platform information
try {
    Write-PlatformBanner
    Write-CrossPlatformWarning
} catch {
    Write-Verbose "Platform utilities not available, continuing without platform detection"
}

Write-Host ""
Write-Host "🎯 Test Configuration:" -ForegroundColor Blue
Write-Host "  Services to test: $($ServicesToTest -join ', ')" -ForegroundColor Gray
Write-Host "  Skip diagnostics: $SkipDiagnostics" -ForegroundColor Gray
Write-Host "  Skip cleanup: $SkipCleanup" -ForegroundColor Gray
Write-Host "  Parallel execution: $Parallel" -ForegroundColor Gray
Write-Host "  Output format: $OutputFormat" -ForegroundColor Gray
if ($OutputFile) {
    Write-Host "  Output file: $OutputFile" -ForegroundColor Gray
}
Write-Host ""

# Check Docker availability with cross-platform support
try {
    $dockerAvailable = Test-DockerAvailability
    $composeInfo = Test-DockerComposeAvailability
    
    Write-Host "🐳 Docker Environment:" -ForegroundColor Blue
    if ($dockerAvailable) {
        Write-Host "  Docker: ✓ Available" -ForegroundColor Green
    } else {
        Write-Host "  Docker: ✗ Not available or not accessible" -ForegroundColor Red
        Write-Host "  Please ensure Docker is running and accessible" -ForegroundColor Yellow
    }
    
    if ($composeInfo.Available) {
        Write-Host "  Docker Compose: ✓ Available ($($composeInfo.Version) - $($composeInfo.Command))" -ForegroundColor Green
    } else {
        Write-Host "  Docker Compose: ✗ Not available" -ForegroundColor Red
    }
    
    if (-not $dockerAvailable -or -not $composeInfo.Available) {
        Write-Host ""
        Write-Host "❌ Docker environment not ready. Please ensure:" -ForegroundColor Red
        Write-Host "   1. Docker is installed and running" -ForegroundColor Yellow
        Write-Host "   2. Docker Compose is installed" -ForegroundColor Yellow
        if ((Get-CurrentPlatform).IsLinux) {
            Write-Host "   3. Current user is in 'docker' group (run: sudo usermod -aG docker `$USER)" -ForegroundColor Yellow
        }
        exit 1
    }
    
    Write-Host ""
} catch {
    Write-Warning "Could not verify Docker availability: $($_.Exception.Message)"
}

# Run initial diagnostics (unless skipped)
if (-not $SkipDiagnostics) {
    Write-Section "RUNNING SYSTEM DIAGNOSTICS"
    
    $diagnosticScript = Join-Path $PSScriptRoot "Check-BackendHealth.ps1"
    if (Test-Path $diagnosticScript) {
        try {
            $params = @{}
            if ($Verbose) { $params['Verbose'] = $true }
            
            Write-Host "Analyzing system health and service status..." -ForegroundColor Yellow
            $diagnosticStart = Get-Date
            
            # Capture diagnostic output but don't display it if not verbose
            if ($Verbose) {
                $diagnosticResults = & $diagnosticScript @params
            } else {
                $diagnosticResults = & $diagnosticScript @params 2>&1 | Out-String
            }
            
            $diagnosticEnd = Get-Date
            $TestResults.DiagnosticResults = @{
                Completed = $true
                Duration = $diagnosticEnd - $diagnosticStart
                Output = $diagnosticResults
            }
            
            Write-Host ""
            Write-Host "✓ System diagnostic completed" -ForegroundColor Green
            Write-Host "  Duration: $(Format-Duration ($diagnosticEnd - $diagnosticStart))" -ForegroundColor Gray
        }
        catch {
            $TestResults.DiagnosticResults = @{
                Completed = $false
                Error = $_.Exception.Message
                Duration = [TimeSpan]::Zero
            }
            Write-Host "✗ System diagnostic failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "⚠ Diagnostic script not found, skipping..." -ForegroundColor Yellow
    }
}

# Run service tests
Write-Section "RUNNING SERVICE TESTS"

if ($Parallel -and $ServicesToTest.Count -gt 1) {
    Write-Host "Running tests in parallel mode..." -ForegroundColor Yellow
    
    $jobs = @()
    foreach ($service in $ServicesToTest) {
        $job = Start-Job -ScriptBlock {
            param($ServiceName, $SkipCleanupFlag, $VerboseFlag, $ScriptRoot)
            
            # Change to the script directory
            Set-Location $ScriptRoot
            
            # Import the test function (this would need to be adapted based on your actual implementation)
            $scriptPath = Join-Path $ScriptRoot "Test-$ServiceName.ps1"
            if (Test-Path $scriptPath) {
                $params = @{}
                if ($SkipCleanupFlag) { $params['SkipCleanup'] = $true }
                if ($VerboseFlag) { $params['Verbose'] = $true }
                
                return & $scriptPath @params
            }
            return $null
        } -ArgumentList $service, $SkipCleanup.IsPresent, $Verbose.IsPresent, $PSScriptRoot
        
        $jobs += @{ Job = $job; Service = $service }
    }
    
    # Wait for all jobs to complete and collect results
    foreach ($jobInfo in $jobs) {
        Write-Host "  Waiting for $($jobInfo.Service) tests to complete..." -ForegroundColor Yellow
        $result = $jobInfo.Job | Wait-Job | Receive-Job
        Remove-Job $jobInfo.Job
        
        if ($result) {
            $TestResults.ServiceTests[$jobInfo.Service] = $result
        }
    }
} else {
    # Sequential execution
    foreach ($service in $ServicesToTest) {
        Write-Host ""
        Write-Host "🔧 Testing $($service.ToUpper()) Service" -ForegroundColor Magenta
        Write-Host "─" * 63 -ForegroundColor Gray
        
        $serviceResult = Invoke-ServiceTest -Service $service -SkipCleanup:$SkipCleanup -Verbose:$Verbose
        $TestResults.ServiceTests[$service] = $serviceResult
        
        # Show brief result
        Write-Host ""
        Write-Host "  $($service.ToUpper()) Result: " -NoNewline
        Write-StatusBadge $serviceResult.OverallStatus $serviceResult.Summary
        Write-Host "  Duration: $(Format-Duration $serviceResult.Duration)" -ForegroundColor Gray
        
        if ($serviceResult.Tests) {
            $passed = ($serviceResult.Tests | Where-Object { $_.Success }).Count
            $total = $serviceResult.Tests.Count
            Write-Host "  Tests: $passed/$total passed" -ForegroundColor Gray
        }
    }
}

# Calculate final statistics
$TestResults.EndTime = Get-Date
$TestResults.Duration = $TestResults.EndTime - $TestResults.StartTime

foreach ($serviceResult in $TestResults.ServiceTests.Values) {
    switch ($serviceResult.OverallStatus) {
        "SUCCESS" { $TestResults.Statistics.SuccessfulServices++ }
        "WARNING" { $TestResults.Statistics.WarningServices++ }
        "FAILURE" { $TestResults.Statistics.FailedServices++ }
    }
    
    if ($serviceResult.Tests) {
        $TestResults.Statistics.TotalTests += $serviceResult.Tests.Count
        $TestResults.Statistics.SuccessfulTests += ($serviceResult.Tests | Where-Object { $_.Success }).Count
    }
}

if ($TestResults.Statistics.TotalTests -gt 0) {
    $TestResults.Statistics.SuccessRate = [math]::Round(($TestResults.Statistics.SuccessfulTests / $TestResults.Statistics.TotalTests) * 100, 1)
}

# Determine overall status
if ($TestResults.Statistics.FailedServices -eq 0 -and $TestResults.Statistics.WarningServices -eq 0) {
    $TestResults.OverallStatus = "SUCCESS"
    $TestResults.Summary = "All services and tests completed successfully"
} elseif ($TestResults.Statistics.FailedServices -eq 0) {
    $TestResults.OverallStatus = "WARNING"
    $TestResults.Summary = "All services operational, but some tests had warnings"
} else {
    $TestResults.OverallStatus = "FAILURE"
    $TestResults.Summary = "One or more services failed testing"
}

# Enhanced cross-service analysis
$allTests = @()
$serviceTimes = @{}
$serviceTestCounts = @{}

foreach ($serviceName in $TestResults.ServiceTests.Keys) {
    $serviceResult = $TestResults.ServiceTests[$serviceName]
    $serviceTimes[$serviceName] = $serviceResult.Duration
    
    if ($serviceResult.Tests) {
        $serviceTestCounts[$serviceName] = @{
            Total = $serviceResult.Tests.Count
            Passed = ($serviceResult.Tests | Where-Object { $_.Success }).Count
            Failed = ($serviceResult.Tests | Where-Object { -not $_.Success }).Count
        }
        $allTests += $serviceResult.Tests
    }
}

# Calculate timing statistics
$avgServiceTime = if ($serviceTimes.Count -gt 0) { 
    [math]::Round(($serviceTimes.Values | ForEach-Object { $_.TotalSeconds } | Measure-Object -Average).Average, 2) 
} else { 0 }
$fastestService = if ($serviceTimes.Count -gt 0) { 
    ($serviceTimes.GetEnumerator() | Sort-Object { $_.Value.TotalSeconds } | Select-Object -First 1)
} else { $null }
$slowestService = if ($serviceTimes.Count -gt 0) { 
    ($serviceTimes.GetEnumerator() | Sort-Object { $_.Value.TotalSeconds } -Descending | Select-Object -First 1)
} else { $null }

# Display enhanced table-based summary
Write-Header "ARTEMIS BACKEND COMPREHENSIVE TEST REPORT"

Write-Host ""
Write-Host "🎯 EXECUTION OVERVIEW" -ForegroundColor Yellow
Write-Host "Test Suite: " -NoNewline
Write-Host "Artemis Backend Full Infrastructure Test" -ForegroundColor Blue
Write-Host "Started: " -NoNewline
Write-Host "$($TestResults.StartTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Blue
Write-Host "Ended: " -NoNewline
Write-Host "$($TestResults.EndTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Blue
Write-Host "Total Duration: " -NoNewline
Write-Host "$(Format-Duration $TestResults.Duration)" -ForegroundColor Blue
Write-Host "Services Tested: " -NoNewline
Write-Host "$($TestResults.Statistics.TestedServices)" -ForegroundColor Blue

Write-Host ""
Write-Host "⏱️ TIMING ANALYSIS" -ForegroundColor Yellow
Write-Host "Average Service Time: " -NoNewline
Write-Host "$avgServiceTime seconds" -ForegroundColor Blue
if ($fastestService) {
    Write-Host "Fastest Service: " -NoNewline
    Write-Host "$($fastestService.Key) ($(Format-Duration $fastestService.Value))" -ForegroundColor Green
}
if ($slowestService) {
    Write-Host "Slowest Service: " -NoNewline
    Write-Host "$($slowestService.Key) ($(Format-Duration $slowestService.Value))" -ForegroundColor Yellow
}

# Clear console to hide individual service test details but keep summary information
Clear-Host

# Display detailed individual test performance breakdown
Write-DetailedTestBreakdown -ServicesToTest $ServicesToTest -ServiceResults $TestResults.ServiceTests

Write-Host "🎯 OVERALL ASSESSMENT" -ForegroundColor Yellow
Write-Host "Status: " -NoNewline
Write-StatusBadge $TestResults.OverallStatus
Write-Host "Summary: " -NoNewline
Write-Host $TestResults.Summary -ForegroundColor Gray

# Enhanced reliability score
$reliabilityScore = 0
if ($TestResults.Statistics.TestedServices -gt 0) {
    $serviceSuccessRate = ($TestResults.Statistics.SuccessfulServices / $TestResults.Statistics.TestedServices) * 100
    $testSuccessRate = $TestResults.Statistics.SuccessRate
    $timelinessScore = if ($TestResults.Duration.TotalMinutes -le 5) { 100 } elseif ($TestResults.Duration.TotalMinutes -le 10) { 80 } else { 60 }
    
    $reliabilityScore = [math]::Round(($serviceSuccessRate * 0.4 + $testSuccessRate * 0.4 + $timelinessScore * 0.2), 1)
}

Write-Host ""
Write-Host "📊 SYSTEM RELIABILITY SCORE: " -NoNewline -ForegroundColor Yellow
$scoreColor = if ($reliabilityScore -ge 90) { "Green" } elseif ($reliabilityScore -ge 70) { "Yellow" } else { "Red" }
Write-Host "$reliabilityScore/100 " -ForegroundColor $scoreColor -NoNewline
$rating = if ($reliabilityScore -ge 95) { "Excellent" } elseif ($reliabilityScore -ge 85) { "Good" } elseif ($reliabilityScore -ge 70) { "Fair" } else { "Needs Attention" }
Write-Host "($rating)" -ForegroundColor $scoreColor

# Show failed tests summary if any
$failedServices = $TestResults.ServiceTests.Values | Where-Object { $_.OverallStatus -eq "FAILURE" }
if ($failedServices) {
    Write-Host ""
    Write-Host "❌ Failed Services Summary:" -ForegroundColor Red
    foreach ($service in $failedServices) {
        Write-Host "  • $($service.ServiceName): $($service.Summary)" -ForegroundColor Red
        if ($service.Tests) {
            $failedTests = $service.Tests | Where-Object { -not $_.Success }
            foreach ($test in $failedTests) {
                Write-Host "    ✗ $($test.TestName)" -ForegroundColor Red
            }
        }
    }
}

Write-Host ""
Write-Host "Generated at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray

# Export results if requested
if ($OutputFormat -ne "Console") {
    Write-Host ""
    Export-Results -Results $TestResults -Format $OutputFormat -FilePath $OutputFile
}

Write-Host ""
Write-Header "TEST SUITE COMPLETED"

# Display final summary table as the last output
Write-ServiceSummaryTable -ServicesToTest $ServicesToTest -ServiceResults $TestResults.ServiceTests -Statistics $TestResults.Statistics

# Set exit code based on results
$exitCode = switch ($TestResults.OverallStatus) {
    "SUCCESS" { 0 }
    "WARNING" { 1 }
    "FAILURE" { 2 }
    default { 3 }
}

exit $exitCode