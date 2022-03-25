from typing import Union
from datamesh.utils import validate_join, delete_join_record, join_record
from gateway.clients import SwaggerClient

import gateway.request as gateway_request


class RequestHandler:

    def __init__(self):
        self.relationship_data, self.request_kwargs = None, None
        self.query_params, self.request_param = None, None
        self.resp_data, self.request_method = None, None
        self.fk_field_name, self.is_forward_lookup = None, None
        self.related_model_pk_name, self.origin_model_pk_name = None, None
        self.organization, self.request, self.relation_data = None, None, None

    def validate_request(self, relationship: str, relationship_data: Union[dict, list], request_kwargs: dict):
        """
        Here we are getting relation,relation data request kwargs from the retrieve_relationship_data function.
        In This function we are validating incoming request and forwarding that request to respective function to
        perform datamesh join.
        """

        # update the variable
        self.organization = self.request.session.get('jwt_organization_uuid', None)
        self.origin_model_pk_name = request_kwargs['request_param'][relationship]['origin_model_pk_name']
        self.related_model_pk_name = request_kwargs['request_param'][relationship]['related_model_pk_name']

        self.fk_field_name = request_kwargs['request_param'][relationship]['fk_field_name']
        self.is_forward_lookup = request_kwargs['request_param'][relationship]['is_forward_lookup']
        self.relation_data = relationship_data

        # post the origin_model model data and create join with related_model
        if self.request.method in ['POST'] and 'extend' in self.query_params:
            origin_model_pk = self.resp_data[self.origin_model_pk_name]
            related_model_pk = self.request.data[self.related_model_pk_name]
            return join_record(relationship=relationship, origin_model_pk=origin_model_pk, related_model_pk=related_model_pk, pk_dict=None)

        # update the created object reference to request_relationship_data
        if self.request.method in ['POST'] and 'join' in self.query_params:
            self.prepare_create_request(relationship=relationship)

        # for the PUT/PATCH request update PK in request param
        if self.request.method in ['PUT', 'PATCH'] and 'join' in self.query_params:
            self.relation_data = self.prepare_update_request(relationship=relationship)
            if not self.relation_data:
                return

        # perform request
        self.perform_request(relationship=relationship, relation_data=self.relation_data)

    def prepare_create_request(self, relationship: str):

        pk = self.resp_data.get(self.origin_model_pk_name)
        if not self.is_forward_lookup:
            pk = self.resp_data.get(self.related_model_pk_name)

        if pk and self.fk_field_name:
            if self.fk_field_name in self.relation_data.data:
                self.relation_data.data[self.fk_field_name] = pk
            self.request_param[relationship]['method'] = self.request_method
        else:
            return

    def prepare_update_request(self, relationship: str):
        """
        Datamesh update request have the following cases:
        1.If the UUID/ID(pk) haven’t been sent for the relation PUT request data in this case datamesh is creating
        that object and join
        2.If the UUID/ID(pk)  is present in the relation data then we're performing the original request i.e PUT or PATCH
        3.The relation that only needs to update ID or UUID: for some relation we don't need to perform CRUD operation we're
        always going to update the reference(pk) in other model
        """

        # retrieving values for reversed relation by checking is_forward_lookup var flag
        if not self.request_param[relationship]['is_forward_lookup']:
            pk = self.relationship_data.data.get(self.origin_model_pk_name)
            res_pk = self.resp_data.get(self.related_model_pk_name)
        else:
            # retrieving values for forward relation
            pk = self.relationship_data.data.get(self.related_model_pk_name)
            res_pk = self.resp_data.get(self.origin_model_pk_name)

        if not pk:
            # Note : Not updating fk reference considering when we're updating we have it already on request relation data
            if self.fk_field_name in self.relationship_data.data.keys():
                # update the method as we are creating relation object and save pk to none as we are performing post request
                self.relationship_data.data[self.fk_field_name] = pk
            self.request_param[relationship]['pk'], self.request.method = None, 'POST'
        else:
            # update the request and param method to original.as considering for above condition(case 1) request method might be updated.
            self.request.method, self.request_param[relationship]['method'] = self.request_method, self.request_method
            self.request_param[relationship]['pk'] = pk

            """
            If have join and previous_pk var in relation data then delete join record for the current relation which 
            contain previous_pk and create join with relation data pk else update current relation data
            """
            if ("join" and "previous_pk") in self.relationship_data.data:
                origin_model_pk_name = self.request_param[relationship]['origin_model_pk_name']
                related_model_pk_name = self.request_param[relationship]['related_model_pk_name']

                # delete join record for the current relation which contain previous_pk
                delete_join_record(pk=res_pk, previous_pk=self.relationship_data.data['previous_pk'])

                # fetch values from response data and relation data to create join
                # retrieving values considering forward relation
                origin_model_pk = self.resp_data.get(origin_model_pk_name)
                related_model_pk = self.relationship_data.data.get(related_model_pk_name)

                # if not forward relation update the values and create join
                if not self.request_param[relationship]['is_forward_lookup']:
                    origin_model_pk = self.relationship_data.data.get(origin_model_pk_name)
                    related_model_pk = self.resp_data.get(related_model_pk_name)

                validate_join(origin_model_pk=origin_model_pk, related_model_pk=related_model_pk, relationship=relationship)

                return False

        return self.relationship_data

    def retrieve_relationship_data(self, request_kwargs: dict):
        """
        This function will work following way:
        1.It will retrieve the datamesh relation and relation related required data
        2.After that iterate over request data and retrieving the relation data
        3.As relation data is always in array formate so function will iterate over relation data
        4.For each relation data the class values will update, and it will remain same till the relation request execution
        """

        # update the variable
        self.resp_data = request_kwargs.get('resp_data', None)
        self.request = request_kwargs['request']
        self.request_kwargs = request_kwargs
        self.request_method = request_kwargs['request_method']
        self.request_param = request_kwargs['request_param']
        self.query_params = request_kwargs['query_params']

        # iterate over the datamesh relationships
        self.relationship_data = {}
        for relationship in request_kwargs['datamesh_relationship']:  # retrieve relationship data from request.data
            self.relationship_data[relationship] = self.request.data.get(relationship)

        for relationship, data in self.relationship_data.items():  # iterate over the relationship and data
            if not data:
                # if data is empty then check the related relation pk is preset on origin request response
                # or not else continue
                self.validate_relationship_data(relationship=relationship, resp_data=self.resp_data)
                continue

            # iterate over the relationship data as the data always in list
            for instance in data:
                self.request.method = self.request_method

                # clearing all the form current request and updating it with related data the going to POST/PUT
                self.relationship_data = self.request  # copy the request data to another variable
                self.relationship_data.data.clear()  # clear request.data.data
                self.relationship_data.data.update(instance)  # update the relationship_data to request.data to perform request

                # validate request
                self.validate_request(relationship=relationship, relationship_data=self.relationship_data, request_kwargs=request_kwargs)

    def perform_request(self, relationship: str, relation_data: any):
        """
        In this function all the relation request ['POST', 'PUT', 'PATCH'] will call and will create join with origin request
        response model pk with relation request response model pk.
        """
        # allow only if origin model needs to update or create
        if self.request.method in ['POST', 'PUT', 'PATCH'] and 'join' in self.query_params:

            # create a client for performing data requests
            g_request = gateway_request.GatewayRequest(self.request_kwargs['request'])
            spec = g_request._get_swagger_spec(self.request_param[relationship]['service'])
            client = SwaggerClient(spec, relation_data)

            # perform a service data request
            content, status_code, headers = client.request(**self.request_param[relationship])

            if self.request.method in ['POST'] and 'join' in self.query_params:  # create join record

                related_model_pk = content[self.request_param[relationship]['related_model_pk_name']]
                origin_model_pk = self.resp_data[self.request_param[relationship]['origin_model_pk_name']]
                if not self.is_forward_lookup:
                    related_model_pk = content[self.request_param[relationship]['related_model_pk_name']]
                    origin_model_pk = self.resp_data[self.request_param[relationship]['origin_model_pk_name']]

                join_record(relationship=relationship, origin_model_pk=origin_model_pk, related_model_pk=related_model_pk, pk_dict=None)

    def validate_relationship_data(self, resp_data: Union[dict, list], relationship: str):
        """
        This function will work following way:
        If the request data has empty array relation like --> '"product_item_relation": []' so for this
        relation this function will check for existing join if we don't have join then it will create it
        with origin request model pk
        """

        # retrieve fk name
        fk_field_name = self.request_param[relationship]['fk_field_name']

        # retrieve pk from origin request response
        origin_lookup_field_uuid = resp_data.get(self.request_param[relationship]['origin_model_pk_name'], None)
        related_lookup_field_uuid = resp_data.get(fk_field_name, None)

        """
        Note: we are updating __init__() values in validate_request() function and current function will execute before that because
        of that when we call __init__() values we will get None except some value that we are updating before this function call.
        To call other values we can retrieve from 'self.request_param[relationship][{relation_value_name}]' 
        """

        related_model_pk_name = self.request_param[relationship]['related_model_pk_name']
        fk_field_name = self.request_param[relationship]['fk_field_name']

        # for reverse relation set value to None
        if not self.request_param[relationship]['is_forward_lookup']:
            if related_model_pk_name == fk_field_name:
                resp_data_keys = list(resp_data.keys())
                resp_data_keys.pop(0)
                if fk_field_name in resp_data_keys:
                    origin_lookup_field_uuid = resp_data.get(self.request_param[relationship]['related_model_pk_name'], None)
            else:
                origin_lookup_field_uuid = resp_data.get(self.request_param[relationship]['related_model_pk_name'], None)

        # considering models field might be array-type.
        if related_lookup_field_uuid and origin_lookup_field_uuid:
            if type(related_lookup_field_uuid) == type([]):  # check for array type
                for uuid in related_lookup_field_uuid:  # for each item in array/list
                    related_lookup_field_uuid = uuid
                    # validate the join
                    validate_join(origin_model_pk=origin_lookup_field_uuid, related_model_pk=related_lookup_field_uuid, relationship=relationship)

            elif type(origin_lookup_field_uuid) == type([]):  # check for array type
                for uuid in origin_lookup_field_uuid:  # for each item in array/list
                    origin_lookup_field_uuid = uuid
                    # validate the join
                    validate_join(origin_model_pk=origin_lookup_field_uuid, related_model_pk=related_lookup_field_uuid, relationship=relationship)
            else:
                return validate_join(origin_model_pk=origin_lookup_field_uuid, related_model_pk=related_lookup_field_uuid, relationship=relationship)
