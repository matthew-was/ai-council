# Architecture

**Status:** Approved
**Date produced:** 2026-04-23
**Source:** Synthesised from `documentation/decisions/architecture-decisions.md` (ADR-001 through ADR-017)

---

## 1. Overview

AI Council is a self-hosted web application that lets a single user simulate advisory conversations with user-created Personas, organise them into Workspaces, and accumulate long-term context through a dedicated Mentor with a three-layer memory system. A nightly Review Agent analyses concluded Conversations and proposes improvements to each Persona's System Prompt; a background Orchestrator suggests Personas mid-conversation but never adds them automatically. A Conversation Observer runs fire-and-forget at conversation end to produce communication-pattern observations for the Mentor's episodic memory, giving the Mentor awareness of non-Mentor Conversations without duplicating the Review Agent's Persona-focused analysis.

The architecture is shaped by three load-bearing requirements: the AI model integration must be swappable between a local LLM and a cloud API by configuration alone (Infrastructure as Configuration); every Workspace-scoped entity must be unreachable from any other Workspace; and the system must run locally with no cloud dependency in V1 while remaining straightforward to lift into a cloud environment later. These constraints drive the choice of LangChain + LangGraph as the agentic framework (with a deliberately narrow `ConversationOrchestrator` containment boundary), a two-tier model abstraction, and a Docker Compose deployment model that uses the same compose file for local and V1 production.

The system is a backend-heavy application. The frontend is intentionally a conservative React 19 + Vite SPA so that engineering attention stays on the conversation graph, the memory system, the Review Agent, and the model abstraction — not on framework experimentation.

---

## 2. Tech Stack

| Component | Technology | ADR |
| --- | --- | --- |
| Backend language | Python 3.12+ | ADR-001 |
| Agentic framework | LangChain v1.0+ and LangGraph (stable) | ADR-001 |
| Web framework | FastAPI (Starlette + Pydantic v2) | ADR-003 |
| Server-side streaming | `sse-starlette` over `StreamingResponse` | ADR-003, ADR-014 |
| Background jobs | APScheduler `AsyncIOScheduler` (in-process) | ADR-003, ADR-011 |
| Database | PostgreSQL | ADR-004 |
| ORM | SQLAlchemy 2.x async (`asyncpg` driver) | ADR-004 |
| Migrations | Alembic | ADR-004 |
| LangGraph state persistence | `PostgresSaver` checkpointer | ADR-004, ADR-001 |
| Backend config loader | Dynaconf (JSON file source) | ADR-015 |
| Backend config validation | Pydantic | ADR-015 |
| Frontend framework | React 19 + Vite (SPA, no SSR) | ADR-013 |
| Frontend SSE client | `@microsoft/fetch-event-source` | ADR-013, ADR-014 |
| Frontend server-state cache | SWR | ADR-013 |
| Frontend component library | Base UI + Tailwind CSS | ADR-013 |
| Frontend API types | `openapi-typescript` (generated from `/openapi.json`) | ADR-013 |
| Frontend config loader | nconf (JSON file source) | ADR-015 |
| Frontend config validation | Zod | ADR-015 |
| Deployment | Docker Compose (`docker compose up`) | ADR-005 |
| Configuration file format | JSON (everywhere) | ADR-015 |

---

## 3. Key Architectural Principles

These rules govern the entire codebase. Any code that violates one of them must be flagged in code review and either corrected or escalated.

### 3.1 Infrastructure as Configuration (hard constraint)

Every external service — most importantly the AI model — is accessed through an interface. The concrete implementation is selected by configuration at runtime. Application code never branches on environment name and never references provider names, model names, or endpoints directly. See `documentation/process/development-principles.md` for the full statement and ADR-002, ADR-015 for the realisations.

### 3.2 Keep simple things simple

Stated by the developer during ADR-003 and applied throughout: "the core system will be complex enough — keep what can be simple, as simple." Where two solutions both meet a requirement, prefer the one with fewer moving parts. This principle is the explicit reason for choosing in-process APScheduler over a Celery/Redis worker stack (ADR-011), no embeddings on Mentor memory in V1 (ADR-009), and SSE over WebSockets (ADR-014).

### 3.3 ModelGateway boundary rule

Only `ModelGateway` itself and the `ConversationOrchestrator` module (including its LangGraph nodes) may import from `langchain.*` or `langgraph.*`. Every other application module imports `ModelGateway`. This rule is documented in `CLAUDE.md` and enforced by code review. Any code that crosses the boundary requires an explicit inline comment stating why. See ADR-001, ADR-002.

### 3.4 Workspace and user isolation by ContextVar + ORM scoping

`workspace_id` and `user_id` are populated into module-level `ContextVar`s by FastAPI middleware on every HTTP request, and explicitly by background jobs at task start. A SQLAlchemy `do_orm_execute` listener injects `WHERE workspace_id = current` into every SELECT against tables that inherit `WorkspaceScopedMixin`. All raw SQL must include an explicit predicate and an inline comment confirming it. See ADR-007, ADR-016.

### 3.5 Multi-user readiness from day one

`user_id` is a real foreign key to a `users` table on every Workspace-scoped table from the initial migration — not a loose UUID, not a future FK noted in a comment. A seeded `DEFAULT_USER_ID = '00000000-0000-7000-8000-000000000001'` row provides referential integrity in V1; a `CurrentUserMiddleware` resolves the request user via a stub function whose body is the only thing that needs to change when real auth is added. See ADR-016.

### 3.6 Persona snapshots are immutable provenance

A running Conversation operates against frozen snapshots of each participating Persona's Name, System Prompt, and Temperature, captured into the `conversation_personas` table at the moment the Persona joins. Edits to the underlying Persona never retroactively alter a Conversation. Context assembly always reads from `conversation_personas`, never from `personas` directly. See ADR-006.

### 3.7 Configuration is the single change vector for environment differences

Base config (`backend/config.json`, `frontend/config.json`) is committed and contains only safe, non-secret defaults. Local overrides (`backend/config.override.json`, `frontend/config.override.json`) are gitignored and mounted into containers via Docker Compose volumes. Secrets live only in the local override or in environment variables. See ADR-015.

---

## 4. System Components

### 4.1 ConversationOrchestrator (LangGraph graph)

The internal abstraction (~200–400 LOC) that contains all LangChain/LangGraph use related to multi-Persona conversation flow. Owns the LangGraph graph definition, the `interrupt()` + checkpointer-based pause/resume, the `@Orchestrator` post-message hook node, the P2P turn-taking conditional edges (turn count, repetition hash, pause flag), and the bridge from `graph.stream()` events to named SSE events. Code outside this module does not import from `langgraph.*`. See ADR-001, ADR-012, ADR-017.

### 4.2 ModelGateway

The single application-layer façade for model calls outside the conversation graph. Exposes four methods — `invoke`, `stream`, `invoke_structured`, `embed` — each accepting a `purpose: str` for retry/timeout/observability dispatch. Owns the configured `BaseChatModel` instance and centralises retry policy. Injected via FastAPI `Depends()`. Used by: auto-naming, context compression, Orchestrator suggestions, Review Agent findings, Mentor memory promotion, speaker selection, loop detection, future Semantic Memory retrieval. See ADR-002.

### 4.3 FastAPI application layer

HTTP API surface. Hosts Conversation REST endpoints, the SSE streaming endpoint per Conversation, control-signal endpoints (`pause` / `resume` / `cancel` / send message), Persona CRUD, Workspace CRUD, Documents (Reports), Review Agent endpoints (including `POST /review-agent/run`), and the Mentor Memory Inspector queries. Uses dependency injection for `ModelGateway` and `ConversationOrchestrator` as separate collaborators. FastAPI auto-generates an OpenAPI spec at `/openapi.json`; the human-readable API contract (`documentation/tasks/api-contract.md`) is the source of truth. The frontend build runs `openapi-typescript` against the spec to generate TypeScript types (`src/api/schema.ts`), providing a type-safe contract boundary between the two services. See ADR-003, ADR-013.

**Persona deletion enforcement.** The DELETE Persona handler performs an application-layer check (not a DB constraint, which cannot return meaningful error context). The check queries `conversation_personas` for rows where `left_at IS NULL` joined to `conversations` where `status = 'active'` for the given `persona_id`; if any such rows exist, the handler returns a 409 with the blocking Conversation IDs and titles. See also Section 5.2.

**Empty Conversation delete on End.** The `POST /conversations/{id}/end` handler first queries `messages` for any rows with `role IN ('user', 'persona', 'mentor')` for that Conversation. System messages (`role = 'system'`, e.g. join/leave events) are excluded — a Conversation containing only system messages is still considered empty. If no qualifying messages exist, the handler performs a full cascade delete: `messages`, `conversation_personas`, `conversation_summaries`, the `conversations` row itself, and the LangGraph checkpointer state for that thread. If qualifying messages exist, the normal end-of-conversation flow proceeds (set `status='ended'`, set `ended_at`, trigger async auto-summary).

### 4.4 PostgreSQL + SQLAlchemy data layer

Single Postgres instance (Docker Compose service) hosts all application tables and the LangGraph `PostgresSaver` checkpointer. SQLAlchemy 2.x async with `asyncpg`. Alembic for migrations. Mixins (`UserScopedMixin`, `WorkspaceScopedMixin`) enforce isolation at the schema and ORM level. Postgres capabilities held in reserve: JSONB + GIN, Row-Level Security, pgvector. See ADR-004, ADR-007.

### 4.5 APScheduler jobs

In-process `AsyncIOScheduler` started in the FastAPI lifespan context manager. Runs:

- **Review Agent** — single `CronTrigger` job, schedule read from `REVIEW_AGENT_SCHEDULE` key in backend config (env var override supported); `max_instances=1`, `coalesce=True`. Coordinates with the `review_agent_runs` row-lock.
- **Async Mentor Episodic→Semantic promotion** — schedule-driven only (see Section 8).
- **Conversation Observer** — fire-and-forget task spawned at conversation end. Writes communication-pattern observations to `mentor_episodic_memories`. No scheduler entry; invoked directly from the `POST /conversations/{id}/end` handler after the auto-summary completes. See Section 9.4.

All scheduled job paths set `current_workspace_id` and `current_user_id` `ContextVar`s explicitly at task start. The Conversation Observer sets these from the concluded Conversation's `workspace_id` and `user_id`. See ADR-011, ADR-010, ADR-016.

### 4.6 React frontend

Single-page application. Vite-built static `/dist` bundle served by a minimal static-file container. Consumes the FastAPI REST endpoints for CRUD, the SSE stream per open Conversation for token streaming and orchestrator events, and HTTP POST for control signals. No SSR. See ADR-013, ADR-014.

### 4.7 Docker Compose deployment

Three services (canonical V1 set): `backend` (FastAPI + APScheduler), `frontend` (static-file server), `postgres` (database). Optional `ollama` may be added or run externally. The same compose file serves local development and V1 production with environment-variable overrides. Local config overrides are mounted via volumes. See ADR-005.

---

## 5. Data Model

This is a conceptual map of the core entities. Field lists are illustrative; the full schema is owned by the initial Alembic migration.

### 5.1 Identity tables

- **`users`** — `(id UUID PK, email TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL)`. Seeded with `DEFAULT_USER_ID` in the initial migration. Every `user_id` column is a real FK here. See ADR-016.
- **`workspaces`** — `(id UUID PK, user_id FK→users, name, created_at, ...)`. Top-level isolation boundary.

### 5.2 Persona and snapshot tables (ADR-006)

- **`personas`** — current live Persona state. `(id UUID PK, workspace_id FK, user_id FK, name, system_prompt, temperature, description, is_mentor BOOL, created_at, updated_at)`.
- **`persona_system_prompt_versions`** — append-only history of System Prompt edits. `(id, persona_id FK, system_prompt, created_at)`. Universal versioning rule: **any** write to `personas.system_prompt` — whether via the PATCH Persona endpoint, Review Agent finding application, or interactive consultation-mode application — must insert a corresponding `persona_system_prompt_versions` row in the same transaction. Supports the future Persona version-history UI (FR-23.1).
- **`conversation_personas`** — per-Conversation participation snapshots. `(id, conversation_id FK, persona_id FK nullable, joined_at, snapshot_name, snapshot_system_prompt, snapshot_temperature, left_at nullable)`. Multiple rows per `(conversation_id, persona_id)` pair are valid; the most recent `joined_at` is the active snapshot. No FK from this table into `persona_system_prompt_versions` — snapshot text is stored directly so a Persona deletion does not corrupt snapshots.

**Canonical "active participants" query.** For a given `conversation_id`, the active participants are obtained by selecting the most recent `joined_at` row per `persona_id` **where `left_at IS NULL`**. All queries for current participants must follow this pattern. Without the `left_at IS NULL` filter, a Persona that has been removed (its most recent row has `left_at` set) would still have the most recent `joined_at` and would incorrectly appear as an active participant.

**Persona deletion enforcement.** A Persona may not be deleted while it is an active participant in any open Conversation. The DELETE Persona handler queries `conversation_personas` for rows where `left_at IS NULL` joined to `conversations` where `status = 'active'` for the given `persona_id`; if any exist, the handler returns 409 with the blocking Conversation IDs and titles. This is an application-layer check, not a DB constraint, so meaningful error context can be returned. See Section 4.3.

### 5.3 Conversation tables

- **`conversations`** — `(id, workspace_id FK, user_id FK, title, mode ENUM(one_to_one|round_robin|p2p), status ENUM(active|ended), context_panel TEXT, folder_id FK nullable, pinned_at TIMESTAMPTZ nullable, created_at, ended_at nullable, ...)`. Additional fields:
  - `auto_summary JSONB NULLABLE` — structured end-of-conversation summary (`key_takeaways`, `points_of_agreement`, `points_of_disagreement`, `action_items`); populated async after `POST /conversations/{id}/end`; null until generated.
  - `last_message_at TIMESTAMPTZ NULLABLE` — updated on every new message; used for sidebar ordering and for Mentor chapter detection (calendar-day comparison on Mentor Conversation load).
  - `is_mentor_conversation BOOL NOT NULL DEFAULT false` — persisted column, set once at insert time when the Mentor Conversation is created and never changed thereafter (consistent with how `is_mentor` is handled on `personas`). The API contract exposes this as a field on all conversation responses.
- **`folders`** — `(id, workspace_id FK, user_id FK, name, created_at)`.
- **`messages`** — `(id, conversation_id FK, conversation_persona_id FK nullable for user/system messages, role ENUM(user|persona|mentor|system), content TEXT, created_at, ...)`. Each Persona message points at the `conversation_personas` row that was active when it was generated. Additional field:
  - `message_subtype TEXT NULLABLE` — discriminator for system messages (values: `persona_joined`, `persona_left`, `chapter_boundary`, `orchestrator_suggestion_accepted`, `mode_changed`); null for user and persona messages.
- **`conversation_summaries`** — one row per Conversation, updated in place. `(id, conversation_id FK UNIQUE, rolling_summary TEXT, updated_at)`. Holds the rolling summary used by context window management (Section 7). **Internal-only table — its contents are never returned in API responses.** The end-of-conversation user-facing summary is the structured `conversations.auto_summary` field (above), which is a distinct concern.

### 5.4 Mentor memory tables (ADR-009)

- **`mentor_episodic_memories`** — `(id, workspace_id, user_id, mentor_persona_id FK, sequence_number INT, summary_text, source_type ENUM(self|observed), source_conversation_id nullable, created_at, promoted_at nullable, pending_promotion BOOL)`. Sequence-number ordered. The `pending_promotion` flag and `promoted_at` together provide idempotency for the async Episodic→Semantic path. `source_type='self'` means the entry was promoted from the Mentor's own Working Memory; `source_type='observed'` means it was written by the Conversation Observer from a concluded non-Mentor Conversation.
- **`mentor_semantic_memories`** — `(id, workspace_id, user_id, mentor_persona_id FK, title, content_markdown, created_at, updated_at)`. No embedding column in V1; pgvector is the documented upgrade path (Section 8.4).

### 5.5 Review Agent tables (ADR-011)

- **`review_agent_runs`** — `(id, workspace_id, status ENUM(pending|running|complete|failed), started_at, completed_at nullable, error_message nullable)`. Serves as run lock, audit log, and crash-recovery state.
- **`review_agent_findings`** — Persona-specific findings with embedded evidence (FR-15.x). Linked to a Persona; not linked to a Conversation (so Conversation deletion does not affect findings).
  - **Fields:** `id`, `persona_id FK`, `run_id FK nullable` (linking to the generating run), `evidence_text` (quoted conversation excerpt showing the issue), `target_passage TEXT NULLABLE` (the specific excerpt from the current System Prompt to be replaced; null for additive suggestions), `suggestion_text` (the proposed replacement or addition), `status ENUM(active|stale|actioned|dismissed)`, `created_at`, `updated_at`.
  - **Apply mechanism:** the apply endpoint performs a find-and-replace of `target_passage` → `suggestion_text` in `personas.system_prompt`, wrapped in a single transaction with a `persona_system_prompt_versions` insert (per the universal versioning rule in Section 5.2). For additive suggestions (`target_passage IS NULL`), `suggestion_text` is appended to the prompt. The apply endpoint can always assume `target_passage` is valid — the Review Agent guarantees it via the reconciliation step (below).
  - **Staleness on prompt edit:** when `personas.system_prompt` is updated via any path (PATCH endpoint, finding application, or consultation-mode application), the handler checks all `active` findings for that Persona — any whose `target_passage` is no longer present in the new prompt are immediately set to `stale`. The UI renders stale findings distinctly and prompts the user to run the Review Agent to refresh.
  - **Finding lifecycle / reconciliation:** the nightly run and any manual "Run now" trigger include a reconciliation step over existing `active` and `stale` findings — drops a finding if the underlying issue is resolved, or updates `target_passage` and `suggestion_text` to match the current System Prompt if the issue persists. This means the apply endpoint never needs a graceful-failure path for a missing `target_passage`.

### 5.6 Documents

- **`documents`** — system-generated only in V1. `(id, workspace_id FK, user_id FK, type ENUM(report), title, content_markdown, source_conversation_id FK nullable, created_at)`. Additional field:
  - `status ENUM(pending|complete|failed)` — tracks async report generation state; set to `pending` on `POST /documents/generate`; updated on completion or failure.

### 5.7 Orchestrator suggestions

**`orchestrator_suggestions`** — server-side record of each Orchestrator suggestion surfaced to the user. `(id UUID PK, workspace_id FK, conversation_id FK, persona_id FK, suggestion_text TEXT, suggested_at TIMESTAMPTZ, status ENUM(pending|accepted|dismissed))`. The `id` is included in the `orchestrator_suggestion` SSE event payload so the frontend can reference it in the accept/dismiss endpoints. Suppression logic in the Orchestrator node reads from this table to avoid re-suggesting a recently dismissed Persona.

### 5.8 LangGraph checkpointer

Tables created and managed by `PostgresSaver`. Hold per-Conversation graph state including `p2p_turn_count`, the rolling response-hash window, `pause_requested`, `messages_since_last_eval`, and per-thread message history snapshots. These tables are owned by LangGraph; application code does not write to them directly.

### 5.9 UUID generation

All primary key `id` columns use **UUID v7**. UUID v7 is time-ordered (monotonically increasing within a millisecond), which gives B-tree indexes far better locality than UUID v4's random distribution and eliminates page-split churn on insert-heavy tables. It also carries the creation timestamp, so UUIDs are naturally sortable by insertion order without a separate `created_at` index scan. The specific Python library (`uuid.uuid7()` available from Python 3.13, or `uuid-utils` for earlier versions) is confirmed during implementation.

### 5.10 Universal scoping

Every Workspace-scoped table includes `workspace_id` (NOT NULL FK to `workspaces`, indexed) and `user_id` (NOT NULL FK to `users`). The mixins enforce this at declaration time; the ORM listener enforces it at query time.

---

## 6. AI Model Abstraction

### 6.1 Two-tier pattern (ADR-002)

**Tier 1 — `ModelGateway`.** A single class that wraps a configured `BaseChatModel`. Used by every application service that calls a model from outside the conversation graph. Four methods:

| Method | Purpose | Call sites (V1) |
| --- | --- | --- |
| `invoke(messages, *, purpose)` | Single-shot text completion | Auto-naming, context compression |
| `stream(messages, *, purpose)` | Token-streamed completion | Persona/Mentor turns outside the graph (e.g. Test panel — FR-4.8) |
| `invoke_structured(messages, schema, *, purpose)` | Structured output via Pydantic schema | Orchestrator suggestions, Review Agent findings, Mentor Episodic→Semantic promotion, P2P speaker selection, Auto-summary generation (end-of-conversation `ConversationSummary` schema), **Conversation Observer** (`ConversationObservation` schema) |
| `embed(text)` | Embedding vector | Loop detection, future Semantic Memory retrieval |

Note: the `@Orchestrator` targeted summary (see Section 9.2) runs **inside** the `ConversationOrchestrator` LangGraph graph and therefore uses `BaseChatModel` direct — not `ModelGateway`. It is deliberately not listed in the table above.

`ModelGateway` is the sole test seam for application-layer service tests — service tests mock `ModelGateway`, not `BaseChatModel`.

**Tier 2 — `BaseChatModel` direct.** Used only inside `ConversationOrchestrator` LangGraph nodes, via LangGraph's config propagation. The `chat_prompt | model` LCEL pattern and `graph.stream()` token streaming require a real `BaseChatModel`; wrapping it inside the graph would sacrifice the LCEL ergonomics that justify using LangGraph in the first place.

### 6.2 Boundary rule (ADR-002)

Restated from Section 3.3: only `ModelGateway` and `ConversationOrchestrator` (with its graph-node submodules) may import `langchain.*` or `langgraph.*`. The boundary is documented in `CLAUDE.md` and enforced in code review.

### 6.3 Configuration-driven model selection (ADR-015, ADR-002)

The model is selected via configuration through LangChain's `init_chat_model(model=..., model_provider=..., configurable_fields=("model", "model_provider"))`. The `model_provider`, `model`, base URL, API key, and `context_window` come from `backend/config.json` (defaults) and `backend/config.override.json` (overrides). Swapping Ollama for OpenAI is a config change; no application code touches.

---

## 7. Context Window Management

### 7.1 Assembly order (ADR-008)

Every Persona or Mentor turn assembles its prompt in this order, every time:

1. `SystemMessage(snapshot_system_prompt)` from the active `conversation_personas` row — always included in full
2. `SystemMessage(context_panel)` from `conversations.context_panel` — always included in full; FR-20.2 guarantee, never truncated
3. `AIMessage(rolling_summary)` from `conversation_summaries` if a summary exists for the Conversation
4. Last-N verbatim messages from `messages`, fitted into the remaining token budget

For the Mentor, two additional layers (Episodic, Semantic) sit between item 2 and item 3 — see Section 8.

### 7.2 Compression trigger and step (ADR-008)

When the verbatim tail plus rolling summary approaches approximately 75% of `context_window` (read from `ModelConfig`), a compression step runs:

- `ModelGateway.invoke` is called at `temperature=0` with a fold prompt
- The oldest verbatim block is folded into the rolling summary
- The updated summary is persisted to `conversation_summaries` (one row per Conversation, upserted)

Token counting in V1 is approximate (~4 chars per token). Per-provider counters are added when hard budget enforcement is required.

**Auto-naming trigger:** When the Conversation title has not been manually set and a summarisation event occurs — either the first automatic context compression (above) or the first `@Orchestrator` targeted summary, whichever comes first — `ModelGateway.invoke` is called to generate a title from the summary content and the result is persisted to `conversations.title`.

### 7.3 CompressionStrategy interface

The compression step is encapsulated behind a `CompressionStrategy` interface; `RollingSummary` is the only V1 implementation. Future strategies (e.g. hierarchical summarisation) plug in without changes to assembly code.

### 7.4 Context Panel guarantee

The Context Panel is the last element evicted; in practice it is never evicted because the assembly order places it before all message history. The character limit on the Context Panel (FR-7.4, FR-7.5) is enforced at the API layer with the value drawn from configuration.

---

## 8. Mentor Memory System

### 8.1 Three layers (ADR-009)

| Layer | Storage | Defined by |
| --- | --- | --- |
| Working Memory | The Mentor Conversation message history + the rolling summary in `conversation_summaries` | ADR-008 |
| Episodic Memory | `mentor_episodic_memories` table — two source types: `self` (promoted from Working Memory) and `observed` (written by Conversation Observer) | ADR-009 |
| Semantic Memory | `mentor_semantic_memories` table — distilled from both source types via the Episodic→Semantic promotion job | ADR-009 |

Working Memory is not a separate table — it is the same context-window mechanism as any other Conversation, with the Mentor's never-ending Conversation as input. The Memory Inspector (FR-19.x) shows only Episodic and Semantic, grouped by source type.

### 8.2 Mentor turn assembly

For a Mentor turn, the prompt assembly is:

1. `SystemMessage(snapshot_system_prompt)` — **the Mentor is a documented exception to the immutable-snapshot rule.** Because the Mentor's Conversation never ends, freezing a snapshot at "join time" is semantically meaningless. The context assembly code checks `is_mentor_conversation` and, when true, reads `personas.system_prompt` directly rather than from `conversation_personas`. The Mentor has no `conversation_personas` row. The immutable-snapshot rule (Section 3.6) applies only to standard Conversations. Note: per overview.md §8.2, the Mentor's System Prompt defines the coaching character only — the user's background and goals are held in the Context Panel (step 2), not the System Prompt.
2. `SystemMessage(context_panel)` — for the Mentor, this contains the user's standing background, experience, goals, and constraints (see overview.md §8.2). It is otherwise assembled identically to any other Conversation's Context Panel.
3. Episodic entries as `SystemMessage`s, ordered by `sequence_number`. Includes both `source_type='self'` and `source_type='observed'` entries — the Mentor sees all episodic memory regardless of origin.
4. Semantic documents as `SystemMessage`s, ordered by `updated_at DESC`
5. Working Memory (rolling summary + verbatim tail per ADR-008)

The `MentorMemoryRetriever.load_context(workspace_id, mentor_persona_id) -> (episodic, semantic)` interface mediates step 3 and 4. V1 implementation loads all entries.

### 8.3 Promotion paths (ADR-010)

| Path | Trigger | Execution | Idempotency |
| --- | --- | --- | --- |
| Working → Episodic (`source_type='self'`) | Working Memory hits the ADR-008 compression threshold; OR new chapter | Synchronous/inline; runs in the same DB transaction as the compression step; brief pause acceptable | DB transaction |
| Conversation Observer → Episodic (`source_type='observed'`) | Concluded non-Mentor Conversation (fire-and-forget after auto-summary); OR backfill on Mentor creation | Async; LLM call via `ModelGateway.invoke_structured`; DB write in single transaction | `source_conversation_id` uniqueness — one observation per concluded Conversation |
| Episodic → Semantic | Scheduled APScheduler job only (same pattern as the Review Agent); processes all `pending_promotion=True` rows regardless of `source_type` | Async; LLM call outside the DB transaction; DB transaction wraps only the row updates | `pending_promotion` flag + `promoted_at` |

Episodic→Semantic extraction calls `ModelGateway.invoke_structured` at `temperature=0` with input `(episodic_summary_text, list_of_existing_semantic_titles)` and a structured output schema yielding `[{target_document_title, content, mode: new|update}]`. Empty array means no facts to promote. Failure handling: retry 3× with exponential backoff; on final failure retire the Episodic row (set `promoted_at`), log `promotion_skipped`. Process crash mid-call leaves the Episodic row unchanged; the next trigger re-runs cleanly.

### 8.4 pgvector upgrade path (anticipated, not in V1)

The upgrade is additive and isolated to the `MentorMemoryRetriever`:

1. Alembic migration adds `embedding vector(N)`, `embedding_model`, `embedded_at` columns and an HNSW index
2. Backfill job embeds existing rows
3. Re-embedding job triggers when the configured embedding model changes — stale embeddings are semantically incompatible and must be regenerated before similarity search is re-enabled
4. `MentorMemoryRetriever.load_context` switches from "load all" to "top-K by similarity"
5. Mentor turn assembly code does not change

### 8.5 Chapter detection

When the Mentor Conversation view loads, the backend compares `conversations.last_message_at` (Section 5.3) to the current date. If the dates differ, the API response includes a `chapter_prompt_required: true` flag, and the frontend presents the "Continue / Start fresh chapter" prompt described in overview.md §8.4. If the user selects "Start fresh chapter" (or via the manual chapter control), the backend inserts a system message with `message_subtype: "chapter_boundary"` and triggers a Working→Episodic compression step for the content up to that point. The `last_message_at` field is updated on every new message, so the comparison is always against the most recent activity.

---

## 9. Background Jobs

### 9.1 Review Agent (ADR-011)

- Runs in-process under the FastAPI APScheduler `AsyncIOScheduler`
- One `CronTrigger` job, schedule read from `REVIEW_AGENT_SCHEDULE` key in backend config (env var override supported)
- `max_instances=1`, `coalesce=True`, small `misfire_grace_time`
- Coordinates with the `review_agent_runs` table:
  - Both nightly cron and `POST /review-agent/run` check for `status='running'` before starting; manual endpoint returns 409 if already running
  - On startup, `status='running'` rows older than a grace period are reset to `failed` (crash recovery)
- Sets both `current_workspace_id` and `current_user_id` `ContextVar`s at task start
- Findings written to `review_agent_findings`; the table is the audit log

### 9.2 Orchestrator (ADR-012)

- Implemented as a LangGraph node (`orchestrator_check`) in the `ConversationOrchestrator` graph
- Runs sequentially after the Persona response node completes — fire-and-forget async, so the user-perceived turn latency is unaffected
- Suggestion (if produced) arrives on the Conversation's existing SSE stream as an `orchestrator_suggestion` event
- Frequency gate: `ORCHESTRATOR_EVAL_EVERY_N` (default 1); `messages_since_last_eval` counter on LangGraph state, resets to 0 on every evaluation attempt, whether or not a suggestion is emitted. `ORCHESTRATOR_EVAL_EVERY_N = 3` therefore means the Orchestrator evaluates every 3 messages regardless of whether a suggestion is produced.
- Uses `ModelGateway.invoke_structured` with a `PersonaSuggestion` Pydantic schema
- Never adds Personas — suggestions only

**1:1 mode threshold:**

In 1:1 mode, the `orchestrator_check` node applies a configurable higher confidence threshold (`ORCHESTRATOR_1TO1_THRESHOLD`, default higher than the standard `ORCHESTRATOR_THRESHOLD`) before emitting a suggestion. This respects the user's deliberate choice of a focused conversation.

**`@Orchestrator` mention handling** — when the user's message begins with `@Orchestrator`, the graph routes to a dedicated `orchestrator_direct` node instead of the normal Persona response node:

- **P2P mode:** the autonomous Persona exchange is paused before the `orchestrator_direct` node runs. After the Orchestrator responds, the graph routes to `await_user` — the exchange does not restart automatically; the user must send a message to resume.
- **Round-Robin mode:** the current in-flight Persona response completes, then the `orchestrator_direct` node runs. The Orchestrator's response is inserted as a message before the cycle resumes on the next user turn.
- **Targeted summary:** when all Workspace Personas are already participants in the Conversation, the primary `@Orchestrator` function available is a targeted summary. The `orchestrator_direct` node calls `ModelGateway.invoke` (or `invoke_structured` if a structured summary is needed) and streams the result back as a normal response on the SSE stream.
- The `@Orchestrator` interaction does not trigger the standard Orchestrator suggestion logic — it is a direct user-initiated call, not the background `orchestrator_check` hook.

### 9.3 Async Mentor Episodic→Semantic promotion (ADR-010)

- Triggered on a configured APScheduler schedule
- Uses the `pending_promotion` flag for idempotency
- See Section 8.3 for transaction boundary and failure handling

### 9.4 Conversation Observer

- **Trigger:** Invoked fire-and-forget from the `POST /conversations/{id}/end` handler, after the auto-summary completes. Not an APScheduler job — runs as an `asyncio.create_task` in the request context.
- **Guard:** If no Mentor Persona exists for the Workspace, the task returns immediately without writing anything.
- **Idempotency:** A unique constraint on `(mentor_persona_id, source_conversation_id)` in `mentor_episodic_memories` prevents duplicate observations if the handler is retried.
- **Logic:**
  1. Set `current_workspace_id` and `current_user_id` ContextVars from the concluded Conversation.
  2. Load the full message history for the concluded Conversation (user and Persona messages only; system messages excluded).
  3. Call `ModelGateway.invoke_structured(messages, ConversationObservation, purpose="conversation_observer")` — the prompt instructs the model to analyse the user's communication patterns, not Persona behaviour.
  4. Insert one `mentor_episodic_memories` row: `source_type='observed'`, `source_conversation_id=conversation_id`, `pending_promotion=True`, `summary_text` set from the structured output.
  5. On failure: log and discard — the observation is not critical-path. The Episodic→Semantic promotion job will pick up the row on its next run if the write succeeded.
- **Backfill on Mentor creation:** when the Mentor Persona is created (`POST /workspaces/{id}/personas` with `is_mentor=true`), the handler spawns an additional fire-and-forget task that iterates all concluded non-Mentor Conversations in the Workspace and runs the Observer logic for each. This gives the Mentor an initial episodic context rather than starting cold. The unique constraint on `(mentor_persona_id, source_conversation_id)` makes this idempotent.
- **`ConversationObservation` schema** (Pydantic structured output):
  - `summary_text: str` — prose observation suitable for storage as an episodic memory entry
  - `communication_patterns: list[str]` — recurring patterns observed in how the user structured their points
  - `explanation_challenges: list[str]` — moments where the user had to repeat or re-explain
  - `bridging_techniques: list[str]` — techniques used to bridge expertise gaps (analogies, examples, reframing)
  - `effectiveness_notes: list[str]` — observations on how well the techniques appeared to land
  The full `ConversationObservation` is serialised into `summary_text` as a formatted Markdown string for storage; the structured fields drive the formatting rather than being stored separately.

---

## 10. Streaming and Real-time Communication

### 10.1 One SSE stream per open Conversation (ADR-014)

- Endpoint: `GET /conversations/{id}/stream`
- Long-lived; one stream per open Conversation; concurrent open Conversations equal concurrent streams
- Backend: `StreamingResponse` + `sse-starlette`; the LangGraph `graph.stream()` output maps onto named SSE event types within the `ConversationOrchestrator`
- Reconnection: server-assigned event IDs + native `Last-Event-ID` handling via `@microsoft/fetch-event-source`

### 10.2 Named SSE event types

| Event type | Payload | Source |
| --- | --- | --- |
| `token` | Incremental token from the active Persona/Mentor response | LangGraph token stream |
| `response_complete` | Marker that the current response finished | LangGraph node end |
| `orchestrator_suggestion` | `PersonaSuggestion` payload | Orchestrator node (ADR-012) |
| `busy` | System has begun processing a turn | Graph state transition |
| `idle` | System is idle and ready for input | Graph state transition |
| `paused` | Conversation has been paused | Pause flag observed at turn boundary |
| `exchange_paused` | P2P autonomous exchange has been paused; payload includes `pause_reason: "user_pause" \| "turn_cap" \| "repetition_detected"` | P2P pause flag (ADR-017) |

The full event schema is finalised in the API contract.

### 10.3 Client → server control signals

Separate HTTP POST endpoints, all visible in the OpenAPI spec:

- `POST /conversations/{id}/messages` — send a user message
- `POST /conversations/{id}/pause` — sets `pause_requested=true` in graph state via the checkpointer
- `POST /conversations/{id}/resume` — clears `pause_requested`; graph resumes from last checkpoint (survives restarts). For user-initiated pauses only.
- `POST /conversations/{id}/cancel` — ends the autonomous exchange; transitions to `idle`; messages produced so far remain persisted

When the exchange pauses due to the turn cap or a repetition detection, the graph routes to `await_user` and emits `exchange_paused` with the appropriate `pause_reason`. Recovery in both cases is via `POST /conversations/{id}/messages` — the user sends a message (even just "continue" for the cap case, or a steering prompt for repetition), which resets the relevant counter (`p2p_turn_count` or the repetition-hash window) and resumes the exchange.

### 10.4 Multi-Persona response sequencing

In Round-Robin and P2P modes, successive Persona responses are emitted strictly sequentially on the same stream. Parallel Persona response streaming is explicitly out of scope for V1.

### 10.5 P2P turn-taking and throttling (ADR-017)

Defence in depth — every mechanism runs on every P2P turn:

- **Hard cap.** `p2p_turn_count` field on LangGraph state; when it reaches `MAX_P2P_TURNS` (config), the graph routes to `await_user`.
- **Minimum delay.** `P2P_TURN_DELAY_SECONDS` (config) at each turn boundary — gives pause/cancel signals a reliable window to land.
- **Repetition-hash throttle.** Each Persona response is hashed (similarity threshold, configurable from day one); compared against a rolling window of the last N (default 5). Near-match → route to `await_user` with reason `repetition_detected`.
- **Speaker selection.** Primary: addressability (regex scan of last response for the name of an active Persona). Fallback: deterministic round-robin over the participant list.
- **Pause/resume/cancel.** Shared with Section 10.3; flag-based via the checkpointer; pause survives process restarts. Turn-cap and repetition recovery is via user message (see Section 10.3); user-initiated pause recovery is via `POST /conversations/{id}/resume`.
- **Orchestrator interaction.** The Orchestrator hook still runs after each P2P Persona turn; suggestions surface on the SSE stream but never reorder the P2P turn flow.

### 10.6 Workspace-switch interrupt

When the user navigates to a different Workspace while a Conversation is open (overview.md §5.5), the navigation acts as an interrupt. The behaviour is layered across the SSE lifecycle, the LangGraph execution, and the resume path:

- **SSE stream close.** When the frontend navigates to a different Workspace, the SSE stream closes. The backend detects this as a disconnected client but **does not interrupt in-flight graph execution** — the current Persona response completes in the background, as the overview specifies.
- **Pause at the next turn boundary.** After the in-flight response completes, the graph checks for an active SSE listener on this Conversation. Finding none, it sets `pause_requested = true` in the checkpointer and routes to `await_user`. No SSE events are emitted (there is no listener to receive them).
- **Round-Robin mode.** The pause fires after the current Persona's response; the remaining Personas in the cycle do not respond.
- **P2P mode.** The pause fires after the current Persona's response; the autonomous exchange does not continue.
- **Resume on return.** When the user returns to the Conversation and the SSE stream re-opens, the user explicitly resumes via the standard `POST /conversations/{id}/resume` endpoint. From the frontend's perspective this is identical to resuming a user-initiated pause.

This intentionally distinguishes a navigation-away close from an intentional user pause only in *origin* — both converge on the same `pause_requested` flag and the same resume path.

---

## 11. Configuration (ADR-015)

### 11.1 Symmetric layered loaders

| Side | Loader | Validator | Base file (committed) | Local override (gitignored) |
| --- | --- | --- | --- | --- |
| Backend | Dynaconf | Pydantic | `backend/config.json` | `backend/config.override.json` |
| Frontend | nconf | Zod | `frontend/config.json` | `frontend/config.override.json` |

### 11.2 Override mechanism

**Backend:** Dynaconf reads `backend/config.override.json` at process startup — true runtime injection. The file is volume-mounted by Docker Compose into the running backend container; no rebuild is required to change a backend config value.

**Frontend:** The intention was symmetric runtime injection, but this is not achievable in a static SPA without SSR. The browser has no filesystem access, so nconf reads `frontend/config.override.json` during the Vite build step — config is baked into the compiled `/dist` bundle. Changing a frontend config value requires a rebuild. The Docker Compose volume mount for the frontend override must therefore be available at build time, not at serve time.

This asymmetry is a known limitation of the SPA architecture (ADR-013). The documented V2 upgrade paths are captured in Section 15.

### 11.3 Format

JSON everywhere. No TOML, YAML, or INI files for application configuration.

### 11.4 Secrets

Live only in `*.override.json` or environment variables. Committed `config.json` files contain no secret values.

### 11.5 Shared keys

Backend and frontend config files are independent by default. No genuinely shared config keys have been identified at this stage: the API base URL is a frontend-only concern (the frontend uses it to call the backend), and CORS allowed origins is a distinct backend-only concern that needs to be consistent with the frontend deployment URL but is not the same key. If genuinely shared keys emerge during implementation they should be documented in a shared reference file at that point; no shared reference document needs to be created up front.

### 11.6 Future cloud config sources

Cloud secrets manager, orchestrator-mounted files, etc. plug in as additional layers beneath the same loader API. Application code does not change.

### 11.7 Config key schema

The governing rule for both sides: if a sensible default is not obvious, the key is required with no default and must be set explicitly by the operator.

**Backend (`backend/config.json`):**

- **Required, no default** (deployment-specific; the operator must set them):
  - `context_window` — model-dependent token window size
  - `model` — model name passed to `init_chat_model`
  - `model_provider` — provider key passed to `init_chat_model`
  - `model_base_url` — endpoint URL for the configured provider
  - `database_url` — Postgres connection string
- **Has sensible defaults** (the specific default values for these keys are sized by the Backend Senior Developer against the implementation):
  - `ORCHESTRATOR_EVAL_EVERY_N` (default: 1)
  - `MAX_P2P_TURNS`
  - `P2P_TURN_DELAY_SECONDS`
  - `REVIEW_AGENT_SCHEDULE`
  - `ORCHESTRATOR_THRESHOLD`
  - `ORCHESTRATOR_1TO1_THRESHOLD`
  - `P2P_REPETITION_WINDOW` — repetition-hash rolling window size (default: 5 per ADR-017)
  - `P2P_REPETITION_THRESHOLD` — similarity threshold for repetition detection
- **Secret, override-only** (never present in the committed base file):
  - `api_key`
- **`CONTEXT_PANEL_MAX_CHARS`** is a backend config key only — the frontend reads this value from the backend API at runtime so it always reflects what the backend enforces. It is not duplicated in `frontend/config.json`.

**Frontend (`frontend/config.json`):**

- **Required, no default:**
  - `api_base_url` — deployment-specific; set in `frontend/config.override.json`
- **`CONTEXT_PANEL_MAX_CHARS`** is **not** a frontend config key. The frontend obtains this value from the backend API (e.g. embedded in the workspace or conversation response, or via a dedicated `GET /config` endpoint), avoiding a manually-synchronised shared key (consistent with Section 11.5).

---

## 12. Deployment

### 12.1 Canonical run model (ADR-005)

`docker compose up` starts the full system. Same compose file for local development and V1 production; environment-variable overrides handle the difference.

### 12.2 Services (V1)

| Service | Image | Notes |
| --- | --- | --- |
| `backend` | Custom Python image (FastAPI + APScheduler) | Mounts `backend/config.override.json` if present |
| `frontend` | Static-file server (e.g. nginx) over Vite `/dist` build | Mounts `frontend/config.override.json` if present |
| `postgres` | Official Postgres image | Data bind-mounted to `./data/postgres` for manual backup |
| `ollama` (optional) | Official Ollama image, or run externally | Decision deferred to implementation |

### 12.3 Backend-only development compose

A `docker-compose.dev.yml` at the repo root starts only `postgres` (and optionally `ollama`), with the data directory bind-mounted to `./data/postgres`. This allows the FastAPI backend to run directly on the developer's machine with a hot-reloading dev server (`uvicorn --reload`) while the database runs in Docker. The full `docker-compose.yml` is used for running the complete stack.

### 12.4 Cloud-deployment seam

The compose file is replaced by equivalent infrastructure-as-code (Terraform/CloudFormation/etc.) at cloud-deployment time. Application code does not change. Configuration is provided via the cloud platform's secrets manager or env vars, mapped onto the same `config.override.json` shape (or read directly via Dynaconf/nconf env-var overrides).

---

## 13. Security and Isolation

### 13.1 Workspace isolation (ADR-007)

- `WorkspaceScopedMixin` adds `workspace_id UUID NOT NULL FK` + index on every Workspace-scoped table
- SQLAlchemy `do_orm_execute` listener reads `workspace_id` from a `ContextVar` and injects `WHERE workspace_id = current` into every SELECT against mixin subclasses
- The `ContextVar` is set by FastAPI middleware per HTTP request and explicitly by background jobs at task start
- Raw SQL must include an explicit `workspace_id` predicate plus an inline comment confirming it — enforced by code review

### 13.2 User scoping (ADR-016)

- `UserScopedMixin` adds `user_id UUID NOT NULL FK→users(id)` on every table
- The `users` table is created and seeded with `DEFAULT_USER_ID` in the initial Alembic migration before any table that references it
- `CurrentUserMiddleware` resolves the current user via `resolve_current_user()` and sets `current_user_id` in a module-level `ContextVar`
- V1 `resolve_current_user()` body is a single line returning `DEFAULT_USER_ID`; no JWT, no session lookup, no DB round-trip
- Background jobs set both `current_workspace_id` and `current_user_id` at task start

### 13.3 RLS reserved path (ADR-007)

The schema is RLS-ready from day one (FK + NOT NULL + indexes in place). PostgreSQL Row-Level Security policies can be added via a future Alembic migration at cloud-deployment time with zero application code changes. Adding RLS adds `SET LOCAL` per transaction but no application-level refactor.

### 13.4 Future auth upgrade seam (ADR-016)

The only change required to swap the V1 stub for real authentication is the body of `resolve_current_user()`. The middleware, the `ContextVar`, every FK constraint, every mixin, the ORM listener, and every application call site are unchanged. Adding `password_hash`, provider-specific columns, etc. is an additive Alembic migration; no existing column changes type or nullability.

### 13.5 Local-data guarantee (NFR-7)

All data is stored locally in V1 (Postgres in the compose stack). User data is transmitted off-machine only when the configured model endpoint is a cloud API — an explicit user choice expressed through configuration.

---

## 14. Decision Index

| ADR | Title | One-line summary |
| --- | --- | --- |
| ADR-001 | Agentic Framework and Backend Language | LangChain + LangGraph in Python; `ConversationOrchestrator` is the containment boundary |
| ADR-002 | AI Model Abstraction Layer | Two-tier: `ModelGateway` for app services, `BaseChatModel` direct inside graph nodes |
| ADR-003 | Backend Web Framework | FastAPI + Starlette + Pydantic v2; `sse-starlette` for streaming; APScheduler for jobs |
| ADR-004 | Database Technology | PostgreSQL + SQLAlchemy 2.x async + Alembic; `PostgresSaver` checkpointer |
| ADR-005 | Deployment Model | `docker compose up` is the canonical run model for local and V1 production |
| ADR-006 | Conversation Snapshot and Persona Versioning | Three-axis: `conversation_personas` snapshots, `persona_system_prompt_versions`, `messages.conversation_persona_id` |
| ADR-007 | Workspace Isolation Enforcement | Application-layer ORM scoping via `ContextVar` + mixins; RLS reserved as future layer |
| ADR-008 | Context Window Management | Rolling recursive summarisation with last-N verbatim tail; Context Panel never truncated |
| ADR-009 | Mentor Memory Implementation | Two relational tables; no embeddings in V1; "load all" retrieval; pgvector documented upgrade path |
| ADR-010 | Mentor Memory Promotion Logic | Working→Episodic synchronous; Episodic→Semantic async via structured LLM output with `pending_promotion` flag |
| ADR-011 | Review Agent Scheduling | APScheduler `AsyncIOScheduler` in-process + `review_agent_runs` row-lock for single-run enforcement |
| ADR-012 | Orchestrator Trigger Mechanism | Sequential post-message LangGraph hook node (fire-and-forget) with `ORCHESTRATOR_EVAL_EVERY_N` frequency gate |
| ADR-013 | Frontend Framework | React 19 + Vite SPA, no SSR; SWR for server state; Base UI + Tailwind CSS; openapi-typescript for API types |
| ADR-014 | Streaming Transport | SSE per Conversation with named event types; HTTP POST for client→server control signals |
| ADR-015 | Configuration and Secrets Management | Symmetric Dynaconf+Pydantic / nconf+Zod over JSON; Docker Compose volume mounts for local overrides |
| ADR-016 | Multi-user Readiness Scaffolding | Seeded `users` table + real FKs + `CurrentUserMiddleware` + `ContextVar`; resolver-body-only auth upgrade seam |
| ADR-017 | P2P Turn-Taking and Throttling | Layered: hard cap + delay + repetition-hash throttle + addressability/round-robin + checkpointer-flag pause/resume/cancel |

---

## 15. Future Upgrades Reference

These are anticipated but unscheduled upgrade paths. None are in scope for V1. They are documented here so that Senior Developers design with them in mind — the schema, interfaces, and seams listed below must not be closed off during initial implementation.

| Upgrade | Current V1 state | Upgrade path | Where designed |
| --- | --- | --- | --- |
| **Semantic Memory embeddings (pgvector)** | "Load all" retrieval; no embedding column | Additive Alembic migration adds `embedding vector(N)` + HNSW index; backfill job; `MentorMemoryRetriever` switches to top-K similarity; re-embedding job required if embedding model changes | Section 8.4 |
| **Real authentication** | Single seeded `DEFAULT_USER_ID`; `resolve_current_user()` returns constant | Replace body of `resolve_current_user()` only; no middleware, FK, mixin, or call-site changes | Section 13.4 |
| **Row-Level Security** | Schema is RLS-ready (FK + NOT NULL + indexes in place) | Additive Alembic migration adds RLS policies; `SET LOCAL` per transaction; zero application code changes | Section 13.3 |
| **Hard token counting** | Approximate (~4 chars per token) | Per-provider token counters replace approximation; plug in behind `CompressionStrategy` interface | Section 7.2 |
| **Alternative compression strategies** | `RollingSummary` only | Additional `CompressionStrategy` implementations (e.g. hierarchical summarisation) plug in without assembly-code changes | Section 7.3 |
| **Cloud config sources** | JSON file loaders (Dynaconf / nconf) | Additional loader layers (cloud secrets manager, orchestrator-mounted files) added beneath the same loader API; application code unchanged | Section 11.6 |
| **Cloud deployment** | Docker Compose | Compose file replaced by IaC (Terraform / CloudFormation / etc.); config provided via cloud secrets manager mapped onto `config.override.json` shape | Section 12.4 |
| **Frontend runtime config injection** | Frontend config baked at Vite build time | Two options: (1) adopt an SSR framework (e.g. Next.js, SvelteKit) so config is injected server-side at request time; (2) add a `GET /config` endpoint on the FastAPI backend that returns browser-safe config values — frontend fetches this at startup, enabling runtime config without a rebuild and opening the door to cookie-based auth and server-side session state | Section 11.2 |
