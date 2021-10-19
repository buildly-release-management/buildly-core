from core.serializers import PartnerSerializer
from core.models import Partner
from django.test import TestCase, Client
from rest_framework import status
from rest_framework.request import Request
from rest_framework.test import APIRequestFactory
from django.urls import reverse
import json

client = Client()


class GetAllPartnerTest(TestCase):
    """ Test module for GET all events API """

    def setUp(self):
        self.partner = Partner.objects.create(

        )
        self.factory = APIRequestFactory()
        self.request = self.factory.get('/')
        self.serializer_context = {
            'request': Request(self.request),
        }

    def test_list_all_partner(self):
        # get API response
        response = client.get('/partner/')
        # get data from db
        partner = Partner.objects.all()
        serializer = PartnerSerializer(partner, many=True,
                                       context=self.serializer_context)
        self.assertEqual(response.data, serializer.data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class GetSinglePartnerTest(TestCase):
    """ Test module for GET single partner API """

    def setUp(self):
        self.partner = Partner.objects.create(

        )
        self.factory = APIRequestFactory()
        self.request = self.factory.get('/')
        self.serializer_context = {
            'request': Request(self.request),
        }

    def test_get_valid_single_partner(self):
        url = reverse('partner-detail',
                      kwargs={'pk': self.partner.pk})
        response = client.get(url)
        partner = Partner.objects.get(pk=self.partner.pk)
        serializer = PartnerSerializer(partner,
                                       context=self.serializer_context)
        self.assertEqual(response.data, serializer.data)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_get_invalid_single_partner(self):
        url = reverse('partner-detail', kwargs={'pk': 4330})
        response = client.get(url)
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class CreateNewpartnerTest(TestCase):
    """ Test module for inserting a new partner"""

    def setUp(self):
        self.valid_payload = {"name": "A12"}

    def test_create_valid_partner(self):
        response = client.post(
            reverse('partner-list'),
            data=json.dumps(self.valid_payload),
            content_type='application/json',
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)


class UpdatePartnerTest(TestCase):
    """Test module for updating an existing partner record"""

    def test_valid_update_partner(self):
        self.partner = Partner.objects.create(

        )
        updated_data = {"name": 'update test'}
        response = client.put(
            reverse('partner-detail',
                    kwargs={'pk': str(self.partner.pk)}),
            data=json.dumps(updated_data),
            content_type='application/json',
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)


class DeleteSinglePartnerTest(TestCase):
    """ Test module for deleting an existing partner record """

    def setUp(self):
        self.partner = Partner.objects.create(name='test name')

    def test_valid_delete_partner(self):
        response = client.delete(reverse('partner-detail',
                                         kwargs={'pk': self.partner.pk}))
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

    def test_invalid_delete_partner(self):
        response = client.delete(reverse('partner-detail',
                                         kwargs={'pk': 300}))
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
