# Docker Travian - Architecture Diagrams
## Complete System Architecture Documentation

## 1. System Overview
```mermaid
graph TB
    subgraph "Users"
        U1[Players]
        U2[Admins]
        U3[API Users]
    end
    
    subgraph "Frontend - FREE"
        WEB[Static HTML/JS/CSS]
        AJAX[AJAX Requests]
    end
    
    subgraph "Gateway - FREE"
        NGINX[NGINX<br/>Load Balancer]
        MODSEC[ModSecurity WAF<br/>FREE]
        FAIL2BAN[Fail2Ban<br/>Rate Limiting]
    end
    
    subgraph "Application - FREE"
        PHP1[PHP-FPM 8.2<br/>Server 1]
        PHP2[PHP-FPM 8.2<br/>Server 2]
        CRON[Cron Jobs<br/>Game Events]
    end
    
    subgraph "Cache/Queue - FREE"
        REDIS[Redis 7<br/>Session/Cache]
        RABBIT[RabbitMQ<br/>Queue System]
    end
    
    subgraph "Database - FREE"
        MARIA_M[MariaDB 10.11<br/>Master]
        MARIA_S[MariaDB 10.11<br/>Slave]
    end
    
    subgraph "Monitoring - FREE"
        PROM[Prometheus<br/>Metrics]
        GRAF[Grafana<br/>Dashboards]
        LOGS[Loki<br/>Logging]
    end
    
    U1 --> WEB
    U2 --> WEB
    U3 --> NGINX
    
    WEB --> AJAX
    AJAX --> NGINX
    
    NGINX --> MODSEC
    MODSEC --> FAIL2BAN
    FAIL2BAN --> PHP1
    FAIL2BAN --> PHP2
    
    PHP1 --> REDIS
    PHP2 --> REDIS
    PHP1 --> RABBIT
    PHP1 --> MARIA_M
    
    MARIA_M --> MARIA_S
    
    PHP1 -.-> PROM
    PROM --> GRAF
    PHP1 -.-> LOGS
    
    CRON --> PHP1
    RABBIT --> PHP2
```

## 2. Data Flow Architecture
```mermaid
flowchart LR
    subgraph "Request Flow"
        REQ[User Request]
        VAL[Validate Input]
        AUTH[Authenticate]
        AUTHZ[Authorize]
        CACHE{Cache Hit?}
        PROC[Process Logic]
        DB[(Database)]
        RESP[Response]
    end
    
    REQ --> VAL
    VAL --> AUTH
    AUTH --> AUTHZ
    AUTHZ --> CACHE
    CACHE -->|Yes| RESP
    CACHE -->|No| PROC
    PROC --> DB
    DB --> CACHE
    CACHE --> RESP
    
    style REQ fill:#e1f5fe
    style RESP fill:#c8e6c9
    style DB fill:#fff3e0
```

## 3. Database Schema
```mermaid
erDiagram
    USERS ||--o{ VILLAGES : owns
    USERS ||--o{ MESSAGES : sends_receives
    USERS ||--o{ REPORTS : has
    USERS ||--o| HERO : has
    USERS }o--|| ALLIANCES : belongs_to
    
    VILLAGES ||--o{ BUILDINGS : contains
    VILLAGES ||--o{ UNITS : produces
    VILLAGES ||--o{ RESOURCES : generates
    VILLAGES ||--o{ MOVEMENTS : origin_destination
    
    ALLIANCES ||--o{ ALLIANCE_MEMBERS : has
    ALLIANCES ||--o{ DIPLOMACY : participates
    ALLIANCES ||--o{ ALLIANCE_WARS : engages
    
    USERS {
        int id PK
        string username UK
        string email UK
        string password_hash
        int tribe
        int gold
        timestamp last_login
        boolean active
    }
    
    VILLAGES {
        int id PK
        int owner_id FK
        string name
        int x_coord
        int y_coord
        int population
        int loyalty
        boolean capital
    }
    
    BUILDINGS {
        int id PK
        int village_id FK
        int type
        int level
        timestamp complete_time
    }
    
    UNITS {
        int id PK
        int village_id FK
        int unit_type
        int quantity
        boolean training
    }
    
    RESOURCES {
        int id PK
        int village_id FK
        float wood
        float clay
        float iron
        float crop
        timestamp last_update
    }
    
    MOVEMENTS {
        int id PK
        int from_village FK
        int to_village FK
        int type
        json units
        timestamp arrival
    }
```

## 4. Container Architecture
```mermaid
graph TB
    subgraph "Docker Host"
        subgraph "Application Stack"
            APP[travian-app<br/>PHP 8.2-FPM]
            NGINX[travian-nginx<br/>NGINX Alpine]
        end
        
        subgraph "Data Stack"
            MYSQL[travian-mysql<br/>MariaDB 10.11]
            REDIS[travian-redis<br/>Redis 7 Alpine]
        end
        
        subgraph "Queue Stack"
            RABBIT[travian-rabbitmq<br/>RabbitMQ 3]
            WORKER[travian-worker<br/>PHP Worker]
        end
        
        subgraph "Monitoring Stack"
            PROM[travian-prometheus<br/>Prometheus]
            GRAF[travian-grafana<br/>Grafana OSS]
        end
        
        subgraph "Dev Tools"
            PMA[travian-phpmyadmin<br/>phpMyAdmin]
            MAIL[travian-mailhog<br/>MailHog]
        end
    end
    
    subgraph "Volumes"
        V1[mysql-data]
        V2[redis-data]
        V3[app-storage]
        V4[nginx-cache]
    end
    
    subgraph "Networks"
        NET[travian-network<br/>bridge]
    end
    
    APP -.-> V3
    MYSQL -.-> V1
    REDIS -.-> V2
    NGINX -.-> V4
    
    APP --> NET
    NGINX --> NET
    MYSQL --> NET
    REDIS --> NET
```

## 5. Security Architecture
```mermaid
graph LR
    subgraph "Attack Vectors"
        ATK1[SQL Injection]
        ATK2[XSS Attacks]
        ATK3[CSRF]
        ATK4[DDoS]
        ATK5[Brute Force]
    end
    
    subgraph "Defense Layers - ALL FREE"
        subgraph "Layer 1: Network"
            FW[iptables<br/>Firewall]
            FAIL[Fail2Ban<br/>IP Blocking]
        end
        
        subgraph "Layer 2: Application"
            WAF[ModSecurity<br/>WAF Rules]
            RATE[Rate<br/>Limiting]
        end
        
        subgraph "Layer 3: Code"
            VAL[Input<br/>Validation]
            ESC[Output<br/>Escaping]
            PREP[Prepared<br/>Statements]
            TOK[CSRF<br/>Tokens]
        end
        
        subgraph "Layer 4: Data"
            BCRYPT[Bcrypt<br/>Hashing]
            SSL[Let's Encrypt<br/>SSL/TLS]
        end
    end
    
    ATK1 --> FW
    ATK2 --> FW
    ATK3 --> FW
    ATK4 --> FW
    ATK5 --> FW
    
    FW --> FAIL
    FAIL --> WAF
    WAF --> RATE
    RATE --> VAL
    VAL --> ESC
    ESC --> PREP
    PREP --> TOK
    TOK --> BCRYPT
    BCRYPT --> SSL
```

## 6. Deployment Pipeline
```mermaid
graph LR
    subgraph "Development"
        DEV[Local Docker<br/>Development]
        TEST[Run Tests<br/>PHPUnit/Jest]
    end
    
    subgraph "CI/CD - GitHub Actions FREE"
        COMMIT[Git Commit]
        BUILD[Build Images]
        SCAN[Security Scan<br/>Trivy FREE]
        QUALITY[Quality Gates<br/>PHPStan FREE]
    end
    
    subgraph "Deployment"
        STAGE[Staging<br/>Docker]
        PROD[Production<br/>Docker Swarm]
    end
    
    DEV --> TEST
    TEST --> COMMIT
    COMMIT --> BUILD
    BUILD --> SCAN
    SCAN --> QUALITY
    QUALITY --> STAGE
    STAGE --> PROD
    
    style DEV fill:#e8f5e9
    style TEST fill:#fff3e0
    style PROD fill:#ffebee
```

## 7. Game Logic Flow
```mermaid
stateDiagram-v2
    [*] --> Registration
    Registration --> Login
    Login --> Village_Creation
    Village_Creation --> Main_Game
    
    Main_Game --> Building_Construction
    Main_Game --> Unit_Training
    Main_Game --> Resource_Production
    Main_Game --> Combat
    Main_Game --> Trading
    Main_Game --> Alliance
    
    Building_Construction --> Main_Game
    Unit_Training --> Main_Game
    Resource_Production --> Main_Game
    Combat --> Battle_Report
    Battle_Report --> Main_Game
    Trading --> Market
    Market --> Main_Game
    Alliance --> Alliance_Management
    Alliance_Management --> Main_Game
    
    Main_Game --> Logout
    Logout --> [*]
```

## 8. Performance Monitoring
```mermaid
graph TB
    subgraph "Metrics Collection - FREE"
        APP[Application<br/>Metrics]
        SYS[System<br/>Metrics]
        BIZ[Business<br/>Metrics]
    end
    
    subgraph "Prometheus Exporters"
        PHP_EXP[PHP-FPM<br/>Exporter]
        NODE_EXP[Node<br/>Exporter]
        MYSQL_EXP[MySQL<br/>Exporter]
        REDIS_EXP[Redis<br/>Exporter]
    end
    
    subgraph "Storage & Viz"
        PROM[(Prometheus<br/>TSDB)]
        GRAF[Grafana<br/>Dashboards]
    end
    
    subgraph "Alerts"
        ALERT[AlertManager]
        SLACK[Slack<br/>Webhook]
        EMAIL[Email<br/>SMTP]
    end
    
    APP --> PHP_EXP
    SYS --> NODE_EXP
    BIZ --> MYSQL_EXP
    
    PHP_EXP --> PROM
    NODE_EXP --> PROM
    MYSQL_EXP --> PROM
    REDIS_EXP --> PROM
    
    PROM --> GRAF
    PROM --> ALERT
    ALERT --> SLACK
    ALERT --> EMAIL
```

## 9. Scaling Strategy
```mermaid
graph TB
    subgraph "Single Server"
        SINGLE[All Services<br/>1 Docker Host]
    end
    
    subgraph "Horizontal Scaling"
        LB[Load Balancer<br/>HAProxy FREE]
        APP1[App Server 1]
        APP2[App Server 2]
        APP3[App Server N]
    end
    
    subgraph "Database Scaling"
        MASTER[MariaDB<br/>Master]
        SLAVE1[MariaDB<br/>Slave 1]
        SLAVE2[MariaDB<br/>Slave 2]
    end
    
    subgraph "Cache Layer"
        REDIS_M[Redis Master]
        REDIS_S[Redis Slaves]
    end
    
    SINGLE --> LB
    LB --> APP1
    LB --> APP2
    LB --> APP3
    
    APP1 --> MASTER
    APP2 --> SLAVE1
    APP3 --> SLAVE2
    
    MASTER --> SLAVE1
    MASTER --> SLAVE2
    
    APP1 --> REDIS_M
    REDIS_M --> REDIS_S
```

## 10. Backup & Recovery
```mermaid
graph LR
    subgraph "Backup Sources"
        DB[(Database)]
        FILES[Game Files]
        CONFIG[Configs]
    end
    
    subgraph "Backup Process - FREE"
        CRON[Cron Job]
        SCRIPT[Backup.sh]
        TAR[tar/gzip]
    end
    
    subgraph "Storage - LOCAL"
        LOCAL[Local Disk]
        NAS[NAS/External]
        RSYNC[Rsync Mirror]
    end
    
    subgraph "Recovery"
        RESTORE[Restore Script]
        VERIFY[Verify Data]
        DEPLOY[Redeploy]
    end
    
    DB --> CRON
    FILES --> CRON
    CONFIG --> CRON
    
    CRON --> SCRIPT
    SCRIPT --> TAR
    TAR --> LOCAL
    LOCAL --> NAS
    LOCAL --> RSYNC
    
    LOCAL --> RESTORE
    RESTORE --> VERIFY
    VERIFY --> DEPLOY
```

---

## Summary
All architecture components use **100% FREE and open-source** software:
- **No cloud services required**
- **No subscription fees**
- **No paid licenses**
- **Everything runs locally**
- **Production-ready**
- **Enterprise-grade**

Total Cost: **$0** (excluding hardware/hosting)
