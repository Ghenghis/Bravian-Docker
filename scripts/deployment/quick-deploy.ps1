# Docker Travian Quick Deployment Script
# One-command deployment for enterprise-grade game server

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "development",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipTests = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Production = $false
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$LogFile = Join-Path $ProjectRoot "logs\deployment-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

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
        default { Write-Host $LogEntry }
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

# Error handling
trap {
    Write-Log "DEPLOYMENT FAILED: $($_.Exception.Message)" "ERROR"
    Write-Log "Check log file: $LogFile" "ERROR"
    exit 1
}

Write-Log "Starting Docker Travian deployment..."
Write-Log "Environment: $Environment"
Write-Log "Production Mode: $Production"
Write-Log "Skip Tests: $SkipTests"

# Validate environment
function Test-Prerequisites {
    Write-Log "Checking deployment prerequisites..."
    
    $MissingTools = @()
    
    # Check Docker
    try {
        $DockerVersion = docker --version
        Write-Log "Docker found: $DockerVersion"
    }
    catch {
        $MissingTools += "Docker Desktop"
    }
    
    # Check Docker Compose
    try {
        $ComposeVersion = docker-compose --version
        Write-Log "Docker Compose found: $ComposeVersion"
    }
    catch {
        $MissingTools += "Docker Compose"
    }
    
    # Check Git
    try {
        $GitVersion = git --version
        Write-Log "Git found: $GitVersion"
    }
    catch {
        $MissingTools += "Git"
    }
    
    if ($MissingTools.Count -gt 0) {
        Write-Log "Missing required tools: $($MissingTools -join ', ')" "ERROR"
        throw "Prerequisites not met"
    }
    
    Write-Log "All prerequisites satisfied" "SUCCESS"
}

# Check if Docker is running
function Test-DockerService {
    Write-Log "Checking Docker service status..."
    
    try {
        docker info | Out-Null
        Write-Log "Docker service is running" "SUCCESS"
    }
    catch {
        Write-Log "Docker service is not running. Please start Docker Desktop." "ERROR"
        throw "Docker service unavailable"
    }
}

# Validate project structure
function Test-ProjectStructure {
    Write-Log "Validating project structure..."
    
    $RequiredFiles = @(
        "docker-compose.yml",
        ".env.example",
        "Makefile"
    )
    
    $MissingFiles = @()
    
    foreach ($File in $RequiredFiles) {
        $FilePath = Join-Path $ProjectRoot $File
        if (-not (Test-Path $FilePath)) {
            $MissingFiles += $File
        }
    }
    
    if ($MissingFiles.Count -gt 0) {
        Write-Log "Missing required files: $($MissingFiles -join ', ')" "ERROR"
        throw "Project structure incomplete"
    }
    
    Write-Log "Project structure validated" "SUCCESS"
}

# Setup environment file
function Initialize-Environment {
    Write-Log "Setting up environment configuration..."
    
    $EnvExample = Join-Path $ProjectRoot ".env.example"
    $EnvFile = Join-Path $ProjectRoot ".env"
    
    if (-not (Test-Path $EnvFile)) {
        if (Test-Path $EnvExample) {
            Copy-Item $EnvExample $EnvFile
            Write-Log "Created .env file from .env.example"
        }
        else {
            Write-Log ".env.example not found, creating basic .env file"
            $BasicEnv = @"
# Docker Travian Environment Configuration
APP_ENV=$Environment
APP_DEBUG=true
APP_URL=http://localhost:8080

# Database Configuration
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=travian
DB_USERNAME=travian
DB_PASSWORD=travian123

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379

# Mail Configuration
MAIL_MAILER=smtp
MAIL_HOST=mailhog
MAIL_PORT=1025
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null

# Security
APP_KEY=base64:$(([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).ToString()))))
"@
            Set-Content -Path $EnvFile -Value $BasicEnv
            Write-Log "Created basic .env file"
        }
    }
    else {
        Write-Log ".env file already exists"
    }
    
    # Update environment for production
    if ($Production) {
        Write-Log "Configuring for production environment..."
        $EnvContent = Get-Content $EnvFile
        $EnvContent = $EnvContent -replace "APP_ENV=.*", "APP_ENV=production"
        $EnvContent = $EnvContent -replace "APP_DEBUG=.*", "APP_DEBUG=false"
        Set-Content -Path $EnvFile -Value $EnvContent
        Write-Log "Environment configured for production"
    }
}

# Run quality checks
function Invoke-QualityChecks {
    if ($SkipTests) {
        Write-Log "Skipping quality checks as requested"
        return
    }
    
    Write-Log "Running quality checks..."
    
    $QualityScript = Join-Path $ProjectRoot "scripts\quality\quality-gate.ps1"
    
    if (Test-Path $QualityScript) {
        try {
            & $QualityScript
            Write-Log "Quality checks passed" "SUCCESS"
        }
        catch {
            if ($Force) {
                Write-Log "Quality checks failed but continuing due to -Force flag" "WARN"
            }
            else {
                Write-Log "Quality checks failed. Use -Force to override or fix issues first." "ERROR"
                throw "Quality gate failed"
            }
        }
    }
    else {
        Write-Log "Quality gate script not found, skipping quality checks" "WARN"
    }
}

# Build and start containers
function Start-DockerServices {
    Write-Log "Building and starting Docker services..."
    
    # Stop existing containers
    Write-Log "Stopping existing containers..."
    docker-compose down 2>$null
    
    # Build images
    Write-Log "Building Docker images..."
    docker-compose build --no-cache
    
    if ($LASTEXITCODE -ne 0) {
        throw "Docker build failed"
    }
    
    # Start services
    Write-Log "Starting Docker services..."
    docker-compose up -d
    
    if ($LASTEXITCODE -ne 0) {
        throw "Docker services failed to start"
    }
    
    Write-Log "Docker services started successfully" "SUCCESS"
}

# Wait for services to be ready
function Wait-ForServices {
    Write-Log "Waiting for services to be ready..."
    
    $MaxAttempts = 30
    $Attempt = 0
    
    while ($Attempt -lt $MaxAttempts) {
        try {
            # Check if web server is responding
            $Response = Invoke-WebRequest -Uri "http://localhost:8080/health" -TimeoutSec 5 -UseBasicParsing
            if ($Response.StatusCode -eq 200) {
                Write-Log "Application is ready!" "SUCCESS"
                return
            }
        }
        catch {
            # Service not ready yet
        }
        
        $Attempt++
        Write-Log "Waiting for services... (attempt $Attempt/$MaxAttempts)"
        Start-Sleep -Seconds 5
    }
    
    Write-Log "Services did not become ready within expected time" "WARN"
    Write-Log "Check service logs: docker-compose logs" "WARN"
}

# Run database migrations
function Invoke-DatabaseMigrations {
    Write-Log "Running database migrations..."
    
    try {
        # Wait a bit more for database to be fully ready
        Start-Sleep -Seconds 10
        
        # Check if migration script exists
        $MigrationScript = Join-Path $ProjectRoot "scripts\database\migrate.sql"
        
        if (Test-Path $MigrationScript) {
            docker-compose exec -T mysql mysql -u travian -ptravian123 travian < $MigrationScript
            Write-Log "Database migrations completed" "SUCCESS"
        }
        else {
            Write-Log "No migration script found, skipping migrations" "WARN"
        }
    }
    catch {
        Write-Log "Database migration failed: $($_.Exception.Message)" "WARN"
        Write-Log "You may need to run migrations manually" "WARN"
    }
}

# Display deployment summary
function Show-DeploymentSummary {
    Write-Log "Deployment completed successfully!" "SUCCESS"
    Write-Log ""
    Write-Log "=== DEPLOYMENT SUMMARY ==="
    Write-Log "Environment: $Environment"
    Write-Log "Application URL: http://localhost:8080"
    Write-Log "phpMyAdmin: http://localhost:8081"
    Write-Log "Grafana Dashboard: http://localhost:3000 (admin/admin123)"
    Write-Log "Prometheus Metrics: http://localhost:9090"
    Write-Log ""
    Write-Log "=== USEFUL COMMANDS ==="
    Write-Log "View logs: docker-compose logs -f"
    Write-Log "Stop services: docker-compose down"
    Write-Log "Restart services: docker-compose restart"
    Write-Log "Shell access: docker-compose exec app /bin/bash"
    Write-Log ""
    Write-Log "=== SERVICE STATUS ==="
    docker-compose ps
    Write-Log ""
    Write-Log "Deployment log saved to: $LogFile"
}

# Main execution
try {
    # Pre-deployment checks
    Test-Prerequisites
    Test-DockerService
    Test-ProjectStructure
    
    # Environment setup
    Initialize-Environment
    
    # Quality checks
    Invoke-QualityChecks
    
    # Docker deployment
    Start-DockerServices
    
    # Post-deployment setup
    Wait-ForServices
    Invoke-DatabaseMigrations
    
    # Summary
    Show-DeploymentSummary
    
    Write-Log "Docker Travian deployment completed successfully!" "SUCCESS"
    exit 0
}
catch {
    Write-Log "Deployment failed: $($_.Exception.Message)" "ERROR"
    Write-Log "Check the deployment log for details: $LogFile" "ERROR"
    
    # Show container status for debugging
    Write-Log "Container status:" "ERROR"
    docker-compose ps
    
    exit 1
}
