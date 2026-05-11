# Agent Workflow Design

## Philosophy

This project uses a **human-in-the-loop** multi-agent workflow. Agents analyse, synthesise, and present options. The developer makes all final decisions. This is intentional — not a limitation.

**Why not full autonomy?**

- Complex architectural decisions involve domain knowledge that agents cannot fully have
- The project will pause and resume many times; clear agent roles ensure context can be re-established quickly
- Confident wrong assumptions compound quickly in a multi-step pipeline — human checkpoints prevent this
- Explicit decision records mean any agent session can be resumed without reconstructing context from memory

---

## How to Start a Session With an Agent

Agents have no memory between sessions. Each conversation starts fresh. To re-establish context quickly:

**Starting any agent session:**

1. Open a new conversation with the relevant agent (via the agent picker in Claude Code)
2. State what phase you are in and what you want to accomplish, for example: *"We are in the Product Owner phase. The overview document is approved. I want to produce the user requirements document."*
3. The agent will read its key context files as defined in its role. Point it at any additional output documents from prior phases that are relevant.

**Context documents to pass at each phase:**

| Agent | Pass these documents |
| --- | --- |
| Product Owner | `documentation/project/overview.md` |
| Head of Development | `documentation/requirements/user-requirements.md`, `documentation/decisions/architecture-decisions.md`, `documentation/process/development-principles.md` |
| Senior Developer (Backend) | `documentation/requirements/user-requirements.md`, `documentation/decisions/architecture-decisions.md`, `documentation/project/architecture.md`, `documentation/tasks/api-contract.md` |
| Senior Developer (Frontend) | `documentation/requirements/user-requirements.md`, `documentation/decisions/architecture-decisions.md`, `documentation/project/architecture.md` |
| Platform Engineer | `documentation/project/architecture.md`, approved task lists |
| Project Manager | Senior Developer implementation plan |
| Implementer | Project Manager task list, Senior Developer implementation plan |
| Code Reviewer | Code under review, original implementation plan, `documentation/tasks/api-contract.md`, `documentation/decisions/architecture-decisions.md` |
| Principles Guardian | Last 5 `post-completion-review-[frontend\|backend]-task-[N].md` files, all four principles files |

**Output documents are the handoff mechanism**: Agents communicate across sessions through documents written to disk. If a document exists at the expected location, the next agent picks it up. This is why every agent's definition of done requires output written to a file — not just discussed in chat.

**Resuming within a phase**: If a session was interrupted mid-phase, re-open the conversation, state the current task, and point the agent at the partially completed output document. It will continue from there.

---

## Why These Agents Exist

The agent structure exists to:

- Give each type of work a consistent, documented role
- Ensure no component is designed in isolation from the others (the Backend Senior Developer owns the API contract that both sides work against)
- Enable the developer to engage at different levels (strategic with Head of Development, task-level with Project Manager)
- Prevent security and quality concerns from being bolted on later (Code Reviewer embeds them from the start)
- Allow the system to improve over time (Principles Guardian surfaces patterns across completed tasks and stress-tests existing principles)

---

## Agent Roster

**⚠️ Important**: Some context files referenced in agent role definitions (particularly implementation plans and API contracts) are created during earlier phases and may not exist yet when you start a new agent. This is expected. When starting an agent session:

- If context files do not exist, the agent will note that they are not yet created
- Agents will identify and flag missing context as blocking dependencies
- Follow the agent's guidance on whether to continue or wait for prior phases to complete

---

### 1. Product Owner

**File**: `.claude/agents/product-owner.md`

**Responsibility**: Define and own the project scope. Reviews `documentation/project/overview.md`, produces the user requirements document, and converts requirements into formal user stories with acceptance criteria. This is the first agent engaged — nothing should be built without a clear requirements foundation.

**Inputs**: `documentation/project/overview.md`

**Outputs**:
- `documentation/requirements/overview-review.md` — issues surfaced before requirements are written (may be discussed in-session rather than written to disk if issues are minor)
- `documentation/requirements/user-requirements.md` — structured requirements with priority, user type, and rationale
- `documentation/requirements/phase-1-user-stories.md` — user stories with acceptance criteria and definition of done

**Scope constraints**: Does NOT make architectural decisions. Flags any requirement with architectural implications for the Head of Development.

**Handoff**: Pass `user-requirements.md` and `phase-1-user-stories.md` to the Head of Development.

---

### 2. Head of Development

**File**: `.claude/agents/head-of-development.md`

**Responsibility**: Facilitate architectural decisions. Reads the Architectural Flags in `user-requirements.md`, presents options with tradeoffs for developer decision, and records all decisions as ADRs. Produces `architecture.md` as a synthesis of all decisions.

**Inputs**: `documentation/requirements/user-requirements.md`, `documentation/requirements/phase-1-user-stories.md`

**Outputs**:
- `documentation/decisions/architecture-decisions.md` — ADRs for every architectural flag resolved
- `documentation/decisions/adr-consistency-review.md` — internal consistency check before approval
- `documentation/project/architecture.md` — fresh synthesis of all decisions
- `documentation/project/system-diagrams.md` — Mermaid diagrams of the confirmed architecture

**Scope constraints**: Does NOT make decisions unilaterally. Presents options; waits for the developer.

**Handoff**: Pass `architecture-decisions.md` and `architecture.md` to the Senior Developers.

---

### 3. Senior Developer (Frontend)

**File**: `.claude/agents/senior-developer-frontend.md`

**Responsibility**: Produce the frontend implementation plan. First drafts an API requirements document — what endpoints the frontend needs from the backend. Then, once the backend API contract is approved, produces the full frontend implementation plan.

**Inputs**: `documentation/project/architecture.md`, `documentation/requirements/phase-1-user-stories.md`, `documentation/tasks/api-contract.md` (once available)

**Outputs**:
- `documentation/tasks/api-requirements-frontend.md` — what the frontend needs from the backend API
- `documentation/tasks/senior-developer-frontend-plan.md` — full frontend implementation plan
- `documentation/tasks/senior-developer-frontend-review.md` — self-review before presenting to developer

**Scope constraints**: Plans `apps/frontend/` only. Does NOT make architectural decisions. Does NOT plan backend routes or data access.

**Handoff**: Pass `senior-developer-frontend-plan.md` to the Project Manager.

---

### 4. Senior Developer (Backend)

**File**: `.claude/agents/senior-developer-backend.md`

**Responsibility**: Own the data model and API contract. Reads the frontend API requirements, designs the full backend API, and produces a human-readable API contract document that both sides work against. Also produces the backend implementation plan. The OpenAPI spec is a build artefact generated from the implementation — not this agent's output.

**Inputs**: `documentation/project/architecture.md`, `documentation/requirements/phase-1-user-stories.md`, `documentation/tasks/api-requirements-frontend.md`

**Outputs**:
- `documentation/tasks/api-contract.md` — approved human-readable API contract; gates both implementation plans
- `documentation/tasks/senior-developer-backend-plan.md` — full backend implementation plan
- `documentation/tasks/senior-developer-backend-review.md` — self-review before presenting to developer

**Scope constraints**: Plans `apps/backend/` only. Does NOT make architectural decisions. The API contract must be approved before either Implementer begins.

**Handoff**: Pass `api-contract.md` to the Senior Developer (Frontend) to complete their plan. Pass `senior-developer-backend-plan.md` to the Project Manager.

---

### 5. Platform Engineer

**File**: `.claude/agents/platform-engineer.md`

**Responsibility**: Own the platform layer — CI/CD pipeline maintenance, dependency currency, and infrastructure integrity as services grow. Does not write application code. Initial Docker Compose setup and GitHub Actions workflows are created as implementation tasks (B-023, B-024, F-029); the Platform Engineer is invoked for ongoing maintenance and reviews once those foundations are in place.

**Three invocation modes (each independently invocable)**:

1. **CI/CD review and repair** — on-demand; audits existing GitHub Actions workflows, identifies jobs that are failing or drifting from the current test suite shape, and proposes fixes. Invoked when CI is consistently failing or when new test tiers are added.
2. **Dependency update review** — on-demand; reads all dependency manifests (`pyproject.toml`, `package.json`), fetches current versions, assesses security advisories, and writes a recommendation report with proposed version bumps. Does not apply changes — produces a report for developer decision.
3. **Infrastructure alignment check** — invoked after significant implementation milestones; verifies that `docker-compose.yml`, CI workflows, and local development setup remain consistent with the current architecture and task list.

**When to invoke**: After B-022 and F-028 are complete (full test suites exist and Docker builds are working). Also on-demand whenever CI is broken, dependencies need reviewing, or infrastructure has drifted.

---

### 6. Project Manager

**File**: `.claude/agents/project-manager.md`

**Responsibility**: Convert Senior Developer implementation plans into ordered task lists (decomposition mode), and verify completed tasks against acceptance conditions (verification mode).

**Pre-task plan**: Before the Implementer writes any code, the Project Manager oversees a pre-task plan step — the Implementer produces a short plan of work for the specific task, which the developer reviews and confirms. Any gaps spotted at this stage are recorded in the post-completion-review file with a `[plan-gap]` or `[task-gap]` tag.

**Post-completion review**: After each task reaches `reviewed` status, the PM reads `documentation/tasks/post-completion-review-[frontend|backend]-task-[N].md`, synthesises observations from all agents, presents proposed additions tagged to their destination principles file, and records actioning outcomes in the review file before setting the task to `done`.

**Outputs**:
- `documentation/tasks/frontend-tasks.md`
- `documentation/tasks/backend-tasks.md`
- Verification notes appended to each task block
- `[plan-gap]` and `[task-gap]` tags recorded in post-completion-review files

---

### 7. Implementer

**File**: `.claude/agents/implementer.md`

**Responsibility**: Write production-ready code from approved task lists for the frontend (`apps/frontend/`) and backend (`apps/backend/`) services.

**Pre-task plan step**: Before writing any code, produces a short plan of work for the specific task — what it intends to do, in what order, and any concerns or ambiguities spotted. The developer reviews and confirms before implementation begins. Any pre-task modifications are recorded in the post-completion-review file.

**Post-completion review**: Writes observations worth formalising to `documentation/tasks/post-completion-review-[frontend|backend]-task-[N].md` as work progresses.

**Scope constraints**: Implements exactly what the plan and task list specify. Does NOT make architectural decisions. Flags principle gaps at handoff.

---

### 8. Code Reviewer

**File**: `.claude/agents/code-reviewer.md`

**Responsibility**: Quality assurance and security validation of implemented code. Invoked after a task is marked `ready_for_review`.

**Post-completion review**: Writes observations to `documentation/tasks/post-completion-review-[frontend|backend]-task-[N].md` alongside its review findings.

**Review focus areas**: Acceptance condition, type safety (Python and TypeScript), security at boundaries, Infrastructure as Configuration compliance, composition root and dependency injection, service layer result types, error handling, data access compliance, test quality, plan compliance, readability.

**Scope constraints**: Does NOT modify code. Does NOT make architectural decisions. Escalates blocking architectural findings to Head of Development.

---

### 9. Principles Guardian

**File**: `.claude/agents/principles-guardian.md`

**Responsibility**: Invoked every 5 completed tasks per service. Reads the last 5 post-completion-review files and looks for patterns across them. Also re-reads all four principles files and stress-tests existing principles against recent evidence — identifying principles worded too narrowly where recent evidence suggests workarounds. Proposes new additions and rewrites for developer approval. Surfaces `[plan-gap]` and `[task-gap]` entries as suggested improvements to the relevant Senior Developer agent definition.

**Inputs**: Last 5 `post-completion-review-[frontend|backend]-task-[N].md` files, all four principles files, actioning records from previous PM summaries.

**Outputs**: Proposed additions and rewrites presented to developer; approved changes written to the relevant principles file.

---

## Workflow Sequence

### Pre-Implementation (run once)

```text
Product Owner reviews overview.md and surfaces issues
  ↓ [DoD: overview.md approved]
Product Owner produces user requirements and user stories
  ↓ [DoD: both documents approved]
Head of Development resolves all architectural flags as ADRs
  ↓ [DoD: architecture-decisions.md, architecture.md, system-diagrams.md approved]
Senior Developer (Frontend) drafts API requirements document
  ↓ [DoD: api-requirements-frontend.md approved]
Senior Developer (Backend) produces API contract and backend plan
  ↓ [DoD: api-contract.md and senior-developer-backend-plan.md approved]
Senior Developer (Frontend) produces frontend plan against approved contract
  ↓ [DoD: senior-developer-frontend-plan.md approved]
Project Manager decomposes both plans into task lists
  ↓ [DoD: frontend-tasks.md and backend-tasks.md approved]
```

Note: Docker Compose setup (B-023), GitHub Actions CI (B-024, F-029), and monorepo scaffolding are embedded in the implementation task lists rather than handled by a separate pre-implementation Platform Engineer phase.

### Per-Task Implementation Loop

```text
PM sets task to plan_pending
  ↓
Implementer writes pre-task plan → sets task to plan_ready
  ↓ [developer confirms plan]
Implementer sets coding_started → writes code and tests → sets code_written
  ↓ [developer sets ready_for_review]
Code Reviewer reviews → sets review_passed or review_failed
  ↓ [developer sets reviewed]
Project Manager verifies acceptance condition and user need
Post-completion review file synthesised and actioned
  ↓ [task set to done]
```

### Every 5 Completed Tasks (per service)

```text
Principles Guardian reads last 5 post-completion-review files
Principles Guardian re-reads all four principles files
Proposes additions, rewrites, and Senior Developer agent improvements
  ↓ [developer approves or rejects each proposal]
Approved changes written to principles files
```

### Platform Engineering (can run concurrently with implementation)

```text
Platform Engineer — Docker Compose local environment
Platform Engineer — GitHub Actions CI/CD
Platform Engineer — Dependency review (on-demand)
```

---

## Definition of Done — General Principles

A phase is not complete until the developer has explicitly reviewed and approved its output. Agents do not self-certify completion. The following apply to all handoffs:

- Outputs are written to their designated locations — not just described in chat
- Any blocking issues are resolved before the next phase begins — they are not carried forward as known debt
- If a phase raises new questions or scope changes, they are recorded before proceeding (as new ADRs or as a new requirement)

---

## Skills vs Agents

**Skills** are reusable workflow definitions and domain knowledge patterns referenced by multiple agents.

**Agents** are role definitions — how to behave in a specific role.

**Decision rule**: Ask "Will multiple agents need to reference this pattern?" If yes → skill. If specific to one agent → belongs in that agent's definition.

**Current skills** (see `.claude/skills/`):

- `approval-workflow.md` — how agents record, check, and cascade document approvals
- `configuration-patterns.md` — how services load and validate configuration (populated after architecture phase)
- `pipeline-testing-strategy.md` — testing tiers and patterns (populated after architecture phase)
- `dependency-composition-pattern.md` — dependency injection patterns (populated after architecture phase)
- `update-task-status/` — task status transition management and enforcement
