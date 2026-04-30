# ADR Roadmap

**Role:** Head of Development
**Phase:** Decision Facilitation
**Date produced:** 2026-04-16
**Status:** Complete — all 17 decisions recorded

---

## Purpose

This file tracks the full set of architectural decisions to be made, their recommended resolution order, current status, and a pointer to the ADR recording each choice. It is a working document — update it as decisions are made.

Source inputs for every decision:

- `documentation/decisions/research-questions.md` — complete research findings (Groups A–I)
- `documentation/requirements/user-requirements.md` — Architectural Flags section
- `documentation/requirements/phase-1-user-stories.md` — approved user stories

---

## Status Key

| Symbol | Meaning |
| ------ | ------- |
| ⬜ | Not yet started |
| 🔵 | Under discussion |
| ✅ | Decided — ADR recorded |

---

## Decision Queue

Ordered foundational-first. Upstream choices constrain downstream ones, so resolving in this order avoids revisiting decisions.

---

### Batch 1 — Foundation

Must resolve first; everything else depends on these.

| # | Decision | Flag | Research | Status | ADR |
| - | -------- | ---- | -------- | ------ | --- |
| 1 | **Agentic framework + backend language** — LangChain/LangGraph vs PydanticAI vs lightweight DIY vs other. Gates language (Python vs TypeScript), orchestration primitives, context handling, streaming, and pause/resume. | FR-21.2 (partial), all FR-2x | A, B | ✅ | ADR-001 |
| 2 | **AI model abstraction layer** — Interface that isolates all model calls; how provider and model name are injected from config at runtime with zero code changes. Must satisfy Infrastructure as Configuration exactly. | FR-21.2 | A (RQ-A4, RQ-A5), I | ✅ | ADR-002 |
| 3 | **Backend web framework** — FastAPI vs Flask vs other (or TS equivalent if #1 resolves to TypeScript). Shapes routing, streaming endpoint design, dependency injection, and OpenAPI generation. | NFR-3, NFR-8 (implied) | B | ✅ | ADR-003 |

---

### Batch 2 — Data and Persistence

Depends on Batch 1 language/framework choice.

| # | Decision | Flag | Research | Status | ADR |
| - | -------- | ---- | -------- | ------ | --- |
| 4 | **Database technology** — Relational vs embedded (SQLite/libSQL) vs hybrid; ORM choice; migration tooling. Must support local-first (NFR-3) and user_id from day one (NFR-8). | NFR-3, NFR-8 | F | ✅ | ADR-004 |
| 5 | **Conversation snapshot / Persona versioning** — How past Conversations are preserved when a Persona's System Prompt changes; snapshot-at-send vs append-only event log vs other. Shapes data model significantly. | FR-12.2 (implied) | E (RQ-E3, RQ-E4), I (RQ-I5) | ✅ | ADR-006 |
| 6 | **Workspace isolation enforcement** — Database-level row-ownership vs application-level middleware vs both. Must be enforced from day one even with a single local user. | NFR-8 | F, G | ✅ | ADR-007 |

---

### Batch 3 — Context and Memory

Depends on Batch 1 and 2.

| # | Decision | Flag | Research | Status | ADR |
| - | -------- | ---- | -------- | ------ | --- |
| 7 | **Context window management** — Strategy for fitting System Prompt + Context Panel + history into the context window; truncation policy; token counting approach. | FR-20.2 | A, G | ✅ | ADR-008 |
| 8 | **Mentor memory implementation** — Three-layer memory (Working → Episodic → Semantic) data model and retrieval pattern; embedding strategy; promotion trigger mechanism. | FR-22.2 | E, G | ✅ | ADR-009 |
| 9 | **Mentor memory promotion logic** — What triggers promotion between layers; LLM-assisted vs rule-based; how promotion failures are handled. | FR-22.3 | E | ✅ | ADR-010 |

---

### Batch 4 — Background Jobs and Scheduling

Depends on Batch 1.

| # | Decision | Flag | Research | Status | ADR |
| - | -------- | ---- | -------- | ------ | --- |
| 10 | **Review Agent scheduling** — Nightly/triggered background job runner; in-process scheduler vs external; job state persistence; retry on failure. | FR-23.1 | D | ✅ | ADR-011 |
| 11 | **Orchestrator trigger mechanism** — How the background Orchestrator is invoked mid-conversation to suggest Personas; synchronous vs async; debounce strategy. | FR-3.x (implied) | A, D | ✅ | ADR-012 |

---

### Batch 5 — Frontend and Transport

| # | Decision | Flag | Research | Status | ADR |
| - | -------- | ---- | -------- | ------ | --- |
| 12 | **Frontend framework** — React (Vite) vs SvelteKit vs other; SSR vs SPA. | NFR-3 (implied) | H | ✅ | ADR-013 |
| 13 | **Streaming transport** — SSE vs WebSocket for token streaming; protocol for multi-Persona simultaneous responses. | FR-2.3, FR-5.x | C | ✅ | ADR-014 |

---

### Batch 6 — Operations and Config

Depends on Batch 1 and 2.

| # | Decision | Flag | Research | Status | ADR |
| - | -------- | ---- | -------- | ------ | --- |
| 14 | **Configuration and secrets management** — How API keys, model names, and env-specific values are loaded; .env vs config file vs secrets backend; local-first requirement. | NFR-3, FR-21.2 | I | ✅ | ADR-015 |
| 15 | **Local-first deployment and packaging** — How the app is packaged for a single local user with no cloud dependency; database location; startup UX. | NFR-3 | B, F, H | ✅ | ADR-005 |
| 16 | **Multi-user readiness scaffolding** — What user_id scaffolding is built in V1 with only one local user; auth stub design; schema and middleware constraints. | NFR-8 | G | ✅ | ADR-016 |

---

### Batch 7 — Edge Cases and Protocol

| # | Decision | Flag | Research | Status | ADR |
| - | -------- | ---- | -------- | ------ | --- |
| 17 | **P2P turn-taking and throttling** — How simultaneous Persona responses are sequenced or rate-limited in a multi-Persona P2P conversation; back-pressure design. | FR-5.3 | C, G | ✅ | ADR-017 |

---

## Notes

- When a decision is made, update the row Status to ✅ and add the ADR filename to the ADR column.
- If a later decision requires revisiting an earlier one, set its status back to 🔵 and note the dependency.
- This file is not an approval document. Decisions recorded in ADRs are developer-confirmed choices, not agent-generated approvals.
- ADRs are recorded in `documentation/decisions/architecture-decisions.md`.
