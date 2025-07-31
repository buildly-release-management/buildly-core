# Buildly Core Deployment Guide

This guide covers deployment strategies, authentication setup, and troubleshooting for Buildly Core in production environments.

## Quick Start Deployment

### Docker Compose (Development)

```bash
# Clone and build
git clone https://github.com/buildlyio/buildly-core.git
cd buildly-core
docker compose build
docker compose up

# Access the application
# Web Interface: http://localhost:8080
# API Documentation: http://localhost:8080/docs/
# Admin Interface: http://localhost:8080/admin/
```

### Docker (Production)

```bash
docker run -d \
  --name buildly-core \
  -p 8080:8080 \
  -e DATABASE_ENGINE=postgresql \
  -e DATABASE_HOST=your-postgres-host \
  -e DATABASE_NAME=buildly \
  -e DATABASE_USER=buildly_user \
  -e DATABASE_PASSWORD=secure_password \
  -e SECRET_KEY=your-secret-key \
  -e JWT_PRIVATE_KEY_RSA_BUILDLY="$(cat private.pem)" \
  -e JWT_PUBLIC_KEY_RSA_BUILDLY="$(cat public.pem)" \
  buildly/buildly:latest
```

## Authentication Configuration

### 1. OAuth2 Application Setup

After deployment, configure OAuth2 applications for your frontend:

1. **Access Admin Interface**: Navigate to `/admin/oauth2_provider/application/`
2. **Create Application**:
   - **Name**: Your application name (e.g., "My Frontend App")
   - **Client Type**: 
     - `Confidential` for server-side applications
     - `Public` for single-page applications (SPAs)
   - **Authorization Grant Type**: `Authorization code`
   - **Redirect URIs**: Your frontend callback URLs (one per line)

3. **Save and Note Credentials**: Copy the generated Client ID and Client Secret

### 2. Frontend Integration

#### React/JavaScript Example

```javascript
// OAuth2 configuration
const oauthConfig = {
  clientId: 'your-client-id-from-admin',
  clientSecret: 'your-client-secret', // Only for server-side apps
  authorizationUrl: 'https://your-buildly-core.com/o/authorize/',
  tokenUrl: 'https://your-buildly-core.com/o/token/',
  redirectUrl: 'https://your-frontend.com/auth/callback',
  scope: 'read write'
};

// Step 1: Redirect to authorization
function login() {
  const params = new URLSearchParams({
    response_type: 'code',
    client_id: oauthConfig.clientId,
    redirect_uri: oauthConfig.redirectUrl,
    scope: oauthConfig.scope
  });
  
  window.location.href = `${oauthConfig.authorizationUrl}?${params}`;
}

// Step 2: Handle callback and exchange code for token
async function handleAuthCallback(authorizationCode) {
  const response = await fetch(oauthConfig.tokenUrl, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: oauthConfig.clientId,
      client_secret: oauthConfig.clientSecret, // Omit for public clients
      code: authorizationCode,
      redirect_uri: oauthConfig.redirectUrl
    })
  });
  
  const tokens = await response.json();
  // Store tokens securely
  localStorage.setItem('access_token', tokens.access_token);
  localStorage.setItem('refresh_token', tokens.refresh_token);
}

// Step 3: Make authenticated API requests
async function apiRequest(endpoint, options = {}) {
  const token = localStorage.getItem('access_token');
  
  return fetch(`https://your-buildly-core.com/api${endpoint}`, {
    ...options,
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...options.headers
    }
  });
}
```

### 3. JWT Key Generation

Generate RSA key pairs for JWT authentication:

```bash
# Generate private key
openssl genrsa -out private.pem 2048

# Generate public key
openssl rsa -in private.pem -outform PEM -pubout -out public.pem

# Set as environment variables
export JWT_PRIVATE_KEY_RSA_BUILDLY="$(cat private.pem)"
export JWT_PUBLIC_KEY_RSA_BUILDLY="$(cat public.pem)"
```

## Database Migration Strategies

Buildly Core includes intelligent migration handling for different deployment scenarios:

### Migration Environment Variables

| Variable | Use Case | Description |
|----------|----------|-------------|
| `SKIP_MIGRATIONS=true` | Read-only containers | Skip all migration steps |
| `FORCE_SYNCDB=true` | Corrupted migration state | Use --run-syncdb with schema verification |
| `FORCE_FAKE=true` | Manual schema management | Mark migrations as applied without executing |
| `FORCE_SCHEMA_SYNC=true` | Complex migration issues | Comprehensive sync with multiple fallbacks |
| Default behavior | Normal deployments | Smart auto-detection with fallbacks |

### Common Migration Scenarios

#### New Deployment (Empty Database)
```bash
# No special configuration needed
docker run buildly/buildly:latest
# Automatically detects empty database and runs fresh migrations
```

#### Existing Database with Migration Issues
```bash
# Use schema synchronization
docker run -e FORCE_SCHEMA_SYNC=true buildly/buildly:latest
```

#### Production Database Upgrade
```bash
# Safe migration with verification
docker run -e FORCE_SYNCDB=true buildly/buildly:latest
```

## Kubernetes Deployment

### Basic Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buildly-core
  namespace: buildly
spec:
  replicas: 3
  selector:
    matchLabels:
      app: buildly-core
  template:
    metadata:
      labels:
        app: buildly-core
    spec:
      containers:
      - name: buildly-core
        image: buildly/buildly:latest
        ports:
        - containerPort: 8080
        env:
        # Database Configuration
        - name: DATABASE_ENGINE
          value: "postgresql"
        - name: DATABASE_HOST
          value: "postgres-service.database.svc.cluster.local"
        - name: DATABASE_NAME
          valueFrom:
            secretKeyRef:
              name: buildly-db-secret
              key: database-name
        - name: DATABASE_USER
          valueFrom:
            secretKeyRef:
              name: buildly-db-secret
              key: database-user
        - name: DATABASE_PASSWORD
          valueFrom:
            secretKeyRef:
              name: buildly-db-secret
              key: database-password
        
        # Application Configuration
        - name: SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: buildly-app-secret
              key: secret-key
        - name: ALLOWED_HOSTS
          value: "buildly.yourdomain.com,localhost"
        
        # OAuth2 Configuration
        - name: OAUTH_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: buildly-oauth-secret
              key: client-id
        - name: OAUTH_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: buildly-oauth-secret
              key: client-secret
        
        # JWT Configuration
        - name: JWT_PRIVATE_KEY_RSA_BUILDLY
          valueFrom:
            secretKeyRef:
              name: buildly-jwt-secret
              key: private-key
        - name: JWT_PUBLIC_KEY_RSA_BUILDLY
          valueFrom:
            secretKeyRef:
              name: buildly-jwt-secret
              key: public-key
        
        # Migration Control (optional)
        - name: FORCE_SCHEMA_SYNC
          value: "true"
        
        # Health checks
        livenessProbe:
          httpGet:
            path: /health/
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health/
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
          
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"

---
apiVersion: v1
kind: Service
metadata:
  name: buildly-core-service
  namespace: buildly
spec:
  selector:
    app: buildly-core
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: buildly-core-ingress
  namespace: buildly
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  tls:
  - hosts:
    - buildly.yourdomain.com
    secretName: buildly-tls
  rules:
  - host: buildly.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: buildly-core-service
            port:
              number: 80
```

### Secrets Configuration

```yaml
# Database secrets
apiVersion: v1
kind: Secret
metadata:
  name: buildly-db-secret
  namespace: buildly
type: Opaque
stringData:
  database-name: "buildly_production"
  database-user: "buildly_user"
  database-password: "secure_database_password"

---
# Application secrets
apiVersion: v1
kind: Secret
metadata:
  name: buildly-app-secret
  namespace: buildly
type: Opaque
stringData:
  secret-key: "your-very-secure-django-secret-key-here"

---
# OAuth2 secrets
apiVersion: v1
kind: Secret
metadata:
  name: buildly-oauth-secret
  namespace: buildly
type: Opaque
stringData:
  client-id: "your-oauth-client-id"
  client-secret: "your-oauth-client-secret"

---
# JWT secrets
apiVersion: v1
kind: Secret
metadata:
  name: buildly-jwt-secret
  namespace: buildly
type: Opaque
stringData:
  private-key: |
    -----BEGIN RSA PRIVATE KEY-----
    [Your private key content here]
    -----END RSA PRIVATE KEY-----
  public-key: |
    -----BEGIN PUBLIC KEY-----
    [Your public key content here]
    -----END PUBLIC KEY-----
```

## Troubleshooting

### Migration Issues

#### Error: "relation does not exist"
```bash
# Solution: Force schema synchronization
kubectl set env deployment/buildly-core FORCE_SCHEMA_SYNC=true
kubectl rollout restart deployment/buildly-core
```

#### Error: "migration dependency conflicts"
```bash
# Solution: Use syncdb with verification
kubectl set env deployment/buildly-core FORCE_SYNCDB=true
kubectl rollout restart deployment/buildly-core
```

#### Error: "no migrations to apply" but schema missing
```bash
# Solution: Reset migration environment variable and restart
kubectl unset env deployment/buildly-core FORCE_SYNCDB FORCE_FAKE
kubectl rollout restart deployment/buildly-core
```

### Authentication Issues

#### OAuth2 "invalid_client" Error
1. Verify Client ID and Secret in admin interface
2. Check redirect URI matches exactly (including trailing slashes)
3. Ensure client type matches your application (Public vs Confidential)

#### JWT Token Issues
1. Verify RSA keys are properly formatted
2. Check JWT_ISSUER matches your domain
3. Ensure clock synchronization between services

### Performance Optimization

#### Database Connection Pooling
```python
# In settings
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'OPTIONS': {
            'MAX_CONNS': 20,
            'CONN_MAX_AGE': 60,
        }
    }
}
```

#### Caching Configuration
```python
# Redis caching
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': 'redis://redis-service:6379/1',
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}
```

## Security Best Practices

1. **Use HTTPS in production** - Configure TLS termination at load balancer or ingress
2. **Secure secret management** - Use Kubernetes secrets or external secret managers
3. **Network policies** - Restrict pod-to-pod communication
4. **Resource limits** - Set appropriate CPU and memory limits
5. **Regular updates** - Keep base images and dependencies updated
6. **Monitoring** - Implement logging and monitoring for security events

## Monitoring and Logging

### Health Checks

Buildly Core provides health check endpoints:
- `/health/` - Basic health check
- `/health/db/` - Database connectivity check
- `/health/ready/` - Readiness check for Kubernetes

### Logging Configuration

```python
# Enhanced logging for production
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/var/log/buildly/app.log',
        },
        'console': {
            'level': 'INFO',
            'class': 'logging.StreamHandler',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file', 'console'],
            'level': 'INFO',
            'propagate': True,
        },
        'buildly': {
            'handlers': ['file', 'console'],
            'level': 'DEBUG',
            'propagate': True,
        },
    },
}
```

For more detailed configuration options, see the main [README.md](README.md) file.
