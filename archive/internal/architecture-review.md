# Architecture Review Findings

**Document reviewed**: `documentation/project/architecture.md`
**Reviewed against**: `documentation/project/overview.md`, `documentation/tasks/api-requirements-frontend.md`, `documentation/decisions/architecture-decisions.md`
**Review date**: 2026-04-24
**Reviewer**: General-purpose review agent

---

## Summary

The architecture document is well-structured and covers the majority of the system at a level that
would allow Senior Developers to begin planning. The document is strong on the model abstraction,
data model, deployment, and configuration sections. However, the review identified 18 findings:
3 Critical, 7 Major, and 8 Minor. The Critical issues are places where a Senior Developer would be
forced to make a design decision that should have been made at the architecture level. The Major
issues are genuine inconsistencies or meaningful gaps that will cause implementation confusion.
The Minor issues are wording ambiguities, cross-reference drifts, and missing details that are
inferable but worth resolving before implementation begins.

The ADRs (`documentation/decisions/architecture-decisions.md`) were cross-referenced against all
18 findings. No finding is fully resolved by the ADRs, but four are partially addressed — see
notes on F-10, F-13, F-15, and F-16.

---

## Suggested Reading Order

Work through findings in this order to make the best use of review time:

1. **Start with the 3 Criticals (F-1, F-2, F-3).** These are the findings where a Senior
   Developer would have to invent an undocumented design decision. F-3 (Workspace-switch
   interrupt) is the largest gap; F-2 (Mentor snapshot contradiction) is the most likely to cause
   a real implementation divergence.

2. **Then the 7 Majors (F-4 through F-10).** F-9 (`message_subtype` naming inconsistency) and
   F-4 (`auto_summary` vs `summary_text`) are worth resolving first within this group — they will
   produce actual bugs if each side of the system implements what its document says. F-6
   (`is_mentor_conversation` deferral) is a quick resolve: state it is a persisted column.

3. **Finally the 8 Minors (F-11 through F-18).** F-17 (missing config key schema) is the most
   useful one to do before the Backend Senior Developer starts planning. F-15 (session end trigger)
   has a clear resolution from the ADRs: remove "session end" from the Section 8.3 trigger table.
   F-18 (broken cross-reference) is a one-line fix.

---

## Findings

### Critical

**[F-1] `review_agent_findings` schema is explicitly deferred with no constraints** *(Severity: Critical)*

- **Location:** Section 5.5
- **Issue:** The document states "Field details to be finalised by the Senior Developer — Backend."
  The Frontend API requirements document (api-requirements-frontend.md, FC-7) only adds: "The
  frontend needs at minimum: `id`, `persona_id`, evidence text, and suggestion text." The
  architecture provides no constraints on how findings relate to run state, whether dismissed vs.
  actioned findings are stored in the same table with a status column, how the Review Agent applies
  a suggestion to a System Prompt (replacement, append, diff?), or how suppression state is
  captured. The Backend Senior Developer must invent all of this with no guidance.
- **Resolution:** Define the schema in Section 5.5 as follows:
  - **Fields:** `id`, `persona_id FK`, `run_id FK nullable` (linking to the generating run),
    `evidence_text` (quoted conversation excerpt showing the issue), `target_passage TEXT NULLABLE`
    (the specific excerpt from the current System Prompt to be replaced; null for additive
    suggestions), `suggestion_text` (the proposed replacement or addition), `status
    ENUM(active|stale|actioned|dismissed)`, `created_at`, `updated_at`.
  - **Apply mechanism:** find-and-replace `target_passage` → `suggestion_text` in
    `personas.system_prompt`, wrapped in a single transaction with a `persona_system_prompt_versions`
    insert. For additive suggestions (`target_passage` is null), append `suggestion_text` to the
    prompt. The apply endpoint can assume `target_passage` is always valid — the Review Agent
    guarantees it via its reconciliation step (see below).
  - **Staleness on prompt edit:** when `personas.system_prompt` is updated via any path (PATCH
    endpoint, finding application, or consultation-mode apply), the handler checks all `active`
    findings for that Persona — any whose `target_passage` is no longer present in the new prompt
    are immediately set to `stale`. The UI renders stale findings distinctly and prompts the user
    to run the Review Agent to refresh.
  - **Finding lifecycle:** the nightly run (and any manual "Run now" trigger) includes a
    reconciliation step over existing `active` and `stale` findings — drops a finding if the
    underlying issue is resolved, or updates `target_passage` and `suggestion_text` to match the
    current System Prompt if the issue persists. This means the apply endpoint never needs a
    graceful-failure path for a missing `target_passage`.

---

**[F-2] Mentor Conversation snapshot behaviour contradicts the Persona snapshot principle** *(Severity: Critical)*

- **Location:** Section 8.2
- **Issue:** Section 8.2 states "Mentor has no snapshot per se since its Conversation never ends;
  the live System Prompt is read directly." Section 3.6 and Section 5.2 establish that context
  assembly always reads from `conversation_personas`, never from `personas` directly. If the Mentor
  Conversation has a row in `conversations`, it must have a corresponding row in
  `conversation_personas` or the context assembly code must have a special Mentor branch. This
  contradiction means a Backend Senior Developer cannot implement context assembly without deciding
  how the Mentor's participating row is structured. The note "(see FR-7 of Section 7 of overview)"
  also points to the Review Agent section of overview.md — the wrong section.
- **Resolution:** The Mentor is a documented exception to the snapshot rule (Option B). The context
  assembly code checks `is_mentor_conversation` and, when true, reads `personas.system_prompt`
  directly rather than from `conversation_personas`. The Mentor has no `conversation_personas` row.
  The immutable-snapshot rule applies only to standard Conversations; the Mentor's never-ending
  Conversation makes a frozen snapshot semantically meaningless. Section 8.2 should be updated to
  state this exception explicitly — including that the Mentor has no `conversation_personas` row —
  and the broken cross-reference "(see FR-7 of Section 7 of overview)" should be replaced with a
  correct reference to overview.md §8.2.

---

**[F-3] Workspace-switch interrupt behaviour has no architectural mapping** *(Severity: Critical)*

- **Location:** Section 5.5 (absent)
- **Issue:** overview.md §5.5 specifies: "If the user switches to a different Workspace while a
  Conversation is open, switching acts as an interrupt. The current in-flight AI response completes
  in the background. In Round-Robin mode, the rest of the current cycle is paused. In P2P mode,
  the autonomous exchange is paused and does not continue in the background. In all cases, the user
  must explicitly resume when they return to that Workspace and Conversation." This is a
  multi-layered behaviour involving: (a) the SSE stream lifecycle when the frontend navigates away,
  (b) graph state and the checkpointer determining whether in-flight LangGraph execution continues,
  (c) the distinction between a navigating-away close and an intentional pause, and (d) the resume
  path on return. None of this is addressed in architecture.md.
- **Resolution:** Add a subsection to Section 10 documenting the Workspace-switch interrupt:
  - When the frontend navigates to a different Workspace, the SSE stream closes. The backend
    detects this as a disconnected client but does not interrupt in-flight graph execution — the
    current Persona response completes in the background as the overview specifies.
  - After the in-flight response completes, the graph checks for an active SSE listener. Finding
    none, it sets `pause_requested = true` in the checkpointer and routes to `await_user`. No SSE
    events are emitted (there is no listener to receive them).
  - In Round-Robin mode, this fires after the current Persona response; the remaining Personas in
    the cycle do not respond.
  - In P2P mode, this fires after the current Persona response; the autonomous exchange does not
    continue.
  - On return, the user resumes via the standard `POST /conversations/{id}/resume` endpoint — from
    the frontend's perspective this is identical to resuming a user-initiated pause.

---

### Major

**[F-4] `auto_summary` vs `summary_text` naming inconsistency across documents** *(Severity: Major)*

- **Location:** Section 5.3 vs. api-requirements-frontend.md (Get a Single Conversation)
- **Issue:** Section 5.3 defines the field as `auto_summary JSONB NULLABLE` with sub-fields
  `key_takeaways`, `points_of_agreement`, `points_of_disagreement`, `action_items`.
  api-requirements-frontend.md refers to the same field as `summary_text` in places. A Backend
  Senior Developer writing the API contract must guess which name is canonical.
- **Resolution:** `auto_summary` is canonical. All references to `summary_text` in
  api-requirements-frontend.md are remnants of the original FC-1 resolution and must be updated
  to `auto_summary` before the Senior Developer agents are invoked. No design decision is
  required — this is a naming consistency fix only.

---

**[F-5] No statement that `conversation_summaries` is an internal-only table** *(Severity: Major)*

- **Location:** Section 5.3
- **Issue:** The document defines two distinct summaries: `auto_summary` (structured
  end-of-conversation, user-facing) and `conversation_summaries` (rolling internal context window
  summary). The api-requirements-frontend.md states "The rolling summary is never exposed in API
  responses," but architecture.md says nothing about this rule. A Backend Senior Developer reading
  only architecture.md would not know this constraint and might expose the rolling summary by
  mistake.
- **Resolution:** Add a sentence to the `conversation_summaries` entry in Section 5.3 explicitly
  stating it is an internal-only table; its contents are never returned in API responses. No design
  decision required — this is a documentation gap only.

---

**[F-6] `is_mentor_conversation` deferral creates unnecessary uncertainty** *(Severity: Major)*

- **Location:** Section 5.3
- **Issue:** The field definition includes "storage detail left to the implementer (persisted column
  or derived from join)." This is not a minor detail — it affects query performance, whether the
  ORM mixin works uniformly, and how the Frontend caches the Mentor Conversation record. Given the
  project's "keep simple things simple" principle, leaving this open invites unnecessary design
  churn.
- **Resolution:** `is_mentor_conversation` is a persisted BOOL column, set once at insert time
  when the Mentor Conversation is created, and never changed thereafter. The note "storage detail
  left to the implementer" should be removed from Section 5.3. This is consistent with how
  `is_mentor` is handled on the `personas` table.

---

**[F-7] Persona deletion while active: no enforcement architecture defined** *(Severity: Major)*

- **Location:** Section 5.2 (absent)
- **Issue:** overview.md §4.2 specifies that a Persona cannot be deleted while active in an open
  Conversation, and that attempting to do so shows a warning with the blocking Conversation(s).
  api-requirements-frontend.md confirms the backend returns an error with blocking Conversation IDs
  and titles. Architecture.md has no guidance on whether this is a DB constraint, an
  application-layer check, which query defines "currently active," or what the error response shape
  is.
- **Resolution:** The DELETE Persona handler performs an application-layer check (not a DB
  constraint, which cannot return meaningful error context). The check queries
  `conversation_personas` for rows where `left_at IS NULL` joined to `conversations` where
  `status = 'active'` for the given `persona_id`; if any exist, the handler returns a 409 with
  the blocking Conversation IDs and titles. This should be documented in Section 5.2 or Section
  4.3 as the enforced pattern for this business rule.

---

**[F-8] "Empty Conversation delete on End" behaviour has no data model or handler guidance** *(Severity: Major)*

- **Location:** Section 5.3 and Section 9 (absent)
- **Issue:** overview.md §5.5 specifies: "If a Conversation has no user or Persona messages —
  including Conversations that contain only system messages — triggering 'End Conversation' deletes
  the Conversation rather than creating an empty ended record." Architecture.md provides no guidance
  on how the End Conversation handler detects this condition, or what cascades when the record is
  deleted (conversation_personas rows, rolling summary, checkpointer state).
- **Resolution:** The `POST /conversations/{id}/end` handler first queries `messages` for any rows
  with `role IN ('user', 'persona', 'mentor')` for that Conversation. System messages
  (`role = 'system'`, e.g. join/leave events) are excluded — a Conversation containing only system
  messages is still considered empty. If no qualifying messages exist, the handler performs a full
  cascade delete: `messages`, `conversation_personas`, `conversation_summaries`, the `conversations`
  row itself, and the LangGraph checkpointer state for that thread. If qualifying messages exist,
  the normal end-of-conversation flow proceeds. This rule should be documented in Section 4.3 or
  as a note on the `conversations` table in Section 5.3.

---

**[F-9] `message_subtype` values are inconsistent between documents** *(Severity: Major)*

- **Location:** Section 5.3 vs. api-requirements-frontend.md (FC-4)
- **Issue:** Section 5.3 defines `message_subtype` values as: `persona_join`, `persona_leave`,
  `chapter_boundary`, `orchestrator_suggestion_accepted`, `mode_change`. The
  api-requirements-frontend.md FC-4 uses: `persona_joined`, `persona_left`, `mode_changed`. The
  present-tense vs. past-tense difference (`persona_join` vs. `persona_joined`) will produce real
  bugs if each side implements what their document says.
- **Resolution:** Standardise on past tense throughout: `persona_joined`, `persona_left`,
  `chapter_boundary`, `orchestrator_suggestion_accepted`, `mode_changed`. `chapter_boundary` and
  `orchestrator_suggestion_accepted` are already consistent between documents and unchanged. The
  fix must be applied to architecture.md Section 5.3 so the Backend Senior Developer sees the
  correct canonical values. api-requirements-frontend.md FC-4 already uses the correct past-tense
  forms and requires no change.

---

**[F-10] No canonical "active participants" query defined for snapshot-per-join model** *(Severity: Major)*

- **Location:** Section 5.2
- **Issue:** Section 5.2 states "Multiple rows per `(conversation_id, persona_id)` pair are valid;
  the most recent `joined_at` is the active snapshot." But the canonical query for "active
  participants in a Conversation" is not defined, and the refresh path (which inserts a new row
  with a new `joined_at`) makes the query non-trivial. Without a defined pattern, the Backend
  Senior Developer and the Implementer may diverge.
- **ADR note:** ADR-006 gives *"Context assembly queries `conversation_personas` ordered by
  `joined_at DESC` for the active snapshot"* — this covers the ordering half of the pattern but
  omits the `left_at IS NULL` filter. The finding still stands.
- **Resolution:** Add an explicit note to Section 5.2 stating the canonical query pattern: for a
  given `conversation_id`, select the most recent `joined_at` row per `persona_id` where
  `left_at IS NULL`. All queries for current participants must follow this pattern. Without
  `left_at IS NULL`, a removed Persona whose row has the most recent `joined_at` would incorrectly
  appear as an active participant. This is a documentation-only fix — the logic is implied by the
  data model, just not stated.

---

### Minor

**[F-11] Orchestrator `messages_since_last_eval` reset condition is ambiguous** *(Severity: Minor)*

- **Location:** Section 9.2
- **Issue:** The counter "resets to 0 when the Orchestrator fires." It is unclear whether this
  means it resets on every evaluation attempt (regardless of whether a suggestion is emitted) or
  only when a suggestion is actually produced. The distinction changes how frequently the
  Orchestrator evaluates in practice.
- **Resolution:** The counter resets on every evaluation attempt, regardless of whether a
  suggestion is produced. `ORCHESTRATOR_EVAL_EVERY_N = 3` means evaluate every 3 messages;
  if no suggestion is produced the counter resets to 0 and the next evaluation fires after another
  N messages. This gives clean "eval every N messages" semantics and makes the config key an
  effective cost lever. Section 9.2 should be updated to replace "resets to 0 when the Orchestrator
  fires" with "resets to 0 on every evaluation attempt, whether or not a suggestion is emitted."

---

**[F-12] "Parallel Persona response streaming" upgrade row points to a section with no seam described** *(Severity: Minor)*

- **Location:** Section 15, row "Parallel Persona response streaming" — "Where designed" column
  points to Section 10.4
- **Issue:** Section 10.4 contains only the statement that parallel streaming is out of scope.
  There is no seam described, so the "Where designed" pointer implies more than exists.
- **Resolution:** Remove the "Parallel Persona response streaming" row from the Section 15 Future
  Upgrades table entirely. Parallel streaming is not a desirable future feature — in P2P mode each
  Persona sees the full conversation history before responding, giving coherent exchanges. Parallel
  responses would mean each Persona responds to an incomplete picture, and the user would have no
  way of knowing what context each Persona had when forming its response. P2P mode already addresses
  the goal of more natural multi-Persona conversation. Section 10.4 requires no seam note; the
  sequential streaming approach is correct and final.

---

**[F-13] `REVIEW_AGENT_SCHEDULE` described as "env var" in one place and "env/config" in another** *(Severity: Minor)*

- **Location:** Sections 4.5 and 9.1
- **Issue:** Section 4.5 says "schedule from `REVIEW_AGENT_SCHEDULE` env var." Section 9.1 says
  "schedule from `REVIEW_AGENT_SCHEDULE` env/config." The configuration system (ADR-015) reads from
  JSON config files with env-var override — "env var" alone implies the schedule is not in
  `backend/config.json`, which contradicts the established approach.
- **ADR note:** ADR-011 itself uses *"schedule read from `REVIEW_AGENT_SCHEDULE` environment
  variable (cron string) — not hardcoded."* This makes Section 4.5's "env var" wording the one
  closer to the ADR source. The correct resolution is to align both sections with ADR-011's
  language, treating it as an environment variable that is also settable via `backend/config.json`
  per the ADR-015 layered approach.
- **Resolution:** Standardise both Sections 4.5 and 9.1 to: *"read from `REVIEW_AGENT_SCHEDULE`
  key in backend config (env var override supported)."* This is consistent with how all other
  config keys work under ADR-015 and removes the inconsistency between the two sections.

---

**[F-14] Shared config keys location is still "TBD during implementation"** *(Severity: Minor)*

- **Location:** Section 11.5
- **Issue:** "Any key that must agree across both sides must be listed in a shared reference
  document (location TBD during implementation)." For the Backend Senior Developer, the API base
  URL is the most important such key. Without a defined location, Senior Developers cannot
  synchronise on shared keys during planning.
- **Resolution:** There are no genuinely shared config keys identified at this stage. The API base
  URL is a frontend-only concern (the frontend uses it to call the backend). The related backend
  concern — CORS allowed origins — is a distinct backend-only key that needs to be consistent with
  the frontend deployment URL but is not the same key. Section 11.5's "location TBD" note should
  be simplified to state that if genuinely shared keys emerge during implementation they should be
  documented in a shared reference file at that point. No shared reference document needs to be
  created now.

---

**[F-15] Working → Episodic "session end" trigger contradicts FC-5 resolution** *(Severity: Minor)*

- **Location:** Sections 8.3 and 9.3
- **Issue:** Section 8.3 lists "session end (FR-18.2)" as a Working → Episodic promotion trigger.
  Section 9.3 also references "session-end signals." However, the api-requirements-frontend.md
  FC-5 developer decision resolved: "Episodic → Semantic promotion runs on a scheduled overnight
  job only… The frontend sends no session-end signal." If there is no session-end signal from the
  frontend, the "session end" trigger for Working → Episodic also has no mechanism, since stream
  disconnection detection was also ruled out under FC-5.
- **ADR note:** ADR-010 lists only one trigger for Working → Episodic: *"fires when Working Memory
  reaches the ADR-008 compression threshold."* It does not mention session end or new chapter.
  Both were added to architecture.md Section 8.3 beyond what the ADR specifies. The session end
  trigger has no ADR decision backing it and should be removed. Whether "new chapter" belongs as
  an additional trigger is a separate question that needs a developer decision.
- **Resolution:** Remove "session end" from the Section 8.3 trigger table and remove the
  "session-end signals" reference from Section 9.3 — neither has a mechanism after FC-5. Retain
  "new chapter" as a Working → Episodic trigger: it is semantically correct (a new chapter is a
  natural session boundary for the Mentor), already described in Section 8.5 (*"triggers a
  Working → Episodic compression step for the content up to that point"*), and consistent with
  the architecture as a whole.

---

**[F-16] Review Agent apply path not covered by the `persona_system_prompt_versions` insert rule** *(Severity: Minor)*

- **Location:** Section 5.2
- **Issue:** Section 5.2 states that `persona_system_prompt_versions` is "Inserted in the same
  transaction that updates `personas.system_prompt`." This covers the standard PATCH endpoint.
  However, applying a Review Agent finding also writes to `personas.system_prompt` — as does
  applying a change via the interactive consultation. The versioning rule must apply to all three
  paths, but the architecture only mentions one.
- **ADR note:** ADR-006 Consequences explicitly states *"Review Agent findings update `personas`
  and insert a `persona_system_prompt_versions` row only."* This confirms the Review Agent apply
  path is intended to trigger a version row insert — the behaviour is decided, just not stated in
  architecture.md Section 5.2. The interactive consultation apply path remains unaddressed by
  either document.
- **Resolution:** Extend the Section 5.2 note to make the rule universal: any write to
  `personas.system_prompt` — whether via PATCH endpoint, finding application, or
  consultation-mode application — must insert a corresponding `persona_system_prompt_versions`
  row in the same transaction. This is consistent with the F-1 resolution, where the stale-finding
  reconciliation step also writes to `personas.system_prompt` and must therefore follow the same
  rule.

---

**[F-17] Config keys referenced throughout the document but no schema is defined** *(Severity: Minor)*

- **Location:** Section 11 (absent); referenced throughout Sections 6.3, 7.2, 9.2, 10.5
- **Issue:** The architecture references `context_window`, `REVIEW_AGENT_SCHEDULE`,
  `ORCHESTRATOR_EVAL_EVERY_N`, `ORCHESTRATOR_THRESHOLD`, `ORCHESTRATOR_1TO1_THRESHOLD`,
  `MAX_P2P_TURNS`, `P2P_TURN_DELAY_SECONDS`, and the Context Panel character limit key — but
  Section 11 defines no schema for `backend/config.json`. A Backend Senior Developer cannot know
  the full set of expected keys, their types, or their defaults.
- **Resolution:** Add a Section 11.7 to architecture.md covering both backend and frontend config
  key schemas. The governing rule for both sides: if a sensible default is not obvious, the key is
  required with no default and must be set explicitly by the operator.

  **Backend (`backend/config.json`):**
  - **Required, no default:** `context_window` (model-dependent), `model`, `model_provider`,
    `model_base_url`, `database_url` — all depend on deployment choices the operator must set.
  - **Has sensible defaults:** `ORCHESTRATOR_EVAL_EVERY_N`, `MAX_P2P_TURNS`,
    `P2P_TURN_DELAY_SECONDS`, `REVIEW_AGENT_SCHEDULE`, `ORCHESTRATOR_THRESHOLD`,
    `ORCHESTRATOR_1TO1_THRESHOLD`, repetition hash window size, and repetition similarity
    threshold.
  - **Secret, override-only, no default in committed file:** `api_key`.
  - **Context Panel character limit:** exposed via API rather than duplicated in frontend config
    (see below) — kept as a backend config key only.
  The specific default values for the "has sensible defaults" group are left to the Backend Senior
  Developer to size against the implementation.

  **Frontend (`frontend/config.json`):**
  - **Required, no default:** `api_base_url` — deployment-specific, must be set in
    `frontend/config.override.json`.
  - **Context Panel character limit:** the backend exposes this value via API (e.g. embedded in
    the workspace or conversation response, or via a dedicated `GET /config` endpoint) so the
    frontend always reflects what the backend actually enforces. No frontend config key is needed,
    avoiding a genuinely shared key that would need manual synchronisation between the two config
    files (consistent with the F-14 resolution).

---

**[F-18] Incorrect cross-reference in Section 8.2 points to wrong section of overview.md** *(Severity: Minor)*

- **Location:** Section 8.2
- **Issue:** The parenthetical "(see FR-7 of Section 7 of overview)" is not resolvable. Section 7
  of overview.md is the Review Agent section. The relevant section is overview.md §8.2 (Mentor
  Configuration). Additionally, "FR-7" is not a numbering scheme used anywhere in overview.md,
  making the reference doubly broken.
- **Resolution:** Replace the parenthetical with the correct reference: "(see overview.md §8.2)".
  One-line fix only.
