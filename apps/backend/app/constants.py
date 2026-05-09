import uuid_utils


DEFAULT_USER_ID = "00000000-0000-7000-8000-000000000001"

SUBTYPE_PERSONA_JOINED = "persona_joined"
SUBTYPE_PERSONA_LEFT = "persona_left"
SUBTYPE_CHAPTER_BOUNDARY = "chapter_boundary"
SUBTYPE_ORCHESTRATOR_SUGGESTION_ACCEPTED = "orchestrator_suggestion_accepted"
SUBTYPE_MODE_CHANGED = "mode_changed"


def new_uuid() -> str:
    return str(uuid_utils.uuid7())
