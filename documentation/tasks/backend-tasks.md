# Task List — Backend Service

## Status

Draft — 2026-04-29

## Source plan

`documentation/tasks/senior-developer-backend-plan.md`

## Flagged issues

None. All plan sections decompose cleanly into verifiable tasks.

## Critical path

B-001 → B-023 → B-002 → B-003 → B-004 → B-024 → B-005 → B-006 → B-007 → B-009 → B-010 → B-011 → B-012 → B-013 → B-018 → B-021 → B-022

---

## Tasks

### Task B-001: Project scaffolding and configuration

**Description**: Create the `apps/backend/` directory structure exactly as specified in the plan (Section 1). Produce:
- `pyproject.toml` with all runtime and dev dependencies (FastAPI, SQLAlchemy 2.x async, asyncpg, LangChain, LangGraph, APScheduler, Alembic, sse-starlette, Dynaconf, Pydantic v2, uuid-utils, tenacity, structlog, pytest, pytest-asyncio)
- `alembic.ini`
- `backend/config.json` with all keys from Section 11.1 (required fields set to the string `"REQUIRED"`, all optional fields with their documented defaults)
- `backend/config.override.json.example` showing the local override shape from Section 11.2 (the actual `config.override.json` is gitignored and not created here)
- `app/config.py` — `BackendConfig` Pydantic `BaseSettings` model with all fields from Section 11.3
- `app/constants.py` — `DEFAULT_USER_ID`, `new_uuid()` using `uuid-utils`, and all `SUBTYPE_*` constants from Section 11.4
- All `__init__.py` files for every package in the directory tree
- `pytest` markers declared in `pyproject.toml` per Section 14.1
- A `.gitignore` entry for `config.override.json`

No application logic is written in this task. All files may be stubs (empty or with only the top-level class/function signature) except for `BackendConfig`, `constants.py`, `config.json`, and `pyproject.toml`.

**Depends on**: none

**Complexity**: S

**Acceptance condition**: `cd apps/backend && python -m pytest --collect-only` exits 0 with no collection errors (no tests exist yet, but the package structure is importable). `python -c "from app.config import BackendConfig"` succeeds. `python -c "from app.constants import new_uuid; print(new_uuid())"` prints a UUID v7 string.

**Condition type**: manual

**Status**: not_started

---

### Task B-023: Docker setup — Postgres, backend service, and Compose file

**Description**: Create the Docker infrastructure that all subsequent integration tests and local development depend on.

Produce:
- `apps/backend/Dockerfile` — two-stage build:
  - Stage 1 (deps): `python:3.12-slim` base; copies `pyproject.toml`; installs all runtime dependencies via `pip install` into `/install`
  - Stage 2 (runtime): `python:3.12-slim` base; copies installed packages from Stage 1 and `app/` source; sets `CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]`
- `docker-compose.yml` at the repository root with three services:
  - `postgres`: `postgres:16-alpine`; exposes port `5432`; `POSTGRES_DB=ai_council`, `POSTGRES_USER=ai_council`, `POSTGRES_PASSWORD=ai_council`; named volume `pgdata` for persistence; health check using `pg_isready`
  - `backend`: built from `apps/backend/Dockerfile`; `depends_on: postgres` (condition: `service_healthy`); environment variables wired from `config.override.json` via volume mount at `/app/config.override.json`; exposes port `8000`
  - `frontend`: placeholder stub (`image: nginx:alpine`) to satisfy F-028's `depends_on: backend` — will be replaced when F-028 is implemented
- `.env.example` at the repository root documenting the environment variable shape expected by the backend container
- A `TEST_DATABASE_URL` environment variable convention documented in `apps/backend/README.md` (one paragraph) for running integration tests against the Compose Postgres instance

**Depends on**: B-001

**Complexity**: S

**Acceptance condition**: `docker compose up postgres -d` starts the Postgres container and `pg_isready -h localhost -p 5432` returns successfully. `docker compose up backend -d` builds and starts the backend container; `curl http://localhost:8000/docs` returns 200. `docker compose down -v` tears everything down cleanly.

**Condition type**: manual

**Status**: not_started

---

### Task B-002: Alembic initial migration and database engine setup

**Description**: Implement the initial Alembic migration and the database engine module.

Produce:
- `alembic/env.py` — async Alembic env that uses the engine from `app/db/engine.py`
- `alembic/versions/0001_initial_schema.py` — the full initial schema migration from Section 2.2, creating all tables in dependency order with all specified indexes, Postgres enum types, and the seed `INSERT` for `DEFAULT_USER_ID`
- `app/db/engine.py` — SQLAlchemy async engine factory and `AsyncSessionLocal` session factory, accepting a `database_url` string (not reading config directly)
- `app/db/session.py` — `get_db()` async generator dependency

The migration must include:
- All Postgres `CREATE TYPE` statements for enums (before the tables that use them)
- All `CREATE INDEX` statements
- The `mentor_episodic_memories.source_type` `CHECK` constraint
- The `UNIQUE (mentor_persona_id, source_conversation_id)` constraint on `mentor_episodic_memories`
- The seed `INSERT` into `users`

The migration must **not** create LangGraph checkpointer tables (those are created via `PostgresSaver.setup()` at runtime).

**Depends on**: B-023

**Complexity**: M

**Acceptance condition**: `alembic upgrade head` runs against a clean Postgres database without error, and `alembic downgrade base` then `alembic upgrade head` also succeeds. Confirmed by running both commands against the test database from a terminal.

**Condition type**: manual

**Status**: not_started

---

### Task B-003: SQLAlchemy ORM models

**Description**: Implement all SQLAlchemy 2.x ORM model classes and the ORM scoping infrastructure.

Produce:
- `app/db/mixins.py` — `UserScopedMixin` and `WorkspaceScopedMixin` per Section 3.1
- `app/db/scoping.py` — `current_workspace_id` and `current_user_id` `ContextVar` declarations; the `do_orm_execute` event listener that appends `WHERE workspace_id = :workspace_id` for all `WorkspaceScopedMixin` subclasses; the `RuntimeError` guard if the `ContextVar` is `None` at query time; inline comments on any raw SQL bypass
- `app/db/models/user.py` — `User`
- `app/db/models/workspace.py` — `Workspace` (inherits `UserScopedMixin` only; `context_panel_max_chars` is not a DB column)
- `app/db/models/persona.py` — `Persona`, `PersonaSystemPromptVersion`
- `app/db/models/conversation.py` — `Conversation`, `ConversationPersona`, `Folder`
- `app/db/models/message.py` — `Message` (`message_subtype` is plain `Text`, not an enum)
- `app/db/models/conversation_summary.py` — `ConversationSummary`
- `app/db/models/mentor_memory.py` — `MentorEpisodicMemory`, `MentorSemanticMemory`
- `app/db/models/review_agent.py` — `ReviewAgentRun`, `ReviewAgentFinding`
- `app/db/models/orchestrator.py` — `OrchestratorSuggestion`
- `app/db/models/document.py` — `Document`
- `app/db/models/__init__.py` — exports all model classes

Every model uses `default=new_uuid` for its primary key. All FK relationships are reflected per Section 2.2 (ON DELETE CASCADE, ON DELETE SET NULL as specified).

**Depends on**: B-002

**Complexity**: M

**Acceptance condition**: `python -c "from app.db.models import Workspace, Persona, Conversation, Message, MentorEpisodicMemory, ReviewAgentRun, Document"` succeeds without error. Running `alembic upgrade head` against a clean DB followed by `python -c "from app.db.scoping import current_workspace_id"` succeeds. An integration test (can be a throwaway script run manually) inserts a `Workspace` row scoped to `DEFAULT_USER_ID` using a session with the `ContextVar` set and verifies the row is retrievable only when the correct `workspace_id` is in the `ContextVar`.

**Condition type**: manual

**Status**: not_started

---

### Task B-004: Testing infrastructure — fakes and conftest

**Description**: Implement the test infrastructure that all subsequent unit and integration tests depend on.

Produce:
- `tests/conftest.py` — shared fixtures per Section 14.3:
  - `test_engine` (session-scoped): creates an async engine against `TEST_DATABASE_URL` and applies all Alembic migrations at session start; drops all tables at session end
  - `db`: yields an `AsyncSession`; rolls back after each test
  - `set_workspace_context(workspace_id)`: sets `current_workspace_id` and `current_user_id` ContextVars and resets them after the test
  - `default_workspace`: creates and returns a test `Workspace` row
  - `mentor_persona`: creates and returns a Mentor Persona + Mentor Conversation
- `tests/fakes/__init__.py`
- `tests/fakes/fake_model_gateway.py` — `FakeModelGateway` that accepts pre-configured responses per call type (`invoke`, `stream`, `invoke_structured`, `embed`) and raises on unexpected calls
- `tests/fakes/fake_conversation_repo.py` — `FakeConversationRepository` with in-memory store
- `tests/fakes/fake_sse_manager.py` — `FakeSseManager` that records all published events for assertion

All test files must start empty (no tests yet — tests are written in later tasks). The fakes must match the interfaces of their real counterparts so they can be substituted directly.

**Depends on**: B-003

**Complexity**: S

**Acceptance condition**: `pytest --collect-only -m unit` exits 0 (no tests found, but no import errors). `pytest --collect-only -m integration` exits 0. `from tests.fakes.fake_model_gateway import FakeModelGateway` imports without error. The `conftest.py` fixtures are importable from a test file without error.

**Condition type**: manual

**Status**: not_started

---

### Task B-024: GitHub Actions — backend CI workflow

**Description**: Create the GitHub Actions workflow that runs the backend test suite, starts the application, and publishes the OpenAPI spec as a workflow artifact for the frontend to consume.

Produce:
- `.github/workflows/backend-ci.yml` — workflow triggered on `push` and `pull_request` for paths matching `apps/backend/**` and `.github/workflows/backend-ci.yml`. Two jobs:

  - **test** (runs on `ubuntu-latest`):
    - PostgreSQL 16 service container (`postgres:16-alpine`) with `POSTGRES_DB=ai_council_test`, `POSTGRES_USER=ai_council`, `POSTGRES_PASSWORD=ai_council`; health check via `pg_isready`; port 5432 mapped to host
    - `actions/checkout@v4`
    - `actions/setup-python@v5` with `python-version: '3.12'`; pip cache keyed on `apps/backend/pyproject.toml`
    - Install: `pip install -e ".[dev]"` from `apps/backend/`
    - Migrate: `alembic upgrade head` with `DATABASE_URL=postgresql+asyncpg://ai_council:ai_council@localhost:5432/ai_council_test`
    - Unit tests: `pytest -m unit` (no database env required)
    - Integration tests: `pytest -m integration` with `DATABASE_URL` set
    - The workflow must not run e2e tests (`@pytest.mark.e2e`) — excluded by the `-m` flag

  - **publish-openapi** (runs on `ubuntu-latest`, `needs: test`):
    - Same Postgres service container and Python setup as the `test` job
    - Same install and migration steps
    - Start uvicorn in the background: `uvicorn app.main:app --host 0.0.0.0 --port 8000 &`; wait for readiness using `curl --retry 10 --retry-connrefused --retry-delay 1 http://localhost:8000/docs`
    - Fetch the spec: `curl http://localhost:8000/openapi.json -o openapi.json`
    - Upload `openapi.json` as a workflow artifact named `openapi-spec` (retention: 90 days) using `actions/upload-artifact@v4`
    - Environment variables for uvicorn: `DATABASE_URL` (pointing to the CI Postgres), `MODEL_PROVIDER=openai`, `MODEL_API_KEY=ci-placeholder`, `MODEL=gpt-4o` — the model gateway is configured but never called; the app only needs to start and serve routes
    - `config.override.json` is not used in CI; all required config is passed as environment variables

Add a `backend-ci` status badge to `README.md`.

**Depends on**: B-004

**Complexity**: S

**Acceptance condition**: A push triggers the workflow. The `test` job passes. The `publish-openapi` job starts the app, fetches `/openapi.json`, and the artifact appears in the workflow run's artifact list on the Actions tab. `GET /openapi.json` in the CI log returns a JSON body containing an `"openapi"` key. Confirmed by viewing the Actions tab on the repository.

**Condition type**: manual

**Status**: not_started

---

### Task B-005: app/results.py and app/errors.py

**Description**: Implement the result type module and global error handling.

Produce:
- `app/results.py` — `Ok[T]`, `Err`, and `ServiceResult = Ok[T] | Err` as specified in Section 4.6. The `Err` dataclass must include `code: str`, `message: str`, `status: int`, and `detail: dict | None = None`.
- `app/errors.py` — global FastAPI exception handler that catches all unhandled exceptions and returns `{"message": "Internal server error"}` for 500s without leaking stack traces; preserves FastAPI's default 422 Pydantic validation error shape. Custom exception classes needed by the application (if any) live here.
- `app/db/helpers.py` — `update_system_prompt(persona, new_prompt, db)` helper function per Section 13.2; `mark_stale_findings_for_persona(persona_id, new_prompt, db)` helper per Section 9.5.

These are foundational modules used by all service and router code.

**Depends on**: B-003

**Complexity**: S

**Acceptance condition**: `python -c "from app.results import Ok, Err, ServiceResult; r = Ok(42); print(r.value)"` prints `42`. `python -c "from app.errors import install_exception_handlers"` (or equivalent top-level function) imports without error. `python -c "from app.db.helpers import update_system_prompt, mark_stale_findings_for_persona"` imports without error.

**Condition type**: manual

**Status**: not_started

---

### Task B-006: ModelGateway

**Description**: Implement `ModelGateway` in `app/gateway/model_gateway.py` per Section 5.

The implementation must:
- Accept constructed config values (model, model_provider, model_base_url, api_key, timeout) as constructor arguments — not a `BackendConfig` object
- Call `init_chat_model` with `configurable_fields=("model", "model_provider")`
- Implement all four methods: `invoke`, `stream`, `invoke_structured`, `embed`
- Apply the tenacity retry policy from Section 5.4 (3 attempts, exponential backoff 1s/2s/4s, retry on network errors/RateLimitError/ServiceUnavailableError, no retry on InvalidRequestError/auth errors, timeout from config)
- Log every call at `DEBUG` level with `purpose`, token count (approximated from content length), and latency via the injected `structlog.BoundLogger`
- The `embed` method V1 fallback: character-hash distance if the model does not support embeddings

The `ModelGateway` must not import from any router or service module. Only `app/gateway/model_gateway.py` and `app/orchestrator/` may import from `langchain.*`.

**Depends on**: B-005

**Complexity**: M

**Acceptance condition**: Unit tests in `tests/unit/test_model_gateway.py` pass (marked `@pytest.mark.unit`). Tests must verify: `purpose` is logged; retry fires on transient error; `invoke_structured` returns a validated Pydantic instance; final failure re-raises. All tests use `FakeModelGateway`'s inverse — i.e. a fake `BaseChatModel` for testing `ModelGateway` itself. `pytest -m unit tests/unit/test_model_gateway.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-007: FastAPI app factory, middleware, and composition root skeleton

**Description**: Implement `app/main.py` as the composition root per Section 4, and all middleware.

Produce:
- `app/main.py` — FastAPI app factory with the full lifespan context manager (startup sequence steps 1–9 and shutdown sequence from Section 4.1). At this stage, steps that depend on not-yet-implemented services (e.g. `ConversationOrchestrator`, `ReviewAgentRunner`) should call stub constructors that will be replaced in later tasks. The lifespan must start and stop cleanly.
- `app/middleware/current_user.py` — `CurrentUserMiddleware` that calls `resolve_current_user()` (stub returning `DEFAULT_USER_ID`) and sets `current_user_id` ContextVar
- `app/middleware/workspace.py` — `WorkspaceContextMiddleware` that extracts `workspace_id` from the path and sets `current_workspace_id` ContextVar for workspace-scoped routes; passes through for non-workspace-scoped routes
- `app/dependencies.py` — `get_db()`, `get_model_gateway()`, `get_orchestrator()` as `Depends()` factories; the gateway and orchestrator return their respective singletons from module-level state set by the lifespan

Middleware must be registered in the correct reverse order per Section 4.2 so execution order is CORS → CurrentUser → WorkspaceContext.

The crash recovery step (step 8 in the lifespan) may be a stub `pass` at this stage.

**Depends on**: B-006

**Complexity**: M

**Acceptance condition**: `uvicorn app.main:app --reload` starts without error and responds to `GET /docs` (FastAPI auto-docs). CORS headers are present on a preflight `OPTIONS` request to any endpoint. The middleware stack does not raise on a basic `GET /workspaces` request (even though no routers are registered yet — it should return 404 cleanly).

**Condition type**: manual

**Status**: not_started

---

### Task B-008: Pydantic response schemas

**Description**: Implement all Pydantic request/response schemas in `app/schemas/`. These are needed by all router tasks.

Produce all files in `app/schemas/` per Section 1:
- `workspace.py` — `WorkspaceResponse`, `WorkspaceCreate`, `WorkspacePatch`
- `persona.py` — `PersonaResponse`, `PersonaCreate`, `PersonaPatch`
- `conversation.py` — `ConversationResponse`, `ConversationCreate`, `ConversationPatch`, `EndConversationResponse`, `ParticipantResponse`, `AddParticipantRequest`, `ConversationSummary` (the structured output schema used for auto-summary; this is the canonical definition — `ContextAssembler`, `MentorPromoter`, and the `end_conversation` handler all import from here)
- `message.py` — `MessageResponse`, `MessageCreate`, `MessageListResponse` (with `has_more` and `next_cursor`)
- `folder.py` — `FolderResponse`, `FolderCreate`, `FolderPatch`, `DeleteFolderResponse` (includes `unassigned_conversation_ids`)
- `document.py` — `DocumentResponse`, `DocumentGenerate`, `DocumentPatch`
- `review_agent.py` — `FindingResponse`, `ConsultationRequest`, `RunStatusResponse`, `RunResponse`
- `mentor_memory.py` — `EpisodicMemoryResponse` (must include `source_type: Literal["self", "observed"]` and `source_conversation_id: UUID | None`), `SemanticMemoryResponse`
- `sse.py` — SSE-specific event payload schemas (token event payload, busy/idle event payload, error event payload); does **not** define `ConversationSummary` — import that from `app/schemas/conversation.py`

All schemas must match the exact field names, types, and nullability specified in `documentation/tasks/api-contract.md`. The `ConversationResponse` must include `chapter_prompt_required: bool` and `auto_summary` as an optional nested object (not a flat field). The `WorkspaceResponse` must include `context_panel_max_chars: int`.

**Depends on**: B-005

**Complexity**: M

**Acceptance condition**: `python -c "from app.schemas.workspace import WorkspaceResponse; from app.schemas.mentor_memory import EpisodicMemoryResponse; from app.schemas.conversation import ConversationResponse"` imports without error. Instantiating `EpisodicMemoryResponse` with `source_type='observed'` and a non-null `source_conversation_id` succeeds. Instantiating it with `source_type='self'` and `source_conversation_id=None` succeeds. Passing `source_type='invalid'` raises a Pydantic `ValidationError`.

**Condition type**: manual

**Status**: not_started

---

### Task B-009: SSE manager and events

**Description**: Implement the SSE infrastructure per Section 10.

Produce:
- `app/sse/events.py` — `SseEvent` dataclass with `event_type: str` and `data: dict`; `to_sse_frame(event_id: int) -> str` method that formats `id: {id}\nevent: {type}\ndata: {json}\n\n`
- `app/sse/manager.py` — `SseManager` class per Section 10.2: `connect`, `disconnect`, `has_listener`, `publish`. In-memory `dict[str, asyncio.Queue]`. Also holds the per-conversation event ring buffer (last `SSE_EVENT_BUFFER_SIZE` events) for `Last-Event-ID` reconnection replay per Section 10.3. The manager accepts `SSE_EVENT_BUFFER_SIZE` as a constructor argument.

The `FakeSseManager` in `tests/fakes/fake_sse_manager.py` (created in B-004) must implement the same interface as `SseManager`.

**Depends on**: B-007

**Complexity**: S

**Acceptance condition**: `python -c "from app.sse.manager import SseManager; from app.sse.events import SseEvent"` imports without error. A manual test: construct an `SseManager`, call `connect("conv-1")`, call `publish("conv-1", SseEvent("token", {"content": "hello"}))`, then `await queue.get()` returns the event. `has_listener("conv-1")` returns `True` before disconnect and `False` after.

**Condition type**: manual

**Status**: not_started

---

### Task B-010: ConversationOrchestrator — LangGraph graph

**Description**: Implement the `ConversationOrchestrator` and its LangGraph graph per Sections 6 and 10.

Produce:
- `app/orchestrator/state.py` — `ConversationState` TypedDict per Section 6.2
- `app/orchestrator/speaker_selection.py` — `select_next_speaker()` function per Section 6.9; `normalise_response()`, `shingle()`, and `jaccard()` per Section 6.9
- `app/orchestrator/nodes.py` — all LangGraph node functions: `receive_message`, `persona_response`, `orchestrator_check`, `orchestrator_direct`, `await_user`, `emit_busy`, `emit_idle`; `listener_check` conditional edge function; `p2p_turn_check` conditional edge function per Section 6.9 (hard cap check, repetition detection using Jaccard shingles, minimum delay via `asyncio.sleep`)
- `app/orchestrator/sse_bridge.py` — `stream_turn()` async generator that calls `graph.astream()` in `stream_mode="messages"` and translates graph events to `SseEvent` instances per the mapping in Section 6.5
- `app/orchestrator/graph.py` — `ConversationOrchestrator` class: constructs the `StateGraph[ConversationState]` with all nodes and edges per Section 6.3; compiles with `PostgresSaver` checkpointer; exposes `stream_turn()`, `get_state()`, `update_state()` methods

Key implementation requirements:
- P2P counter reset logic per Section 6.10
- `@Orchestrator` detection in `route_message` per Section 6.8: case-insensitive `content.lstrip().lower().startswith("@orchestrator")`
- Workspace-switch interrupt: `listener_check` conditional edge sets `pause_requested=True` and routes to `await_user` if `has_listener()` is `False`
- The Mentor `conversation_persona_id` format in token events: `"mentor:{persona_id}"` per Section 8.6
- Workspace-switch resume handshake: stream generator preamble checks `pause_requested` and emits `paused` event before entering the queue loop (wired in B-014)

Only `app/orchestrator/` and `app/gateway/model_gateway.py` may import from `langchain.*` or `langgraph.*`.

**Depends on**: B-009

**Complexity**: L

**Acceptance condition**: Unit tests in `tests/unit/test_speaker_selection.py` pass (marked `@pytest.mark.unit`), verifying: name-addressability detection (present, absent, case-insensitive), round-robin fallback, correct wrap-around. `pytest -m unit tests/unit/test_speaker_selection.py` exits 0. Integration test: the graph processes a single user message in `one_to_one` mode against a real Postgres checkpointer (test DB), emits `busy` then `idle` events, and persists graph state between invocations. This integration test can be written in B-021.

**Condition type**: both

**Status**: not_started

---

### Task B-011: Context window management

**Description**: Implement the context window management system per Section 7.

Produce:
- `app/context/strategy.py` — `CompressionStrategy` abstract base class per Section 7.1
- `app/context/rolling_summary.py` — `RollingSummary` concrete implementation: takes oldest messages beyond the `last_N` window, calls `ModelGateway.invoke(purpose="context_compression")`, upserts into `conversation_summaries`, returns updated summary text
- `app/context/assembler.py` — `ContextAssembler.build()` per Section 7.3: assembly order (SystemMessage from snapshot, context_panel, Episodic/Semantic for Mentor, rolling summary, verbatim messages), token budget calculation using `CHARS_PER_TOKEN=4`, compression trigger at 75% threshold, auto-naming trigger on first compression for untitled Conversation (calls `ModelGateway.invoke(purpose="auto_naming")`)

For Mentor Conversations, `ContextAssembler.build()` must read `personas.system_prompt` directly (not from `conversation_personas`).

**Depends on**: B-010

**Complexity**: M

**Acceptance condition**: Unit tests in `tests/unit/test_rolling_summary.py` and `tests/unit/test_context_assembler.py` pass (marked `@pytest.mark.unit`). `test_rolling_summary.py` verifies: summary upserted correctly; compression trigger threshold respected; called with `purpose="context_compression"`. `test_context_assembler.py` verifies: assembly order (all six positions); token budget respected; Mentor path reads live system prompt; non-Mentor path reads snapshot; `chapter_prompt_required` UTC comparison (parametrised: same day / different day). `pytest -m unit tests/unit/test_rolling_summary.py tests/unit/test_context_assembler.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-012: Mentor memory system

**Description**: Implement the Mentor memory system per Section 8.

Produce:
- `app/mentor/retriever.py` — `MentorMemoryRetriever` ABC per Section 8.1; `AllEntriesRetriever` V1 implementation that loads all rows for the given `mentor_persona_id` (one query per table, no filtering on `pending_promotion`)
- `app/mentor/promoter.py` — `MentorPromoter` class with two methods:
  - `promote_working_to_episodic(conversation_id, db)` per Section 8.2: reads existing rolling summary, inserts `mentor_episodic_memories` row with `source_type='self'`, `pending_promotion=True`, clears `conversation_summaries` row — all in one transaction
  - `promote_episodic_to_semantic(row, db)` per Section 8.3: loads existing semantic titles, calls `ModelGateway.invoke_structured(purpose="mentor_episodic_to_semantic")`, creates/updates semantic rows, sets `promoted_at`, handles 3-retry failure with `promotion_skipped` log

`MentorPromoter` receives `ModelGateway` and `structlog.BoundLogger` as constructor arguments. The APScheduler job wrapper for the episodic-to-semantic promotion is wired in B-016.

**Depends on**: B-011

**Complexity**: M

**Acceptance condition**: Unit tests in `tests/unit/test_mentor_promoter.py` pass (marked `@pytest.mark.unit`). Tests verify: empty output list retires Episodic row without semantic writes; `mode="new"` inserts `MentorSemanticMemory`; `mode="update"` updates existing row; failure after 3 retries logs `promotion_skipped` and retires row; `promoted_at` not set mid-crash (idempotency check). `pytest -m unit tests/unit/test_mentor_promoter.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-013: Conversation Observer

**Description**: Implement the Conversation Observer per Section 8.4 and Section 9.0.

Produce:
- `app/conversation_observer/schemas.py` — `ConversationObservation` Pydantic schema per Section 8.4
- `app/conversation_observer/observer.py` — `ConversationObserver` class with two methods:
  - `observe(conversation_id, db)`: guard (check Mentor exists), load messages (`role IN ('user','persona','mentor')`), call `ModelGateway.invoke_structured(purpose="conversation_observer")`, serialise output to Markdown `summary_text`, insert `mentor_episodic_memories` row with `source_type='observed'`, `source_conversation_id=conversation_id`, `pending_promotion=True`; log-and-discard on any error
  - `backfill(workspace_id, mentor_persona_id, db)`: query all `status='ended'` non-Mentor Conversations ordered by `ended_at ASC`; call `observe()` for each
- `app/jobs/conversation_observer_task.py` — `run_conversation_observer(conversation_id, db, model_gateway, log)` and `run_conversation_observer_backfill(workspace_id, mentor_persona_id, db, model_gateway, log)` async task wrappers that set ContextVars and delegate to `ConversationObserver`

The `UNIQUE (mentor_persona_id, source_conversation_id)` constraint on `mentor_episodic_memories` provides idempotency — a second call for the same `source_conversation_id` must be handled gracefully (catch the unique constraint violation and log, do not re-raise).

**Depends on**: B-012

**Complexity**: M

**Acceptance condition**: Unit tests in `tests/unit/test_conversation_observer.py` pass (marked `@pytest.mark.unit`). Tests verify: guard returns immediately without DB write when no Mentor exists; happy path inserts one `mentor_episodic_memories` row with `source_type='observed'`, correct `source_conversation_id`, `pending_promotion=True`; idempotency: second call for same `source_conversation_id` raises no error; backfill processes all concluded non-Mentor Conversations in sequence. `pytest -m unit tests/unit/test_conversation_observer.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-014: SSE stream endpoint

**Description**: Implement the SSE stream endpoint in `app/routers/stream.py` per Section 10.1.

The handler must:
1. Bootstrap workspace context from the Conversation row PK (unscoped query with inline comment) and validate `X-Workspace-ID` header against the loaded `workspace_id` — return 403 on mismatch
2. Register the connection with `SseManager`; update `has_sse_listener=True` in LangGraph state via `orchestrator.update_state()`
3. Workspace-switch resume preamble: read current graph state via `orchestrator.get_state()`; if `pause_requested=True`, emit a `paused` SSE event as the first event before entering the queue loop
4. Main event queue loop: yield events from the per-conversation queue formatted as SSE frames with server-assigned monotonically increasing integer event IDs
5. Handle `Last-Event-ID` reconnection: if the header is present on reconnect, replay buffered events from that ID forward (up to `SSE_EVENT_BUFFER_SIZE` events)
6. On client disconnect: deregister from `SseManager`; update `has_sse_listener=False` in graph state

Register this router on the FastAPI app in `app/main.py` without a workspace prefix.

**Depends on**: B-010, B-009

**Complexity**: M

**Acceptance condition**: A manual test using `curl -N -H "X-Workspace-ID: {ws_id}" http://localhost:8000/conversations/{conv_id}/stream` (with a valid conversation and workspace) holds the connection open and receives SSE-formatted keep-alive or initial events. A mismatched `X-Workspace-ID` returns `403`. A non-existent `conversation_id` returns `404`. On reconnect with a valid `Last-Event-ID`, previously buffered events are replayed.

**Condition type**: manual

**Status**: not_started

---

### Task B-015: Review Agent runner

**Description**: Implement the Review Agent per Sections 9.1–9.6.

Produce:
- `app/review_agent/schemas.py` — `PersonaFinding` Pydantic schema per Section 9.4
- `app/review_agent/runner.py` — `ReviewAgentRunner` class with `run_for_workspace(workspace_id, db)` method implementing the full sweep logic per Section 9.3:
  - Row-lock check to prevent duplicate runs
  - Per-Persona: load concluded Conversations and existing findings; reconciliation step with all three outcomes (resolved → `dismissed`, passage moved → update in place, stale → `stale`); prepare suppression context; call `ModelGateway.invoke_structured(purpose="review_agent_finding")`; deduplicate and insert new findings
  - Update `ReviewAgentRun` to `complete` or `failed`
  - ContextVar setup per Section 13.1 (`current_workspace_id`, `current_user_id` set before any scoped queries)

`ReviewAgentRunner` receives `ModelGateway` and `structlog.BoundLogger` as constructor arguments.

**Depends on**: B-005, B-006

**Complexity**: L

**Acceptance condition**: Unit tests in `tests/unit/test_review_agent_runner.py` pass (marked `@pytest.mark.unit`). Tests verify: row-lock check; all three reconciliation outcomes; no duplicate `active` findings inserted; `Ok` returned on success; `Err` on expected failures. `pytest -m unit tests/unit/test_review_agent_runner.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-016: APScheduler jobs wiring

**Description**: Wire all background jobs into APScheduler per Sections 9.1, 13.1, and the lifespan sequence in Section 4.1.

Produce:
- `app/jobs/scheduler.py` — `AsyncIOScheduler` factory function that accepts job registrations
- `app/jobs/review_agent_job.py` — `run_review_agent_job()` async function per Section 13.1: unscoped workspace ID query (with inline comment), sets ContextVars per workspace, delegates to `ReviewAgentRunner.run_for_workspace()`; wrapped as a `CronTrigger` job registered with `max_instances=1`, `coalesce=True`, `misfire_grace_time=300`
- `app/jobs/mentor_promotion_job.py` — `run_episodic_to_semantic_job()` per Section 13.1 and Section 8.3: unscoped `pending_promotion` query, sets ContextVars per row, delegates to `MentorPromoter.promote_episodic_to_semantic()`; wrapped as a scheduled job

Update `app/main.py` lifespan to:
- Replace stubs with real `ReviewAgentRunner` and `MentorPromoter` instances constructed with `ModelGateway` and named loggers
- Register both APScheduler jobs per Section 4.1 steps 7–9
- Implement crash recovery for stale `running` Review Agent runs (step 8)

**Depends on**: B-015, B-013, B-007

**Complexity**: M

**Acceptance condition**: `uvicorn app.main:app` starts cleanly, the APScheduler logs show both jobs registered, and the application logs the crash-recovery query result at startup. Manual verification: trigger the Review Agent job directly by calling its function in a Python REPL (not via the HTTP endpoint) against the test database; confirm it creates a `ReviewAgentRun` row and completes without error.

**Condition type**: manual

**Status**: not_started

---

### Task B-017: Workspaces and Personas routers

**Description**: Implement the Workspaces and Personas REST routers per Sections 11.1, 11.2, and 11.3.

Produce:
- `app/routers/workspaces.py` — all five workspace handlers: `list_workspaces`, `get_workspace`, `create_workspace`, `rename_workspace`, `delete_workspace`. The `delete_workspace` handler must cascade-delete in the exact order from Section 11.1 including calling `checkpointer.adelete_thread()` for each Conversation's LangGraph state, and setting any `running` review agent run to `failed` before deletion.
- `app/routers/personas.py` — all handlers for Personas CRUD (Sections 11.2) plus the persona test handler (Section 11.3):
  - `create_persona`: insert Persona + `PersonaSystemPromptVersion` in one transaction; if `is_mentor=True`: 409 if Mentor exists, create Mentor Conversation in same transaction, spawn `asyncio.create_task` for Conversation Observer backfill
  - `update_persona`: use `update_system_prompt()` helper for `system_prompt` changes; call `mark_stale_findings_for_persona()` in same transaction; 409 `MENTOR_NAME_IMMUTABLE` if attempting to rename Mentor
  - `delete_persona`: 409 `MENTOR_CANNOT_BE_DELETED` if Mentor; application-layer check for active participants (query with inline comment); cascade delete
  - `test_persona`: validate `X-Workspace-ID` and bootstrap workspace context from persona PK; maintain in-memory test sessions keyed by `session_id` with TTL `TEST_SESSION_TTL_SECONDS`; call `ModelGateway.stream(purpose="persona_test")`; return SSE stream

All workspace response objects must include `context_panel_max_chars` read from the singleton config (not from the database).

Register both routers on the FastAPI app in `app/main.py`.

**Depends on**: B-008, B-007, B-013

**Complexity**: L

**Acceptance condition**: Integration tests in `tests/integration/test_workspaces.py` and `tests/integration/test_personas.py` pass (marked `@pytest.mark.integration`). `test_workspaces.py` verifies full CRUD and that `context_panel_max_chars` is present in all responses. `test_personas.py` verifies: `system_prompt` write always inserts a `persona_system_prompt_versions` row; `is_mentor=True` creates Mentor Conversation; delete 409 when active in open Conversation; `mark_stale_findings_for_persona` called on system_prompt update. `pytest -m integration tests/integration/test_workspaces.py tests/integration/test_personas.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-018: Conversations router

**Description**: Implement the Conversations REST router per Sections 11.4, 11.5, and 11.6.

Produce `app/routers/conversations.py` with all handlers:

**Conversation CRUD (Section 11.4):**
- `list_conversations`: include `is_mentor_conversation` on all items
- `get_conversation`: load Conversation + all `conversation_personas` rows; compute `chapter_prompt_required` via the UTC date comparison from Section 8.5; `auto_summary` is `null` while generation is pending
- `create_conversation`: validate mode/participant count; reject Mentor Persona in `persona_ids`; title `"New Conversation {ISO_TIMESTAMP}"`; insert Conversation + participant snapshots in one transaction
- `update_conversation`: 403 if ended; mode change requires idle check and participant count validation; insert `mode_changed` system message on mode change; enforce `CONTEXT_PANEL_MAX_CHARS`; return `Err` with `context_panel_too_long` code on violation
- `end_conversation`: if P2P in progress, cancel internally first; query for qualifying messages; if none: cascade delete + return `{deleted: true}`; else: set `status='ended'`, `ended_at=now()`; spawn two `asyncio.create_task`s: auto-summary generation and Conversation Observer; return `{deleted: false, conversation: ...}` with `auto_summary: null`
- `delete_conversation`: cascade delete; do not delete Documents with `source_conversation_id` pointing here

**Participant management (Section 11.5):**
- `add_persona_to_conversation`: idle check, snapshot, insert `conversation_personas`, insert `persona_joined` system message
- `remove_persona_from_conversation`: idle check, last-persona check; set `left_at`; insert `persona_left` system message; if mode downgrade needed, insert `mode_changed` system message and return `updated_mode`
- `refresh_persona_snapshot`: idle check; insert new `conversation_personas` row; old row preserved

**Mentor chapter (Section 11.6):**
- `start_chapter`: 403 if not `is_mentor_conversation`; idle check; insert `chapter_boundary` system message; trigger `MentorPromoter.promote_working_to_episodic()` in same transaction

**Orchestrator suggestion responses (Section 11.13) — on this router:**
- `accept_suggestion`: validate `X-Workspace-ID` and bootstrap workspace context; idle check; snapshot; insert `conversation_personas`; insert `orchestrator_suggestion_accepted` system message; if was `one_to_one`, switch to `round_robin` + insert `mode_changed`; return `updated_mode`
- `dismiss_suggestion`: validate `X-Workspace-ID`; set `dismissed`

**Conversation export (Section 11.14):**
- `export_conversation`: idle check; load all messages in `created_at ASC` order; format as Markdown with speaker labels; return `text/markdown` response with `Content-Disposition` header

Register this router in `app/main.py`.

**Depends on**: B-008, B-007, B-012, B-013

**Complexity**: L

**Acceptance condition**: Integration tests in `tests/integration/test_conversations.py` pass (marked `@pytest.mark.integration`). Tests verify: `POST /end` with qualifying messages returns `{deleted: false}` and sets `status='ended'`; `POST /end` with no qualifying messages returns `{deleted: true}` and the Conversation row is gone; `context_panel` enforcement returns 422 with `CONTEXT_PANEL_TOO_LONG`; participant add/remove/refresh round-trips correctly; `chapter_prompt_required` flag (requires UTC mocking for date comparison). `pytest -m integration tests/integration/test_conversations.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-019: Messages, Folders, and Documents routers

**Description**: Implement the Messages, Folders, and Documents REST routers per Sections 11.7, 11.8, and 11.9.

Produce:
- `app/routers/messages.py` — `list_messages` (cursor-based pagination: `before` UUID cursor, `ORDER BY created_at ASC`, `has_more` and `next_cursor` derived from row existence beyond the page limit) and `send_message` (403 if ended; 409 `CONVERSATION_BUSY` if graph state is not `await_user`; persist user message; update `last_message_at`; call `orchestrator.invoke_turn(conversation_id)` as background task; return persisted message immediately)
- `app/routers/folders.py` — all four folder handlers: `list_folders` (compute `conversation_count` via count subquery), `create_folder`, `rename_folder`, `delete_folder` (set `folder_id=NULL` on all Conversations; return `unassigned_conversation_ids`)
- `app/routers/documents.py` — all five document handlers: `list_documents` (optional `source_conversation_id` filter; exclude `content_markdown`), `get_document`, `generate_document` (203 if source Conversation not ended; 409 if pending Document exists; insert with `status='pending'`; fire-and-forget background task calling `ModelGateway.invoke(purpose="report_generation")`; return 202), `rename_document`, `delete_document`

Register all three routers in `app/main.py`.

**Depends on**: B-008, B-007, B-010

**Complexity**: M

**Acceptance condition**: Integration tests in `tests/integration/test_messages.py` pass (marked `@pytest.mark.integration`). Tests verify cursor-based pagination: `has_more=true` when more rows exist; `next_cursor` is the oldest message ID in the page; `last_message_at` on the Conversation is updated on message insert. Folder and Document CRUD are verified by sending requests via `httpx.AsyncClient` against the test app and asserting HTTP status codes and response shapes. `pytest -m integration tests/integration/test_messages.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-020: Review Agent and Mentor Memory routers

**Description**: Implement the Review Agent and Mentor Memory Inspector REST routers per Sections 11.10 and 11.11.

Produce:
- `app/routers/review_agent.py` — all six Review Agent handlers:
  - `get_run_status`: query latest `ReviewAgentRun` for Workspace; return `{has_run: false, latest_run: null}` if none; otherwise return latest run status
  - `trigger_run`: 409 if `status='running'` exists for this Workspace; insert `ReviewAgentRun` row with `status='running'`; spawn `asyncio.create_task(run_review_agent_job(workspace_id))`; return 202
  - `list_findings`: return only `active` and `stale` findings
  - `apply_finding`: 409 if not `active`; use `update_system_prompt()` helper; call `mark_stale_findings_for_persona()` in same transaction; set finding to `actioned`
  - `dismiss_finding`: 409 if not `active`; set `status='dismissed'`
  - `consultation`: validate `X-Workspace-ID`, bootstrap workspace context from persona PK; load `active` and `stale` findings as context; maintain in-memory session keyed by `session_id` with TTL `CONSULTATION_SESSION_TTL_SECONDS`; call `ModelGateway.stream(purpose="consultation")`; return SSE stream. Full conversation histories are excluded per the US-RA4 constraint.
- `app/routers/mentor.py` — two mentor memory handlers (note: `start_chapter` is already implemented in B-018 on the conversations router):
  - `get_episodic_memories`: 403 if not `is_mentor`; return all entries ordered by `sequence_number ASC`
  - `get_semantic_memories`: 403 if not `is_mentor`; return all entries ordered by `updated_at DESC`

Register both routers in `app/main.py`.

**Depends on**: B-008, B-007, B-015, B-012

**Complexity**: M

**Acceptance condition**: Integration tests in `tests/integration/test_review_agent.py` and `tests/integration/test_mentor_memory.py` pass (marked `@pytest.mark.integration`). `test_review_agent.py` verifies the full finding lifecycle end-to-end (create → apply → stale detection → dismiss) and all three reconciliation outcomes against a real DB. `test_mentor_memory.py` verifies Working→Episodic promotion trigger and Episodic→Semantic promotion lifecycle including `pending_promotion` flag. `pytest -m integration tests/integration/test_review_agent.py tests/integration/test_mentor_memory.py` exits 0.

**Condition type**: automated

**Status**: not_started

---

### Task B-021: Control signals router and full integration test pass

**Description**: Implement the conversation control signal router per Section 11.12, and complete the integration test suite for the full message send → stream → response flow.

Produce:
- `app/routers/control.py` — three control handlers, all requiring `X-Workspace-ID` header validation and workspace context bootstrap from conversation PK:
  - `pause_conversation`: 403 if ended; set `pause_requested=True` via `orchestrator.update_state()`
  - `resume_conversation`: 403 if ended; 409 `CONVERSATION_NOT_PAUSED` if not paused; clear `pause_requested=False`; trigger graph resume
  - `cancel_conversation`: 403 if ended; set `exchange_cancelled=True` in graph state; graph transitions to idle on next tick

Register this router in `app/main.py` without a workspace prefix.

Also write the integration test for the full message send → SSE stream → response complete flow:
- `tests/integration/test_conversations.py` (add to existing file): test that `POST /messages` with a valid user message returns 201 with the persisted user message, the graph begins processing (state transitions to busy), and eventually emits an `idle` event on the SSE stream. Uses `FakeSseManager` to capture events.

**Depends on**: B-018, B-019, B-010

**Complexity**: M

**Acceptance condition**: `POST /conversations/{id}/pause` returns `{"status": "pause_requested"}`. `POST /conversations/{id}/resume` on a paused conversation returns `{"status": "resumed"}`. `POST /conversations/{id}/cancel` returns `{"status": "cancelled"}`. 403 is returned for ended conversations. 409 `CONVERSATION_NOT_PAUSED` is returned by resume on a non-paused conversation. Integration test for message send → idle SSE event passes. `pytest -m integration tests/integration/test_conversations.py` exits 0 (including the new message flow test).

**Condition type**: automated

**Status**: not_started

---

### Task B-022: End-to-end smoke test and OpenAPI spec validation

**Description**: Validate the complete backend is wired correctly and the generated OpenAPI spec matches the approved API contract.

Produce:
- A runnable smoke test script `tests/smoke/test_smoke.py` (marked `@pytest.mark.e2e`) that uses `httpx.AsyncClient` against a running backend instance (with `TEST_DATABASE_URL` and a real config.override.json) and verifies:
  - `POST /workspaces` creates a workspace
  - `POST /workspaces/{id}/personas` creates a non-Mentor Persona
  - `POST /workspaces/{id}/personas` with `is_mentor=True` creates a Mentor + Mentor Conversation
  - `POST /workspaces/{id}/conversations` creates a Conversation
  - `POST /workspaces/{id}/conversations/{id}/messages` returns 201 with the user message
  - `GET /workspaces/{id}/personas/{id}/memory/episodic` returns 200 (empty list initially)
  - `DELETE /workspaces/{id}` returns 204
- Verification that the live `/openapi.json` matches the approved API contract for: all endpoint paths exist; all documented request/response fields are present; all documented error codes appear in the spec

The OpenAPI spec validation can be a checklist run manually against `GET /openapi.json`. The Implementer must compare the generated spec against `documentation/tasks/api-contract.md` and document any gaps found in the pre-task plan.

**Depends on**: B-021, B-020, B-017

**Complexity**: M

**Acceptance condition**: `pytest -m e2e tests/smoke/test_smoke.py` exits 0 against a running backend with a seeded test database. Manual inspection of `GET /openapi.json` confirms all endpoint paths in `documentation/tasks/api-contract.md` are present and all documented response fields appear in the schema definitions. Any discrepancies are listed in a `documentation/tasks/post-completion-review-backend-task-22.md` file.

**Condition type**: both

**Status**: not_started

---
