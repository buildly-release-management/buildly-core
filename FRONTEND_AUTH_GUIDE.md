# Frontend Authentication Guide

This guide explains how to integrate your frontend application with Buildly Core's JWT authentication system.

## Overview

Buildly Core uses JWT (JSON Web Tokens) for API authentication, providing secure access to protected resources. The authentication flow is simple: login with username/password to get JWT tokens, then use those tokens for subsequent API requests.

## Authentication Flow

1. **Login**: Send username/password to `/token/` endpoint
2. **Receive Tokens**: Get access token (1 hour) and refresh token (1 day)
3. **API Requests**: Include access token in Authorization header
4. **Token Refresh**: Use refresh token to get new access token when needed

## JWT Configuration

### Basic Configuration

```javascript
// config/auth.js
export const authConfig = {
  apiBaseUrl: process.env.REACT_APP_API_URL || 'http://localhost:8000',
  loginUrl: '/token/',
  refreshUrl: '/token/refresh/',
  verifyUrl: '/token/verify/',
  tokenKey: 'buildly_access_token',
  refreshTokenKey: 'buildly_refresh_token'
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
      access: localStorage.getItem(authConfig.tokenKey),
      refresh: localStorage.getItem(authConfig.refreshTokenKey)
    };
  });

  // Initialize auth state
  useEffect(() => {
    if (tokens.access && !isTokenExpired(tokens.access)) {
      fetchUserProfile();
    } else if (tokens.refresh) {
      refreshToken();
    } else {
      setLoading(false);
    }
  }, []);

  // Fetch user profile
  const fetchUserProfile = async () => {
    try {
      const user = await apiRequest('/coreuser/me/');
      setUser(user);
    } catch (error) {
      console.error('Failed to fetch user profile:', error);
      logout();
    } finally {
      setLoading(false);
    }
  };

  // Login with username/password
  const login = async (username, password) => {
    try {
      const response = await fetch(`${authConfig.apiBaseUrl}${authConfig.loginUrl}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Login failed');
      }

      const tokenData = await response.json();
      
      // Store tokens
      localStorage.setItem(authConfig.tokenKey, tokenData.access);
      localStorage.setItem(authConfig.refreshTokenKey, tokenData.refresh);
      
      setTokens({
        access: tokenData.access,
        refresh: tokenData.refresh
      });

      await fetchUserProfile();
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
      const response = await fetch(`${authConfig.apiBaseUrl}${authConfig.refreshUrl}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ refresh: tokens.refresh })
      });

      if (!response.ok) {
        throw new Error('Token refresh failed');
      }

      const tokenData = await response.json();
      
      localStorage.setItem(authConfig.tokenKey, tokenData.access);
      
      setTokens(prev => ({
        ...prev,
        access: tokenData.access
      }));

      return tokenData.access;
    } catch (error) {
      console.error('Token refresh failed:', error);
      logout();
      return null;
    }
  };

  // Logout
  const logout = () => {
    localStorage.removeItem(authConfig.tokenKey);
    localStorage.removeItem(authConfig.refreshTokenKey);
    setTokens({ access: null, refresh: null });
    setUser(null);
  };

  // Make authenticated API request
  const apiRequest = async (endpoint, method = 'GET', data = null) => {
    let accessToken = tokens.access;

    // Check if token needs refresh
    if (accessToken && isTokenExpired(accessToken)) {
      accessToken = await refreshToken();
      if (!accessToken) {
        throw new Error('Authentication required');
      }
    }

    const options = {
      method,
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      }
    };

    if (data && ['POST', 'PUT', 'PATCH'].includes(method)) {
      options.body = JSON.stringify(data);
    }

    const response = await fetch(`${authConfig.apiBaseUrl}${endpoint}`, options);

    if (response.status === 401) {
      // Try to refresh token once
      accessToken = await refreshToken();
      if (accessToken) {
        options.headers['Authorization'] = `Bearer ${accessToken}`;
        const retryResponse = await fetch(`${authConfig.apiBaseUrl}${endpoint}`, options);
        if (!retryResponse.ok) {
          throw new Error(`API request failed: ${retryResponse.statusText}`);
        }
        return retryResponse.json();
      } else {
        throw new Error('Authentication required');
      }
    }

    if (!response.ok) {
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  };

  // Helper function to check if token is expired
  const isTokenExpired = (token) => {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return Date.now() >= payload.exp * 1000;
    } catch {
      return true;
    }
  };

  const value = {
    user,
    loading,
    isAuthenticated: !!tokens.access && !isTokenExpired(tokens.access),
    login,
    logout,
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
```

### Login Component

```javascript
// components/LoginForm.js
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

const LoginForm = () => {
  const navigate = useNavigate();
  const { login } = useAuth();
  const [formData, setFormData] = useState({
    username: '',
    password: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const handleChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');

    try {
      await login(formData.username, formData.password);
      navigate('/dashboard');
    } catch (error) {
      setError(error.message || 'Login failed');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="login-container">
      <form onSubmit={handleSubmit} className="login-form">
        <h2>Login to Buildly</h2>
        
        {error && (
          <div className="error-message">
            {error}
          </div>
        )}
        
        <div className="form-group">
          <label htmlFor="username">Username:</label>
          <input
            type="text"
            id="username"
            name="username"
            value={formData.username}
            onChange={handleChange}
            required
          />
        </div>
        
        <div className="form-group">
          <label htmlFor="password">Password:</label>
          <input
            type="password"
            id="password"
            name="password"
            value={formData.password}
            onChange={handleChange}
            required
          />
        </div>
        
        <button type="submit" disabled={loading}>
          {loading ? 'Logging in...' : 'Login'}
        </button>
      </form>
    </div>
  );
};

export default LoginForm;
```

### Protected Route Component

```javascript
// components/ProtectedRoute.js
import React from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from '../hooks/useAuth';

const ProtectedRoute = ({ children }) => {
  const { isAuthenticated, loading } = useAuth();

  if (loading) {
    return <div>Loading...</div>;
  }

  if (!isAuthenticated) {
    return <Navigate to="/login" replace />;
  }

  return children;
};

export default ProtectedRoute;
```

### App Setup

```javascript
// App.js
import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider } from './hooks/useAuth';
import LoginForm from './components/LoginForm';
import ProtectedRoute from './components/ProtectedRoute';
import Dashboard from './components/Dashboard';

function App() {
  return (
    <AuthProvider>
      <Router>
        <Routes>
          <Route path="/login" element={<LoginForm />} />
          <Route 
            path="/dashboard" 
            element={
              <ProtectedRoute>
                <Dashboard />
              </ProtectedRoute>
            } 
          />
          <Route path="/" element={<Navigate to="/dashboard" replace />} />
        </Routes>
      </Router>
    </AuthProvider>
  );
}

export default App;
```

## Vue.js Implementation

### Pinia Store (Vue 3)

```javascript
// stores/auth.js
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { authConfig } from '../config/auth';

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null);
  const tokens = ref({
    access: localStorage.getItem(authConfig.tokenKey),
    refresh: localStorage.getItem(authConfig.refreshTokenKey)
  });
  const loading = ref(false);

  const isAuthenticated = computed(() => {
    return !!tokens.value.access && !isTokenExpired(tokens.value.access);
  });

  const login = async (username, password) => {
    loading.value = true;
    try {
      const response = await fetch(`${authConfig.apiBaseUrl}${authConfig.loginUrl}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ username, password })
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.detail || 'Login failed');
      }

      const tokenData = await response.json();
      
      localStorage.setItem(authConfig.tokenKey, tokenData.access);
      localStorage.setItem(authConfig.refreshTokenKey, tokenData.refresh);
      
      tokens.value = {
        access: tokenData.access,
        refresh: tokenData.refresh
      };

      await fetchUserProfile();
      return tokenData;
    } catch (error) {
      console.error('Authentication failed:', error);
      throw error;
    } finally {
      loading.value = false;
    }
  };

  const logout = () => {
    localStorage.removeItem(authConfig.tokenKey);
    localStorage.removeItem(authConfig.refreshTokenKey);
    tokens.value = { access: null, refresh: null };
    user.value = null;
  };

  const fetchUserProfile = async () => {
    try {
      const userData = await apiRequest('/coreuser/me/');
      user.value = userData;
    } catch (error) {
      console.error('Failed to fetch user profile:', error);
      logout();
    }
  };

  const apiRequest = async (endpoint, method = 'GET', data = null) => {
    let accessToken = tokens.value.access;

    if (accessToken && isTokenExpired(accessToken)) {
      accessToken = await refreshToken();
      if (!accessToken) {
        throw new Error('Authentication required');
      }
    }

    const options = {
      method,
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      }
    };

    if (data && ['POST', 'PUT', 'PATCH'].includes(method)) {
      options.body = JSON.stringify(data);
    }

    const response = await fetch(`${authConfig.apiBaseUrl}${endpoint}`, options);

    if (!response.ok) {
      throw new Error(`API request failed: ${response.statusText}`);
    }

    return response.json();
  };

  const refreshToken = async () => {
    if (!tokens.value.refresh) {
      logout();
      return null;
    }

    try {
      const response = await fetch(`${authConfig.apiBaseUrl}${authConfig.refreshUrl}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ refresh: tokens.value.refresh })
      });

      if (!response.ok) {
        throw new Error('Token refresh failed');
      }

      const tokenData = await response.json();
      
      localStorage.setItem(authConfig.tokenKey, tokenData.access);
      tokens.value.access = tokenData.access;

      return tokenData.access;
    } catch (error) {
      console.error('Token refresh failed:', error);
      logout();
      return null;
    }
  };

  const isTokenExpired = (token) => {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return Date.now() >= payload.exp * 1000;
    } catch {
      return true;
    }
  };

  return {
    user,
    tokens,
    loading,
    isAuthenticated,
    login,
    logout,
    fetchUserProfile,
    apiRequest,
    refreshToken
  };
});
```

### Vue Login Component

```vue
<!-- components/LoginForm.vue -->
<template>
  <div class="login-container">
    <form @submit.prevent="handleSubmit" class="login-form">
      <h2>Login to Buildly</h2>
      
      <div v-if="error" class="error-message">
        {{ error }}
      </div>
      
      <div class="form-group">
        <label for="username">Username:</label>
        <input
          v-model="formData.username"
          type="text"
          id="username"
          name="username"
          required
        />
      </div>
      
      <div class="form-group">
        <label for="password">Password:</label>
        <input
          v-model="formData.password"
          type="password"
          id="password"
          name="password"
          required
        />
      </div>
      
      <button type="submit" :disabled="loading">
        {{ loading ? 'Logging in...' : 'Login' }}
      </button>
    </form>
  </div>
</template>

<script setup>
import { ref } from 'vue';
import { useRouter } from 'vue-router';
import { useAuthStore } from '../stores/auth';

const router = useRouter();
const authStore = useAuthStore();

const formData = ref({
  username: '',
  password: ''
});

const loading = ref(false);
const error = ref('');

const handleSubmit = async () => {
  loading.value = true;
  error.value = '';

  try {
    await authStore.login(formData.value.username, formData.value.password);
    router.push('/dashboard');
  } catch (err) {
    error.value = err.message || 'Login failed';
  } finally {
    loading.value = false;
  }
};
</script>
```

## Angular Implementation

### Auth Service

```typescript
// services/auth.service.ts
import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { BehaviorSubject, Observable, throwError } from 'rxjs';
import { catchError, tap } from 'rxjs/operators';
import { environment } from '../environments/environment';

interface LoginResponse {
  access: string;
  refresh: string;
}

interface User {
  id: number;
  username: string;
  email: string;
  first_name: string;
  last_name: string;
}

@Injectable({
  providedIn: 'root'
})
export class AuthService {
  private apiUrl = environment.apiUrl;
  private tokenKey = 'buildly_access_token';
  private refreshTokenKey = 'buildly_refresh_token';
  
  private userSubject = new BehaviorSubject<User | null>(null);
  public user$ = this.userSubject.asObservable();
  
  private tokenSubject = new BehaviorSubject<string | null>(
    localStorage.getItem(this.tokenKey)
  );
  public token$ = this.tokenSubject.asObservable();

  constructor(private http: HttpClient) {
    this.initializeAuth();
  }

  private initializeAuth(): void {
    const token = localStorage.getItem(this.tokenKey);
    if (token && !this.isTokenExpired(token)) {
      this.fetchUserProfile().subscribe();
    } else {
      this.logout();
    }
  }

  login(username: string, password: string): Observable<LoginResponse> {
    return this.http.post<LoginResponse>(`${this.apiUrl}/token/`, {
      username,
      password
    }).pipe(
      tap(response => {
        localStorage.setItem(this.tokenKey, response.access);
        localStorage.setItem(this.refreshTokenKey, response.refresh);
        this.tokenSubject.next(response.access);
        this.fetchUserProfile().subscribe();
      }),
      catchError(error => {
        console.error('Login failed:', error);
        return throwError(error);
      })
    );
  }

  logout(): void {
    localStorage.removeItem(this.tokenKey);
    localStorage.removeItem(this.refreshTokenKey);
    this.tokenSubject.next(null);
    this.userSubject.next(null);
  }

  refreshToken(): Observable<{access: string}> {
    const refresh = localStorage.getItem(this.refreshTokenKey);
    if (!refresh) {
      this.logout();
      return throwError('No refresh token');
    }

    return this.http.post<{access: string}>(`${this.apiUrl}/token/refresh/`, {
      refresh
    }).pipe(
      tap(response => {
        localStorage.setItem(this.tokenKey, response.access);
        this.tokenSubject.next(response.access);
      }),
      catchError(error => {
        console.error('Token refresh failed:', error);
        this.logout();
        return throwError(error);
      })
    );
  }

  fetchUserProfile(): Observable<User> {
    return this.http.get<User>(`${this.apiUrl}/coreuser/me/`).pipe(
      tap(user => this.userSubject.next(user)),
      catchError(error => {
        console.error('Failed to fetch user profile:', error);
        this.logout();
        return throwError(error);
      })
    );
  }

  getAuthHeaders(): HttpHeaders {
    const token = this.tokenSubject.value;
    return new HttpHeaders({
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json'
    });
  }

  isAuthenticated(): boolean {
    const token = this.tokenSubject.value;
    return !!token && !this.isTokenExpired(token);
  }

  private isTokenExpired(token: string): boolean {
    try {
      const payload = JSON.parse(atob(token.split('.')[1]));
      return Date.now() >= payload.exp * 1000;
    } catch {
      return true;
    }
  }
}
```

### Angular Login Component

```typescript
// components/login.component.ts
import { Component } from '@angular/core';
import { Router } from '@angular/router';
import { FormBuilder, FormGroup, Validators } from '@angular/forms';
import { AuthService } from '../services/auth.service';

@Component({
  selector: 'app-login',
  template: `
    <div class="login-container">
      <form [formGroup]="loginForm" (ngSubmit)="onSubmit()" class="login-form">
        <h2>Login to Buildly</h2>
        
        <div *ngIf="errorMessage" class="error-message">
          {{ errorMessage }}
        </div>
        
        <div class="form-group">
          <label for="username">Username:</label>
          <input
            type="text"
            id="username"
            formControlName="username"
            required
          />
        </div>
        
        <div class="form-group">
          <label for="password">Password:</label>
          <input
            type="password"
            id="password"
            formControlName="password"
            required
          />
        </div>
        
        <button type="submit" [disabled]="loading || loginForm.invalid">
          {{ loading ? 'Logging in...' : 'Login' }}
        </button>
      </form>
    </div>
  `
})
export class LoginComponent {
  loginForm: FormGroup;
  loading = false;
  errorMessage = '';

  constructor(
    private fb: FormBuilder,
    private authService: AuthService,
    private router: Router
  ) {
    this.loginForm = this.fb.group({
      username: ['', Validators.required],
      password: ['', Validators.required]
    });
  }

  onSubmit(): void {
    if (this.loginForm.valid) {
      this.loading = true;
      this.errorMessage = '';

      const { username, password } = this.loginForm.value;

      this.authService.login(username, password).subscribe({
        next: () => {
          this.router.navigate(['/dashboard']);
        },
        error: (error) => {
          this.errorMessage = error.error?.detail || 'Login failed';
          this.loading = false;
        },
        complete: () => {
          this.loading = false;
        }
      });
    }
  }
}
```

## API Usage Examples

### Making Authenticated Requests

```javascript
// Get user organizations
const organizations = await apiRequest('/organization/');

// Create a new organization
const newOrg = await apiRequest('/organization/', 'POST', {
  name: 'My Organization',
  organization_type: 'Developer'
});

// Update user profile
const updatedUser = await apiRequest('/coreuser/me/', 'PATCH', {
  first_name: 'John',
  last_name: 'Doe'
});
```

### Error Handling

```javascript
try {
  const data = await apiRequest('/some-endpoint/');
  // Handle success
} catch (error) {
  if (error.message === 'Authentication required') {
    // Redirect to login
    navigate('/login');
  } else {
    // Handle other errors
    console.error('API Error:', error.message);
  }
}
```

## Environment Variables

### Development (.env.development)
```
REACT_APP_API_URL=http://localhost:8000
```

### Production (.env.production)
```
REACT_APP_API_URL=https://api.yourdomain.com
```

## Security Best Practices

1. **Token Storage**: Store tokens in localStorage or sessionStorage, not in cookies for SPA
2. **Token Expiry**: Always check token expiry before making requests
3. **Automatic Refresh**: Implement automatic token refresh before expiry
4. **Error Handling**: Handle 401 responses gracefully with re-authentication
5. **HTTPS**: Always use HTTPS in production
6. **Environment Variables**: Store API URLs in environment variables

## Common Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/token/` | POST | Login (get tokens) |
| `/token/refresh/` | POST | Refresh access token |
| `/token/verify/` | POST | Verify token validity |
| `/coreuser/` | GET | List users |
| `/coreuser/me/` | GET | Get current user |
| `/organization/` | GET/POST | Organizations |
| `/logicmodule/` | GET/POST | Logic modules |

## Troubleshooting

### Common Issues

1. **401 Unauthorized**: Token expired or invalid - refresh or re-login
2. **403 Forbidden**: User doesn't have permission - check user permissions
3. **CORS Errors**: Configure CORS settings in Buildly Core
4. **Token Refresh Loop**: Check token expiry logic and refresh implementation

### Debug Tips

```javascript
// Log token payload to debug expiry
const token = localStorage.getItem('buildly_access_token');
if (token) {
  const payload = JSON.parse(atob(token.split('.')[1]));
  console.log('Token expires:', new Date(payload.exp * 1000));
  console.log('Current time:', new Date());
}
```

This guide provides everything needed to integrate with Buildly Core's JWT authentication system. The examples are production-ready and include proper error handling, token refresh, and security best practices.
