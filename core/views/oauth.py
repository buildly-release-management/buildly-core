from rest_framework.generics import GenericAPIView
from core.permissions import IsSuperUser
from rest_framework import mixins, viewsets
import django_filters
from django.shortcuts import render
from django.utils.encoding import smart_str
from oauth2_provider.models import AccessToken, Application, RefreshToken

from core.serializers import AccessTokenSerializer, ApplicationSerializer, RefreshTokenSerializer,\
    GithubSocialAuthSerializer


class AccessTokenViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin,
                         mixins.DestroyModelMixin,
                         viewsets.GenericViewSet):
    """
    title:
    Users' access tokens

    description:
    An AccessToken instance represents the actual access token to access user's resources.

    retrieve:
    Return the given AccessToken.

    Return the given AccessToken.

    list:
    Return a list of all the existing AccessTokens.

    Return a list of all the existing AccessTokens.

    destroy:
    Delete an AccessToken instance.

    Delete an AccessToken instance.
    """

    filterset_fields = ('user__username',)
    filter_backends = (django_filters.rest_framework.DjangoFilterBackend,)
    permission_classes = (IsSuperUser,)
    queryset = AccessToken.objects.all()
    serializer_class = AccessTokenSerializer


class ApplicationViewSet(viewsets.ModelViewSet):
    """
    title:
    Clients on the authorization server

    description:
    An Application instance represents the actual access token to access user's resources.

    retrieve:
    Return the given Application.

    Return the given Application.

    list:
    Return a list of all existing Applications.

    Return a list of all existing Applications.

    create:
    Create a new Application instance.

    Create a new Application instance.

    update:
    Update an existing Application instance.

    Update an existing Application instance.

    destroy:
    Delete an existing Application instance.

    Delete an existing Application instance.
    """

    permission_classes = (IsSuperUser,)
    queryset = Application.objects.all()
    serializer_class = ApplicationSerializer


class RefreshTokenViewSet(mixins.ListModelMixin, mixins.RetrieveModelMixin,
                          mixins.DestroyModelMixin,
                          viewsets.GenericViewSet):
    """
    title:
    Users' refresh tokens

    description:
    A RefreshToken instance represents a token that can be swapped for a new access token when it expires.

    retrieve:
    Return the given RefreshToken.

    Return the given RefreshToken.

    list:
    Return a list of all the existing RefreshTokens.

    Return a list of all the existing RefreshTokens.

    destroy:
    Delete a RefreshToken instance.

    Delete a RefreshToken instance.
    """

    filterset_fields = ('user__username',)
    filter_backends = (django_filters.rest_framework.DjangoFilterBackend,)
    permission_classes = (IsSuperUser,)
    queryset = RefreshToken.objects.all()
    serializer_class = RefreshTokenSerializer


"""
OAUTH FLOW
1. Request a user's GitHub identity
GET https://github.com/login/oauth/authorize

2. Users are redirected back to your site by GitHub
Exchange this code for an access token:

POST https://github.com/login/oauth/access_token
By default, the response takes the following form:

access_token=e72e16c7e42f292c6912e7710c838347ae178b4a&token_type=bearer

3. Use the access token to access the API
Authorization: token OAUTH-TOKEN
GET https://api.github.com/user
For example, in curl you can set the Authorization header like this:

curl -H "Authorization: token OAUTH-TOKEN" https://api.github.com/user
"""


class GithubSocialAuthView(GenericAPIView):

    serializer_class = GithubSocialAuthSerializer

    def post(self, request):
        """
        POST with "access_token" and "token_type"
        Send an access_token as from github to get user information
        """

        serializer = self.serializer_class(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = ((serializer.validated_data)['auth_token'])
        return Response(data, status=status.HTTP_200_OK)


def github_login(request):
    encoded_client_id = smart_str('076e9a822c235db9057f', encoding='utf-8', strings_only=False, errors='strict')
    context = {
        'url': encoded_client_id
    }
    return render(request, 'email/index.html', context)
