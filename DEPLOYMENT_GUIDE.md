# 🚀 Docker Travian - Complete Deployment Guide

**Enterprise-Grade Game Server Deployment**

[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://docker.com)
[![PHP](https://img.shields.io/badge/PHP-8.2+-green.svg)](https://php.net)
[![MariaDB](https://img.shields.io/badge/MariaDB-10.11+-orange.svg)](https://mariadb.org)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## 📋 Table of Contents

1. [Quick Start](#-quick-start)
2. [System Requirements](#-system-requirements)
3. [Installation Methods](#-installation-methods)
4. [Configuration](#-configuration)
5. [Service Management](#-service-management)
6. [Monitoring & Maintenance](#-monitoring--maintenance)
7. [Troubleshooting](#-troubleshooting)
8. [Production Deployment](#-production-deployment)
9. [Security Hardening](#-security-hardening)
10. [Performance Optimization](#-performance-optimization)

## ⚡ Quick Start

### One-Command Deployment
```powershell
# Clone and deploy in under 5 minutes
git clone https://github.com/ghenghis/docker-travian.git
cd docker-travian
.\scripts\deployment\quick-deploy.ps1
```

**That's it!** Your game server will be running at http://localhost:8080

## 💻 System Requirements

### Minimum Requirements
- **OS**: Windows 10/11, macOS 10.15+, Ubuntu 20.04+
- **RAM**: 4GB (8GB recommended)
- **Storage**: 10GB free space
- **CPU**: 2 cores (4 cores recommended)
- **Network**: Broadband internet connection

### Software Dependencies
- **Docker Desktop** 4.25+ ([Download](https://www.docker.com/products/docker-desktop/))
- **Git** 2.40+ ([Download](https://git-scm.com/downloads))
- **PowerShell** 5.1+ (Windows built-in)

### Hardware Recommendations

| Player Count | RAM | CPU | Storage | Network |
|--------------|-----|-----|---------|---------|
| **1-100** | 4GB | 2 cores | 20GB | 10 Mbps |
| **100-500** | 8GB | 4 cores | 50GB | 50 Mbps |
| **500-1000** | 16GB | 6 cores | 100GB | 100 Mbps |
| **1000+** | 32GB+ | 8+ cores | 200GB+ | 1 Gbps |

## 🛠️ Installation Methods

### Method 1: Automated Setup (Recommended)
```powershell
# Full automated setup with quality checks
.\scripts\automation\setup-project.ps1
.\scripts\deployment\quick-deploy.ps1 -Environment production
```

### Method 2: Manual Setup
```powershell
# 1. Setup environment
cp .env.example .env
# Edit .env file with your settings

# 2. Build and start services
docker-compose build
docker-compose up -d

# 3. Run database migrations
docker-compose exec app php artisan migrate

# 4. Seed initial data
docker-compose exec app php artisan db:seed
```

### Method 3: Development Setup
```powershell
# For developers with hot reloading
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

## ⚙️ Configuration

### Environment Variables

Edit `.env` file for your deployment:

```env
# Application Settings
APP_NAME="Docker Travian"
APP_ENV=production
APP_DEBUG=false
APP_URL=https://your-domain.com

# Database Configuration
DB_HOST=mysql
DB_PORT=3306
DB_DATABASE=travian
DB_USERNAME=travian
DB_PASSWORD=your_secure_password_here

# Redis Configuration
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_PASSWORD=your_redis_password

# Mail Configuration
MAIL_MAILER=smtp
MAIL_HOST=your-smtp-server.com
MAIL_PORT=587
MAIL_USERNAME=your-email@domain.com
MAIL_PASSWORD=your-email-password
MAIL_ENCRYPTION=tls

# Game Settings
GAME_SPEED=1
MAX_PLAYERS=10000
PROTECTION_HOURS=72
WORLD_SIZE=801

# Security
APP_KEY=base64:your-32-character-secret-key-here
JWT_SECRET=your-jwt-secret-key-here

# Monitoring
PROMETHEUS_ENABLED=true
GRAFANA_ADMIN_PASSWORD=your-grafana-password
```

### Docker Compose Overrides

Create `docker-compose.override.yml` for custom settings:

```yaml
version: '3.9'
services:
  app:
    environment:
      - GAME_SPEED=3
      - MAX_PLAYERS=5000
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

  nginx:
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./ssl:/etc/ssl/certs

  mysql:
    environment:
      - MYSQL_ROOT_PASSWORD=your-root-password
    deploy:
      resources:
        limits:
          memory: 2G
```

## 🔧 Service Management

### Essential Commands

```powershell
# Start all services
docker-compose up -d

# Stop all services
docker-compose down

# Restart specific service
docker-compose restart app

# View logs
docker-compose logs -f app

# Scale services
docker-compose up -d --scale app=3

# Update services
docker-compose pull
docker-compose up -d --build

# Backup database
.\scripts\maintenance\backup-system.ps1 -BackupType database

# Health check
.\scripts\monitoring\health-check.ps1

# Optimize database
.\scripts\database\optimize-queries.ps1 -ApplyOptimizations
```

### Service Ports

| Service | Port | Purpose | URL |
|---------|------|---------|-----|
| **Game Server** | 8080 | Main application | http://localhost:8080 |
| **Database Admin** | 8081 | phpMyAdmin | http://localhost:8081 |
| **Monitoring** | 3000 | Grafana dashboard | http://localhost:3000 |
| **Metrics** | 9090 | Prometheus | http://localhost:9090 |
| **Mail Testing** | 8025 | MailHog | http://localhost:8025 |

## 📊 Monitoring & Maintenance

### Health Monitoring
```powershell
# Continuous health monitoring
.\scripts\monitoring\health-check.ps1 -Continuous -IntervalSeconds 300

# One-time health check
.\scripts\monitoring\health-check.ps1 -Detailed

# Health check with alerts
.\scripts\monitoring\health-check.ps1 -AlertOnFailure -AlertWebhook "https://hooks.slack.com/your-webhook"
```

### Automated Backups
```powershell
# Full system backup
.\scripts\maintenance\backup-system.ps1 -BackupType full -Compress

# Database only backup
.\scripts\maintenance\backup-system.ps1 -BackupType database -RetentionDays 7

# Scheduled backup (add to Windows Task Scheduler)
.\scripts\maintenance\backup-system.ps1 -BackupType full -BackupLocation "\\backup-server\travian"
```

### Performance Monitoring

Access Grafana dashboard at http://localhost:3000:
- **Username**: admin
- **Password**: admin123 (change in production)

Key metrics to monitor:
- **Response Time**: <300ms target
- **CPU Usage**: <80% sustained
- **Memory Usage**: <85% sustained
- **Database Connections**: <80% of max
- **Active Players**: Real-time count
- **Error Rate**: <1% target

## 🔍 Troubleshooting

### Common Issues

#### 1. Services Won't Start
```powershell
# Check Docker status
docker info

# Check service logs
docker-compose logs app

# Restart Docker Desktop
# Then try again
docker-compose up -d
```

#### 2. Database Connection Errors
```powershell
# Check database container
docker-compose ps mysql

# Test database connection
docker-compose exec mysql mysql -u travian -p

# Reset database
docker-compose down -v
docker-compose up -d
```

#### 3. Port Conflicts
```powershell
# Find what's using port 8080
netstat -ano | findstr :8080

# Kill conflicting process
taskkill /PID <PID> /F

# Or change port in docker-compose.yml
```

#### 4. Performance Issues
```powershell
# Check resource usage
docker stats

# Optimize database
.\scripts\database\optimize-queries.ps1 -AnalyzeOnly

# Check slow queries
docker-compose exec mysql mysql -u travian -p -e "SHOW PROCESSLIST;"
```

#### 5. SSL/HTTPS Issues
```powershell
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ssl/private.key -out ssl/certificate.crt

# Or use Let's Encrypt
certbot certonly --webroot -w /var/www/html -d your-domain.com
```

### Debug Mode

Enable debug mode for troubleshooting:

```env
# In .env file
APP_DEBUG=true
LOG_LEVEL=debug
```

```powershell
# View detailed logs
docker-compose logs -f --tail=100
```

## 🏭 Production Deployment

### Pre-Production Checklist

- [ ] **Security**: Change all default passwords
- [ ] **SSL**: Configure HTTPS certificates
- [ ] **Firewall**: Configure proper firewall rules
- [ ] **Backups**: Set up automated backups
- [ ] **Monitoring**: Configure alerting
- [ ] **Performance**: Run load tests
- [ ] **Documentation**: Update deployment docs

### Production Configuration

```yaml
# docker-compose.prod.yml
version: '3.9'
services:
  app:
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 1G
          cpus: '1.0'
        reservations:
          memory: 512M
          cpus: '0.5'
      restart_policy:
        condition: on-failure
        max_attempts: 3

  nginx:
    deploy:
      resources:
        limits:
          memory: 256M
        reservations:
          memory: 128M

  mysql:
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

### Load Balancer Setup

```nginx
# nginx.conf for load balancing
upstream travian_backend {
    server app1:8080;
    server app2:8080;
    server app3:8080;
}

server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://travian_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
```

### Database Optimization

```sql
-- Production MySQL optimizations
SET GLOBAL innodb_buffer_pool_size = 2147483648;  -- 2GB
SET GLOBAL query_cache_size = 134217728;          -- 128MB
SET GLOBAL max_connections = 500;
SET GLOBAL innodb_log_file_size = 268435456;      -- 256MB
```

## 🔒 Security Hardening

### Application Security

```env
# Security settings in .env
APP_DEBUG=false
APP_ENV=production
SESSION_SECURE_COOKIE=true
SESSION_HTTP_ONLY=true
BCRYPT_ROUNDS=12
```

### Network Security

```yaml
# docker-compose.security.yml
version: '3.9'
services:
  app:
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
      - /var/cache

  mysql:
    security_opt:
      - no-new-privileges:true
    read_only: true
    tmpfs:
      - /tmp
      - /var/run/mysqld
```

### Firewall Configuration

```powershell
# Windows Firewall
New-NetFirewallRule -DisplayName "Docker Travian HTTP" -Direction Inbound -Port 80 -Protocol TCP -Action Allow
New-NetFirewallRule -DisplayName "Docker Travian HTTPS" -Direction Inbound -Port 443 -Protocol TCP -Action Allow

# Block direct database access
New-NetFirewallRule -DisplayName "Block MySQL" -Direction Inbound -Port 3306 -Protocol TCP -Action Block
```

### SSL/TLS Configuration

```yaml
# SSL configuration
services:
  nginx:
    volumes:
      - ./ssl/certificate.crt:/etc/ssl/certs/certificate.crt:ro
      - ./ssl/private.key:/etc/ssl/private/private.key:ro
    environment:
      - SSL_CERTIFICATE=/etc/ssl/certs/certificate.crt
      - SSL_PRIVATE_KEY=/etc/ssl/private/private.key
```

## ⚡ Performance Optimization

### Database Optimization

```powershell
# Run automated optimization
.\scripts\database\optimize-queries.ps1 -ApplyOptimizations -CreateIndexes

# Manual optimization
docker-compose exec mysql mysql -u travian -p -e "
OPTIMIZE TABLE users, villages, buildings, units, movements;
ANALYZE TABLE users, villages, buildings, units, movements;
"
```

### Caching Strategy

```yaml
# Redis configuration for caching
services:
  redis:
    command: redis-server --maxmemory 512mb --maxmemory-policy allkeys-lru
    deploy:
      resources:
        limits:
          memory: 1G
```

### CDN Integration

```nginx
# CDN configuration
location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header X-CDN-Cache "HIT";
}
```

### Performance Monitoring

```powershell
# Performance testing
.\scripts\testing\load-test.ps1 -Users 1000 -Duration 300

# Resource monitoring
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
```

## 📞 Support & Resources

### Getting Help

1. **Documentation**: Check this guide and [docs/](docs/) folder
2. **GitHub Issues**: [Create an issue](https://github.com/ghenghis/docker-travian/issues)
3. **Community**: [Discord Server](https://discord.gg/travian)
4. **Email**: support@docker-travian.game

### Useful Resources

- [Docker Documentation](https://docs.docker.com/)
- [PHP 8.2 Documentation](https://www.php.net/docs.php)
- [MariaDB Documentation](https://mariadb.com/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

### Professional Support

Enterprise support available:
- **Response Time**: 4 hours
- **Coverage**: 24/7
- **Includes**: Custom optimization, security audit, performance tuning
- **Contact**: enterprise@docker-travian.game

## 📄 License & Credits

- **License**: MIT License
- **Original Game**: Travian Games GmbH
- **Docker Implementation**: Docker Travian Team
- **Contributors**: See [CONTRIBUTORS.md](CONTRIBUTORS.md)

---

**🎉 Congratulations!** You now have a production-ready Travian game server running with enterprise-grade features, monitoring, and security.

**Last Updated**: January 2025  
**Version**: 1.0.0  
**Maintained By**: Docker Travian Team
