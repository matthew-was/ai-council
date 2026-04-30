# Senior Developer (Backend) — Implementation Plan

**Status**: Unapproved
**Date produced**: 2026-04-28
**Source documents**: `documentation/project/architecture.md`, `documentation/decisions/architecture-decisions.md`, `documentation/tasks/api-contract.md`

---

## 1. Project Structure

```text
apps/backend/
├── config.json                        # Committed base config (no secrets)
├── config.override.json               # Gitignored; Docker Compose volume-mounted
├── pyproject.toml                     # Dependencies and tool config
├── alembic.ini                        # Alembic config
├── alembic/
│   ├── env.py                         # Alembic env — uses async engine from app config
│   └── versions/
│       └── 0001_initial_schema.py     # Full initial schema (see Section 2)
├── app/
│   ├── main.py                        # FastAPI app factory + lifespan
│   ├── config.py                      # Dynaconf loader + Pydantic validation model
│   ├── constants.py                   # DEFAULT_USER_ID, CONTEXT_PANEL_MAX_CHARS, etc.
│   ├── db/
│   │   ├── engine.py                  # SQLAlchemy async engine + session factory
│   │   ├── session.py                 # get_db dependency (AsyncSession generator)
│   │   ├── mixins.py                  # WorkspaceScopedMixin, UserScopedMixin
│   │   ├── scoping.py                 # ContextVar declarations + do_orm_execute listener
│   │   └── models/
│   │       ├── __init__.py            # Exports all model classes
│   │       ├── user.py                # User
│   │       ├── workspace.py           # Workspace
│   │       ├── persona.py             # Persona, PersonaSystemPromptVersion
│   │       ├── conversation.py        # Conversation, ConversationPersona, Folder
│   │       ├── message.py             # Message
│   │       ├── conversation_summary.py # ConversationSummary (internal)
│   │       ├── mentor_memory.py       # MentorEpisodicMemory, MentorSemanticMemory
│   │       ├── review_agent.py        # ReviewAgentRun, ReviewAgentFinding
│   │       ├── orchestrator.py        # OrchestratorSuggestion
│   │       └── document.py            # Document
│   ├── middleware/
│   │   ├── current_user.py            # CurrentUserMiddleware + resolve_current_user()
│   │   └── workspace.py               # WorkspaceContextMiddleware (sets current_workspace_id)
│   ├── dependencies.py                # FastAPI Depends() factories
│   ├── errors.py                      # Custom exception classes + global exception handler
│   ├── gateway/
│   │   ├── __init__.py
│   │   └── model_gateway.py           # ModelGateway class (Tier 1 abstraction — ADR-002)
│   ├── orchestrator/
│   │   ├── __init__.py
│   │   ├── graph.py                   # LangGraph graph definition (ConversationOrchestrator)
│   │   ├── nodes.py                   # LangGraph node functions
│   │   ├── state.py                   # LangGraph state schema (TypedDict)
│   │   ├── speaker_selection.py       # Addressability + round-robin logic
│   │   └── sse_bridge.py              # Translates graph.stream() events to SSE payloads
│   ├── context/
│   │   ├── __init__.py
│   │   ├── strategy.py                # CompressionStrategy abstract base class
│   │   ├── rolling_summary.py         # RollingSummary implementation
│   │   └── assembler.py               # Context assembly (ordering, token budget)
│   ├── mentor/
│   │   ├── __init__.py
│   │   ├── retriever.py               # MentorMemoryRetriever interface + V1 implementation
│   │   └── promoter.py                # Working→Episodic and Episodic→Semantic promotion logic
│   ├── review_agent/
│   │   ├── __init__.py
│   │   ├── runner.py                  # ReviewAgentRunner — sweep logic, row-lock, reconciliation
│   │   └── schemas.py                 # PersonaFinding Pydantic structured output schema
│   ├── conversation_observer/
│   │   ├── __init__.py
│   │   ├── observer.py                # ConversationObserver — core logic, ModelGateway call, DB write
│   │   └── schemas.py                 # ConversationObservation Pydantic structured output schema
│   ├── jobs/
│   │   ├── __init__.py
│   │   ├── scheduler.py               # APScheduler AsyncIOScheduler setup
│   │   ├── review_agent_job.py        # CronTrigger wrapper that sets ContextVars and calls runner
│   │   ├── mentor_promotion_job.py    # ScheduledTrigger wrapper for Episodic→Semantic promotion
│   │   └── conversation_observer_task.py  # asyncio.create_task wrapper; wired at conversation end
│   ├── sse/
│   │   ├── __init__.py
│   │   ├── manager.py                 # In-memory SSE listener registry (conversation_id → event queue)
│   │   └── events.py                  # SSE event type dataclasses and serialisers
│   ├── schemas/
│   │   ├── __init__.py
│   │   ├── workspace.py               # WorkspaceResponse, WorkspaceCreate, WorkspacePatch
│   │   ├── persona.py                 # PersonaResponse, PersonaCreate, PersonaPatch
│   │   ├── conversation.py            # ConversationResponse, ConversationCreate, etc.
│   │   ├── message.py                 # MessageResponse, MessageCreate, MessageListResponse
│   │   ├── folder.py                  # FolderResponse, FolderCreate, FolderPatch
│   │   ├── document.py                # DocumentResponse, DocumentGenerate, DocumentPatch
│   │   ├── review_agent.py            # FindingResponse, ConsultationRequest, RunResponse
│   │   ├── mentor_memory.py           # EpisodicMemoryResponse (includes source_type, source_conversation_id), SemanticMemoryResponse
│   │   └── sse.py                     # ConversationSummary (structured output schema)
│   └── routers/
│       ├── __init__.py
│       ├── workspaces.py
│       ├── personas.py
│       ├── conversations.py
│       ├── messages.py
│       ├── folders.py
│       ├── documents.py
│       ├── review_agent.py
│       ├── mentor.py
│       ├── stream.py                  # GET /conversations/{id}/stream
│       └── control.py                 # POST /conversations/{id}/pause|resume|cancel
└── tests/
    ├── conftest.py                    # Shared fixtures: test DB, session, ContextVar setup
    ├── fakes/
    │   ├── __init__.py
    │   ├── fake_model_gateway.py      # FakeModelGateway — concrete ABC impl; pre-configured responses
    │   ├── fake_conversation_repo.py  # FakeConversationRepository — in-memory store
    │   └── fake_sse_manager.py        # FakeSseManager — records emitted events for assertion
    ├── unit/
    │   ├── test_model_gateway.py
    │   ├── test_rolling_summary.py
    │   ├── test_context_assembler.py
    │   ├── test_speaker_selection.py
    │   ├── test_review_agent_runner.py
    │   └── test_mentor_promoter.py
    └── integration/
        ├── test_workspaces.py
        ├── test_personas.py
        ├── test_conversations.py
        ├── test_messages.py
        ├── test_review_agent.py
        └── test_mentor_memory.py
```

**Naming conventions:**

- Module files: `snake_case.py`
- Classes: `PascalCase`
- Route handler functions: `snake_case` verb-noun (e.g. `create_workspace`, `list_personas`)
- Pydantic schemas: named for their purpose with `Request` / `Response` suffix where ambiguity exists
- SQLAlchemy model classes: singular PascalCase matching the table entity (e.g. `Conversation`, not `ConversationModel`)

---

## 2. Initial Alembic Migration

**File**: `alembic/versions/0001_initial_schema.py`

The migration creates all application tables in dependency order, seeds `DEFAULT_USER_ID`, and creates all required indexes. It does not create LangGraph checkpointer tables — those are created by calling `PostgresSaver.setup()` in the FastAPI lifespan (see Section 4.1).

### 2.1 Dependency order

```text
users
  └── workspaces (user_id FK → users)
        ├── personas (workspace_id FK, user_id FK)
        │     └── persona_system_prompt_versions (persona_id FK)
        ├── folders (workspace_id FK, user_id FK)
        ├── conversations (workspace_id FK, user_id FK, folder_id FK nullable)
        │     ├── conversation_personas (conversation_id FK, persona_id FK nullable)
        │     ├── messages (conversation_id FK, conversation_persona_id FK nullable)
        │     ├── conversation_summaries (conversation_id FK UNIQUE)
        │     └── orchestrator_suggestions (workspace_id FK, conversation_id FK, persona_id FK)
        ├── review_agent_runs (workspace_id FK, user_id FK)
        ├── review_agent_findings (persona_id FK, run_id FK nullable)
        ├── mentor_episodic_memories (workspace_id FK, user_id FK, mentor_persona_id FK)
        ├── mentor_semantic_memories (workspace_id FK, user_id FK, mentor_persona_id FK)
        └── documents (workspace_id FK, user_id FK, source_conversation_id FK nullable)
```

### 2.2 Table definitions

**`users`**

```sql
CREATE TABLE users (
    id          UUID PRIMARY KEY,
    email       TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL
);
-- Seed row
INSERT INTO users (id, email, created_at)
VALUES ('00000000-0000-7000-8000-000000000001', 'local@localhost', now());
```

**`workspaces`**

```sql
CREATE TABLE workspaces (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL REFERENCES users(id),
    name        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_workspaces_user_id ON workspaces(user_id);
```

**`personas`**

```sql
CREATE TABLE personas (
    id              UUID PRIMARY KEY,
    workspace_id    UUID NOT NULL REFERENCES workspaces(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    name            TEXT NOT NULL,
    description     TEXT,
    system_prompt   TEXT NOT NULL,
    temperature     FLOAT NOT NULL,
    is_mentor       BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_personas_workspace_id ON personas(workspace_id);
CREATE INDEX ix_personas_user_id ON personas(user_id);
```

**`persona_system_prompt_versions`**

```sql
CREATE TABLE persona_system_prompt_versions (
    id              UUID PRIMARY KEY,
    persona_id      UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    system_prompt   TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_pspv_persona_id ON persona_system_prompt_versions(persona_id);
```

**`folders`**

```sql
CREATE TABLE folders (
    id              UUID PRIMARY KEY,
    workspace_id    UUID NOT NULL REFERENCES workspaces(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    name            TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_folders_workspace_id ON folders(workspace_id);
```

**`conversations`**

```sql
CREATE TYPE conversation_mode AS ENUM ('one_to_one', 'round_robin', 'p2p');
CREATE TYPE conversation_status AS ENUM ('active', 'ended');

CREATE TABLE conversations (
    id                      UUID PRIMARY KEY,
    workspace_id            UUID NOT NULL REFERENCES workspaces(id),
    user_id                 UUID NOT NULL REFERENCES users(id),
    folder_id               UUID REFERENCES folders(id) ON DELETE SET NULL,
    title                   TEXT NOT NULL,
    mode                    conversation_mode NOT NULL,
    status                  conversation_status NOT NULL DEFAULT 'active',
    is_mentor_conversation  BOOLEAN NOT NULL DEFAULT FALSE,
    context_panel           TEXT NOT NULL DEFAULT '',
    pinned_at               TIMESTAMPTZ,
    auto_summary            JSONB,
    last_message_at         TIMESTAMPTZ,
    created_at              TIMESTAMPTZ NOT NULL,
    ended_at                TIMESTAMPTZ
);
CREATE INDEX ix_conversations_workspace_id ON conversations(workspace_id);
CREATE INDEX ix_conversations_folder_id ON conversations(folder_id);
CREATE INDEX ix_conversations_last_message_at ON conversations(last_message_at);
```

**`conversation_personas`**

```sql
CREATE TABLE conversation_personas (
    id                      UUID PRIMARY KEY,
    conversation_id         UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    persona_id              UUID REFERENCES personas(id) ON DELETE SET NULL,
    snapshot_name           TEXT NOT NULL,
    snapshot_system_prompt  TEXT NOT NULL,
    snapshot_temperature    FLOAT NOT NULL,
    joined_at               TIMESTAMPTZ NOT NULL,
    left_at                 TIMESTAMPTZ
);
CREATE INDEX ix_cp_conversation_id ON conversation_personas(conversation_id);
CREATE INDEX ix_cp_persona_id ON conversation_personas(persona_id);
```

**`messages`**

```sql
CREATE TYPE message_role AS ENUM ('user', 'persona', 'mentor', 'system');

CREATE TABLE messages (
    id                      UUID PRIMARY KEY,
    conversation_id         UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    conversation_persona_id UUID REFERENCES conversation_personas(id) ON DELETE SET NULL,
    role                    message_role NOT NULL,
    message_subtype         TEXT,
    content                 TEXT NOT NULL,
    created_at              TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_messages_conversation_id ON messages(conversation_id);
CREATE INDEX ix_messages_conversation_id_created_at
    ON messages(conversation_id, created_at);
```

`message_subtype` is a plain `TEXT` column (not an enum) so new values can be added without a migration. Valid values: `persona_joined`, `persona_left`, `chapter_boundary`, `orchestrator_suggestion_accepted`, `mode_changed`.

**`conversation_summaries`**

```sql
CREATE TABLE conversation_summaries (
    id              UUID PRIMARY KEY,
    conversation_id UUID NOT NULL UNIQUE REFERENCES conversations(id) ON DELETE CASCADE,
    rolling_summary TEXT NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL
);
```

Internal table only — never returned in API responses.

**`orchestrator_suggestions`**

```sql
CREATE TYPE orchestrator_suggestion_status AS ENUM ('pending', 'accepted', 'dismissed');

CREATE TABLE orchestrator_suggestions (
    id              UUID PRIMARY KEY,
    workspace_id    UUID NOT NULL REFERENCES workspaces(id),
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    persona_id      UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    suggestion_text TEXT NOT NULL,
    suggested_at    TIMESTAMPTZ NOT NULL,
    status          orchestrator_suggestion_status NOT NULL DEFAULT 'pending'
);
CREATE INDEX ix_os_conversation_id ON orchestrator_suggestions(conversation_id);
CREATE INDEX ix_os_persona_id ON orchestrator_suggestions(persona_id);
```

**`review_agent_runs`**

```sql
CREATE TYPE run_status AS ENUM ('pending', 'running', 'complete', 'failed');

CREATE TABLE review_agent_runs (
    id              UUID PRIMARY KEY,
    workspace_id    UUID NOT NULL REFERENCES workspaces(id),
    user_id         UUID NOT NULL REFERENCES users(id),
    status          run_status NOT NULL DEFAULT 'pending',
    started_at      TIMESTAMPTZ NOT NULL,
    completed_at    TIMESTAMPTZ,
    error_message   TEXT
);
CREATE INDEX ix_rar_workspace_id ON review_agent_runs(workspace_id);
CREATE INDEX ix_rar_status ON review_agent_runs(status);
```

**`review_agent_findings`**

```sql
CREATE TYPE finding_status AS ENUM ('active', 'stale', 'actioned', 'dismissed');

CREATE TABLE review_agent_findings (
    id              UUID PRIMARY KEY,
    persona_id      UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    run_id          UUID REFERENCES review_agent_runs(id) ON DELETE SET NULL,
    evidence_text   TEXT NOT NULL,
    target_passage  TEXT,
    suggestion_text TEXT NOT NULL,
    status          finding_status NOT NULL DEFAULT 'active',
    created_at      TIMESTAMPTZ NOT NULL,
    updated_at      TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_raf_persona_id ON review_agent_findings(persona_id);
CREATE INDEX ix_raf_status ON review_agent_findings(status);
```

**`mentor_episodic_memories`**

```sql
CREATE TABLE mentor_episodic_memories (
    id                  UUID PRIMARY KEY,
    workspace_id        UUID NOT NULL REFERENCES workspaces(id),
    user_id             UUID NOT NULL REFERENCES users(id),
    mentor_persona_id   UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    sequence_number     INTEGER NOT NULL,
    summary_text        TEXT NOT NULL,
    source_type         TEXT NOT NULL CHECK (source_type IN ('self', 'observed')),
    source_conversation_id UUID REFERENCES conversations(id) ON DELETE SET NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    promoted_at         TIMESTAMPTZ,
    pending_promotion   BOOLEAN NOT NULL DEFAULT FALSE,
    UNIQUE (mentor_persona_id, source_conversation_id)
);
CREATE INDEX ix_mem_workspace_id ON mentor_episodic_memories(workspace_id);
CREATE INDEX ix_mem_mentor_persona_id ON mentor_episodic_memories(mentor_persona_id);
CREATE INDEX ix_mem_pending_promotion ON mentor_episodic_memories(pending_promotion)
    WHERE pending_promotion = TRUE;
```

**`mentor_semantic_memories`**

```sql
CREATE TABLE mentor_semantic_memories (
    id                  UUID PRIMARY KEY,
    workspace_id        UUID NOT NULL REFERENCES workspaces(id),
    user_id             UUID NOT NULL REFERENCES users(id),
    mentor_persona_id   UUID NOT NULL REFERENCES personas(id) ON DELETE CASCADE,
    title               TEXT NOT NULL,
    content_markdown    TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL,
    updated_at          TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_msm_workspace_id ON mentor_semantic_memories(workspace_id);
CREATE INDEX ix_msm_mentor_persona_id ON mentor_semantic_memories(mentor_persona_id);
```

**`documents`**

```sql
CREATE TYPE document_type AS ENUM ('report');
CREATE TYPE document_status AS ENUM ('pending', 'complete', 'failed');

CREATE TABLE documents (
    id                      UUID PRIMARY KEY,
    workspace_id            UUID NOT NULL REFERENCES workspaces(id),
    user_id                 UUID NOT NULL REFERENCES users(id),
    type                    document_type NOT NULL DEFAULT 'report',
    title                   TEXT NOT NULL,
    status                  document_status NOT NULL DEFAULT 'pending',
    content_markdown        TEXT,
    source_conversation_id  UUID REFERENCES conversations(id) ON DELETE SET NULL,
    created_at              TIMESTAMPTZ NOT NULL
);
CREATE INDEX ix_documents_workspace_id ON documents(workspace_id);
CREATE INDEX ix_documents_source_conversation_id ON documents(source_conversation_id);
```

### 2.3 UUID v7 generation

Python 3.12 does not include `uuid7()` natively. Use the `uuid-utils` package (C-extension wrapper around the Rust `uuid` crate). Define a helper:

```python
# app/constants.py
from uuid_utils import uuid7

def new_uuid() -> str:
    return str(uuid7())
```

All primary key default values in SQLAlchemy models use `default=new_uuid`.

---

## 3. SQLAlchemy Models

### 3.1 Mixins — `app/db/mixins.py`

**`UserScopedMixin`**

Adds `user_id UUID NOT NULL FK → users(id)` to every subclass.

```python
class UserScopedMixin:
    user_id: Mapped[str] = mapped_column(
        ForeignKey("users.id"), nullable=False, index=True
    )
```

**`WorkspaceScopedMixin`**

Adds `workspace_id UUID NOT NULL FK → workspaces(id)` to every subclass. Inherits `UserScopedMixin`.

```python
class WorkspaceScopedMixin(UserScopedMixin):
    workspace_id: Mapped[str] = mapped_column(
        ForeignKey("workspaces.id"), nullable=False, index=True
    )
```

### 3.2 ORM scoping listener — `app/db/scoping.py`

Two module-level `ContextVar`s:

```python
current_workspace_id: ContextVar[str | None] = ContextVar("current_workspace_id", default=None)
current_user_id: ContextVar[str | None] = ContextVar("current_user_id", default=None)
```

A `do_orm_execute` event listener is registered on the session factory at engine creation time. For every SELECT statement against a mapped class that inherits `WorkspaceScopedMixin`, the listener appends `WHERE workspace_id = :workspace_id` using the value from `current_workspace_id` via SQLAlchemy's parameterised bind variable API (not string interpolation). If the `ContextVar` is `None` (background task forgot to set it), the listener raises `RuntimeError` — this prevents silent cross-workspace data leaks.

Raw SQL that intentionally bypasses the listener (e.g. Alembic migrations, admin queries) must include an inline comment: `# workspace scoping bypassed — [reason]`.

### 3.3 Model classes

Each model file defines one or more SQLAlchemy 2.x `DeclarativeBase` mapped classes. Key implementation notes per model:

**`User`** (`app/db/models/user.py`)

Plain mapped class, no mixins. The `DEFAULT_USER_ID` constant is defined in `app/constants.py`.

**`Workspace`** (`app/db/models/workspace.py`)

Inherits `UserScopedMixin` only (not `WorkspaceScopedMixin`, because Workspace itself is the scoping root). The `context_panel_max_chars` value is not stored in the database — it is added to Workspace response shapes by the handler reading it from configuration.

**`Persona`** (`app/db/models/persona.py`)

Inherits `WorkspaceScopedMixin`. The `is_mentor` field is `Boolean NOT NULL DEFAULT FALSE`. When `is_mentor=True`, the handler must also create the Mentor `Conversation` row in the same transaction (see Section 11.1).

**`PersonaSystemPromptVersion`** (`app/db/models/persona.py`)

No mixin (scoped through `persona_id → personas → workspace_id`). The `ON DELETE CASCADE` constraint ensures versions are deleted with the Persona.

**`Conversation`** (`app/db/models/conversation.py`)

Inherits `WorkspaceScopedMixin`. The `auto_summary` column is `JSONB` nullable. The `is_mentor_conversation` column is `Boolean NOT NULL DEFAULT FALSE`, set once at creation and never changed.

**`ConversationPersona`** (`app/db/models/conversation.py`)

No direct mixin — scoped through `conversation_id`. `persona_id` is nullable FK (set to NULL on Persona deletion). No unique constraint on `(conversation_id, persona_id)`.

**`Message`** (`app/db/models/message.py`)

`conversation_persona_id` is nullable FK. `message_subtype` is a plain `Text` column — not a Postgres enum — so new values can be added without a migration.

**`ConversationSummary`** (`app/db/models/conversation_summary.py`)

One row per Conversation (`UNIQUE` on `conversation_id`). Not exposed via any API response.

**`OrchestratorSuggestion`** (`app/db/models/orchestrator.py`)

Inherits `WorkspaceScopedMixin`. Status enum: `pending | accepted | dismissed`.

**`ReviewAgentRun`** (`app/db/models/review_agent.py`)

Inherits `WorkspaceScopedMixin`.

**`ReviewAgentFinding`** (`app/db/models/review_agent.py`)

No mixin — scoped through `persona_id`. `run_id` is nullable FK (set to NULL on run deletion). `target_passage` is nullable TEXT.

**`MentorEpisodicMemory`** and **`MentorSemanticMemory`** (`app/db/models/mentor_memory.py`)

Both inherit `WorkspaceScopedMixin`.

**`Document`** (`app/db/models/document.py`)

Inherits `WorkspaceScopedMixin`. `source_conversation_id` is nullable FK set to NULL on Conversation deletion (does not cascade delete).

---

## 4. FastAPI Application Setup

### 4.1 Lifespan context manager — `app/main.py`

`app/main.py` is the **composition root** for the entire backend. It is the only module that reads `BackendConfig`. All services and singletons are constructed here and receive their collaborators as constructor arguments — never config objects, never module-level singletons imported from elsewhere. No other module calls `dynaconf.settings` or reads `BackendConfig` directly.

The FastAPI application uses a single lifespan context manager that handles startup and shutdown in strict order:

**Startup sequence:**

1. Validate configuration — load and parse `BackendConfig` (Pydantic model). Fail fast if required keys are absent.
2. Initialise the SQLAlchemy async engine and session factory (from `app/db/engine.py`).
3. Call `PostgresSaver.setup()` — creates LangGraph checkpointer tables if they do not exist. Uses a synchronous connection or `asyncio.run()` wrapper as required by the LangGraph API.
4. Build the `ModelGateway` singleton — constructed with the model config values it needs (extracted from `BackendConfig`); calls `init_chat_model` internally.
5. Build all services that depend on `ModelGateway` — `RollingSummary`, `ReviewAgentRunner`, `MentorPromoter` — each receives a constructed `ModelGateway` and a named `structlog.BoundLogger`.
6. Build the `ConversationOrchestrator` singleton — compiles the LangGraph graph with the `PostgresSaver` checkpointer and `ModelGateway` injected.
7. Wire APScheduler jobs with the service instances built above.
8. Run crash-recovery for Review Agent: query `review_agent_runs` for rows with `status='running'` older than `REVIEW_AGENT_CRASH_GRACE_SECONDS` (default 300) and reset them to `status='failed'`.
9. Start the APScheduler `AsyncIOScheduler` with the Review Agent cron job and Episodic→Semantic promotion job registered.

**Shutdown sequence:**

1. Shut down the `AsyncIOScheduler` (wait for in-progress jobs to complete up to a grace period).
2. Dispose the SQLAlchemy engine.

### 4.2 Middleware stack — `app/main.py`

Middleware is registered in reverse execution order (last registered = first to run). Desired execution order on each request:

1. **CORS middleware** — `fastapi.middleware.cors.CORSMiddleware`; allowed origins read from `CORS_ALLOWED_ORIGINS` config key.
2. **`CurrentUserMiddleware`** — `app/middleware/current_user.py`; calls `resolve_current_user()` and sets `current_user_id` ContextVar.
3. **`WorkspaceContextMiddleware`** — `app/middleware/workspace.py`; for workspace-scoped routes, extracts `workspace_id` from the path or `X-Workspace-ID` header and sets `current_workspace_id` ContextVar. For non-workspace-scoped endpoints (stream, control signals, suggestion accept/dismiss, test, consultation), workspace context is resolved differently (see Section 4.3).

### 4.3 Workspace context resolution for non-workspace-scoped endpoints

The following endpoints are not under `/workspaces/{workspace_id}/` but still require workspace scoping:

- `GET /conversations/{conversation_id}/stream`
- `POST /conversations/{conversation_id}/pause`
- `POST /conversations/{conversation_id}/resume`
- `POST /conversations/{conversation_id}/cancel`
- `POST /conversations/{conversation_id}/suggestions/{suggestion_id}/accept`
- `POST /conversations/{conversation_id}/suggestions/{suggestion_id}/dismiss`
- `POST /personas/{persona_id}/test`
- `POST /personas/{persona_id}/consultation`

**HTTP mechanism — `X-Workspace-ID` request header:** The frontend must include an `X-Workspace-ID` header on every request to these endpoints, populated from the currently active workspace stored in the frontend's route state. This is the agreed workspace context mechanism. The frontend plan must match this header name exactly.

**Resolution mechanism:** Despite the header being available, these handlers additionally bootstrap workspace context from a trusted PK lookup to guard against a mismatched or forged header. The handler loads the `conversations` (or `personas`) row by its primary key using an unscoped query (bypassing the ORM listener with an explicit inline comment). The `workspace_id` is then read from the loaded row and set into the `current_workspace_id` ContextVar before any further scoped queries execute. If the `X-Workspace-ID` header value does not match the `workspace_id` from the PK lookup, the handler returns 403. This is the one legitimate use of an unscoped query — bootstrap and validate the ContextVar from a trusted PK lookup.

```python
# app/routers/stream.py — example pattern
# Workspace scoping bootstrapped from conversation PK — see Section 4.3 of implementation plan
conversation = await db.get(Conversation, conversation_id)
if conversation is None:
    raise HTTPException(status_code=404)
workspace_id_from_header = request.headers.get("X-Workspace-ID")
if workspace_id_from_header != conversation.workspace_id:
    raise HTTPException(status_code=403)
current_workspace_id.set(conversation.workspace_id)
# All subsequent queries are now workspace-scoped by the ORM listener
```

This pattern applies uniformly to all non-workspace-scoped endpoints. The frontend populates `X-Workspace-ID` from its active workspace context; the backend validates it against the resource's actual `workspace_id`.

### 4.4 Dependency injection — `app/dependencies.py`

Three application-wide dependencies are available via `Depends()`:

- `get_db() -> AsyncSession` — yields an `AsyncSession` from the session factory; commits on success, rolls back on exception.
- `get_model_gateway() -> ModelGateway` — returns the singleton `ModelGateway` built at startup.
- `get_orchestrator() -> ConversationOrchestrator` — returns the singleton `ConversationOrchestrator` built at startup.

Route handlers declare these as parameters:

```python
async def send_message(
    conversation_id: UUID,
    body: MessageCreate,
    db: AsyncSession = Depends(get_db),
    orchestrator: ConversationOrchestrator = Depends(get_orchestrator),
):
```

### 4.5 Router registration — `app/main.py`

All routers from `app/routers/` are registered on the `FastAPI` application instance with appropriate prefixes. The SSE stream and control signal routers are registered without a workspace prefix.

### 4.6 Error handling — `app/errors.py` and `app/results.py`

**Global exception handler (`app/errors.py`):** Catches any unhandled exception and formats all responses per the contract's error shape: `{ "message": "...", "code": "..." }`. Standard FastAPI 422 validation errors retain their default Pydantic shape. All `500` errors return `{ "message": "Internal server error" }` without leaking stack traces in production.

**Service layer result types (`app/results.py`):** Expected domain failures — those the API contract documents as 4XX responses — are returned from service methods as explicit result types, not raised as exceptions. Routers inspect the result and raise `HTTPException` themselves.

```python
# app/results.py
from dataclasses import dataclass, field
from typing import Generic, TypeVar

T = TypeVar("T")

@dataclass
class Ok(Generic[T]):
    value: T

@dataclass
class Err:
    code: str           # matches the contract's error `code` field
    message: str
    status: int         # 409, 422, etc.
    detail: dict | None = field(default=None)  # e.g. {"blocking_conversations": [...]}

ServiceResult = Ok[T] | Err
```

Router pattern:

```python
result = await conversation_service.end(conversation_id)
if isinstance(result, Err):
    raise HTTPException(
        status_code=result.status,
        detail={"message": result.message, "code": result.code, **(result.detail or {})},
    )
return result.value
```

Expected failure codes returned by service methods include (but are not limited to):

| Code | Status | Returned by |
| --- | --- | --- |
| `persona_active_in_conversation` | 409 | `PersonaService.delete` |
| `mentor_already_exists` | 409 | `PersonaService.create` |
| `mentor_name_immutable` | 409 | `PersonaService.patch` |
| `mentor_cannot_be_deleted` | 409 | `PersonaService.delete` |
| `last_persona_in_conversation` | 409 | `ConversationService.remove_persona` |
| `conversation_not_idle` | 409 | `ConversationService.send_message` |
| `conversation_busy` | 409 | `ConversationService.pause` |
| `conversation_not_paused` | 409 | `ConversationService.resume` |
| `context_panel_too_long` | 422 | `ConversationService.patch` |
| `report_generation_in_progress` | 409 | `DocumentService.generate` |
| `review_agent_already_running` | 409 | `ReviewAgentService.trigger` |
| `finding_not_active` | 409 | `ReviewAgentService.dismiss` |
| `suggestion_already_resolved` | 409 | `OrchestratorService.resolve_suggestion` |
| `invalid_mode_for_participant_count` | 409 | `ConversationService.add_persona` |

---

## 5. ModelGateway

### 5.1 Class design — `app/gateway/model_gateway.py`

`ModelGateway` is instantiated once at application startup and held as a singleton. It owns the configured `BaseChatModel` instance and centralises all retry and timeout policy. It does not import from any route or service module.

```python
class ModelGateway:
    def __init__(self, config: BackendConfig) -> None:
        self._model = init_chat_model(
            model=config.model,
            model_provider=config.model_provider,
            base_url=config.model_base_url,
            api_key=config.api_key,
            configurable_fields=("model", "model_provider"),
        )

    async def invoke(self, messages: list[BaseMessage], *, purpose: str) -> str: ...
    async def stream(self, messages: list[BaseMessage], *, purpose: str) -> AsyncIterator[str]: ...
    async def invoke_structured(
        self, messages: list[BaseMessage], schema: type[T], *, purpose: str
    ) -> T: ...
    async def embed(self, text: str) -> list[float]: ...
```

### 5.2 The four methods

**`invoke`**

Used for: auto-naming, context compression, Report generation.

Calls `self._model.ainvoke(messages)` via the retry wrapper. Returns the content string from the `AIMessage` response.

**`stream`**

Used for: Persona/Mentor turns outside the graph (test panel, consultation mode).

Calls `self._model.astream(messages)` and yields token strings. The retry wrapper applies to the stream setup; mid-stream errors are surfaced as SSE error events by the caller.

**`invoke_structured`**

Used for: Orchestrator `PersonaSuggestion`, Review Agent `PersonaFinding`, Mentor Episodic→Semantic promotion, P2P speaker selection, auto-summary `ConversationSummary`.

Calls `self._model.with_structured_output(schema).ainvoke(messages)`. Returns a validated instance of the Pydantic `schema` type `T`.

**`embed`**

Used for: loop/repetition detection (similarity hashing), future Semantic Memory retrieval.

V1: calls `self._model.embed_query(text)` if the model supports embeddings; otherwise falls back to a character-hash distance as a stand-in (the P2P repetition detection hash does not require real embeddings — it uses content hashing rather than semantic similarity in V1). The interface is defined so the real embedding call drops in without changing call sites.

### 5.3 `purpose` parameter

The `purpose` string is passed to all four methods. It is used for:

- Logging: every model call is logged at `DEBUG` level with `purpose`, token count, and latency.
- Retry policy dispatch: different `purpose` values may map to different retry configurations in future (e.g. `review_agent_finding` could use more retries than `auto_naming`). In V1, all purposes share the same retry policy.
- Observability: the `purpose` value is attached to traces as a tag.

Canonical `purpose` values:

| Purpose string | Method | Call site |
| --- | --- | --- |
| `auto_naming` | `invoke` | Context assembler, post-first-compression |
| `context_compression` | `invoke` | `RollingSummary` |
| `report_generation` | `invoke` | Document report job |
| `review_agent_finding` | `invoke_structured` | `ReviewAgentRunner` |
| `orchestrator_suggestion` | `invoke_structured` | `orchestrator_check` node |
| `auto_summary` | `invoke_structured` | End-of-conversation background task |
| `mentor_episodic_to_semantic` | `invoke_structured` | `MentorPromoter` |
| `conversation_observer` | `invoke_structured` | `ConversationObserver` |
| `p2p_speaker_selection` | `invoke_structured` | `SpeakerSelector` |
| `persona_test` | `stream` | Test panel handler |
| `consultation` | `stream` | Consultation handler |
| `embed_repetition` | `embed` | P2P repetition detection |

### 5.4 Retry and timeout policy

In V1, all model calls share a single retry policy using `tenacity`:

- 3 attempts with exponential backoff (1s, 2s, 4s)
- Retry on: network errors, `RateLimitError`, `ServiceUnavailableError`
- No retry on: `InvalidRequestError`, authentication errors
- Per-call timeout: `MODEL_CALL_TIMEOUT_SECONDS` (config, default 60)
- On final failure: re-raise the exception to the caller (handler converts to 503 for request-path calls; background jobs log and proceed)

### 5.5 ModelGateway boundary rule

`app/gateway/model_gateway.py` is the only module outside of `app/orchestrator/` that may import from `langchain.*`. All other application modules import `ModelGateway` only. Any violation requires an explicit inline comment: `# ModelGateway boundary exception — [reason]`.

---

## 6. ConversationOrchestrator

### 6.1 Overview

`ConversationOrchestrator` (`app/orchestrator/`) is the containment boundary for all LangGraph and LangChain use related to multi-Persona conversation flow. It is instantiated once at startup and injected via `Depends()`. Code outside this module does not import from `langchain.*` or `langgraph.*`.

### 6.2 LangGraph state schema — `app/orchestrator/state.py`

```python
class ConversationState(TypedDict):
    # Core conversation state
    conversation_id: str
    workspace_id: str
    mode: str                        # "one_to_one" | "round_robin" | "p2p"
    messages: list[BaseMessage]      # LangGraph message list (managed by graph)

    # P2P turn-taking state (ADR-017)
    p2p_turn_count: int              # Resets to 0 on user message
    p2p_response_shingles: list[set[str]]  # Rolling window of last N shingle sets (see Section 6.9)
    messages_since_last_eval: int    # Resets to 0 on Orchestrator eval attempt

    # Control signals
    pause_requested: bool            # Set by POST /pause; cleared by POST /resume
    exchange_cancelled: bool         # Set by POST /cancel; cleared on next user message

    # Metadata
    current_persona_id: str | None   # Active speaker for round-robin/p2p
    participant_ids: list[str]       # Ordered list of active conversation_persona_ids
    has_sse_listener: bool           # Updated by SSE manager on connect/disconnect

    # Auto-naming
    title_auto_set: bool             # True once auto-name has been applied
```

The checkpointer persists all fields. LangGraph manages the `messages` list natively; application code reads it but does not write it directly outside of the graph.

### 6.3 Graph definition — `app/orchestrator/graph.py`

The graph is a `StateGraph[ConversationState]`. Nodes and edges:

**Nodes:**

| Node name | Function | Description |
| --- | --- | --- |
| `receive_message` | `nodes.receive_message` | Persists the incoming user message; updates `last_message_at`; resets P2P counters if recovering from turn-cap or repetition |
| `route_message` | Conditional edge function | Routes to `persona_response`, `orchestrator_direct`, or `await_user` based on state |
| `persona_response` | `nodes.persona_response` | Assembles context, calls `BaseChatModel`, streams tokens, persists the response message |
| `orchestrator_check` | `nodes.orchestrator_check` | Post-response hook; evaluates frequency gate; calls `invoke_structured` for `PersonaSuggestion`; persists to `orchestrator_suggestions`; emits SSE event |
| `orchestrator_direct` | `nodes.orchestrator_direct` | Handles `@Orchestrator` mentions; produces targeted summary or direct response; streams via SSE |
| `p2p_turn_check` | Conditional edge function | P2P only: checks turn cap, repetition, pause flag, delay; routes to `persona_response` or `await_user` |
| `await_user` | `nodes.await_user` | Terminal node for turn; emits `idle` or `exchange_paused` SSE event depending on reason; routes to `receive_message` on next user input |
| `emit_busy` | `nodes.emit_busy` | Emits `busy` SSE event at turn start |
| `emit_idle` | `nodes.emit_idle` | Emits `idle` SSE event at turn end (non-P2P or single-turn) |

**Edge structure:**

```text
START
  └── receive_message
        └── route_message (conditional)
              ├── [if @Orchestrator] → orchestrator_direct → await_user (P2P: pause first)
              └── [else] → emit_busy → persona_response
                                └── orchestrator_check (fire-and-forget)
                                └── [if one_to_one] → emit_idle → await_user
                                └── [if round_robin] → listener_check (conditional)
                                                            ├── [no listener] → await_user (pause)
                                                            └── [has listener] → route_message (next cycle)
                                └── [if p2p] → p2p_turn_check (conditional)
                                                    ├── [continue] → emit_busy → persona_response
                                                    └── [pause/cap/repetition/no listener] → await_user
```

### 6.4 PostgresSaver wiring

The graph is compiled with `checkpointer=PostgresSaver(conn_string)`. The `thread_id` for the checkpointer is the `conversation_id`. On every state transition, LangGraph automatically persists the updated `ConversationState` via the checkpointer.

`POST /pause` and `POST /resume` interact with the checkpointer directly:

```python
# app/routers/control.py
async def pause_conversation(conversation_id: str):
    state = await orchestrator.get_state(conversation_id)
    await orchestrator.update_state(conversation_id, {"pause_requested": True})
```

### 6.5 `graph.stream()` to SSE event mapping — `app/orchestrator/sse_bridge.py`

The `ConversationOrchestrator` exposes a `stream_turn(conversation_id, user_message)` async generator that:

1. Calls `graph.astream(input, config={"thread_id": conversation_id}, stream_mode="messages")`
2. Inspects each yielded event from the graph
3. Translates graph events to named SSE event payloads per the API contract

The SSE bridge translates:

| LangGraph stream event | SSE event |
| --- | --- |
| Node entry: `persona_response` | `busy` — `{}` |
| Token chunk from `BaseChatModel` | `token` — `{ "content": "...", "conversation_persona_id": "..." }` |
| Node exit: `persona_response` (message persisted) | `response_complete` — `{ "message_id": "...", "conversation_persona_id": "...", "content": "..." }` |
| `orchestrator_check` emits suggestion | `orchestrator_suggestion` — `{ "suggestion_id": "...", ... }` |
| Node entry: `await_user` (normal) | `idle` — `{}` |
| Node entry: `await_user` (user_pause) | `exchange_paused` — `{ "pause_reason": "user_pause" }` |
| Node entry: `await_user` (turn_cap) | `exchange_paused` — `{ "pause_reason": "turn_cap" }` |
| Node entry: `await_user` (repetition) | `exchange_paused` — `{ "pause_reason": "repetition_detected" }` |
| Node entry: `await_user` (workspace_switch) | Sets `pause_requested=True` in state; emits `paused` event when stream re-opens (see Section 10.1) |

### 6.6 Workspace-switch interrupt detection

The SSE manager (`app/sse/manager.py`) maintains a set of active `conversation_id`s with connected SSE clients. The `has_listener()` check runs **inside the LangGraph graph** — specifically as a conditional edge evaluated after each Persona response node completes, before the graph decides whether to continue to the next turn or route to `await_user`.

**Placement in the graph:** After every `persona_response` node completes, a conditional edge (`listener_check` in Round-Robin, `p2p_turn_check` in P2P) calls `sse_manager.has_listener(conversation_id)`. If no listener is present, the edge sets `pause_requested = True` in LangGraph state and routes to `await_user` instead of continuing to the next turn. The conditional check runs on every turn in all multi-Persona modes (Round-Robin and P2P), not just P2P — a workspace switch can occur during any multi-Persona conversation.

```python
# Inside the conditional edge function — runs within the LangGraph graph
def listener_check(state: ConversationState) -> str:
    if not sse_manager.has_listener(state["conversation_id"]):
        # User has navigated away; pause at this turn boundary
        # pause_requested is set via state update before routing
        return "await_user_workspace_switch"
    if state["mode"] == "p2p":
        return "p2p_turn_check"
    return "route_message"
```

The `has_sse_listener` state field mirrors the current SSE connection state. It is updated by the SSE manager at connect and disconnect so the graph can also read it from the checkpointer between graph invocations (e.g. if the graph resumes after a restart and needs to know if the client is connected).

No polling task runs outside the graph. The check is a single in-graph conditional edge call per turn — no race conditions with reconnecting clients, since the check occurs only at inter-turn boundaries after a response has fully completed.

### 6.7 `orchestrator_check` node — post-message hook

The `orchestrator_check` node runs after every `persona_response` node completion. It is implemented as a sequential node (not a parallel branch), so the user-facing response completes before the Orchestrator evaluation begins. The hook:

1. Increments `messages_since_last_eval`
2. Checks if `messages_since_last_eval >= ORCHESTRATOR_EVAL_EVERY_N`. If not, returns without calling the model.
3. Resets `messages_since_last_eval = 0`
4. Loads active participants and Workspace Personas from the DB
5. If all Workspace Personas are already participants, skips suggestion evaluation (no one to suggest)
6. Applies the mode-appropriate threshold: `ORCHESTRATOR_1TO1_THRESHOLD` for `one_to_one` mode, `ORCHESTRATOR_THRESHOLD` otherwise
7. Calls `BaseChatModel.with_structured_output(PersonaSuggestion).ainvoke(...)` (inside the graph — Tier 2, not via `ModelGateway`)
8. If a suggestion is produced and passes the threshold:
   - Inserts a row into `orchestrator_suggestions`
   - Emits an `orchestrator_suggestion` SSE event via the SSE manager
9. Records dismissed suggestions in suppression check (reads `orchestrator_suggestions` table filtered by `status='dismissed'` within the last `ORCHESTRATOR_SUPPRESSION_WINDOW_MESSAGES` messages)

### 6.8 `orchestrator_direct` node — `@Orchestrator` mention handling

Detection: the `route_message` node checks if `content.lstrip().lower().startswith("@orchestrator")` (case-insensitive prefix match — `@Orchestrator`, `@orchestrator`, and `@ORCHESTRATOR` all trigger this path).

In P2P mode, the graph pauses the autonomous exchange before routing to `orchestrator_direct`. After the Orchestrator responds, the graph routes to `await_user` — the exchange does not restart automatically.

In Round-Robin mode, the current in-flight Persona response completes first (handled by the graph's edge ordering), then `orchestrator_direct` runs.

The node loads the current System Prompt and recent conversation history, then calls `BaseChatModel` directly (Tier 2, inside graph) for a targeted summary or direct response. Streams via the SSE bridge.

If this is the first targeted summary and the Conversation has not been manually renamed, auto-naming is triggered (see Section 7.3).

### 6.9 P2P turn-taking logic — `app/orchestrator/nodes.py` and `app/orchestrator/speaker_selection.py`

**Hard cap check:** `p2p_turn_check` conditional edge reads `state["p2p_turn_count"]`. If `>= MAX_P2P_TURNS`, routes to `await_user` with reason `turn_cap`.

**Minimum delay:** The `persona_response` node awaits `asyncio.sleep(P2P_TURN_DELAY_SECONDS)` at the start of each P2P turn. This gives the event loop a reliable window to process pause/cancel signals from HTTP endpoints.

**Repetition detection — chosen algorithm (character n-gram Jaccard similarity):**

The near-duplicate detection algorithm uses character n-gram shingles and Jaccard similarity. This detects paraphrased repetition, not just exact duplicates. SHA256 alone is explicitly not used here — it only detects exact byte-for-byte duplicates and cannot detect near-matches.

**Normalisation:** Before comparison, each response is normalised:

```python
import re

def normalise_response(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^\w\s]", "", text)   # strip punctuation
    text = re.sub(r"\s+", " ", text).strip()  # collapse whitespace
    return text
```

**Shingle set construction:** The normalised text is split into overlapping character n-grams (shingles) of width `SHINGLE_SIZE = 4` (a fixed constant, not configurable — character 4-grams provide good sensitivity for prose repetition):

```python
def shingle(text: str, size: int = 4) -> set[str]:
    return {text[i:i+size] for i in range(len(text) - size + 1)}
```

**What is stored in LangGraph state:** The `p2p_response_shingles` field in `ConversationState` holds a rolling window of the last `P2P_REPETITION_WINDOW` shingle sets — one `set[str]` per prior response. Raw response text and SHA256 hashes are not stored.

**Comparison at each turn:** After a Persona response is generated, the normalised shingle set for the new response is computed and compared against every entry in the window using Jaccard similarity:

```python
def jaccard(a: set[str], b: set[str]) -> float:
    if not a and not b:
        return 1.0
    intersection = len(a & b)
    union = len(a | b)
    return intersection / union if union > 0 else 0.0
```

If any Jaccard similarity score between the new response's shingle set and any window entry equals or exceeds `P2P_REPETITION_THRESHOLD` (config, default `0.85`), the graph routes to `await_user` with reason `repetition_detected`.

**Window update:** The new shingle set is appended to `p2p_response_shingles` and the oldest entry is dropped if the window exceeds `P2P_REPETITION_WINDOW` entries.

**Speaker selection** (`app/orchestrator/speaker_selection.py`):

```python
def select_next_speaker(
    last_response_content: str,
    active_participant_ids: list[str],
    participant_names: dict[str, str],  # conversation_persona_id → snapshot_name
    current_speaker_id: str,
) -> str:
    # Primary: scan last response for another Persona's name
    for persona_id, name in participant_names.items():
        if re.search(rf"\b{re.escape(name)}\b", last_response_content, re.IGNORECASE):
            if persona_id != current_speaker_id:
                return persona_id
    # Fallback: round-robin
    idx = active_participant_ids.index(current_speaker_id)
    return active_participant_ids[(idx + 1) % len(active_participant_ids)]
```

For round-robin mode (non-autonomous), the same function is used but without the turn-cap and repetition checks.

### 6.10 P2P counter reset on user message

When `receive_message` processes a user message and the graph is in `await_user` state (recovering from turn-cap or repetition), the node resets:

- `p2p_turn_count = 0` — reset on every user message in P2P mode regardless of the pause reason. This means the hard cap re-triggers only after `MAX_P2P_TURNS` additional autonomous turns following the user's input, which is the intended behaviour.
- `p2p_response_shingles = []` — only when recovering from `repetition_detected`. Clearing the shingle window on turn-cap recovery is not necessary and is omitted.

This is the message-based recovery path (ADR-017).

---

## 7. Context Window Management

### 7.1 `CompressionStrategy` interface — `app/context/strategy.py`

```python
class CompressionStrategy(ABC):
    @abstractmethod
    async def compress(
        self,
        messages: list[BaseMessage],
        existing_summary: str | None,
        *,
        conversation_id: str,
        db: AsyncSession,
    ) -> str:
        """
        Folds the oldest block of messages into the summary.
        Returns the updated summary text.
        Persists the updated summary to conversation_summaries in the same DB session.
        """
```

### 7.2 `RollingSummary` — `app/context/rolling_summary.py`

The only V1 implementation of `CompressionStrategy`. On trigger:

1. Takes the oldest block of verbatim messages (those beyond the `last_N` window)
2. Calls `ModelGateway.invoke(fold_prompt, purpose="context_compression")` at `temperature=0`
3. Upserts the result into `conversation_summaries` for the given `conversation_id`
4. Returns the new summary text

### 7.3 Context assembly — `app/context/assembler.py`

`ContextAssembler.build(conversation_id, db, model_gateway) -> list[BaseMessage]`

Assembly order per architecture Section 7.1:

1. `SystemMessage(snapshot_system_prompt)` — from the active `conversation_personas` row (most recent `joined_at` where `left_at IS NULL`). Exception: for `is_mentor_conversation`, read `personas.system_prompt` directly.
2. `SystemMessage(context_panel)` — from `conversations.context_panel`. Always included in full.
3. For Mentor Conversations only: Episodic entries as `SystemMessage`s (ordered by `sequence_number` ascending), then Semantic documents as `SystemMessage`s (ordered by `updated_at DESC`). Loaded via `MentorMemoryRetriever.load_context()`.
4. `AIMessage(rolling_summary)` — from `conversation_summaries` if a row exists for this Conversation.
5. Last-N verbatim messages — loaded from `messages` in ascending `created_at` order, fitted into the remaining token budget.

**Token budget calculation:**

```python
CHARS_PER_TOKEN = 4  # V1 approximation
used_chars = len(system_prompt) + len(context_panel) + len(rolling_summary or "")
remaining_chars = config.context_window * CHARS_PER_TOKEN - used_chars
# Fill from most recent messages backward until remaining_chars is consumed
```

**Compression trigger:** After assembly, if `(len(rolling_summary or "") + total_verbatim_chars) > 0.75 * config.context_window * CHARS_PER_TOKEN`, trigger compression before returning the assembled messages.

**Auto-naming trigger:** After the first compression event for a Conversation where `title_auto_set=False` and the title matches the default pattern `"New Conversation "`, call `ModelGateway.invoke(auto_name_prompt, purpose="auto_naming")` and update `conversations.title`. Set `title_auto_set=True` in graph state. No SSE event is emitted for the title change — the frontend re-fetches `GET /conversations/{id}` on next access.

### 7.4 Context Panel enforcement

The handler for `PATCH /conversations/{id}` enforces `CONTEXT_PANEL_MAX_CHARS` from configuration. If `len(context_panel) > CONTEXT_PANEL_MAX_CHARS`, raise `ContextPanelTooLongError`. This is a backend-authoritative check — the frontend may enforce client-side as a courtesy but the backend is the source of truth.

---

## 8. Mentor Memory System

### 8.1 `MentorMemoryRetriever` interface — `app/mentor/retriever.py`

```python
class MentorMemoryRetriever(ABC):
    @abstractmethod
    async def load_context(
        self,
        workspace_id: str,
        mentor_persona_id: str,
        db: AsyncSession,
    ) -> tuple[list[MentorEpisodicMemory], list[MentorSemanticMemory]]:
        """
        Returns (episodic_entries, semantic_documents).
        episodic_entries: ordered by sequence_number ASC
        semantic_documents: ordered by updated_at DESC
        """
```

**V1 implementation**: `AllEntriesRetriever` — loads all rows for the given `mentor_persona_id`. One query per table. No filtering by `promoted_at` or `pending_promotion` — all entries are included regardless of promotion state. Entries with `pending_promotion=True` are valid episodic content awaiting semantic extraction and must appear in Mentor context; they are not errors or incomplete records.

### 8.2 Working → Episodic promotion — `app/mentor/promoter.py`

**Trigger:** Called by `RollingSummary.compress()` inside the same DB transaction when the Conversation is `is_mentor_conversation=True`.

Also triggered by `POST /conversations/{id}/chapter` (chapter boundary) — the same compression step runs before the chapter system message is inserted.

**Logic:**

1. Read the existing `rolling_summary` for the Mentor Conversation from `conversation_summaries`
2. Determine the next `sequence_number` (MAX + 1 for this `mentor_persona_id`)
3. Insert a new `mentor_episodic_memories` row with `summary_text = rolling_summary`, `source_type = 'self'`, `source_conversation_id = conversation_id`, `pending_promotion = True`
4. Clear the `rolling_summary` in `conversation_summaries` (or delete the row) so the Mentor Conversation starts fresh after the chapter
5. All steps in the same DB transaction as the compression step

### 8.3 Episodic → Semantic promotion — `app/mentor/promoter.py`

**Trigger:** APScheduler scheduled job only (not session-end triggered).

**Logic per Episodic row with `pending_promotion=True` and `promoted_at IS NULL`:**

1. Set `current_workspace_id` and `current_user_id` ContextVars from the row's `workspace_id` and `user_id`
2. Load all existing `mentor_semantic_memories` titles for this `mentor_persona_id`
3. Call `ModelGateway.invoke_structured(messages, EpisodicToSemanticOutput, purpose="mentor_episodic_to_semantic")` with:
   - Input: `summary_text` + `existing_semantic_titles`
   - Schema: `EpisodicToSemanticOutput` — `list[SemanticFact]` where `SemanticFact = { target_document_title: str, content: str, mode: "new" | "update" }`
4. If the output list is empty: set `promoted_at = now()`, `pending_promotion = False`. No semantic rows created.
5. For each `SemanticFact`:
   - `mode = "new"`: insert a new `mentor_semantic_memories` row
   - `mode = "update"`: query for an existing row with matching `title`, update `content_markdown` and `updated_at`
6. Set `promoted_at = now()`, `pending_promotion = False` on the Episodic row
7. All DB writes in a single transaction

**Failure handling:**

- Retry 3× with exponential backoff (1s, 2s, 4s) on model errors
- On final failure: set `promoted_at = now()`, `pending_promotion = False`, log `promotion_skipped` with the Episodic row ID — memory system stays unblocked
- Process crash mid-call: `promoted_at` is not set, so the row is retried on the next scheduled run

**ContextVar management for the scheduled job:**

```python
# app/jobs/mentor_promotion_job.py
async def run_episodic_to_semantic_promotion():
    async with get_session() as db:
        pending_rows = await db.execute(
            select(MentorEpisodicMemory).where(
                MentorEpisodicMemory.pending_promotion == True,
                MentorEpisodicMemory.promoted_at == None
            )
        )
        for row in pending_rows.scalars():
            # Set ContextVars before processing each row
            current_workspace_id.set(row.workspace_id)
            current_user_id.set(row.user_id)
            await promoter.promote_episodic_to_semantic(row, db)
```

### 8.4 Conversation Observer — `app/conversation_observer/observer.py`

**Trigger:** Spawned as `asyncio.create_task` from the `POST /conversations/{id}/end` handler after the auto-summary task completes. Wired in `app/jobs/conversation_observer_task.py`.

**Guard:** Query `personas` for a row with `workspace_id = conversation.workspace_id` and `is_mentor = True`. If no Mentor exists, return immediately — nothing to write.

**Idempotency:** The `UNIQUE (mentor_persona_id, source_conversation_id)` constraint prevents duplicate observations if the task is retried.

**Logic:**

1. Set `current_workspace_id` and `current_user_id` ContextVars from the concluded Conversation's fields.
2. Load all messages for the Conversation where `role IN ('user', 'persona', 'mentor')`, ordered by `created_at ASC`.
3. Call `ModelGateway.invoke_structured(messages, ConversationObservation, purpose="conversation_observer")`. The system prompt instructs the model to analyse the user's communication patterns — not Persona behaviour.
4. Serialise the `ConversationObservation` output into a formatted Markdown `summary_text`.
5. Determine the next `sequence_number` (MAX + 1 for this `mentor_persona_id`).
6. Insert one `mentor_episodic_memories` row: `source_type='observed'`, `source_conversation_id=conversation_id`, `pending_promotion=True`, `summary_text` from step 4.
7. All DB writes in a single transaction.

**Failure handling:** Log and discard on any error — this is non-critical-path. The unique constraint ensures a partial failure cannot produce a duplicate on retry.

**Backfill on Mentor creation:** `POST /workspaces/{id}/personas` with `is_mentor=True` spawns an additional `asyncio.create_task` that calls `ConversationObserver.backfill(workspace_id, mentor_persona_id, db)`. This method:

1. Queries all `conversations` in the Workspace with `status='ended'` and `is_mentor_conversation=False`, ordered by `ended_at ASC`.
2. For each, calls the standard observer logic above (guard, model call, insert). The unique constraint makes this safe to re-run.

**`ConversationObservation` schema — `app/conversation_observer/schemas.py`:**

```python
class ConversationObservation(BaseModel):
    communication_patterns: list[str]
    # Recurring patterns in how the user structured their points and arguments
    explanation_challenges: list[str]
    # Moments where the user had to repeat or re-explain themselves
    bridging_techniques: list[str]
    # Techniques used to bridge expertise gaps (analogies, examples, reframing)
    effectiveness_notes: list[str]
    # Observations on how well those techniques appeared to land
    summary_text: str
    # Prose summary combining the above, formatted as Markdown for episodic storage
```

**`EpisodicMemoryResponse` schema update — `app/schemas/mentor_memory.py`:**

```python
class EpisodicMemoryResponse(BaseModel):
    id: UUID
    sequence_number: int
    summary_text: str
    source_type: Literal["self", "observed"]
    source_conversation_id: UUID | None
    created_at: datetime
```

### 8.5 Chapter detection

In `GET /workspaces/{workspace_id}/conversations/{conversation_id}`, the handler computes `chapter_prompt_required`:

```python
from datetime import datetime, timezone

chapter_prompt_required = (
    conversation.is_mentor_conversation
    and conversation.last_message_at is not None
    and conversation.last_message_at.astimezone(timezone.utc).date()
       != datetime.now(timezone.utc).date()
)
```

All comparison is UTC. The `last_message_at` column stores `TIMESTAMPTZ` so Postgres retains timezone information.

### 8.6 Mentor `conversation_persona_id` format in SSE token events

The `token` and `response_complete` SSE events carry `conversation_persona_id` to identify the speaker. For the Mentor Conversation, there is no `conversation_personas` row. The value for Mentor token events is defined as:

```text
"mentor:{persona_id}"
```

Where `persona_id` is the Mentor Persona's UUID. This is a stable, predictable synthetic identifier that the frontend can distinguish from a real `conversation_personas` UUID. The frontend team must be informed of this format before implementing the Mentor stream rendering.

Example: if the Mentor Persona has ID `018e1234-0000-7000-8000-000000000001`, the `conversation_persona_id` in all token events for that Mentor Conversation is `"mentor:018e1234-0000-7000-8000-000000000001"`.

---

## 9. Review Agent and Conversation Observer Wiring

### 9.0 Conversation Observer wiring — `app/jobs/conversation_observer_task.py`

The Conversation Observer is not an APScheduler job. It is spawned as a fire-and-forget `asyncio.create_task` from the `POST /conversations/{id}/end` handler, after the auto-summary task is dispatched:

```python
# app/routers/conversations.py — end handler (abbreviated)
asyncio.create_task(run_auto_summary(conversation_id, db, model_gateway))
asyncio.create_task(run_conversation_observer(conversation_id, db, model_gateway, log))
```

`run_conversation_observer` (in `app/jobs/conversation_observer_task.py`) sets ContextVars and delegates to `ConversationObserver.observe(conversation_id, db)`.

**Backfill wiring:** The Mentor Persona creation handler (`POST /workspaces/{id}/personas` with `is_mentor=True`) additionally spawns:

```python
asyncio.create_task(
    run_conversation_observer_backfill(workspace_id, mentor_persona_id, db, model_gateway, log)
)
```

### 9.1 APScheduler job wiring — `app/jobs/review_agent_job.py`

The Review Agent is registered as a `CronTrigger` job in the `AsyncIOScheduler`:

```python
scheduler.add_job(
    run_review_agent,
    trigger=CronTrigger.from_crontab(config.REVIEW_AGENT_SCHEDULE),
    id="review_agent_nightly",
    max_instances=1,
    coalesce=True,
    misfire_grace_time=300,
)
```

`REVIEW_AGENT_SCHEDULE` is a cron string, e.g. `"0 2 * * *"` (2am daily). Default in `backend/config.json`.

### 9.2 `review_agent_runs` row-lock and crash recovery

Both the nightly cron job and `POST /review-agent/run` share the same `run_review_agent` function. The function begins with a row-lock check:

```python
async def run_review_agent(workspace_id: str | None = None):
    # If triggered by nightly cron, iterate all Workspaces
    # If triggered by POST /run, workspace_id is set
    workspaces = [workspace_id] if workspace_id else await get_all_workspace_ids(db)

    for ws_id in workspaces:
        existing_run = await db.execute(
            select(ReviewAgentRun)
            .where(ReviewAgentRun.workspace_id == ws_id, ReviewAgentRun.status == "running")
        )
        if existing_run.scalar_one_or_none():
            continue  # Skip; already running for this Workspace

        run = ReviewAgentRun(workspace_id=ws_id, user_id=DEFAULT_USER_ID, status="running", started_at=now())
        db.add(run)
        await db.commit()  # Commit run row before LLM calls
        ...
```

**Crash recovery** (called at application startup, Section 4.1):

```python
stale_cutoff = datetime.now(timezone.utc) - timedelta(seconds=config.REVIEW_AGENT_CRASH_GRACE_SECONDS)
await db.execute(
    update(ReviewAgentRun)
    .where(ReviewAgentRun.status == "running", ReviewAgentRun.started_at < stale_cutoff)
    .values(status="failed", error_message="Recovered from process crash")
)
```

### 9.3 Review Agent sweep logic — `app/review_agent/runner.py`

For each Workspace being reviewed:

1. Set `current_workspace_id` and `current_user_id` ContextVars
2. Load all Personas in the Workspace
3. For each Persona:
   a. Load all concluded Conversations (`status='ended'`) that have messages involving this Persona
   b. Load the Persona's existing `active` and `stale` findings
   c. **Reconciliation step** — for each `active` or `stale` finding, the reconciliation logic distinguishes three distinct outcomes:

      **Outcome 1 — Issue resolved:** Re-run the LLM (`ModelGateway.invoke_structured` with `PersonaFinding` schema, `purpose="review_agent_finding"`) against the Persona's recent Conversations and current System Prompt. If the LLM does not identify the same underlying issue in its new findings list (i.e. no new finding has materially equivalent evidence), the issue is considered resolved. Set `finding.status = "dismissed"` and `finding.updated_at = now()`. The finding is retained in the table as `dismissed` (not deleted) so it appears in the audit history and suppression logic.

      **Outcome 2 — Passage moved:** If the LLM identifies the same underlying issue (matching or semantically equivalent evidence in the same area of behaviour), but `target_passage` no longer appears verbatim in the current `personas.system_prompt`, re-run the LLM specifically against the current System Prompt to locate the updated passage. If the LLM returns a new `target_passage` and `suggestion_text` that reference an existing passage in the current prompt, update the finding in place: set `finding.target_passage = new_target_passage`, `finding.suggestion_text = new_suggestion_text`, `finding.status = "active"`, `finding.updated_at = now()`. This restores the apply-endpoint guarantee that `target_passage` is always valid for `active` findings.

      **Outcome 3 — Stale (no replacement found):** If the issue persists (LLM still surfaces it) but the LLM cannot identify a valid `target_passage` in the updated prompt (returns `None` or a passage that is not present verbatim in `system_prompt`), set `finding.status = "stale"`, `finding.updated_at = now()`. The `stale` status signals to the user that the finding requires a fresh Review Agent run before it can be applied.

      The apply endpoint relies on the guarantee that `target_passage` is always valid when `status = "active"`. This guarantee holds because: (a) the staleness-on-prompt-edit path (Section 9.5) sets findings to `stale` whenever `target_passage` becomes invalid due to a manual prompt edit, and (b) the reconciliation step (Outcome 2 above) restores validity or downgrades to `stale` when the issue persists. No graceful-failure path is needed in the apply endpoint.

   d. Prepare the LLM prompt: current `system_prompt` + conversation excerpts + list of existing `dismissed` findings (for suppression)
   e. Call `ModelGateway.invoke_structured(messages, PersonaFinding, purpose="review_agent_finding")`
   f. For each new finding returned:
      - Check if a substantively equivalent finding (same `target_passage`, same `suggestion_text`) already exists as `active` — skip if so (no duplicate)
      - Insert new `ReviewAgentFinding` row with `status='active'`
4. Update `ReviewAgentRun` to `status='complete'`, set `completed_at`
5. On any unhandled exception: update to `status='failed'`, set `error_message`

### 9.4 `PersonaFinding` schema — `app/review_agent/schemas.py`

```python
class PersonaFinding(BaseModel):
    evidence_text: str          # Quoted excerpt showing the issue
    target_passage: str | None  # Passage to replace; None for additive suggestions
    suggestion_text: str        # Proposed replacement or addition
```

`ModelGateway.invoke_structured` with this schema returns a `list[PersonaFinding]` per Persona.

### 9.5 Finding lifecycle and staleness detection

**Staleness on prompt edit:**

Any path that writes to `personas.system_prompt` (PATCH endpoint, finding apply, consultation apply) must call `mark_stale_findings_for_persona(persona_id, new_system_prompt, db)` in the same transaction:

```python
async def mark_stale_findings_for_persona(persona_id: str, new_prompt: str, db: AsyncSession):
    active_findings = await db.execute(
        select(ReviewAgentFinding)
        .where(
            ReviewAgentFinding.persona_id == persona_id,
            ReviewAgentFinding.status == "active",
            ReviewAgentFinding.target_passage != None
        )
    )
    for finding in active_findings.scalars():
        if finding.target_passage not in new_prompt:
            finding.status = "stale"
            finding.updated_at = now()
```

This function is called after every `system_prompt` update, regardless of how the update occurred.

### 9.6 Finding apply — `POST /findings/{id}/apply`

```python
# In the same DB transaction:
# 1. Find-and-replace or append
if finding.target_passage is not None:
    new_prompt = persona.system_prompt.replace(
        finding.target_passage, finding.suggestion_text, 1
    )
else:
    new_prompt = persona.system_prompt + "\n\n" + finding.suggestion_text

# 2. Update persona (via shared helper — universal versioning rule)
await update_system_prompt(persona, new_prompt, db)

# 3. Set finding to actioned
finding.status = "actioned"
finding.updated_at = now()

# 4. Mark stale any other active findings whose target_passage is gone
await mark_stale_findings_for_persona(persona.id, new_prompt, db)

await db.commit()
```

The `update_system_prompt()` helper (Section 13.2) handles both the `system_prompt` field update and the `persona_system_prompt_versions` insert in a single call, per the universal versioning rule.

### 9.7 Interactive consultation — `POST /personas/{id}/consultation`

The consultation handler uses `ModelGateway.stream` (not `BaseChatModel` direct — this is outside the LangGraph graph). Context includes:

- The Persona's current `system_prompt` from `personas` table
- All `active` and `stale` findings for this Persona (from `review_agent_findings`)
- The in-memory session history for this `session_id` (accumulated turns from previous messages in this session)

Full conversation histories are excluded. The session is maintained in a module-level `dict[str, list[BaseMessage]]` keyed by `session_id`, with TTL managed by a background async cleanup task (configurable `CONSULTATION_SESSION_TTL_SECONDS`, default 3600).

If the consultation results in the user applying a suggestion (a frontend-driven action calling `POST /personas/{id}/findings/{id}/apply`), the `update_system_prompt()` helper is used — inserting a `persona_system_prompt_versions` row in the same transaction per the universal versioning rule (Section 13.2), and staleness detection follows the standard path (Section 9.5).

---

## 10. SSE Streaming

### 10.1 SSE endpoint — `app/routers/stream.py`

`GET /conversations/{conversation_id}/stream` returns a `sse_starlette.sse.EventSourceResponse`. The response is an async generator that:

1. Bootstraps workspace context from the Conversation row and validates the `X-Workspace-ID` header (Section 4.3)
2. Registers the connection in `SseManager`; updates `has_sse_listener = True` in LangGraph graph state via the checkpointer
3. **Workspace-switch resume handshake (Option A):** Immediately after registering, before entering the main event-queue wait loop, reads the current LangGraph graph state for this conversation via the checkpointer. If `pause_requested = True` is found in the state, the stream generator emits a `paused` SSE event as the first event in the stream — before any events from the main event queue are yielded. This happens in the stream generator's preamble, prior to entering the `graph.stream()` loop. The frontend receives this `paused` event, renders the Resume button, and the user calls `POST /conversations/{id}/resume`. The graph then resumes and emits `busy`/`idle` as normal. This handshake is identical whether the pause originated from a user-initiated `POST /pause` or from a workspace-switch interrupt — both converge on `pause_requested = True`.
4. Enters a wait loop on the per-conversation event queue in `SseManager`
5. For each queued event, formats it as an SSE frame and yields it
6. On client disconnect: deregisters from `SseManager`; updates `has_sse_listener = False` in LangGraph graph state. If a P2P or Round-Robin exchange is active, the graph will detect the absence of a listener at the next turn boundary via the `listener_check` conditional edge (Section 6.6) and set `pause_requested = True`.

**Stream generator structure (pseudocode):**

```python
async def stream_conversation(conversation_id: str, request: Request):
    # Step 1: bootstrap and validate workspace context
    conversation = await bootstrap_workspace_context(conversation_id, request)

    # Step 2: register SSE listener
    queue = sse_manager.connect(conversation_id)
    await orchestrator.update_state(conversation_id, {"has_sse_listener": True})

    async def generate():
        try:
            # Step 3: preamble — emit paused event if conversation is paused
            graph_state = await orchestrator.get_state(conversation_id)
            if graph_state.get("pause_requested"):
                yield SseEvent("paused", {}).to_sse_frame(next_event_id())

            # Step 4: main event queue loop
            while True:
                event = await queue.get()
                if event is DISCONNECT_SENTINEL:
                    break
                yield event.to_sse_frame(next_event_id())
        finally:
            # Step 6: deregister on disconnect
            sse_manager.disconnect(conversation_id)
            await orchestrator.update_state(conversation_id, {"has_sse_listener": False})

    return EventSourceResponse(generate())
```

### 10.2 SseManager — `app/sse/manager.py`

An in-memory registry. In V1 (single-process), this is a module-level dict:

```python
class SseManager:
    def __init__(self):
        self._queues: dict[str, asyncio.Queue] = {}

    def connect(self, conversation_id: str) -> asyncio.Queue:
        queue = asyncio.Queue()
        self._queues[conversation_id] = queue
        return queue

    def disconnect(self, conversation_id: str):
        self._queues.pop(conversation_id, None)

    def has_listener(self, conversation_id: str) -> bool:
        return conversation_id in self._queues

    async def publish(self, conversation_id: str, event: SseEvent):
        if conversation_id in self._queues:
            await self._queues[conversation_id].put(event)
```

The `ConversationOrchestrator`'s `sse_bridge` publishes events via `sse_manager.publish()`.

### 10.3 Server-assigned event IDs

Each event is assigned a monotonically increasing integer ID scoped to the conversation. IDs are stored in-memory in `SseManager`. On reconnection, `Last-Event-ID` is read from the request header — the backend replays events from that ID forward by holding a short ring buffer (last 100 events per conversation, configurable) in `SseManager`.

### 10.4 SSE event dataclasses — `app/sse/events.py`

```python
@dataclass
class SseEvent:
    event_type: str   # "token", "response_complete", etc.
    data: dict        # JSON-serialisable payload matching the contract

    def to_sse_frame(self, event_id: int) -> str:
        return f"id: {event_id}\nevent: {self.event_type}\ndata: {json.dumps(self.data)}\n\n"
```

---

## 11. REST Endpoint Handlers

Each router file in `app/routers/` contains one handler function per endpoint. Handlers follow this pattern: validate input, execute business logic, return a Pydantic response schema. All DB interactions go through the `AsyncSession` from `Depends(get_db)`.

### 11.1 Workspaces — `app/routers/workspaces.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `list_workspaces` | GET | `/workspaces` | Query all Workspaces for `current_user_id`; append `context_panel_max_chars` from config to each response |
| `get_workspace` | GET | `/workspaces/{id}` | Load single Workspace; 404 if not found |
| `create_workspace` | POST | `/workspaces` | Insert Workspace row; append `context_panel_max_chars` |
| `rename_workspace` | PATCH | `/workspaces/{id}` | Update `name`; 404 if not found |
| `delete_workspace` | DELETE | `/workspaces/{id}` | Cascade delete in order: messages, conversation_personas, conversation_summaries, LangGraph checkpointer state (call `checkpointer.adelete_thread()` for each Conversation), orchestrator_suggestions, conversations, folders, review_agent_findings, review_agent_runs, mentor_episodic_memories, mentor_semantic_memories, persona_system_prompt_versions, personas, then Workspace itself. Set any `running` review_agent_run for this Workspace to `failed` before deletion. |

### 11.2 Personas — `app/routers/personas.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `list_personas` | GET | `/workspaces/{ws_id}/personas` | Query all Personas for Workspace |
| `get_persona` | GET | `/workspaces/{ws_id}/personas/{id}` | Load single Persona |
| `create_persona` | POST | `/workspaces/{ws_id}/personas` | Insert Persona + `PersonaSystemPromptVersion` in one transaction. If `is_mentor=True`: check no existing Mentor (409); also create Mentor Conversation row (`is_mentor_conversation=True`, `mode='one_to_one'`, `status='active'`) in same transaction |
| `update_persona` | PATCH | `/workspaces/{ws_id}/personas/{id}` | Update allowed fields; if `system_prompt` in body: call `update_system_prompt()` helper + call `mark_stale_findings_for_persona()` in same transaction; if `name` in body and `is_mentor=True`: 409 `MENTOR_NAME_IMMUTABLE` |
| `delete_persona` | DELETE | `/workspaces/{ws_id}/personas/{id}` | Check `is_mentor=True` → 409; check `conversation_personas` active in open Conversations → 409 with `blocking_conversations`; delete Persona (ON DELETE CASCADE handles versions); delete `review_agent_findings` for this Persona |

### 11.3 Persona test — `app/routers/personas.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `test_persona` | POST | `/personas/{id}/test` | Validate `X-Workspace-ID` header and bootstrap workspace context from persona PK (Section 4.3); load Persona; retrieve or create in-memory test session for `session_id`; call `ModelGateway.stream` with System Prompt and session history; return SSE stream |

### 11.4 Conversations — `app/routers/conversations.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `list_conversations` | GET | `/workspaces/{ws_id}/conversations` | Query all Conversations for Workspace; include `is_mentor_conversation` |
| `get_conversation` | GET | `/workspaces/{ws_id}/conversations/{id}` | Load Conversation + all `conversation_personas` rows (active and left); compute `chapter_prompt_required` (Section 8.5); return full detail |
| `create_conversation` | POST | `/workspaces/{ws_id}/conversations` | Validate mode/participant count; reject Mentor persona_id in `persona_ids`; insert Conversation; insert `conversation_personas` snapshots for each persona_id; title = `"New Conversation {ISO_TIMESTAMP}"` |
| `update_conversation` | PATCH | `/workspaces/{ws_id}/conversations/{id}` | 403 if ended; mode change: check idle + valid participant count; if mode changed: insert `mode_changed` system message; enforce `CONTEXT_PANEL_MAX_CHARS` on `context_panel`; `participants` not returned (use GET for full detail) |
| `end_conversation` | POST | `/workspaces/{ws_id}/conversations/{id}/end` | If P2P in progress: cancel internally first; query for qualifying messages (`role IN ('user','persona','mentor')`); if none: cascade delete + return `{deleted:true}`; else: set `status='ended'`, `ended_at=now()`; fire-and-forget async task for auto-summary generation; return `{deleted:false, conversation:...}` |
| `delete_conversation` | DELETE | `/workspaces/{ws_id}/conversations/{id}` | Cascade delete; do not delete Documents with `source_conversation_id = this` |

**Auto-summary background task:**

```python
async def generate_auto_summary(conversation_id: str, model_gateway: ModelGateway):
    async with get_session() as db:
        messages = await load_all_messages(conversation_id, db)
        result = await model_gateway.invoke_structured(
            messages, ConversationSummary, purpose="auto_summary"
        )
        await db.execute(
            update(Conversation)
            .where(Conversation.id == conversation_id)
            .values(auto_summary=result.model_dump())
        )
        await db.commit()
```

Triggered with `asyncio.create_task()` immediately after the response is returned to the client.

### 11.5 Conversation participants — `app/routers/conversations.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `add_persona_to_conversation` | POST | `/workspaces/{ws_id}/conversations/{id}/personas` | 409 if ended/not idle/already active; take snapshot; insert `conversation_personas`; insert `persona_joined` system message |
| `remove_persona_from_conversation` | DELETE | `…/{id}/personas/{cp_id}` | 409 if ended/not idle/last Persona; set `left_at=now()`; insert `persona_left` system message; if remaining participants < mode minimum: downgrade mode + insert `mode_changed` system message; return `updated_mode` |
| `refresh_persona_snapshot` | POST | `…/{id}/personas/{cp_id}/refresh` | 409 if ended/not idle; insert new `conversation_personas` row with current live Persona data; old row preserved |

### 11.6 Mentor chapter — `app/routers/mentor.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `start_chapter` | POST | `/workspaces/{ws_id}/conversations/{id}/chapter` | 403 if not `is_mentor_conversation`; 409 if not idle; insert `chapter_boundary` system message; trigger Working→Episodic compression (same transaction) |

### 11.7 Messages — `app/routers/messages.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `list_messages` | GET | `…/conversations/{id}/messages` | Cursor-based pagination using `before` (UUID v7 cursor); `ORDER BY created_at ASC`; `has_more` and `next_cursor` derived from whether more rows exist beyond the page |
| `send_message` | POST | `…/conversations/{id}/messages` | 403 if ended; 409 if busy (graph state not `await_user`); persist user message; update `last_message_at`; call `orchestrator.invoke_turn(conversation_id)` as background task; return persisted message immediately |

**Conversation busy check:**

Before persisting the user message, the handler checks the LangGraph graph state via `orchestrator.get_state(conversation_id)`. If the state is not `await_user`, return 409 `CONVERSATION_BUSY`.

### 11.8 Folders — `app/routers/folders.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `list_folders` | GET | `/workspaces/{ws_id}/folders` | Query + compute `conversation_count` per folder via a count subquery |
| `create_folder` | POST | `/workspaces/{ws_id}/folders` | Insert folder; `conversation_count = 0` in response |
| `rename_folder` | PATCH | `/workspaces/{ws_id}/folders/{id}` | Update name; re-query count for response |
| `delete_folder` | DELETE | `/workspaces/{ws_id}/folders/{id}` | Set `folder_id=NULL` on all Conversations; return `unassigned_conversation_ids` |

### 11.9 Documents — `app/routers/documents.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `list_documents` | GET | `/workspaces/{ws_id}/documents` | Query; optional `source_conversation_id` filter; `content_markdown` excluded from list |
| `get_document` | GET | `/workspaces/{ws_id}/documents/{id}` | Full document including `content_markdown` |
| `generate_document` | POST | `/workspaces/{ws_id}/documents/generate` | 403 if source Conversation not ended; 409 if pending Document exists for this Conversation; insert Document with `status='pending'`; fire-and-forget background task calling `ModelGateway.invoke`; return 202 |
| `rename_document` | PATCH | `/workspaces/{ws_id}/documents/{id}` | Update title |
| `delete_document` | DELETE | `/workspaces/{ws_id}/documents/{id}` | Delete document; source Conversation unaffected |

### 11.10 Review Agent — `app/routers/review_agent.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `get_run_status` | GET | `/workspaces/{ws_id}/review-agent/status` | Query latest `ReviewAgentRun` for Workspace; return `has_run=False` if none |
| `trigger_run` | POST | `/workspaces/{ws_id}/review-agent/run` | 409 if `status='running'` exists for Workspace; insert run row; fire-and-forget `run_review_agent(workspace_id)`; return 202 |
| `list_findings` | GET | `/workspaces/{ws_id}/personas/{id}/findings` | Return `active` and `stale` findings only |
| `apply_finding` | POST | `…/findings/{id}/apply` | 409 if not `active`; apply (Section 9.6) |
| `dismiss_finding` | POST | `…/findings/{id}/dismiss` | 409 if not `active`; set `status='dismissed'` |
| `consultation` | POST | `/personas/{id}/consultation` | Validate `X-Workspace-ID` header and bootstrap workspace context from persona PK (Section 4.3); consultation handler (Section 9.7) |

### 11.11 Mentor Memory Inspector — `app/routers/mentor.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `get_episodic_memories` | GET | `…/personas/{id}/memory/episodic` | 403 if not `is_mentor`; return all Episodic entries ordered by `sequence_number ASC` |
| `get_semantic_memories` | GET | `…/personas/{id}/memory/semantic` | 403 if not `is_mentor`; return all Semantic entries ordered by `updated_at DESC` |

### 11.12 Control signals — `app/routers/control.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `pause_conversation` | POST | `/conversations/{id}/pause` | Validate `X-Workspace-ID` header and bootstrap workspace context (Section 4.3); 403 if ended; set `pause_requested=True` in graph state via checkpointer |
| `resume_conversation` | POST | `/conversations/{id}/resume` | Validate `X-Workspace-ID` header and bootstrap workspace context; 403 if ended; 409 if not paused; clear `pause_requested=False`; trigger graph resume |
| `cancel_conversation` | POST | `/conversations/{id}/cancel` | Validate `X-Workspace-ID` header and bootstrap workspace context; 403 if ended; set `exchange_cancelled=True` in graph state; graph transitions to idle on next tick |

### 11.13 Orchestrator suggestion responses — `app/routers/conversations.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `accept_suggestion` | POST | `/conversations/{id}/suggestions/{sid}/accept` | Validate `X-Workspace-ID` header and bootstrap workspace context (Section 4.3); 409 if not `pending`/ended/not idle; take snapshot; insert `conversation_personas`; insert `orchestrator_suggestion_accepted` system message; if mode was `one_to_one`: switch to `round_robin`, insert `mode_changed` system message; set suggestion `status='accepted'`; return updated_mode |
| `dismiss_suggestion` | POST | `/conversations/{id}/suggestions/{sid}/dismiss` | Validate `X-Workspace-ID` header and bootstrap workspace context; 409 if not `pending`; set suggestion `status='dismissed'` |

### 11.14 Conversation export — `app/routers/conversations.py`

| Handler | Method | Path | Key business logic |
| --- | --- | --- | --- |
| `export_conversation` | GET | `/workspaces/{ws_id}/conversations/{id}/export` | 409 if not idle; load all messages in `created_at ASC` order; format as Markdown with speaker labels; return `Response(content=..., media_type="text/markdown", headers={"Content-Disposition": ...})` |

---

## 12. Configuration

### 12.1 `backend/config.json` — committed base config

```json
{
  "model": "REQUIRED",
  "model_provider": "REQUIRED",
  "model_base_url": "REQUIRED",
  "database_url": "REQUIRED",
  "context_window": "REQUIRED",
  "cors_allowed_origins": ["http://localhost:5173"],
  "CONTEXT_PANEL_MAX_CHARS": 2000,
  "ORCHESTRATOR_EVAL_EVERY_N": 1,
  "ORCHESTRATOR_THRESHOLD": 0.7,
  "ORCHESTRATOR_1TO1_THRESHOLD": 0.9,
  "ORCHESTRATOR_SUPPRESSION_WINDOW_MESSAGES": 20,
  "MAX_P2P_TURNS": 10,
  "P2P_TURN_DELAY_SECONDS": 1.0,
  "P2P_REPETITION_WINDOW": 5,
  "P2P_REPETITION_THRESHOLD": 0.85,
  "REVIEW_AGENT_SCHEDULE": "0 2 * * *",
  "REVIEW_AGENT_CRASH_GRACE_SECONDS": 300,
  "MENTOR_PROMOTION_SCHEDULE": "0 3 * * *",
  "MODEL_CALL_TIMEOUT_SECONDS": 60,
  "CONSULTATION_SESSION_TTL_SECONDS": 3600,
  "TEST_SESSION_TTL_SECONDS": 3600,
  "SSE_EVENT_BUFFER_SIZE": 100
}
```

**Required fields** (no default — operator must set):

- `model` — model name passed to `init_chat_model`
- `model_provider` — provider key passed to `init_chat_model`
- `model_base_url` — endpoint URL for the configured provider
- `database_url` — Postgres connection string
- `context_window` — model-dependent token window size (integer)

**Secret, override-only** (never in committed base file):

- `api_key` — provider API key; set in `backend/config.override.json` only

### 12.2 `backend/config.override.json` — gitignored local override

Example:

```json
{
  "model": "llama3.2:3b",
  "model_provider": "ollama",
  "model_base_url": "http://localhost:11434",
  "database_url": "postgresql+asyncpg://ai_council:password@localhost:5432/ai_council",
  "context_window": 8192,
  "api_key": ""
}
```

### 12.3 Pydantic validation model — `app/config.py`

```python
class BackendConfig(BaseSettings):
    # Required fields (no default)
    model: str
    model_provider: str
    model_base_url: str
    database_url: str
    context_window: int

    # Optional secret
    api_key: str = ""

    # Configurable with defaults
    cors_allowed_origins: list[str] = ["http://localhost:5173"]
    CONTEXT_PANEL_MAX_CHARS: int = 2000
    ORCHESTRATOR_EVAL_EVERY_N: int = 1
    ORCHESTRATOR_THRESHOLD: float = 0.7
    ORCHESTRATOR_1TO1_THRESHOLD: float = 0.9
    ORCHESTRATOR_SUPPRESSION_WINDOW_MESSAGES: int = 20
    MAX_P2P_TURNS: int = 10
    P2P_TURN_DELAY_SECONDS: float = 1.0
    P2P_REPETITION_WINDOW: int = 5
    P2P_REPETITION_THRESHOLD: float = 0.85
    REVIEW_AGENT_SCHEDULE: str = "0 2 * * *"
    REVIEW_AGENT_CRASH_GRACE_SECONDS: int = 300
    MENTOR_PROMOTION_SCHEDULE: str = "0 3 * * *"
    MODEL_CALL_TIMEOUT_SECONDS: int = 60
    CONSULTATION_SESSION_TTL_SECONDS: int = 3600
    TEST_SESSION_TTL_SECONDS: int = 3600
    SSE_EVENT_BUFFER_SIZE: int = 100

    model_config = ConfigDict(extra="ignore")
```

Dynaconf loads `backend/config.json` then applies `backend/config.override.json` as a layer. The merged dict is validated by `BackendConfig(**merged)` at startup. Missing required fields raise `ValidationError` immediately — the process does not start.

### 12.4 Constants — `app/constants.py`

```python
DEFAULT_USER_ID = "00000000-0000-7000-8000-000000000001"

# message_subtype values
SUBTYPE_PERSONA_JOINED = "persona_joined"
SUBTYPE_PERSONA_LEFT = "persona_left"
SUBTYPE_CHAPTER_BOUNDARY = "chapter_boundary"
SUBTYPE_ORCHESTRATOR_SUGGESTION_ACCEPTED = "orchestrator_suggestion_accepted"
SUBTYPE_MODE_CHANGED = "mode_changed"
```

---

## 13. Background Job Harnesses

### 13.1 ContextVar setup requirement

Both background jobs (Review Agent and Episodic→Semantic promotion) must set `current_workspace_id` and `current_user_id` ContextVars before executing any scoped query. This is the symmetric requirement with the HTTP middleware (ADR-016).

For the Review Agent sweep (which iterates all Workspaces):

```python
# app/jobs/review_agent_job.py
async def run_review_agent_job():
    async with get_session() as db:
        # Workspace iteration — unscoped query to get all workspace IDs
        # workspace scoping bypassed — bootstrap iteration; each workspace is processed separately
        workspace_ids = await db.execute(select(Workspace.id))
        for ws_id in workspace_ids.scalars():
            current_workspace_id.set(ws_id)
            current_user_id.set(DEFAULT_USER_ID)
            await runner.run_for_workspace(ws_id, db)
```

For the Episodic→Semantic promotion job:

```python
# app/jobs/mentor_promotion_job.py
async def run_episodic_to_semantic_job():
    async with get_session() as db:
        # pending_promotion query — unscoped; bootstrap ContextVar per row
        # workspace scoping bypassed — bootstrap ContextVar per row (see Section 8.3)
        pending = await db.execute(
            select(MentorEpisodicMemory)
            .where(
                MentorEpisodicMemory.pending_promotion == True,
                MentorEpisodicMemory.promoted_at == None
            )
        )
        for row in pending.scalars():
            current_workspace_id.set(row.workspace_id)
            current_user_id.set(row.user_id)
            await promoter.promote_episodic_to_semantic(row, db)
```

### 13.2 Universal versioning rule — enforcement pattern

Every write to `personas.system_prompt` goes through a shared helper to enforce the versioning rule:

```python
# app/db/helpers.py
async def update_system_prompt(
    persona: Persona,
    new_prompt: str,
    db: AsyncSession,
) -> None:
    """
    Updates personas.system_prompt and inserts a persona_system_prompt_versions row
    in the same DB session (caller commits).
    Must be called for ALL system_prompt writes without exception.
    """
    persona.system_prompt = new_prompt
    persona.updated_at = now()
    db.add(PersonaSystemPromptVersion(
        id=new_uuid(),
        persona_id=persona.id,
        system_prompt=new_prompt,
        created_at=now(),
    ))
```

All call sites (PATCH Persona, finding apply, consultation apply) use this helper. Code review enforces that no direct assignment to `persona.system_prompt` exists outside this function.

---

## 14. Testing Strategy

### 14.1 Guiding principles

Per `documentation/process/development-principles-backend.md`:

- Every test carries exactly one pytest marker: `unit`, `integration`, or `e2e`
- `unit` tests use fakes from `tests/fakes/`, have no I/O, and run in milliseconds
- `integration` tests use a real test database (Postgres in Docker Compose dev stack) with Alembic migrations applied
- `FakeModelGateway` is the canonical substitute for `ModelGateway` in unit tests — never mock `BaseChatModel` directly
- SSE event emission is tested by subscribing to `FakeSseManager` in tests, not by asserting HTTP response bodies
- P2P graph tests use a real `PostgresSaver` checkpointer against the test DB (integration tier)
- Top-level service classes receive a `structlog.BoundLogger` as a constructor argument; tests pass `structlog.testing.capture_logs()` or a no-op bound logger

### 14.2 Unit test patterns — `tests/unit/`

All unit tests are marked `@pytest.mark.unit`. They use fakes from `tests/fakes/` and make no I/O calls.

**`test_model_gateway.py`**

Tests all four `ModelGateway` methods using a `FakeBaseChatModel` (a concrete fake of the LangChain base). Verifies:

- `purpose` is logged correctly
- Retry policy fires on transient errors
- `invoke_structured` returns a validated Pydantic instance
- Final failure re-raises

**`test_rolling_summary.py`**

Tests `RollingSummary.compress()` with `FakeModelGateway`. Verifies:

- Summary is correctly upserted in `conversation_summaries`
- Compression trigger threshold is respected
- Called with `purpose="context_compression"`

**`test_context_assembler.py`**

Tests `ContextAssembler.build()` with a `FakeConversationRepository` and `FakeModelGateway`. Verifies:

- Assembly order: System Prompt, Context Panel, Episodic (Mentor), Semantic (Mentor), rolling summary, verbatim messages
- Token budget is respected
- Mentor Conversation reads `personas.system_prompt` directly, not from `conversation_personas`
- Non-Mentor Conversation reads from `conversation_personas`
- `chapter_prompt_required` UTC comparison (parametrised: same day / different day)

**`test_speaker_selection.py`**

Tests `select_next_speaker()` with various response contents and participant lists. Verifies:

- Addressability detection (name present, name absent, case-insensitive)
- Round-robin fallback
- Wraps around participant list correctly

**`test_review_agent_runner.py`**

Tests `ReviewAgentRunner.run_for_workspace()` with `FakeModelGateway`. Verifies:

- Row-lock check prevents duplicate runs
- Reconciliation Outcome 1 (resolved): finding set to `dismissed` when LLM no longer surfaces the issue
- Reconciliation Outcome 2 (passage moved): `target_passage` and `suggestion_text` updated when issue persists but passage location has changed
- Reconciliation Outcome 3 (stale): finding set to `stale` when issue persists but LLM cannot locate a valid replacement passage
- New findings are not duplicated if already `active`
- `PersonaFinding` list is inserted correctly
- Service returns `Ok` on success; returns `Err` with appropriate code on expected failures

**`test_conversation_observer.py`**

Tests `ConversationObserver.observe()` with `FakeModelGateway`. Verifies:

- Guard: returns immediately without DB write if no Mentor Persona exists in the Workspace
- Happy path: one `mentor_episodic_memories` row inserted with `source_type='observed'`, correct `source_conversation_id`, `pending_promotion=True`
- Idempotency: second call for the same `source_conversation_id` raises no error (unique constraint handled gracefully)
- Backfill: `ConversationObserver.backfill()` processes all concluded non-Mentor Conversations in sequence

**`test_mentor_promoter.py`**

Tests `MentorPromoter.promote_episodic_to_semantic()` with `FakeModelGateway`. Verifies:

- Empty output list: Episodic row retired without semantic writes
- `mode="new"`: new `MentorSemanticMemory` row inserted
- `mode="update"`: existing row updated
- Failure after 3 retries: row retired with `promotion_skipped` log
- `promoted_at` not set on crash (idempotency)

### 14.3 Integration test patterns — `tests/integration/`

All integration tests are marked `@pytest.mark.integration`. They use a dedicated test database. `conftest.py` provides:

```python
@pytest.fixture(scope="session")
async def test_engine():
    # Create engine against TEST_DATABASE_URL
    # Apply all Alembic migrations
    yield engine
    # Drop all tables

@pytest.fixture
async def db(test_engine):
    # Yield an AsyncSession; roll back after each test

@pytest.fixture
def set_workspace_context(workspace_id):
    # Sets current_workspace_id and current_user_id ContextVars
    # Resets after test

@pytest.fixture
async def default_workspace(db):
    # Creates and returns a test Workspace

@pytest.fixture
async def mentor_persona(db, default_workspace):
    # Creates and returns a Mentor Persona + Mentor Conversation
```

**`test_workspaces.py`**

Tests full CRUD against a real DB. Verifies `context_panel_max_chars` is present in responses.

**`test_personas.py`**

Tests Persona CRUD including:

- `system_prompt` write always inserts a `persona_system_prompt_versions` row
- `is_mentor=True` creates Mentor Conversation
- Delete 409 when active in open Conversation
- `mark_stale_findings_for_persona` called on system_prompt update

**`test_conversations.py`**

Tests Conversation CRUD including:

- `POST /end` with qualifying messages: `status='ended'`, `deleted=false`
- `POST /end` with no qualifying messages: cascade delete, `deleted=true`
- `context_panel` enforcement
- Participant add/remove/refresh
- `chapter_prompt_required` flag value (requires UTC mocking)

**`test_messages.py`**

Tests message pagination (cursor-based). Verifies `has_more`, `next_cursor` values. Verifies `last_message_at` updated on message insert.

**`test_review_agent.py`**

Tests the full Review Agent sweep against a real DB with a mocked `ModelGateway`. Verifies finding lifecycle end-to-end: create → apply → stale detection → dismiss. Also verifies all three reconciliation outcomes end-to-end against a real DB.

**`test_mentor_memory.py`**

Tests Working→Episodic promotion trigger and Episodic→Semantic promotion against a real DB with a mocked `ModelGateway`. Verifies `pending_promotion` flag lifecycle.

---

## 15. Items Resolved from Self-Review and Plan Review

The following items were identified in the self-review of the API contract (`documentation/tasks/senior-developer-backend-review.md`) or the subsequent implementation plan review (`documentation/tasks/implementation-plan-review.md`) and are resolved in this plan:

1. **Workspace context for non-workspace-scoped endpoints (Section 3.1 of contract review)**: Resolved in Section 4.3 above — `X-Workspace-ID` header is the agreed HTTP mechanism; PK-lookup bootstrap with header validation applied uniformly to all eight non-workspace-scoped endpoints. The frontend must send this header on every request to these endpoints.

2. **Mentor `conversation_persona_id` format in SSE token events (Section 3.2 of contract review)**: Resolved in Section 8.6 above — format is `"mentor:{persona_id}"`. Frontend team must be informed before Mentor stream implementation.

3. **`@Orchestrator` detection is server-side (Section 3.3 of contract review)**: Resolved in Section 6.8 above — detection is a case-insensitive `content.lstrip().lower().startswith("@orchestrator")` check inside the `route_message` node. No client-side preprocessing.

4. **Auto-naming side-effect (Section 4.2 of contract review)**: Resolved in Section 7.3 above — no SSE event is emitted for auto-naming; the title is written to `conversations.title` and the frontend discovers it on the next `GET /conversations/{id}` fetch.

5. **`chapter_prompt_required` UTC comparison (Section 4.5 of contract review)**: Resolved in Section 8.5 above — comparison uses `datetime.now(timezone.utc).date()` with explicit UTC on both sides.

6. **Review Agent reconciliation step incomplete (B-1)**: Resolved in Section 9.3 above — all three reconciliation outcomes documented: Outcome 1 (resolved → `dismissed`), Outcome 2 (passage moved → update `target_passage` and `suggestion_text`), Outcome 3 (stale → `stale`).

7. **Workspace-switch resume protocol (B-2)**: Resolved in Section 10.1 above — Option A adopted: stream generator emits `paused` event in its preamble if `pause_requested=True` on stream re-open; frontend shows Resume button; user calls `POST /resume`; graph resumes normally.

8. **Workspace-switch interrupt detection mechanism (B-3)**: Resolved in Section 6.6 above — `has_listener()` check runs inside the LangGraph graph as a `listener_check` conditional edge after each Persona response node, on every turn in Round-Robin and P2P modes.

9. **Repetition detection algorithm (B-4)**: Resolved in Section 6.9 above — character n-gram (4-gram) shingle sets with Jaccard similarity; shingle sets stored in LangGraph state (not SHA256 hashes); Jaccard ≥ `P2P_REPETITION_THRESHOLD` triggers `repetition_detected`.

10. **Workspace context HTTP mechanism for non-workspace-scoped endpoints (M-1)**: Resolved in Section 4.3 above — `X-Workspace-ID` request header, validated against the PK-lookup result. All relevant handler descriptions in Section 11 updated to reference this mechanism.
