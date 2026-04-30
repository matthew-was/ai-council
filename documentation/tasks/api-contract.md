# API Contract — AI Council

## Status

Unapproved — 2026-04-27

## Authentication

V1: No authentication. All requests are accepted without an `Authorization` header. The `CurrentUserMiddleware` resolves the request user to `DEFAULT_USER_ID = '00000000-0000-7000-8000-000000000001'` on every request. The auth upgrade seam (ADR-016) means future authentication requires only changing the body of `resolve_current_user()`.

The frontend must centralise all request construction in a single utility so that authentication headers can be added later without component-level changes.

CORS: The backend must serve appropriate `Access-Control-Allow-Origin` headers. The allowed origins value is configurable in `backend/config.json` (with override in `backend/config.override.json`) to support both local development and Docker Compose production deployment.

---

## Error Response Shape

All error responses return a JSON body with the following shape:

```json
{
  "message": "string — human-readable description",
  "code": "string — optional machine-readable code (e.g. PERSONA_ACTIVE_IN_CONVERSATION)"
}
```

`422 Unprocessable Entity` (validation errors) returns FastAPI's default Pydantic validation error shape:

```json
{
  "detail": [
    {
      "loc": ["body", "field_name"],
      "msg": "string",
      "type": "string"
    }
  ]
}
```

All `5xx` errors return `{ "message": "string" }`. The frontend must handle non-JSON responses gracefully (e.g. a gateway 502 HTML page) without crashing.

---

## Data Model Summary

Key entities and relationships:

- **Workspace** — top-level isolation boundary; scopes all other entities
- **Persona** — user-created advisory character with name, system prompt, temperature; exactly one per Workspace may have `is_mentor: true`
- **persona_system_prompt_versions** — append-only history; a row is inserted on every system prompt write
- **Conversation** — a conversation session; `is_mentor_conversation` is a persisted boolean set once at creation; exactly one per Workspace has `is_mentor_conversation: true`
- **conversation_personas** — participation snapshot per Persona per Conversation; multiple rows per `(conversation_id, persona_id)` pair are valid (one per join event); active participants are rows with the most recent `joined_at` per persona where `left_at IS NULL`
- **Message** — conversation message; `role` is `user | persona | mentor | system`; system messages carry a `message_subtype` discriminator
- **Folder** — optional grouping for Conversations
- **Document** — system-generated Report; `status` tracks async generation
- **orchestrator_suggestions** — server-side record of each Orchestrator suggestion
- **review_agent_findings** — Persona improvement suggestions from the Review Agent; `status` enum is `active | stale | actioned | dismissed`
- **mentor_episodic_memories** — Episodic Memory layer for the Mentor
- **mentor_semantic_memories** — Semantic Memory layer for the Mentor
- **review_agent_runs** — audit log and run-lock for the Review Agent scheduler

All primary keys are UUID v7 (time-ordered). All Workspace-scoped tables carry `workspace_id` (NOT NULL FK) and `user_id` (NOT NULL FK).

---

## Workspaces

### GET /workspaces — List All Workspaces

**Purpose**: Return all Workspaces. Used to populate the top-level navigation dropdown.

**Request**: No body. No query parameters.

**Response** `200 OK`:

```json
{
  "workspaces": [
    {
      "id": "string (UUID v7)",
      "name": "string",
      "created_at": "string (ISO 8601 timestamptz)",
      "context_panel_max_chars": "integer"
    }
  ]
}
```

`context_panel_max_chars` is included on every Workspace response so the frontend has the enforced character limit before the user opens any Conversation. Value is read from `CONTEXT_PANEL_MAX_CHARS` in backend configuration. This value is the same for all Workspaces (it is a system-wide operator config, not per-Workspace data), but is embedded here to avoid a separate config round-trip.

**Error responses**:
- `500 Internal Server Error`: Database or server error.

**Notes**: The list is not paginated. Ordered by `created_at` ascending in the response; the frontend may re-sort. The frontend must not hardcode `CONTEXT_PANEL_MAX_CHARS` — it must always read this value from the API response.

---

### GET /workspaces/{workspace_id} — Get a Single Workspace

**Purpose**: Return a single Workspace's details. Used when loading the active Workspace on switch.

**Request**:
- Path: `workspace_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "name": "string",
  "created_at": "string (ISO 8601 timestamptz)",
  "context_panel_max_chars": "integer"
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.

---

### POST /workspaces — Create a Workspace

**Purpose**: Create a new named Workspace.

**Request**:

```json
{
  "name": "string (required, non-empty)"
}
```

**Response** `201 Created`:

```json
{
  "id": "string (UUID v7)",
  "name": "string",
  "created_at": "string (ISO 8601 timestamptz)",
  "context_panel_max_chars": "integer"
}
```

**Error responses**:
- `422 Unprocessable Entity`: `name` is missing or empty.

---

### PATCH /workspaces/{workspace_id} — Rename a Workspace

**Purpose**: Update the name of an existing Workspace.

**Request**:
- Path: `workspace_id` (UUID v7, required)

```json
{
  "name": "string (required, non-empty)"
}
```

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "name": "string",
  "created_at": "string (ISO 8601 timestamptz)",
  "context_panel_max_chars": "integer"
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.
- `422 Unprocessable Entity`: `name` is empty.

---

### DELETE /workspaces/{workspace_id} — Delete a Workspace

**Purpose**: Permanently delete a Workspace and all its content.

**Request**:
- Path: `workspace_id` (UUID v7, required)

**Response** `204 No Content`

**Error responses**:
- `404 Not Found`: Workspace does not exist.

**Notes**: This is a cascading delete. The backend deletes in order: messages, conversation_personas, conversation_summaries, LangGraph checkpointer state for all Conversations in the Workspace, conversations, orchestrator_suggestions, folders, review_agent_findings, review_agent_runs, mentor_episodic_memories, mentor_semantic_memories, persona_system_prompt_versions, personas, and finally the Workspace itself. If a Review Agent run is currently `running` for this Workspace, the backend sets it to `failed` before deleting. No partial state is returned — the frontend treats a `204` as complete success.

---

## Personas

### GET /workspaces/{workspace_id}/personas — List Personas

**Purpose**: Return all Personas in a Workspace. Used to populate the Personas area and Persona selection in the new Conversation flow.

**Request**:
- Path: `workspace_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "personas": [
    {
      "id": "string (UUID v7)",
      "name": "string",
      "description": "string | null",
      "system_prompt": "string",
      "temperature": "number (float, 0.0–2.0)",
      "is_mentor": "boolean",
      "created_at": "string (ISO 8601 timestamptz)",
      "updated_at": "string (ISO 8601 timestamptz)"
    }
  ]
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.

**Notes**: Ordered by `created_at` ascending. The `is_mentor` flag distinguishes the Mentor from standard Personas. The `updated_at` timestamp is used by the frontend to determine whether a Persona's live configuration differs from a Conversation snapshot (for the snapshot refresh control — US-C5).

---

### GET /workspaces/{workspace_id}/personas/{persona_id} — Get a Single Persona

**Purpose**: Load full Persona configuration for the Persona profile page.

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "name": "string",
  "description": "string | null",
  "system_prompt": "string",
  "temperature": "number (float, 0.0–2.0)",
  "is_mentor": "boolean",
  "created_at": "string (ISO 8601 timestamptz)",
  "updated_at": "string (ISO 8601 timestamptz)"
}
```

**Error responses**:
- `404 Not Found`: Persona or Workspace does not exist.

---

### POST /workspaces/{workspace_id}/personas — Create a Persona

**Purpose**: Create a new Persona. Also used to create the Mentor (with `is_mentor: true`).

**Request**:
- Path: `workspace_id` (UUID v7, required)

```json
{
  "name": "string (required, non-empty)",
  "system_prompt": "string (required, non-empty)",
  "description": "string | null (optional, defaults to null)",
  "temperature": "number (required, float, 0.0–2.0)",
  "is_mentor": "boolean (optional, defaults to false)"
}
```

**Response** `201 Created`:

```json
{
  "id": "string (UUID v7)",
  "name": "string",
  "description": "string | null",
  "system_prompt": "string",
  "temperature": "number",
  "is_mentor": "boolean",
  "created_at": "string (ISO 8601 timestamptz)",
  "updated_at": "string (ISO 8601 timestamptz)"
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.
- `409 Conflict`: `is_mentor: true` but a Mentor already exists in this Workspace. Body: `{ "message": "A Mentor already exists in this Workspace", "code": "MENTOR_ALREADY_EXISTS" }`.
- `422 Unprocessable Entity`: `name` or `system_prompt` is empty; `temperature` is out of range.

**Notes**: The backend inserts a corresponding row in `persona_system_prompt_versions` in the same transaction as the Persona row (universal versioning rule — architecture section 5.2). When a Persona is created with `is_mentor: true`, the backend also automatically creates the Mentor Conversation record (a Conversation row with `is_mentor_conversation: true`, `mode: one_to_one`, `status: active`, and no initial participants — the Mentor is the implicit participant accessed via the live System Prompt rather than a `conversation_personas` snapshot, per architecture section 8.2).

---

### PATCH /workspaces/{workspace_id}/personas/{persona_id} — Update a Persona

**Purpose**: Save edits to an existing Persona's fields.

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required)

```json
{
  "name": "string (optional, non-empty if present)",
  "description": "string | null (optional)",
  "system_prompt": "string (optional, non-empty if present)",
  "temperature": "number (optional, float, 0.0–2.0 if present)"
}
```

Any subset of fields may be sent. Fields not present are unchanged.

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "name": "string",
  "description": "string | null",
  "system_prompt": "string",
  "temperature": "number",
  "is_mentor": "boolean",
  "created_at": "string (ISO 8601 timestamptz)",
  "updated_at": "string (ISO 8601 timestamptz)"
}
```

**Error responses**:
- `404 Not Found`: Persona or Workspace does not exist.
- `409 Conflict`: Attempt to change `name` on a Mentor Persona. Body: `{ "message": "The Mentor name cannot be changed after creation", "code": "MENTOR_NAME_IMMUTABLE" }`.
- `422 Unprocessable Entity`: Validation failure (empty `name` or `system_prompt`, out-of-range `temperature`).

**Notes**: If `system_prompt` is included in the request, the backend inserts a row in `persona_system_prompt_versions` in the same transaction as the `personas` update (universal versioning rule). After any `system_prompt` change, the backend checks all `active` findings for this Persona — any whose `target_passage` is no longer present in the new prompt are immediately set to `stale` (architecture section 5.5). The `updated_at` timestamp is updated on every successful PATCH.

---

### DELETE /workspaces/{workspace_id}/personas/{persona_id} — Delete a Persona

**Purpose**: Delete a Persona that is not active in any open Conversation.

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required)

**Response** `204 No Content`

**Error responses**:
- `404 Not Found`: Persona or Workspace does not exist.
- `409 Conflict` (active in open Conversations): Body:

```json
{
  "message": "This Persona is active in one or more open Conversations",
  "code": "PERSONA_ACTIVE_IN_CONVERSATION",
  "blocking_conversations": [
    { "id": "string", "title": "string" }
  ]
}
```

- `409 Conflict` (is Mentor): Body: `{ "message": "The Mentor cannot be deleted — delete the Workspace to remove it", "code": "MENTOR_CANNOT_BE_DELETED" }`.

**Notes**: The backend performs an application-layer check: queries `conversation_personas` for rows where `left_at IS NULL` joined to `conversations` where `status = 'active'` for the given `persona_id`. If any exist, returns 409. On successful delete, the Persona row is removed; `conversation_personas.persona_id` for concluded Conversations is set to NULL (preserving snapshots per ADR-006). Review Agent findings for this Persona are also deleted.

---

## Persona Test (Preview Mode)

### POST /personas/{persona_id}/test — Send a Test Message

**Purpose**: Send a test message to a Persona and receive a streamed response. Does not persist any messages. Used by the Persona Test panel (US-P5).

**Request**:
- Path: `persona_id` (UUID v7, required)

```json
{
  "message": "string (required, non-empty)",
  "session_id": "string (required, frontend-generated ephemeral UUID for turn context)"
}
```

**Response**: `200 OK` — SSE stream (`Content-Type: text/event-stream`)

Events on the stream:
- `token` event: `{ "content": "string" }`
- `response_complete` event: `{ "content": "string" }`

**Error responses**:
- `404 Not Found`: Persona does not exist.
- `422 Unprocessable Entity`: `message` or `session_id` missing.
- `503 Service Unavailable`: Model backend unavailable.

**Notes**: The backend maintains an in-memory session keyed by `session_id` for multi-turn context within a test session. Test session messages are never written to the `messages` table or any other persistent table. The session is discarded after a configurable inactivity timeout (implementation detail). The test runs against the Persona's current saved `system_prompt` and `temperature` from the `personas` table — not a snapshot. Uses `ModelGateway.stream` (architecture section 6.1). No `Last-Event-ID` reconnection is required for test sessions (sessions are ephemeral). This endpoint is at `/personas/{persona_id}/test` rather than under the workspace path for ergonomics; workspace scoping is enforced by the ORM listener.

---

## Conversations

### GET /workspaces/{workspace_id}/conversations — List Conversations

**Purpose**: Return all Conversations in a Workspace for the Discussions sidebar.

**Request**:
- Path: `workspace_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "conversations": [
    {
      "id": "string (UUID v7)",
      "title": "string",
      "mode": "one_to_one | round_robin | p2p",
      "status": "active | ended",
      "is_mentor_conversation": "boolean",
      "folder_id": "string (UUID v7) | null",
      "pinned_at": "string (ISO 8601 timestamptz) | null",
      "created_at": "string (ISO 8601 timestamptz)",
      "last_message_at": "string (ISO 8601 timestamptz) | null",
      "ended_at": "string (ISO 8601 timestamptz) | null"
    }
  ]
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.

**Notes**: `last_message_at` is updated on every new message and is used by the frontend to sort standalone Conversations by most recent activity. `is_mentor_conversation` is a persisted boolean set once at Conversation creation and never changed. Exactly one Conversation per Workspace will have `is_mentor_conversation: true` (created automatically when the Mentor Persona is created). The frontend uses this flag to identify and render the Mentor slot in the sidebar without a dedicated endpoint (FC-2 resolution). Ordering is left to the frontend; the backend returns the full list unsorted.

---

### GET /workspaces/{workspace_id}/conversations/{conversation_id} — Get a Single Conversation

**Purpose**: Load the full Conversation detail when the user opens a Conversation, including active participants and their snapshots.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "title": "string",
  "mode": "one_to_one | round_robin | p2p",
  "status": "active | ended",
  "is_mentor_conversation": "boolean",
  "context_panel": "string",
  "folder_id": "string (UUID v7) | null",
  "pinned_at": "string (ISO 8601 timestamptz) | null",
  "created_at": "string (ISO 8601 timestamptz)",
  "ended_at": "string (ISO 8601 timestamptz) | null",
  "last_message_at": "string (ISO 8601 timestamptz) | null",
  "chapter_prompt_required": "boolean",
  "auto_summary": {
    "key_takeaways": ["string"],
    "points_of_agreement": ["string"],
    "points_of_disagreement": ["string"],
    "action_items": ["string"]
  },
  "participants": [
    {
      "conversation_persona_id": "string (UUID v7)",
      "persona_id": "string (UUID v7) | null",
      "snapshot_name": "string",
      "snapshot_system_prompt": "string",
      "snapshot_temperature": "number",
      "joined_at": "string (ISO 8601 timestamptz)",
      "left_at": "string (ISO 8601 timestamptz) | null"
    }
  ]
}
```

`auto_summary` is `null` when pending or not yet generated.

**Error responses**:
- `404 Not Found`: Conversation or Workspace does not exist.

**Notes**:

`auto_summary` is `null` while pending (immediately after `POST /conversations/{id}/end` and during async summary generation) and is populated once complete. The frontend polls by re-fetching this endpoint when returning to an ended Conversation to check for the completed summary.

`chapter_prompt_required` is `true` when the Conversation is the Mentor Conversation (`is_mentor_conversation: true`), has prior messages, and `last_message_at` is on a different calendar date than today (UTC). The frontend uses this to present the "Continue / Start fresh chapter" prompt (US-M4). For non-Mentor Conversations and for the Mentor Conversation on the same calendar day as the last message, this field is always `false`.

`participants` returns all `conversation_personas` rows (both active and those with `left_at` set). The frontend uses `left_at` to distinguish currently active participants from those who have left. `persona_id` is nullable — it is `null` if the Persona was subsequently deleted; the `snapshot_name` and other snapshot fields remain intact.

The Mentor Conversation has no `participants` entries because the Mentor is accessed via the live System Prompt rather than a snapshot (architecture section 8.2). For the Mentor Conversation, `participants` is always an empty array.

---

### POST /workspaces/{workspace_id}/conversations — Create a Conversation

**Purpose**: Create a new Conversation with an initial set of Persona participants.

**Request**:
- Path: `workspace_id` (UUID v7, required)

```json
{
  "mode": "one_to_one | round_robin | p2p (required)",
  "persona_ids": ["string (UUID v7) — required, min 1 element"],
  "folder_id": "string (UUID v7) | null (optional, defaults to null)"
}
```

**Response** `201 Created`:

```json
{
  "id": "string (UUID v7)",
  "title": "string",
  "mode": "one_to_one | round_robin | p2p",
  "status": "active",
  "is_mentor_conversation": false,
  "context_panel": "",
  "folder_id": "string (UUID v7) | null",
  "pinned_at": null,
  "created_at": "string (ISO 8601 timestamptz)",
  "ended_at": null,
  "last_message_at": null,
  "chapter_prompt_required": false,
  "auto_summary": null,
  "participants": [
    {
      "conversation_persona_id": "string (UUID v7)",
      "persona_id": "string (UUID v7)",
      "snapshot_name": "string",
      "snapshot_system_prompt": "string",
      "snapshot_temperature": "number",
      "joined_at": "string (ISO 8601 timestamptz)",
      "left_at": null
    }
  ]
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist, or one or more `persona_ids` do not exist in this Workspace.
- `422 Unprocessable Entity`: `mode` is invalid; `persona_ids` is empty; mode/participant count mismatch (e.g. `one_to_one` with multiple Persona IDs); a Mentor Persona ID is included (use the dedicated Mentor Conversation instead).

**Notes**: The title is set by the backend to `"New Conversation [ISO timestamp]"` at creation. The backend captures snapshots of all specified Personas into `conversation_personas` rows. The Mentor Persona ID must not be included in `persona_ids` — the Mentor Conversation is automatically created when the Mentor Persona is created and is accessed via the Conversation list. The first user message is sent separately via `POST /conversations/{id}/messages`.

---

### PATCH /workspaces/{workspace_id}/conversations/{conversation_id} — Update a Conversation

**Purpose**: Update individual mutable fields of a Conversation — title, context panel, folder assignment, pin status, and mode.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)

```json
{
  "title": "string (optional, non-empty if present)",
  "context_panel": "string (optional)",
  "folder_id": "string (UUID v7) | null (optional — null removes from Folder)",
  "pinned_at": "string (ISO 8601 timestamptz) | null (optional — null unpins)",
  "mode": "one_to_one | round_robin | p2p (optional)"
}
```

Any subset of fields may be sent.

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "title": "string",
  "mode": "one_to_one | round_robin | p2p",
  "status": "active | ended",
  "is_mentor_conversation": "boolean",
  "context_panel": "string",
  "folder_id": "string (UUID v7) | null",
  "pinned_at": "string (ISO 8601 timestamptz) | null",
  "created_at": "string (ISO 8601 timestamptz)",
  "ended_at": "string (ISO 8601 timestamptz) | null",
  "last_message_at": "string (ISO 8601 timestamptz) | null",
  "chapter_prompt_required": "boolean",
  "auto_summary": "object | null"
}
```

**Error responses**:
- `404 Not Found`: Conversation or Workspace does not exist.
- `403 Forbidden`: Attempt to modify an ended Conversation.
- `409 Conflict`: Attempt to change `mode` when the Conversation is not idle. Body: `{ "message": "Mode cannot be changed while a response is in progress", "code": "CONVERSATION_NOT_IDLE" }`.
- `409 Conflict`: Mode change is invalid given current participant count. Body: `{ "message": "...", "code": "INVALID_MODE_FOR_PARTICIPANT_COUNT" }`.
- `422 Unprocessable Entity`: `context_panel` exceeds `CONTEXT_PANEL_MAX_CHARS`. Body: `{ "message": "Context Panel exceeds maximum length of {n} characters", "code": "CONTEXT_PANEL_TOO_LONG", "max_chars": integer }`.
- `422 Unprocessable Entity`: Other validation failures.

**Notes**: When `mode` is updated, a system message with `message_subtype: "mode_changed"` is inserted into the Conversation thread. The `context_panel` character limit is enforced against `CONTEXT_PANEL_MAX_CHARS` from backend configuration — the frontend enforces client-side as a courtesy but the backend is authoritative. Participants array is not included in this response — use `GET /conversations/{id}` if the full detail including participants is needed.

---

### POST /workspaces/{workspace_id}/conversations/{conversation_id}/end — End a Conversation

**Purpose**: Transition a Conversation to `ended` status. Has two distinct outcomes depending on whether the Conversation contains any user, persona, or mentor messages.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)
- No request body.

**Response — Normal case** (Conversation has user/persona/mentor messages) `200 OK`:

```json
{
  "deleted": false,
  "conversation": {
    "id": "string (UUID v7)",
    "title": "string",
    "mode": "one_to_one | round_robin | p2p",
    "status": "ended",
    "is_mentor_conversation": "boolean",
    "context_panel": "string",
    "folder_id": "string (UUID v7) | null",
    "pinned_at": "string (ISO 8601 timestamptz) | null",
    "created_at": "string (ISO 8601 timestamptz)",
    "ended_at": "string (ISO 8601 timestamptz)",
    "last_message_at": "string (ISO 8601 timestamptz) | null",
    "chapter_prompt_required": false,
    "auto_summary": null
  }
}
```

`auto_summary` is always `null` in this response — summary generation is async. The frontend shows a "summary being generated" placeholder. The frontend retrieves the completed summary by re-fetching `GET /conversations/{id}` when the user returns to the ended Conversation.

**Response — Empty case** (Conversation has no user/persona/mentor messages) `200 OK`:

```json
{
  "deleted": true,
  "conversation_id": "string (UUID v7)"
}
```

The `deleted: true` flag tells the frontend that the Conversation no longer exists. The frontend removes it from the sidebar and navigates away. No ended Conversation view is rendered.

**Error responses**:
- `404 Not Found`: Conversation or Workspace does not exist.
- `403 Forbidden`: Conversation is already ended.

**Notes**: The backend distinguishes empty from non-empty by querying `messages` for rows with `role IN ('user', 'persona', 'mentor')` for this Conversation. System messages (`role = 'system'`) are excluded — a Conversation with only system messages is treated as empty.

For non-empty Conversations: the backend sets `status = 'ended'` and `ended_at = now()`, then triggers async auto-summary generation via `ModelGateway.invoke_structured` with a `ConversationSummary` Pydantic schema. The summary is written to `conversations.auto_summary` on completion.

For empty Conversations: cascade delete of messages, conversation_personas, conversation_summaries, LangGraph checkpointer state, and the conversations row.

The `auto_summary` structured object shape (when populated):

```json
{
  "key_takeaways": ["string"],
  "points_of_agreement": ["string"],
  "points_of_disagreement": ["string"],
  "action_items": ["string"]
}
```

If a P2P autonomous exchange is in progress when this endpoint is called, the backend cancels the exchange internally (equivalent to the internal effect of `POST /cancel`) before proceeding with the end-of-conversation flow. The frontend calls `POST /end` as a single action regardless of Conversation state — no prior `POST /cancel` call is required.

---

### DELETE /workspaces/{workspace_id}/conversations/{conversation_id} — Delete a Conversation

**Purpose**: Permanently delete a Conversation and its messages. Does not affect Reports generated from it.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)

**Response** `204 No Content`

**Error responses**:
- `404 Not Found`: Conversation or Workspace does not exist.

**Notes**: Cascade deletes: messages, conversation_personas, conversation_summaries, LangGraph checkpointer state. Reports (documents) with `source_conversation_id` pointing to this Conversation are not deleted — their `source_conversation_id` becomes a dangling reference that the frontend handles by suppressing navigation links.

---

## Conversation Participants

### POST /workspaces/{workspace_id}/conversations/{conversation_id}/personas — Add a Persona to a Conversation

**Purpose**: Add a Persona to an active Conversation when the system is idle.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)

```json
{
  "persona_id": "string (UUID v7, required)"
}
```

**Response** `201 Created`:

```json
{
  "conversation_persona": {
    "conversation_persona_id": "string (UUID v7)",
    "persona_id": "string (UUID v7)",
    "snapshot_name": "string",
    "snapshot_system_prompt": "string",
    "snapshot_temperature": "number",
    "joined_at": "string (ISO 8601 timestamptz)",
    "left_at": null
  },
  "system_message": {
    "id": "string (UUID v7)",
    "conversation_id": "string (UUID v7)",
    "conversation_persona_id": null,
    "role": "system",
    "message_subtype": "persona_joined",
    "content": "string",
    "created_at": "string (ISO 8601 timestamptz)"
  }
}
```

**Error responses**:
- `404 Not Found`: Conversation, Workspace, or Persona does not exist in this Workspace.
- `409 Conflict`: Persona is already an active participant in this Conversation.
- `409 Conflict`: Conversation is ended.
- `409 Conflict`: Conversation is not idle. Body: `{ "message": "Cannot modify participants while a response is in progress", "code": "CONVERSATION_NOT_IDLE" }`.
- `422 Unprocessable Entity`: Attempt to add the Mentor Persona to a non-Mentor Conversation.

**Notes**: The backend takes a snapshot of the Persona's current `name`, `system_prompt`, and `temperature` from the `personas` table and inserts a new `conversation_personas` row. It also inserts a system message with `message_subtype: "persona_joined"`.

---

### DELETE /workspaces/{workspace_id}/conversations/{conversation_id}/personas/{conversation_persona_id} — Remove a Persona from a Conversation

**Purpose**: Remove a Persona from an active Conversation when the system is idle.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required), `conversation_persona_id` (UUID v7, required — the snapshot row ID, not the Persona ID)

**Response** `200 OK`:

```json
{
  "conversation_persona": {
    "conversation_persona_id": "string (UUID v7)",
    "persona_id": "string (UUID v7) | null",
    "snapshot_name": "string",
    "snapshot_system_prompt": "string",
    "snapshot_temperature": "number",
    "joined_at": "string (ISO 8601 timestamptz)",
    "left_at": "string (ISO 8601 timestamptz)"
  },
  "system_message": {
    "id": "string (UUID v7)",
    "conversation_id": "string (UUID v7)",
    "conversation_persona_id": null,
    "role": "system",
    "message_subtype": "persona_left",
    "content": "string",
    "created_at": "string (ISO 8601 timestamptz)"
  },
  "updated_mode": "one_to_one | round_robin | p2p | null"
}
```

`updated_mode` is non-null if the mode was automatically downgraded because the remaining active participant count dropped below the mode minimum. The frontend updates the displayed mode if this field is non-null.

**Error responses**:
- `404 Not Found`: Conversation, Workspace, or `conversation_persona_id` does not exist.
- `409 Conflict`: Removing this Persona would leave zero active participants. Body: `{ "message": "Cannot remove the last active Persona from a Conversation", "code": "LAST_PERSONA_IN_CONVERSATION" }`.
- `409 Conflict`: Conversation is ended.
- `409 Conflict`: Conversation is not idle. Body: `{ "message": "Cannot modify participants while a response is in progress", "code": "CONVERSATION_NOT_IDLE" }`.

**Notes**: The backend sets `left_at = now()` on the `conversation_personas` row (the row is not deleted). It inserts a system message with `message_subtype: "persona_left"`. If the remaining active participant count drops below the minimum for the current mode, the mode is automatically downgraded and a system message with `message_subtype: "mode_changed"` is also inserted.

---

### POST /workspaces/{workspace_id}/conversations/{conversation_id}/personas/{conversation_persona_id}/refresh — Refresh a Persona Snapshot

**Purpose**: Replace a Persona's snapshot in an active Conversation with their current live configuration.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required), `conversation_persona_id` (UUID v7, required)
- No request body.

**Response** `201 Created`:

```json
{
  "conversation_persona": {
    "conversation_persona_id": "string (UUID v7)",
    "persona_id": "string (UUID v7)",
    "snapshot_name": "string",
    "snapshot_system_prompt": "string",
    "snapshot_temperature": "number",
    "joined_at": "string (ISO 8601 timestamptz)",
    "left_at": null
  }
}
```

The returned `conversation_persona` is the newly created row. The previous row remains in the database (history preserved, per ADR-006).

**Error responses**:
- `404 Not Found`: The `conversation_persona_id` does not exist, or the Persona has been deleted.
- `409 Conflict`: Conversation is ended.
- `409 Conflict`: Conversation is not idle. Body: `{ "message": "Cannot refresh snapshot while a response is in progress", "code": "CONVERSATION_NOT_IDLE" }`.

**Notes**: The backend inserts a new `conversation_personas` row for the same `persona_id` with the current `system_prompt`, `name`, and `temperature` from the `personas` table and a new `joined_at`. The old row is not modified. Future messages from this Persona use the new snapshot. The frontend hides the refresh control after receiving the response.

---

## Messages

### GET /workspaces/{workspace_id}/conversations/{conversation_id}/messages — List Messages (Paginated)

**Purpose**: Load the message history for a Conversation. Supports cursor-based pagination for long histories.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)
- Query parameters:
  - `before`: string (UUID v7, optional) — cursor; returns messages older than this message ID. If omitted, returns the most recent page.
  - `limit`: integer (optional, default 50, max 200)

**Response** `200 OK`:

```json
{
  "messages": [
    {
      "id": "string (UUID v7)",
      "conversation_id": "string (UUID v7)",
      "conversation_persona_id": "string (UUID v7) | null",
      "role": "user | persona | mentor | system",
      "message_subtype": "persona_joined | persona_left | chapter_boundary | orchestrator_suggestion_accepted | mode_changed | null",
      "content": "string",
      "created_at": "string (ISO 8601 timestamptz)"
    }
  ],
  "has_more": "boolean",
  "next_cursor": "string (UUID v7) | null"
}
```

**Error responses**:
- `404 Not Found`: Conversation or Workspace does not exist.

**Notes**: Messages are returned in ascending order by `created_at` (oldest first within the page). The frontend loads the most recent page first (no `before` cursor on first load), then fetches older pages as the user scrolls up by passing the oldest message ID as the `before` cursor.

`message_subtype` is non-null only for system messages (`role = 'system'`). The values are:
- `persona_joined` — a Persona joined the Conversation
- `persona_left` — a Persona left the Conversation
- `chapter_boundary` — a Mentor chapter boundary was inserted
- `orchestrator_suggestion_accepted` — an Orchestrator suggestion was accepted and the Persona was added
- `mode_changed` — the Conversation mode was changed

For `user`, `persona`, and `mentor` role messages, `message_subtype` is always `null`.

`conversation_persona_id` is null for user messages and system messages. The frontend resolves display names by cross-referencing `conversation_persona_id` with the participants list from the Conversation detail response.

---

### POST /workspaces/{workspace_id}/conversations/{conversation_id}/messages — Send a User Message

**Purpose**: Submit a user message to the Conversation and trigger the AI response cycle.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)

```json
{
  "content": "string (required, non-empty)"
}
```

**Response** `201 Created`:

```json
{
  "id": "string (UUID v7)",
  "conversation_id": "string (UUID v7)",
  "conversation_persona_id": null,
  "role": "user",
  "message_subtype": null,
  "content": "string",
  "created_at": "string (ISO 8601 timestamptz)"
}
```

**Error responses**:
- `404 Not Found`: Conversation or Workspace does not exist.
- `403 Forbidden`: Conversation is ended.
- `409 Conflict`: Conversation is not idle. Body: `{ "message": "A response is in progress", "code": "CONVERSATION_BUSY" }`.

**Notes**: The backend persists the user message and triggers the LangGraph graph to begin the response cycle. The endpoint returns promptly after persisting — it does not block waiting for AI responses. AI response tokens arrive via the SSE stream. `last_message_at` on the Conversation is updated when the user message is persisted.

This endpoint also serves as the P2P recovery mechanism when `pause_reason` is `turn_cap` or `repetition_detected` (architecture section 10.3). The graph detects the recovery context from its state and resets the relevant counter before resuming.

The `@Orchestrator` mention (used for targeted summaries in US-O2 and P2P pause in US-O3) is detected entirely server-side within the LangGraph graph. The frontend sends the message content as-is — no client-side preprocessing of the mention is required.

---

## Mentor Conversation

### POST /workspaces/{workspace_id}/conversations/{conversation_id}/chapter — Start a New Mentor Chapter

**Purpose**: Insert a chapter boundary marker into the Mentor Conversation thread.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)
- No request body.

**Response** `201 Created`:

```json
{
  "system_message": {
    "id": "string (UUID v7)",
    "conversation_id": "string (UUID v7)",
    "conversation_persona_id": null,
    "role": "system",
    "message_subtype": "chapter_boundary",
    "content": "Chapter boundary",
    "created_at": "string (ISO 8601 timestamptz)"
  }
}
```

**Error responses**:
- `404 Not Found`: Conversation or Workspace does not exist.
- `403 Forbidden`: The Conversation is not a Mentor Conversation (`is_mentor_conversation` is false).
- `409 Conflict`: Conversation is not idle. Body: `{ "message": "Cannot start a chapter while a response is in progress", "code": "CONVERSATION_NOT_IDLE" }`.

**Notes**: The backend inserts the system message and triggers a Working Memory → Episodic Memory compression step for the content up to the chapter boundary (architecture section 8.3). This compression is a backend side-effect — the frontend does not need to be aware of it. The `chapter_boundary` value of `message_subtype` is the identifier the frontend uses to render the chapter marker visually distinct from other system messages (FC-4 resolution).

---

## Folders

### GET /workspaces/{workspace_id}/folders — List Folders

**Purpose**: Return all Folders in a Workspace for the sidebar and Conversation creation flow.

**Request**:
- Path: `workspace_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "folders": [
    {
      "id": "string (UUID v7)",
      "name": "string",
      "created_at": "string (ISO 8601 timestamptz)",
      "conversation_count": "integer"
    }
  ]
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.

**Notes**: Ordered by `created_at` ascending (oldest first). `conversation_count` is a computed field — the count of Conversations with `folder_id` matching this Folder's ID. The frontend uses this for the collapsed Folder row in the sidebar.

---

### POST /workspaces/{workspace_id}/folders — Create a Folder

**Purpose**: Create a new Folder.

**Request**:
- Path: `workspace_id` (UUID v7, required)

```json
{
  "name": "string (required, non-empty)"
}
```

**Response** `201 Created`:

```json
{
  "id": "string (UUID v7)",
  "name": "string",
  "created_at": "string (ISO 8601 timestamptz)",
  "conversation_count": 0
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.
- `422 Unprocessable Entity`: `name` is empty.

---

### PATCH /workspaces/{workspace_id}/folders/{folder_id} — Rename a Folder

**Purpose**: Update a Folder's name.

**Request**:
- Path: `workspace_id` (UUID v7, required), `folder_id` (UUID v7, required)

```json
{
  "name": "string (required, non-empty)"
}
```

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "name": "string",
  "created_at": "string (ISO 8601 timestamptz)",
  "conversation_count": "integer"
}
```

**Error responses**:
- `404 Not Found`: Folder or Workspace does not exist.
- `422 Unprocessable Entity`: `name` is empty.

---

### DELETE /workspaces/{workspace_id}/folders/{folder_id} — Delete a Folder

**Purpose**: Delete a Folder. Conversations within the Folder become standalone (not deleted).

**Request**:
- Path: `workspace_id` (UUID v7, required), `folder_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "unassigned_conversation_ids": ["string"]
}
```

**Error responses**:
- `404 Not Found`: Folder or Workspace does not exist.

**Notes**: The backend sets `folder_id = null` on all Conversations in this Folder and returns the list of affected Conversation IDs. The frontend uses `unassigned_conversation_ids` to update the sidebar without a full Conversation list refetch — it moves those Conversations from the Folder section to the Standalone section.

---

## Documents (Reports)

### GET /workspaces/{workspace_id}/documents — List Documents

**Purpose**: Return all Documents (Reports) in a Workspace.

**Request**:
- Path: `workspace_id` (UUID v7, required)
- Query parameters:
  - `source_conversation_id`: string (UUID v7, optional) — filter to Documents for a specific source Conversation

**Response** `200 OK`:

```json
{
  "documents": [
    {
      "id": "string (UUID v7)",
      "type": "report",
      "title": "string",
      "status": "pending | complete | failed",
      "source_conversation_id": "string (UUID v7) | null",
      "created_at": "string (ISO 8601 timestamptz)"
    }
  ]
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.

**Notes**: Ordered by `created_at` descending (newest first). `content_markdown` is not included in the list response — only in the detail view. The `source_conversation_id` query filter supports listing Reports for a specific Conversation from within the Conversation view. `status` is `pending` during async generation, `complete` when available, `failed` if generation failed.

---

### GET /workspaces/{workspace_id}/documents/{document_id} — Get a Single Document

**Purpose**: Display the full Report content.

**Request**:
- Path: `workspace_id` (UUID v7, required), `document_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "type": "report",
  "title": "string",
  "status": "pending | complete | failed",
  "content_markdown": "string | null",
  "source_conversation_id": "string (UUID v7) | null",
  "created_at": "string (ISO 8601 timestamptz)"
}
```

**Error responses**:
- `404 Not Found`: Document or Workspace does not exist.

**Notes**: `content_markdown` is `null` while `status` is `pending` or `failed`. The frontend re-fetches this endpoint to check generation status.

---

### POST /workspaces/{workspace_id}/documents/generate — Generate a Report

**Purpose**: Trigger Report generation from a concluded Conversation.

**Request**:
- Path: `workspace_id` (UUID v7, required)

```json
{
  "conversation_id": "string (UUID v7, required)"
}
```

**Response** `202 Accepted`:

```json
{
  "id": "string (UUID v7)",
  "type": "report",
  "title": "string",
  "status": "pending",
  "content_markdown": null,
  "source_conversation_id": "string (UUID v7)",
  "created_at": "string (ISO 8601 timestamptz)"
}
```

**Error responses**:
- `404 Not Found`: Workspace or Conversation does not exist.
- `403 Forbidden`: Conversation is not ended.
- `409 Conflict`: A Report is already being generated for this Conversation. Body: `{ "message": "Report generation already in progress for this Conversation", "code": "REPORT_GENERATION_IN_PROGRESS" }`.

**Notes**: Async with refresh (FC-3 resolution). The endpoint returns immediately with a `pending` Document record. Report generation runs in the background using `ModelGateway.invoke`. The frontend shows a "Report is being generated, check back later" placeholder. The frontend re-fetches `GET /documents/{id}` (manually or on re-navigation) to retrieve the completed Report. The Report title is auto-generated by the backend from the Conversation title and creation timestamp. Only one Report per Conversation may be in `pending` state at a time.

---

### PATCH /workspaces/{workspace_id}/documents/{document_id} — Rename a Document

**Purpose**: Update a Document's title.

**Request**:
- Path: `workspace_id` (UUID v7, required), `document_id` (UUID v7, required)

```json
{
  "title": "string (required, non-empty)"
}
```

**Response** `200 OK`:

```json
{
  "id": "string (UUID v7)",
  "type": "report",
  "title": "string",
  "status": "pending | complete | failed",
  "content_markdown": "string | null",
  "source_conversation_id": "string (UUID v7) | null",
  "created_at": "string (ISO 8601 timestamptz)"
}
```

**Error responses**:
- `404 Not Found`: Document or Workspace does not exist.
- `422 Unprocessable Entity`: `title` is empty.

---

### DELETE /workspaces/{workspace_id}/documents/{document_id} — Delete a Document

**Purpose**: Permanently delete a Report.

**Request**:
- Path: `workspace_id` (UUID v7, required), `document_id` (UUID v7, required)

**Response** `204 No Content`

**Error responses**:
- `404 Not Found`: Document or Workspace does not exist.

**Notes**: The source Conversation is unaffected. After deletion, the Conversation view no longer shows a link to this Report.

---

## Review Agent

### GET /workspaces/{workspace_id}/review-agent/status — Get Review Agent Run Status

**Purpose**: Determine whether a Review Agent run is currently in progress to control the "Run now" button state.

**Request**:
- Path: `workspace_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "has_run": "boolean",
  "latest_run": {
    "id": "string (UUID v7)",
    "status": "pending | running | complete | failed",
    "started_at": "string (ISO 8601 timestamptz)",
    "completed_at": "string (ISO 8601 timestamptz) | null",
    "error_message": "string | null"
  }
}
```

`has_run` is `false` and `latest_run` is `null` if no runs have ever been executed for this Workspace.

**Error responses**:
- `404 Not Found`: Workspace does not exist.

**Notes**: The frontend checks this on page load of the Personas area. The "Run now" button is disabled if and only if `latest_run.status === 'running'`. The frontend does not poll.

---

### POST /workspaces/{workspace_id}/review-agent/run — Manually Trigger a Review Agent Run

**Purpose**: Trigger an immediate Review Agent run covering all Personas in the Workspace.

**Request**:
- Path: `workspace_id` (UUID v7, required)
- No request body.

**Response** `202 Accepted`:

```json
{
  "run_id": "string (UUID v7)",
  "status": "running",
  "started_at": "string (ISO 8601 timestamptz)"
}
```

**Error responses**:
- `404 Not Found`: Workspace does not exist.
- `409 Conflict`: A run is already in progress. Body: `{ "message": "A Review Agent run is already in progress", "code": "REVIEW_AGENT_ALREADY_RUNNING" }`.

**Notes**: Both this endpoint and the nightly cron job check for `status = 'running'` in `review_agent_runs` before starting. On `409`, the frontend shows a message that a run is already in progress and keeps the button disabled.

---

### GET /workspaces/{workspace_id}/personas/{persona_id}/findings — List Findings for a Persona

**Purpose**: Display Review Agent findings in a Persona's Recommendations section.

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required)

**Response** `200 OK`:

```json
{
  "findings": [
    {
      "id": "string (UUID v7)",
      "persona_id": "string (UUID v7)",
      "evidence_text": "string",
      "target_passage": "string | null",
      "suggestion_text": "string",
      "status": "active | stale",
      "created_at": "string (ISO 8601 timestamptz)",
      "updated_at": "string (ISO 8601 timestamptz)"
    }
  ]
}
```

**Error responses**:
- `404 Not Found`: Persona or Workspace does not exist.

**Notes**: Returns only findings with `status` of `active` or `stale`. Findings with `status = 'actioned'` or `status = 'dismissed'` are not returned (historical records only). The list is refreshed on page load; no real-time updating.

The frontend renders `active` and `stale` findings differently:
- `active`: displayed with Apply and Dismiss action controls
- `stale`: displayed visually distinct (without Apply or Dismiss controls; shows a message prompting the user to run the Review Agent to refresh)

`target_passage` is `null` for additive suggestions (the suggestion appends to the System Prompt rather than replacing a specific passage). This field is informational — the frontend does not need to use it directly.

---

### POST /workspaces/{workspace_id}/personas/{persona_id}/findings/{finding_id}/apply — Apply a Finding

**Purpose**: Apply a Review Agent finding to update the Persona's live System Prompt.

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required), `finding_id` (UUID v7, required)
- No request body.

**Response** `200 OK`:

```json
{
  "persona": {
    "id": "string (UUID v7)",
    "name": "string",
    "description": "string | null",
    "system_prompt": "string",
    "temperature": "number",
    "is_mentor": "boolean",
    "created_at": "string (ISO 8601 timestamptz)",
    "updated_at": "string (ISO 8601 timestamptz)"
  },
  "finding_id": "string (UUID v7)"
}
```

**Error responses**:
- `404 Not Found`: Finding, Persona, or Workspace does not exist.
- `409 Conflict`: Finding `status` is not `active`. Body: `{ "message": "Only active findings can be applied", "code": "FINDING_NOT_ACTIVE" }`.

**Notes**: The backend performs a find-and-replace of `target_passage` → `suggestion_text` in `personas.system_prompt`. For additive suggestions (`target_passage IS NULL`), `suggestion_text` is appended. Both the `personas` update and a `persona_system_prompt_versions` insert happen in a single transaction (universal versioning rule). After the prompt update, the backend checks all other `active` findings for this Persona and sets any whose `target_passage` is no longer present in the new prompt to `stale`. The finding itself is set to `actioned` and removed from future list responses.

The frontend removes the finding card immediately and updates its local copy of the Persona's System Prompt with the returned `system_prompt`.

---

### POST /workspaces/{workspace_id}/personas/{persona_id}/findings/{finding_id}/dismiss — Dismiss a Finding

**Purpose**: Dismiss a Review Agent finding so it is suppressed by the Review Agent in future runs.

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required), `finding_id` (UUID v7, required)
- No request body.

**Response** `200 OK`:

```json
{
  "finding_id": "string (UUID v7)",
  "status": "dismissed"
}
```

**Error responses**:
- `404 Not Found`: Finding, Persona, or Workspace does not exist.
- `409 Conflict`: Finding `status` is not `active`. Body: `{ "message": "Only active findings can be dismissed", "code": "FINDING_NOT_ACTIVE" }`.

**Notes**: The backend sets the finding's `status` to `dismissed`. The dismissed finding is excluded from future list responses. The Review Agent's nightly run reconciliation step reads dismissed findings to apply prompt-driven suppression when generating new findings for the same Persona.

---

### POST /workspaces/{workspace_id}/personas/{persona_id}/consultation — Interactive Consultation

**Purpose**: Send a message to the Review Agent in consultation mode for interactive Persona shaping (US-RA4).

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required)

```json
{
  "message": "string (required, non-empty)",
  "session_id": "string (required, frontend-generated ephemeral UUID)"
}
```

**Response**: `200 OK` — SSE stream (`Content-Type: text/event-stream`)

Events on the stream:
- `token` event: `{ "content": "string" }`
- `response_complete` event: `{ "content": "string" }`

**Error responses**:
- `404 Not Found`: Persona or Workspace does not exist.
- `422 Unprocessable Entity`: `message` or `session_id` missing.
- `503 Service Unavailable`: Model backend unavailable.

**Notes**: The backend calls `ModelGateway.stream` with the Persona's current `system_prompt` and any `active` or `stale` findings as context. Full Conversation histories are explicitly excluded from this context (US-RA4 constraint). The `session_id` scopes multi-turn context in memory — no messages are persisted. The session is discarded after a configurable inactivity timeout. The frontend discards the session on navigation away from the Persona page.

---

## Mentor Memory Inspector

### GET /workspaces/{workspace_id}/personas/{persona_id}/memory/episodic — Get Episodic Memory Entries

**Purpose**: Display the Episodic Memory section of the Memory Inspector panel (US-M5).

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required — must be the Mentor Persona)

**Response** `200 OK`:

```json
{
  "episodic_memories": [
    {
      "id": "string (UUID v7)",
      "sequence_number": "integer",
      "summary_text": "string",
      "source_type": "self | observed",
      "source_conversation_id": "string (UUID v7) | null",
      "created_at": "string (ISO 8601 timestamptz)"
    }
  ]
}
```

**Error responses**:
- `404 Not Found`: Persona or Workspace does not exist.
- `403 Forbidden`: Persona is not the Mentor (`is_mentor` is false).

**Notes**: Ordered by `sequence_number` ascending. All entries are returned (V1 "load all" pattern per architecture section 8.2). Panel is read-only. `source_type` distinguishes entries promoted from the Mentor's own Conversation (`self`) from entries written by the Conversation Observer from a concluded non-Mentor Conversation (`observed`). `source_conversation_id` is non-null for `observed` entries and identifies the originating Conversation; it is null for `self` entries. The frontend uses `source_type` to group and label entries distinctly in the Memory Inspector panel.

---

### GET /workspaces/{workspace_id}/personas/{persona_id}/memory/semantic — Get Semantic Memory Documents

**Purpose**: Display the Semantic Memory section of the Memory Inspector panel (US-M5).

**Request**:
- Path: `workspace_id` (UUID v7, required), `persona_id` (UUID v7, required — must be the Mentor Persona)

**Response** `200 OK`:

```json
{
  "semantic_memories": [
    {
      "id": "string (UUID v7)",
      "title": "string",
      "content_markdown": "string",
      "created_at": "string (ISO 8601 timestamptz)",
      "updated_at": "string (ISO 8601 timestamptz)"
    }
  ]
}
```

**Error responses**:
- `404 Not Found`: Persona or Workspace does not exist.
- `403 Forbidden`: Persona is not the Mentor (`is_mentor` is false).

**Notes**: Ordered by `updated_at` descending (most recently updated first). All entries are returned (V1 "load all" pattern). Panel is read-only.

---

## SSE Streaming

### GET /conversations/{conversation_id}/stream — Open a Conversation Stream

**Purpose**: Open a long-lived Server-Sent Events stream for a Conversation. Delivers AI response tokens, Orchestrator suggestions, and system state signals.

**Request**:
- Path: `conversation_id` (UUID v7, required)
- Headers: `Last-Event-ID` (optional) — provided by `@microsoft/fetch-event-source` on reconnect; the backend resumes sending events from after the given event ID.

**Response**: `200 OK` — SSE stream (`Content-Type: text/event-stream`)

The stream remains open until the client closes the connection or the server terminates it.

**Error responses**:
- `404 Not Found`: Conversation does not exist.

**Notes**: This endpoint is not under `/workspaces/{workspace_id}/` because `@microsoft/fetch-event-source` opens the stream using only the Conversation ID in a GET request. Workspace scoping is enforced by the ORM listener via the `ContextVar` set by the workspace middleware. The backend plan must document how workspace context is established for this endpoint and all other non-workspace-scoped endpoints (e.g. a `X-Workspace-ID` request header or a query parameter passed at stream open time). The same mechanism applies to `POST /conversations/{id}/pause`, `POST /conversations/{id}/resume`, `POST /conversations/{id}/cancel`, and the suggestion accept/dismiss endpoints.

The backend assigns a server-side event ID to every event (monotonically increasing per Conversation stream). The frontend's `@microsoft/fetch-event-source` sends `Last-Event-ID` on reconnect; the backend uses this to resume from the correct position.

One stream per open Conversation. Multiple Persona responses in Round-Robin and P2P modes are emitted sequentially on the same stream (no parallel streaming in V1 per architecture section 10.4).

---

### SSE Event Types

All events follow the SSE wire format:

```text
id: {event_id}
event: {event_type}
data: {JSON-encoded payload}

```

(Two newlines terminate each event block.)

---

#### `token`

Emitted for each incremental token from the active Persona or Mentor response.

**Payload**:

```json
{
  "content": "string",
  "conversation_persona_id": "string (UUID v7)"
}
```

`conversation_persona_id` identifies which Persona (or Mentor) is speaking. The frontend cross-references this with the participants list to determine the speaker's display name. For the Mentor Conversation, the `conversation_persona_id` value is a stable identifier derived from the Mentor Persona ID — the implementation plan must define this format and communicate it to the frontend team before the Mentor stream is implemented.

---

#### `response_complete`

Emitted when a Persona or Mentor response is fully generated and persisted.

**Payload**:

```json
{
  "message_id": "string (UUID v7)",
  "conversation_persona_id": "string (UUID v7)",
  "content": "string"
}
```

`message_id` is the ID of the persisted `messages` row. `content` is the full message text. The frontend replaces its streaming buffer with the canonical `content` and stores `message_id` for export ordering.

---

#### `orchestrator_suggestion`

Emitted when the Orchestrator has a Persona suggestion for the user.

**Payload**:

```json
{
  "suggestion_id": "string (UUID v7)",
  "suggested_persona_id": "string (UUID v7)",
  "suggested_persona_name": "string",
  "reason": "string"
}
```

`suggestion_id` is the ID of the `orchestrator_suggestions` row. It is used when the user accepts or dismisses the suggestion via the control endpoints. `reason` is a human-readable explanation for the suggestion. The frontend displays a non-intrusive suggestion card; the user accepts or dismisses via the appropriate endpoints.

---

#### `busy`

Emitted when the system begins processing a turn.

**Payload**: `{}`

The frontend sets the system state to "busy" — disables send controls, hides Persona add/remove/mode-switch controls, shows a loading indicator.

---

#### `idle`

Emitted when the system has finished processing and is ready for input.

**Payload**: `{}`

The frontend sets the system state to "idle" — re-enables send controls, shows Persona add/remove/mode-switch controls, hides loading indicators.

---

#### `paused`

Emitted when the Conversation has been paused (e.g. after a Workspace-switch interrupt is detected at the next turn boundary, or when a paused Conversation's stream re-opens).

**Payload**: `{}`

The frontend shows a "Conversation paused — resume to continue" state with a Resume button visible. Recovery is via `POST /conversations/{id}/resume`.

---

#### `exchange_paused`

Emitted when a P2P autonomous exchange has been paused. Carries the pause reason so the frontend can display the appropriate message and recovery path.

**Payload**:

```json
{
  "pause_reason": "user_pause | turn_cap | repetition_detected"
}
```

Frontend behaviour by `pause_reason`:
- `user_pause`: user pressed Pause. Show a "Paused" state with a Resume button. Recovery via `POST /conversations/{id}/resume`.
- `turn_cap`: exchange hit the configured turn cap. Show a message explaining the check-in. A text input prompts the user to send a message to reset the counter and resume. Recovery via `POST /conversations/{id}/messages`.
- `repetition_detected`: system detected repetitive responses. Show a message explaining this and prompt the user to send a steering input. Recovery via `POST /conversations/{id}/messages`.

---

## Conversation Control Signals

### POST /conversations/{conversation_id}/pause — Pause a Conversation

**Purpose**: Set `pause_requested = true` in the LangGraph graph state so the current exchange pauses at the next turn boundary (user-initiated).

**Request**:
- Path: `conversation_id` (UUID v7, required)
- No request body.

**Response** `200 OK`:

```json
{
  "status": "pause_requested"
}
```

**Error responses**:
- `404 Not Found`: Conversation does not exist.
- `403 Forbidden`: Conversation is ended.

**Notes**: The backend sets the flag via the LangGraph checkpointer. The actual `exchange_paused` event with `pause_reason: "user_pause"` arrives on the SSE stream when the graph observes the flag at the next turn boundary. The endpoint returns immediately after setting the flag.

---

### POST /conversations/{conversation_id}/resume — Resume a Paused Conversation

**Purpose**: Clear `pause_requested` and resume the Conversation or P2P exchange from the last checkpoint.

**Request**:
- Path: `conversation_id` (UUID v7, required)
- No request body.

**Response** `200 OK`:

```json
{
  "status": "resumed"
}
```

**Error responses**:
- `404 Not Found`: Conversation does not exist.
- `403 Forbidden`: Conversation is ended.
- `409 Conflict`: Conversation is not in a paused state. Body: `{ "message": "Conversation is not paused", "code": "CONVERSATION_NOT_PAUSED" }`.

**Notes**: The backend clears `pause_requested` in the LangGraph checkpointer and resumes the graph from the last checkpoint. The `busy` event arrives on the SSE stream when the exchange resumes.

This endpoint handles two pause origins that both converge here (FC-8 and architecture section 10.6):
1. **User-initiated pause** (`pause_reason: "user_pause"`): user pressed the Pause button.
2. **Workspace-switch interrupt**: the backend automatically sets `pause_requested = true` at the next turn boundary after the SSE stream closes. When the user returns and the stream re-opens, the frontend detects the paused state (from a `paused` SSE event emitted when the stream re-opens) and presents a resume prompt.

Both origins are recovered via this same endpoint — no distinction is made in the request.

This endpoint is NOT used for `turn_cap` or `repetition_detected` recovery — those are recovered via `POST /conversations/{id}/messages`.

---

### POST /conversations/{conversation_id}/cancel — Cancel the P2P Exchange

**Purpose**: End the autonomous P2P exchange and return to idle. Messages produced so far are preserved.

**Request**:
- Path: `conversation_id` (UUID v7, required)
- No request body.

**Response** `200 OK`:

```json
{
  "status": "cancelled"
}
```

**Error responses**:
- `404 Not Found`: Conversation does not exist.
- `403 Forbidden`: Conversation is ended.

**Notes**: The backend transitions the graph to idle state. The `idle` event arrives on the SSE stream. Messages produced during the P2P exchange before the cancel are not deleted. The frontend re-enables all controls when `idle` is received.

---

## Orchestrator Suggestion Responses

### POST /conversations/{conversation_id}/suggestions/{suggestion_id}/accept — Accept an Orchestrator Suggestion

**Purpose**: Accept an Orchestrator Persona suggestion, adding the Persona to the Conversation.

**Request**:
- Path: `conversation_id` (UUID v7, required), `suggestion_id` (UUID v7, required)
- No request body.

**Response** `200 OK`:

```json
{
  "conversation_persona": {
    "conversation_persona_id": "string (UUID v7)",
    "persona_id": "string (UUID v7)",
    "snapshot_name": "string",
    "snapshot_system_prompt": "string",
    "snapshot_temperature": "number",
    "joined_at": "string (ISO 8601 timestamptz)",
    "left_at": null
  },
  "system_message": {
    "id": "string (UUID v7)",
    "conversation_id": "string (UUID v7)",
    "conversation_persona_id": null,
    "role": "system",
    "message_subtype": "orchestrator_suggestion_accepted",
    "content": "string",
    "created_at": "string (ISO 8601 timestamptz)"
  },
  "updated_mode": "one_to_one | round_robin | p2p"
}
```

**Error responses**:
- `404 Not Found`: Conversation or suggestion does not exist.
- `409 Conflict`: Suggestion is not in `pending` status (already accepted or dismissed).
- `409 Conflict`: Conversation is ended.
- `409 Conflict`: Conversation is not idle. Body: `{ "message": "Cannot add a Persona while a response is in progress", "code": "CONVERSATION_NOT_IDLE" }`.

**Notes**: The backend takes a snapshot of the Persona, inserts a `conversation_personas` row, inserts a system message with `message_subtype: "orchestrator_suggestion_accepted"`. If the Conversation was in `one_to_one` mode, the mode is automatically switched to `round_robin` and a second system message with `message_subtype: "mode_changed"` is also inserted. `updated_mode` always reflects the current mode after the operation. The `orchestrator_suggestions` row is set to `accepted`.

---

### POST /conversations/{conversation_id}/suggestions/{suggestion_id}/dismiss — Dismiss an Orchestrator Suggestion

**Purpose**: Dismiss an Orchestrator suggestion to suppress it from future evaluations.

**Request**:
- Path: `conversation_id` (UUID v7, required), `suggestion_id` (UUID v7, required)
- No request body.

**Response** `200 OK`:

```json
{
  "suggestion_id": "string (UUID v7)",
  "status": "dismissed"
}
```

**Error responses**:
- `404 Not Found`: Conversation or suggestion does not exist.
- `409 Conflict`: Suggestion is not in `pending` status. Body: `{ "message": "Suggestion has already been resolved", "code": "SUGGESTION_ALREADY_RESOLVED" }`.

**Notes**: The backend sets the `orchestrator_suggestions` row to `dismissed`. The Orchestrator's suppression logic reads this table to avoid re-suggesting recently dismissed Personas. The exact suppression mechanism (e.g. time-based decay or N-message window) is an implementation detail for the backend plan.

---

## Conversation Export

### GET /workspaces/{workspace_id}/conversations/{conversation_id}/export — Export Conversation as Markdown

**Purpose**: Export the full Conversation as a raw Markdown file with all messages in chronological order.

**Request**:
- Path: `workspace_id` (UUID v7, required), `conversation_id` (UUID v7, required)

**Response** `200 OK`:
- `Content-Type: text/markdown`
- `Content-Disposition: attachment; filename="{conversation-title}.md"`
- Body: Markdown-formatted transcript including all messages in chronological order with speaker labels (Persona snapshot name or "You" for user messages) and system messages formatted as event markers.

**Error responses**:
- `404 Not Found`: Conversation or Workspace does not exist.
- `409 Conflict`: Conversation is not idle. Body: `{ "message": "Export is not available while a response is in progress", "code": "CONVERSATION_BUSY" }`.

**Notes**: Both active and ended Conversations can be exported when idle (US-R3). The export includes all message types including system messages (rendered as event markers, e.g. `---\n*Risk Analyst joined*\n---`). No pagination — the full transcript is returned in a single response.

---

## Flagged Issues

No blocking issues remain. All flagged concerns from `api-requirements-frontend.md` (FC-1 through FC-8) are resolved:

| Concern | Resolution |
| --- | --- |
| FC-1: Auto-summary delivery mechanism | Async. `POST /end` returns immediately with `auto_summary: null`. Frontend polls via `GET /conversations/{id}` on return. |
| FC-2: Mentor Conversation discovery | No dedicated endpoint. `is_mentor_conversation` flag on all Conversation list and detail responses. |
| FC-3: Report generation delivery mechanism | Async with refresh. `POST /generate` returns `202` with `status: pending`. Frontend polls via `GET /documents/{id}`. |
| FC-4: Chapter marker differentiation | `message_subtype: "chapter_boundary"` on the system message. |
| FC-5: Mentor session-end signal protocol | No frontend signal required. Episodic to Semantic promotion runs on a scheduled job only. |
| FC-6: Persona Test streaming mechanism | SSE used for test sessions (same `@microsoft/fetch-event-source` client path as Conversations). |
| FC-7: Review Agent finding schema | Defined in the findings list endpoint: `id`, `persona_id`, `evidence_text`, `target_passage`, `suggestion_text`, `status`, `created_at`, `updated_at`. |
| FC-8: Orchestrator accept/dismiss protocol | Dedicated endpoints with `suggestion_id`: `POST /conversations/{id}/suggestions/{suggestion_id}/accept` and `.../dismiss`. |
