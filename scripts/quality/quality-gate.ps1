# Docker Travian Quality Gate Script
# Automated code quality checks and enforcement

param(
    [Parameter(Mandatory=$false)]
    [switch]$Fix = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Strict = $false,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFormat = "console"
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$LogFile = Join-Path $ProjectRoot "logs\quality-gate-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

# Quality thresholds
$QualityThresholds = @{
    CodeCoverage = 85
    CyclomaticComplexity = 10
    DuplicationPercentage = 2
    PHPStanLevel = 9
    MaxLinesPerMethod = 50
    MaxMethodsPerClass = 20
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
        default { Write-Host $LogEntry }
    }
    
    Add-Content -Path $LogFile -Value $LogEntry
}

# Quality check results
$QualityResults = @{
    Passed = @()
    Failed = @()
    Warnings = @()
    TotalScore = 0
}

Write-Log "Starting Docker Travian Quality Gate checks..."
Write-Log "Project Root: $ProjectRoot"
Write-Log "Fix Mode: $Fix"
Write-Log "Strict Mode: $Strict"

# Check if required tools are available
function Test-QualityTools {
    Write-Log "Checking quality tools availability..."
    
    $Tools = @{
        "composer" = "Composer (PHP dependency manager)"
        "vendor/bin/phpunit" = "PHPUnit (Testing framework)"
        "vendor/bin/phpstan" = "PHPStan (Static analysis)"
        "vendor/bin/phpcs" = "PHP_CodeSniffer (Code style)"
        "vendor/bin/phpmd" = "PHPMD (Mess detector)"
    }
    
    $MissingTools = @()
    
    foreach ($Tool in $Tools.Keys) {
        $ToolPath = Join-Path $ProjectRoot $Tool
        if ($Tool -eq "composer") {
            try {
                composer --version | Out-Null
                Write-Log "✓ $($Tools[$Tool]) - Available"
            }
            catch {
                $MissingTools += $Tools[$Tool]
                Write-Log "✗ $($Tools[$Tool]) - Missing" "ERROR"
            }
        }
        elseif (Test-Path $ToolPath) {
            Write-Log "✓ $($Tools[$Tool]) - Available"
        }
        else {
            $MissingTools += $Tools[$Tool]
            Write-Log "✗ $($Tools[$Tool]) - Missing" "ERROR"
        }
    }
    
    if ($MissingTools.Count -gt 0) {
        Write-Log "Missing tools detected. Run 'composer install' first." "ERROR"
        return $false
    }
    
    return $true
}

# PHP Code Style Check (PSR-12)
function Test-CodeStyle {
    Write-Log "Running PHP Code Style checks (PSR-12)..."
    
    $PhpcsPath = Join-Path $ProjectRoot "vendor\bin\phpcs"
    $SrcPath = Join-Path $ProjectRoot "src"
    $TestsPath = Join-Path $ProjectRoot "tests"
    
    if (-not (Test-Path $SrcPath)) {
        Write-Log "Source directory not found: $SrcPath" "WARN"
        return $true
    }
    
    try {
        if ($Fix) {
            Write-Log "Attempting to fix code style issues..."
            $PhpcbfPath = Join-Path $ProjectRoot "vendor\bin\phpcbf"
            & $PhpcbfPath $SrcPath --standard=PSR12 2>$null
            if (Test-Path $TestsPath) {
                & $PhpcbfPath $TestsPath --standard=PSR12 2>$null
            }
        }
        
        $StyleResult = & $PhpcsPath $SrcPath --standard=PSR12 --report=json 2>$null
        if (Test-Path $TestsPath) {
            $TestStyleResult = & $PhpcsPath $TestsPath --standard=PSR12 --report=json 2>$null
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Code style check passed" "SUCCESS"
            $QualityResults.Passed += "Code Style (PSR-12)"
            return $true
        }
        else {
            Write-Log "✗ Code style violations found" "ERROR"
            $QualityResults.Failed += "Code Style (PSR-12)"
            
            if ($OutputFormat -eq "detailed") {
                Write-Log "Style violations details:" "ERROR"
                Write-Log $StyleResult "ERROR"
            }
            
            return $false
        }
    }
    catch {
        Write-Log "Error running code style check: $($_.Exception.Message)" "ERROR"
        $QualityResults.Failed += "Code Style (PSR-12)"
        return $false
    }
}

# Static Analysis with PHPStan
function Test-StaticAnalysis {
    Write-Log "Running static analysis (PHPStan Level $($QualityThresholds.PHPStanLevel))..."
    
    $PhpstanPath = Join-Path $ProjectRoot "vendor\bin\phpstan"
    $SrcPath = Join-Path $ProjectRoot "src"
    
    if (-not (Test-Path $SrcPath)) {
        Write-Log "Source directory not found: $SrcPath" "WARN"
        return $true
    }
    
    try {
        $AnalysisResult = & $PhpstanPath analyse $SrcPath --level=$($QualityThresholds.PHPStanLevel) --error-format=json 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ Static analysis passed (Level $($QualityThresholds.PHPStanLevel))" "SUCCESS"
            $QualityResults.Passed += "Static Analysis (PHPStan)"
            return $true
        }
        else {
            Write-Log "✗ Static analysis failed" "ERROR"
            $QualityResults.Failed += "Static Analysis (PHPStan)"
            
            if ($OutputFormat -eq "detailed") {
                Write-Log "Static analysis errors:" "ERROR"
                Write-Log $AnalysisResult "ERROR"
            }
            
            return $false
        }
    }
    catch {
        Write-Log "Error running static analysis: $($_.Exception.Message)" "ERROR"
        $QualityResults.Failed += "Static Analysis (PHPStan)"
        return $false
    }
}

# Mess Detection with PHPMD
function Test-MessDetection {
    Write-Log "Running mess detection (PHPMD)..."
    
    $PhpmdPath = Join-Path $ProjectRoot "vendor\bin\phpmd"
    $SrcPath = Join-Path $ProjectRoot "src"
    
    if (-not (Test-Path $SrcPath)) {
        Write-Log "Source directory not found: $SrcPath" "WARN"
        return $true
    }
    
    try {
        $Rules = "cleancode,codesize,controversial,design,naming,unusedcode"
        $MessResult = & $PhpmdPath $SrcPath json $Rules 2>$null
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 2) {
            if ($MessResult -and $MessResult.Trim() -ne "") {
                $MessData = $MessResult | ConvertFrom-Json
                $ViolationCount = $MessData.violations.Count
                
                if ($ViolationCount -eq 0) {
                    Write-Log "✓ Mess detection passed (0 violations)" "SUCCESS"
                    $QualityResults.Passed += "Mess Detection (PHPMD)"
                    return $true
                }
                elseif ($ViolationCount -le 5) {
                    Write-Log "⚠ Mess detection passed with warnings ($ViolationCount violations)" "WARN"
                    $QualityResults.Warnings += "Mess Detection (PHPMD) - $ViolationCount violations"
                    return $true
                }
                else {
                    Write-Log "✗ Mess detection failed ($ViolationCount violations)" "ERROR"
                    $QualityResults.Failed += "Mess Detection (PHPMD)"
                    return $false
                }
            }
            else {
                Write-Log "✓ Mess detection passed (0 violations)" "SUCCESS"
                $QualityResults.Passed += "Mess Detection (PHPMD)"
                return $true
            }
        }
        else {
            Write-Log "✗ Mess detection failed" "ERROR"
            $QualityResults.Failed += "Mess Detection (PHPMD)"
            return $false
        }
    }
    catch {
        Write-Log "Error running mess detection: $($_.Exception.Message)" "ERROR"
        $QualityResults.Failed += "Mess Detection (PHPMD)"
        return $false
    }
}

# Unit Tests with Coverage
function Test-UnitTests {
    Write-Log "Running unit tests with coverage..."
    
    $PhpunitPath = Join-Path $ProjectRoot "vendor\bin\phpunit"
    $TestsPath = Join-Path $ProjectRoot "tests"
    
    if (-not (Test-Path $TestsPath)) {
        Write-Log "Tests directory not found: $TestsPath" "WARN"
        $QualityResults.Warnings += "Unit Tests - No tests found"
        return $true
    }
    
    try {
        $TestResult = & $PhpunitPath --coverage-text --coverage-clover=coverage.xml 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            # Extract coverage percentage
            $CoverageMatch = $TestResult | Select-String "Lines:\s+(\d+\.\d+)%"
            if ($CoverageMatch) {
                $Coverage = [double]$CoverageMatch.Matches[0].Groups[1].Value
                
                if ($Coverage -ge $QualityThresholds.CodeCoverage) {
                    Write-Log "✓ Unit tests passed with $Coverage% coverage" "SUCCESS"
                    $QualityResults.Passed += "Unit Tests ($Coverage% coverage)"
                    return $true
                }
                else {
                    Write-Log "✗ Unit tests coverage below threshold: $Coverage% < $($QualityThresholds.CodeCoverage)%" "ERROR"
                    $QualityResults.Failed += "Unit Tests (Coverage: $Coverage%)"
                    return $false
                }
            }
            else {
                Write-Log "✓ Unit tests passed (coverage data not available)" "SUCCESS"
                $QualityResults.Passed += "Unit Tests"
                return $true
            }
        }
        else {
            Write-Log "✗ Unit tests failed" "ERROR"
            $QualityResults.Failed += "Unit Tests"
            
            if ($OutputFormat -eq "detailed") {
                Write-Log "Test failures:" "ERROR"
                Write-Log $TestResult "ERROR"
            }
            
            return $false
        }
    }
    catch {
        Write-Log "Error running unit tests: $($_.Exception.Message)" "ERROR"
        $QualityResults.Failed += "Unit Tests"
        return $false
    }
}

# Security Vulnerability Check
function Test-SecurityVulnerabilities {
    Write-Log "Checking for security vulnerabilities..."
    
    try {
        $SecurityResult = composer audit --format=json 2>$null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Log "✓ No security vulnerabilities found" "SUCCESS"
            $QualityResults.Passed += "Security Audit"
            return $true
        }
        else {
            if ($SecurityResult) {
                $SecurityData = $SecurityResult | ConvertFrom-Json
                $VulnCount = $SecurityData.advisories.Count
                
                if ($VulnCount -gt 0) {
                    Write-Log "✗ $VulnCount security vulnerabilities found" "ERROR"
                    $QualityResults.Failed += "Security Audit ($VulnCount vulnerabilities)"
                    return $false
                }
            }
            
            Write-Log "✓ Security audit completed" "SUCCESS"
            $QualityResults.Passed += "Security Audit"
            return $true
        }
    }
    catch {
        Write-Log "Error running security audit: $($_.Exception.Message)" "WARN"
        $QualityResults.Warnings += "Security Audit - Check failed"
        return $true
    }
}

# Docker Security Check
function Test-DockerSecurity {
    Write-Log "Checking Docker configuration security..."
    
    $DockerComposePath = Join-Path $ProjectRoot "docker-compose.yml"
    
    if (-not (Test-Path $DockerComposePath)) {
        Write-Log "Docker Compose file not found" "WARN"
        return $true
    }
    
    try {
        $DockerContent = Get-Content $DockerComposePath -Raw
        $SecurityIssues = @()
        
        # Check for hardcoded passwords
        if ($DockerContent -match "password.*=.*\w+") {
            $SecurityIssues += "Hardcoded passwords detected"
        }
        
        # Check for privileged containers
        if ($DockerContent -match "privileged:\s*true") {
            $SecurityIssues += "Privileged containers detected"
        }
        
        # Check for host network mode
        if ($DockerContent -match "network_mode:\s*host") {
            $SecurityIssues += "Host network mode detected"
        }
        
        if ($SecurityIssues.Count -eq 0) {
            Write-Log "✓ Docker security check passed" "SUCCESS"
            $QualityResults.Passed += "Docker Security"
            return $true
        }
        else {
            Write-Log "✗ Docker security issues found: $($SecurityIssues -join ', ')" "ERROR"
            $QualityResults.Failed += "Docker Security"
            return $false
        }
    }
    catch {
        Write-Log "Error checking Docker security: $($_.Exception.Message)" "WARN"
        $QualityResults.Warnings += "Docker Security - Check failed"
        return $true
    }
}

# Generate Quality Report
function Write-QualityReport {
    Write-Log "Generating quality report..."
    
    $TotalChecks = $QualityResults.Passed.Count + $QualityResults.Failed.Count + $QualityResults.Warnings.Count
    $PassedChecks = $QualityResults.Passed.Count
    $QualityScore = if ($TotalChecks -gt 0) { [math]::Round(($PassedChecks / $TotalChecks) * 100, 2) } else { 0 }
    
    Write-Log "=================================="
    Write-Log "QUALITY GATE REPORT"
    Write-Log "=================================="
    Write-Log "Total Checks: $TotalChecks"
    Write-Log "Passed: $($QualityResults.Passed.Count)" "SUCCESS"
    Write-Log "Failed: $($QualityResults.Failed.Count)" "ERROR"
    Write-Log "Warnings: $($QualityResults.Warnings.Count)" "WARN"
    Write-Log "Quality Score: $QualityScore%" $(if ($QualityScore -ge 80) { "SUCCESS" } elseif ($QualityScore -ge 60) { "WARN" } else { "ERROR" })
    
    if ($QualityResults.Passed.Count -gt 0) {
        Write-Log ""
        Write-Log "PASSED CHECKS:" "SUCCESS"
        foreach ($Check in $QualityResults.Passed) {
            Write-Log "  ✓ $Check" "SUCCESS"
        }
    }
    
    if ($QualityResults.Failed.Count -gt 0) {
        Write-Log ""
        Write-Log "FAILED CHECKS:" "ERROR"
        foreach ($Check in $QualityResults.Failed) {
            Write-Log "  ✗ $Check" "ERROR"
        }
    }
    
    if ($QualityResults.Warnings.Count -gt 0) {
        Write-Log ""
        Write-Log "WARNINGS:" "WARN"
        foreach ($Check in $QualityResults.Warnings) {
            Write-Log "  ⚠ $Check" "WARN"
        }
    }
    
    Write-Log ""
    Write-Log "Report saved to: $LogFile"
    
    return $QualityScore
}

# Main execution
try {
    if (-not (Test-QualityTools)) {
        Write-Log "Quality tools check failed. Exiting." "ERROR"
        exit 1
    }
    
    # Run all quality checks
    $Checks = @(
        { Test-CodeStyle },
        { Test-StaticAnalysis },
        { Test-MessDetection },
        { Test-UnitTests },
        { Test-SecurityVulnerabilities },
        { Test-DockerSecurity }
    )
    
    $AllPassed = $true
    
    foreach ($Check in $Checks) {
        if (-not (& $Check)) {
            $AllPassed = $false
        }
        Write-Log "---"
    }
    
    $QualityScore = Write-QualityReport
    
    # Determine exit code based on results
    if ($Strict) {
        if ($QualityResults.Failed.Count -gt 0 -or $QualityResults.Warnings.Count -gt 0) {
            Write-Log "Quality gate FAILED (Strict mode)" "ERROR"
            exit 1
        }
    }
    else {
        if ($QualityResults.Failed.Count -gt 0) {
            Write-Log "Quality gate FAILED" "ERROR"
            exit 1
        }
    }
    
    Write-Log "Quality gate PASSED" "SUCCESS"
    exit 0
}
catch {
    Write-Log "Quality gate execution failed: $($_.Exception.Message)" "ERROR"
    exit 1
}
