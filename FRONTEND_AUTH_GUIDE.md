# Frontend Authentication Guide

This guide explains how to integrate your frontend application with Buildly Core's OAuth2 authentication system.

## Overview

Buildly Core uses OAuth2 for API authentication, providing secure access to protected resources. This guide covers the complete integration process for different frontend frameworks.

## OAuth2 Configuration

### 1. Admin Setup

Before integrating your frontend, configure OAuth2 in the Buildly Core admin interface:

1. **Navigate to OAuth2 Applications**: `https://your-buildly-core.com/admin/oauth2_provider/application/`
2. **Create New Application**:
   - **Name**: Your application name (e.g., "My React App")
   - **Client Type**: 
     - `Public` for SPAs (React, Vue, Angular)
     - `Confidential` for server-side applications
   - **Authorization Grant Type**: `Authorization code`
   - **Redirect URIs**: Add your callback URLs (one per line):
     ```
     http://localhost:3000/auth/callback
     https://yourapp.com/auth/callback
     ```

3. **Save and Copy Credentials**: Note the Client ID (and Client Secret for confidential apps)

### 2. Application Configuration

Store your OAuth2 configuration securely:

```javascript
// config/auth.js
export const authConfig = {
  clientId: process.env.REACT_APP_OAUTH_CLIENT_ID,
  clientSecret: process.env.REACT_APP_OAUTH_CLIENT_SECRET, // Only for server-side
  authorizationUrl: `${process.env.REACT_APP_API_URL}/o/authorize/`,
  tokenUrl: `${process.env.REACT_APP_API_URL}/o/token/`,
  revokeUrl: `${process.env.REACT_APP_API_URL}/o/revoke_token/`,
  redirectUrl: `${window.location.origin}/auth/callback`,
  scope: 'read write',
  apiBaseUrl: process.env.REACT_APP_API_URL
};
```

## Implementation Examples

### React with Hooks

```javascript
// hooks/useAuth.js
import { useState, useEffect, createContext, useContext } from 'react';
import { authConfig } from '../config/auth';

const AuthContext = createContext();

export const AuthProvider = ({ children }) => {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [tokens, setTokens] = useState(() => {
    return {
      access: localStorage.getItem('access_token'),
      refresh: localStorage.getItem('refresh_token')
    };
  });

  // Initialize auth state
  useEffect(() => {
    if (tokens.access) {
      fetchUserProfile();
    } else {
      setLoading(false);
    }
  }, [tokens.access]);

  // Fetch user profile
  const fetchUserProfile = async () => {
    try {
      const response = await apiRequest('/users/me/');
      setUser(response.data);
    } catch (error) {
      console.error('Failed to fetch user profile:', error);
      logout();
    } finally {
      setLoading(false);
    }
  };

  // Start OAuth2 flow
  const login = () => {
    const params = new URLSearchParams({
      response_type: 'code',
      client_id: authConfig.clientId,
      redirect_uri: authConfig.redirectUrl,
      scope: authConfig.scope,
      state: generateRandomState() // CSRF protection
    });

    // Store state for validation
    sessionStorage.setItem('oauth_state', params.get('state'));
    
    window.location.href = `${authConfig.authorizationUrl}?${params}`;
  };

  // Handle OAuth2 callback
  const handleCallback = async (code, state) => {
    // Validate state parameter
    const storedState = sessionStorage.getItem('oauth_state');
    if (state !== storedState) {
      throw new Error('Invalid state parameter');
    }
    sessionStorage.removeItem('oauth_state');

    try {
      const response = await fetch(authConfig.tokenUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: authConfig.clientId,
          client_secret: authConfig.clientSecret, // Omit for public clients
          code: code,
          redirect_uri: authConfig.redirectUrl
        })
      });

      if (!response.ok) {
        throw new Error('Token exchange failed');
      }

      const tokenData = await response.json();
      
      // Store tokens
      localStorage.setItem('access_token', tokenData.access_token);
      localStorage.setItem('refresh_token', tokenData.refresh_token);
      
      setTokens({
        access: tokenData.access_token,
        refresh: tokenData.refresh_token
      });

      return tokenData;
    } catch (error) {
      console.error('Authentication failed:', error);
      throw error;
    }
  };

  // Refresh access token
  const refreshToken = async () => {
    if (!tokens.refresh) {
      logout();
      return null;
    }

    try {
      const response = await fetch(authConfig.tokenUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: new URLSearchParams({
          grant_type: 'refresh_token',
          client_id: authConfig.clientId,
          client_secret: authConfig.clientSecret, // Omit for public clients
          refresh_token: tokens.refresh
        })
      });

      if (!response.ok) {
        throw new Error('Token refresh failed');
      }

      const tokenData = await response.json();
      
      localStorage.setItem('access_token', tokenData.access_token);
      if (tokenData.refresh_token) {
        localStorage.setItem('refresh_token', tokenData.refresh_token);
      }
      
      setTokens({
        access: tokenData.access_token,
        refresh: tokenData.refresh_token || tokens.refresh
      });

      return tokenData.access_token;
    } catch (error) {
      console.error('Token refresh failed:', error);
      logout();
      return null;
    }
  };

  // Logout
  const logout = async () => {
    if (tokens.access) {
      try {
        // Revoke token on server
        await fetch(authConfig.revokeUrl, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': `Bearer ${tokens.access}`
          },
          body: new URLSearchParams({
            token: tokens.access,
            client_id: authConfig.clientId,
            client_secret: authConfig.clientSecret // Omit for public clients
          })
        });
      } catch (error) {
        console.error('Token revocation failed:', error);
      }
    }

    // Clear local storage
    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    
    setTokens({ access: null, refresh: null });
    setUser(null);
  };

  // Make authenticated API request
  const apiRequest = async (endpoint, options = {}) => {
    let accessToken = tokens.access;

    // Check if token needs refresh (simple expiry check)
    if (accessToken && isTokenExpired(accessToken)) {
      accessToken = await refreshToken();
      if (!accessToken) {
        throw new Error('Authentication required');
      }
    }

    const response = await fetch(`${authConfig.apiBaseUrl}${endpoint}`, {
      ...options,
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
        ...options.headers
      }
    });

    if (response.status === 401) {
      // Try to refresh token once
      accessToken = await refreshToken();
      if (accessToken) {
        // Retry with new token
        return fetch(`${authConfig.apiBaseUrl}${endpoint}`, {
          ...options,
          headers: {
            'Authorization': `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
            ...options.headers
          }
        });
      }
    }

    return response;
  };

  const value = {
    user,
    loading,
    isAuthenticated: !!tokens.access,
    login,
    logout,
    handleCallback,
    apiRequest,
    refreshToken
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};

// Utility functions
const generateRandomState = () => {
  return Math.random().toString(36).substring(2, 15) + 
         Math.random().toString(36).substring(2, 15);
};

const isTokenExpired = (token) => {
  try {
    const payload = JSON.parse(atob(token.split('.')[1]));
    return payload.exp * 1000 < Date.now();
  } catch {
    return true;
  }
};
```

### React Components

```javascript
// components/AuthCallback.js
import { useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

const AuthCallback = () => {
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const { handleCallback } = useAuth();

  useEffect(() => {
    const processCallback = async () => {
      const code = searchParams.get('code');
      const state = searchParams.get('state');
      const error = searchParams.get('error');

      if (error) {
        console.error('OAuth2 error:', error);
        navigate('/login?error=oauth_failed');
        return;
      }

      if (!code) {
        navigate('/login?error=no_code');
        return;
      }

      try {
        await handleCallback(code, state);
        navigate('/dashboard');
      } catch (error) {
        console.error('Authentication failed:', error);
        navigate('/login?error=auth_failed');
      }
    };

    processCallback();
  }, [searchParams, handleCallback, navigate]);

  return (
    <div className="auth-callback">
      <p>Processing authentication...</p>
    </div>
  );
};

export default AuthCallback;
```

```javascript
// components/LoginButton.js
import { useAuth } from '../hooks/useAuth';

const LoginButton = () => {
  const { login, logout, isAuthenticated, user } = useAuth();

  if (isAuthenticated) {
    return (
      <div className="user-menu">
        <span>Welcome, {user?.username}</span>
        <button onClick={logout} className="logout-btn">
          Logout
        </button>
      </div>
    );
  }

  return (
    <button onClick={login} className="login-btn">
      Login with Buildly
    </button>
  );
};

export default LoginButton;
```

```javascript
// components/ProtectedRoute.js
import { useAuth } from '../hooks/useAuth';

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!isAuthenticated) {
    return (
      <div className="auth-required">
        <p>Please log in to access this page.</p>
        <LoginButton />
      </div>
    );
  }

  return children;
};

export default ProtectedRoute;
```

### Vue.js Implementation

```javascript
// stores/auth.js (Pinia)
import { defineStore } from 'pinia';
import { authConfig } from '../config/auth';

export const useAuthStore = defineStore('auth', {
  state: () => ({
    user: null,
    tokens: {
      access: localStorage.getItem('access_token'),
      refresh: localStorage.getItem('refresh_token')
    },
    loading: false
  }),

  getters: {
    isAuthenticated: (state) => !!state.tokens.access
  },

  actions: {
    async login() {
      const params = new URLSearchParams({
        response_type: 'code',
        client_id: authConfig.clientId,
        redirect_uri: authConfig.redirectUrl,
        scope: authConfig.scope,
        state: this.generateState()
      });

      sessionStorage.setItem('oauth_state', params.get('state'));
      window.location.href = `${authConfig.authorizationUrl}?${params}`;
    },

    async handleCallback(code, state) {
      const storedState = sessionStorage.getItem('oauth_state');
      if (state !== storedState) {
        throw new Error('Invalid state parameter');
      }
      sessionStorage.removeItem('oauth_state');

      const response = await fetch(authConfig.tokenUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: authConfig.clientId,
          code: code,
          redirect_uri: authConfig.redirectUrl
        })
      });

      const tokenData = await response.json();
      
      localStorage.setItem('access_token', tokenData.access_token);
      localStorage.setItem('refresh_token', tokenData.refresh_token);
      
      this.tokens = {
        access: tokenData.access_token,
        refresh: tokenData.refresh_token
      };

      await this.fetchUser();
    },

    async fetchUser() {
      try {
        const response = await this.apiRequest('/users/me/');
        this.user = response.data;
      } catch (error) {
        console.error('Failed to fetch user:', error);
        this.logout();
      }
    },

    async logout() {
      if (this.tokens.access) {
        try {
          await fetch(authConfig.revokeUrl, {
            method: 'POST',
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Authorization': `Bearer ${this.tokens.access}`
            },
            body: new URLSearchParams({
              token: this.tokens.access,
              client_id: authConfig.clientId
            })
          });
        } catch (error) {
          console.error('Token revocation failed:', error);
        }
      }

      localStorage.removeItem('access_token');
      localStorage.removeItem('refresh_token');
      this.tokens = { access: null, refresh: null };
      this.user = null;
    },

    async apiRequest(endpoint, options = {}) {
      const response = await fetch(`${authConfig.apiBaseUrl}${endpoint}`, {
        ...options,
        headers: {
          'Authorization': `Bearer ${this.tokens.access}`,
          'Content-Type': 'application/json',
          ...options.headers
        }
      });

      if (response.status === 401) {
        await this.refreshToken();
        // Retry request with new token
        return fetch(`${authConfig.apiBaseUrl}${endpoint}`, {
          ...options,
          headers: {
            'Authorization': `Bearer ${this.tokens.access}`,
            'Content-Type': 'application/json',
            ...options.headers
          }
        });
      }

      return response;
    },

    generateState() {
      return Math.random().toString(36).substring(2, 15) + 
             Math.random().toString(36).substring(2, 15);
    }
  }
});
```

### Angular Implementation

```typescript
// services/auth.service.ts
import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { BehaviorSubject, Observable } from 'rxjs';
import { Router } from '@angular/router';

export interface User {
  id: number;
  username: string;
  email: string;
}

export interface AuthTokens {
  access_token: string;
  refresh_token: string;
  token_type: string;
  expires_in: number;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private currentUserSubject = new BehaviorSubject<User | null>(null);
  public currentUser$ = this.currentUserSubject.asObservable();

  private authConfig = {
    clientId: environment.oauthClientId,
    authorizationUrl: `${environment.apiUrl}/o/authorize/`,
    tokenUrl: `${environment.apiUrl}/o/token/`,
    revokeUrl: `${environment.apiUrl}/o/revoke_token/`,
    redirectUrl: `${window.location.origin}/auth/callback`,
    scope: 'read write'
  };

  constructor(
    private http: HttpClient,
    private router: Router
  ) {
    this.initializeAuth();
  }

  private initializeAuth(): void {
    const token = localStorage.getItem('access_token');
    if (token) {
      this.fetchUserProfile().subscribe();
    }
  }

  login(): void {
    const state = this.generateState();
    sessionStorage.setItem('oauth_state', state);

    const params = new URLSearchParams({
      response_type: 'code',
      client_id: this.authConfig.clientId,
      redirect_uri: this.authConfig.redirectUrl,
      scope: this.authConfig.scope,
      state: state
    });

    window.location.href = `${this.authConfig.authorizationUrl}?${params}`;
  }

  async handleCallback(code: string, state: string): Promise<void> {
    const storedState = sessionStorage.getItem('oauth_state');
    if (state !== storedState) {
      throw new Error('Invalid state parameter');
    }
    sessionStorage.removeItem('oauth_state');

    const body = new URLSearchParams({
      grant_type: 'authorization_code',
      client_id: this.authConfig.clientId,
      code: code,
      redirect_uri: this.authConfig.redirectUrl
    });

    const headers = new HttpHeaders({
      'Content-Type': 'application/x-www-form-urlencoded'
    });

    try {
      const tokens = await this.http.post<AuthTokens>(
        this.authConfig.tokenUrl,
        body.toString(),
        { headers }
      ).toPromise();

      if (tokens) {
        localStorage.setItem('access_token', tokens.access_token);
        localStorage.setItem('refresh_token', tokens.refresh_token);
        
        this.fetchUserProfile().subscribe();
      }
    } catch (error) {
      console.error('Token exchange failed:', error);
      throw error;
    }
  }

  logout(): void {
    const token = localStorage.getItem('access_token');
    
    if (token) {
      const body = new URLSearchParams({
        token: token,
        client_id: this.authConfig.clientId
      });

      this.http.post(this.authConfig.revokeUrl, body.toString(), {
        headers: new HttpHeaders({
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Bearer ${token}`
        })
      }).subscribe();
    }

    localStorage.removeItem('access_token');
    localStorage.removeItem('refresh_token');
    this.currentUserSubject.next(null);
    this.router.navigate(['/login']);
  }

  private fetchUserProfile(): Observable<User> {
    return this.http.get<User>('/api/users/me/');
  }

  get isAuthenticated(): boolean {
    return !!localStorage.getItem('access_token');
  }

  getAuthHeaders(): HttpHeaders {
    const token = localStorage.getItem('access_token');
    return new HttpHeaders({
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    });
  }

  private generateState(): string {
    return Math.random().toString(36).substring(2, 15) + 
           Math.random().toString(36).substring(2, 15);
  }
}
```

## Best Practices

### Security

1. **Use HTTPS**: Always use HTTPS in production
2. **Validate State Parameter**: Prevent CSRF attacks by validating the state parameter
3. **Store Tokens Securely**: Consider using secure HTTP-only cookies for token storage
4. **Token Expiration**: Implement proper token refresh logic
5. **Logout Handling**: Always revoke tokens on logout

### Error Handling

```javascript
// Comprehensive error handling
const handleAuthError = (error, context) => {
  console.error(`Authentication error in ${context}:`, error);
  
  switch (error.message) {
    case 'invalid_client':
      // Handle invalid client credentials
      break;
    case 'invalid_grant':
      // Handle invalid authorization code or refresh token
      logout();
      break;
    case 'access_denied':
      // Handle user denial
      break;
    default:
      // Handle generic errors
      break;
  }
};
```

### Token Management

```javascript
// Token refresh with retry logic
const apiRequestWithRetry = async (endpoint, options = {}, retries = 1) => {
  try {
    return await apiRequest(endpoint, options);
  } catch (error) {
    if (error.status === 401 && retries > 0) {
      await refreshToken();
      return apiRequestWithRetry(endpoint, options, retries - 1);
    }
    throw error;
  }
};
```

## Testing

### Unit Tests

```javascript
// __tests__/auth.test.js
import { render, screen, fireEvent } from '@testing-library/react';
import { AuthProvider, useAuth } from '../hooks/useAuth';

const TestComponent = () => {
  const { login, isAuthenticated } = useAuth();
  return (
    <div>
      <span>{isAuthenticated ? 'Authenticated' : 'Not authenticated'}</span>
      <button onClick={login}>Login</button>
    </div>
  );
};

test('should initiate login flow', () => {
  const mockLocation = { href: '' };
  Object.defineProperty(window, 'location', {
    value: mockLocation,
    writable: true
  });

  render(
    <AuthProvider>
      <TestComponent />
    </AuthProvider>
  );

  fireEvent.click(screen.getByText('Login'));
  
  expect(mockLocation.href).toContain('/o/authorize/');
  expect(mockLocation.href).toContain('response_type=code');
});
```

## Troubleshooting

### Common Issues

1. **Redirect URI Mismatch**: Ensure redirect URIs in admin match exactly
2. **CORS Issues**: Configure CORS_ORIGIN_WHITELIST in Buildly Core
3. **Token Expiration**: Implement proper refresh token logic
4. **State Parameter Validation**: Always validate state parameter to prevent CSRF

### Debug Mode

```javascript
// Enable debug logging
const debugAuth = {
  logTokens: process.env.NODE_ENV === 'development',
  logRequests: process.env.NODE_ENV === 'development'
};

if (debugAuth.logTokens) {
  console.log('Access token:', tokens.access?.substring(0, 20) + '...');
}
```

For more information, see the main [README.md](README.md) and [DEPLOYMENT.md](DEPLOYMENT.md) guides.
