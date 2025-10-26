#!/bin/sh
# Docker Travian Application Entrypoint Script
# Handles container initialization, health checks, and graceful shutdown

set -e

# Configuration
APP_ENV=${APP_ENV:-production}
LOG_LEVEL=${LOG_LEVEL:-info}
MAX_STARTUP_TIME=${MAX_STARTUP_TIME:-60}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level=$1
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        ERROR)
            echo -e "${RED}[$timestamp] [ERROR] $message${NC}" >&2
            ;;
        WARN)
            echo -e "${YELLOW}[$timestamp] [WARN] $message${NC}" >&2
            ;;
        INFO)
            echo -e "${GREEN}[$timestamp] [INFO] $message${NC}"
            ;;
        DEBUG)
            if [ "$LOG_LEVEL" = "debug" ]; then
                echo -e "${BLUE}[$timestamp] [DEBUG] $message${NC}"
            fi
            ;;
    esac
}

# Error handling
handle_error() {
    local exit_code=$?
    log ERROR "Container startup failed with exit code $exit_code"
    log ERROR "Check logs for more details: docker logs <container_name>"
    exit $exit_code
}

trap handle_error ERR

# Signal handling for graceful shutdown
shutdown_handler() {
    log INFO "Received shutdown signal, initiating graceful shutdown..."
    
    # Stop supervisor and all processes
    if [ -f /var/run/supervisord.pid ]; then
        supervisorctl shutdown
        log INFO "Supervisor stopped"
    fi
    
    # Stop nginx gracefully
    if [ -f /run/nginx/nginx.pid ]; then
        nginx -s quit
        log INFO "Nginx stopped"
    fi
    
    # Stop PHP-FPM gracefully
    if [ -f /run/php/php-fpm.pid ]; then
        kill -QUIT $(cat /run/php/php-fpm.pid)
        log INFO "PHP-FPM stopped"
    fi
    
    log INFO "Graceful shutdown completed"
    exit 0
}

trap shutdown_handler SIGTERM SIGINT

# Validate environment
validate_environment() {
    log INFO "Validating environment configuration..."
    
    # Required environment variables
    local required_vars="DB_HOST DB_DATABASE DB_USERNAME DB_PASSWORD"
    local missing_vars=""
    
    for var in $required_vars; do
        if [ -z "$(eval echo \$$var)" ]; then
            missing_vars="$missing_vars $var"
        fi
    done
    
    if [ -n "$missing_vars" ]; then
        log ERROR "Missing required environment variables:$missing_vars"
        log ERROR "Please check your .env file or Docker environment configuration"
        exit 1
    fi
    
    # Validate database connection
    log INFO "Testing database connection..."
    if ! mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1" "$DB_DATABASE" >/dev/null 2>&1; then
        log ERROR "Cannot connect to database. Please check your database configuration"
        exit 1
    fi
    
    # Validate Redis connection (if configured)
    if [ -n "$REDIS_HOST" ]; then
        log INFO "Testing Redis connection..."
        if ! redis-cli -h "$REDIS_HOST" -p "${REDIS_PORT:-6379}" ping >/dev/null 2>&1; then
            log WARN "Cannot connect to Redis. Caching will be disabled"
        else
            log INFO "Redis connection successful"
        fi
    fi
    
    log INFO "Environment validation completed"
}

# Setup application
setup_application() {
    log INFO "Setting up application..."
    
    # Create necessary directories
    mkdir -p \
        /var/www/html/var/cache \
        /var/www/html/var/sessions \
        /var/www/html/var/uploads \
        /var/www/html/logs \
        /var/log/nginx \
        /var/log/php
    
    # Set proper permissions
    chmod -R 755 /var/www/html/var
    chmod -R 755 /var/www/html/logs
    
    # Clear cache if in development mode
    if [ "$APP_ENV" = "development" ]; then
        log INFO "Development mode: Clearing application cache..."
        rm -rf /var/www/html/var/cache/*
    fi
    
    # Run database migrations if needed
    if [ "$APP_ENV" != "production" ] || [ "$RUN_MIGRATIONS" = "true" ]; then
        log INFO "Running database migrations..."
        # Add migration command here when available
        # php bin/console doctrine:migrations:migrate --no-interaction
    fi
    
    # Warm up cache
    log INFO "Warming up application cache..."
    # Add cache warmup command here when available
    # php bin/console cache:warmup
    
    log INFO "Application setup completed"
}

# Wait for dependencies
wait_for_dependencies() {
    log INFO "Waiting for dependencies to be ready..."
    
    local max_attempts=30
    local attempt=0
    
    # Wait for database
    while [ $attempt -lt $max_attempts ]; do
        if mysql -h"$DB_HOST" -u"$DB_USERNAME" -p"$DB_PASSWORD" -e "SELECT 1" "$DB_DATABASE" >/dev/null 2>&1; then
            log INFO "Database is ready"
            break
        fi
        
        attempt=$((attempt + 1))
        log INFO "Waiting for database... (attempt $attempt/$max_attempts)"
        sleep 2
    done
    
    if [ $attempt -eq $max_attempts ]; then
        log ERROR "Database is not ready after $max_attempts attempts"
        exit 1
    fi
    
    # Wait for Redis (if configured)
    if [ -n "$REDIS_HOST" ]; then
        attempt=0
        while [ $attempt -lt $max_attempts ]; do
            if redis-cli -h "$REDIS_HOST" -p "${REDIS_PORT:-6379}" ping >/dev/null 2>&1; then
                log INFO "Redis is ready"
                break
            fi
            
            attempt=$((attempt + 1))
            log INFO "Waiting for Redis... (attempt $attempt/$max_attempts)"
            sleep 2
        done
        
        if [ $attempt -eq $max_attempts ]; then
            log WARN "Redis is not ready after $max_attempts attempts, continuing without cache"
        fi
    fi
}

# Health check endpoint
setup_health_check() {
    log INFO "Setting up health check endpoint..."
    
    cat > /var/www/html/health <<'EOF'
<?php
// Health check endpoint
header('Content-Type: application/json');

$health = [
    'status' => 'healthy',
    'timestamp' => date('c'),
    'version' => '1.0.0',
    'checks' => []
];

// Database check
try {
    $pdo = new PDO(
        "mysql:host={$_ENV['DB_HOST']};dbname={$_ENV['DB_DATABASE']}",
        $_ENV['DB_USERNAME'],
        $_ENV['DB_PASSWORD']
    );
    $pdo->query('SELECT 1');
    $health['checks']['database'] = 'healthy';
} catch (Exception $e) {
    $health['checks']['database'] = 'unhealthy';
    $health['status'] = 'unhealthy';
}

// Redis check (if configured)
if (!empty($_ENV['REDIS_HOST'])) {
    try {
        $redis = new Redis();
        $redis->connect($_ENV['REDIS_HOST'], $_ENV['REDIS_PORT'] ?? 6379);
        $redis->ping();
        $health['checks']['redis'] = 'healthy';
    } catch (Exception $e) {
        $health['checks']['redis'] = 'unhealthy';
        // Redis is optional, don't mark as unhealthy
    }
}

// Disk space check
$diskFree = disk_free_space('/var/www/html');
$diskTotal = disk_total_space('/var/www/html');
$diskUsage = (($diskTotal - $diskFree) / $diskTotal) * 100;

if ($diskUsage > 90) {
    $health['checks']['disk'] = 'critical';
    $health['status'] = 'unhealthy';
} elseif ($diskUsage > 80) {
    $health['checks']['disk'] = 'warning';
} else {
    $health['checks']['disk'] = 'healthy';
}

// Memory check
$memoryUsage = memory_get_usage(true);
$memoryLimit = ini_get('memory_limit');
$memoryLimitBytes = return_bytes($memoryLimit);
$memoryUsagePercent = ($memoryUsage / $memoryLimitBytes) * 100;

if ($memoryUsagePercent > 90) {
    $health['checks']['memory'] = 'critical';
    $health['status'] = 'unhealthy';
} elseif ($memoryUsagePercent > 80) {
    $health['checks']['memory'] = 'warning';
} else {
    $health['checks']['memory'] = 'healthy';
}

function return_bytes($val) {
    $val = trim($val);
    $last = strtolower($val[strlen($val)-1]);
    $val = (int)$val;
    switch($last) {
        case 'g': $val *= 1024;
        case 'm': $val *= 1024;
        case 'k': $val *= 1024;
    }
    return $val;
}

http_response_code($health['status'] === 'healthy' ? 200 : 503);
echo json_encode($health, JSON_PRETTY_PRINT);
EOF
    
    chmod 644 /var/www/html/health
    log INFO "Health check endpoint created at /health"
}

# Main execution
main() {
    log INFO "Starting Docker Travian container..."
    log INFO "Environment: $APP_ENV"
    log INFO "Log Level: $LOG_LEVEL"
    
    # Wait for dependencies
    wait_for_dependencies
    
    # Validate environment
    validate_environment
    
    # Setup application
    setup_application
    
    # Setup health check
    setup_health_check
    
    log INFO "Container initialization completed successfully"
    log INFO "Starting application services..."
    
    # Execute the main command
    exec "$@"
}

# Run main function
main "$@"
