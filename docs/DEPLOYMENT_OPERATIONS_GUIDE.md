# Docker Travian Deployment & Operations Guide

## 🚀 Production Deployment Guide

This comprehensive guide covers deployment, configuration, monitoring, and maintenance of the Docker Travian enterprise platform.

## 📋 Pre-Deployment Checklist

### System Requirements
- **OS**: Ubuntu 20.04 LTS or newer / Windows Server 2019+ with WSL2
- **CPU**: 4+ cores (8+ recommended for production)
- **RAM**: 16GB minimum (32GB+ recommended)
- **Storage**: 100GB SSD minimum (500GB+ for production)
- **Network**: 1Gbps+ connection with static IP

### Required Software
- Docker Engine 20.10+
- Docker Compose 2.0+
- Git 2.30+
- SSL Certificate (Let's Encrypt recommended)

## 🔧 Environment Configuration

### 1. Clone and Setup Project
```bash
# Clone repository
git clone https://github.com/your-org/docker-travian.git
cd docker-travian

# Copy environment template
cp .env.example .env

# Generate secure passwords
SECURE_DB_PASSWORD=$(openssl rand -base64 32)
SECURE_RABBIT_PASSWORD=$(openssl rand -base64 32)
SECURE_GRAFANA_PASSWORD=$(openssl rand -base64 32)

# Update .env file
sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=${SECURE_DB_PASSWORD}/" .env
sed -i "s/RABBIT_PASSWORD=.*/RABBIT_PASSWORD=${SECURE_RABBIT_PASSWORD}/" .env
sed -i "s/GRAFANA_PASSWORD=.*/GRAFANA_PASSWORD=${SECURE_GRAFANA_PASSWORD}/" .env
```

### 2. Environment Variables Configuration

#### Production `.env` Configuration
```bash
# Application Environment
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-domain.com

# Database Configuration
DB_CONNECTION=mysql
DB_HOST=database
DB_PORT=3306
DB_DATABASE=travian
DB_USERNAME=travian
DB_PASSWORD=your_secure_password_here
DB_ROOT_PASSWORD=your_secure_root_password_here

# Redis Configuration
REDIS_HOST=redis
REDIS_PASSWORD=null
REDIS_PORT=6379

# RabbitMQ Configuration
RABBIT_HOST=rabbitmq
RABBIT_PORT=5672
RABBIT_USER=travian
RABBIT_PASSWORD=your_secure_rabbit_password_here

# Mail Configuration
MAIL_MAILER=smtp
MAIL_HOST=smtp.your-provider.com
MAIL_PORT=587
MAIL_USERNAME=your_email@domain.com
MAIL_PASSWORD=your_email_password
MAIL_ENCRYPTION=tls

# Monitoring Configuration
GRAFANA_PASSWORD=your_secure_grafana_password_here
PROMETHEUS_RETENTION=30d

# Security Configuration
SESSION_LIFETIME=120
HASH_DRIVER=bcrypt
BCRYPT_ROUNDS=12

# Performance Configuration
PHP_MEMORY_LIMIT=256M
PHP_MAX_EXECUTION_TIME=30
OPCACHE_ENABLE=1
REDIS_CACHE_TTL=3600
```

## 🐳 Docker Deployment Process

### 3. One-Command Production Deployment

#### For Linux/WSL2
```bash
#!/bin/bash
# Production deployment script

echo "🚀 Starting Docker Travian production deployment..."

# Pull latest images
docker-compose pull

# Build application container
docker-compose build --no-cache app

# Start core services
docker-compose up -d database redis rabbitmq

# Wait for database initialization
echo "⏳ Waiting for database to initialize..."
sleep 30

# Initialize database schema
docker-compose exec database mysql -u root -p${DB_ROOT_PASSWORD} -e "CREATE DATABASE IF NOT EXISTS ${DB_DATABASE};"
docker-compose exec database mysql -u root -p${DB_ROOT_PASSWORD} -e "GRANT ALL PRIVILEGES ON ${DB_DATABASE}.* TO '${DB_USERNAME}'@'%';"

# Import initial schema
docker-compose exec -T database mysql -u ${DB_USERNAME} -p${DB_PASSWORD} ${DB_DATABASE} < database/schema.sql

# Start application services
docker-compose up -d app nginx

# Start monitoring services
docker-compose up -d prometheus grafana

# Start management services
docker-compose up -d phpmyadmin mailhog

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 20

# Run health checks
echo "🔍 Running health checks..."
./scripts/monitoring/health-check.ps1

echo "✅ Deployment completed successfully!"
echo "🎮 Game Server: https://your-domain.com"
echo "📊 Monitoring: https://your-domain.com:3000"
echo "📈 Metrics: https://your-domain.com:9090"
```

#### For Windows PowerShell
```powershell
# quick-deploy.ps1
Write-Host "🚀 Starting Docker Travian production deployment..." -ForegroundColor Green

# Pull latest images
docker-compose pull

# Build application container
docker-compose build --no-cache app

# Start services in order
docker-compose up -d database redis rabbitmq
Start-Sleep -Seconds 30

# Initialize database
$env:DB_ROOT_PASSWORD = (Get-Content .env | Select-String "DB_ROOT_PASSWORD" | ForEach-Object { $_.ToString().Split('=')[1] })
$env:DB_PASSWORD = (Get-Content .env | Select-String "DB_PASSWORD" | ForEach-Object { $_.ToString().Split('=')[1] })
$env:DB_DATABASE = (Get-Content .env | Select-String "DB_DATABASE" | ForEach-Object { $_.ToString().Split('=')[1] })
$env:DB_USERNAME = (Get-Content .env | Select-String "DB_USERNAME" | ForEach-Object { $_.ToString().Split('=')[1] })

docker-compose exec database mysql -u root -p$env:DB_ROOT_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $env:DB_DATABASE;"

# Start remaining services
docker-compose up -d

Write-Host "✅ Deployment completed!" -ForegroundColor Green
Write-Host "🎮 Access your game at: http://localhost:8080" -ForegroundColor Cyan
```

## 🔍 Service Configuration Details

### 4. NGINX Production Configuration

#### `/docker/nginx/nginx.conf`
```nginx
user nginx;
worker_processes auto;
pid /var/run/nginx.pid;

events {
    worker_connections 2048;
    use epoll;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";

    # Performance settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 20M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;

    # Rate limiting
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=10r/s;

    # Upstream configuration
    upstream php-fpm {
        server app:9000;
        keepalive 32;
    }

    server {
        listen 80;
        server_name _;
        root /var/www/html/public;
        index index.php index.html;

        # Security
        location ~ /\. {
            deny all;
        }

        # Static files
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }

        # Rate limiting for sensitive endpoints
        location /login {
            limit_req zone=login burst=3 nodelay;
            try_files $uri $uri/ /index.php?$query_string;
        }

        location /api/ {
            limit_req zone=api burst=20 nodelay;
            try_files $uri $uri/ /index.php?$query_string;
        }

        # PHP processing
        location ~ \.php$ {
            try_files $uri =404;
            fastcgi_split_path_info ^(.+\.php)(/.+)$;
            fastcgi_pass php-fpm;
            fastcgi_index index.php;
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_param PATH_INFO $fastcgi_path_info;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Deny access to sensitive files
        location ~ /config {
            deny all;
        }
    }
}
```

### 5. Database Configuration

#### MariaDB Optimization (`docker/mariadb/mariadb.cnf`)
```ini
[mysql]
default-character-set = utf8mb4

[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# Performance settings
innodb_buffer_pool_size = 2G
innodb_log_file_size = 256M
innodb_log_buffer_size = 64M
innodb_flush_log_at_trx_commit = 2
innodb_file_per_table = 1

# Connection settings
max_connections = 200
max_connect_errors = 10000
wait_timeout = 600
interactive_timeout = 600

# Query cache
query_cache_type = 1
query_cache_size = 256M
query_cache_limit = 64M

# Slow query log
slow_query_log = 1
slow_query_log_file = /var/log/mysql/slow.log
long_query_time = 2

# Binary logging for replication
log-bin = mysql-bin
server-id = 1
binlog_format = ROW
expire_logs_days = 7
```

## 📊 Monitoring Configuration

### 6. Prometheus Alerting Rules

#### `/monitoring/alert_rules.yml`
```yaml
groups:
- name: docker_travian_alerts
  rules:
  - alert: HighResponseTime
    expr: http_request_duration_seconds{quantile="0.95"} > 0.5
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "High response time detected"
      description: "95th percentile response time is {{ $value }}s"

  - alert: HighErrorRate
    expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
    for: 2m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} req/sec"

  - alert: DatabaseConnectionPoolHigh
    expr: mysql_global_status_threads_connected / mysql_global_variables_max_connections > 0.8
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Database connection pool usage high"
      description: "Connection pool is {{ $value }}% full"

  - alert: RedisMemoryHigh
    expr: redis_memory_used_bytes / redis_memory_max_bytes > 0.9
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Redis memory usage high"
      description: "Redis memory usage is {{ $value }}%"

  - alert: DiskSpaceHigh
    expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes > 0.9
    for: 5m
    labels:
      severity: critical
    annotations:
      summary: "Disk space usage high"
      description: "Disk usage is {{ $value }}%"
```

### 7. Grafana Dashboard Configuration

Pre-configured dashboards include:

#### Application Performance Dashboard
- Response time trends
- Request throughput
- Error rate monitoring
- Active user sessions
- Game-specific metrics

#### Infrastructure Dashboard
- CPU and memory utilization
- Disk I/O and space usage
- Network traffic
- Container health status
- Service availability

#### Database Dashboard
- Query performance metrics
- Connection pool status
- Slow query analysis
- Replication lag (if applicable)
- Storage utilization

## 🔐 Security Configuration

### 8. SSL/TLS Setup with Let's Encrypt

```bash
#!/bin/bash
# SSL certificate setup script

# Install certbot
sudo apt update
sudo apt install certbot python3-certbot-nginx

# Obtain certificate
sudo certbot --nginx -d your-domain.com

# Auto-renewal setup
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -

# Update nginx configuration for HTTPS
cat > /etc/nginx/sites-available/travian-ssl.conf << EOF
server {
    listen 443 ssl http2;
    server_name your-domain.com;
    
    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains";
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    
    location / {
        proxy_pass http://localhost:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}

server {
    listen 80;
    server_name your-domain.com;
    return 301 https://\$server_name\$request_uri;
}
EOF

sudo ln -s /etc/nginx/sites-available/travian-ssl.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
```

## 🔄 Backup and Recovery

### 9. Automated Backup System

#### Database Backup Script (`scripts/backup/db-backup.sh`)
```bash
#!/bin/bash
# Automated database backup script

BACKUP_DIR="/opt/backups/travian"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="travian_backup_${DATE}.sql.gz"

# Create backup directory
mkdir -p $BACKUP_DIR

# Perform backup
docker-compose exec database mysqldump \
    --single-transaction \
    --routines \
    --triggers \
    -u travian \
    -p${DB_PASSWORD} \
    travian | gzip > "${BACKUP_DIR}/${BACKUP_FILE}"

# Verify backup
if [ $? -eq 0 ]; then
    echo "✅ Backup completed successfully: ${BACKUP_FILE}"
    
    # Remove backups older than 30 days
    find $BACKUP_DIR -name "travian_backup_*.sql.gz" -mtime +30 -delete
    
    # Upload to cloud storage (optional)
    # aws s3 cp "${BACKUP_DIR}/${BACKUP_FILE}" s3://your-backup-bucket/travian/
else
    echo "❌ Backup failed!"
    exit 1
fi
```

#### Application Data Backup
```bash
#!/bin/bash
# Application data backup script

BACKUP_DIR="/opt/backups/travian"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup uploaded files and configs
tar -czf "${BACKUP_DIR}/app_data_${DATE}.tar.gz" \
    -C /opt/travian \
    uploads/ \
    config/ \
    .env

echo "✅ Application data backup completed"
```

### 10. Disaster Recovery Procedures

#### Complete System Recovery
1. **Infrastructure Recovery**
   ```bash
   # Restore from backup
   git clone https://github.com/your-org/docker-travian.git
   cd docker-travian
   
   # Restore environment configuration
   cp /backup/.env .env
   
   # Restore application data
   tar -xzf /backup/app_data_latest.tar.gz
   ```

2. **Database Recovery**
   ```bash
   # Start database service
   docker-compose up -d database
   
   # Restore database
   gunzip -c /backup/travian_backup_latest.sql.gz | \
   docker-compose exec -T database mysql -u travian -p${DB_PASSWORD} travian
   ```

3. **Service Restoration**
   ```bash
   # Start all services
   docker-compose up -d
   
   # Verify health
   ./scripts/monitoring/health-check.ps1
   ```

## 📈 Performance Optimization

### 11. Production Performance Tuning

#### PHP-FPM Configuration
```ini
; /docker/php/php-fpm.conf
[global]
daemonize = no

[www]
user = www-data
group = www-data
listen = 9000
listen.backlog = 65535
pm = dynamic
pm.max_children = 50
pm.start_servers = 10
pm.min_spare_servers = 5
pm.max_spare_servers = 35
pm.max_requests = 1000
pm.status_path = /status
ping.path = /ping
```

#### OPcache Configuration
```ini
; OPcache settings
opcache.enable=1
opcache.memory_consumption=256
opcache.interned_strings_buffer=16
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.save_comments=1
opcache.enable_file_override=1
```

#### Redis Configuration
```conf
# Redis performance settings
maxmemory 2gb
maxmemory-policy allkeys-lru
save 900 1
save 300 10
save 60 10000
tcp-keepalive 300
timeout 0
```

## 🎯 Production Launch Checklist

### 12. Final Pre-Launch Verification

#### System Health Check
- [ ] All containers running and healthy
- [ ] Database connections working
- [ ] Redis cache operational
- [ ] NGINX serving requests
- [ ] SSL certificates valid
- [ ] Monitoring dashboards active
- [ ] Backup system functional

#### Performance Verification
- [ ] Response times <300ms
- [ ] Load testing passed (1000+ users)
- [ ] Memory usage within limits
- [ ] Database queries optimized
- [ ] CDN configuration active
- [ ] Caching layers functional

#### Security Verification
- [ ] Security headers configured
- [ ] WAF rules active
- [ ] Rate limiting functional
- [ ] SSL/TLS properly configured
- [ ] Vulnerability scan clean
- [ ] Access controls verified
- [ ] Audit logging active

#### Operational Readiness
- [ ] Monitoring alerts configured
- [ ] Backup procedures tested
- [ ] Disaster recovery plan ready
- [ ] Documentation complete
- [ ] Support procedures defined
- [ ] Team training completed

## 🚀 Go-Live Process

### 13. Production Launch Steps

1. **Final Preparation**
   - Deploy to production environment
   - Run complete test suite
   - Verify all integrations

2. **DNS Configuration**
   - Update DNS records
   - Configure CDN (if applicable)
   - Set up monitoring for DNS

3. **Go-Live**
   - Enable production traffic
   - Monitor performance metrics
   - Verify user functionality

4. **Post-Launch Monitoring**
   - 24/7 monitoring for first 48 hours
   - Performance baseline establishment
   - User feedback collection

Your Docker Travian enterprise platform is now ready for production deployment with enterprise-grade reliability, security, and performance! 🎉
