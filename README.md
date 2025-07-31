# Buildly Open Source RAD Core Gateway
[![Docker Pulls](https://img.shields.io/docker/pulls/buildly/buildly.svg)](https://hub.docker.com/r/buildly/buildly/) [![Build Status](https://travis-ci.org/buildlyio/buildly-core.svg?branch=master)](https://travis-ci.org/buildlyio/buildly-core) [![Documentation Status](https://readthedocs.org/projects/buildly-core/badge/?version=latest)](https://buildly-core.readthedocs.io/en/latest/?badge=latest) [![Gitter](https://badges.gitter.im/Buildlyio/community.svg)](https://gitter.im/Buildlyio/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)

A gateway and service discovery system for “micro” services. A light weight Gateway that connects all of your data services, API’s and endpoints to a single easy-to-use URL.  Based on the Rapid Application Development tools and processes, the Gateway is build to use our Business Logic Module services, or allow for open source or propreitary gateways to connect and auth through the core and data mesh for faster component based development.

# Buildly-Core Project Goals and Vision

## Project Vision

Buildly-Core is designed to be a cornerstone component for cloud-native architectures, providing a versatile gateway and service discovery system for microservices. Our vision is to simplify the integration of data services, APIs, and endpoints, offering a lightweight and easy-to-use solution that connects them all through a single, accessible URL.

## Key Objectives

- Simplified Integration: Streamline the integration of diverse data services, APIs, and endpoints into a unified gateway, making it easier for developers to work with microservices.
- Lightweight and High Performance: Prioritize performance optimization to ensure that Buildy-Core remains lightweight and responsive even in high-traffic environments.
- Service Discovery: Implement robust service discovery mechanisms to enable dynamic service registration and discovery for microservices within the architecture.
- Security and Access Control: Implement security measures to protect against unauthorized access and ensure data and services are secure.
- Flexibility and Scalability: Design Buildly-Core to be flexible and scalable, accommodating future growth and evolving architectural needs.
- Documentation and Ease of Use: Provide comprehensive documentation and resources to make it easy for developers to understand and work with Buildy-Core.
- Community Support: Foster a supportive community where developers can collaborate, seek help, and share insights and best practices.


## Getting Started

These instructions will get you a copy of the project up and running on your local machine for development and testing purposes. See deployment for notes on how to deploy the project on a live system.

### Prerequisites

* Docker version 19+

### Installing

Build first the image:

```bash
docker compose build # --no-cache to force dependencies installation
```

To run the webserver (go to 127.0.0.1:8080):

```bash
docker compose up # -d for detached
```

### Default Login Credentials

For development environments:
- **Username**: `admin`
- **Password**: `admin`

### Authentication

Buildly Core uses OAuth2 for API authentication. The system supports multiple authentication methods:

1. **OAuth2 Token Authentication** - Primary method for API access
2. **JWT Authentication** - For microservice communication  
3. **Session Authentication** - For web interface access

#### Frontend Integration

For frontend applications, use the OAuth2 authorization flow:

1. **Register your application** at `/admin/oauth2_provider/application/`
2. **Configure OAuth2 flow** in your frontend:
   ```javascript
   // Example OAuth2 configuration
   const oauthConfig = {
     clientId: 'your-client-id',
     authorizationUrl: 'http://your-buildly-core/o/authorize/',
     tokenUrl: 'http://your-buildly-core/o/token/',
     redirectUrl: 'http://your-frontend/callback',
     scope: 'read write'
   };
   ```
3. **API requests** should include the OAuth2 token:
   ```javascript
   headers: {
     'Authorization': 'Bearer ' + access_token,
     'Content-Type': 'application/json'
   }
   ```

📖 **For detailed frontend integration examples**, see [FRONTEND_AUTH_GUIDE.md](FRONTEND_AUTH_GUIDE.md)

📚 **For comprehensive deployment instructions**, see [DEPLOYMENT.md](DEPLOYMENT.md)

#### API Documentation

Interactive API documentation is available at `/docs/` when the server is running. This provides a complete reference for all available endpoints and authentication methods.

To run the webserver with pdb support:

```bash
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
  -e ALLOWED_HOSTS="yourdomain.com,localhost" \
  buildly/buildly:latest
```

### Migration Management

Buildly Core includes intelligent migration handling that automatically detects database state and applies appropriate strategies:

- **Fresh deployments**: Automatically runs initial migrations
- **Existing databases**: Smart detection with fallback strategies  
- **Schema conflicts**: Automatic resolution and verification
- **Production safety**: All migration strategies preserve existing data

Control migration behavior with environment variables:
```bash
# For complex migration issues
-e FORCE_SCHEMA_SYNC=true

# For corrupted migration state  
-e FORCE_SYNCDB=true

# Skip migrations (read-only containers)
-e SKIP_MIGRATIONS=true
```

docker compose run --rm --service-ports buildly
```

## Running the tests

To run the tests without flake8:

```bash
docker compose run --entrypoint '/usr/bin/env' --rm buildly bash scripts/run-tests.sh --keepdb
```

To run the tests like if it was CI with flake8:

```bash
docker compose run --entrypoint '/usr/bin/env' --rm buildly bash scripts/run-tests.sh --ci
```

See `pytest --help` for more options.

## Deployment

Buildly Core supports multiple deployment scenarios with intelligent migration handling. The deployment process automatically detects database state and applies appropriate migration strategies.

### Migration Environment Variables

The following environment variables control the migration behavior:

- **`SKIP_MIGRATIONS=true`** - Skip all migration steps (for read-only containers)
- **`FORCE_SYNCDB=true`** - Use `--run-syncdb` with schema verification (for corrupted migration state)
- **`FORCE_FAKE=true`** - Mark all migrations as applied without executing (for manual schema management)  
- **`FORCE_SCHEMA_SYNC=true`** - Comprehensive schema synchronization with multiple fallback strategies
- **Default behavior** - Smart migration with automatic detection and fallbacks

### Production Deployment

For production environments, the container automatically:

1. **Waits for database connectivity**
2. **Detects database state** (empty vs existing)
3. **Applies appropriate migration strategy**
4. **Verifies schema integrity** 
5. **Loads initial data**
6. **Starts the application server**

### Kubernetes Deployment

Example Kubernetes deployment with migration control:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: buildly-core
spec:
  template:
    spec:
      containers:
      - name: buildly-core
        image: buildly/buildly:latest
        env:
        # Database configuration
        - name: DATABASE_ENGINE
          value: "postgresql"
        - name: DATABASE_HOST
          value: "postgres-service"
        # Migration control (optional)
        - name: FORCE_SCHEMA_SYNC
          value: "true"  # Use for comprehensive migration handling
        # OAuth2 configuration
        - name: OAUTH_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: buildly-secrets
              key: oauth-client-id
        - name: OAUTH_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: buildly-secrets
              key: oauth-client-secret
```

### Database Migration Troubleshooting

If you encounter migration issues:

1. **For corrupted migration state**: Set `FORCE_SYNCDB=true`
2. **For complex schema conflicts**: Set `FORCE_SCHEMA_SYNC=true`
3. **For manual schema management**: Set `FORCE_FAKE=true`

The system includes automatic schema verification and repair for common issues.

### Configure the API authentication

All clients interact with our API using the OAuth2 protocol. In order to configure it:

1. **Access the admin interface** at `/admin/oauth2_provider/application/`
2. **Create a new application** with these settings:
   - **Client Type**: `Confidential` (for server-side apps) or `Public` (for SPAs)
   - **Authorization Grant Type**: `Authorization code` (recommended) or `Client credentials`
   - **Name**: Your application name
3. **Note the Client ID and Client Secret** for your frontend application
4. **Configure allowed redirect URIs** for your frontend

### OAuth2 Application Types

- **Confidential**: For server-side applications that can securely store credentials
- **Public**: For single-page applications and mobile apps
- **Authorization Code**: Standard OAuth2 flow with redirect
- **Client Credentials**: For server-to-server communication

### Generating RSA keys

For using JWT as authentication method, we need to configure public and
private RSA keys.

The following commands will generate a public and private key. The private
key will stay in Buildly and the public one will be supplied to
microservices in order to verify the authenticity of the message:

```bash
$ openssl genrsa -out private.pem 2048
$ openssl rsa -in private.pem -outform PEM -pubout -out public.pem
```

### Configuration

Specify each parameter using `-e`, `--env`, and `--env-file` flags to set simple (non-array) environment variables to `docker run`. For example,

```bash
$ docker run -e MYVAR1 --env MYVAR2=foo \
    --env-file ./env.list \
    buildly/buildly:<version>
```

### API Documentation

The API documentation is available at `/docs/` when the server is running. It provides an interactive Swagger/OpenAPI interface to explore and test all API endpoints.

**Features:**
- **Interactive testing** - Execute API calls directly from the documentation
- **Authentication support** - OAuth2 token integration for testing authenticated endpoints  
- **Schema validation** - View request/response schemas and data types
- **Endpoint filtering** - Search and filter endpoints by tags or operations

**Note:** Ensure proper OAuth2 configuration for full functionality. Some endpoints may require authentication tokens for testing.

### Frontend Integration Guide

#### OAuth2 Flow Implementation

1. **Authorization Request**:
   ```
   GET /o/authorize/?response_type=code&client_id={CLIENT_ID}&redirect_uri={REDIRECT_URI}&scope=read+write
   ```

2. **Token Exchange**:
   ```javascript
   POST /o/token/
   Content-Type: application/x-www-form-urlencoded
   
   grant_type=authorization_code&
   client_id={CLIENT_ID}&
   client_secret={CLIENT_SECRET}&
   code={AUTHORIZATION_CODE}&
   redirect_uri={REDIRECT_URI}
   ```

3. **API Usage**:
   ```javascript
   fetch('/api/endpoint/', {
     headers: {
       'Authorization': 'Bearer ' + access_token,
       'Content-Type': 'application/json'
     }
   })
   ```

#### Token Refresh

```javascript
POST /o/token/
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token&
client_id={CLIENT_ID}&
client_secret={CLIENT_SECRET}&
refresh_token={REFRESH_TOKEN}
```

The following tables list the configurable parameters of buildly and their default values.

#### Security System
|             Parameter               |            Description             |                    Default                |
|-------------------------------------|------------------------------------|-------------------------------------------|
| `ALLOWED_HOSTS`                     | A list of strings representing the domain names the app can serve  | `[]`      |
| `CORS_ORIGIN_ALLOW_ALL`             | If True, CORS_ORIGIN_WHITELIST is not used and all origins are accepted  | False |
| `CORS_ORIGIN_WHITELIST`             | A tuple or list of origins that are authorized to make cross-site HTTP requests  | `[]` |
| `DEFAULT_ORG`                       | The first organization created in the database  | ``                           |
| `SECRET_KEY`                        | Used to provide cryptographic signing, and should be set to a unique, unpredictable value | None |
| `SUPER_USER_PASSWORD`               | Used to define the super user password when it's created for the first time | `admin` in Debug mode or None |
| `AUTO_APPROVE_USER`                 | If approval process is set to auto-approve users can automatically login without admin approval | False |

#### Migration Control
|             Parameter               |            Description             |                    Default                |
|-------------------------------------|------------------------------------|-------------------------------------------|
| `SKIP_MIGRATIONS`                   | Skip all migration steps (for read-only containers)  | False      |
| `FORCE_SYNCDB`                      | Use --run-syncdb with schema verification for corrupted migration state  | False |
| `FORCE_FAKE`                        | Mark all migrations as applied without executing (for manual schema management)  | False |
| `FORCE_SCHEMA_SYNC`                 | Comprehensive schema synchronization with multiple fallback strategies | False |

#### Database Connection
|             Parameter               |            Description             |                    Default                |
|-------------------------------------|------------------------------------|-------------------------------------------|
| `DATABASE_ENGINE`                   | The database backend to use. (`postgresql`, `mysql`, `sqlite3` or `oracle`) | `` |
| `DATABASE_NAME`                     | The name of the database to use          | ``                                  |
| `DATABASE_USER`                     | The username to use when connecting to the database | ``                       |
| `DATABASE_PASSWORD`                 | The password to use when connecting to the database | ``                       |
| `DATABASE_HOST`                     | The host to use when connecting to the database | ``                           |
| `DATABASE_PORT`                     | The port to use when connecting to the database | ``                           |

#### Authentication System
|             Parameter               |            Description             |                    Default                |
|-------------------------------------|------------------------------------|-------------------------------------------|
| `ACCESS_TOKEN_EXPIRE_SECONDS`       | The number of seconds an access token remains valid | 3600                     |
| `JWT_ISSUER`                        | The name of the JWT issuer               | ``                                  |
| `JWT_PRIVATE_KEY_RSA_BUILDLY`       | The private RSA KEY                      | ``                                  |
| `JWT_PUBLIC_KEY_RSA_BUILDLY`        | The public RSA KEY                       | ``                                  |
| `OAUTH_CLIENT_ID`                   | Used in combination with OAUTH_CLIENT_SECRET to create OAuth2 password grant | None |
| `OAUTH_CLIENT_SECRET`               | Used in combination with OAUTH_CLIENT_ID to create OAuth2 password grant | None |
| `PASSWORD_MINIMUM_LENGTH`           | The minimum length of passwords      | `6` |
| `USE_PASSWORD_MINIMUM_LENGTH_VALIDATOR`   | Checks whether the password meets a minimum length | True       |
| `USE_PASSWORD_USER_ATTRIBUTE_SIMILARITY_VALIDATOR`  | Checks the similarity between the password and a set of attributes of the user | True |
| `USE_PASSWORD_COMMON_VALIDATOR`     | Checks whether the password occurs in a list of common passwords | True |
| `USE_PASSWORD_NUMERIC_VALIDATOR`    | Checks whether the password isn’t entirely numeric | True |
| `SOCIAL_AUTH_GITHUB_REDIRECT_URL`   | The redirect URL for GitHub Social auth  | None                                |
| `SOCIAL_AUTH_GOOGLE_OAUTH2_REDIRECT_URL`  | The redirect URL for Google Social auth  | None                          |
| `SOCIAL_AUTH_LOGIN_REDIRECT_URL`    | Redirect the user once the auth process ended successfully | None                              |
| `SOCIAL_AUTH_MICROSOFT_GRAPH_REDIRECT_URL` | The redirect URL for Microsoft graph Social auth | None                 |


#### Email Server
|             Parameter               |            Description             |                    Default                |
|-------------------------------------|------------------------------------|-------------------------------------------|
| `EMAIL_BACKEND`                     | If `SMTP`, enable connection to an SMTP Server  | `` |
| `EMAIL_HOST`                        | The host to use for sending email server | `` |
| `EMAIL_HOST_USER`                   | The username to use when connecting to the SMTP server  | `` |
| `EMAIL_HOST_PASSWORD`               | The password to use when connecting to the SMTP server | `` |
| `EMAIL_PORT`                        | The port to use when connecting to the SMTP Server | `587` |
| `EMAIL_USE_TLS`                     | Whether to use a TLS connection when talking to the SMTP server | `True` |
| `EMAIL_SUBJECT_PREFIX`              | Subject-line prefix for email messages sent | `` |
| `DEFAULT_FROM_EMAIL`                | The email address to be set in messages' FROM | `` |
| `DEFAULT_REPLYTO_EMAIL`             | The email address to be set in messages' REPLY TO | `` |

## Built With

* GitHub Actions - Recommended CI/CD
* [Travis CI](https://travis-ci.org/)

## Contributing

Please read [CONTRIBUTING.md](https://github.com/buildlyio/docs/blob/master/CONTRIBUTING.md) for details on our code of conduct, and the process for submitting pull requests to us.

## Versioning

We use [SemVer](http://semver.org/) for versioning. For the versions available, see the [tags on this repository](https://github.com/buildlyio/buildly-core/tags).

## Authors

* **Buildly** - *Initial work*

See also the list of [contributors](https://github.com/buildlyio/buildly-core/graphs/contributors) who participated in this project.

## License

This project is licensed under the GPL v3 License - see the [LICENSE](LICENSE) file for details.
