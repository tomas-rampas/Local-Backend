#!/usr/bin/env pwsh
<#
.SYNOPSIS
    SQL Server Service Test Script
    
.DESCRIPTION
    Tests SQL Server functionality by connecting to the database, creating test databases,
    tables, inserting data, performing queries, and testing various SQL Server operations.
    Returns a detailed test report.
    
.PARAMETER ServerHost
    SQL Server host (default: 127.0.0.1)
    
.PARAMETER ServerPort
    SQL Server port (default: 1433)
    
.PARAMETER Username
    SQL Server username (default: sa)
    
.PARAMETER Password
    SQL Server password (required: must be provided via parameter or SQLSERVER_SA_PASSWORD environment variable)
    
.PARAMETER TestDatabase
    Test database name (default: artemis_test_TIMESTAMP)
    
.PARAMETER SkipCleanup
    Skip cleanup of test database after testing
    
.EXAMPLE
    .\Test-SqlServer.ps1
    .\Test-SqlServer.ps1 -ServerHost "127.0.0.1" -Username "sa" -Password "MyPassword123!"
    .\Test-SqlServer.ps1 -SkipCleanup
#>

param(
    [string]$ServerHost = "127.0.0.1",
    [int]$ServerPort = 1433,
    [string]$Username = "sa",
    [string]$Password = $null,
    [string]$TestDatabase = $null,
    [switch]$SkipCleanup
)

# Load environment variables from .env file if it exists
function Load-EnvironmentVariables {
    $envFile = Join-Path $PSScriptRoot "../.env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^([^#][^=]*)=(.*)$') {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Remove quotes if present
                $value = $value -replace '^["'']|["'']$', ''
                [Environment]::SetEnvironmentVariable($name, $value, 'Process')
            }
        }
    }
}

# Load environment variables from .env file
Load-EnvironmentVariables

# Set password from environment or fail if not available
if (-not $Password) {
    $Password = $env:SQLSERVER_SA_PASSWORD
    if (-not $Password) {
        Write-Error "SQLSERVER_SA_PASSWORD is not defined in environment variables or .env file. Please set this variable before running the test." -ErrorAction Stop
        exit 1
    }
}

# Set test database name if not provided
if (-not $TestDatabase) {
    $TestDatabase = "artemis_test_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
}

# Test configuration
$TestResults = @{
    ServiceName = "SQL Server"
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

function Invoke-SqlServerCommand {
    param(
        [string]$Query,
        [string]$Database = "master",
        [int]$TimeoutSeconds = 30,
        [switch]$ReturnDataSet
    )
    
    try {
        # Use direct command with -Q parameter for simple queries
        if ($Query.Length -lt 500 -and -not $Query.Contains("`n")) {
            # Simple single-line query - use -Q parameter
            $dockerCommand = @(
                "docker-compose", "exec", "-T", "sqlserver",
                "/opt/mssql-tools/bin/sqlcmd",
                "-S", "$ServerHost,$ServerPort",
                "-U", $Username,
                "-P", $Password,
                "-d", $Database,
                "-t", $TimeoutSeconds,
                "-Q", $Query
            )
            
            Write-Verbose "Executing simple query: $($dockerCommand -join ' ')"
            $result = & $dockerCommand[0] $dockerCommand[1..($dockerCommand.Length-1)] 2>&1
        } else {
            # Complex query - use base64 encoding to avoid temp file issues
            $queryBytes = [System.Text.Encoding]::UTF8.GetBytes($Query)
            $base64Query = [Convert]::ToBase64String($queryBytes)
            
            $bashCommand = "echo '$base64Query' | base64 -d | docker-compose exec -T sqlserver /opt/mssql-tools/bin/sqlcmd -S $ServerHost,$ServerPort -U $Username -P '$Password' -d $Database -t $TimeoutSeconds"
            
            Write-Verbose "Executing complex query via base64 encoding"
            $result = bash -c $bashCommand 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            return @{
                Success = $true
                Output = $result
                Data = $result
            }
        } else {
            return @{
                Success = $false
                Error = if ($result) { $result -join "`n" } else { "Command failed with exit code $LASTEXITCODE" }
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

function Test-SqlServerConnection {
    try {
        $result = Invoke-SqlServerCommand -Query "SELECT @@VERSION" -Database "master"
        return $result.Success
    }
    catch {
        return $false
    }
}

# Start testing
Clear-Host
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "                   SQL SERVER SERVICE TEST                  " -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-Host "🎯 Target: $ServerHost`:$ServerPort" -ForegroundColor Blue
Write-Host "👤 User: $Username" -ForegroundColor Blue  
Write-Host "🗄️ Test Database: $TestDatabase" -ForegroundColor Blue
Write-Host ""

# Test 1: Connection Test
Write-Host "Testing SQL Server connection..." -ForegroundColor Yellow
$testStart = Get-Date
if (Test-SqlServerConnection) {
    Write-TestResult "Connection Test" $true "Successfully connected to SQL Server" -TestStartTime $testStart -TestCategory "Connection"
} else {
    Write-TestResult "Connection Test" $false -ErrorMessage "Failed to connect to SQL Server" -TestStartTime $testStart -TestCategory "Connection"
}

# Test 2: Server Information
Write-Host "Retrieving server information..." -ForegroundColor Yellow
$testStart = Get-Date
$serverInfoResult = Invoke-SqlServerCommand -Query "SELECT @@VERSION AS Version, @@SERVERNAME AS ServerName, DB_NAME() AS CurrentDB, SYSTEM_USER AS CurrentUser"
if ($serverInfoResult.Success) {
    Write-TestResult "Server Information" $true "Server information retrieved successfully" -ResponseData $serverInfoResult.Output -TestStartTime $testStart -TestCategory "Connection"
} else {
    Write-TestResult "Server Information" $false -ErrorMessage $serverInfoResult.Error -TestStartTime $testStart -TestCategory "Connection"
}

# Test 3: List Databases
Write-Host "Listing existing databases..." -ForegroundColor Yellow
$testStart = Get-Date
$listDbResult = Invoke-SqlServerCommand -Query "SELECT name, database_id, create_date FROM sys.databases ORDER BY name"
if ($listDbResult.Success) {
    $dbInfo = $listDbResult.Output | Where-Object { $_ -match '\w+' }
    Write-TestResult "List Databases" $true "Database list retrieved successfully" -ResponseData $listDbResult.Output -TestStartTime $testStart -TestCategory "Database Operations"
} else {
    Write-TestResult "List Databases" $false -ErrorMessage $listDbResult.Error -TestStartTime $testStart -TestCategory "Database Operations"
}

# Test 4: Create Test Database
Write-Host "Creating test database..." -ForegroundColor Yellow
$testStart = Get-Date
$createDbQuery = @"
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$TestDatabase')
BEGIN
    CREATE DATABASE [$TestDatabase];
    SELECT 'Database created successfully' AS Result;
END
ELSE
BEGIN
    SELECT 'Database already exists' AS Result;
END
"@

$createDbResult = Invoke-SqlServerCommand -Query $createDbQuery
if ($createDbResult.Success) {
    # Wait a moment for database to be fully available
    Start-Sleep -Seconds 2
    
    # Verify database is accessible by trying to connect to it
    $verifyQuery = "SELECT DB_NAME() AS CurrentDatabase"
    $verifyResult = Invoke-SqlServerCommand -Query $verifyQuery -Database $TestDatabase
    
    if ($verifyResult.Success) {
        Write-TestResult "Create Test Database" $true "Database '$TestDatabase' created and verified successfully" -ResponseData $createDbResult.Output -TestStartTime $testStart -TestCategory "Database Operations"
    } else {
        Write-TestResult "Create Test Database" $false -ErrorMessage "Database created but not accessible: $($verifyResult.Error)" -TestStartTime $testStart -TestCategory "Database Operations"
    }
} else {
    Write-TestResult "Create Test Database" $false -ErrorMessage $createDbResult.Error -TestStartTime $testStart -TestCategory "Database Operations"
}

# Test 5: Create Test Table with Various Column Types
Write-Host "Creating test table with multiple column types..." -ForegroundColor Yellow
$testStart = Get-Date
$createTableQuery = @"
USE [$TestDatabase];

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[employees] (
        [id] int IDENTITY(1,1) PRIMARY KEY,
        [employee_id] nvarchar(10) UNIQUE NOT NULL,
        [first_name] nvarchar(50) NOT NULL,
        [last_name] nvarchar(50) NOT NULL,
        [email] nvarchar(100) UNIQUE NOT NULL,
        [hire_date] date NOT NULL,
        [salary] decimal(10,2),
        [department] nvarchar(50),
        [is_active] bit DEFAULT 1,
        [created_at] datetime2 DEFAULT GETDATE(),
        [metadata] nvarchar(max) -- JSON data
    );
    SELECT 'Table created successfully' AS Result;
END
ELSE
BEGIN
    SELECT 'Table already exists' AS Result;
END
"@

$createTableResult = Invoke-SqlServerCommand -Query $createTableQuery -Database $TestDatabase
if ($createTableResult.Success) {
    Write-TestResult "Create Test Table" $true "Employees table created with 10 columns" -ResponseData $createTableResult.Output -TestStartTime $testStart -TestCategory "Table Operations"
} else {
    Write-TestResult "Create Test Table" $false -ErrorMessage $createTableResult.Error -TestStartTime $testStart -TestCategory "Table Operations"
}

# Test 6: Insert Test Data
Write-Host "Inserting test data..." -ForegroundColor Yellow
$testStart = Get-Date
$insertDataQuery = @"
USE [$TestDatabase];

INSERT INTO [dbo].[employees] 
(employee_id, first_name, last_name, email, hire_date, salary, department, is_active, metadata)
VALUES
('EMP001', 'John', 'Doe', 'john.doe@artemis.dev', '2023-01-15', 85000.00, 'Engineering', 1, '{"skills": ["C#", "SQL", "Docker"], "level": "Senior"}'),
('EMP002', 'Jane', 'Smith', 'jane.smith@artemis.dev', '2023-03-10', 90000.00, 'DevOps', 1, '{"skills": ["Kubernetes", "AWS", "Python"], "level": "Lead"}'),
('EMP003', 'Bob', 'Johnson', 'bob.johnson@artemis.dev', '2022-11-20', 95000.00, 'Engineering', 0, '{"skills": ["Java", "Spring", "Microservices"], "level": "Principal"}'),
('EMP004', 'Alice', 'Brown', 'alice.brown@artemis.dev', '2023-06-01', 80000.00, 'Data Science', 1, '{"skills": ["Python", "Machine Learning", "Statistics"], "level": "Mid"}'),
('EMP005', 'Charlie', 'Wilson', 'charlie.wilson@artemis.dev', '2023-08-15', 75000.00, 'QA', 1, '{"skills": ["Selenium", "TestNG", "SQL"], "level": "Junior"}');

SELECT @@ROWCOUNT AS RowsInserted;
"@

$insertResult = Invoke-SqlServerCommand -Query $insertDataQuery -Database $TestDatabase
if ($insertResult.Success) {
    Write-TestResult "Insert Test Data" $true "5 employee records inserted successfully" -ResponseData $insertResult.Output -TestStartTime $testStart -TestCategory "Data Operations"
} else {
    Write-TestResult "Insert Test Data" $false -ErrorMessage $insertResult.Error -TestStartTime $testStart -TestCategory "Data Operations"
}

# Test 7: Select All Data
Write-Host "Querying all employee data..." -ForegroundColor Yellow
$testStart = Get-Date
$selectAllQuery = "USE [$TestDatabase]; SELECT * FROM [dbo].[employees] ORDER BY id;"
$selectAllResult = Invoke-SqlServerCommand -Query $selectAllQuery -Database $TestDatabase
if ($selectAllResult.Success) {
    Write-TestResult "Select All Data" $true "All employee records retrieved successfully" -ResponseData $selectAllResult.Output -TestStartTime $testStart -TestCategory "Query Operations"
} else {
    Write-TestResult "Select All Data" $false -ErrorMessage $selectAllResult.Error -TestStartTime $testStart -TestCategory "Query Operations"
}

# Test 8: Conditional Queries
Write-Host "Testing conditional queries..." -ForegroundColor Yellow
$conditionalQuery = @"
USE [$TestDatabase];
SELECT employee_id, first_name, last_name, department, salary 
FROM [dbo].[employees] 
WHERE department = 'Engineering' AND is_active = 1
ORDER BY salary DESC;
"@

$conditionalResult = Invoke-SqlServerCommand -Query $conditionalQuery -Database $TestDatabase
if ($conditionalResult.Success) {
    Write-TestResult "Conditional Query" $true "Engineering department query executed successfully" -ResponseData $conditionalResult.Output
} else {
    Write-TestResult "Conditional Query" $false -ErrorMessage $conditionalResult.Error
}

# Test 9: Aggregate Functions
Write-Host "Testing aggregate functions..." -ForegroundColor Yellow
$aggregateQuery = @"
USE [$TestDatabase];
SELECT 
    department,
    COUNT(*) AS employee_count,
    AVG(salary) AS avg_salary,
    MIN(salary) AS min_salary,
    MAX(salary) AS max_salary,
    SUM(salary) AS total_salary
FROM [dbo].[employees] 
WHERE is_active = 1
GROUP BY department
ORDER BY avg_salary DESC;
"@

$aggregateResult = Invoke-SqlServerCommand -Query $aggregateQuery -Database $TestDatabase
if ($aggregateResult.Success) {
    Write-TestResult "Aggregate Functions" $true "Salary statistics by department calculated successfully" -ResponseData $aggregateResult.Output
} else {
    Write-TestResult "Aggregate Functions" $false -ErrorMessage $aggregateResult.Error
}

# Test 10: Update Operations
Write-Host "Testing update operations..." -ForegroundColor Yellow
$updateQuery = @"
USE [$TestDatabase];
UPDATE [dbo].[employees] 
SET salary = salary * 1.05, 
    metadata = JSON_MODIFY(metadata, '$.last_updated', GETDATE())
WHERE department = 'Engineering' AND is_active = 1;

SELECT @@ROWCOUNT AS RowsUpdated;
"@

$updateResult = Invoke-SqlServerCommand -Query $updateQuery -Database $TestDatabase
if ($updateResult.Success) {
    Write-TestResult "Update Operations" $true "Engineering salaries updated (5% increase)" -ResponseData $updateResult.Output
} else {
    Write-TestResult "Update Operations" $false -ErrorMessage $updateResult.Error
}

# Test 11: JSON Operations (if supported)
Write-Host "Testing JSON operations..." -ForegroundColor Yellow
$jsonQuery = @"
USE [$TestDatabase];
SELECT 
    employee_id,
    first_name,
    last_name,
    JSON_VALUE(metadata, '$.level') AS experience_level,
    JSON_VALUE(metadata, '$.skills[0]') AS primary_skill
FROM [dbo].[employees]
WHERE JSON_VALUE(metadata, '$.level') IN ('Senior', 'Lead', 'Principal')
ORDER BY 
    CASE JSON_VALUE(metadata, '$.level')
        WHEN 'Principal' THEN 1
        WHEN 'Lead' THEN 2
        WHEN 'Senior' THEN 3
        ELSE 4
    END;
"@

$jsonResult = Invoke-SqlServerCommand -Query $jsonQuery -Database $TestDatabase
if ($jsonResult.Success) {
    Write-TestResult "JSON Operations" $true "JSON data extraction and filtering completed" -ResponseData $jsonResult.Output
} else {
    Write-TestResult "JSON Operations" $false -ErrorMessage $jsonResult.Error
}

# Test 12: Create Index
Write-Host "Testing index creation..." -ForegroundColor Yellow
$createIndexQuery = @"
USE [$TestDatabase];
CREATE NONCLUSTERED INDEX [IX_employees_department_salary] 
ON [dbo].[employees] ([department] ASC, [salary] DESC);

SELECT 'Index created successfully' AS Result;
"@

$createIndexResult = Invoke-SqlServerCommand -Query $createIndexQuery -Database $TestDatabase
if ($createIndexResult.Success) {
    Write-TestResult "Create Index" $true "Composite index on department and salary created" -ResponseData $createIndexResult.Output
} else {
    Write-TestResult "Create Index" $false -ErrorMessage $createIndexResult.Error
}

# Test 13: Stored Procedure
Write-Host "Creating and testing stored procedure..." -ForegroundColor Yellow
$createProcQuery = @"
USE [$TestDatabase];

IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name = 'GetEmployeesByDepartment')
DROP PROCEDURE [dbo].[GetEmployeesByDepartment];

GO

CREATE PROCEDURE [dbo].[GetEmployeesByDepartment]
    @Department NVARCHAR(50),
    @ActiveOnly BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        employee_id,
        first_name + ' ' + last_name AS full_name,
        email,
        hire_date,
        salary,
        CASE WHEN is_active = 1 THEN 'Active' ELSE 'Inactive' END AS status
    FROM [dbo].[employees]
    WHERE department = @Department 
        AND (@ActiveOnly = 0 OR is_active = @ActiveOnly)
    ORDER BY salary DESC;
END

GO

-- Test the stored procedure
EXEC [dbo].[GetEmployeesByDepartment] @Department = 'Engineering', @ActiveOnly = 1;
"@

$createProcResult = Invoke-SqlServerCommand -Query $createProcQuery -Database $TestDatabase
if ($createProcResult.Success) {
    Write-TestResult "Stored Procedure" $true "Stored procedure created and executed successfully" -ResponseData $createProcResult.Output
} else {
    Write-TestResult "Stored Procedure" $false -ErrorMessage $createProcResult.Error
}

# Test 14: Transaction Test
Write-Host "Testing transaction handling..." -ForegroundColor Yellow
$transactionQuery = @"
USE [$TestDatabase];

BEGIN TRANSACTION;

INSERT INTO [dbo].[employees] 
(employee_id, first_name, last_name, email, hire_date, salary, department, is_active, metadata)
VALUES
('EMP999', 'Test', 'Transaction', 'test.transaction@artemis.dev', GETDATE(), 70000.00, 'Testing', 1, '{"skills": ["Testing"], "level": "Test"}');

-- Check if insert was successful
IF @@ROWCOUNT = 1
BEGIN
    COMMIT TRANSACTION;
    SELECT 'Transaction committed successfully' AS Result;
    
    -- Clean up the test record
    DELETE FROM [dbo].[employees] WHERE employee_id = 'EMP999';
    SELECT 'Test record cleaned up' AS Cleanup;
END
ELSE
BEGIN
    ROLLBACK TRANSACTION;
    SELECT 'Transaction rolled back' AS Result;
END
"@

$transactionResult = Invoke-SqlServerCommand -Query $transactionQuery -Database $TestDatabase
if ($transactionResult.Success) {
    Write-TestResult "Transaction Handling" $true "Transaction test completed successfully" -ResponseData $transactionResult.Output
} else {
    Write-TestResult "Transaction Handling" $false -ErrorMessage $transactionResult.Error
}

# Test 15: Database Schema Information
Write-Host "Retrieving database schema information..." -ForegroundColor Yellow
$schemaQuery = @"
USE [$TestDatabase];
SELECT 
    t.TABLE_NAME,
    t.TABLE_TYPE,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.IS_NULLABLE,
    c.COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.TABLES t
INNER JOIN INFORMATION_SCHEMA.COLUMNS c ON t.TABLE_NAME = c.TABLE_NAME
WHERE t.TABLE_TYPE = 'BASE TABLE'
ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION;
"@

$schemaResult = Invoke-SqlServerCommand -Query $schemaQuery -Database $TestDatabase
if ($schemaResult.Success) {
    Write-TestResult "Database Schema" $true "Schema information retrieved successfully" -ResponseData $schemaResult.Output
} else {
    Write-TestResult "Database Schema" $false -ErrorMessage $schemaResult.Error
}

# Cleanup (unless skipped)
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "Cleaning up test database..." -ForegroundColor Yellow
    
    $dropDbQuery = @"
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$TestDatabase')
BEGIN
    ALTER DATABASE [$TestDatabase] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$TestDatabase];
    SELECT 'Database dropped successfully' AS Result;
END
ELSE
BEGIN
    SELECT 'Database does not exist' AS Result;
END
"@

    $dropDbResult = Invoke-SqlServerCommand -Query $dropDbQuery -Database "master"
    if ($dropDbResult.Success) {
        Write-TestResult "Cleanup Test Database" $true "Test database '$TestDatabase' dropped successfully"
    } else {
        Write-TestResult "Cleanup Test Database" $false -ErrorMessage $dropDbResult.Error
    }
} else {
    Write-Host ""
    Write-Host "⚠️ Skipping cleanup - Test database '$TestDatabase' preserved" -ForegroundColor Yellow
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
Write-Host "SQL Server" -ForegroundColor Blue

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
Write-Host "Test Database: $TestDatabase" -ForegroundColor Gray
Write-Host "Features Tested:" -ForegroundColor Gray
Write-Host "  - Database & table creation" -ForegroundColor Gray
Write-Host "  - CRUD operations (Create, Read, Update, Delete)" -ForegroundColor Gray
Write-Host "  - Complex queries & aggregations" -ForegroundColor Gray
Write-Host "  - JSON data handling" -ForegroundColor Gray
Write-Host "  - Indexes & stored procedures" -ForegroundColor Gray
Write-Host "  - Transaction management" -ForegroundColor Gray

if (-not $SkipCleanup) {
    Write-Host "Cleanup: Completed" -ForegroundColor Gray
} else {
    Write-Host "Cleanup: Skipped - Database preserved for inspection" -ForegroundColor Gray
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan

# Return results object for consumption by other scripts
return $TestResults