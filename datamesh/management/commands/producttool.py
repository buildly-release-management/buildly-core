import json
from datamesh.models import JoinRecord, Relationship, LogicModuleModel
from core.models import LogicModule, Organization
import re


def product_tool_users_relationship():
    """
     product_tool <-> users -  service and core model join.
     Load product_tool with user_uuid from json file and write the data directly into the JoinRecords.
     open json file from data directory in root path.
    """

    model_json_file = "ProductTeam.json"

    # load json file and take data into model_data variable
    with open(model_json_file, 'r', encoding='utf-8') as model_data:
        model_data = json.load(model_data)

    # get logic module from core
    origin_logic_module = LogicModule.objects.get(endpoint_name='product')

    # get or create datamesh Logic Module Model
    origin_model, _ = LogicModuleModel.objects.get_or_create(
        model='ProductTools',
        logic_module_endpoint_name=origin_logic_module.endpoint_name,
        endpoint='/producttools/',
        lookup_field_name='product_tool_uuid',

    )

    related_model, _ = LogicModuleModel.objects.get_or_create(
        model='CoreUser',
        logic_module_endpoint_name="core",
        endpoint='/coreuser/',
        lookup_field_name='core_user_uuid',
        is_local=True,
    )

    # get or create relationship of origin_model and related_model in datamesh
    relationship, _ = Relationship.objects.get_or_create(
        origin_model=origin_model,
        related_model=related_model,
        key='product_tool_user_relationship'
    )
    eligible_join_records = []
    counter = 0

    # iterate over loaded JSON data
    for data in model_data:

        counter += 1

        # get item ids from model data
        user_uuid = data['fields']['users']
        # check if shipment_uuid is null or not
        if not user_uuid:
            continue

        # convert uuid string to list
        user_uuid_list = re.findall(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){4}[0-9a-f]{8}', user_uuid)

        for user_uuid in user_uuid_list:
            # get uuid from string
            # create join record
            join_record, _ = JoinRecord.objects.get_or_create(
                relationship=relationship,
                record_uuid=data['pk'],
                related_record_uuid=user_uuid,
                defaults={'organization': None}
            )
            print(join_record)
            # append eligible join records
            eligible_join_records.append(join_record.pk)

    print(f'{counter} product_tool <-> users parsed and written to the JoinRecords.')

    # delete not eligible JoinRecords in this relationship
    deleted, _ = JoinRecord.objects.exclude(pk__in=eligible_join_records).filter(relationship=relationship).delete()
    print(f'{deleted} JoinRecord(s) deleted.')
