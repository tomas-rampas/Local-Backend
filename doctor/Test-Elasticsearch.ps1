#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Elasticsearch Service Test Script
    
.DESCRIPTION
    Tests Elasticsearch functionality by creating an index, inserting documents,
    performing searches, and cleaning up. Returns a detailed test report.
    
.PARAMETER ElasticsearchUrl
    Elasticsearch endpoint URL (default: https://localhost:9200)
    
.PARAMETER Username
    Elasticsearch username (default: elastic)
    
.PARAMETER Password
    Elasticsearch password (default: from LOCAL_BACKEND_BOOTSTRAP_PASSWORD or 'changeme')
    
.PARAMETER SkipCleanup
    Skip cleanup of test data after testing
    
.EXAMPLE
    .\Test-Elasticsearch.ps1
    .\Test-Elasticsearch.ps1 -ElasticsearchUrl "https://localhost:9200" -Username "elastic" -Password "mypassword"
    .\Test-Elasticsearch.ps1 -SkipCleanup
#>

param(
    [string]$ElasticsearchUrl = "https://localhost:9200",
    [string]$Username = "elastic", 
    [string]$Password = $null,
    [switch]$SkipCleanup
)

# Set default password if not provided
if (-not $Password) {
    $Password = $env:LOCAL_BACKEND_BOOTSTRAP_PASSWORD
    if (-not $Password) {
        $Password = "changeme"  # Default fallback
    }
}

# Test configuration
$TestIndexName = "artemis-test-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
$TestResults = @{
    ServiceName = "Elasticsearch"
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
        [object]$ResponseData = $null
    )
    
    $result = @{
        TestName = $TestName
        Success = $Success
        Details = $Details
        ErrorMessage = $ErrorMessage
        ResponseData = $ResponseData
        Timestamp = Get-Date
    }
    
    $TestResults.Tests += $result
    
    # Console output
    $status = if ($Success) { "✓" } else { "✗" }
    $color = if ($Success) { "Green" } else { "Red" }
    
    Write-Host "[$status] " -ForegroundColor $color -NoNewline
    Write-Host $TestName -NoNewline
    if ($Details) {
        Write-Host " - $Details" -ForegroundColor Gray
    } else {
        Write-Host ""
    }
    
    if (-not $Success -and $ErrorMessage) {
        Write-Host "    Error: $ErrorMessage" -ForegroundColor Red
    }
}

function Invoke-ElasticsearchRequest {
    param(
        [string]$Method = "GET",
        [string]$Endpoint,
        [object]$Body = $null,
        [hashtable]$Headers = @{}
    )
    
    try {
        # Create basic auth header
        $encodedAuth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$Username`:$Password"))
        $defaultHeaders = @{
            "Authorization" = "Basic $encodedAuth"
            "Content-Type" = "application/json"
        }
        
        # Merge headers
        foreach ($key in $Headers.Keys) {
            $defaultHeaders[$key] = $Headers[$key]
        }
        
        $params = @{
            Uri = "$ElasticsearchUrl$Endpoint"
            Method = $Method
            Headers = $defaultHeaders
            SkipCertificateCheck = $true
            TimeoutSec = 30
        }
        
        if ($Body) {
            if ($Body -is [string]) {
                $params.Body = $Body
            } else {
                $params.Body = $Body | ConvertTo-Json -Depth 10
            }
        }
        
        $response = Invoke-RestMethod @params
        return @{
            Success = $true
            Data = $response
            StatusCode = 200  # RestMethod doesn't return status code on success
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            StatusCode = if ($_.Exception.Response) { $_.Exception.Response.StatusCode } else { "Unknown" }
            ResponseContent = if ($_.Exception.Response) { $_.Exception.Response.Content } else { "" }
        }
    }
}

# Start testing
Clear-Host
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                ELASTICSEARCH SERVICE TEST                  " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "🎯 Target: $ElasticsearchUrl" -ForegroundColor Blue
Write-Host "👤 User: $Username" -ForegroundColor Blue  
Write-Host "📋 Test Index: $TestIndexName" -ForegroundColor Blue
Write-Host ""

# Test 1: Cluster Health
Write-Host "Testing cluster health..." -ForegroundColor Yellow
$healthResponse = Invoke-ElasticsearchRequest -Endpoint "/_cluster/health"
if ($healthResponse.Success) {
    $health = $healthResponse.Data
    $healthStatus = $health.status
    $details = "Status: $healthStatus, Nodes: $($health.number_of_nodes), Active Shards: $($health.active_shards)"
    Write-TestResult "Cluster Health Check" $true $details -ResponseData $health
} else {
    Write-TestResult "Cluster Health Check" $false -ErrorMessage $healthResponse.Error
}

# Test 2: Create Index
Write-Host "Creating test index..." -ForegroundColor Yellow
$indexMapping = @{
    mappings = @{
        properties = @{
            title = @{ type = "text"; analyzer = "standard" }
            description = @{ type = "text" }
            tags = @{ type = "keyword" }
            created_date = @{ type = "date" }
            priority = @{ type = "integer" }
            metadata = @{ 
                type = "object"
                properties = @{
                    author = @{ type = "keyword" }
                    category = @{ type = "keyword" }
                }
            }
        }
    }
    settings = @{
        number_of_shards = 1
        number_of_replicas = 0
    }
}

$createResponse = Invoke-ElasticsearchRequest -Method "PUT" -Endpoint "/$TestIndexName" -Body $indexMapping
if ($createResponse.Success) {
    Write-TestResult "Create Test Index" $true "Index '$TestIndexName' created successfully" -ResponseData $createResponse.Data
} else {
    Write-TestResult "Create Test Index" $false -ErrorMessage $createResponse.Error
}

# Test 3: Insert Documents
Write-Host "Inserting test documents..." -ForegroundColor Yellow
$testDocuments = @(
    @{
        title = "Artemis Backend Test Document 1"
        description = "This is a test document for validating Elasticsearch functionality in the Artemis backend"
        tags = @("test", "artemis", "backend")
        created_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        priority = 1
        metadata = @{
            author = "artemis-test"
            category = "testing"
        }
    },
    @{
        title = "Elasticsearch Performance Test"
        description = "Document to test search and indexing performance"
        tags = @("performance", "elasticsearch", "search")
        created_date = (Get-Date).AddMinutes(-10).ToString("yyyy-MM-ddTHH:mm:ss")
        priority = 2
        metadata = @{
            author = "system-test"
            category = "performance"
        }
    },
    @{
        title = "Data Analytics Test Record"
        description = "Sample document for analytics and aggregation testing"
        tags = @("analytics", "data", "aggregation")
        created_date = (Get-Date).AddHours(-1).ToString("yyyy-MM-ddTHH:mm:ss")
        priority = 3
        metadata = @{
            author = "data-analyst"
            category = "analytics"
        }
    }
)

$insertedDocs = 0
foreach ($i in 0..($testDocuments.Count - 1)) {
    $doc = $testDocuments[$i]
    $docId = "test-doc-$($i + 1)"
    
    $insertResponse = Invoke-ElasticsearchRequest -Method "PUT" -Endpoint "/$TestIndexName/_doc/$docId" -Body $doc
    if ($insertResponse.Success) {
        $insertedDocs++
    }
}

if ($insertedDocs -eq $testDocuments.Count) {
    Write-TestResult "Insert Test Documents" $true "$insertedDocs documents inserted successfully"
} else {
    Write-TestResult "Insert Test Documents" $false -ErrorMessage "Only $insertedDocs out of $($testDocuments.Count) documents inserted"
}

# Wait for indexing
Write-Host "Waiting for documents to be indexed..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

# Test 4: Refresh Index
$refreshResponse = Invoke-ElasticsearchRequest -Method "POST" -Endpoint "/$TestIndexName/_refresh"
if ($refreshResponse.Success) {
    Write-TestResult "Refresh Index" $true "Index refreshed for search availability"
} else {
    Write-TestResult "Refresh Index" $false -ErrorMessage $refreshResponse.Error
}

# Test 5: Search Documents
Write-Host "Searching documents..." -ForegroundColor Yellow
$searchQuery = @{
    query = @{
        match = @{
            description = "test"
        }
    }
    size = 10
}

$searchResponse = Invoke-ElasticsearchRequest -Method "POST" -Endpoint "/$TestIndexName/_search" -Body $searchQuery
if ($searchResponse.Success) {
    $hits = $searchResponse.Data.hits
    $totalHits = $hits.total.value
    Write-TestResult "Search Documents" $true "Found $totalHits documents matching search query" -ResponseData $hits
} else {
    Write-TestResult "Search Documents" $false -ErrorMessage $searchResponse.Error
}

# Test 6: Aggregation Query
Write-Host "Testing aggregations..." -ForegroundColor Yellow
$aggregationQuery = @{
    size = 0
    aggs = @{
        categories = @{
            terms = @{
                field = "metadata.category"
                size = 10
            }
        }
        priority_stats = @{
            stats = @{
                field = "priority"
            }
        }
    }
}

$aggResponse = Invoke-ElasticsearchRequest -Method "POST" -Endpoint "/$TestIndexName/_search" -Body $aggregationQuery
if ($aggResponse.Success) {
    $categories = $aggResponse.Data.aggregations.categories.buckets
    $categoryCount = $categories.Count
    Write-TestResult "Aggregation Query" $true "Aggregated $categoryCount categories successfully" -ResponseData $aggResponse.Data.aggregations
} else {
    Write-TestResult "Aggregation Query" $false -ErrorMessage $aggResponse.Error
}

# Test 7: Update Document
Write-Host "Testing document updates..." -ForegroundColor Yellow
$updateDoc = @{
    doc = @{
        title = "Updated Artemis Backend Test Document 1"
        updated_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
        priority = 5
    }
}

$updateResponse = Invoke-ElasticsearchRequest -Method "POST" -Endpoint "/$TestIndexName/_doc/test-doc-1/_update" -Body $updateDoc
if ($updateResponse.Success) {
    Write-TestResult "Update Document" $true "Document updated successfully" -ResponseData $updateResponse.Data
} else {
    Write-TestResult "Update Document" $false -ErrorMessage $updateResponse.Error
}

# Test 8: Get Document by ID
Write-Host "Testing document retrieval by ID..." -ForegroundColor Yellow
$getResponse = Invoke-ElasticsearchRequest -Endpoint "/$TestIndexName/_doc/test-doc-1"
if ($getResponse.Success) {
    $document = $getResponse.Data
    Write-TestResult "Get Document by ID" $true "Document retrieved successfully (Version: $($document._version))" -ResponseData $document
} else {
    Write-TestResult "Get Document by ID" $false -ErrorMessage $getResponse.Error
}

# Test 9: Count Documents
Write-Host "Counting documents in index..." -ForegroundColor Yellow
$countResponse = Invoke-ElasticsearchRequest -Endpoint "/$TestIndexName/_count"
if ($countResponse.Success) {
    $count = $countResponse.Data.count
    Write-TestResult "Count Documents" $true "$count documents found in index" -ResponseData $countResponse.Data
} else {
    Write-TestResult "Count Documents" $false -ErrorMessage $countResponse.Error
}

# Test 10: Bulk Operations
Write-Host "Testing bulk operations..." -ForegroundColor Yellow
$bulkData = @"
{"index":{"_index":"$TestIndexName","_id":"bulk-doc-1"}}
{"title":"Bulk Document 1","description":"Created via bulk API","tags":["bulk","test"],"created_date":"$(Get-Date -Format yyyy-MM-ddTHH:mm:ss)","priority":4,"metadata":{"author":"bulk-test","category":"bulk"}}
{"index":{"_index":"$TestIndexName","_id":"bulk-doc-2"}}
{"title":"Bulk Document 2","description":"Another bulk document","tags":["bulk","test"],"created_date":"$(Get-Date -Format yyyy-MM-ddTHH:mm:ss)","priority":5,"metadata":{"author":"bulk-test","category":"bulk"}}
"@

$bulkResponse = Invoke-ElasticsearchRequest -Method "POST" -Endpoint "/_bulk" -Body $bulkData -Headers @{"Content-Type" = "application/x-ndjson"}
if ($bulkResponse.Success) {
    $items = $bulkResponse.Data.items
    $successCount = ($items | Where-Object { $_.index.status -eq 201 }).Count
    Write-TestResult "Bulk Operations" $true "$successCount documents created via bulk API" -ResponseData $bulkResponse.Data
} else {
    Write-TestResult "Bulk Operations" $false -ErrorMessage $bulkResponse.Error
}

# Cleanup (unless skipped)
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "Cleaning up test data..." -ForegroundColor Yellow
    
    $deleteResponse = Invoke-ElasticsearchRequest -Method "DELETE" -Endpoint "/$TestIndexName"
    if ($deleteResponse.Success) {
        Write-TestResult "Cleanup Test Index" $true "Test index '$TestIndexName' deleted successfully"
    } else {
        Write-TestResult "Cleanup Test Index" $false -ErrorMessage $deleteResponse.Error
    }
} else {
    Write-Host ""
    Write-Host "⚠️ Skipping cleanup - Test index '$TestIndexName' preserved" -ForegroundColor Yellow
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

# Display summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                        TEST SUMMARY                        " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host ""
Write-Host "Service: " -NoNewline
Write-Host "Elasticsearch" -ForegroundColor Blue

Write-Host "Duration: " -NoNewline
Write-Host "$([math]::Round($TestResults.Duration.TotalSeconds, 1)) seconds" -ForegroundColor Blue

Write-Host "Tests: " -NoNewline
Write-Host "$successfulTests/$totalTests passed " -ForegroundColor $(if ($successfulTests -eq $totalTests) { "Green" } else { "Yellow" }) -NoNewline
Write-Host "($successRate%)" -ForegroundColor $(if ($successRate -eq 100) { "Green" } elseif ($successRate -ge 50) { "Yellow" } else { "Red" })

Write-Host "Status: " -NoNewline
$statusColor = switch ($TestResults.OverallStatus) {
    "SUCCESS" { "Green" }
    "WARNING" { "Yellow" }
    "FAILURE" { "Red" }
    default { "Gray" }
}
Write-Host $TestResults.OverallStatus -ForegroundColor $statusColor

Write-Host ""
Write-Host $TestResults.Summary -ForegroundColor Gray

if ($successfulTests -lt $totalTests) {
    Write-Host ""
    Write-Host "Failed Tests:" -ForegroundColor Red
    $failedTests = $TestResults.Tests | Where-Object { -not $_.Success }
    foreach ($test in $failedTests) {
        Write-Host "  ✗ $($test.TestName): $($test.ErrorMessage)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Return results object for consumption by other scripts
return $TestResults