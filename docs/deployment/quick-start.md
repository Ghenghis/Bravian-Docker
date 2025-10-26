# 🚀 Docker Travian - Quick Start Guide

Get your enterprise-grade Travian game server running in **under 5 minutes** with our automated deployment system.

## 📋 Prerequisites

### Required Software
- **Docker Desktop** 4.25+ ([Download](https://www.docker.com/products/docker-desktop/))
- **Git** 2.40+ ([Download](https://git-scm.com/downloads))
- **PowerShell** 5.1+ (Windows built-in)

### System Requirements
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 10GB free space
- **OS**: Windows 10/11, macOS, or Linux
- **Network**: Internet connection for initial setup

## ⚡ One-Command Deployment

### Option 1: Quick Deploy (Recommended)
```powershell
# Clone and deploy in one command
git clone https://github.com/ghenghis/docker-travian.git
cd docker-travian
.\scripts\deployment\quick-deploy.ps1
```

### Option 2: Step-by-Step
```powershell
# 1. Clone repository
git clone https://github.com/ghenghis/docker-travian.git
cd docker-travian

# 2. Setup project
.\scripts\automation\setup-project.ps1

# 3. Deploy services
.\scripts\deployment\quick-deploy.ps1 -Environment development
```

## 🎯 Access Your Game Server

After deployment completes (2-3 minutes), access these URLs:

| Service | URL | Credentials |
|---------|-----|-------------|
| **🎮 Game Server** | http://localhost:8080 | Create account |
| **📊 Database Admin** | http://localhost:8081 | `travian` / `travian123` |
| **📈 Monitoring** | http://localhost:3000 | `admin` / `admin123` |
| **🔍 Metrics** | http://localhost:9090 | No auth required |
| **📧 Mail Testing** | http://localhost:8025 | No auth required |

## 🛠️ Advanced Deployment Options

### Production Deployment
```powershell
.\scripts\deployment\quick-deploy.ps1 -Production -Environment production
```

### Skip Quality Checks (Faster)
```powershell
.\scripts\deployment\quick-deploy.ps1 -SkipTests
```

### Force Deployment (Override Failures)
```powershell
.\scripts\deployment\quick-deploy.ps1 -Force
```

### Custom Environment
```powershell
.\scripts\deployment\quick-deploy.ps1 -Environment staging
```

## 🔧 Configuration

### Environment Variables
Edit `.env` file to customize your deployment:

```env
# Application Settings
APP_ENV=development
APP_DEBUG=true
APP_URL=http://localhost:8080

# Database Configuration
DB_HOST=mysql
DB_DATABASE=travian
DB_USERNAME=travian
DB_PASSWORD=travian123

# Game Settings
GAME_SPEED=1
MAX_PLAYERS=10000
PROTECTION_HOURS=72
```

### Docker Compose Override
Create `docker-compose.override.yml` for custom configurations:

```yaml
version: '3.9'
services:
  app:
    ports:
      - "80:8080"  # Use port 80 instead of 8080
    environment:
      - GAME_SPEED=3  # Faster game speed
```

## 📊 Service Management

### Essential Commands
```powershell
# View all services status
docker-compose ps

# View logs (all services)
docker-compose logs -f

# View logs (specific service)
docker-compose logs -f app

# Restart all services
docker-compose restart

# Stop all services
docker-compose down

# Start services
docker-compose up -d

# Rebuild and restart
docker-compose up -d --build
```

### Individual Service Management
```powershell
# Restart just the web server
docker-compose restart app

# Scale PHP workers
docker-compose up -d --scale app=3

# Access container shell
docker-compose exec app /bin/bash

# Run database commands
docker-compose exec mysql mysql -u travian -p travian
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Port Already in Use
```powershell
# Check what's using port 8080
netstat -ano | findstr :8080

# Kill process using port (replace PID)
taskkill /PID <PID> /F

# Or change port in docker-compose.yml
```

#### 2. Docker Not Running
```powershell
# Start Docker Desktop
# Wait for Docker to fully initialize
docker info
```

#### 3. Services Won't Start
```powershell
# Check Docker logs
docker-compose logs

# Rebuild images
docker-compose build --no-cache

# Clean Docker system
docker system prune -af
```

#### 4. Database Connection Issues
```powershell
# Check database container
docker-compose exec mysql mysql -u root -p

# Reset database
docker-compose down -v
docker-compose up -d
```

### Health Checks
```powershell
# Application health
curl http://localhost:8080/health

# Database health
docker-compose exec mysql mysqladmin ping -u travian -p

# Redis health
docker-compose exec redis redis-cli ping
```

## 📈 Performance Optimization

### For Development
```yaml
# docker-compose.override.yml
version: '3.9'
services:
  app:
    volumes:
      - ./src:/var/www/html/src:cached  # Faster file sync
    environment:
      - PHP_OPCACHE_ENABLE=0  # Disable OPcache for development
```

### For Production
```yaml
# docker-compose.prod.yml
version: '3.9'
services:
  app:
    deploy:
      replicas: 3
      resources:
        limits:
          memory: 512M
        reservations:
          memory: 256M
    environment:
      - PHP_OPCACHE_ENABLE=1
      - APP_DEBUG=false
```

## 🔐 Security Configuration

### SSL/HTTPS Setup
```yaml
# Add to docker-compose.override.yml
services:
  nginx:
    ports:
      - "443:443"
    volumes:
      - ./ssl:/etc/ssl/certs
```

### Firewall Configuration
```powershell
# Windows Firewall
New-NetFirewallRule -DisplayName "Docker Travian" -Direction Inbound -Port 8080 -Protocol TCP -Action Allow

# Or use Windows Defender Firewall GUI
```

## 📦 Backup & Restore

### Backup
```powershell
# Backup database
docker-compose exec mysql mysqldump -u travian -ptravian123 travian > backup.sql

# Backup volumes
docker run --rm -v docker-travian_mysql-data:/data -v ${PWD}:/backup alpine tar czf /backup/mysql-backup.tar.gz -C /data .
```

### Restore
```powershell
# Restore database
docker-compose exec -T mysql mysql -u travian -ptravian123 travian < backup.sql

# Restore volumes
docker run --rm -v docker-travian_mysql-data:/data -v ${PWD}:/backup alpine tar xzf /backup/mysql-backup.tar.gz -C /data
```

## 🚀 Scaling for Production

### Horizontal Scaling
```powershell
# Scale application servers
docker-compose up -d --scale app=5

# Add load balancer
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

### Resource Monitoring
```powershell
# View resource usage
docker stats

# Monitor with Grafana
# Visit http://localhost:3000
# Import dashboard ID: 1860 (Node Exporter Full)
```

## 🎮 Game Configuration

### Admin Account Setup
1. Visit http://localhost:8080
2. Register first account (becomes admin)
3. Access admin panel at http://localhost:8080/admin

### Game Speed Settings
```sql
-- Connect to database
docker-compose exec mysql mysql -u travian -ptravian123 travian

-- Update game speed
UPDATE config SET value = '3' WHERE name = 'game_speed';

-- Update protection time
UPDATE config SET value = '24' WHERE name = 'protection_hours';
```

## 📞 Support & Resources

### Documentation
- [Architecture Diagrams](../architecture/diagrams.md)
- [API Documentation](../api/README.md)
- [Security Guide](../security/README.md)
- [Development Guide](../development/README.md)

### Community
- [GitHub Issues](https://github.com/ghenghis/docker-travian/issues)
- [Discord Server](https://discord.gg/travian)
- [Reddit Community](https://reddit.com/r/travian)

### Professional Support
- Email: support@docker-travian.game
- Response Time: 24 hours
- Enterprise Support Available

---

## ✅ Quick Checklist

- [ ] Docker Desktop installed and running
- [ ] Git installed
- [ ] Repository cloned
- [ ] Deployment script executed
- [ ] All services running (docker-compose ps)
- [ ] Game accessible at http://localhost:8080
- [ ] Admin account created
- [ ] Basic configuration completed

**🎉 Congratulations! Your enterprise-grade Travian server is now running!**

---

**Last Updated**: January 2025  
**Maintained By**: Docker Travian Team  
**Version**: 1.0.0
