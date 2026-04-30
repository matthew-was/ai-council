# Architecture Decisions

This file records the Architecture Decision Records (ADRs) for AI Council. Each ADR captures a cross-cutting decision made during the Head of Development phase. Decisions are developer-confirmed; the Head of Development agent facilitates and records but does not decide unilaterally.

---

## ADR-001 — Agentic Framework and Backend Language

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

AI Council has several distinct agentic behaviours: multi-Persona conversations in three modes (Single, Round-Robin, P2P), a background Orchestrator that suggests Personas mid-conversation, a three-layer Mentor memory system, and a nightly Review Agent. The choice of agentic framework gates the backend language, the primitives available for orchestration and context handling, streaming, and conversation pause/resume across process restarts. The Infrastructure as Configuration principle requires that no framework force hardcoded provider selection or model endpoints.

### Decision

Adopt **LangChain + LangGraph (Python)** as the agentic framework and backend language, with an explicit internal `ConversationOrchestrator` abstraction (~200–400 LOC) to contain LangChain/LangGraph lock-in.

Scope of use:

- LangGraph: used for the Conversation graph (multi-Persona turn sequencing, pause/resume via `interrupt()` + checkpointer, `@Orchestrator` post-message hook node)
- LangChain: used for model calls (`init_chat_model` with `configurable_fields`), prompt templates, and `trim_messages`
- Plain async Python: used for the Review Agent sweep and other background jobs that do not require graph semantics
- The `ConversationOrchestrator` class is the containment boundary — code outside it does not import from `langchain.*` or `langgraph.*` except via `ModelGateway` (see ADR-002)

### Rationale

LangGraph's `interrupt()` + checkpointer is the only off-the-shelf solution that natively satisfies pause/resume of P2P autonomous exchanges across process restarts. Re-implementing this capability bespoke would require approximately 300–500 LOC of stateful async code. LangChain's `BaseChatModel` interface satisfies Infrastructure as Configuration via `init_chat_model(configurable_fields=("model", "model_provider"))`.

The developer chose this option because LangChain and LangGraph are the standard libraries in the agentic AI field; learning them on this project has direct career value. Python is the lower-risk language given LangGraph's primacy in that ecosystem and the maturity of Ollama/provider tooling in Python.

### Consequences

- All downstream decisions assume Python as the backend language
- The `ConversationOrchestrator` abstraction must be designed before any graph node is written
- LangGraph's supervisor pattern does not fit the Orchestrator's "soft suggester" role — the Orchestrator is implemented as a post-message hook node, not a supervisor
- Framework version: LangChain v1.0+ (committed to no breaks until v2.0 as of Oct 2025); LangGraph stable release

### Options Considered

- **PydanticAI (Python):** thin abstraction + structured output but no built-in graph or checkpointer; would require building the equivalent of LangGraph's pause/resume bespoke
- **Mastra (TypeScript):** TypeScript end-to-end stack; production-stable but lags Python LangGraph on edge features; ML tooling weaker in TypeScript
- **No framework, thin SDK wrapper:** genuinely viable but requires ~300–500 LOC of persistence and streaming plumbing that LangGraph provides out of the box

---

## ADR-002 — AI Model Abstraction Layer

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

Every LLM call in AI Council — Persona turns, Orchestrator suggestions, Review Agent analysis, Mentor memory promotion, auto-naming, context compression — must be swappable between providers (Ollama, OpenAI, Anthropic, etc.) by configuration change alone, with zero application code changes. ADR-001 adopted LangChain/LangGraph, which provides `BaseChatModel` as a provider-agnostic protocol. The question is whether `BaseChatModel` itself is the abstraction boundary or whether a project-internal façade is needed.

### Decision

Adopt a **two-tier abstraction**:

**Tier 1 — `ModelGateway` (application services outside the LangGraph graph)**

A single `ModelGateway` class used by all application-layer services that make model calls outside the conversation graph. Exposes four methods:

- `invoke(messages, *, purpose: str) -> str` — auto-naming, context compression
- `stream(messages, *, purpose: str) -> AsyncIterator[str]` — Persona/Mentor turns outside the graph
- `invoke_structured(messages, schema, *, purpose: str) -> T` — Orchestrator suggestions, Review Agent findings, Mentor memory promotion, speaker selection
- `embed(text) -> vector` — loop detection, Semantic Memory retrieval (when added)

`ModelGateway` owns the configured `BaseChatModel` instance, centralises retry/timeout policy, and is the sole test seam for application-layer service tests.

**Tier 2 — `BaseChatModel` direct (inside LangGraph nodes)**

LangGraph nodes within `ConversationOrchestrator` use `BaseChatModel` directly via LangGraph's config propagation. The `chat_prompt | model` LCEL pattern and `graph.stream()` token streaming require a real `BaseChatModel`; wrapping it inside the graph would sacrifice LCEL ergonomics.

**Boundary rule:** Only `ModelGateway` itself and the `ConversationOrchestrator` module (and its graph nodes) may import from `langchain.*`. All other application code imports `ModelGateway`. This rule must be documented in CLAUDE.md and enforced by code review. Any code that crosses the boundary requires an explicit comment explaining why.

### Rationale

ADR-001 established the `ConversationOrchestrator` as the LangChain containment boundary. Adding a second wrapper inside LangGraph nodes is redundant. Application services outside the graph benefit clearly from a LangChain-free, retry-centralised, test-friendly façade. The developer confirmed: "the line between ModelGateway and LangChain needs to be very clear and well documented."

Option B (single `ModelGateway` everywhere) would drift into Option C in practice because LangGraph nodes naturally reach for `BaseChatModel` for LCEL and streaming ergonomics.

### Consequences

- `ModelGateway` is a required collaborator injected via FastAPI `Depends()` (see ADR-003)
- The four-method façade surface covers all identified V1 call sites; tool-binding is not required in V1
- The boundary rule must appear in CLAUDE.md
- New code crossing the boundary requires an explicit inline comment

### Options Considered

- **Option A (no wrapper):** `BaseChatModel` used everywhere; Infrastructure as Configuration satisfied natively but retry lives at each call site and every test touches LangChain
- **Option B (single `ModelGateway` everywhere):** uniform but LangGraph nodes would need to call the façade and lose LCEL ergonomics, or be given a raw-model escape hatch — which is Option C in disguise

---

## ADR-003 — Backend Web Framework

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

ADR-001 commits to Python as the backend language. The web framework must support async streaming endpoints (SSE or WebSocket — see ADR-013), dependency injection of `ModelGateway` and `ConversationOrchestrator` as distinct collaborators, OpenAPI spec generation from the implementation (required by CLAUDE.md: spec is a build artefact), and single-command local launch (NFR-3/NFR-5). Flask (sync-only) and Django (full-stack overhead) were eliminated by research.

### Decision

Adopt **FastAPI** (Starlette + Pydantic v2) as the backend web framework.

- Streaming: `StreamingResponse` + `sse-starlette` for SSE endpoints
- Dependency injection: FastAPI `Depends()` injects `ModelGateway` and `ConversationOrchestrator` as separate dependencies
- OpenAPI: auto-generated from route signatures and Pydantic models — satisfies the build-artefact constraint
- Background jobs: APScheduler `AsyncIOScheduler` integrated via the FastAPI lifespan context manager

### Rationale

LangGraph + FastAPI + SSE is the most documented Python pattern for the exact use case AI Council represents. FastAPI's ecosystem weight reduces the risk of novel integration questions that cannot be resolved from community resources.

The developer stated: "the core system will be complex enough — keep what can be simple, as simple." This is recorded as a project-wide design heuristic that should inform future decisions.

### Consequences

- Streaming endpoints use `StreamingResponse` + `sse-starlette` pending ADR-013
- `ModelGateway` and `ConversationOrchestrator` are FastAPI dependencies, injected per-request
- OpenAPI spec is a build artefact; the human-readable API contract remains the source of truth
- APScheduler `AsyncIOScheduler` is the chosen background job runner (used by ADR-011 and ADR-010)

### Options Considered

- **Litestar:** native SSE handlers, stronger DI system, msgspec serialisation; technically capable but only ~5,900 GitHub stars; no published LangGraph integration examples; higher ecosystem risk for a solo developer

---

## ADR-004 — Database Technology

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

The database anchors persistence for every entity: Workspaces, Personas, Conversations, Messages, `conversation_personas` snapshots, Mentor memory layers, Review Agent findings. It also hosts the LangGraph checkpointer for conversation state. Requirements: local-first with no external cloud dependency (NFR-3), `user_id`/`workspace_id` on every table from day one (NFR-8), schema migration support, and compatibility with the Python + FastAPI stack.

### Decision

Adopt **PostgreSQL** as the database, with:

- **ORM:** SQLAlchemy 2.x async (`asyncpg` driver)
- **Migrations:** Alembic
- **LangGraph checkpointer:** `PostgresSaver`

PostgreSQL runs as a container in the Docker Compose stack (ADR-005).

### Rationale

PostgreSQL is the developer's career default. Running a Docker container with a Postgres instance is their natural starting point, not a complexity cost. The "keep simple, simple" principle (ADR-003) applies relative to the developer's existing knowledge and tooling defaults, not in the abstract. The Docker Compose deployment model (ADR-005) removes the server-process objection. PostgreSQL's additional capabilities — MVCC, JSONB + GIN indexes, Row-Level Security — are available without requiring migration at cloud-deployment time.

### Consequences

- `user_id` and `workspace_id` are present on every table from day one (NFR-8)
- JSONB columns are available for memory documents and structured data
- Row-Level Security is a future defence-in-depth option (see ADR-007)
- The `PostgresSaver` checkpointer stores LangGraph conversation state in the same database
- All primary key `id` columns use **UUID v7** (time-ordered, monotonically increasing within a millisecond). This gives B-tree indexes far better locality than UUID v4's random distribution and eliminates page-split churn on insert-heavy tables. UUIDs are naturally sortable by insertion order. Specific Python library (`uuid.uuid7()` from Python 3.13+, or `uuid-utils` for 3.12) confirmed during implementation.

### Options Considered

- **SQLite + SQLAlchemy async (`aiosqlite`) + Alembic:** zero install steps; rejected because PostgreSQL is simpler for this developer and Docker Compose makes the server-process requirement a non-issue
- **libSQL / Turso:** SQLite-compatible with embedded cloud sync; Python/SQLAlchemy integration experimental as of early 2026; introduces external-service lock-in risk

---

## ADR-005 — Deployment Model: Docker Compose

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

NFR-3 requires local-first operation with no cloud dependency. The developer stated Docker Compose as the canonical run model for the full system. This resolves Decision #15 (local-first deployment and packaging) from the ADR roadmap.

### Decision

**`docker compose up` is the canonical way to run the full AI Council system**, for both local development and V1 deployment.

- All services (FastAPI backend, PostgreSQL, and any future services) run as containers defined in `docker-compose.yml`
- Local development and production use the same compose file, with environment variable overrides for environment-specific configuration
- A single `docker compose up` command starts the full system with no manual service installation required

### Rationale

Docker Compose makes the PostgreSQL server-process requirement a non-issue (ADR-004). It ensures the system is portable and self-contained. NFR-3 (local-first) is satisfied by the compose file, not by choosing an embedded/serverless database.

### Consequences

- All service configuration is injected via environment variables in the compose file or a `.env` file
- The compose file is a first-class project artefact and must be kept up to date as new services are added
- Ollama may be added as an optional compose service or run externally — to be confirmed during implementation
- Future cloud deployment replaces the compose file with equivalent infrastructure-as-code without application code changes

### Options Considered

No alternatives were evaluated — Docker Compose was stated as a core part of the plan by the developer.

---

## ADR-006 — Conversation Snapshot and Persona Versioning

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

A Persona's Name, System Prompt, and Temperature can be edited at any time. Past and in-flight Conversations must continue using the values that were active for that Persona when it participated — edits must not retroactively rewrite historical Conversations. Two concerns must be decoupled: the per-Conversation participant snapshot and the Persona's full edit history.

### Decision

**Three-axis design:**

**Axis 1 — `conversation_personas` table (per-Conversation snapshot)**

`(id, conversation_id FK, persona_id nullable FK, joined_at, snapshot_name, snapshot_system_prompt, snapshot_temperature, left_at nullable)`

- Context assembly always reads from this table, never from `personas` directly
- `(conversation_id, persona_id)` is NOT a unique constraint — multiple rows per pair are valid and expected
- "Active snapshot" = the row with the most recent `joined_at` for that `(conversation_id, persona_id)` pair

**Mid-conversation prompt refresh:** A user may pull the latest System Prompt into an active Conversation. When this happens, a new `conversation_personas` row is inserted for the same Persona. New messages use the newer snapshot; old messages retain their original FK. This is a user-initiated action only — Review Agent findings do NOT automatically insert new rows into running Conversations.

**Axis 2 — `persona_system_prompt_versions` table (Persona version history)**

`(id, persona_id FK, system_prompt, created_at)`

On every edit: insert a new version row + update `personas.system_prompt` in place in a single transaction.

**Axis 3 — `messages.conversation_persona_id` FK (Message provenance)**

Each Message points at the `conversation_personas` row that was active when that Message was generated.

**Decoupling rule (hard constraint):** No FK from `conversation_personas` into `persona_system_prompt_versions`. Snapshots store System Prompt text directly. Deleting a Persona sets `conversation_personas.persona_id` to NULL but leaves snapshot columns intact.

### Rationale

The developer confirmed: "a Conversation is a self-contained concept in however many tables it needs; separately a Persona has its own set of tables. A message is part of a conversation so then references the parent conversation persona." If a Persona is updated mid-conversation, two `conversation_personas` rows exist — the latest is used for new messages, but each message still points to the version active when it was created.

### Consequences

- Context assembly queries `conversation_personas` ordered by `joined_at DESC` for the active snapshot
- The Memory Inspector reads both `persona_system_prompt_versions` and `conversation_personas` directly
- Review Agent findings update `personas` + insert a `persona_system_prompt_versions` row only

### Options Considered

- **`participants_snapshot JSONB` on `conversations`:** fewer tables but harder to evolve for leave/rejoin scenarios
- **Event-sourced log:** disproportionate — only one event type (prompt edit) was relevant
- **`is_current` flag on version table:** more invariants to maintain with no benefit

---

## ADR-007 — Workspace Isolation Enforcement

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

Every Workspace-scoped entity must be unreachable from any other Workspace (FR-1.6). The risk is mechanical: a query without a `workspace_id` predicate leaks data. NFR-8 requires `user_id` on every table from day one. ADR-004 (PostgreSQL) makes Row-Level Security available as a future option. ADR-005 (single local user in V1) means there is no multi-tenant adversary in V1.

### Decision

**Application-layer ORM scoping now, with PostgreSQL RLS explicitly reserved as a documented future layer.**

- `WorkspaceScopedMixin`: `workspace_id UUID NOT NULL FK` + index on every Workspace-scoped table
- `UserScopedMixin`: `user_id UUID NOT NULL` on every table; composes with `WorkspaceScopedMixin` for most entities
- SQLAlchemy `do_orm_execute` session listener: reads `workspace_id` from a `ContextVar` and injects `WHERE workspace_id = current` into every SELECT against mixin subclasses
- `ContextVar` set by FastAPI middleware per request; set explicitly by background jobs at task start
- Raw SQL must carry an explicit `workspace_id` predicate — enforced by code review; raw SQL must include an inline comment confirming the predicate

**RLS reserved:** Schema is RLS-ready from day one (indexes and NOT NULL in place). PostgreSQL RLS policies can be added via a future Alembic migration at cloud-deployment time with zero application code changes.

### Rationale

RLS adds transaction-boundary ceremony that solves a problem V1 does not have — a single local user with no adversary. The research explicitly recommended this layering: V1 = ORM scope; cloud = ORM scope + RLS. Choosing this option over Option A ensures the deferral is documented rather than forgotten.

### Consequences

- All Workspace-scoped entities inherit both mixins; the ORM listener enforces isolation transparently
- Background jobs must set the `ContextVar` explicitly at task start
- Cloud deployment upgrade path: add RLS policies via migration; no application code changes required

### Options Considered

- **Option A (ORM scoping only, no documented RLS path):** functionally identical but does not record the future commitment
- **Option B (ORM scoping + RLS now):** adds `SET LOCAL` per transaction, Alembic policy management, and connection pool verification in V1 for a problem that does not exist with a single local user

---

## ADR-008 — Context Window Management

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

Every model call for a Persona or Mentor turn must fit three elements into the configured context window: the frozen System Prompt from the active `conversation_personas` snapshot (ADR-006), the full Context Panel (FR-20.2 — must always be included and never truncated), and as much message history as the remaining budget allows. Different providers have different context window sizes and tokenisers.

### Decision

**Rolling recursive summarisation with last-N verbatim tail, paired with approximate token counting.**

**Context assembly order (always):**

1. `SystemMessage(snapshot_system_prompt)` — always included in full
2. `SystemMessage(context_panel)` — always included in full; FR-20.2 guarantee; never subject to truncation
3. `AIMessage(rolling_summary)` — if a summary exists for this Conversation
4. Last-N verbatim messages within the remaining token budget

**Compression trigger:** When the verbatim tail + summary approaches approximately 75% of the configured context window size.

**Compression step:** `ModelGateway.invoke` at `temperature=0` folds the oldest verbatim block into the rolling summary. The updated summary persists to a `conversation_summaries` table (one row per Conversation, updated in place).

**Token counting:** Approximate counting (character-based heuristic, ~4 chars/token) in V1. Per-provider counters added when hard budget enforcement is needed.

**Context window size:** A `context_window` field on `ModelConfig`, set by configuration — not derived from the model name.

**`CompressionStrategy` interface:** Created in V1 (only `RollingSummary` implemented) so the implementation is encapsulated and swappable.

### Rationale

Rolling summarisation at temperature=0 is the closest-to-deterministic production pattern and provides the best balance of information retention and cost. The Context Panel is placed before history and always included regardless of window pressure — this is FR-20.2's core guarantee. Approximate token counting is sufficient for compression triggering (±10% accuracy at 75% threshold).

### Consequences

- The compression step adds one model call per compression event; brief pause possible on slow local LLMs
- The rolling summary is the single long-term coherence mechanism for non-Mentor Conversations
- `conversation_summaries` table required in the initial migration
- `CompressionStrategy` interface isolates the implementation for future replacement

### Options Considered

- **Option A (sliding-window only):** simplest; zero latency overhead; early-conversation facts permanently lost once outside the window
- **Option C (staged — sliding-window V1, rolling summary later):** honours simplicity principle but defers until real usage justifies it; rejected in favour of building the correct solution from the start

---

## ADR-009 — Mentor Memory Implementation

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

The Mentor is a single Persona per Workspace with a persistent, never-ending Conversation. Its three-layer memory system provides long-term continuity. Working Memory is defined by ADR-008 (rolling summary + verbatim tail). This ADR covers the storage shape and retrieval pattern for the Episodic and Semantic layers. Promotion logic is ADR-010.

### Decision

**Two dedicated relational tables, no embeddings in V1, retrieval by loading all entries.**

**`mentor_episodic_memories`**

`(id, workspace_id, user_id, mentor_persona_id, sequence_number, summary_text, source_conversation_id nullable, created_at, promoted_at nullable)`

**`mentor_semantic_memories`**

`(id, workspace_id, user_id, mentor_persona_id, title, content_markdown, created_at, updated_at)`

No embedding column in V1. Both tables use `WorkspaceScopedMixin` and `UserScopedMixin` (ADR-007).

**Retrieval interface:** `MentorMemoryRetriever.load_context(workspace_id, mentor_persona_id) -> (episodic_entries, semantic_documents)`

V1 implementation: load all Episodic entries ordered by `sequence_number`, and all Semantic documents ordered by `updated_at DESC`.

**Injection order at Mentor turn:**

1. `SystemMessage(snapshot_system_prompt)`
2. `SystemMessage(context_panel)`
3. Episodic entries (as `SystemMessage`s)
4. Semantic documents (as `SystemMessage`s)
5. Working Memory (rolling summary + verbatim tail per ADR-008)

### Rationale

Semantic documents are a small, curated corpus — "load all" is both correct behaviour and a one-line query at V1 scale. Adding pgvector and an embedding model before there is a concrete retrieval failure pays infrastructure cost for no current benefit. The `MentorMemoryRetriever` interface means the upgrade to top-K retrieval is additive when warranted.

### Consequences

**Forward path to pgvector (anticipated eventual endpoint per developer):**

The upgrade requires: (1) `embedding vector(N)` column + HNSW index via Alembic migration, (2) `embedding_model` and `embedded_at` tracking columns, (3) backfill job for existing rows, (4) re-embedding job triggered when the configured embedding model changes — stale embeddings from a different model are semantically incompatible and must be fully regenerated before similarity search is re-enabled.

The `MentorMemoryRetriever` interface is the only change point — Mentor turn assembly code does not change.

### Options Considered

- **Option B (pgvector on Semantic from day one):** adds embedding model selection and similarity query before the corpus is large enough to need it; "load all" and "top-K" produce the same result at V1 scale
- **Option C (pgvector on both Episodic and Semantic):** Episodic is a rolling window of N — similarity and recency ordering produce equivalent results at V1 scale; rejected on ADR-003 simplicity grounds

---

## ADR-010 — Mentor Memory Promotion Logic

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

The Mentor has two promotion paths: Working Memory → Episodic and Episodic → Semantic. Both involve LLM calls and must be designed around that. The developer explicitly stated that a brief inline pause for Working→Episodic is acceptable, and that Episodic→Semantic is non-critical and appropriate for out-of-band execution.

### Decision

**Trigger model:**

- **Working→Episodic at capacity threshold:** synchronous/inline — fires when Working Memory reaches the ADR-008 compression threshold; runs in the same DB transaction as the compression step; brief pause is acceptable
- **Episodic→Semantic:** async — fires on a configured APScheduler schedule only (same pattern as the Review Agent nightly job); session-end triggering is not used. A `pending_promotion` flag on the Episodic row ensures idempotency

**Extraction (Episodic→Semantic):** LLM structured output via `ModelGateway.invoke_structured` at `temperature=0`. Input: Episodic row summary text + list of existing Semantic document titles. Output: JSON list of facts with `(target_document_title, content, mode: new|update)`. Empty array = no facts to promote.

**Failure handling:** Retry 3× with exponential backoff. On final failure: retire the Episodic row (set `promoted_at`), log `promotion_skipped` with the entry ID. Memory system stays unblocked.

**Transaction boundary:** LLM call is outside the DB transaction. The DB transaction wraps only: insert/update `mentor_semantic_memories` + set `promoted_at` on the Episodic row. Process crash mid-call leaves the row unchanged; promotion re-runs on next trigger; `promoted_at` prevents double-promotion.

### Rationale

The "must not block" framing in the research was a quality-of-life recommendation, not a hard product requirement. The developer overrode it: an inline pause for Working→Episodic is acceptable because it coincides with an already-synchronous compression step (ADR-008). Episodic→Semantic is async for cost and complexity reasons, not latency reasons. LLM structured output (E-B) is the correct extraction approach — pure rules-based extraction has an unacceptably high false-negative rate for implicit conversational facts.

### Consequences

- The synchronous Working→Episodic path shares the ADR-008 compression DB transaction
- The async Episodic→Semantic path requires a `pending_promotion` flag for idempotency
- LLM unavailability during Episodic→Semantic does not block the Mentor's conversation

### Options Considered

- **T-A (capacity-only triggers, all inline):** Episodic→Semantic inline adds a significant LLM call pause to the turn
- **T-B (all triggers async):** would require making ADR-008's synchronous compression step async — unnecessary complexity
- **E-A (rules-based extraction):** high false-negative rate for implicit conversational facts; rejected
- **F-A (block retirement indefinitely):** memory system becomes blocked under persistent LLM failure

---

## ADR-011 — Review Agent Scheduling

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

FR-23.1 requires a nightly (or on-demand) Review Agent sweep that analyses concluded Conversations and surfaces System Prompt improvement suggestions per Persona. Reliability (not missing a run silently) matters more than latency. ADR-001 (Python), ADR-003 (FastAPI + APScheduler), and ADR-005 (Docker Compose, no external managed scheduler) constrain the options.

### Decision

**APScheduler `AsyncIOScheduler` inside the FastAPI process.**

- One `AsyncIOScheduler` started in the FastAPI lifespan context manager
- One `CronTrigger` job with schedule read from `REVIEW_AGENT_SCHEDULE` environment variable (cron string) — not hardcoded
- `max_instances=1`, `coalesce=True`, small `misfire_grace_time`

**`review_agent_runs` status table:**

`(id, workspace_id, status ENUM(pending/running/complete/failed), started_at, completed_at, error_message nullable)`

- Serves as: run lock, audit log, and crash-recovery state
- Both nightly cron and `POST /review-agent/run` check for `status='running'` before starting; manual endpoint returns 409 if already running
- Crash recovery: on startup, `status='running'` rows older than a grace period are reset to `failed`

### Rationale

Every prior ADR converges on this pattern: APScheduler named in ADR-003; PostgreSQL as state store (ADR-004); no new compose service (ADR-005). The two-layer guard (`max_instances=1` + `review_agent_runs` row-lock) handles single-run enforcement, collision, and crash recovery in one mechanism. The nightly schedule is configurable to avoid surprise runs at inconvenient times.

### Consequences

- Review Agent runs are auditable via the `review_agent_runs` table
- Manual triggering via `POST /review-agent/run` enables on-demand analysis
- Multiple API instances protected against duplicate runs by the row-lock

### Options Considered

- **Option B (dedicated worker compose service):** clean separation of concerns but adds a second process and cross-process dispatch protocol for one nightly job; not warranted for V1
- **Option C (Celery/RQ/Arq + Redis):** adds Redis as a new compose dependency; disproportionate for a single nightly job

---

## ADR-012 — Orchestrator Trigger Mechanism

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

The Orchestrator is a background process that suggests (never adds) Personas mid-conversation. ADR-001 (LangGraph) means it is implemented as a post-message hook node in the conversation graph. ADR-002 specifies `ModelGateway.invoke_structured` as the appropriate call surface.

### Decision

**Post-message hook node, sequential after Persona turn (fire-and-forget async), with a configurable frequency gate.**

- `orchestrator_check` LangGraph node runs sequentially after the Persona response node completes
- Fires as a fire-and-forget async coroutine — the Persona turn's SSE stream ends before the Orchestrator call starts; user-perceived turn latency is unaffected
- If a suggestion is produced, it arrives on the Conversation's existing SSE channel as an `orchestrator_suggestion` event (distinct from token streaming events)
- Uses `ModelGateway.invoke_structured` with a `PersonaSuggestion` structured output schema

**Frequency gate:**

- `ORCHESTRATOR_EVAL_EVERY_N` environment variable (default: 1 — evaluate after every message)
- `messages_since_last_eval` counter in LangGraph conversation state; resets to 0 when the Orchestrator fires
- Simple message-count gate only — no time-based second dimension in V1
- The Orchestrator never adds Personas — suggestions only; user acceptance/dismissal is a separate UI action

### Rationale

The sequential post-message hook ensures the user's Persona turn response is unaffected by Orchestrator latency. A parallel branch (Option B) risks delaying the turn cycle close if the Orchestrator call is slow, and provides only marginal freshness benefit for a suggestion (not a routing decision). The frequency gate is included from day one as a configurable cost lever — `N=1` is equivalent to evaluating after every message.

### Consequences

- The SSE channel must support multiple event types: token streaming, `busy`/`idle` state, and `orchestrator_suggestion`
- Frontend must handle stale suggestions gracefully
- `ORCHESTRATOR_EVAL_EVERY_N` allows cost tuning without code changes

### Options Considered

- **Option A alone (no gate):** always evaluate after every message; no cost lever; adds an LLM call to every single message turn
- **Option B (parallel branch):** risks delaying turn cycle close; graph topology more complex; narrower signal (sees user message but not the Persona's just-generated response)

---

## ADR-013 — Frontend Framework

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

AI Council's frontend is a single-user, local-first interactive application: a persistent sidebar of Workspaces and Conversations, a real-time streaming message thread, the Persona configuration surface with a test panel (FR-4.9), the Mentor Memory Inspector, and modal flows for Review Agent findings. There is no public surface, no SEO requirement, and no marketing content. The frontend must consume the SSE streaming transport (ADR-003, ADR-013 transport selection), integrate with the FastAPI backend over HTTP/JSON, and be independently deployable as static assets under the Docker Compose model (ADR-005).

### Decision

**React 19 + Vite as the SPA framework and build tool.**

- **SPA only, no SSR.** The Vite build produces a static `/dist` bundle. AI Council is a local tool, not a public-facing web app, so server-side rendering adds build and runtime complexity with no benefit.
- **Served as a static build from a Docker Compose frontend container (ADR-005)**, alongside the FastAPI backend container. The container is a minimal static-file server (e.g., nginx or equivalent) serving the Vite build output.
- **Confirmed libraries:**
  - `@microsoft/fetch-event-source` for SSE — supports `POST` with body/headers, which native `EventSource` does not
  - **SWR** for server state (REST endpoints, cache invalidation, request deduplication)
  - **Base UI + Tailwind CSS** for accessible headless primitives with Tailwind-based styling
  - **`openapi-typescript`** generates TypeScript types (`src/api/schema.ts`) from the FastAPI-generated `/openapi.json` spec at frontend build time; this is the type-safe contract boundary between frontend and backend
  - No dedicated global state management library — streaming and conversation state is managed via custom hooks at the conversation page level
- Routing: React Router or TanStack Router, at the Senior Developer — Frontend's discretion.

### Rationale

The developer's stated reasoning: they know React; the frontend is not the main focus of this project; and the well-trodden path is the right choice for V1. Svelte, SolidJS, and Vue are all credible on technical grounds — the RQ-G4 research found no disqualifying weakness in any of them — but none of them offer a benefit that outweighs the cost of working in an unfamiliar framework on a project whose centre of gravity is backend (LangGraph, memory system, Review Agent).

React 19 + Vite is the most documented combination for the exact patterns AI Council needs: SSE consumption, token accumulation for streaming LLM output, server state caching, and a component library ecosystem. The ecosystem weight reduces the risk of novel integration questions that cannot be resolved from community resources — the same rationale that drove ADR-003 toward FastAPI.

The "not the main focus" framing is load-bearing: the frontend is the surface of a complex backend, and the right V1 choice is the one that minimises frontend-side research cost so that engineering attention stays on the backend. The decision is therefore explicitly conservative and may be revisited post-V1 if the interaction model evolves in a direction that would benefit from a different framework.

### Consequences

- Senior Developer — Frontend plans against React 19 + Vite
- The frontend is served as static assets from a Docker Compose container; it does not require a Node.js runtime in production
- The API contract (forthcoming) must assume a client that can handle SSE with `POST` + body — i.e., `fetch-event-source`-style consumption rather than raw `EventSource`
- The confirmed library stack (SWR, Base UI + Tailwind, openapi-typescript, fetch-event-source) is binding; routing library is at the Senior Developer — Frontend's discretion
- No SSR means no hydration mismatch concerns, no dual-runtime environment, and no Node server in the frontend container

### Options Considered

- **Svelte 5 + SvelteKit (SPA adapter):** smallest bundle, best fine-grained streaming rendering, highest developer-satisfaction scores; rejected because the developer is a React practitioner and this project is not the right one to take on a framework learning curve
- **SolidJS:** top-tier streaming rendering performance via signals; rejected because ecosystem is materially smaller than React's and the hiring/onboarding risk is higher for no benefit the use case actually needs
- **Vue 3 + Vite:** credible mainstream alternative; rejected on the same "well-trodden path" reasoning — no developer familiarity advantage over React
- **HTMX + server templates:** rejected by research (RQ-G4) — streaming token rendering via server round-trip is the wrong architecture; not independently deployable
- **Astro, vanilla JS / Web Components:** rejected by research (RQ-G4) — wrong shape for a stateful interactive SPA

---

## ADR-014 — Streaming Transport

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

The frontend (ADR-013, React 19 + Vite) and backend (ADR-003, FastAPI) must exchange real-time streamed data for every active Conversation: token streaming from Persona/Mentor turns, Orchestrator suggestions arriving mid-turn, system state signals (`busy`/`idle`/`paused`), and exchange-level signals for P2P mode. The client also needs to issue control signals back to the server: send a user message, pause, cancel, resume. The question is which transport carries the server→client stream, and how the client→server signals are delivered. ADR-012 already assumed a single per-Conversation SSE channel carrying multiple named event types; this ADR confirms that choice and its supporting shape.

### Decision

**Server-Sent Events (SSE) over HTTP as the streaming transport, with separate HTTP POST endpoints for client→server control signals.**

- **One long-lived SSE stream per open Conversation:** `GET /conversations/{id}/stream`
- **Client library:** `@microsoft/fetch-event-source` on the React client. It handles `POST` bodies, custom headers, and transparent reconnection — capabilities the native `EventSource` API lacks
- **Named SSE event types carried on the stream:**
  - `token` — incremental token from the current Persona/Mentor response
  - `response_complete` — current response finished
  - `orchestrator_suggestion` — Orchestrator suggestion payload (ADR-012)
  - `busy` — system has begun processing a turn
  - `idle` — system is idle and ready for input
  - `paused` — Conversation has been paused
  - `exchange_paused` — P2P autonomous exchange has been paused (distinct from Conversation pause)
- **Client→server signals as separate HTTP POST endpoints:**
  - `POST /conversations/{id}/messages` — send a user message
  - `POST /conversations/{id}/pause`
  - `POST /conversations/{id}/cancel`
  - `POST /conversations/{id}/resume`
- **Backend implementation:** FastAPI `StreamingResponse` + `sse-starlette` (already chosen in ADR-003). `graph.stream()` output from the LangGraph conversation graph maps directly onto the named SSE events — each graph event type corresponds to an SSE event type
- **Reconnection:** native `Last-Event-ID` header handling provided by `@microsoft/fetch-event-source`, paired with server-side event-ID assignment, gives resilient reconnection without additional protocol design
- **Multi-Persona responses (Round-Robin, P2P):** sequential within the same Conversation stream. A single Conversation has one active stream; successive Persona responses in Round-Robin or P2P mode are emitted in order on that stream — there is no parallel-response transport in V1

### Rationale

The developer's stated reasoning: they have not previously worked with SSE or WebSockets, so the simpler option is preferable. SSE is the simpler option for this application's needs because the transport is asymmetric — the server streams continuously, the client issues occasional discrete signals — which matches HTTP+SSE's native shape. Adding a second, symmetric protocol (WebSocket) for a traffic pattern that is not symmetric introduces complexity with no corresponding benefit.

SSE over HTTP also inherits the existing HTTP stack: authentication headers, request tracing, logging, reverse proxy configuration, and standard status codes all apply without protocol-specific plumbing. Control signals as ordinary `POST` endpoints means they are visible in the OpenAPI spec (ADR-003) and testable with standard HTTP tooling.

The ADR-012 decision already assumed a single multiplexed SSE channel carrying multiple named event types; confirming SSE here keeps that assumption intact rather than retrofitting a different transport.

### Consequences

- The API contract must document each named SSE event type and its payload schema
- `@microsoft/fetch-event-source` is the required SSE client library on the frontend (`EventSource` is insufficient)
- Server-side event-ID assignment is required to support `Last-Event-ID` reconnection
- Backend emits a single SSE stream per open Conversation; concurrent open Conversations = concurrent streams (one per)
- P2P and Round-Robin responses are strictly sequential on the stream in V1 — parallel Persona response streaming is explicitly out of scope
- No WebSocket infrastructure, no sticky-session requirements for bidirectional upgrade

### Options Considered

- **WebSocket (bidirectional):** full-duplex single connection; appropriate when client and server both push frequent independent messages. Rejected because AI Council's traffic pattern is asymmetric (server streams, client signals occasionally) and the developer is unfamiliar with both SSE and WebSockets — the simpler transport is the right default
- **Long-polling / HTTP chunked without SSE framing:** re-implements SSE badly; no reconnection semantics; no named event types without custom framing. Rejected
- **Per-event-type separate SSE streams:** one stream for tokens, one for orchestrator, etc. Rejected because coordinating multiple streams across a single logical Conversation adds complexity without benefit — named event types on one stream is the documented SSE pattern

**Source:** Resolved in Head of Development phase, 2026-04-20. Addresses Decision #13 (Streaming transport) from the ADR roadmap and the FR-2.3 / FR-5.x Architectural Flags.

---

## ADR-015 — Configuration and Secrets Management

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

AI Council runs as a Docker Compose stack (ADR-005) with a Python/FastAPI backend (ADR-003) and a React/Vite frontend (ADR-013). Configuration values span model endpoints and API keys (FR-21.2), the database URL, the Review Agent cron schedule, the Orchestrator frequency gate, and frontend values such as the API base URL and feature flags. The Infrastructure as Configuration principle requires that swapping a local LLM for a cloud API, or changing any environment-specific value, is a configuration change only — no code change. Secrets must be gitignored; non-secret defaults should be committed so the system runs with minimal per-developer setup.

### Decision

**A custom, symmetric layered-configuration approach using Dynaconf + Pydantic on the backend and nconf + Zod on the frontend, with JSON as the file format throughout and Docker Compose volume mounts for local overrides.**

**Backend:**

- **Dynaconf** as the configuration loader, using **JSON** file format (Dynaconf supports JSON natively — TOML is not used here)
- **Pydantic** validates the loaded configuration into typed models. This mirrors a pattern the developer has used successfully on a prior Python project.
- **Base config:** `backend/config.json` — checked into the repository; contains safe, non-secret defaults
- **Local override:** `backend/config.override.json` — gitignored; mounted into the backend container via a Docker Compose volume so it transparently overrides the base config at runtime

**Frontend:**

- **nconf** as the configuration loader, using **JSON** file format
- **Zod** validates the loaded configuration — mirrors the Pydantic role on the backend; symmetric validation is a deliberate design choice so both sides of the system have equivalent type-safe config parsing
- **Base config:** `frontend/config.json` — checked into the repository; contains safe, non-secret defaults
- **Local override:** `frontend/config.override.json` — gitignored; mounted into the frontend container via a Docker Compose volume

**Format:** JSON is the single configuration file format across the whole system. No TOML, YAML, or INI files for application configuration.

**Override mechanism:** Docker Compose volume mounts. Each `config.override.json` is mounted at the expected path inside its container when present, so the loader (Dynaconf or nconf) reads it automatically and overrides base values.

**Shared keys:** By default the backend and frontend configuration files are independent — they define different keys for different concerns. Any key that must agree across both (for example API base URL, or feature flags that both sides consult) must be explicitly documented in a shared reference document (location TBD during implementation) so the values can be kept in sync manually. This documentation requirement is a named consequence of this ADR rather than a loader-enforced mechanism.

### Rationale

- The developer has prior successful experience with Dynaconf + Pydantic in Python and finds the pattern ergonomic; choosing it here reduces learning cost and leverages a known good path.
- A single file format (JSON) across backend and frontend avoids the cognitive tax of switching between TOML, YAML, and JSON. JSON is a first-class format in both Dynaconf and nconf.
- Symmetric validation (Pydantic on the backend, Zod on the frontend) means type-safety and clear failure messages are present on both sides of the system — neither side silently accepts malformed config.
- Docker Compose volume mounts for overrides keep the override mechanism consistent with the deployment model (ADR-005) — no environment-variable sprawl, no bespoke `.env` parsing, no per-developer onboarding beyond creating a `config.override.json`.
- Splitting base (`config.json`, committed) from local override (`config.override.json`, gitignored) delivers the Infrastructure as Configuration goal: the system runs out-of-the-box with safe defaults, and any secret or environment-specific value is a file change, not a code change. The cloud deployment path replaces the volume-mounted override file with whatever the target environment provides (secrets manager, orchestrator-mounted file, env vars) with no application code change.
- The decision to manage shared keys by documentation rather than a shared loader keeps the two codebases independent and avoids introducing a third, cross-cutting config artefact. The tradeoff (manual sync) is acceptable for a single-developer V1.

### Consequences

- `backend/config.override.json` and `frontend/config.override.json` are gitignored; `backend/config.json` and `frontend/config.json` are committed.
- Docker Compose mounts the local override files as volumes into their respective containers when those files are present.
- Secrets (model API keys, database passwords, any future cloud credentials) live only in `config.override.json` or in environment variables — never in `config.json`. Committed base files must contain no secret values.
- Any key present in both `backend/config.json` and `frontend/config.json` must be listed in a shared reference document (location TBD during implementation) with a note that it must be kept in sync manually across the two files.
- The backend uses Dynaconf + Pydantic; the frontend uses nconf + Zod. Both sides load config at startup, validate it, and fail fast on malformed configuration.
- JSON is the only configuration file format in the project. New configuration sources added later (for example a cloud secrets manager) plug in as additional layers beneath the same loader API — application code does not change.

### Options Considered

This decision supersedes three earlier-presented options (pydantic-settings alone, Dynaconf alone with TOML, and a pure env-var approach). They were considered and rejected in favour of the custom Dynaconf+Pydantic / nconf+Zod approach described above, because:

- **pydantic-settings alone:** lacks native JSON-file-as-first-class-source support and does not extend symmetrically to the frontend.
- **Dynaconf with TOML:** the developer prefers JSON over TOML for consistency with the frontend and with their prior experience.
- **Pure environment variables (no config files):** scales poorly for the number of configuration values the system has; no symmetric frontend story; defaults cannot be committed.

**Source:** Resolved in Head of Development phase, 2026-04-20. Addresses Decision #14 (Configuration and secrets management) from the ADR roadmap and NFR-3 / FR-21.2 Architectural Flags.

---

## ADR-016 — Multi-user Readiness Scaffolding

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

NFR-8 requires that `user_id` be present on every Workspace-scoped entity from day one, even though V1 has only a single local user and no authentication. The question is how much of the multi-user machinery to build now versus defer. Two risks pull in opposite directions: over-building a full auth system before it is needed (wasted work, premature complexity), and under-scaffolding such that adding real auth later requires touching every service and every table (hidden cost materialising at the worst time). ADR-007 already committed to a `workspace_id` `ContextVar` pattern populated by FastAPI middleware and set explicitly by background jobs; the resolution for `user_id` must be symmetric with that pattern so there is a single mental model for both isolation dimensions.

### Decision

**A seeded `users` table with real foreign-key integrity from day one, plus an authentication-stub `CurrentUserMiddleware` that resolves the current user per request and sets a `current_user_id` `ContextVar` — mirroring the ADR-007 `workspace_id` pattern exactly.**

**`users` table (initial Alembic migration):**

- Columns: `(id UUID PRIMARY KEY, email TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL)`
- Seed row inserted in the same initial migration:
  - `id = DEFAULT_USER_ID` where `DEFAULT_USER_ID = '00000000-0000-7000-8000-000000000001'`
  - `email = 'local@localhost'`
  - `created_at = <migration timestamp>`

**Foreign-key integrity:**

- Every `user_id` column on every table is a real `FOREIGN KEY REFERENCES users(id)` constraint from day one — not a "future FK" noted in a comment, not a nullable column, not a detached UUID
- `WorkspaceScopedMixin` and `UserScopedMixin` (ADR-007) produce NOT NULL FK columns; referential integrity is enforced by the database

**`CurrentUserMiddleware` (FastAPI middleware):**

- Runs on every HTTP request before route handlers
- Resolves the current user via a `resolve_current_user()` function and sets `current_user_id` in a module-level `ContextVar`
- V1 implementation of `resolve_current_user()` is a single line returning `DEFAULT_USER_ID` — no JWT parsing, no session lookup, no database round-trip
- The middleware, the `ContextVar`, and the resolver function are introduced as distinct artefacts from day one; only the resolver body is a stub

**Background jobs:**

- Background jobs (Review Agent sweep per ADR-011, async Episodic→Semantic promotion per ADR-010, APScheduler jobs) set `current_user_id` explicitly at task start — same pattern as the `workspace_id` `ContextVar` set by background jobs in ADR-007

**Symmetry with ADR-007:**

- Two `ContextVar`s — `current_workspace_id` (ADR-007) and `current_user_id` (this ADR) — set by the same two mechanisms: FastAPI middleware per request; background jobs at task start
- One mental model covers both isolation dimensions

**Future auth upgrade path:**

- Replacing `resolve_current_user()`'s body with a real JWT/session implementation is the only change required
- The middleware, the `ContextVar`, the FK constraints, the mixins, the ORM scoping listener (ADR-007), and every application call site are unchanged
- Adding a `user_email`, `user_password_hash`, or provider-specific columns is an additive Alembic migration; no existing column changes type or nullability

### Rationale

- **Real FK integrity from day one eliminates a class of bugs that are invisible in V1.** A dangling `user_id` that points at nothing is caught immediately by the database rather than surfacing months later when auth is added. The cost is a single seed row in the initial migration.
- **Symmetry with ADR-007 is load-bearing.** Having `workspace_id` use a `ContextVar`+middleware pattern while `user_id` uses a different pattern would create two mental models for the same concern (request-scoped isolation state) and double the surface where a new developer — or the developer returning to this code in six months — has to check which mechanism applies.
- **The resolver-body-only swap makes the auth upgrade genuinely additive.** The alternative (introducing middleware and a `ContextVar` at the point real auth is added) means every call site has to be audited to confirm it reads from the `ContextVar` rather than accepting `user_id` as a parameter. Building the pattern now forces call sites into the correct shape from day one.
- **The cost is trivial.** The seed row, the middleware, the `ContextVar`, and the one-line resolver together add perhaps 30 LOC. The schema already had `user_id` columns (NFR-8); the change is making them real FKs rather than loose UUIDs.
- The developer explicitly framed the decision in terms of this scaffolding pattern — the question presented was whether to commit to it, and the answer was yes.

### Consequences

- The initial Alembic migration creates the `users` table and inserts the seeded `DEFAULT_USER_ID` row before any other table that references it
- All tables bearing `user_id` declare a real FK to `users(id)` from day one; no nullable `user_id` columns on Workspace-scoped entities
- `DEFAULT_USER_ID` is defined as a named constant in backend code (`00000000-0000-7000-8000-000000000001`) and used wherever the V1 resolver or tests need to produce a user reference
- `CurrentUserMiddleware` is registered in the FastAPI application alongside any existing middleware (including the ADR-007 workspace middleware); both middlewares run on every request
- Background job harnesses (Review Agent, Mentor promotion, APScheduler jobs) must set both `current_workspace_id` and `current_user_id` `ContextVar`s at task start; this is a shared precondition for entering any scoped application code
- Future auth upgrade is a single-file change to the resolver body plus an additive migration for any new user columns; no call-site refactor, no constraint changes
- Tests that exercise scoped queries can set the `ContextVar` explicitly via a test fixture; the same fixture works for both `workspace_id` and `user_id`

### Options Considered

- **Option A — `user_id` columns with no FK, no seed row, no middleware:** minimum V1 scaffolding; `user_id` is a loose UUID written as a constant at each call site. Rejected: every call site becomes an audit point when real auth is added; no referential integrity protection; asymmetric with ADR-007.
- **Option B (chosen) — Seeded `users` table with real FK + `CurrentUserMiddleware` + `ContextVar`, auth-stub resolver:** real integrity from day one; symmetric with ADR-007; future auth upgrade is a resolver-body swap.
- **Option C — Full auth system (JWT, sessions, password hashing, login flow) in V1:** maximum future-proofing but builds machinery for a user base that does not exist in V1. Rejected as disproportionate — V1 is explicitly single-user and local-first (NFR-3, ADR-005).

**Source:** Resolved in Head of Development phase, 2026-04-20. Addresses Decision #16 (Multi-user readiness scaffolding) from the ADR roadmap and NFR-8.

---

## ADR-017 — P2P Turn-Taking and Throttling

**Date:** 2026-04-20
**Status:** Decided
**Decider:** Developer

### Context

FR-5.x specifies a Peer-to-Peer (P2P) conversation mode in which two or more Personas respond to each other autonomously without per-turn user input, until the user intervenes or a terminating condition is reached. This mode is the highest-risk interaction pattern in AI Council: an unbounded loop of LLM-to-LLM turns could burn cost indefinitely, collapse into repetitive exchanges, and — in the worst case — run away if left unattended. ADR-001 (LangGraph) and ADR-014 (SSE + HTTP POST control signals) establish the primitives available for sequencing turns and surfacing user-initiated pause/resume/cancel. This ADR decides how P2P turn termination, speaker selection, and mid-exchange control are structured so the behaviour is bounded, responsive, and recoverable.

### Decision

**Turn termination (always-on, layered — every mechanism runs on every P2P turn):**

- A `p2p_turn_count` counter lives in LangGraph conversation state and increments on each autonomous Persona turn within the exchange.
- `MAX_P2P_TURNS` is a configurable hard cap read from an environment variable. When `p2p_turn_count` reaches `MAX_P2P_TURNS`, the conversation graph routes to the `await_user` state; no further autonomous turns fire until the user re-engages.
- `P2P_TURN_DELAY_SECONDS` is a configurable minimum delay between turns, read from an environment variable. The graph awaits this delay at each turn boundary before selecting the next speaker. This prevents runaway LLM chaining and gives pause/cancel signals a reliable window in which to land.
- **Repetition-hash throttle:** each Persona response is hashed and compared against a rolling window of the last N responses (default `N = 5`). If the new response is a near-exact match to any response in the window, the graph routes to `await_user` with a `repetition_detected` reason, before the hard cap fires. This is an O(1) check that requires zero additional LLM calls and catches collapsed "I agree" / "indeed" loops early.

**Speaker selection (primary + fallback):**

- **Primary — addressability:** the just-completed Persona response is scanned (regex) for the name of another active Persona in the Conversation. If a match is found, that Persona is selected as the next speaker. This preserves natural conversational flow when Personas use each other's names.
- **Fallback — round-robin:** when no addressability match is found, the graph falls back to a round-robin cycle among the active Personas, deterministically advancing to the next Persona in the participant list.

**Pause / resume / cancel (shared with ADR-001 and ADR-014):**

- `POST /conversations/{id}/pause` writes `pause_requested = true` into the LangGraph conversation state via the checkpointer. At the next turn boundary, the graph's conditional edge observes the flag and routes to `await_user`, emitting an `exchange_paused` SSE event (ADR-014).
- `POST /conversations/{id}/resume` clears the `pause_requested` flag and is used **only for user-initiated pauses**. Because LangGraph persists state via the checkpointer (ADR-001), the graph resumes from the last checkpoint — this survives process restarts.
- `POST /conversations/{id}/cancel` ends the autonomous exchange outright; the graph transitions to an `idle` state and no further autonomous turns fire until a new exchange is initiated.
- **`exchange_paused` payload:** the SSE event carries a `pause_reason` field — one of `"user_pause"`, `"turn_cap"`, or `"repetition_detected"` — so the frontend can display an appropriate message to the user.
- **Turn-cap and repetition recovery:** when the exchange pauses due to the hard cap or a repetition detection, recovery is via `POST /conversations/{id}/messages`. The user sends a message (even just "continue" for the cap case, or a steering prompt for repetition); the `await_user` node resets the relevant counter (`p2p_turn_count` to 0, or the repetition-hash window) and resumes the exchange. No separate `resume` or `continue` endpoint is needed for these cases.
- **Orchestrator interaction:** the Orchestrator post-message hook (ADR-012) continues to run after each Persona turn during the exchange. `orchestrator_suggestion` SSE events surface on the Conversation's stream but do not interrupt or reorder the P2P turn flow — the exchange proceeds until pause, cancel, hard cap, or repetition-hash throttle.

### Rationale

- **Defence in depth is the right shape for an autonomous loop.** Any single termination mechanism is insufficient: a hard cap alone allows long stretches of collapsed repetition before firing; a repetition throttle alone cannot bound total cost if Personas keep generating superficially-different output; a delay alone does not stop anything. Stacking all three means the exchange is bounded by cost, bounded by quality, and responsive to user control signals — independently.
- **The repetition-hash throttle is cheap and catches the most common failure mode.** Collapsed P2P exchanges (short polite agreement loops) are the single most common way autonomous multi-agent conversations fail in practice, and they are detectable with a plain rolling-window hash comparison. Catching them before the hard cap preserves budget for genuinely productive exchanges.
- **Addressability with round-robin fallback is robust to arbitrary Persona prompt quality.** When Personas are written to engage each other by name, addressability produces a natural conversational flow. When they are not, round-robin still produces a deterministic, observable, and correct sequence. There is no hidden failure mode where speaker selection deadlocks.
- **Flag-based pause/resume/cancel via the checkpointer is the simplest realisation of ADR-001's primitives.** LangGraph's checkpointer already persists state across restarts. Writing a flag into that state and checking it at turn boundaries uses the existing mechanism rather than adding a sidechannel. The HTTP POST endpoints are symmetric with the other control signals defined in ADR-014, so the frontend has a single mental model for Conversation-level control.
- **Orchestrator non-interference preserves its "soft suggester" role.** The Orchestrator was established in ADR-012 as a suggester that never changes turn order; keeping its output on the SSE channel but out of the P2P turn-selection path maintains that contract during autonomous exchanges.

### Consequences

- `p2p_turn_count`, the rolling response hash window, and `pause_requested` are all fields on the LangGraph conversation state and persist via the checkpointer (ADR-001). The initial state shape must account for this.
- `MAX_P2P_TURNS` and `P2P_TURN_DELAY_SECONDS` are environment variables loaded via the configuration mechanism in ADR-015. Sensible defaults must be set in `backend/config.json`.
- The API contract (forthcoming) must document the `exchange_paused` SSE event payload (including `pause_reason`), the semantics of `POST /conversations/{id}/pause` / `resume` / `cancel` during an active P2P exchange, and the message-based recovery path for turn-cap and repetition-detected states.
- **Addressability requires Persona System Prompts that reference each other by name to be effective.** If prompts are generic and never mention other Personas, the round-robin fallback fires on every turn. This is acceptable behaviour — round-robin produces a coherent conversation — and is not a failure mode to design around; it is a property of the Persona authorship, not of the system.
- **The repetition-hash threshold should be a configurable similarity threshold, not a binary hash-equality check.** Minor paraphrasing ("I agree" vs "I agree completely") should still be detected. The specific similarity algorithm and threshold value are implementation details for the Senior Developer — Backend to finalise, but the configuration surface must exist from day one.
- **Option C (LLM progress check every N turns) remains a future upgrade path.** The conditional edge at the turn boundary already branches on multiple signals (turn count, repetition hash, pause flag); adding a fourth branch that calls `ModelGateway.invoke_structured` with a "is this exchange still productive?" prompt is a localised change. It is not warranted in V1 because the three mechanisms in this ADR cover the current failure modes at near-zero cost, whereas an LLM progress check adds both cost and latency.
- Cancelling a P2P exchange does not delete the messages produced so far — those remain persisted as ordinary messages on the Conversation. Cancel ends the autonomous loop only.

### Options Considered

- **Option A — Single mechanism: hard turn cap only.** Simplest possible implementation; one counter, one branch. Rejected: allows long stretches of collapsed repetition before firing; no responsiveness to quality degradation; no rate control.
- **Option B (chosen) — Layered: hard cap + configurable delay + repetition-hash throttle + addressability with round-robin fallback + checkpointer-flag pause/resume/cancel.** Defence in depth; each mechanism is cheap; all primitives already present in ADR-001 / ADR-014.
- **Option C — Option B plus an LLM progress check every N turns.** Adds an LLM call that judges whether the exchange is still productive. Rejected for V1 on cost and latency grounds — the three throttle mechanisms in Option B already catch the dominant failure modes without additional LLM calls. Explicitly retained as a future upgrade path because the conditional-edge architecture makes adding a fourth branch straightforward.

**Source:** Resolved in Head of Development phase, 2026-04-20. Addresses Decision #17 (P2P turn-taking and throttling) from the ADR roadmap and the FR-5.3 Architectural Flag.

---
