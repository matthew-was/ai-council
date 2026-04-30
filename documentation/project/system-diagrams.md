# System Diagrams

**Status:** Approved
**Date produced:** 2026-04-23
**Source:** Visual companion to `documentation/project/architecture.md`; reflects ADR-001 through ADR-017 in `documentation/decisions/architecture-decisions.md`.

---

## Purpose

This document is the visual companion to `architecture.md`. Each diagram illustrates one dimension of the approved architecture — deployment topology, internal component boundaries, the data model, the conversation graph, memory promotion flow, streaming and control signals, and configuration layering. The diagrams do not introduce any decisions; they depict decisions already recorded as ADRs. If a diagram and an ADR disagree, the ADR is correct and the diagram is a bug.

Read `architecture.md` first — it is the narrative; the diagrams below are references.

---

## 1. System Overview — Docker Compose Services

This diagram shows the canonical V1 deployment topology under `docker compose up` (ADR-005). Three services form the always-on set — `backend`, `frontend`, and `postgres`. An optional `ollama` service may be included in the compose stack or run externally; the model endpoint is chosen by configuration (ADR-002, ADR-015). Each mount on the backend and frontend containers is the local override file (gitignored) that layers over the committed base config (ADR-015). The diagram matters because it makes the "one compose file for local and V1 production" claim concrete — the only environmental variance is what is in the override files and which model endpoint they point at.

```mermaid
graph TD
  User[Browser / User]

  subgraph Compose["docker-compose.yml"]
    FE["frontend container<br/>static Vite build<br/>nginx or equivalent"]
    BE["backend container<br/>FastAPI + APScheduler<br/>uvicorn"]
    PG[("postgres container<br/>application tables +<br/>LangGraph checkpointer")]
    OL["ollama container<br/>[optional]"]
  end

  FEOverride["frontend/config.override.json<br/>[gitignored, host file]"]
  BEOverride["backend/config.override.json<br/>[gitignored, host file]"]
  PGData["./data/postgres<br/>[host bind mount]"]

  User -->|HTTP + SSE| FE
  User -->|HTTP + SSE| BE
  FE -->|REST + SSE| BE
  BE -->|SQLAlchemy asyncpg| PG
  BE -->|model calls, optional| OL

  FEOverride -. volume mount .-> FE
  BEOverride -. volume mount .-> BE
  PGData -. bind mount .-> PG
```

---

## 2. Backend Component Diagram — ModelGateway Boundary

This diagram shows the internal structure of the FastAPI backend and, critically, makes the ModelGateway boundary rule visible (ADR-001, ADR-002). Only the `ConversationOrchestrator` module (with its LangGraph nodes) and the `ModelGateway` itself may import from `langchain.*` or `langgraph.*`. Every other backend component — FastAPI routes, APScheduler jobs, services such as auto-naming and memory promotion — imports `ModelGateway` and never reaches for LangChain directly. The dashed line separates the "LangChain-aware" zone from the "LangChain-free" zone. This diagram matters because the boundary rule is the single most load-bearing architectural constraint on the backend codebase, and a picture makes violations obvious during review.

```mermaid
graph TD
  subgraph FastAPI["FastAPI Application Layer"]
    Routes["HTTP Routes<br/>REST + SSE endpoints"]
    Middleware["CurrentUserMiddleware<br/>+ Workspace middleware<br/>sets ContextVars"]
    Lifespan["Lifespan: start<br/>APScheduler"]
  end

  subgraph Jobs["APScheduler AsyncIOScheduler (in-process)"]
    ReviewJob["Review Agent job<br/>CronTrigger"]
    PromoJob["Episodic to Semantic<br/>promotion job"]
  end

  subgraph Services["Application Services [LangChain-free]"]
    AutoName["Auto-naming"]
    Compress["Context compression"]
    OrcSvc["Orchestrator suggestion service"]
    RevSvc["Review Agent service"]
    MemPromo["Mentor memory promotion"]
  end

  MG["ModelGateway<br/>invoke / stream /<br/>invoke_structured / embed<br/>[LangChain-aware]"]

  subgraph Graph["ConversationOrchestrator [LangChain-aware]"]
    GraphDef["LangGraph graph definition"]
    Nodes["persona_turn / orchestrator_check /<br/>speaker_select / await_user nodes"]
    Saver["PostgresSaver checkpointer"]
  end

  subgraph Data["SQLAlchemy Data Layer [LangChain-free]"]
    Mixins["WorkspaceScopedMixin<br/>UserScopedMixin<br/>do_orm_execute listener"]
    Models["ORM Models"]
    Alembic["Alembic migrations"]
  end

  PG[("PostgreSQL")]

  Routes --> Services
  Routes --> Graph
  Middleware --> Routes
  Lifespan --> Jobs

  Services --> MG
  ReviewJob --> RevSvc
  PromoJob --> MemPromo

  Nodes -->|BaseChatModel direct<br/>LCEL + graph.stream| Graph
  MG -->|BaseChatModel| Graph
  Graph --> Saver
  Saver --> PG

  Services --> Data
  Routes --> Data
  Data --> Mixins
  Mixins --> Models
  Models --> PG

  classDef lcZone fill:#fde8d0,stroke:#c96,stroke-width:2px;
  classDef lcFree fill:#e4f1e4,stroke:#4a4,stroke-width:1px;
  class MG,Graph,GraphDef,Nodes,Saver lcZone;
  class Services,Data,AutoName,Compress,OrcSvc,RevSvc,MemPromo,Mixins,Models lcFree;
```

---

## 3. Data Model — Core Entities

This ER diagram shows the primary keys and foreign-key relationships of the core tables. It omits most non-FK columns to keep the relational skeleton readable. All Workspace-scoped tables carry `workspace_id` and `user_id` FKs (ADR-007, ADR-016) — these are shown explicitly because they are the isolation backbone. `conversation_personas` intentionally has no FK to `persona_system_prompt_versions`: snapshots store the System Prompt text directly so that deleting a Persona cannot corrupt historical Conversations (ADR-006). `messages.conversation_persona_id` is the provenance link from each message to the snapshot that produced it.

```mermaid
erDiagram
  users ||--o{ workspaces : owns
  users ||--o{ personas : owns
  users ||--o{ conversations : owns
  users ||--o{ folders : owns
  users ||--o{ documents : owns

  workspaces ||--o{ personas : contains
  workspaces ||--o{ conversations : contains
  workspaces ||--o{ folders : contains
  workspaces ||--o{ documents : contains
  workspaces ||--o{ mentor_episodic_memories : contains
  workspaces ||--o{ mentor_semantic_memories : contains
  workspaces ||--o{ review_agent_runs : contains

  personas ||--o{ persona_system_prompt_versions : "version history"
  personas ||--o{ conversation_personas : "snapshotted into"
  personas ||--o{ review_agent_findings : "findings about"

  folders ||--o{ conversations : "groups"

  conversations ||--o{ conversation_personas : "participants"
  conversations ||--o{ messages : "contains"
  conversations ||--|| conversation_summaries : "rolling summary"
  conversations ||--o{ documents : "source of"

  conversation_personas ||--o{ messages : "authored"

  review_agent_runs ||--o{ review_agent_findings : "produces"

  users {
    uuid id PK
    text email
    timestamptz created_at
  }
  workspaces {
    uuid id PK
    uuid user_id FK
    text name
  }
  personas {
    uuid id PK
    uuid workspace_id FK
    uuid user_id FK
    text name
    text system_prompt
    float temperature
    bool is_mentor
  }
  persona_system_prompt_versions {
    uuid id PK
    uuid persona_id FK
    text system_prompt
    timestamptz created_at
  }
  conversations {
    uuid id PK
    uuid workspace_id FK
    uuid user_id FK
    uuid folder_id FK "nullable"
    text title
    text mode
    text status
    text context_panel
  }
  folders {
    uuid id PK
    uuid workspace_id FK
    uuid user_id FK
    text name
  }
  conversation_personas {
    uuid id PK
    uuid conversation_id FK
    uuid persona_id FK "nullable"
    timestamptz joined_at
    text snapshot_name
    text snapshot_system_prompt
    float snapshot_temperature
  }
  messages {
    uuid id PK
    uuid conversation_id FK
    uuid conversation_persona_id FK "nullable"
    text role
    text content
  }
  conversation_summaries {
    uuid id PK
    uuid conversation_id FK "unique"
    text rolling_summary
    timestamptz updated_at
  }
  mentor_episodic_memories {
    uuid id PK
    uuid workspace_id FK
    uuid user_id FK
    uuid mentor_persona_id FK
    int sequence_number
    text summary_text
    uuid source_conversation_id FK "nullable"
    bool pending_promotion
    timestamptz promoted_at "nullable"
  }
  mentor_semantic_memories {
    uuid id PK
    uuid workspace_id FK
    uuid user_id FK
    uuid mentor_persona_id FK
    text title
    text content_markdown
  }
  review_agent_runs {
    uuid id PK
    uuid workspace_id FK
    text status
    timestamptz started_at
    timestamptz completed_at "nullable"
  }
  review_agent_findings {
    uuid id PK
    uuid review_agent_run_id FK
    uuid persona_id FK
  }
  documents {
    uuid id PK
    uuid workspace_id FK
    uuid user_id FK
    text type
    text title
    text content_markdown
    uuid source_conversation_id FK "nullable"
  }
```

---

## 4. Conversation Graph — LangGraph Nodes and Edges

This flowchart is the logical shape of the `ConversationOrchestrator` LangGraph graph (ADR-001, ADR-012, ADR-017). A Persona turn runs; the `orchestrator_check` hook runs sequentially after it (fire-and-forget — it never gates the next turn); then a routing decision examines P2P state. Three conditional edges can divert from "next turn" to `await_user`: the hard turn cap, the repetition-hash throttle, and the user-initiated pause flag. When routed to `await_user`, the graph awaits a user message (POST) that resets the relevant counter and resumes. This diagram matters because it shows why P2P mode is bounded in depth — every autonomous turn passes all three throttles, independently.

```mermaid
graph TD
  Start([User message received]) --> PersonaTurn["persona_turn node<br/>stream response via<br/>BaseChatModel LCEL"]
  PersonaTurn --> OrcCheck["orchestrator_check node<br/>fire-and-forget<br/>gated by EVAL_EVERY_N"]
  OrcCheck --> ModeBranch{"Conversation mode?"}

  ModeBranch -->|one_to_one or<br/>round_robin end| AwaitUser["await_user state<br/>emit idle event"]
  ModeBranch -->|round_robin next| PersonaTurn
  ModeBranch -->|p2p| P2PDelay["wait<br/>P2P_TURN_DELAY_SECONDS"]

  P2PDelay --> PauseCheck{"pause_requested?"}
  PauseCheck -->|yes| EmitUserPause["emit exchange_paused<br/>reason=user_pause"]
  EmitUserPause --> AwaitUser

  PauseCheck -->|no| CapCheck{"p2p_turn_count &gt;= MAX?"}
  CapCheck -->|yes| EmitCap["emit exchange_paused<br/>reason=turn_cap"]
  EmitCap --> AwaitUser

  CapCheck -->|no| RepCheck{"response hash near-match<br/>in rolling window?"}
  RepCheck -->|yes| EmitRep["emit exchange_paused<br/>reason=repetition_detected"]
  EmitRep --> AwaitUser

  RepCheck -->|no| SpeakerSelect["speaker_select node<br/>primary: addressability regex<br/>fallback: round-robin"]
  SpeakerSelect --> IncCount["increment p2p_turn_count<br/>append hash to window"]
  IncCount --> PersonaTurn

  AwaitUser --> Resume{{"user action"}}
  Resume -->|POST resume<br/>user_pause only| PersonaTurn
  Resume -->|POST messages<br/>turn_cap / repetition| ResetCounters["reset p2p_turn_count<br/>or repetition window"]
  ResetCounters --> PersonaTurn
  Resume -->|POST cancel| Idle([idle / exchange ended])
```

---

## 5. Mentor Memory Promotion Flow

This sequence diagram traces a memory item from Working Memory through Episodic to Semantic (ADR-009, ADR-010). Working to Episodic is synchronous and shares the same DB transaction as the ADR-008 compression step — a brief inline pause is acceptable. Episodic to Semantic is asynchronous: triggered by session-end signals or the APScheduler schedule, it calls `ModelGateway.invoke_structured` outside the DB transaction, then wraps only the row updates in a transaction. The `pending_promotion` flag + `promoted_at` provide idempotency so a crash mid-call simply re-runs cleanly on the next trigger. The retry-and-retire path keeps the memory system unblocked under persistent LLM failure.

```mermaid
sequenceDiagram
  autonumber
  participant Conv as Mentor Conversation<br/>[Working Memory]
  participant Comp as Compression Step<br/>[ADR-008]
  participant DB as PostgreSQL
  participant Trig as Session-end /<br/>APScheduler trigger
  participant MG as ModelGateway<br/>invoke_structured
  participant Sem as mentor_semantic_memories

  Note over Conv,DB: Working to Episodic [synchronous, same transaction]
  Conv->>Comp: threshold reached
  Comp->>MG: invoke [fold oldest block]
  MG-->>Comp: rolling_summary updated
  Comp->>DB: BEGIN
  Comp->>DB: UPDATE conversation_summaries
  Comp->>DB: INSERT mentor_episodic_memories<br/>[pending_promotion=true]
  Comp->>DB: COMMIT

  Note over Trig,Sem: Episodic to Semantic [async]
  Trig->>DB: SELECT episodic WHERE<br/>pending_promotion AND promoted_at IS NULL
  DB-->>Trig: episodic row
  Trig->>MG: invoke_structured<br/>[summary_text + existing titles]
  alt success
    MG-->>Trig: [{title, content, mode}]
    Trig->>DB: BEGIN
    Trig->>Sem: INSERT or UPDATE per item
    Trig->>DB: UPDATE episodic<br/>SET promoted_at=now,<br/>pending_promotion=false
    Trig->>DB: COMMIT
  else transient failure [retry up to 3x with backoff]
    MG--xTrig: error
    Trig->>Trig: exponential backoff + retry
  else final failure
    Trig->>DB: UPDATE episodic<br/>SET promoted_at=now<br/>[retire / skip]
    Trig->>Trig: log promotion_skipped
  else process crash mid-call
    Note over Trig,DB: no DB change yet<br/>next trigger re-runs cleanly<br/>promoted_at prevents double-promotion
  end
```

---

## 6. SSE Streaming and Control Signals — P2P Scenario

This sequence shows a full client-server interaction for a P2P conversation using the transport and signals from ADR-014 and ADR-017. The frontend opens one long-lived SSE stream per open Conversation. The user sends a message by POST — a separate request from the stream. The backend processes turns inside the LangGraph graph, emitting named SSE events (`busy`, `token`, `response_complete`, `orchestrator_suggestion`, `exchange_paused`). The user recovery path from a `turn_cap` or `repetition_detected` pause is a normal message POST, not a separate resume endpoint — see ADR-017. This diagram matters because it makes the asymmetric traffic pattern visible: the server streams, the client signals occasionally.

```mermaid
sequenceDiagram
  autonumber
  participant FE as React Frontend<br/>fetch-event-source
  participant API as FastAPI Routes
  participant Graph as ConversationOrchestrator<br/>LangGraph
  participant MG as ModelGateway /<br/>BaseChatModel
  participant DB as PostgreSQL

  FE->>API: GET /conversations/{id}/stream
  API-->>FE: SSE stream open

  FE->>API: POST /conversations/{id}/messages<br/>[user message]
  API->>DB: INSERT message
  API->>Graph: invoke / stream

  Graph-->>API: busy event
  API-->>FE: event: busy

  loop P2P autonomous turns
    Graph->>MG: stream [Persona A turn]
    MG-->>Graph: token stream
    Graph-->>API: token events
    API-->>FE: event: token [chunks]
    Graph-->>API: response_complete
    API-->>FE: event: response_complete

    Graph->>MG: invoke_structured [orchestrator_check]
    MG-->>Graph: PersonaSuggestion or none
    opt suggestion produced
      Graph-->>API: orchestrator_suggestion
      API-->>FE: event: orchestrator_suggestion
    end

    Graph->>Graph: wait P2P_TURN_DELAY_SECONDS
    Graph->>Graph: check pause_requested /<br/>turn_cap / repetition-hash

    alt user pressed pause
      FE->>API: POST /conversations/{id}/pause
      API->>DB: set pause_requested=true<br/>[via checkpointer]
    end
  end

  Graph-->>API: exchange_paused<br/>[pause_reason=repetition_detected]
  API-->>FE: event: exchange_paused<br/>[pause_reason=repetition_detected]
  API-->>FE: event: idle

  Note over FE: UI shows pause reason<br/>offers steering input

  FE->>API: POST /conversations/{id}/messages<br/>[steering message]
  API->>Graph: resume with reset counters
  Graph-->>API: busy event
  API-->>FE: event: busy
  Note over FE,Graph: loop continues until cancel,<br/>user pause, or next throttle fires
```

---

## 7. Configuration and Secrets Layering

This diagram shows the two-layer configuration stack on each side of the system (ADR-015). The backend stack is Dynaconf loading JSON, validated by Pydantic. The frontend stack is nconf loading JSON, validated by Zod. On both sides the committed base file (`config.json`) provides safe, non-secret defaults; the gitignored local override (`config.override.json`) is mounted into the container via a Docker Compose volume and layers over the base at load time. Secrets live only in the override file or in environment variables. This diagram matters because the "Infrastructure as Configuration" hard constraint lives and dies on this layering — the contract is that swapping a local LLM for a cloud API is a file change, not a code change.

```mermaid
graph LR
  subgraph Host["Host filesystem [developer machine]"]
    BEBase["backend/config.json<br/>[committed]<br/>non-secret defaults"]
    BEOver["backend/config.override.json<br/>[gitignored]<br/>secrets + local overrides"]
    FEBase["frontend/config.json<br/>[committed]<br/>non-secret defaults"]
    FEOver["frontend/config.override.json<br/>[gitignored]<br/>secrets + local overrides"]
  end

  subgraph BE["backend container"]
    BEDyna["Dynaconf loader<br/>JSON source"]
    BEPyd["Pydantic models<br/>validate + type"]
    BEApp["FastAPI application<br/>reads typed config"]
  end

  subgraph FE["frontend container"]
    FEnconf["nconf loader<br/>JSON source"]
    FEZod["Zod schemas<br/>validate + type"]
    FEApp["React app<br/>reads typed config"]
  end

  BEBase -->|baked into image| BEDyna
  BEOver -. docker compose<br/>volume mount .-> BEDyna
  BEDyna --> BEPyd --> BEApp

  FEBase -->|baked into build| FEnconf
  FEOver -. docker compose<br/>volume mount .-> FEnconf
  FEnconf --> FEZod --> FEApp

  EnvVars["Environment variables<br/>[cloud seam]"] -. optional additional layer .-> BEDyna
  EnvVars -. optional additional layer .-> FEnconf
```

---
