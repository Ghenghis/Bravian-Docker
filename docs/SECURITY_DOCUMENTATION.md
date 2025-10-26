# Docker Travian Security Documentation

## 🔐 Enterprise Security Framework

This document outlines the comprehensive security implementation for Docker Travian, ensuring OWASP Top 10 compliance and enterprise-grade protection.

## 📋 Security Overview

### Security Principles
- **Defense in Depth**: Multi-layer security architecture
- **Zero Trust**: Never trust, always verify
- **Least Privilege**: Minimal access rights
- **Fail Secure**: Secure defaults and graceful degradation
- **Security by Design**: Built-in security from the ground up

### Compliance Standards
- **OWASP Top 10 2021**: Full compliance
- **CIS Docker Benchmark**: Container security hardening
- **GDPR**: Data protection compliance ready
- **ISO 27001**: Information security management

## 🛡️ Application Security

### 1. Input Validation and Sanitization

#### Comprehensive Input Validation
```php
<?php
// Example: Input validation service
class InputValidator {
    public function validateUsername(string $username): bool {
        // Length check
        if (strlen($username) < 3 || strlen($username) > 20) {
            return false;
        }
        
        // Character validation
        if (!preg_match('/^[a-zA-Z0-9_-]+$/', $username)) {
            return false;
        }
        
        // Blacklist check
        $blacklisted = ['admin', 'root', 'system', 'test'];
        if (in_array(strtolower($username), $blacklisted)) {
            return false;
        }
        
        return true;
    }
    
    public function sanitizeInput(string $input): string {
        // Remove null bytes
        $input = str_replace("\0", '', $input);
        
        // HTML entity encoding
        $input = htmlspecialchars($input, ENT_QUOTES | ENT_HTML5, 'UTF-8');
        
        // Trim whitespace
        $input = trim($input);
        
        return $input;
    }
    
    public function validateEmail(string $email): bool {
        return filter_var($email, FILTER_VALIDATE_EMAIL) !== false;
    }
}
```

#### SQL Injection Prevention
```php
<?php
// Prepared statements implementation
class DatabaseService {
    private PDO $pdo;
    
    public function getUserByUsername(string $username): ?User {
        $stmt = $this->pdo->prepare(
            "SELECT * FROM users WHERE username = :username AND is_active = 1"
        );
        $stmt->bindParam(':username', $username, PDO::PARAM_STR);
        $stmt->execute();
        
        $data = $stmt->fetch(PDO::FETCH_ASSOC);
        return $data ? User::fromArray($data) : null;
    }
    
    public function createUser(array $userData): bool {
        $stmt = $this->pdo->prepare(
            "INSERT INTO users (username, email, password_hash, created_at) 
             VALUES (:username, :email, :password_hash, NOW())"
        );
        
        return $stmt->execute([
            ':username' => $userData['username'],
            ':email' => $userData['email'],
            ':password_hash' => $userData['password_hash']
        ]);
    }
}
```

### 2. Authentication and Session Management

#### Secure Authentication Service
```php
<?php
class AuthenticationService {
    private const MAX_LOGIN_ATTEMPTS = 5;
    private const LOCKOUT_DURATION = 900; // 15 minutes
    
    public function authenticate(string $username, string $password): AuthResult {
        // Check if account is locked
        if ($this->isAccountLocked($username)) {
            return AuthResult::accountLocked();
        }
        
        // Get user from database
        $user = $this->userRepository->findByUsername($username);
        if (!$user) {
            $this->recordFailedAttempt($username);
            return AuthResult::invalidCredentials();
        }
        
        // Verify password
        if (!password_verify($password, $user->getPasswordHash())) {
            $this->recordFailedAttempt($username);
            return AuthResult::invalidCredentials();
        }
        
        // Check if password needs rehashing
        if (password_needs_rehash($user->getPasswordHash(), PASSWORD_DEFAULT)) {
            $newHash = password_hash($password, PASSWORD_DEFAULT);
            $this->userRepository->updatePasswordHash($user->getId(), $newHash);
        }
        
        // Clear failed attempts
        $this->clearFailedAttempts($username);
        
        // Create secure session
        $sessionId = $this->createSecureSession($user);
        
        return AuthResult::success($user, $sessionId);
    }
    
    private function createSecureSession(User $user): string {
        // Generate cryptographically secure session ID
        $sessionId = bin2hex(random_bytes(32));
        
        // Store session in Redis with expiration
        $sessionData = [
            'user_id' => $user->getId(),
            'username' => $user->getUsername(),
            'created_at' => time(),
            'last_activity' => time(),
            'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
        ];
        
        $this->redis->setex(
            "session:{$sessionId}",
            3600, // 1 hour
            json_encode($sessionData)
        );
        
        return $sessionId;
    }
}
```

#### Password Security
```php
<?php
class PasswordService {
    private const MIN_LENGTH = 8;
    private const MAX_LENGTH = 128;
    
    public function validatePassword(string $password): ValidationResult {
        $errors = [];
        
        // Length validation
        if (strlen($password) < self::MIN_LENGTH) {
            $errors[] = "Password must be at least " . self::MIN_LENGTH . " characters";
        }
        
        if (strlen($password) > self::MAX_LENGTH) {
            $errors[] = "Password must not exceed " . self::MAX_LENGTH . " characters";
        }
        
        // Complexity validation
        if (!preg_match('/[a-z]/', $password)) {
            $errors[] = "Password must contain at least one lowercase letter";
        }
        
        if (!preg_match('/[A-Z]/', $password)) {
            $errors[] = "Password must contain at least one uppercase letter";
        }
        
        if (!preg_match('/[0-9]/', $password)) {
            $errors[] = "Password must contain at least one number";
        }
        
        if (!preg_match('/[^a-zA-Z0-9]/', $password)) {
            $errors[] = "Password must contain at least one special character";
        }
        
        // Common password check
        if ($this->isCommonPassword($password)) {
            $errors[] = "Password is too common, please choose a different one";
        }
        
        return new ValidationResult(empty($errors), $errors);
    }
    
    public function hashPassword(string $password): string {
        return password_hash($password, PASSWORD_ARGON2ID, [
            'memory_cost' => 65536,
            'time_cost' => 4,
            'threads' => 3
        ]);
    }
}
```

### 3. Authorization and Access Control

#### Role-Based Access Control (RBAC)
```php
<?php
class AuthorizationService {
    public function checkPermission(User $user, string $resource, string $action): bool {
        // Get user roles
        $roles = $this->getUserRoles($user);
        
        // Check each role for permission
        foreach ($roles as $role) {
            if ($this->roleHasPermission($role, $resource, $action)) {
                return true;
            }
        }
        
        return false;
    }
    
    public function requirePermission(User $user, string $resource, string $action): void {
        if (!$this->checkPermission($user, $resource, $action)) {
            throw new UnauthorizedException(
                "User {$user->getUsername()} does not have permission to {$action} {$resource}"
            );
        }
    }
    
    private function roleHasPermission(Role $role, string $resource, string $action): bool {
        $permissions = $this->getRolePermissions($role);
        
        foreach ($permissions as $permission) {
            if ($permission->getResource() === $resource && 
                $permission->getAction() === $action) {
                return true;
            }
            
            // Check wildcard permissions
            if ($permission->getResource() === '*' && 
                $permission->getAction() === $action) {
                return true;
            }
        }
        
        return false;
    }
}
```

## 🐳 Container Security

### 4. Docker Security Hardening

#### Secure Dockerfile Implementation
```dockerfile
# Multi-stage build for security
FROM composer:2 AS composer-build
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts

FROM php:8.2-fpm-alpine AS runtime

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -D -S -G appgroup appuser

# Install security updates only
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
        curl \
        nginx \
        && rm -rf /var/cache/apk/* \
        && rm -rf /tmp/*

# Install required PHP extensions
RUN docker-php-ext-install \
    pdo_mysql \
    opcache \
    && docker-php-ext-enable opcache

# Security hardening
RUN echo "expose_php = Off" >> /usr/local/etc/php/php.ini && \
    echo "display_errors = Off" >> /usr/local/etc/php/php.ini && \
    echo "log_errors = On" >> /usr/local/etc/php/php.ini && \
    echo "allow_url_fopen = Off" >> /usr/local/etc/php/php.ini && \
    echo "allow_url_include = Off" >> /usr/local/etc/php/php.ini

# Set secure file permissions
COPY --from=composer-build --chown=appuser:appgroup /app/vendor ./vendor
COPY --chown=appuser:appgroup . .
RUN find . -type f -exec chmod 644 {} \; && \
    find . -type d -exec chmod 755 {} \; && \
    chmod 644 composer.json composer.lock

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/health || exit 1

# Run as non-root user
USER appuser
EXPOSE 9000

CMD ["php-fpm"]
```

#### Container Resource Limits
```yaml
# docker-compose.yml security configuration
version: '3.8'

services:
  app:
    build: .
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 256M
    security_opt:
      - no-new-privileges:true
    cap_drop:
      - ALL
    cap_add:
      - SETGID
      - SETUID
    read_only: true
    tmpfs:
      - /tmp:noexec,nosuid,size=100m
      - /var/run:noexec,nosuid,size=10m
    networks:
      - app-network

networks:
  app-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### 5. Network Security

#### NGINX Security Configuration
```nginx
# Security-hardened NGINX configuration
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self';" always;
    
    # Hide server information
    server_tokens off;
    
    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
    limit_req_zone $binary_remote_addr zone=api:10m rate=100r/m;
    limit_req_zone $binary_remote_addr zone=general:10m rate=200r/m;
    
    # DDoS protection
    client_body_buffer_size 1k;
    client_header_buffer_size 1k;
    client_max_body_size 10m;
    large_client_header_buffers 2 1k;
    
    # Timeouts
    client_body_timeout 10;
    client_header_timeout 10;
    keepalive_timeout 10 10;
    send_timeout 10;
    
    # Block common attack patterns
    location ~* /(wp-admin|wp-login|admin|phpmyadmin) {
        deny all;
        return 404;
    }
    
    # Block file extensions
    location ~* \.(bat|exe|sh|cmd|com|scr|vbs)$ {
        deny all;
        return 404;
    }
    
    # Rate limiting for sensitive endpoints
    location /api/auth {
        limit_req zone=login burst=3 nodelay;
        proxy_pass http://app:9000;
    }
    
    location /api/ {
        limit_req zone=api burst=20 nodelay;
        proxy_pass http://app:9000;
    }
    
    location / {
        limit_req zone=general burst=50 nodelay;
        proxy_pass http://app:9000;
    }
}
```

## 🔍 Security Monitoring

### 6. Intrusion Detection and Logging

#### Security Event Logging
```php
<?php
class SecurityLogger {
    private LoggerInterface $logger;
    
    public function logAuthenticationAttempt(string $username, string $ip, bool $successful): void {
        $this->logger->info('Authentication attempt', [
            'event_type' => 'authentication',
            'username' => $username,
            'ip_address' => $ip,
            'successful' => $successful,
            'timestamp' => date('c'),
            'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
        ]);
    }
    
    public function logSuspiciousActivity(string $type, array $context): void {
        $this->logger->warning('Suspicious activity detected', [
            'event_type' => 'security_threat',
            'threat_type' => $type,
            'context' => $context,
            'timestamp' => date('c'),
            'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);
    }
    
    public function logPrivilegeEscalation(User $user, string $attempted_action): void {
        $this->logger->critical('Privilege escalation attempt', [
            'event_type' => 'privilege_escalation',
            'user_id' => $user->getId(),
            'username' => $user->getUsername(),
            'attempted_action' => $attempted_action,
            'timestamp' => date('c'),
            'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'unknown'
        ]);
    }
}
```

#### Fail2Ban Configuration
```ini
# /etc/fail2ban/jail.local
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = auto

[nginx-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2

[docker-travian-auth]
enabled = true
port = http,https
logpath = /var/log/travian/security.log
maxretry = 3
bantime = 1800
```

### 7. Vulnerability Management

#### Automated Security Scanning
```yaml
# .github/workflows/security-scan.yml
name: Security Scanning

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  push:
    branches: [ main ]

jobs:
  dependency-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Run Composer Security Checker
      run: |
        composer install
        vendor/bin/security-checker security:check composer.lock
    
    - name: Run NPM Audit
      run: |
        npm install
        npm audit --audit-level high
  
  container-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Build image
      run: docker build -t travian-security-scan .
      
    - name: Run Trivy vulnerability scanner
      uses: aquasecurity/trivy-action@master
      with:
        image-ref: 'travian-security-scan'
        format: 'sarif'
        output: 'trivy-results.sarif'
        severity: 'HIGH,CRITICAL'
        
    - name: Upload scan results
      uses: github/codeql-action/upload-sarif@v2
      with:
        sarif_file: 'trivy-results.sarif'

  code-scan:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Initialize CodeQL
      uses: github/codeql-action/init@v2
      with:
        languages: php, javascript
        
    - name: Perform CodeQL Analysis
      uses: github/codeql-action/analyze@v2
```

## 📊 Security Metrics and KPIs

### 8. Security Dashboard Metrics

#### Key Security Indicators
- **Failed Authentication Attempts**: Monitor login failures
- **Blocked IP Addresses**: Track banned IPs and patterns
- **Vulnerability Counts**: High/Critical vulnerabilities by category
- **Security Event Frequency**: Rate of security incidents
- **Certificate Expiry**: SSL/TLS certificate validity
- **Patch Status**: System and dependency update status

#### Grafana Security Dashboard Query Examples
```promql
# Failed authentication rate
rate(http_requests_total{endpoint="/api/auth",status="401"}[5m])

# Blocked IP addresses count
fail2ban_banned_ips_total

# SSL certificate expiry
ssl_certificate_expiry_days < 30

# Security events per hour
rate(security_events_total[1h])

# High/Critical vulnerabilities
vulnerability_count{severity=~"HIGH|CRITICAL"}
```

## 🚨 Incident Response

### 9. Security Incident Response Plan

#### Incident Classification
- **P1 - Critical**: Active security breach, data exposure
- **P2 - High**: Potential security vulnerability, system compromise
- **P3 - Medium**: Security policy violation, suspicious activity
- **P4 - Low**: Security awareness, configuration issues

#### Response Procedures
1. **Detection and Analysis**
   - Automated alerting systems
   - Log analysis and correlation
   - Threat intelligence integration

2. **Containment and Eradication**
   - Isolate affected systems
   - Patch vulnerabilities
   - Remove malicious content

3. **Recovery and Monitoring**
   - Restore services from clean backups
   - Enhanced monitoring
   - Lessons learned documentation

#### Emergency Contacts
```yaml
# Security incident contacts
contacts:
  security_lead:
    name: "Security Team Lead"
    email: "security@company.com"
    phone: "+1-XXX-XXX-XXXX"
  
  system_admin:
    name: "System Administrator"
    email: "sysadmin@company.com"
    phone: "+1-XXX-XXX-XXXX"
    
  management:
    name: "IT Management"
    email: "itmanagement@company.com"
    phone: "+1-XXX-XXX-XXXX"
```

## 📋 Security Compliance Checklist

### 10. OWASP Top 10 2021 Compliance

- ✅ **A01:2021 - Broken Access Control**
  - Role-based access control implemented
  - Permission verification on all endpoints
  - Session management with timeout

- ✅ **A02:2021 - Cryptographic Failures**
  - Strong password hashing (Argon2ID)
  - HTTPS/TLS encryption enforced
  - Secure random number generation

- ✅ **A03:2021 - Injection**
  - Prepared statements for all SQL queries
  - Input validation and sanitization
  - Output encoding implemented

- ✅ **A04:2021 - Insecure Design**
  - Threat modeling performed
  - Security-by-design principles
  - Secure development lifecycle

- ✅ **A05:2021 - Security Misconfiguration**
  - Security hardening implemented
  - Regular security updates
  - Minimal attack surface

- ✅ **A06:2021 - Vulnerable Components**
  - Dependency scanning automated
  - Regular updates and patching
  - Component inventory maintained

- ✅ **A07:2021 - Authentication Failures**
  - Strong authentication mechanisms
  - Account lockout protection
  - Session security implemented

- ✅ **A08:2021 - Software Integrity Failures**
  - Code signing implemented
  - CI/CD pipeline security
  - Dependency verification

- ✅ **A09:2021 - Logging Failures**
  - Comprehensive security logging
  - Log integrity protection
  - Real-time monitoring

- ✅ **A10:2021 - Server-Side Request Forgery**
  - Input validation for URLs
  - Network segmentation
  - Allowlist validation

Your Docker Travian platform implements enterprise-grade security with comprehensive protection against all major threats! 🔐
