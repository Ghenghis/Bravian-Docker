# Docker Travian API Documentation

## 📚 API Reference Guide

Complete RESTful API documentation for Docker Travian enterprise platform, featuring comprehensive endpoints for game mechanics, user management, and administrative operations.

## 🔧 API Overview

### Base URL
- **Production**: `https://your-domain.com/api/v1`
- **Staging**: `https://staging.your-domain.com/api/v1`
- **Development**: `http://localhost:8080/api/v1`

### API Standards
- **Protocol**: RESTful HTTP/HTTPS
- **Data Format**: JSON
- **Authentication**: Bearer Token (JWT)
- **Versioning**: URL path versioning
- **Rate Limiting**: Implemented per endpoint

### Response Format
```json
{
  "success": true,
  "data": {
    // Response payload
  },
  "meta": {
    "timestamp": "2025-01-01T12:00:00Z",
    "version": "1.0.0",
    "request_id": "uuid-here"
  },
  "errors": null
}
```

## 🔐 Authentication Endpoints

### POST /auth/login
Authenticate user and receive access token.

**Request Body:**
```json
{
  "username": "player123",
  "password": "SecurePassword123!",
  "remember_me": false
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "user": {
      "id": 12345,
      "username": "player123",
      "email": "player@example.com",
      "tribe": 1,
      "created_at": "2025-01-01T10:00:00Z"
    }
  }
}
```

**Error Responses:**
- `401 Unauthorized`: Invalid credentials
- `429 Too Many Requests`: Rate limit exceeded
- `423 Locked`: Account temporarily locked

### POST /auth/register
Register new user account.

**Request Body:**
```json
{
  "username": "newplayer",
  "email": "newplayer@example.com",
  "password": "SecurePassword123!",
  "password_confirmation": "SecurePassword123!",
  "tribe": 1,
  "terms_accepted": true
}
```

**Validation Rules:**
- `username`: 3-20 characters, alphanumeric + underscore/hyphen
- `email`: Valid email address
- `password`: 8+ characters with complexity requirements
- `tribe`: Valid tribe ID (1-5)

### POST /auth/logout
Logout and invalidate token.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "message": "Successfully logged out"
  }
}
```

### POST /auth/refresh
Refresh access token using refresh token.

**Request Body:**
```json
{
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9..."
}
```

## 👤 User Management Endpoints

### GET /users/profile
Get current user profile information.

**Headers:**
```
Authorization: Bearer {access_token}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "id": 12345,
    "username": "player123",
    "email": "player@example.com",
    "tribe": 1,
    "gold": 1250,
    "silver": 50000,
    "population": 2847,
    "villages_count": 3,
    "alliance": {
      "id": 42,
      "name": "Elite Warriors",
      "tag": "EW"
    },
    "statistics": {
      "attack_points": 15640,
      "defense_points": 8930,
      "rank_attack": 156,
      "rank_defense": 298,
      "rank_population": 89
    },
    "created_at": "2025-01-01T10:00:00Z",
    "last_login": "2025-01-15T14:30:00Z"
  }
}
```

### PUT /users/profile
Update user profile information.

**Request Body:**
```json
{
  "email": "newemail@example.com",
  "notification_preferences": {
    "email_reports": true,
    "attack_alerts": true,
    "alliance_messages": false
  }
}
```

### POST /users/change-password
Change user password.

**Request Body:**
```json
{
  "current_password": "OldPassword123!",
  "new_password": "NewPassword456!",
  "new_password_confirmation": "NewPassword456!"
}
```

## 🏘️ Village Management Endpoints

### GET /villages
Get list of user's villages.

**Query Parameters:**
- `page`: Page number (default: 1)
- `per_page`: Items per page (default: 10, max: 50)
- `sort`: Sort field (name, population, created_at)
- `order`: Sort order (asc, desc)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "villages": [
      {
        "id": 1001,
        "name": "Capital City",
        "x": 0,
        "y": 0,
        "population": 1247,
        "tribe": 1,
        "resources": {
          "wood": 15420,
          "clay": 18630,
          "iron": 12840,
          "crop": 9560
        },
        "production": {
          "wood_per_hour": 240,
          "clay_per_hour": 280,
          "iron_per_hour": 180,
          "crop_per_hour": 160
        },
        "storage": {
          "warehouse_capacity": 80000,
          "granary_capacity": 80000
        },
        "is_capital": true,
        "created_at": "2025-01-01T10:00:00Z"
      }
    ]
  },
  "meta": {
    "pagination": {
      "current_page": 1,
      "per_page": 10,
      "total": 3,
      "total_pages": 1
    }
  }
}
```

### GET /villages/{id}
Get detailed village information.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "village": {
      "id": 1001,
      "name": "Capital City",
      "x": 0,
      "y": 0,
      "population": 1247,
      "tribe": 1,
      "buildings": [
        {
          "id": 101,
          "type": "main_building",
          "level": 15,
          "position": 26,
          "upgrade_cost": {
            "wood": 6800,
            "clay": 8200,
            "iron": 6100,
            "crop": 2850,
            "time": 3240
          }
        }
      ],
      "units": [
        {
          "type": "legionnaire",
          "count": 150,
          "training": 0
        }
      ],
      "movements": {
        "incoming": 2,
        "outgoing": 1
      }
    }
  }
}
```

### PUT /villages/{id}
Update village information.

**Request Body:**
```json
{
  "name": "New Village Name"
}
```

### POST /villages/{id}/buildings/{position}/upgrade
Upgrade building at specified position.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "upgrade": {
      "building_type": "main_building",
      "current_level": 15,
      "target_level": 16,
      "completion_time": "2025-01-15T18:30:00Z",
      "cost": {
        "wood": 6800,
        "clay": 8200,
        "iron": 6100,
        "crop": 2850
      }
    }
  }
}
```

## ⚔️ Military Endpoints

### GET /villages/{id}/units
Get village units information.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "units": {
      "in_village": {
        "legionnaire": 150,
        "praetorian": 75,
        "imperian": 25,
        "equites_legati": 10,
        "equites_imperatoris": 5,
        "equites_caesaris": 2
      },
      "training": {
        "legionnaire": {
          "count": 20,
          "completion_time": "2025-01-15T16:45:00Z"
        }
      },
      "movements": {
        "outgoing": [
          {
            "id": 5001,
            "target": {
              "village_id": 2001,
              "name": "Enemy Village",
              "x": 15,
              "y": -8
            },
            "type": "attack",
            "units": {
              "legionnaire": 100,
              "praetorian": 50
            },
            "arrival_time": "2025-01-15T17:20:00Z"
          }
        ],
        "incoming": [
          {
            "id": 5002,
            "source": {
              "village_id": 3001,
              "name": "Ally Village",
              "x": -5,
              "y": 12
            },
            "type": "reinforcement",
            "arrival_time": "2025-01-15T16:55:00Z",
            "units_visible": false
          }
        ]
      }
    }
  }
}
```

### POST /villages/{id}/units/train
Train new units.

**Request Body:**
```json
{
  "units": {
    "legionnaire": 50,
    "praetorian": 25
  }
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "training": {
      "units": {
        "legionnaire": 50,
        "praetorian": 25
      },
      "total_cost": {
        "wood": 3750,
        "clay": 4500,
        "iron": 6750,
        "crop": 2250
      },
      "total_time": 4200,
      "completion_time": "2025-01-15T19:10:00Z"
    }
  }
}
```

### POST /villages/{id}/attacks
Send attack to target village.

**Request Body:**
```json
{
  "target": {
    "x": 15,
    "y": -8
  },
  "units": {
    "legionnaire": 100,
    "praetorian": 50,
    "imperian": 25
  },
  "type": "normal_attack"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "attack": {
      "id": 6001,
      "target": {
        "village_id": 2001,
        "name": "Enemy Village",
        "x": 15,
        "y": -8,
        "distance": 17.0
      },
      "units": {
        "legionnaire": 100,
        "praetorian": 50,
        "imperian": 25
      },
      "type": "normal_attack",
      "departure_time": "2025-01-15T15:30:00Z",
      "arrival_time": "2025-01-15T17:20:00Z",
      "travel_time": 6600
    }
  }
}
```

## 🏛️ Alliance Endpoints

### GET /alliances
Search alliances.

**Query Parameters:**
- `q`: Search term (name or tag)
- `page`: Page number
- `per_page`: Items per page
- `sort`: Sort field (name, members_count, created_at)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "alliances": [
      {
        "id": 42,
        "name": "Elite Warriors",
        "tag": "EW",
        "description": "Premier alliance for experienced players",
        "members_count": 45,
        "total_population": 1247830,
        "average_population": 27729,
        "rank": 3,
        "leader": {
          "id": 1001,
          "username": "AllianceLeader"
        },
        "recruitment_open": true,
        "created_at": "2024-12-01T10:00:00Z"
      }
    ]
  }
}
```

### GET /alliances/{id}
Get detailed alliance information.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "alliance": {
      "id": 42,
      "name": "Elite Warriors",
      "tag": "EW",
      "description": "Premier alliance for experienced players",
      "members": [
        {
          "id": 1001,
          "username": "AllianceLeader",
          "role": "leader",
          "population": 45670,
          "villages_count": 12,
          "rank_in_alliance": 1,
          "joined_at": "2024-12-01T10:00:00Z"
        }
      ],
      "statistics": {
        "total_population": 1247830,
        "total_villages": 234,
        "average_population": 27729,
        "rank": 3,
        "attack_points": 856420,
        "defense_points": 743690
      },
      "diplomacy": [
        {
          "alliance_id": 15,
          "alliance_name": "Friendly Neighbors",
          "alliance_tag": "FN",
          "relation_type": "non_aggression_pact",
          "created_at": "2025-01-05T14:20:00Z"
        }
      ]
    }
  }
}
```

### POST /alliances/{id}/join
Request to join alliance.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "application": {
      "id": 7001,
      "alliance_id": 42,
      "status": "pending",
      "message": "I would like to join your alliance",
      "created_at": "2025-01-15T15:30:00Z"
    }
  }
}
```

## 📊 Statistics Endpoints

### GET /statistics/players
Get player rankings.

**Query Parameters:**
- `category`: attack, defense, population, climbers
- `page`: Page number
- `per_page`: Items per page (max: 100)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "rankings": [
      {
        "rank": 1,
        "user": {
          "id": 5001,
          "username": "TopPlayer",
          "alliance": {
            "id": 1,
            "name": "Legends",
            "tag": "LEG"
          }
        },
        "population": 75420,
        "villages_count": 15,
        "attack_points": 125640,
        "defense_points": 89750
      }
    ]
  },
  "meta": {
    "category": "population",
    "pagination": {
      "current_page": 1,
      "per_page": 20,
      "total": 15623,
      "total_pages": 782
    }
  }
}
```

### GET /statistics/alliances
Get alliance rankings.

### GET /world/map
Get world map data.

**Query Parameters:**
- `x_min`, `x_max`, `y_min`, `y_max`: Map boundaries
- `include_details`: Include village details (default: false)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "tiles": [
      {
        "x": 0,
        "y": 0,
        "type": "village",
        "village": {
          "id": 1001,
          "name": "Capital City",
          "owner": {
            "id": 12345,
            "username": "player123",
            "alliance": {
              "id": 42,
              "tag": "EW"
            }
          },
          "population": 1247,
          "tribe": 1
        }
      }
    ],
    "boundaries": {
      "x_min": -50,
      "x_max": 50,
      "y_min": -50,
      "y_max": 50
    }
  }
}
```

## 📨 Messaging Endpoints

### GET /messages
Get user messages.

**Query Parameters:**
- `type`: inbox, outbox, system, reports
- `unread_only`: boolean
- `page`: Page number

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "messages": [
      {
        "id": 8001,
        "subject": "Alliance Meeting",
        "sender": {
          "id": 1001,
          "username": "AllianceLeader"
        },
        "content": "Meeting scheduled for tomorrow at 8 PM",
        "type": "player_message",
        "is_read": false,
        "created_at": "2025-01-15T14:30:00Z"
      }
    ]
  }
}
```

### POST /messages
Send new message.

**Request Body:**
```json
{
  "recipient_username": "targetplayer",
  "subject": "Hello",
  "content": "Message content here"
}
```

### GET /reports
Get battle and activity reports.

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "reports": [
      {
        "id": 9001,
        "type": "attack_report",
        "attacker": {
          "username": "enemy123",
          "village": "Enemy Base"
        },
        "defender": {
          "username": "player123",
          "village": "Capital City"
        },
        "result": "defender_victory",
        "losses": {
          "attacker": {
            "legionnaire": 50,
            "praetorian": 25
          },
          "defender": {
            "legionnaire": 15,
            "praetorian": 8
          }
        },
        "resources_stolen": {
          "wood": 1500,
          "clay": 1200,
          "iron": 800,
          "crop": 600
        },
        "created_at": "2025-01-15T12:45:00Z"
      }
    ]
  }
}
```

## ⚙️ Admin Endpoints

### GET /admin/users
Get user list (Admin only).

**Headers:**
```
Authorization: Bearer {admin_access_token}
```

**Query Parameters:**
- `search`: Search term
- `status`: active, banned, inactive
- `sort`: created_at, last_login, population
- `page`: Page number

### POST /admin/users/{id}/ban
Ban user account (Admin only).

**Request Body:**
```json
{
  "reason": "Cheating",
  "duration": 86400,
  "note": "Using unauthorized scripts"
}
```

### GET /admin/statistics
Get server statistics (Admin only).

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "server_stats": {
      "total_users": 15623,
      "active_users_24h": 2847,
      "total_villages": 45230,
      "total_alliances": 342,
      "attacks_today": 1205,
      "registrations_today": 87
    },
    "performance": {
      "avg_response_time": 145,
      "database_connections": 23,
      "memory_usage": "68%",
      "cpu_usage": "34%"
    }
  }
}
```

## 📝 Error Codes Reference

### HTTP Status Codes
- `200 OK`: Request successful
- `201 Created`: Resource created successfully
- `400 Bad Request`: Invalid request parameters
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `409 Conflict`: Resource conflict
- `422 Unprocessable Entity`: Validation errors
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

### Custom Error Codes
```json
{
  "success": false,
  "data": null,
  "errors": [
    {
      "code": "VALIDATION_ERROR",
      "message": "The given data was invalid",
      "details": {
        "username": ["Username must be at least 3 characters"],
        "email": ["Email format is invalid"]
      }
    }
  ]
}
```

## 🔄 Rate Limiting

### Rate Limit Headers
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 85
X-RateLimit-Reset: 1642262400
```

### Rate Limits by Endpoint Category
- **Authentication**: 5 requests per minute
- **Game Actions**: 60 requests per minute
- **Statistics**: 100 requests per minute
- **Messaging**: 30 requests per minute
- **Admin**: 1000 requests per minute

## 🔌 WebSocket Real-time Events

### Connection
```javascript
const ws = new WebSocket('wss://your-domain.com/ws');
ws.send(JSON.stringify({
  type: 'auth',
  token: 'bearer_token_here'
}));
```

### Event Types
- `village_updated`: Village resource changes
- `attack_incoming`: Incoming attack alert
- `message_received`: New message notification
- `building_completed`: Building upgrade finished
- `unit_training_completed`: Unit training finished

Your Docker Travian API provides comprehensive, enterprise-grade functionality with full RESTful design and real-time capabilities! 🚀
