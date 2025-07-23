#!/usr/bin/env pwsh
<#
.SYNOPSIS
    MongoDB Service Test Script
    
.DESCRIPTION
    Tests MongoDB functionality by creating databases, collections, inserting documents,
    performing queries, and testing various MongoDB operations. Returns a detailed test report.
    
.PARAMETER MongoHost
    MongoDB host (default: 127.0.0.1)
    
.PARAMETER MongoPort
    MongoDB port (default: 27017)
    
.PARAMETER Database
    Test database name (default: artemis-test-TIMESTAMP)
    
.PARAMETER SkipCleanup
    Skip cleanup of test data after testing
    
.EXAMPLE
    .\Test-MongoDB.ps1
    .\Test-MongoDB.ps1 -MongoHost "127.0.0.1" -MongoPort 27017
    .\Test-MongoDB.ps1 -SkipCleanup
#>

param(
    [string]$MongoHost = "127.0.0.1",
    [int]$MongoPort = 27017,
    [string]$Database = $null,
    [switch]$SkipCleanup
)

# Set test database name if not provided
if (-not $Database) {
    $Database = "artemis-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
}

# Test configuration
$CollectionName = "test-collection"
$TestResults = @{
    ServiceName = "MongoDB"
    StartTime = Get-Date
    Tests = @()
    OverallStatus = "UNKNOWN"
    Summary = ""
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$Details = "",
        [string]$ErrorMessage = "",
        [object]$ResponseData = $null,
        [datetime]$TestStartTime = (Get-Date),
        [string]$TestCategory = "General"
    )
    
    $endTime = Get-Date
    $duration = $endTime - $TestStartTime
    
    $result = @{
        TestName = $TestName
        Success = $Success
        Details = $Details
        ErrorMessage = $ErrorMessage
        ResponseData = $ResponseData
        StartTime = $TestStartTime
        EndTime = $endTime
        Duration = $duration
        DurationMs = [math]::Round($duration.TotalMilliseconds, 0)
        DurationSeconds = [math]::Round($duration.TotalSeconds, 2)
        Category = $TestCategory
        Timestamp = $endTime  # For backward compatibility
    }
    
    $TestResults.Tests += $result
    
    # Console output with timing
    $status = if ($Success) { "✓" } else { "✗" }
    $color = if ($Success) { "Green" } else { "Red" }
    $durationStr = if ($duration.TotalSeconds -lt 1) {
        "$($result.DurationMs)ms"
    } else {
        "$($result.DurationSeconds)s"
    }
    
    Write-Host "[$status] " -ForegroundColor $color -NoNewline
    Write-Host $TestName -NoNewline
    Write-Host " ($durationStr)" -ForegroundColor Cyan -NoNewline
    if ($Details) {
        Write-Host " - $Details" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
    
    if (-not $Success -and $ErrorMessage) {
        Write-Host "    Error: $ErrorMessage" -ForegroundColor Red
    }
}

function Invoke-MongoCommand {
    param(
        [string]$Command,
        [string]$DatabaseName = $Database
    )
    
    try {
        # For complex commands with JSON, write to a temp file to avoid shell escaping issues
        if ($Command.Length -gt 200 -or $Command.Contains('[') -or $Command.Contains('{')) {
            # Use PowerShell's temp directory which works cross-platform
            $tempDir = [System.IO.Path]::GetTempPath()
            $tempFileName = "mongo_query_$(Get-Random).js"
            $tempFile = Join-Path $tempDir $tempFileName
            
            # Write command to temp file
            $Command | Out-File -FilePath $tempFile -Encoding UTF8 -NoNewline
            
            # Use the correct path for bash command (convert Windows path if needed)
            $bashTempFile = if ($IsWindows -or $env:OS -eq "Windows_NT") {
                # On Windows/WSL, convert to Unix-style path
                $tempFile -replace '\\', '/' -replace '^([A-Za-z]):', '/mnt/$1'
            } else {
                $tempFile
            }
            
            try {
                $result = bash -c "cat '$bashTempFile' | docker-compose exec -T mongodb mongosh --quiet" 2>&1
            } finally {
                if (Test-Path $tempFile) {
                    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            # Simple command - use direct execution
            $mongoCommand = "docker-compose exec -T mongodb mongosh --quiet --eval `"$Command`""
            $result = Invoke-Expression $mongoCommand 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            return @{
                Success = $true
                Output = $result
            }
        } else {
            return @{
                Success = $false
                Error = if ($result) { 
                    if ($result -is [array]) { $result -join "`n" } else { $result.ToString() }
                } else { 
                    "Command failed with exit code $LASTEXITCODE" 
                }
            }
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
        }
    }
}

function Test-MongoConnection {
    try {
        $pingResult = Invoke-MongoCommand -Command "db.adminCommand('ping')" -DatabaseName "admin"
        return $pingResult.Success
    }
    catch {
        return $false
    }
}

# Start testing
Clear-Host
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                     MONGODB SERVICE TEST                   " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "🎯 Target: $MongoHost`:$MongoPort" -ForegroundColor Blue
Write-Host "🗄️ Test Database: $Database" -ForegroundColor Blue  
Write-Host "📁 Test Collection: $CollectionName" -ForegroundColor Blue
Write-Host ""

# Test 1: Connection Test
Write-Host "Testing MongoDB connection..." -ForegroundColor Yellow
$testStart = Get-Date
if (Test-MongoConnection) {
    Write-TestResult "Connection Test" $true "Successfully connected to MongoDB" -TestStartTime $testStart -TestCategory "Connection"
} else {
    Write-TestResult "Connection Test" $false -ErrorMessage "Failed to connect to MongoDB" -TestStartTime $testStart -TestCategory "Connection"
}

# Test 2: Database Creation and Listing
Write-Host "Testing database operations..." -ForegroundColor Yellow
$testStart = Get-Date
$createDbResult = Invoke-MongoCommand -Command "use $Database; db.createCollection('$CollectionName')"
if ($createDbResult.Success) {
    Write-TestResult "Create Database" $true "Database '$Database' created successfully" -TestStartTime $testStart -TestCategory "Database Operations"
} else {
    Write-TestResult "Create Database" $false -ErrorMessage $createDbResult.Error -TestStartTime $testStart -TestCategory "Database Operations"
}

# Test 3: List Databases
Write-Host "Listing databases..." -ForegroundColor Yellow
$testStart = Get-Date
$listDbResult = Invoke-MongoCommand -Command "show dbs" -DatabaseName "admin"
if ($listDbResult.Success) {
    $dbLines = $listDbResult.Output -split "`n" | Where-Object { $_ -match '\w+' }
    $dbCount = if ($dbLines) { $dbLines.Count } else { 0 }
    Write-TestResult "List Databases" $true "Found $dbCount databases" -ResponseData $listDbResult.Output -TestStartTime $testStart -TestCategory "Database Operations"
} else {
    Write-TestResult "List Databases" $false -ErrorMessage $listDbResult.Error -TestStartTime $testStart -TestCategory "Database Operations"
}

# Test 4: Insert Test Documents
Write-Host "Inserting test documents..." -ForegroundColor Yellow
$testStart = Get-Date
$testDocuments = @'
[
  {
    "name": "John Doe",
    "email": "john.doe@artemis.dev",
    "age": 30,
    "department": "Engineering",
    "joined_date": "2023-01-15T00:00:00Z",
    "skills": ["JavaScript", "Python", "Docker"],
    "active": true,
    "salary": 85000,
    "projects": [
      {"name": "Project Alpha", "role": "Lead Developer"},
      {"name": "Project Beta", "role": "Contributor"}
    ]
  },
  {
    "name": "Jane Smith",
    "email": "jane.smith@artemis.dev", 
    "age": 28,
    "department": "DevOps",
    "joined_date": "2023-03-10T00:00:00Z",
    "skills": ["Kubernetes", "AWS", "MongoDB"],
    "active": true,
    "salary": 90000,
    "projects": [
      {"name": "Infrastructure", "role": "Lead DevOps"}
    ]
  },
  {
    "name": "Bob Johnson",
    "email": "bob.johnson@artemis.dev",
    "age": 35,
    "department": "Engineering", 
    "joined_date": "2022-11-20T00:00:00Z",
    "skills": ["Java", "Spring", "Elasticsearch"],
    "active": false,
    "salary": 95000,
    "projects": []
  },
  {
    "name": "Alice Brown",
    "email": "alice.brown@artemis.dev",
    "age": 26,
    "department": "Data Science",
    "joined_date": "2023-06-01T00:00:00Z",
    "skills": ["Python", "Machine Learning", "SQL"],
    "active": true,
    "salary": 80000,
    "projects": [
      {"name": "ML Pipeline", "role": "Data Scientist"}
    ]
  }
]
'@

$insertCommand = "use $Database; db.$CollectionName.insertMany($testDocuments)"
$insertResult = Invoke-MongoCommand -Command $insertCommand
if ($insertResult.Success) {
    Write-TestResult "Insert Documents" $true "Test documents inserted successfully" -ResponseData $insertResult.Output -TestStartTime $testStart -TestCategory "Document Operations"
} else {
    Write-TestResult "Insert Documents" $false -ErrorMessage $insertResult.Error -TestStartTime $testStart -TestCategory "Document Operations"
}

# Test 5: Count Documents
Write-Host "Counting documents..." -ForegroundColor Yellow
$testStart = Get-Date
$countResult = Invoke-MongoCommand -Command "use $Database; db.$CollectionName.countDocuments({})"
if ($countResult.Success) {
    $countMatches = $countResult.Output -split "`n" | Where-Object { $_ -match '^\d+$' }
    $count = if ($countMatches) { $countMatches[0] } else { "0" }
    Write-TestResult "Count Documents" $true "Collection contains $count documents" -ResponseData $count -TestStartTime $testStart -TestCategory "Document Operations"
} else {
    Write-TestResult "Count Documents" $false -ErrorMessage $countResult.Error -TestStartTime $testStart -TestCategory "Document Operations"
}

# Test 6: Find All Documents
Write-Host "Querying all documents..." -ForegroundColor Yellow
$testStart = Get-Date
$findAllResult = Invoke-MongoCommand -Command "use $Database; db.$CollectionName.find().limit(5)"
if ($findAllResult.Success) {
    Write-TestResult "Find All Documents" $true "Successfully retrieved documents" -ResponseData $findAllResult.Output -TestStartTime $testStart -TestCategory "Query Operations"
} else {
    Write-TestResult "Find All Documents" $false -ErrorMessage $findAllResult.Error -TestStartTime $testStart -TestCategory "Query Operations"
}

# Test 7: Query with Conditions
Write-Host "Testing conditional queries..." -ForegroundColor Yellow
$testStart = Get-Date
$queryResult = Invoke-MongoCommand -Command "use $Database; db.$CollectionName.find({department: 'Engineering'})"
if ($queryResult.Success) {
    Write-TestResult "Conditional Query" $true "Engineering department query executed successfully" -ResponseData $queryResult.Output -TestStartTime $testStart -TestCategory "Query Operations"
} else {
    Write-TestResult "Conditional Query" $false -ErrorMessage $queryResult.Error -TestStartTime $testStart -TestCategory "Query Operations"
}

# Test 8: Range Query
Write-Host "Testing range queries..." -ForegroundColor Yellow
$testStart = Get-Date
$rangeQuery = "use $Database; db.$CollectionName.find({age: {`${'$'}gte: 25, `${'$'}lte: 32}})"
$rangeQueryResult = Invoke-MongoCommand -Command $rangeQuery
if ($rangeQueryResult.Success) {
    Write-TestResult "Range Query" $true "Age range query (25-32) executed successfully" -ResponseData $rangeQueryResult.Output -TestStartTime $testStart -TestCategory "Query Operations"
} else {
    Write-TestResult "Range Query" $false -ErrorMessage $rangeQueryResult.Error -TestStartTime $testStart -TestCategory "Query Operations"
}

# Test 9: Array Query
Write-Host "Testing array queries..." -ForegroundColor Yellow
$testStart = Get-Date
$arrayQueryResult = Invoke-MongoCommand -Command "use $Database; db.$CollectionName.find({skills: 'Python'})"
if ($arrayQueryResult.Success) {
    Write-TestResult "Array Query" $true "Skills array query executed successfully" -ResponseData $arrayQueryResult.Output -TestStartTime $testStart -TestCategory "Query Operations"
} else {
    Write-TestResult "Array Query" $false -ErrorMessage $arrayQueryResult.Error -TestStartTime $testStart -TestCategory "Query Operations"
}

# Test 10: Update Operations
Write-Host "Testing document updates..." -ForegroundColor Yellow
$testStart = Get-Date
$updateQuery = "use $Database; db.$CollectionName.updateOne({name: 'John Doe'}, {`${'$'}set: {age: 31, last_updated: '$(Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")'}})"
$updateResult = Invoke-MongoCommand -Command $updateQuery
if ($updateResult.Success) {
    Write-TestResult "Update Document" $true "Document updated successfully" -ResponseData $updateResult.Output -TestStartTime $testStart -TestCategory "Document Operations"
} else {
    Write-TestResult "Update Document" $false -ErrorMessage $updateResult.Error -TestStartTime $testStart -TestCategory "Document Operations"
}

# Test 11: Aggregation Pipeline
Write-Host "Testing aggregation pipeline..." -ForegroundColor Yellow
$testStart = Get-Date
# Build aggregation query with proper escaping
$aggregationQuery = "use $Database; db.$CollectionName.aggregate([" +
    "{" + "`${'$'}group: {" + 
        "_id: `"`${'$'}department`", " +
        "count: { `${'$'}sum: 1 }, " +
        "avgAge: { `${'$'}avg: `"`${'$'}age`" }, " +
        "avgSalary: { `${'$'}avg: `"`${'$'}salary`" }" +
    "}}, " +
    "{" + "`${'$'}sort: { count: -1 }" + "}" +
"])"

$aggregationResult = Invoke-MongoCommand -Command $aggregationQuery
if ($aggregationResult.Success) {
    Write-TestResult "Aggregation Pipeline" $true "Department statistics aggregation completed" -ResponseData $aggregationResult.Output -TestStartTime $testStart -TestCategory "Query Operations"
} else {
    Write-TestResult "Aggregation Pipeline" $false -ErrorMessage $aggregationResult.Error -TestStartTime $testStart -TestCategory "Query Operations"
}

# Test 12: Create Index
Write-Host "Testing index creation..." -ForegroundColor Yellow
$testStart = Get-Date
$createIndexResult = Invoke-MongoCommand -Command "use $Database; db.$CollectionName.createIndex({email: 1})"
if ($createIndexResult.Success) {
    Write-TestResult "Create Index" $true "Email index created successfully" -ResponseData $createIndexResult.Output -TestStartTime $testStart -TestCategory "Index Management"
} else {
    Write-TestResult "Create Index" $false -ErrorMessage $createIndexResult.Error -TestStartTime $testStart -TestCategory "Index Management"
}

# Test 13: List Indexes
Write-Host "Listing collection indexes..." -ForegroundColor Yellow
$testStart = Get-Date
$listIndexResult = Invoke-MongoCommand -Command "use $Database; db.$CollectionName.getIndexes()"
if ($listIndexResult.Success) {
    Write-TestResult "List Indexes" $true "Collection indexes listed successfully" -ResponseData $listIndexResult.Output -TestStartTime $testStart -TestCategory "Index Management"
} else {
    Write-TestResult "List Indexes" $false -ErrorMessage $listIndexResult.Error -TestStartTime $testStart -TestCategory "Index Management"
}

# Test 14: Text Search (create text index first)
Write-Host "Testing text search..." -ForegroundColor Yellow
$testStart = Get-Date
$createTextIndexResult = Invoke-MongoCommand -Command "use $Database; db.$CollectionName.createIndex({name: 'text', skills: 'text'})"
if ($createTextIndexResult.Success) {
    $textSearchQuery = "use $Database; db.$CollectionName.find({`${'$'}text: {`${'$'}search: 'Python'}})"
    $textSearchResult = Invoke-MongoCommand -Command $textSearchQuery
    if ($textSearchResult.Success) {
        Write-TestResult "Text Search" $true "Text search executed successfully" -ResponseData $textSearchResult.Output -TestStartTime $testStart -TestCategory "Query Operations"
    } else {
        Write-TestResult "Text Search" $false -ErrorMessage $textSearchResult.Error -TestStartTime $testStart -TestCategory "Query Operations"
    }
} else {
    Write-TestResult "Text Search" $false -ErrorMessage "Failed to create text index: $($createTextIndexResult.Error)" -TestStartTime $testStart -TestCategory "Query Operations"
}

# Test 15: Database Stats
Write-Host "Getting database statistics..." -ForegroundColor Yellow
$testStart = Get-Date
$dbStatsResult = Invoke-MongoCommand -Command "use $Database; db.stats()"
if ($dbStatsResult.Success) {
    Write-TestResult "Database Statistics" $true "Database statistics retrieved successfully" -ResponseData $dbStatsResult.Output -TestStartTime $testStart -TestCategory "Database Operations"
} else {
    Write-TestResult "Database Statistics" $false -ErrorMessage $dbStatsResult.Error -TestStartTime $testStart -TestCategory "Database Operations"
}

# Cleanup (unless skipped)
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "Cleaning up test data..." -ForegroundColor Yellow
    
    $testStart = Get-Date
    $dropDbResult = Invoke-MongoCommand -Command "use $Database; db.dropDatabase()" -DatabaseName $Database
    if ($dropDbResult.Success) {
        Write-TestResult "Cleanup Test Database" $true "Test database '$Database' dropped successfully" -TestStartTime $testStart -TestCategory "Database Operations"
    } else {
        Write-TestResult "Cleanup Test Database" $false -ErrorMessage $dropDbResult.Error -TestStartTime $testStart -TestCategory "Database Operations"
    }
} else {
    Write-Host ""
    Write-Host "⚠️ Skipping cleanup - Test database '$Database' preserved" -ForegroundColor Yellow
}

# Calculate results
$TestResults.EndTime = Get-Date
$TestResults.Duration = $TestResults.EndTime - $TestResults.StartTime
$successfulTests = ($TestResults.Tests | Where-Object { $_.Success }).Count
$totalTests = $TestResults.Tests.Count
$successRate = [math]::Round(($successfulTests / $totalTests) * 100, 1)

# Determine overall status
if ($successfulTests -eq $totalTests) {
    $TestResults.OverallStatus = "SUCCESS"
    $TestResults.Summary = "All tests passed successfully"
} elseif ($successfulTests -gt ($totalTests * 0.5)) {
    $TestResults.OverallStatus = "WARNING"
    $TestResults.Summary = "Most tests passed, but some issues detected"
} else {
    $TestResults.OverallStatus = "FAILURE"  
    $TestResults.Summary = "Multiple test failures detected"
}

# Enhanced test analysis
$testsByCategory = $TestResults.Tests | Group-Object Category
$avgTestTime = if ($totalTests -gt 0) { [math]::Round(($TestResults.Tests | Measure-Object DurationSeconds -Average).Average, 2) } else { 0 }
$fastestTest = $TestResults.Tests | Sort-Object DurationSeconds | Select-Object -First 1
$slowestTest = $TestResults.Tests | Sort-Object DurationSeconds -Descending | Select-Object -First 1

# Display enhanced summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                  MONGODB SERVICE TEST REPORT               " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host ""
Write-Host "🎯 SERVICE OVERVIEW" -ForegroundColor Yellow
Write-Host "Service: " -NoNewline
Write-Host "MongoDB" -ForegroundColor Blue
Write-Host "Target: " -NoNewline  
Write-Host "$MongoHost`:$MongoPort" -ForegroundColor Blue
Write-Host "Database: " -NoNewline
Write-Host "$Database" -ForegroundColor Blue
Write-Host "Total Duration: " -NoNewline
Write-Host "$([math]::Round($TestResults.Duration.TotalSeconds, 1)) seconds" -ForegroundColor Blue

Write-Host ""
Write-Host "📊 TEST STATISTICS" -ForegroundColor Yellow
Write-Host "Total Tests: " -NoNewline
Write-Host "$totalTests" -ForegroundColor Blue
Write-Host "Successful: " -NoNewline
Write-Host "$successfulTests" -ForegroundColor $(if ($successfulTests -eq $totalTests) { "Green" } else { "Yellow" })
Write-Host "Failed: " -NoNewline
Write-Host "$($totalTests - $successfulTests)" -ForegroundColor $(if ($successfulTests -eq $totalTests) { "Green" } else { "Red" })
Write-Host "Success Rate: " -NoNewline
Write-Host "$successRate%" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })

Write-Host ""
Write-Host "⏱️ TIMING ANALYSIS" -ForegroundColor Yellow
Write-Host "Average Test Time: " -NoNewline
Write-Host "$avgTestTime seconds" -ForegroundColor Blue
if ($fastestTest) {
    Write-Host "Fastest Test: " -NoNewline
    Write-Host "$($fastestTest.TestName) ($($fastestTest.DurationSeconds)s)" -ForegroundColor Green
}
if ($slowestTest) {
    Write-Host "Slowest Test: " -NoNewline
    Write-Host "$($slowestTest.TestName) ($($slowestTest.DurationSeconds)s)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📋 TEST CATEGORIES" -ForegroundColor Yellow
foreach ($category in $testsByCategory) {
    $categoryTests = $category.Group
    $categoryPassed = ($categoryTests | Where-Object { $_.Success }).Count
    $categoryTotal = $categoryTests.Count
    $categoryRate = if ($categoryTotal -gt 0) { [math]::Round(($categoryPassed / $categoryTotal) * 100, 1) } else { 0 }
    $categoryTime = [math]::Round(($categoryTests | Measure-Object DurationSeconds -Sum).Sum, 2)
    
    Write-Host "  $($category.Name): " -NoNewline
    Write-Host "$categoryPassed/$categoryTotal passed ($categoryRate%) - ${categoryTime}s total" -ForegroundColor $(if ($categoryRate -eq 100) { "Green" } elseif ($categoryRate -ge 50) { "Yellow" } else { "Red" })
}

Write-Host ""
Write-Host "🎯 OVERALL STATUS" -ForegroundColor Yellow
$statusColor = switch ($TestResults.OverallStatus) {
    "SUCCESS" { "Green" }
    "WARNING" { "Yellow" }  
    "FAILURE" { "Red" }
    default { "Gray" }
}
Write-Host "Status: " -NoNewline  
Write-Host $TestResults.OverallStatus -ForegroundColor $statusColor
Write-Host "Summary: " -NoNewline
Write-Host $TestResults.Summary -ForegroundColor Gray

if ($successfulTests -lt $totalTests) {
    Write-Host ""
    Write-Host "❌ FAILED TESTS ANALYSIS" -ForegroundColor Red
    $failedTests = $TestResults.Tests | Where-Object { -not $_.Success }
    foreach ($test in $failedTests) {
        Write-Host "  ✗ $($test.TestName) ($($test.DurationSeconds)s)" -ForegroundColor Red
        Write-Host "    Category: $($test.Category)" -ForegroundColor Gray  
        Write-Host "    Error: $($test.ErrorMessage)" -ForegroundColor Red
        Write-Host ""
    }
}

Write-Host ""
Write-Host "🔍 DETAILED TEST BREAKDOWN" -ForegroundColor Yellow
foreach ($test in $TestResults.Tests | Sort-Object StartTime) {
    $statusIcon = if ($test.Success) { "✓" } else { "✗" }
    $statusColor = if ($test.Success) { "Green" } else { "Red" }
    $timeStr = if ($test.DurationSeconds -lt 1) { "$($test.DurationMs)ms" } else { "$($test.DurationSeconds)s" }
    
    Write-Host "  [$statusIcon] " -ForegroundColor $statusColor -NoNewline
    Write-Host "$($test.TestName) " -NoNewline
    Write-Host "($timeStr) " -ForegroundColor Cyan -NoNewline
    Write-Host "[$($test.Category)]" -ForegroundColor Gray
    if ($test.Details) {
        Write-Host "      $($test.Details)" -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Test Database: $Database" -ForegroundColor Gray
if (-not $SkipCleanup) {
    Write-Host "Cleanup: Completed" -ForegroundColor Gray
} else {
    Write-Host "Cleanup: Skipped - Database preserved for inspection" -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Return results object for consumption by other scripts
return $TestResults