# AI Council: Strategic Ideation & Persona Simulation

AI Council is a self-hosted platform for validating ideas, stress-testing strategies, and anticipating objections. It simulates discussions between customisable expert personas, giving you holistic feedback before real-world implementation — via 1:1 chats, structured round-robins, or dynamic peer-to-peer exchanges.

## Core Concepts

- **Workspaces** — isolated advisory contexts (e.g. "Internal Team" vs. "Investor Board"). All Personas, Conversations, Documents, and Mentor history are Workspace-scoped and never shared.
- **Personas** — fully customisable agents with a System Prompt and temperature setting.
- **The Mentor** — one special Persona per Workspace with a persistent, never-ending Conversation and a three-layer memory system (Working → Episodic → Semantic).
- **Conversation Observer** — background job that analyses non-Mentor conversations and feeds the Mentor's episodic memory, so the Mentor learns how you communicate across all your work.
- **Review Agent** — nightly background job that analyses concluded Conversations and surfaces System Prompt improvement suggestions per Persona.
- **Orchestrator** — suggests (never adds) additional Personas mid-conversation based on the discussion content.

## Status

**Phase: Implementation** — the planning phase is complete. All architecture, API contract, and task decomposition documents are approved.

| Stream | Tasks | First task |
| --- | --- | --- |
| Backend | 23 tasks (B-001–B-023) | B-001: Project scaffolding |
| Frontend | 28 tasks (F-001–F-028) | F-001: Project scaffolding |

## Tech Stack

| Layer | Technologies |
| --- | --- |
| Backend | FastAPI, SQLAlchemy 2.x async, LangGraph, APScheduler, Alembic, PostgreSQL, Pydantic v2, structlog |
| Frontend | React 19, Vite, TanStack Router, SWR, Base UI + Tailwind CSS, openapi-typescript |
| Testing | pytest + MSW (backend); Vitest + React Testing Library + vitest-axe (frontend) |
| Infrastructure | Docker Compose (PostgreSQL + backend + frontend) |

## Key Documentation

| Document | Purpose |
| --- | --- |
| [Product Overview](documentation/project/overview.md) | Definitive product description — read first |
| [Architecture](documentation/project/architecture.md) | Data model, API layer, LangGraph orchestrator, background jobs, Mentor memory system |
| [System Diagrams](documentation/project/system-diagrams.md) | Mermaid diagrams for data flow, components, and deployment |
| [API Contract](documentation/tasks/api-contract.md) | Human-readable source of truth for all endpoints; OpenAPI spec is generated from the implementation to match this |
| [Backend Implementation Plan](documentation/tasks/senior-developer-backend-plan.md) | Detailed backend implementation guide |
| [Frontend Implementation Plan](documentation/tasks/senior-developer-frontend-plan.md) | Detailed frontend implementation guide |
| [Backend Tasks](documentation/tasks/backend-tasks.md) | Ordered task list for the backend service (B-001–B-023) |
| [Frontend Tasks](documentation/tasks/frontend-tasks.md) | Ordered task list for the frontend service (F-001–F-028) |
| [Agent Workflow](documentation/process/agent-workflow.md) | Multi-agent SDLC process |
| [Backend Principles](documentation/process/development-principles-backend.md) | Coding principles for the backend service |
| [Approvals](documentation/approvals.md) | Approval status and audit log for all tracked documents |

## Development Workflow

The project uses a multi-agent SDLC workflow. Agents run in sequence; each phase requires explicit approval before the next begins.

1. **Product Owner** → requirements and user stories
2. **Head of Development** → ADRs and architecture
3. **Senior Developer (Frontend + Backend)** → API contract and implementation plans
4. **Project Manager** → task decomposition and pre-task planning
5. **Implementer** → writes code against approved tasks
6. **Code Reviewer** → reviews each completed task
7. **Principles Guardian** → runs every 5 completed tasks; synthesises patterns into principles files

---

*Prior prototype code is archived in [archive/](archive/).*
