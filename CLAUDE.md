# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

**Phase: Implementation.** The planning phase is complete. All architecture, API contract, and implementation plan documents are approved. The `apps/` directory does not yet exist — implementation begins at task B-001 (backend scaffolding).

Prior prototype code and documentation is archived in [archive/](archive/).

The definitive product description is [documentation/project/overview.md](documentation/project/overview.md). The API source of truth is [documentation/tasks/api-contract.md](documentation/tasks/api-contract.md).

### Confirmed tech stack

**Backend**: FastAPI, SQLAlchemy 2.x async, asyncpg, LangGraph (orchestrator), APScheduler (background jobs), Alembic (migrations), Dynaconf (config), Pydantic v2, structlog, PostgreSQL.

**Frontend**: React 19, Vite, TanStack Router, SWR, Base UI + Tailwind CSS, `@microsoft/fetch-event-source`, openapi-typescript, Vitest, MSW, React Testing Library, vitest-axe.

## Documentation Standards

- All documentation lives in `documentation/`. The `archive/` directory is read-only — do not modify it.
- Lint markdown before committing: `markdownlint .`
- Markdown rules are configured in [.markdownlint.json](.markdownlint.json): MD013 (line length), MD022, MD032, MD036 are all disabled.
- Use conventional commit messages (`feat:`, `fix:`, `docs:`, `refactor:`).
- **Never auto-commit** — always ask before committing.

## Documentation Structure

```text
documentation/
  project/          # overview.md, architecture.md, system-diagrams.md
  requirements/     # user-requirements.md, phase-1-user-stories.md
  decisions/        # architecture-decisions.md (ADR format)
  tasks/            # implementation plans, task lists, review files
  process/          # agent-workflow.md, development-principles*.md, code-review-principles.md
  approvals.md      # approval status table + audit log
```

## Development Workflow

The project uses a multi-agent SDLC workflow defined in [documentation/process/agent-workflow.md](documentation/process/agent-workflow.md). Agents run in sequence; each phase requires explicit approval before the next begins.

Agent roster (in order):

1. **Product Owner** — overview → user-requirements → phase-1-user-stories
2. **Head of Development** — requirements → ADRs → architecture.md
3. **Senior Developer (Frontend)** — api-requirements-frontend.md, then senior-developer-frontend-plan.md
4. **Senior Developer (Backend)** — api-contract.md, then senior-developer-backend-plan.md
5. **Project Manager** — decomposes plans into frontend-tasks.md and backend-tasks.md; oversees pre-task plans and post-completion reviews
6. **Implementer** — writes code against approved task list
7. **Code Reviewer** — reviews completed code against principles and contract
8. **Principles Guardian** — runs every 5 completed tasks per service; synthesises patterns into principles files

Approval status for all tracked documents is in [documentation/approvals.md](documentation/approvals.md). All agents check this file at session start.

## Hooks

Two hooks run automatically (configured in `.claude/settings.json`):

- **lint-markdown.sh** — runs `markdownlint` after any Write or Edit to a `.md` file; blocks on errors
- **protect-task-status.sh** — blocks any tool call that would set a user-only task status (`ready_for_review`, `reviewed`, `changes_requested`)

## Key Product Concepts

These terms have precise meanings — use them consistently:

- **Workspace**: Top-level isolation boundary. All Personas, Conversations, Documents, and Mentor history are Workspace-scoped and never shared.
- **Persona**: User-created virtual character with a System Prompt and temperature setting.
- **Mentor**: One special Persona per Workspace with a persistent, never-ending Conversation and a three-layer memory system (Working → Episodic → Semantic).
- **Orchestrator**: Background process that suggests (never adds) Personas mid-conversation.
- **Review Agent**: Nightly background job that analyses concluded Conversations and surfaces System Prompt improvement suggestions per Persona.
- **Conversation Observer**: Fire-and-forget job that runs at conversation end, analysing user communication patterns from non-Mentor conversations and writing `source_type='observed'` entries to Mentor episodic memory. Silent no-op if no Mentor exists; backfills on Mentor creation.
- **Context Panel**: User-owned editable field in each Conversation that is always included in LLM context, surviving message truncation.

## Key Architectural Constraints

- The AI model integration must be abstracted so a local LLM can be swapped for a cloud API via configuration alone — no code changes required.
- The data model must include `user_id` from day one (even as a fixed local default in V1) to enable multi-user support later.
- The OpenAPI spec is a **build artefact** generated from the implementation. The human-readable API contract (`documentation/tasks/api-contract.md`) is the source of truth — the spec must match it.
