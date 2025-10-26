# Docker Travian Load Testing Script
# Performance testing with automated load generation

param(
    [Parameter(Mandatory=$false)]
    [int]$Users = 100,
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 300,
    
    [Parameter(Mandatory=$false)]
    [string]$TargetUrl = "http://localhost:8080",
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport = $true
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$LogFile = Join-Path $ProjectRoot "logs\load-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$ReportFile = Join-Path $ProjectRoot "reports\load-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"

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

# Test results
$TestResults = @{
    StartTime = Get-Date
    EndTime = $null
    TotalRequests = 0
    SuccessfulRequests = 0
    FailedRequests = 0
    ResponseTimes = @()
    Errors = @()
    ThroughputRPS = 0
    AverageResponseTime = 0
    P95ResponseTime = 0
    P99ResponseTime = 0
}

Write-Log "Starting load test..."
Write-Log "Target URL: $TargetUrl"
Write-Log "Concurrent Users: $Users"
Write-Log "Duration: $Duration seconds"

# Test scenarios
$TestScenarios = @(
    @{ Name = "Home Page"; Url = "/"; Weight = 30 },
    @{ Name = "Login Page"; Url = "/login.php"; Weight = 20 },
    @{ Name = "Village View"; Url = "/dorf1.php"; Weight = 25 },
    @{ Name = "Map View"; Url = "/karte.php"; Weight = 15 },
    @{ Name = "Statistics"; Url = "/statistiken.php"; Weight = 10 }
)

# Generate load test
function Start-LoadTest {
    Write-Log "Initializing load test with $Users concurrent users..."
    
    $Jobs = @()
    $StartTime = Get-Date
    
    # Create user simulation jobs
    for ($i = 1; $i -le $Users; $i++) {
        $Job = Start-Job -ScriptBlock {
            param($TargetUrl, $Duration, $TestScenarios, $UserId)
            
            $EndTime = (Get-Date).AddSeconds($Duration)
            $Results = @{
                UserId = $UserId
                Requests = 0
                Successes = 0
                Failures = 0
                ResponseTimes = @()
                Errors = @()
            }
            
            while ((Get-Date) -lt $EndTime) {
                # Select random scenario based on weight
                $Random = Get-Random -Maximum 100
                $CumulativeWeight = 0
                $SelectedScenario = $null
                
                foreach ($Scenario in $TestScenarios) {
                    $CumulativeWeight += $Scenario.Weight
                    if ($Random -lt $CumulativeWeight) {
                        $SelectedScenario = $Scenario
                        break
                    }
                }
                
                if (-not $SelectedScenario) {
                    $SelectedScenario = $TestScenarios[0]
                }
                
                # Make HTTP request
                try {
                    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    $Response = Invoke-WebRequest -Uri "$TargetUrl$($SelectedScenario.Url)" -TimeoutSec 30 -UseBasicParsing
                    $Stopwatch.Stop()
                    
                    $Results.Requests++
                    $Results.ResponseTimes += $Stopwatch.ElapsedMilliseconds
                    
                    if ($Response.StatusCode -eq 200) {
                        $Results.Successes++
                    } else {
                        $Results.Failures++
                        $Results.Errors += "HTTP $($Response.StatusCode) for $($SelectedScenario.Name)"
                    }
                }
                catch {
                    $Results.Requests++
                    $Results.Failures++
                    $Results.Errors += "Request failed for $($SelectedScenario.Name): $($_.Exception.Message)"
                }
                
                # Random think time between requests (1-5 seconds)
                Start-Sleep -Milliseconds (Get-Random -Minimum 1000 -Maximum 5000)
            }
            
            return $Results
        } -ArgumentList $TargetUrl, $Duration, $TestScenarios, $i
        
        $Jobs += $Job
        
        # Stagger user startup
        Start-Sleep -Milliseconds 100
    }
    
    Write-Log "All $Users users started. Running test for $Duration seconds..."
    
    # Wait for test completion
    $CompletedJobs = 0
    while ($CompletedJobs -lt $Users) {
        Start-Sleep -Seconds 5
        $CompletedJobs = ($Jobs | Where-Object { $_.State -eq "Completed" }).Count
        $RunningJobs = ($Jobs | Where-Object { $_.State -eq "Running" }).Count
        
        Write-Log "Progress: $CompletedJobs/$Users users completed, $RunningJobs running"
    }
    
    # Collect results
    Write-Log "Collecting test results..."
    
    foreach ($Job in $Jobs) {
        $JobResult = Receive-Job -Job $Job
        Remove-Job -Job $Job
        
        if ($JobResult) {
            $TestResults.TotalRequests += $JobResult.Requests
            $TestResults.SuccessfulRequests += $JobResult.Successes
            $TestResults.FailedRequests += $JobResult.Failures
            $TestResults.ResponseTimes += $JobResult.ResponseTimes
            $TestResults.Errors += $JobResult.Errors
        }
    }
    
    $TestResults.EndTime = Get-Date
    
    # Calculate metrics
    if ($TestResults.ResponseTimes.Count -gt 0) {
        $SortedTimes = $TestResults.ResponseTimes | Sort-Object
        $TestResults.AverageResponseTime = [math]::Round(($TestResults.ResponseTimes | Measure-Object -Average).Average, 2)
        $TestResults.P95ResponseTime = $SortedTimes[[math]::Floor($SortedTimes.Count * 0.95)]
        $TestResults.P99ResponseTime = $SortedTimes[[math]::Floor($SortedTimes.Count * 0.99)]
    }
    
    $TestDuration = ($TestResults.EndTime - $TestResults.StartTime).TotalSeconds
    $TestResults.ThroughputRPS = [math]::Round($TestResults.TotalRequests / $TestDuration, 2)
}

# Generate HTML report
function New-LoadTestReport {
    if (-not $GenerateReport) {
        return
    }
    
    Write-Log "Generating load test report..."
    
    $SuccessRate = if ($TestResults.TotalRequests -gt 0) { 
        [math]::Round(($TestResults.SuccessfulRequests / $TestResults.TotalRequests) * 100, 2) 
    } else { 0 }
    
    $ErrorRate = if ($TestResults.TotalRequests -gt 0) { 
        [math]::Round(($TestResults.FailedRequests / $TestResults.TotalRequests) * 100, 2) 
    } else { 0 }
    
    $ReportHTML = @"
<!DOCTYPE html>
<html>
<head>
    <title>Docker Travian - Load Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1, h2 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .summary { background: #e7f3ff; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; padding: 15px; background: #f0f8ff; border-radius: 5px; text-align: center; }
        .metric-value { font-size: 28px; font-weight: bold; color: #007acc; }
        .metric-label { font-size: 14px; color: #666; margin-top: 5px; }
        .status-good { color: #4caf50; }
        .status-warning { color: #ff9800; }
        .status-error { color: #f44336; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #007acc; color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .chart-container { margin: 20px 0; padding: 20px; background: #f8f9fa; border-radius: 5px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 Docker Travian - Load Test Report</h1>
        
        <div class="summary">
            <h2>📊 Test Summary</h2>
            <div class="metric">
                <div class="metric-value">$Users</div>
                <div class="metric-label">Concurrent Users</div>
            </div>
            <div class="metric">
                <div class="metric-value">$Duration</div>
                <div class="metric-label">Duration (seconds)</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($TestResults.TotalRequests)</div>
                <div class="metric-label">Total Requests</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($TestResults.ThroughputRPS)</div>
                <div class="metric-label">Requests/Second</div>
            </div>
        </div>

        <h2>📈 Performance Metrics</h2>
        <table>
            <tr>
                <th>Metric</th>
                <th>Value</th>
                <th>Status</th>
            </tr>
            <tr>
                <td>Success Rate</td>
                <td>$SuccessRate%</td>
                <td class="$(if ($SuccessRate -ge 95) { 'status-good' } elseif ($SuccessRate -ge 90) { 'status-warning' } else { 'status-error' })">$(if ($SuccessRate -ge 95) { '✅ Excellent' } elseif ($SuccessRate -ge 90) { '⚠️ Good' } else { '❌ Poor' })</td>
            </tr>
            <tr>
                <td>Error Rate</td>
                <td>$ErrorRate%</td>
                <td class="$(if ($ErrorRate -le 1) { 'status-good' } elseif ($ErrorRate -le 5) { 'status-warning' } else { 'status-error' })">$(if ($ErrorRate -le 1) { '✅ Excellent' } elseif ($ErrorRate -le 5) { '⚠️ Acceptable' } else { '❌ High' })</td>
            </tr>
            <tr>
                <td>Average Response Time</td>
                <td>$($TestResults.AverageResponseTime) ms</td>
                <td class="$(if ($TestResults.AverageResponseTime -le 300) { 'status-good' } elseif ($TestResults.AverageResponseTime -le 1000) { 'status-warning' } else { 'status-error' })">$(if ($TestResults.AverageResponseTime -le 300) { '✅ Fast' } elseif ($TestResults.AverageResponseTime -le 1000) { '⚠️ Acceptable' } else { '❌ Slow' })</td>
            </tr>
            <tr>
                <td>95th Percentile</td>
                <td>$($TestResults.P95ResponseTime) ms</td>
                <td class="$(if ($TestResults.P95ResponseTime -le 500) { 'status-good' } elseif ($TestResults.P95ResponseTime -le 2000) { 'status-warning' } else { 'status-error' })">$(if ($TestResults.P95ResponseTime -le 500) { '✅ Good' } elseif ($TestResults.P95ResponseTime -le 2000) { '⚠️ Acceptable' } else { '❌ Poor' })</td>
            </tr>
            <tr>
                <td>99th Percentile</td>
                <td>$($TestResults.P99ResponseTime) ms</td>
                <td class="$(if ($TestResults.P99ResponseTime -le 1000) { 'status-good' } elseif ($TestResults.P99ResponseTime -le 3000) { 'status-warning' } else { 'status-error' })">$(if ($TestResults.P99ResponseTime -le 1000) { '✅ Good' } elseif ($TestResults.P99ResponseTime -le 3000) { '⚠️ Acceptable' } else { '❌ Poor' })</td>
            </tr>
            <tr>
                <td>Throughput</td>
                <td>$($TestResults.ThroughputRPS) RPS</td>
                <td class="$(if ($TestResults.ThroughputRPS -ge 100) { 'status-good' } elseif ($TestResults.ThroughputRPS -ge 50) { 'status-warning' } else { 'status-error' })">$(if ($TestResults.ThroughputRPS -ge 100) { '✅ High' } elseif ($TestResults.ThroughputRPS -ge 50) { '⚠️ Medium' } else { '❌ Low' })</td>
            </tr>
        </table>

        <h2>📋 Test Results</h2>
        <table>
            <tr>
                <th>Metric</th>
                <th>Count</th>
                <th>Percentage</th>
            </tr>
            <tr>
                <td>Successful Requests</td>
                <td>$($TestResults.SuccessfulRequests)</td>
                <td>$SuccessRate%</td>
            </tr>
            <tr>
                <td>Failed Requests</td>
                <td>$($TestResults.FailedRequests)</td>
                <td>$ErrorRate%</td>
            </tr>
            <tr>
                <td>Total Requests</td>
                <td>$($TestResults.TotalRequests)</td>
                <td>100%</td>
            </tr>
        </table>
"@
    
    if ($TestResults.Errors.Count -gt 0) {
        $ReportHTML += @"
        <h2>❌ Errors</h2>
        <table>
            <tr>
                <th>Error</th>
                <th>Count</th>
            </tr>
"@
        
        $ErrorGroups = $TestResults.Errors | Group-Object | Sort-Object Count -Descending
        foreach ($ErrorGroup in $ErrorGroups) {
            $ReportHTML += @"
            <tr>
                <td>$($ErrorGroup.Name)</td>
                <td>$($ErrorGroup.Count)</td>
            </tr>
"@
        }
        
        $ReportHTML += "</table>"
    }
    
    $ReportHTML += @"
        <div style="margin-top: 40px; padding: 20px; background: #f8f9fa; border-radius: 5px; text-align: center;">
            <p><strong>Test Started:</strong> $($TestResults.StartTime.ToString("yyyy-MM-dd HH:mm:ss"))</p>
            <p><strong>Test Completed:</strong> $($TestResults.EndTime.ToString("yyyy-MM-dd HH:mm:ss"))</p>
            <p><strong>Target URL:</strong> $TargetUrl</p>
            <p><strong>Docker Travian Load Testing System</strong></p>
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
    # Verify target is accessible
    Write-Log "Verifying target accessibility..."
    try {
        $TestResponse = Invoke-WebRequest -Uri $TargetUrl -TimeoutSec 10 -UseBasicParsing
        Write-Log "Target accessible: HTTP $($TestResponse.StatusCode)"
    }
    catch {
        Write-Log "Warning: Target may not be accessible: $($_.Exception.Message)" "WARN"
    }
    
    # Run load test
    Start-LoadTest
    
    # Generate report
    New-LoadTestReport
    
    # Summary
    Write-Log ""
    Write-Log "=== LOAD TEST SUMMARY ===" "SUCCESS"
    Write-Log "Total Requests: $($TestResults.TotalRequests)"
    Write-Log "Successful: $($TestResults.SuccessfulRequests)"
    Write-Log "Failed: $($TestResults.FailedRequests)"
    Write-Log "Average Response Time: $($TestResults.AverageResponseTime) ms"
    Write-Log "Throughput: $($TestResults.ThroughputRPS) RPS"
    Write-Log "Report: $ReportFile"
    Write-Log "Log: $LogFile"
    
    exit 0
}
catch {
    Write-Log "Load test failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
