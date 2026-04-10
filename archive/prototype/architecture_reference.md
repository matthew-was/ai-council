# AI Council: Architect Reference (Implementation Details)

## Purpose
`docs/system_document.md` is intentionally high-level (requirements and user/workflow behavior). This reference document consolidates the concrete, decided implementation-oriented details from:
- `overview.md`
- `docs/archive/open_questions.md`
- `docs/archive/open_questions_v2.md`
- `backend_tech.md`

Use this as an input when producing an architecture design document (component diagram, state machine, data model, job orchestration, etc.).

## 1. Source-of-truth mapping (where decisions live)
1. Core concept, components, and UI structure: `overview.md`
2. v1 scope decisions (what exists now vs later), including:
   - local vs OAuth, single implicit user mode
   - folder/conversation organization
   - retention/archive/delete behavior
   - mentor memory and mentor session behavior
   - review agent workflow and finding lifecycle
   - report generation constraints and report format expectations
   - storage paths and data privacy constraints
   - performance targets and failure-mode mitigations
   - agent involvement rules (suggestions vs auto-add, dismissal behavior)
: `docs/archive/open_questions.md`
3. Expanded/clarified decisions for v2 draft, including:
   - enhanced mentor memory lifecycle diagram and policies
   - review agent finding presentation and acceptance/dismiss/action flows
   - report generation format details: YAML front matter, standardized sections, filename/versioning
: `docs/archive/open_questions_v2.md`
4. Conversation orchestration modes and a first pass on how LangGraph/LangChain may be used:
: `backend_tech.md`

## 2. Conversation and agent orchestration modes
This system supports multiple conversation modes; the backend reference suggests implementing each mode as a LangGraph state machine (nodes = participants/chains; edges = turn order / routing).

### 2.1 1:1 conversation (single agent)
- Behavior: user talks to exactly one agent (examples: Mentor Agent, Business Strategist).
- Orchestration pattern: linear user <-> agent loop with a single chat window.
- Context: the agent uses the conversation history (buffer/summarized context depending on memory policy).

### 2.2 Round-robin conversation (hybrid multiple agents)
- Behavior: structured turns with multiple agents in a predefined order (example: Vision Keeper -> Business Strategist -> user loop).
- Orchestration pattern: LangGraph enforces a fixed turn order across agents.
- Context: shared across agents for the duration of the conversation step; messages are tagged by sender in the UI.

### 2.3 P2P (agent-to-agent) conversation
- Behavior: agents respond directly to each other (example: Vision Keeper -> Business Strategist), with routing determined from user input.
- Orchestration pattern:
  - conditional routing from the user turn to the addressed agent (based on a `target` field)
  - allow subsequent edges between agents (e.g., A -> B and B -> A)
- Context: agents pull relevant history rather than entire transcript (hybrid retrieval described in memory section).

### 2.4 Agent hand-offs vs auto-add (what the orchestrator does vs what requires user confirmation)
Decided in `docs/archive/open_questions.md` / overview:
- Auto-adding agents is not allowed in v1.
- The system can suggest agents (and hand-offs), but the user must confirm/add.
- Dismissed suggestions are remembered to prevent immediate re-suggestion.
- Re-suggestion can occur if the conversation topic changes significantly (threshold: > 30% topic change).

## 3. Agent involvement rules and "dismiss / resuggest" behavior
The agent suggestion system is part of the orchestrator UX:
- Suggestions are context-aware based on conversation topics.
- Each suggestion includes confidence percentage and rationale.
- Adding a suggested agent requires explicit user confirmation.
- Dismissing a suggestion records dismissal context and prevents immediate re-suggestion.
- The review agent later uses ended conversations to identify missed opportunities where an agent could have contributed.

## 4. Mentor session lifecycle (team-specific)
Mentor behavior is a special conversation type with a dedicated UI region.

### 4.1 Mentor scope and UI constraints
- Team-specific mentor: each team/workspace has its own mentor instance.
- Mentor-only conversation UI: no other agents are allowed in the mentor conversation view.
- UI distinction: mentor session is placed at the bottom of the conversations sidebar and visually differentiated.

### 4.2 Session model
- Single long-lived session per team.
- Inactivity handling:
  - timeout: 1 hour of inactivity
  - on return, user sees a prompt to either:
    - continue the existing session, or
    - start a fresh session
  - the choice impacts review-agent analysis and memory structuring.

### 4.3 Mentor context management and token handling (behavioral requirements)
- Automatic summarization triggers:
  - when context approaches ~3000 tokens
  - also on conversation ends / when summarization is needed to preserve context
- Working memory behavior:
  - keep last 5 messages verbatim
  - summarize older context into episodic memory
- Periodic knowledge extraction:
  - every 20 messages, extract structured knowledge into knowledge documents / semantic memory
- Resource monitoring:
  - token usage warnings at 3500 / 4096 (per archive decision)
- Auto-save:
  - every 5 minutes

## 5. Mentor memory architecture (Working / Episodic / Semantic)
The memory policy is implemented as a three-layer system with lifecycle rules and retrieval constraints.

### 5.1 Memory types (what goes where)
1. Working memory (volatile)
   - last 5 messages verbatim
   - active session context and short-term scratch/reasoning artifacts
2. Episodic memory (short-term)
   - summaries of last 10 team conversations
   - key decisions/outcomes extracted
   - automatic decay/pruning after 30 days
3. Semantic memory (long-term)
   - team context and goals (structured)
   - user profile preferences for the team
   - learned strategies/best practices
   - knowledge documents created from user additions and review-agent suggestions

### 5.2 Lifecycle transitions
- Working -> Episodic: when context approaches the working token limit, summarize older messages into episodic memory.
- Working -> Semantic: extract key insights into semantic memory (via periodic extraction and/or key transitions).
- Episodic -> Pruned: prune after > 30 days.
- Semantic -> Updated: nightly review agent updates semantic/knowledge documents with new insights and flags outdated knowledge.

### 5.3 Context window optimization (how retrieval/injection is decided)
- Retrieval is relevance-driven (not pure recency): score by recency + relevance + importance.
- Filtering includes a "hybrid retrieval" approach: semantic similarity plus metadata filtering.
- Compression behavior:
  - summarize older conversations; avoid truncating without guidance.
- Reasoning budget:
  - reserve a portion of the context window for reasoning (reserve policy described as ~20% in system_doc; archive discussions describe reserving context for reasoning during injection).

## 6. Review agent (nightly batch) and finding lifecycle
Review is a continuous improvement mechanism that runs asynchronously.

### 6.1 Review timing and scope
- Timing: nightly batch processing.
- Scope: team/workspace-scoped; reviews all agent activity since the last run.
- Goal: improve agent prompts and involvement rules using evidence from conversation history.

### 6.2 Metrics and evaluation rubric (what is measured)
Review metrics tracked include:
- Agent performance
  - relevance (0-10)
  - role adherence (0-10)
  - missed opportunities
  - engagement (0-10)
  - value added (0-10)
- Conversation quality
  - topic coverage
  - perspective diversity
  - decision clarity
- System health
  - context usage
  - token efficiency

### 6.3 Finding structure (what a review produces)
Findings are grouped for each agent and include:
- metric name
- score
- issue description
- evidence (examples referencing conversations and message text)
- suggestion (human-readable improvement)
- rationale
- priority (high/medium/low)

### 6.4 Finding lifecycle states and persistence
- New findings are marked New.
- Updated findings retain history and are marked Updated when new evidence changes the suggestion.
- Resolved findings are moved to history.
- Reviews remain visible until dismissed/acted on by the user.

### 6.5 UI integration (where findings appear)
- Findings appear in each agent page under a Recommendations section.
- Recommendations persist and evolve nightly until actioned.
- Evidence is expandable; user can see examples and related context.

### 6.6 Accept/reject semantics (Apply/Dismiss)
Decided behavior:
- One-click accept/reject is available for each finding.
- Accept:
  - creates/updates the agent configuration by applying the `prompt_modification` (or equivalent instruction update) proposed in the finding.
- Reject/Dismiss:
  - dismissals are recorded.
  - dismissed findings remain until resolved but are not immediately re-surfaced (dedupe depends on the review workflow).

## 7. Report generation (format and versioning)
Reports are generated with a dedicated report agent and follow a fixed structure for v1.

### 7.1 When reports are produced
- Summaries are always generated when a conversation ends (per archive decisions).
- Reports are generated only when the user requests it (via "Create report").
- The report agent generates the report automatically from conversation data once requested.

### 7.2 Fixed Markdown template (v1)
Report content sections:
- Overview
- Participants
- Key Discussion Points
- Perspectives
- Outcomes
- Metadata

### 7.3 YAML front matter and standardized metadata
Reports use YAML front matter with comprehensive metadata, including at least:
- title
- date
- agents
- team
- conversation_id
- version
- template

### 7.4 File naming and versioning
- Filename includes a timestamp suffix: `[title]-[YYYYMMDD-HHMM].md`
- Template version tracking is included in front matter (`template: standard-v1`)
- Storage path (local v1):
  - `~/.ai-council/reports/{team_id}/{conversation_id}/{title}-{timestamp}.md`

## 8. Storage model and local paths (v1)
### 8.1 Database and filesystem responsibilities
- PostgreSQL holds structured data:
  - users, teams/workspaces
  - folders, conversations, messages/summaries/context summaries
  - agent definitions/configurations
  - review data (reviews/findings) and statuses
  - mentor knowledge documents and memory representations (as defined by the memory policy)
- Filesystem holds generated report artifacts:
  - reports follow the path conventions above

### 8.2 Local user data isolation
Decided privacy approach for local mode:
- user-specific directory: `~/.ai-council/{user_id}/`
- restrictive permissions:
  - directories: 0700
  - files: 0600
- no cross-user access possible in local mode.

### 8.3 Docker Compose guidance (PostgreSQL)
Archive decision includes:
- PostgreSQL 15 in Docker
- data volume mapped to `./postgres-data`

## 9. Operational behavior: retention and nightly jobs
### 9.1 Retention job (conversation history lifecycle)
- Archive after 1 year (365 days)
- Delete after 2 years (730 days)
- Warning 30 days before auto-archive
- Implement as a daily retention job.
- Archived conversations are read-only.
- Pinning and manual archive/delete are supported.

### 9.2 Nightly review job
- Runs nightly.
- Processes team conversations since last run.
- Produces/updates agent findings in the Recommendations system.

### 9.3 Open architecture-level implementation concerns (not decided here)
Even though the *policy* is decided, the *engineering mechanics* are not fully specified in the docs:
- scheduling mechanism for nightly jobs (cron vs background worker in the container)
- job idempotency/deduping when rerun
- retry behavior on partial failures and how to avoid duplicate findings

## 10. Open items for the architect reference (remain undecided)
This section intentionally lists only items that are still not fully specified across `system_document.md`, `overview.md`, and the archive open-question decision docs.

### 10.1 Multi-agent conversation state protocol (turn-taking + merging)
- How iterative refinement is encoded in the LangGraph state machine:
  - exact ordering of responses
  - whether agent responses are merged into a single assistant message vs stored as separate messages
  - when summaries are generated during an active conversation (beyond end-of-conversation)

### 10.2 Safety/security and prompt-injection/data leakage guardrails
- Input/output filtering strategy for unsafe content.
- Prompt injection resilience strategy (especially for user-provided documents).
- How to ensure workspace isolation beyond "filesystem permissions" in the presence of logging/auditing.

### 10.3 Observability/tracing/audit logging
- What log events are emitted for:
  - conversation runs
  - agent hand-offs
  - nightly job runs and their outputs
- how correlation ids are propagated through web/UI -> backend -> LLM calls -> DB writes.

### 10.4 LLM routing/versioning/concurrency engineering
- How model version tracking is handled for reproducibility.
- Per-agent/per-workflow concurrency controls and queuing.
- Request timeouts and error handling strategy for each LLM call site.
