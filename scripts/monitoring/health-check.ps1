# Docker Travian Health Check System
# Comprehensive monitoring and alerting for all services

param(
    [Parameter(Mandatory=$false)]
    [switch]$Continuous = $false,
    
    [Parameter(Mandatory=$false)]
    [int]$IntervalSeconds = 60,
    
    [Parameter(Mandatory=$false)]
    [switch]$AlertOnFailure = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$AlertWebhook = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$Detailed = $false
)

# Script configuration
$ErrorActionPreference = "Continue"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$LogFile = Join-Path $ProjectRoot "logs\health-check-$(Get-Date -Format 'yyyyMMdd').log"

# Health check thresholds
$HealthThresholds = @{
    ResponseTime = 5000  # 5 seconds
    MemoryUsage = 80     # 80%
    CPUUsage = 85        # 85%
    DiskUsage = 90       # 90%
    DatabaseConnections = 80  # 80% of max connections
}

# Ensure logs directory exists
$LogDir = Split-Path -Parent $LogFile
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
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
        "CRITICAL" { Write-Host $LogEntry -ForegroundColor Magenta }
        default { Write-Host $LogEntry }
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

# Health check results
$HealthResults = @{
    Timestamp = Get-Date
    Services = @{}
    Overall = @{
        Status = "Unknown"
        Score = 0
        Issues = @()
        Warnings = @()
    }
}

Write-Log "Starting Docker Travian health check..."
Write-Log "Continuous Mode: $Continuous"
Write-Log "Check Interval: $IntervalSeconds seconds"

# Check Docker service status
function Test-DockerService {
    param([string]$ServiceName)
    
    try {
        $ServiceInfo = docker-compose ps $ServiceName --format json | ConvertFrom-Json
        
        if (-not $ServiceInfo) {
            return @{
                Status = "Not Found"
                Health = "Critical"
                Message = "Service not found in Docker Compose"
            }
        }
        
        $Status = $ServiceInfo.State
        $Health = switch ($Status) {
            "running" { "Healthy" }
            "restarting" { "Warning" }
            "paused" { "Warning" }
            "exited" { "Critical" }
            default { "Unknown" }
        }
        
        return @{
            Status = $Status
            Health = $Health
            Message = "Service is $Status"
            Uptime = $ServiceInfo.RunningFor
        }
    }
    catch {
        return @{
            Status = "Error"
            Health = "Critical"
            Message = "Failed to check service: $($_.Exception.Message)"
        }
    }
}

# Check HTTP endpoint
function Test-HttpEndpoint {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 10
    )
    
    try {
        $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $Response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSeconds -UseBasicParsing
        $Stopwatch.Stop()
        
        $ResponseTime = $Stopwatch.ElapsedMilliseconds
        
        $Health = if ($Response.StatusCode -eq 200) {
            if ($ResponseTime -lt $HealthThresholds.ResponseTime) { "Healthy" } else { "Warning" }
        } else { "Critical" }
        
        return @{
            StatusCode = $Response.StatusCode
            ResponseTime = $ResponseTime
            Health = $Health
            Message = "HTTP $($Response.StatusCode) in ${ResponseTime}ms"
        }
    }
    catch {
        return @{
            StatusCode = 0
            ResponseTime = -1
            Health = "Critical"
            Message = "HTTP request failed: $($_.Exception.Message)"
        }
    }
}

# Check database connectivity
function Test-DatabaseConnection {
    try {
        $TestQuery = "SELECT 1 as test, NOW() as timestamp"
        $Result = docker-compose exec -T mysql mysql -u travian -ptravian123 -e "$TestQuery" travian 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            # Get database stats
            $StatsQuery = @"
SELECT 
    (SELECT COUNT(*) FROM information_schema.processlist) as connections,
    (SELECT @@max_connections) as max_connections,
    (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'travian') as tables
"@
            
            $Stats = docker-compose exec -T mysql mysql -u travian -ptravian123 -e "$StatsQuery" travian 2>$null
            
            return @{
                Health = "Healthy"
                Message = "Database connection successful"
                Connected = $true
                Stats = $Stats
            }
        }
        else {
            return @{
                Health = "Critical"
                Message = "Database connection failed"
                Connected = $false
            }
        }
    }
    catch {
        return @{
            Health = "Critical"
            Message = "Database test failed: $($_.Exception.Message)"
            Connected = $false
        }
    }
}

# Check Redis connectivity
function Test-RedisConnection {
    try {
        $Result = docker-compose exec -T redis redis-cli ping 2>$null
        
        if ($Result -match "PONG") {
            # Get Redis info
            $Info = docker-compose exec -T redis redis-cli info memory 2>$null
            
            return @{
                Health = "Healthy"
                Message = "Redis connection successful"
                Connected = $true
                Info = $Info
            }
        }
        else {
            return @{
                Health = "Critical"
                Message = "Redis ping failed"
                Connected = $false
            }
        }
    }
    catch {
        return @{
            Health = "Critical"
            Message = "Redis test failed: $($_.Exception.Message)"
            Connected = $false
        }
    }
}

# Check container resource usage
function Get-ContainerResources {
    param([string]$ContainerName)
    
    try {
        $Stats = docker stats $ContainerName --no-stream --format "table {{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}"
        
        if ($Stats -and $Stats.Count -gt 1) {
            $Data = $Stats[1] -split ","
            
            $CPUPercent = [float]($Data[0] -replace '%', '')
            $MemoryPercent = [float]($Data[2] -replace '%', '')
            
            $CPUHealth = if ($CPUPercent -gt $HealthThresholds.CPUUsage) { "Critical" } 
                        elseif ($CPUPercent -gt ($HealthThresholds.CPUUsage * 0.8)) { "Warning" }
                        else { "Healthy" }
            
            $MemoryHealth = if ($MemoryPercent -gt $HealthThresholds.MemoryUsage) { "Critical" }
                           elseif ($MemoryPercent -gt ($HealthThresholds.MemoryUsage * 0.8)) { "Warning" }
                           else { "Healthy" }
            
            return @{
                CPU = @{
                    Percent = $CPUPercent
                    Health = $CPUHealth
                }
                Memory = @{
                    Usage = $Data[1]
                    Percent = $MemoryPercent
                    Health = $MemoryHealth
                }
                Network = $Data[3]
                BlockIO = $Data[4]
                OverallHealth = if ($CPUHealth -eq "Critical" -or $MemoryHealth -eq "Critical") { "Critical" }
                               elseif ($CPUHealth -eq "Warning" -or $MemoryHealth -eq "Warning") { "Warning" }
                               else { "Healthy" }
            }
        }
        else {
            return @{
                OverallHealth = "Unknown"
                Message = "Unable to retrieve container stats"
            }
        }
    }
    catch {
        return @{
            OverallHealth = "Error"
            Message = "Failed to get container resources: $($_.Exception.Message)"
        }
    }
}

# Check disk usage
function Test-DiskUsage {
    try {
        $DiskInfo = docker-compose exec -T app df -h / 2>$null
        
        if ($DiskInfo) {
            $Lines = $DiskInfo -split "`n"
            if ($Lines.Count -gt 1) {
                $Data = $Lines[1] -split '\s+' | Where-Object { $_ -ne "" }
                $UsagePercent = [int]($Data[4] -replace '%', '')
                
                $Health = if ($UsagePercent -gt $HealthThresholds.DiskUsage) { "Critical" }
                         elseif ($UsagePercent -gt ($HealthThresholds.DiskUsage * 0.8)) { "Warning" }
                         else { "Healthy" }
                
                return @{
                    Used = $Data[2]
                    Available = $Data[3]
                    Percent = $UsagePercent
                    Health = $Health
                    Message = "Disk usage: $UsagePercent%"
                }
            }
        }
        
        return @{
            Health = "Unknown"
            Message = "Unable to retrieve disk usage"
        }
    }
    catch {
        return @{
            Health = "Error"
            Message = "Disk usage check failed: $($_.Exception.Message)"
        }
    }
}

# Send alert notification
function Send-Alert {
    param(
        [string]$Message,
        [string]$Level = "WARNING"
    )
    
    if (-not $AlertOnFailure -or -not $AlertWebhook) {
        return
    }
    
    try {
        $AlertPayload = @{
            text = "Docker Travian Alert"
            attachments = @(
                @{
                    color = switch ($Level) {
                        "CRITICAL" { "danger" }
                        "WARNING" { "warning" }
                        default { "good" }
                    }
                    title = "Health Check Alert - $Level"
                    text = $Message
                    ts = [int][double]::Parse((Get-Date -UFormat %s))
                }
            )
        } | ConvertTo-Json -Depth 3
        
        Invoke-RestMethod -Uri $AlertWebhook -Method Post -Body $AlertPayload -ContentType "application/json"
        Write-Log "Alert sent: $Message" "INFO"
    }
    catch {
        Write-Log "Failed to send alert: $($_.Exception.Message)" "ERROR"
    }
}

# Perform comprehensive health check
function Invoke-HealthCheck {
    Write-Log "Performing health check..."
    
    $HealthResults.Timestamp = Get-Date
    $HealthResults.Services = @{}
    
    # Define services to check
    $Services = @{
        "app" = @{
            Name = "PHP Application"
            CheckHttp = "http://localhost:8080/health"
        }
        "nginx" = @{
            Name = "Web Server"
            CheckHttp = "http://localhost:8080"
        }
        "mysql" = @{
            Name = "Database"
            CheckDatabase = $true
        }
        "redis" = @{
            Name = "Cache"
            CheckRedis = $true
        }
        "grafana" = @{
            Name = "Monitoring"
            CheckHttp = "http://localhost:3000/api/health"
        }
        "prometheus" = @{
            Name = "Metrics"
            CheckHttp = "http://localhost:9090/-/healthy"
        }
    }
    
    foreach ($ServiceKey in $Services.Keys) {
        $Service = $Services[$ServiceKey]
        Write-Log "Checking service: $($Service.Name)"
        
        $ServiceHealth = @{
            Name = $Service.Name
            Docker = Test-DockerService -ServiceName $ServiceKey
            Resources = Get-ContainerResources -ContainerName "travian-$ServiceKey"
            OverallHealth = "Unknown"
            Issues = @()
            Warnings = @()
        }
        
        # HTTP endpoint check
        if ($Service.CheckHttp) {
            $ServiceHealth.Http = Test-HttpEndpoint -Url $Service.CheckHttp
        }
        
        # Database check
        if ($Service.CheckDatabase) {
            $ServiceHealth.Database = Test-DatabaseConnection
        }
        
        # Redis check
        if ($Service.CheckRedis) {
            $ServiceHealth.Redis = Test-RedisConnection
        }
        
        # Determine overall service health
        $HealthStatuses = @()
        $HealthStatuses += $ServiceHealth.Docker.Health
        if ($ServiceHealth.Http) { $HealthStatuses += $ServiceHealth.Http.Health }
        if ($ServiceHealth.Database) { $HealthStatuses += $ServiceHealth.Database.Health }
        if ($ServiceHealth.Redis) { $HealthStatuses += $ServiceHealth.Redis.Health }
        if ($ServiceHealth.Resources) { $HealthStatuses += $ServiceHealth.Resources.OverallHealth }
        
        $ServiceHealth.OverallHealth = if ($HealthStatuses -contains "Critical") { "Critical" }
                                      elseif ($HealthStatuses -contains "Warning") { "Warning" }
                                      elseif ($HealthStatuses -contains "Healthy") { "Healthy" }
                                      else { "Unknown" }
        
        # Collect issues and warnings
        if ($ServiceHealth.Docker.Health -eq "Critical") {
            $ServiceHealth.Issues += "Docker: $($ServiceHealth.Docker.Message)"
        }
        if ($ServiceHealth.Http -and $ServiceHealth.Http.Health -eq "Critical") {
            $ServiceHealth.Issues += "HTTP: $($ServiceHealth.Http.Message)"
        }
        if ($ServiceHealth.Database -and $ServiceHealth.Database.Health -eq "Critical") {
            $ServiceHealth.Issues += "Database: $($ServiceHealth.Database.Message)"
        }
        if ($ServiceHealth.Redis -and $ServiceHealth.Redis.Health -eq "Critical") {
            $ServiceHealth.Issues += "Redis: $($ServiceHealth.Redis.Message)"
        }
        
        $HealthResults.Services[$ServiceKey] = $ServiceHealth
        
        # Log service status
        $StatusColor = switch ($ServiceHealth.OverallHealth) {
            "Healthy" { "SUCCESS" }
            "Warning" { "WARN" }
            "Critical" { "CRITICAL" }
            default { "INFO" }
        }
        
        Write-Log "$($Service.Name): $($ServiceHealth.OverallHealth)" $StatusColor
    }
    
    # Check system resources
    $HealthResults.System = @{
        Disk = Test-DiskUsage
    }
    
    # Calculate overall health score
    $TotalServices = $HealthResults.Services.Count
    $HealthyServices = ($HealthResults.Services.Values | Where-Object { $_.OverallHealth -eq "Healthy" }).Count
    $WarningServices = ($HealthResults.Services.Values | Where-Object { $_.OverallHealth -eq "Warning" }).Count
    $CriticalServices = ($HealthResults.Services.Values | Where-Object { $_.OverallHealth -eq "Critical" }).Count
    
    $HealthResults.Overall.Score = if ($TotalServices -gt 0) { 
        [math]::Round(($HealthyServices / $TotalServices) * 100, 1) 
    } else { 0 }
    
    $HealthResults.Overall.Status = if ($CriticalServices -gt 0) { "Critical" }
                                   elseif ($WarningServices -gt 0) { "Warning" }
                                   elseif ($HealthyServices -eq $TotalServices) { "Healthy" }
                                   else { "Unknown" }
    
    # Collect overall issues
    foreach ($Service in $HealthResults.Services.Values) {
        $HealthResults.Overall.Issues += $Service.Issues
        $HealthResults.Overall.Warnings += $Service.Warnings
    }
    
    return $HealthResults
}

# Display health check results
function Show-HealthResults {
    param($Results)
    
    Write-Log ""
    Write-Log "=== HEALTH CHECK RESULTS ===" "INFO"
    Write-Log "Timestamp: $($Results.Timestamp)"
    Write-Log "Overall Status: $($Results.Overall.Status)"
    Write-Log "Health Score: $($Results.Overall.Score)%"
    Write-Log ""
    
    foreach ($ServiceKey in $Results.Services.Keys) {
        $Service = $Results.Services[$ServiceKey]
        $StatusColor = switch ($Service.OverallHealth) {
            "Healthy" { "SUCCESS" }
            "Warning" { "WARN" }
            "Critical" { "CRITICAL" }
            default { "INFO" }
        }
        
        Write-Log "🔹 $($Service.Name): $($Service.OverallHealth)" $StatusColor
        
        if ($Detailed) {
            if ($Service.Docker) {
                Write-Log "   Docker: $($Service.Docker.Status) - $($Service.Docker.Message)"
            }
            if ($Service.Http) {
                Write-Log "   HTTP: $($Service.Http.StatusCode) - $($Service.Http.Message)"
            }
            if ($Service.Resources -and $Service.Resources.CPU) {
                Write-Log "   CPU: $($Service.Resources.CPU.Percent)% | Memory: $($Service.Resources.Memory.Percent)%"
            }
        }
        
        if ($Service.Issues.Count -gt 0) {
            foreach ($Issue in $Service.Issues) {
                Write-Log "   ❌ $Issue" "ERROR"
            }
        }
    }
    
    if ($Results.Overall.Issues.Count -gt 0) {
        Write-Log ""
        Write-Log "Critical Issues Found:" "CRITICAL"
        foreach ($Issue in $Results.Overall.Issues) {
            Write-Log "❌ $Issue" "ERROR"
        }
        
        # Send alert if configured
        $AlertMessage = "Docker Travian Health Check Failed`n" +
                       "Status: $($Results.Overall.Status)`n" +
                       "Issues: $($Results.Overall.Issues.Count)`n" +
                       "Details: $($Results.Overall.Issues -join ', ')"
        
        Send-Alert -Message $AlertMessage -Level "CRITICAL"
    }
    
    Write-Log ""
}

# Main execution
try {
    do {
        $Results = Invoke-HealthCheck
        Show-HealthResults -Results $Results
        
        if ($Continuous) {
            Write-Log "Waiting $IntervalSeconds seconds for next check..."
            Start-Sleep -Seconds $IntervalSeconds
        }
    } while ($Continuous)
    
    Write-Log "Health check completed"
    Write-Log "Log file: $LogFile"
    
    # Exit with appropriate code
    $ExitCode = switch ($Results.Overall.Status) {
        "Healthy" { 0 }
        "Warning" { 1 }
        "Critical" { 2 }
        default { 3 }
    }
    
    exit $ExitCode
}
catch {
    Write-Log "Health check failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
