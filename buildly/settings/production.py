from .base import *
from .email import *

# CORS to allow external apps auth through OAuth 2
# https://github.com/ottoyiu/django-cors-headers

INSTALLED_APPS += (
    'corsheaders',
)

MIDDLEWARE_CORS = [
    'corsheaders.middleware.CorsMiddleware',
]

MIDDLEWARE = MIDDLEWARE_CORS + MIDDLEWARE


CORS_ORIGIN_ALLOW_ALL = False if os.getenv('CORS_ORIGIN_ALLOW_ALL') == 'False' else True

CORS_ORIGIN_WHITELIST = os.getenv('CORS_ORIGIN_WHITELIST', '').split(',')

# Database
# https://docs.djangoproject.com/en/1.11/ref/settings/#databases

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.{}'.format(os.environ['DATABASE_ENGINE']),
        'NAME': os.environ['DATABASE_NAME'],
        'USER': os.environ['DATABASE_USER'],
        'PASSWORD': os.getenv('DATABASE_PASSWORD'),
        'HOST': os.getenv('DATABASE_HOST', 'localhost'),
        'PORT': os.environ['DATABASE_PORT'],
    }
}

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'


# Security
# https://docs.djangoproject.com/en/1.11/ref/settings/#allowed-hosts

ALLOWED_HOSTS = os.environ['ALLOWED_HOSTS'].split(',')

# Production Security Settings
SECURE_SSL_REDIRECT = True if os.getenv('SECURE_SSL_REDIRECT', 'True') == 'True' else False
SECURE_HSTS_SECONDS = int(os.getenv('SECURE_HSTS_SECONDS', '31536000'))  # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True if os.getenv('SECURE_HSTS_INCLUDE_SUBDOMAINS', 'True') == 'True' else False
SECURE_HSTS_PRELOAD = True if os.getenv('SECURE_HSTS_PRELOAD', 'True') == 'True' else False
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_BROWSER_XSS_FILTER = True
SESSION_COOKIE_SECURE = True if os.getenv('SESSION_COOKIE_SECURE', 'True') == 'True' else False
CSRF_COOKIE_SECURE = True if os.getenv('CSRF_COOKIE_SECURE', 'True') == 'True' else False

# https://docs.djangoproject.com/en/1.11/ref/settings/#secure-proxy-ssl-header

SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')


# Logging
# https://docs.djangoproject.com/en/1.11/topics/logging/#configuring-logging

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'handlers': {
        'file': {
            'level': os.getenv('DJANGO_LOG_LEVEL', 'INFO'),
            'class': 'logging.FileHandler',
            'filename': '/var/log/buildly.log',
        },
    },
    'loggers': {
        'django': {
            'handlers': ['file'],
            'level': os.getenv('DJANGO_LOG_LEVEL', 'INFO'),
            'propagate': True,
        },
    },
}

HUBSPOT_API_KEY = os.getenv('HUBSPOT_API_KEY', '')

SECRET_KEY = os.getenv('SECRET_KEY', '')
TOKEN_SECRET_KEY = os.getenv('TOKEN_SECRET_KEY', '')

# NGINX and HTTPS
# https://docs.djangoproject.com/en/1.11/ref/settings/#std:setting-USE_X_FORWARDED_HOST

USE_X_FORWARDED_HOST = True if os.getenv('USE_X_FORWARDED_HOST') == 'True' else False

# Production OAuth2 Settings - Override base settings for security
OAUTH2_PROVIDER = {
    'SCOPES': {
        'read': 'Read scope',
        'write': 'Write scope',
    },
    'ACCESS_TOKEN_EXPIRE_SECONDS': int(os.getenv('OAUTH2_ACCESS_TOKEN_EXPIRE_SECONDS', '3600')),
    'REFRESH_TOKEN_EXPIRE_SECONDS': int(os.getenv('OAUTH2_REFRESH_TOKEN_EXPIRE_SECONDS', '86400')),
    'AUTHORIZATION_CODE_EXPIRE_SECONDS': int(os.getenv('OAUTH2_AUTHORIZATION_CODE_EXPIRE_SECONDS', '600')),
    'ROTATE_REFRESH_TOKEN': True if os.getenv('OAUTH2_ROTATE_REFRESH_TOKEN', 'True') == 'True' else False,
    # Production security settings
    'APPLICATION_MODEL': 'oauth2_provider.Application',
    'ACCESS_TOKEN_MODEL': 'oauth2_provider.AccessToken',
    'REFRESH_TOKEN_MODEL': 'oauth2_provider.RefreshToken',
    'REQUEST_APPROVAL_PROMPT': 'force',  # Always require approval in production
}

INSTALLED_APPS += ('django.contrib.postgres',)
