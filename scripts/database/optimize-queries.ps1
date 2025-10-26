# Docker Travian Database Query Optimization
# Automated system to identify and optimize slow queries

param(
    [Parameter(Mandatory=$false)]
    [switch]$AnalyzeOnly = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$ApplyOptimizations = $false,
    
    [Parameter(Mandatory=$false)]
    [int]$SlowQueryThreshold = 1,
    
    [Parameter(Mandatory=$false)]
    [switch]$CreateIndexes = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport = $true
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$LogFile = Join-Path $ProjectRoot "logs\query-optimization-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ReportFile = Join-Path $ProjectRoot "reports\query-analysis-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

# Ensure directories exist
@((Split-Path -Parent $LogFile), (Split-Path -Parent $ReportFile)) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
    }
}

# Logging function
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogEntry = "[$Timestamp] [$Level] $Message"
    
    switch ($Level) {
        "ERROR" { Write-Host $LogEntry -ForegroundColor Red }
        "WARN" { Write-Host $LogEntry -ForegroundColor Yellow }
        "SUCCESS" { Write-Host $LogEntry -ForegroundColor Green }
        default { Write-Host $LogEntry }
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

# Query analysis results
$QueryAnalysis = @{
    SlowQueries = @()
    MissingIndexes = @()
    TableStats = @()
    Recommendations = @()
    OptimizationsApplied = @()
}

Write-Log "Starting database query optimization analysis..."
Write-Log "Slow Query Threshold: $SlowQueryThreshold seconds"
Write-Log "Analyze Only: $AnalyzeOnly"
Write-Log "Apply Optimizations: $ApplyOptimizations"

# Execute MySQL query
function Invoke-MySQLQuery {
    param(
        [string]$Query,
        [switch]$Silent = $false
    )
    
    try {
        $Result = docker-compose exec -T mysql mysql -u travian -ptravian123 -e "$Query" travian 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            return $Result
        }
        else {
            if (-not $Silent) {
                Write-Log "MySQL query failed: $Query" "ERROR"
            }
            return $null
        }
    }
    catch {
        if (-not $Silent) {
            Write-Log "MySQL query error: $($_.Exception.Message)" "ERROR"
        }
        return $null
    }
}

# Enable slow query log
function Enable-SlowQueryLog {
    Write-Log "Enabling slow query log..."
    
    $Queries = @(
        "SET GLOBAL slow_query_log = 'ON';",
        "SET GLOBAL long_query_time = $SlowQueryThreshold;",
        "SET GLOBAL log_queries_not_using_indexes = 'ON';"
    )
    
    foreach ($Query in $Queries) {
        $Result = Invoke-MySQLQuery -Query $Query -Silent
        if ($Result) {
            Write-Log "Executed: $Query"
        }
    }
}

# Analyze slow queries
function Get-SlowQueries {
    Write-Log "Analyzing slow queries..."
    
    $SlowQueryAnalysis = @"
SELECT 
    sql_text,
    exec_count,
    avg_timer_wait/1000000000 as avg_time_sec,
    max_timer_wait/1000000000 as max_time_sec,
    sum_timer_wait/1000000000 as total_time_sec,
    sum_rows_examined,
    sum_rows_sent,
    digest_text
FROM performance_schema.events_statements_summary_by_digest 
WHERE avg_timer_wait > ($SlowQueryThreshold * 1000000000)
ORDER BY avg_timer_wait DESC 
LIMIT 20;
"@
    
    $Result = Invoke-MySQLQuery -Query $SlowQueryAnalysis
    
    if ($Result) {
        $Lines = $Result -split "`n" | Where-Object { $_ -and $_ -notmatch "^sql_text" }
        
        foreach ($Line in $Lines) {
            if ($Line.Trim()) {
                $Fields = $Line -split "`t"
                if ($Fields.Count -ge 8) {
                    $QueryAnalysis.SlowQueries += @{
                        SQL = $Fields[0]
                        ExecutionCount = $Fields[1]
                        AvgTime = [math]::Round([double]$Fields[2], 3)
                        MaxTime = [math]::Round([double]$Fields[3], 3)
                        TotalTime = [math]::Round([double]$Fields[4], 3)
                        RowsExamined = $Fields[5]
                        RowsSent = $Fields[6]
                        DigestText = $Fields[7]
                    }
                }
            }
        }
        
        Write-Log "Found $($QueryAnalysis.SlowQueries.Count) slow queries"
    }
}

# Analyze table statistics
function Get-TableStatistics {
    Write-Log "Analyzing table statistics..."
    
    $TableStatsQuery = @"
SELECT 
    TABLE_NAME,
    TABLE_ROWS,
    DATA_LENGTH,
    INDEX_LENGTH,
    (DATA_LENGTH + INDEX_LENGTH) as TOTAL_SIZE,
    AVG_ROW_LENGTH,
    AUTO_INCREMENT
FROM information_schema.TABLES 
WHERE TABLE_SCHEMA = 'travian' 
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;
"@
    
    $Result = Invoke-MySQLQuery -Query $TableStatsQuery
    
    if ($Result) {
        $Lines = $Result -split "`n" | Where-Object { $_ -and $_ -notmatch "^TABLE_NAME" }
        
        foreach ($Line in $Lines) {
            if ($Line.Trim()) {
                $Fields = $Line -split "`t"
                if ($Fields.Count -ge 7) {
                    $QueryAnalysis.TableStats += @{
                        TableName = $Fields[0]
                        RowCount = $Fields[1]
                        DataSize = [math]::Round([long]$Fields[2] / 1MB, 2)
                        IndexSize = [math]::Round([long]$Fields[3] / 1MB, 2)
                        TotalSize = [math]::Round([long]$Fields[4] / 1MB, 2)
                        AvgRowLength = $Fields[5]
                        AutoIncrement = $Fields[6]
                    }
                }
            }
        }
        
        Write-Log "Analyzed $($QueryAnalysis.TableStats.Count) tables"
    }
}

# Find missing indexes
function Find-MissingIndexes {
    Write-Log "Identifying missing indexes..."
    
    # Common patterns that need indexes
    $IndexRecommendations = @(
        @{
            Table = "users"
            Columns = @("username", "email", "last_login", "active")
            Reason = "User authentication and lookups"
        },
        @{
            Table = "villages"
            Columns = @("owner_id", "x_coord", "y_coord", "population")
            Reason = "Village queries and map operations"
        },
        @{
            Table = "buildings"
            Columns = @("village_id", "type", "level")
            Reason = "Building queries per village"
        },
        @{
            Table = "units"
            Columns = @("village_id", "unit_type")
            Reason = "Unit management per village"
        },
        @{
            Table = "movements"
            Columns = @("from_village", "to_village", "arrival")
            Reason = "Movement tracking and arrival times"
        },
        @{
            Table = "resources"
            Columns = @("village_id", "last_update")
            Reason = "Resource calculations"
        },
        @{
            Table = "messages"
            Columns = @("receiver_id", "sender_id", "timestamp", "read_status")
            Reason = "Message system performance"
        },
        @{
            Table = "reports"
            Columns = @("user_id", "timestamp", "type")
            Reason = "Report retrieval"
        }
    )
    
    foreach ($Recommendation in $IndexRecommendations) {
        # Check if indexes exist
        $IndexCheckQuery = @"
SELECT COUNT(*) as index_count
FROM information_schema.STATISTICS 
WHERE TABLE_SCHEMA = 'travian' 
AND TABLE_NAME = '$($Recommendation.Table)'
AND COLUMN_NAME IN ('$($Recommendation.Columns -join "', '")')
"@
        
        $Result = Invoke-MySQLQuery -Query $IndexCheckQuery -Silent
        
        if ($Result) {
            $IndexCount = ($Result -split "`n")[1]
            
            if ([int]$IndexCount -lt $Recommendation.Columns.Count) {
                $QueryAnalysis.MissingIndexes += @{
                    Table = $Recommendation.Table
                    Columns = $Recommendation.Columns
                    Reason = $Recommendation.Reason
                    Priority = "High"
                }
            }
        }
    }
    
    Write-Log "Found $($QueryAnalysis.MissingIndexes.Count) potential missing indexes"
}

# Generate optimization recommendations
function New-OptimizationRecommendations {
    Write-Log "Generating optimization recommendations..."
    
    # Analyze slow queries for recommendations
    foreach ($SlowQuery in $QueryAnalysis.SlowQueries) {
        if ($SlowQuery.AvgTime -gt 2) {
            $QueryAnalysis.Recommendations += @{
                Type = "Query Optimization"
                Priority = "High"
                Description = "Query taking $($SlowQuery.AvgTime)s on average"
                Query = $SlowQuery.DigestText
                Suggestion = "Consider adding indexes, rewriting query, or optimizing WHERE clauses"
            }
        }
    }
    
    # Analyze table sizes for recommendations
    foreach ($Table in $QueryAnalysis.TableStats) {
        if ($Table.TotalSize -gt 100 -and $Table.IndexSize -lt ($Table.DataSize * 0.1)) {
            $QueryAnalysis.Recommendations += @{
                Type = "Index Optimization"
                Priority = "Medium"
                Description = "Large table '$($Table.TableName)' with minimal indexes"
                Table = $Table.TableName
                Suggestion = "Consider adding indexes for frequently queried columns"
            }
        }
        
        if ([long]$Table.RowCount -gt 100000) {
            $QueryAnalysis.Recommendations += @{
                Type = "Table Optimization"
                Priority = "Medium"
                Description = "Large table '$($Table.TableName)' with $($Table.RowCount) rows"
                Table = $Table.TableName
                Suggestion = "Consider partitioning, archiving old data, or query optimization"
            }
        }
    }
    
    # Missing index recommendations
    foreach ($MissingIndex in $QueryAnalysis.MissingIndexes) {
        $QueryAnalysis.Recommendations += @{
            Type = "Missing Index"
            Priority = $MissingIndex.Priority
            Description = "Missing indexes on table '$($MissingIndex.Table)'"
            Table = $MissingIndex.Table
            Suggestion = "Add composite index on columns: $($MissingIndex.Columns -join ', ')"
            Reason = $MissingIndex.Reason
        }
    }
    
    Write-Log "Generated $($QueryAnalysis.Recommendations.Count) optimization recommendations"
}

# Apply optimizations
function Apply-DatabaseOptimizations {
    if (-not $ApplyOptimizations) {
        Write-Log "Skipping optimization application (use -ApplyOptimizations to enable)"
        return
    }
    
    Write-Log "Applying database optimizations..."
    
    # Create recommended indexes
    if ($CreateIndexes) {
        foreach ($MissingIndex in $QueryAnalysis.MissingIndexes) {
            $IndexName = "idx_$($MissingIndex.Table)_$($MissingIndex.Columns -join '_')"
            $CreateIndexQuery = "CREATE INDEX $IndexName ON $($MissingIndex.Table) ($($MissingIndex.Columns -join ', '));"
            
            Write-Log "Creating index: $IndexName"
            $Result = Invoke-MySQLQuery -Query $CreateIndexQuery
            
            if ($Result -ne $null) {
                $QueryAnalysis.OptimizationsApplied += @{
                    Type = "Index Creation"
                    Description = "Created index $IndexName on table $($MissingIndex.Table)"
                    Query = $CreateIndexQuery
                }
                Write-Log "Index created successfully: $IndexName" "SUCCESS"
            }
            else {
                Write-Log "Failed to create index: $IndexName" "ERROR"
            }
        }
    }
    
    # Apply MySQL configuration optimizations
    $ConfigOptimizations = @(
        "SET GLOBAL innodb_buffer_pool_size = 1073741824;",  # 1GB
        "SET GLOBAL query_cache_size = 67108864;",           # 64MB
        "SET GLOBAL query_cache_type = 1;",
        "SET GLOBAL tmp_table_size = 67108864;",             # 64MB
        "SET GLOBAL max_heap_table_size = 67108864;"         # 64MB
    )
    
    foreach ($OptQuery in $ConfigOptimizations) {
        $Result = Invoke-MySQLQuery -Query $OptQuery -Silent
        if ($Result -ne $null) {
            $QueryAnalysis.OptimizationsApplied += @{
                Type = "Configuration"
                Description = "Applied MySQL configuration optimization"
                Query = $OptQuery
            }
        }
    }
    
    Write-Log "Applied $($QueryAnalysis.OptimizationsApplied.Count) optimizations"
}

# Generate HTML report
function New-OptimizationReport {
    if (-not $GenerateReport) {
        return
    }
    
    Write-Log "Generating optimization report..."
    
    $ReportHTML = @"
<!DOCTYPE html>
<html>
<head>
    <title>Docker Travian - Database Optimization Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1, h2 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .summary { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; padding: 10px; background: #f0f8ff; border-radius: 5px; }
        .metric-value { font-size: 24px; font-weight: bold; color: #007acc; }
        .metric-label { font-size: 12px; color: #666; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #007acc; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .priority-high { color: #d32f2f; font-weight: bold; }
        .priority-medium { color: #f57c00; font-weight: bold; }
        .priority-low { color: #388e3c; font-weight: bold; }
        .query-text { font-family: monospace; background: #f5f5f5; padding: 5px; border-radius: 3px; }
        .recommendation { background: #fff3cd; border: 1px solid #ffeaa7; padding: 10px; margin: 10px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Docker Travian - Database Optimization Report</h1>
        
        <div class="summary">
            <h2>📊 Summary</h2>
            <div class="metric">
                <div class="metric-value">$($QueryAnalysis.SlowQueries.Count)</div>
                <div class="metric-label">Slow Queries</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($QueryAnalysis.MissingIndexes.Count)</div>
                <div class="metric-label">Missing Indexes</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($QueryAnalysis.TableStats.Count)</div>
                <div class="metric-label">Tables Analyzed</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($QueryAnalysis.Recommendations.Count)</div>
                <div class="metric-label">Recommendations</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($QueryAnalysis.OptimizationsApplied.Count)</div>
                <div class="metric-label">Optimizations Applied</div>
            </div>
        </div>

        <h2>🐌 Slow Queries Analysis</h2>
        <table>
            <tr>
                <th>Query Digest</th>
                <th>Avg Time (s)</th>
                <th>Max Time (s)</th>
                <th>Executions</th>
                <th>Rows Examined</th>
            </tr>
"@
    
    foreach ($Query in $QueryAnalysis.SlowQueries) {
        $ReportHTML += @"
            <tr>
                <td class="query-text">$($Query.DigestText)</td>
                <td>$($Query.AvgTime)</td>
                <td>$($Query.MaxTime)</td>
                <td>$($Query.ExecutionCount)</td>
                <td>$($Query.RowsExamined)</td>
            </tr>
"@
    }
    
    $ReportHTML += @"
        </table>

        <h2>📋 Table Statistics</h2>
        <table>
            <tr>
                <th>Table Name</th>
                <th>Row Count</th>
                <th>Data Size (MB)</th>
                <th>Index Size (MB)</th>
                <th>Total Size (MB)</th>
            </tr>
"@
    
    foreach ($Table in $QueryAnalysis.TableStats) {
        $ReportHTML += @"
            <tr>
                <td>$($Table.TableName)</td>
                <td>$($Table.RowCount)</td>
                <td>$($Table.DataSize)</td>
                <td>$($Table.IndexSize)</td>
                <td>$($Table.TotalSize)</td>
            </tr>
"@
    }
    
    $ReportHTML += @"
        </table>

        <h2>💡 Optimization Recommendations</h2>
"@
    
    foreach ($Rec in $QueryAnalysis.Recommendations) {
        $PriorityClass = "priority-$($Rec.Priority.ToLower())"
        $ReportHTML += @"
        <div class="recommendation">
            <h3 class="$PriorityClass">$($Rec.Type) - $($Rec.Priority) Priority</h3>
            <p><strong>Description:</strong> $($Rec.Description)</p>
            <p><strong>Suggestion:</strong> $($Rec.Suggestion)</p>
            $(if ($Rec.Reason) { "<p><strong>Reason:</strong> $($Rec.Reason)</p>" })
        </div>
"@
    }
    
    $ReportHTML += @"
        <h2>✅ Applied Optimizations</h2>
        <table>
            <tr>
                <th>Type</th>
                <th>Description</th>
                <th>Query</th>
            </tr>
"@
    
    foreach ($Opt in $QueryAnalysis.OptimizationsApplied) {
        $ReportHTML += @"
            <tr>
                <td>$($Opt.Type)</td>
                <td>$($Opt.Description)</td>
                <td class="query-text">$($Opt.Query)</td>
            </tr>
"@
    }
    
    $ReportHTML += @"
        </table>

        <div style="margin-top: 40px; padding: 20px; background: #f8f9fa; border-radius: 5px; text-align: center;">
            <p><strong>Report Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
            <p><strong>Docker Travian Database Optimization System</strong></p>
        </div>
    </div>
</body>
</html>
"@
    
    Set-Content -Path $ReportFile -Value $ReportHTML -Encoding UTF8
    Write-Log "Report generated: $ReportFile" "SUCCESS"
}

# Main execution
try {
    # Enable slow query logging
    Enable-SlowQueryLog
    
    # Perform analysis
    Get-SlowQueries
    Get-TableStatistics
    Find-MissingIndexes
    New-OptimizationRecommendations
    
    # Apply optimizations if requested
    Apply-DatabaseOptimizations
    
    # Generate report
    New-OptimizationReport
    
    # Summary
    Write-Log ""
    Write-Log "=== OPTIMIZATION SUMMARY ===" "SUCCESS"
    Write-Log "Slow Queries Found: $($QueryAnalysis.SlowQueries.Count)"
    Write-Log "Missing Indexes: $($QueryAnalysis.MissingIndexes.Count)"
    Write-Log "Recommendations: $($QueryAnalysis.Recommendations.Count)"
    Write-Log "Optimizations Applied: $($QueryAnalysis.OptimizationsApplied.Count)"
    Write-Log "Report File: $ReportFile"
    Write-Log "Log File: $LogFile"
    
    exit 0
}
catch {
    Write-Log "Query optimization failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
