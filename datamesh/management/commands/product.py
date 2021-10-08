import json
from datamesh.models import JoinRecord, Relationship, LogicModuleModel
from core.models import LogicModule


def product_product_tool_relationship():
    """
     product <-> product_tool - within service model join.
     Load product with product_tool_uuid from json file and write the data directly into the JoinRecords.
     open json file from data directory in root path.
    """

    model_json_file = "product.json"

    # load json file and take data into model_data variable
    with open(model_json_file, 'r', encoding='utf-8') as file_data:
        model_data = json.load(file_data)

    # get logic module from core
    origin_logic_module = LogicModule.objects.get(endpoint_name='product')
    related_logic_module = LogicModule.objects.get(endpoint_name='product')

    # get or create datamesh Logic Module Model
    origin_model, _ = LogicModuleModel.objects.get_or_create(
        model='Product',
        logic_module_endpoint_name=origin_logic_module.endpoint_name,
        endpoint='/product/',
        lookup_field_name='product_uuid',
    )

    # get or create datamesh Logic Module Model
    related_model, _ = LogicModuleModel.objects.get_or_create(
        model='ProductTools',
        logic_module_endpoint_name=related_logic_module.endpoint_name,
        endpoint='/producttools/',
        lookup_field_name='product_tool_uuid',
    )

    # get or create relationship of origin_model and related_model in datamesh
    relationship, _ = Relationship.objects.get_or_create(
        origin_model=origin_model,
        related_model=related_model,
        key='product_product_tool_relationship'
    )
    eligible_join_records = []
    counter = 0

    # iterate over loaded JSON data
    for related_data in model_data:

        counter += 1

        product_tool_uuid = related_data['fields']['product_tool']

        if not product_tool_uuid:
            continue

        join_record, _ = JoinRecord.objects.get_or_create(
            relationship=relationship,
            record_uuid=related_data['pk'],
            related_record_uuid=product_tool_uuid,
            defaults={'organization': None}
        )
        print(join_record)
        eligible_join_records.append(join_record.pk)

    print(f'{counter} product <-> product_tool parsed and written to the JoinRecords.')


def product_product_team_relationship():
    """
     product <-> product_team - within service model join.
     Load product with product_team_uuid from json file and write the data directly into the JoinRecords.
     open json file from data directory in root path.
    """

    model_json_file = "product.json"

    # load json file and take data into model_data variable
    with open(model_json_file, 'r', encoding='utf-8') as file_data:
        model_data = json.load(file_data)

    # get logic module from core
    origin_logic_module = LogicModule.objects.get(endpoint_name='product')
    related_logic_module = LogicModule.objects.get(endpoint_name='product')

    # get or create datamesh Logic Module Model
    origin_model, _ = LogicModuleModel.objects.get_or_create(
        model='Product',
        logic_module_endpoint_name=origin_logic_module.endpoint_name,
        endpoint='/product/',
        lookup_field_name='product_uuid',
    )

    # get or create datamesh Logic Module Model
    related_model, _ = LogicModuleModel.objects.get_or_create(
        model='ProductTeam',
        logic_module_endpoint_name=related_logic_module.endpoint_name,
        endpoint='/productteam/',
        lookup_field_name='product_team_uuid',
    )

    # get or create relationship of origin_model and related_model in datamesh
    relationship, _ = Relationship.objects.get_or_create(
        origin_model=origin_model,
        related_model=related_model,
        key='product_product_team_relationship'
    )
    eligible_join_records = []
    counter = 0

    # iterate over loaded JSON data
    for related_data in model_data:

        counter += 1

        product_team_uuid = related_data['fields']['product_team']

        if not product_team_uuid:
            continue

        join_record, _ = JoinRecord.objects.get_or_create(
            relationship=relationship,
            record_uuid=related_data['pk'],
            related_record_uuid=product_team_uuid,
            defaults={'organization': None}
        )
        print(join_record)
        eligible_join_records.append(join_record.pk)

    print(f'{counter} product <-> product_team parsed and written to the JoinRecords.')


