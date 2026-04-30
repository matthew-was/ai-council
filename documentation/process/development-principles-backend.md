# Development Principles — Backend

Backend-specific principles for `apps/backend/`. Read this file alongside `development-principles.md` for every backend task.

---

## How Principles Are Added

Principles are proposed by the Principles Guardian after every 5 completed backend tasks. The developer approves or rejects each proposal. Approved principles are added here.

Do not restate universal principles from `development-principles.md` — reference them if needed.

---

## AI Model Abstraction

`ModelGateway` is a concrete class — not an abstract base class and not a factory function. It owns the configured `BaseChatModel` instance (created via `init_chat_model`) and centralises all retry and timeout policy. Provider swaps (OpenAI → Ollama, etc.) are handled by changing `model` and `model_provider` in config; no code changes are required.

`ModelGateway` is the test seam for all AI calls. Unit tests replace it with `FakeModelGateway` (see Fakes Over Mocks). Tests never import `BaseChatModel` directly.

**What this rules out:** ABC/interface wrappers around `ModelGateway`; factory functions that return different gateway implementations; tests that mock `BaseChatModel` methods directly.

---

## Composition Root

`app/main.py` is the only module that reads configuration (`BackendConfig`). All application services and singletons are constructed in the lifespan context manager and receive their collaborators as constructor arguments — never config objects, never global imports of config.

The construction order in `main.py` is:

1. Load and validate `BackendConfig`
2. Build infrastructure (engine, session factory, `PostgresSaver`)
3. Build `ModelGateway` (receives extracted config values it needs, not the whole `BackendConfig`)
4. Build all services that depend on `ModelGateway` (e.g. `RollingSummary`, `ReviewAgentRunner`, `MentorPromoter`)
5. Build `ConversationOrchestrator` (receives `ModelGateway` and session factory)
6. Wire APScheduler jobs (receive the service instances built above)

No module outside `main.py` calls `dynaconf.settings` or reads `BackendConfig` directly.

**What this rules out:** Services that call `settings.FOO` internally; config singletons imported across modules; services that accept a `BackendConfig` and extract what they need.

---

## No Hidden State — Dependencies Explicit at Construction

All dependencies a class needs must be declared as constructor parameters and assigned to instance attributes. Classes are the preferred way to group shared state and collaborators.

A "hidden dependency" is any collaborator obtained from a global registry, module-level singleton, or ambient context inside a method body — rather than passed in at construction time. This includes calling `structlog.get_logger()`, importing a config singleton, or reaching into a global cache inside business logic.

**What this rules out:** `self.log = structlog.get_logger()` inside `__init__`; module-level singleton objects used across services; accessing globals inside methods rather than via constructor-injected collaborators.

---

## Service Layer Result Types

The service layer communicates expected failure outcomes — those that map to 4XX HTTP responses — using explicit result types, not exceptions. Routers inspect the result and raise `HTTPException` themselves.

A simple tagged union is the preferred shape:

```python
# app/results.py
from dataclasses import dataclass
from typing import Generic, TypeVar

T = TypeVar("T")

@dataclass
class Ok(Generic[T]):
    value: T

@dataclass
class Err:
    code: str          # matches the contract's error `code` field
    message: str
    status: int        # 409, 422, etc.
    detail: dict | None = None   # e.g. blocking_conversations list

ServiceResult = Ok[T] | Err
```

Router pattern:

```python
result = await conversation_service.end(conversation_id)
if isinstance(result, Err):
    raise HTTPException(status_code=result.status, detail={"message": result.message, "code": result.code})
return result.value
```

**Scope of this rule:** Expected domain failures that the API contract documents as 4XX responses. Unexpected failures (database connectivity, unhandled edge cases) remain as exceptions and are caught by the global 500 handler in `app/errors.py`.

**What this rules out:** Raising custom `ConversationNotIdleError`, `MentorAlreadyExistsError`, etc. from inside service methods; service-layer `HTTPException` raises; a large custom exception hierarchy in `errors.py` that mirrors the contract's error codes.

---

## Fakes Over Mocks

Test doubles for collaborators (repositories, `ModelGateway`, `SseManager`) are concrete implementations of the same abstract base class (ABC) as the real implementation. They live in `tests/fakes/` and are constructed with the return values or behaviours the test needs.

```text
tests/
└── fakes/
    ├── fake_model_gateway.py      # FakeModelGateway(responses: list[str])
    ├── fake_conversation_repo.py  # FakeConversationRepository(conversations: list[Conversation])
    └── fake_sse_manager.py        # FakeSseManager — records emitted events
```

`FakeModelGateway` is the canonical substitute for `ModelGateway` in unit tests. It accepts a list of pre-configured responses and raises on any unexpected call — forcing tests to be explicit about what the gateway will return.

**What this rules out:** `unittest.mock.MagicMock()` or `pytest-mock` `mocker.patch()` for collaborators that have a defined interface; mocking `BaseChatModel` methods directly.

---

## Logger Injection

Top-level service classes constructed by the composition root (`main.py`) receive a `structlog.BoundLogger` as a constructor argument:

```python
class ReviewAgentRunner:
    def __init__(self, repo: ReviewAgentRepository, gateway: ModelGateway, log: BoundLogger):
        self._repo = repo
        self._gateway = gateway
        self._log = log
```

`main.py` binds a named logger for each service at construction time:

```python
review_agent_runner = ReviewAgentRunner(
    repo=review_agent_repo,
    gateway=model_gateway,
    log=structlog.get_logger("review_agent"),
)
```

LangGraph node functions and small helper functions that are not constructed by the composition root may call `structlog.get_logger(__name__)` locally — the injection requirement applies only to classes that `main.py` constructs directly.

**What this rules out:** `self.log = structlog.get_logger()` inside a top-level service class `__init__`; module-level logger globals in service files.

---

## Tiered Test Markers

Every test is tagged with exactly one pytest marker indicating its tier:

| Marker | Meaning |
| --- | --- |
| `unit` | No I/O; uses fakes; runs in milliseconds |
| `integration` | Hits the real test database; requires Docker Compose dev stack |
| `e2e` | Full stack via HTTP client; rarely used in V1 |

Markers are declared in `pyproject.toml`:

```toml
[tool.pytest.ini_options]
markers = [
    "unit: no I/O, uses fakes",
    "integration: hits the test database",
    "e2e: full stack via HTTP client",
]
```

CI runs `pytest -m unit` for fast feedback on every push and `pytest -m "unit or integration"` on pull requests.

**What this rules out:** Unmarked tests; tests tagged `unit` that open a database connection or make a network call.

---

## API Design

The backend produces an OpenAPI spec as a build artefact that must match the approved API contract document (`documentation/tasks/api-contract.md`). The Code Reviewer validates the generated spec against the contract.

---

## What These Principles Rule Out (Backend-Specific)

| Anti-pattern | Why prohibited | Principle violated |
| --- | --- | --- |
| Ad-hoc SQL queries outside defined data access patterns | Creates brittle coupling to the schema; bypasses transaction boundaries | Clear Boundaries |
| Hardcoded AI model names or endpoint URLs | Prevents swapping the AI model via configuration | Infrastructure as Configuration |
| ABC/interface wrappers around `ModelGateway` | Adds indirection with no benefit; `ModelGateway` is already the seam | AI Model Abstraction |
| Services that read `BackendConfig` or `dynaconf.settings` directly | Violates the single-composition-root rule | Composition Root |
| Custom exception hierarchy mirroring contract error codes | Couples service layer to HTTP semantics; result types are clearer | Service Layer Result Types |
| `MagicMock` / `mocker.patch` for collaborators with defined interfaces | Hides missing ABC methods; breaks under interface changes | Fakes Over Mocks |
| `structlog.get_logger()` inside top-level service class `__init__` | Hidden dependency not visible at the construction site | Logger Injection |
| Unmarked tests or `unit`-tagged tests with I/O | Breaks tier separation; slows fast-feedback loop | Tiered Test Markers |
