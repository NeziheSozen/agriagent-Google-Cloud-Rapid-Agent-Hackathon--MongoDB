"""
Common Pydantic v2 base model and helpers for MongoDB integration.

``PyObjectId`` transparently converts between BSON ``ObjectId`` and ``str``
so FastAPI JSON responses contain plain string IDs while MongoDB stores
native ObjectIds.
"""

from __future__ import annotations

from typing import Annotated, Any

from bson import ObjectId
from pydantic import BaseModel, ConfigDict, Field
from pydantic.functional_validators import BeforeValidator
from pydantic.functional_serializers import PlainSerializer
from pydantic import WithJsonSchema


def _validate_object_id(v: Any) -> ObjectId:
    """Accept str or ObjectId and always return an ObjectId."""
    if isinstance(v, ObjectId):
        return v
    if isinstance(v, str) and ObjectId.is_valid(v):
        return ObjectId(v)
    raise ValueError(f"Invalid ObjectId: {v!r}")


PyObjectId = Annotated[
    ObjectId,
    BeforeValidator(_validate_object_id),
    PlainSerializer(lambda v: str(v), return_type=str),
    WithJsonSchema({"type": "string"}, mode="serialization"),
]
"""
Custom type that stores as ``ObjectId`` internally but serializes to
``str`` in JSON. Use with ``Field(alias="_id", default_factory=ObjectId)``.
"""


class MongoBaseModel(BaseModel):
    """
    Base model for documents stored in MongoDB.

    * Maps the Mongo ``_id`` field to a Pydantic ``id`` attribute.
    * Enables ``populate_by_name`` so both ``id`` and ``_id`` work.
    """

    id: PyObjectId = Field(alias="_id", default_factory=ObjectId)

    model_config = ConfigDict(
        populate_by_name=True,
        arbitrary_types_allowed=True,
    )
