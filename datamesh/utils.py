from typing import Tuple

from django.db.models import Q

from datamesh.models import Relationship, JoinRecord, LogicModuleModel
from gateway.utils import valid_uuid4


def prepare_lookup_kwargs(is_forward_lookup: bool,
                          relationship: Relationship,
                          join_record: JoinRecord) -> Tuple[LogicModuleModel, str]:
    """Find out if pk is id or uuid and prepare lookup according to direction."""
    if is_forward_lookup:
        related_model = relationship.related_model
        related_record_field = 'related_record_id' if join_record.related_record_id is not None \
            else 'related_record_uuid'
    else:
        related_model = relationship.origin_model
        related_record_field = 'record_id' if join_record.record_id is not None \
            else 'record_uuid'

    return related_model, related_record_field


def validate_join(record_uuid: [str, int], related_record_uuid: [str, int], relationship: str) -> None:
    """This function is validating the join if the join not created, yet then it will create the join """
    pk_dict = validate_primary_key(origin_model_pk=record_uuid, related_model_pk=related_record_uuid)

    join_record_instance = JoinRecord.objects.filter(**pk_dict, relationship__key=relationship)
    if not join_record_instance:
        join_record(pk_dict=pk_dict, relationship=relationship, origin_model_pk=None, related_model_pk=None)


def join_record(relationship: str, origin_model_pk: [str, int], related_model_pk: [str, int], pk_dict: [dict, None]) -> None:
    """This function will create datamesh join"""

    if not pk_dict:
        pk_dict = validate_primary_key(origin_model_pk=origin_model_pk, related_model_pk=related_model_pk)

    JoinRecord.objects.create(
        relationship=Relationship.objects.filter(key=relationship).first(),
        **pk_dict,
        organization_id=None
    )


def delete_join_record(pk: [str, int], previous_pk: [str, int]):
    pk_query_set = JoinRecord.objects.filter(Q(record_uuid__icontains=pk) | Q(related_record_uuid__icontains=pk)
                                             | Q(record_id__icontains=pk) | Q(related_record_id__icontains=pk))
    if previous_pk and pk:
        pk_dict = validate_primary_key(origin_model_pk=pk, related_model_pk=previous_pk)
        pk_query_set.filter(**pk_dict).delete()

        pk_dict = validate_primary_key(origin_model_pk=previous_pk, related_model_pk=pk)
        pk_query_set.filter(**pk_dict).delete()
        return True

    if pk and not previous_pk:
        return pk_query_set.delete()


def validate_primary_key(origin_model_pk: [str, int], related_model_pk: [str, int]):
    origin_pk_type = 'uuid' if valid_uuid4(str(origin_model_pk)) else 'id'
    related_pk_type = 'uuid' if valid_uuid4(str(related_model_pk)) else 'id'

    if origin_pk_type == 'id' and related_pk_type == 'id':
        return {
            "record_id": origin_model_pk,
            "related_record_id": related_model_pk
        }

    elif origin_pk_type == 'uuid' and related_pk_type == 'uuid':
        return {
            "record_uuid": origin_model_pk,
            "related_record_uuid": related_model_pk
        }

    elif origin_pk_type == 'uuid' and related_pk_type == 'id':
        return {
            "record_uuid": origin_model_pk,
            "related_record_id": related_model_pk
        }

    elif origin_pk_type == 'id' and related_pk_type == 'uuid':
        return {
            "record_id": origin_model_pk,
            "related_record_uuid": related_model_pk
        }
