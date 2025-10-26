# Docker Travian Project Setup Script
# Automated setup for enterprise-grade development environment

param(
    [Parameter(Mandatory=$false)]
    [string]$Environment = "development",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDocker = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDependencies = $false
)

# Script configuration
$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$LogFile = Join-Path $ProjectRoot "logs\setup-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

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
    Write-Host $LogEntry
    Add-Content -Path $LogFile -Value $LogEntry
}

# Error handling
trap {
    Write-Log "FATAL ERROR: $($_.Exception.Message)" "ERROR"
    Write-Log "Setup failed. Check log file: $LogFile" "ERROR"
    exit 1
}

Write-Log "Starting Docker Travian project setup..."
Write-Log "Environment: $Environment"
Write-Log "Project Root: $ProjectRoot"

# Create essential directories
Write-Log "Creating project directory structure..."
$Directories = @(
    "src\App\Controllers",
    "src\App\Middleware", 
    "src\App\Services",
    "src\App\Repositories",
    "src\Domain\Entities",
    "src\Domain\ValueObjects",
    "src\Domain\Services",
    "src\Infrastructure\Database",
    "src\Infrastructure\Cache",
    "src\Infrastructure\External",
    "src\Shared\Utils",
    "src\Shared\Exceptions",
    "tests\Unit",
    "tests\Integration", 
    "tests\Feature",
    "tests\Performance",
    "docker\app",
    "docker\nginx",
    "docker\mysql",
    "docker\monitoring",
    "config",
    "scripts\deployment",
    "scripts\maintenance",
    "docs\api",
    "docs\architecture",
    "docs\deployment",
    "docs\development",
    "docs\operations",
    "tools\analysis",
    "tools\migration",
    "logs\php",
    "logs\nginx",
    "logs\mysql",
    "logs\application",
    "var\cache",
    "var\sessions",
    "var\uploads"
)

foreach ($Dir in $Directories) {
    $FullPath = Join-Path $ProjectRoot $Dir
    if (-not (Test-Path $FullPath)) {
        New-Item -ItemType Directory -Path $FullPath -Force | Out-Null
        Write-Log "Created directory: $Dir"
    }
}

# Copy environment file
Write-Log "Setting up environment configuration..."
$EnvExample = Join-Path $ProjectRoot ".env.example"
$EnvFile = Join-Path $ProjectRoot ".env"

if ((Test-Path $EnvExample) -and (-not (Test-Path $EnvFile))) {
    Copy-Item $EnvExample $EnvFile
    Write-Log "Created .env file from .env.example"
}

# Check Docker installation
if (-not $SkipDocker) {
    Write-Log "Checking Docker installation..."
    try {
        $DockerVersion = docker --version
        Write-Log "Docker found: $DockerVersion"
        
        $ComposeVersion = docker-compose --version
        Write-Log "Docker Compose found: $ComposeVersion"
    }
    catch {
        Write-Log "Docker or Docker Compose not found. Please install Docker Desktop." "ERROR"
        throw "Docker installation required"
    }
}

# Check PHP installation (for local development)
if (-not $SkipDependencies) {
    Write-Log "Checking PHP installation..."
    try {
        $PhpVersion = php --version
        Write-Log "PHP found: $($PhpVersion.Split("`n")[0])"
    }
    catch {
        Write-Log "PHP not found. Installing via Chocolatey..." "WARN"
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            choco install php -y
            Write-Log "PHP installed via Chocolatey"
        } else {
            Write-Log "Chocolatey not found. Please install PHP manually." "WARN"
        }
    }
    
    # Check Composer
    Write-Log "Checking Composer installation..."
    try {
        $ComposerVersion = composer --version
        Write-Log "Composer found: $ComposerVersion"
    }
    catch {
        Write-Log "Composer not found. Please install Composer." "WARN"
    }
}

# Create .gitignore if it doesn't exist
Write-Log "Setting up .gitignore..."
$GitIgnorePath = Join-Path $ProjectRoot ".gitignore"
if (-not (Test-Path $GitIgnorePath)) {
    $GitIgnoreContent = @"
# Environment files
.env
.env.local
.env.*.local

# Dependencies
/vendor/
/node_modules/

# Logs
/logs/*.log
/var/log/

# Cache
/var/cache/
/var/sessions/

# Uploads
/var/uploads/

# IDE files
.vscode/
.idea/
*.swp
*.swo

# OS files
.DS_Store
Thumbs.db

# Docker
docker-compose.override.yml

# Testing
/coverage/
.phpunit.result.cache

# Build artifacts
/build/
/dist/

# Temporary files
*.tmp
*.temp
"@
    Set-Content -Path $GitIgnorePath -Value $GitIgnoreContent
    Write-Log "Created .gitignore file"
}

# Create composer.json if it doesn't exist
Write-Log "Setting up Composer configuration..."
$ComposerPath = Join-Path $ProjectRoot "composer.json"
if (-not (Test-Path $ComposerPath)) {
    $ComposerContent = @"
{
    "name": "ghenghis/docker-travian",
    "description": "Enterprise-grade containerized Travian game server",
    "type": "project",
    "license": "MIT",
    "authors": [
        {
            "name": "Docker Travian Team",
            "email": "devops@docker-travian.game"
        }
    ],
    "require": {
        "php": "^8.2",
        "ext-pdo": "*",
        "ext-json": "*",
        "ext-mbstring": "*",
        "monolog/monolog": "^3.0",
        "vlucas/phpdotenv": "^5.5",
        "symfony/http-foundation": "^6.0",
        "symfony/routing": "^6.0",
        "doctrine/dbal": "^3.0",
        "predis/predis": "^2.0"
    },
    "require-dev": {
        "phpunit/phpunit": "^10.0",
        "phpstan/phpstan": "^1.0",
        "squizlabs/php_codesniffer": "^3.7",
        "phpmd/phpmd": "^2.13",
        "psalm/plugin-symfony": "^5.0",
        "symfony/var-dumper": "^6.0"
    },
    "autoload": {
        "psr-4": {
            "DockerTravian\\": "src/"
        }
    },
    "autoload-dev": {
        "psr-4": {
            "DockerTravian\\Tests\\": "tests/"
        }
    },
    "scripts": {
        "test": "phpunit",
        "test-coverage": "phpunit --coverage-html coverage",
        "phpstan": "phpstan analyse src tests --level=9",
        "phpcs": "phpcs src tests --standard=PSR12",
        "phpmd": "phpmd src,tests text cleancode,codesize,controversial,design,naming,unusedcode",
        "quality": [
            "@phpcs",
            "@phpstan", 
            "@phpmd"
        ]
    },
    "config": {
        "optimize-autoloader": true,
        "sort-packages": true
    },
    "minimum-stability": "stable",
    "prefer-stable": true
}
"@
    Set-Content -Path $ComposerPath -Value $ComposerContent
    Write-Log "Created composer.json file"
}

# Create package.json for frontend dependencies
Write-Log "Setting up Node.js configuration..."
$PackagePath = Join-Path $ProjectRoot "package.json"
if (-not (Test-Path $PackagePath)) {
    $PackageContent = @"
{
  "name": "docker-travian",
  "version": "1.0.0",
  "description": "Enterprise-grade containerized Travian game server",
  "main": "index.js",
  "scripts": {
    "dev": "webpack serve --mode development",
    "build": "webpack --mode production",
    "test": "jest",
    "lint": "eslint src/js/**/*.js",
    "lint:fix": "eslint src/js/**/*.js --fix"
  },
  "repository": {
    "type": "git",
    "url": "https://github.com/ghenghis/docker-travian.git"
  },
  "keywords": [
    "travian",
    "game",
    "docker",
    "php",
    "browser-game"
  ],
  "author": "Docker Travian Team",
  "license": "MIT",
  "devDependencies": {
    "webpack": "^5.88.0",
    "webpack-cli": "^5.1.0",
    "webpack-dev-server": "^4.15.0",
    "babel-loader": "^9.1.0",
    "@babel/core": "^7.22.0",
    "@babel/preset-env": "^7.22.0",
    "css-loader": "^6.8.0",
    "style-loader": "^3.3.0",
    "eslint": "^8.44.0",
    "jest": "^29.6.0"
  },
  "dependencies": {
    "axios": "^1.4.0",
    "bootstrap": "^5.3.0"
  }
}
"@
    Set-Content -Path $PackagePath -Value $PackageContent
    Write-Log "Created package.json file"
}

# Create phpunit.xml configuration
Write-Log "Setting up PHPUnit configuration..."
$PhpUnitPath = Join-Path $ProjectRoot "phpunit.xml"
if (-not (Test-Path $PhpUnitPath)) {
    $PhpUnitContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<phpunit xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:noNamespaceSchemaLocation="vendor/phpunit/phpunit/phpunit.xsd"
         bootstrap="vendor/autoload.php"
         colors="true"
         failOnRisky="true"
         failOnWarning="true"
         stopOnFailure="false"
         executionOrder="random"
         resolveDependencies="true">
    <testsuites>
        <testsuite name="Unit">
            <directory suffix="Test.php">./tests/Unit</directory>
        </testsuite>
        <testsuite name="Integration">
            <directory suffix="Test.php">./tests/Integration</directory>
        </testsuite>
        <testsuite name="Feature">
            <directory suffix="Test.php">./tests/Feature</directory>
        </testsuite>
    </testsuites>
    <coverage>
        <include>
            <directory suffix=".php">./src</directory>
        </include>
        <exclude>
            <directory>./src/Shared/Exceptions</directory>
        </exclude>
        <report>
            <html outputDirectory="coverage"/>
            <text outputFile="coverage.txt"/>
        </report>
    </coverage>
    <php>
        <env name="APP_ENV" value="testing"/>
        <env name="DB_CONNECTION" value="sqlite"/>
        <env name="DB_DATABASE" value=":memory:"/>
    </php>
</phpunit>
"@
    Set-Content -Path $PhpUnitPath -Value $PhpUnitContent
    Write-Log "Created phpunit.xml file"
}

# Set up file permissions (Windows)
Write-Log "Setting up file permissions..."
$LogsPath = Join-Path $ProjectRoot "logs"
$VarPath = Join-Path $ProjectRoot "var"

if (Test-Path $LogsPath) {
    icacls $LogsPath /grant "Everyone:(OI)(CI)F" /T | Out-Null
    Write-Log "Set permissions for logs directory"
}

if (Test-Path $VarPath) {
    icacls $VarPath /grant "Everyone:(OI)(CI)F" /T | Out-Null
    Write-Log "Set permissions for var directory"
}

# Final setup steps
Write-Log "Project setup completed successfully!"
Write-Log "Next steps:"
Write-Log "1. Review and update .env file with your configuration"
Write-Log "2. Run 'composer install' to install PHP dependencies"
Write-Log "3. Run 'npm install' to install Node.js dependencies"
Write-Log "4. Run 'docker-compose up -d' to start the development environment"
Write-Log "5. Visit http://localhost:8080 to access the application"

Write-Log "Setup log saved to: $LogFile"
Write-Log "Setup completed at: $(Get-Date)"
