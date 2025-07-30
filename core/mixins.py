"""
Common mixins for Django REST Framework viewsets
"""
from rest_framework import status
from rest_framework.response import Response


class SafeUserAccessMixin:
    """
    Mixin to safely access request.user and user.organization 
    in viewsets, handling cases where user is anonymous or 
    API documentation is being generated.
    """
    
    def get_authenticated_user(self):
        """
        Safely get authenticated user, return None if not authenticated
        """
        if not hasattr(self, 'request') or not self.request:
            return None
        if not hasattr(self.request, 'user') or not self.request.user.is_authenticated:
            return None
        return self.request.user
    
    def get_user_organization(self):
        """
        Safely get user's organization, return None if user has no organization
        """
        user = self.get_authenticated_user()
        if not user:
            return None
        if not hasattr(user, 'organization') or not user.organization:
            return None
        return user.organization
    
    def require_authenticated_user(self):
        """
        Check if user is authenticated, return error response if not
        """
        user = self.get_authenticated_user()
        if not user:
            return Response(
                {'detail': 'Authentication required.'},
                status=status.HTTP_401_UNAUTHORIZED
            )
        return None
    
    def require_user_organization(self):
        """
        Check if user has organization, return error response if not
        """
        auth_error = self.require_authenticated_user()
        if auth_error:
            return auth_error
            
        organization = self.get_user_organization()
        if not organization:
            return Response(
                {'detail': 'User must belong to an organization.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        return None
