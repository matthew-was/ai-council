# Senior Developer (Backend) — Self-Review: API Contract

**Document reviewed**: `documentation/tasks/api-contract.md`
**Review date**: 2026-04-27
**Reviewer**: Senior Developer (Backend) agent

---

## 1. Completeness

### 1.1 User story coverage

Every Phase 1 user story with backend API implications is traced below. Stories whose backend work is purely internal (no new endpoint) are noted as such.

| Story | Backend concern | Covered in contract |
| --- | --- | --- |
| US-W1 | POST /workspaces | Yes |
| US-W2 | PATCH /workspaces/{id} | Yes |
| US-W3 | DELETE /workspaces/{id} (cascade spec) | Yes |
| US-W4 | Workspace-switch interrupt, resume endpoint | Yes — POST /resume handles this; `paused` SSE event documented |
| US-P1 | POST /workspaces/{id}/personas | Yes |
| US-P2 | Temperature field on Persona create/update | Yes |
| US-P3 | PATCH /workspaces/{id}/personas/{id} | Yes |
| US-P4 | DELETE /workspaces/{id}/personas/{id}, blocking_conversations body | Yes |
| US-P5 | POST /personas/{id}/test, SSE stream | Yes |
| US-C1 | POST /workspaces/{id}/conversations | Yes |
| US-C2 | folder_id on create and PATCH conversation | Yes |
| US-C3 | POST/DELETE conversation personas, system messages | Yes |
| US-C4 | mode field on PATCH conversation, system message | Yes |
| US-C5 | POST .../personas/{cpid}/refresh | Yes |
| US-C6 | pinned_at on PATCH conversation | Yes |
| US-CP1 | context_panel on PATCH conversation, CONTEXT_PANEL_MAX_CHARS | Yes |
| US-CP2 | auto_summary field (key_takeaways usable for one-click copy) | Yes — no additional endpoint needed; frontend assembles from returned summary |
| US-O1 | orchestrator_suggestion SSE event, accept/dismiss endpoints, suggestion_id | Yes |
| US-O2 | @Orchestrator parsing is graph-internal; no dedicated endpoint | Implicit — no endpoint required; Orchestrator behaviour is documented in SSE events |
| US-O3 | POST /pause, POST /resume; exchange_paused SSE event | Yes |
| US-L1 | POST /end (two-outcome), P2P in-flight handling | Yes — gap noted in section 4.6 |
| US-L2 | auto_summary on ended Conversation, async generation | Yes |
| US-L3 | Canonise placeholder is frontend-only; no backend endpoint needed | Confirmed in api-requirements-frontend.md |
| US-R1 | POST /documents/generate, 409 for duplicate | Yes |
| US-R2 | GET/PATCH/DELETE /documents, list filtering by conversation | Yes |
| US-R3 | GET /conversations/{id}/export | Yes |
| US-RA1 | Internal nightly scheduler; no API needed beyond status/run endpoints | Yes |
| US-RA2 | POST /review-agent/run | Yes |
| US-RA3 | GET/POST findings (apply/dismiss) | Yes |
| US-RA4 | POST /personas/{id}/consultation (SSE stream) | Yes |
| US-RA5 | Mentor treated identically to standard Persona in findings | Yes — findings endpoints work for Mentor persona_id |
| US-M1 | POST /personas with is_mentor:true, MENTOR_ALREADY_EXISTS, MENTOR_NAME_IMMUTABLE, MENTOR_CANNOT_BE_DELETED | Yes |
| US-M2 | system_prompt field on Persona, immediate effect via live prompt | Yes |
| US-M3 | is_mentor_conversation flag, Mentor Conversation participants empty | Yes |
| US-M4 | POST /chapter, chapter_prompt_required on GET conversation, chapter_boundary subtype | Yes |
| US-M5 | GET /memory/episodic, GET /memory/semantic | Yes |
| US-MM1 | Working Memory compression is graph-internal; chapter endpoint triggers as side-effect | Documented in chapter endpoint Notes |
| US-MM2 | Episodic to Semantic promotion runs on schedule; no API | Resolved in FC-5 — no frontend signal |
| US-AI1 | CONTEXT_PANEL_MAX_CHARS on Workspace response; configuration is backend-internal | Yes |
| US-DM1 | user_id in data model; V1 fixed default | Noted in data model summary |
| US-DM2 | persona_system_prompt_versions insert on every write | Yes — noted on create and PATCH persona |

All 40 user stories are addressed. No story has been silently dropped.

### 1.2 Frontend API requirements coverage

All sections of `api-requirements-frontend.md` are covered:

| FR requirement | Contract section |
| --- | --- |
| Base URL / configurable | Authentication section note |
| Content-Type | Authentication section |
| Error response shape | Error Response Shape section |
| Auth V1 stub | Authentication section |
| CORS | Authentication section |
| OpenAPI spec availability | Implementation detail — not a contract concern |
| All Workspace endpoints | Workspaces section |
| CONTEXT_PANEL_MAX_CHARS | Embedded in all Workspace responses |
| All Persona endpoints | Personas section |
| Persona test session | Persona Test section |
| All Conversation endpoints | Conversations section |
| All Message endpoints | Messages section |
| All Folder endpoints | Folders section |
| All Document endpoints | Documents section |
| Review Agent status/run | Review Agent section |
| Findings list/apply/dismiss | Review Agent section |
| Interactive consultation | Review Agent section |
| Mentor chapter | Mentor Conversation section |
| Episodic/Semantic memory | Mentor Memory Inspector section |
| SSE stream endpoint | SSE Streaming section |
| All 7 SSE event types | SSE Event Types section |
| Orchestrator accept/dismiss | Orchestrator Suggestion Responses section |
| Pause/resume/cancel | Conversation Control Signals section |
| Message cursor pagination | Messages section |
| Findings list filter (active/stale only) | Findings endpoint Notes |
| Documents filter by source_conversation_id | Documents section — query param |
| FC-1 through FC-8 all resolved | Flagged Issues table at contract end |

No frontend requirement from `api-requirements-frontend.md` is missing.

---

## 2. Consistency

### 2.1 Endpoint path consistency

All Workspace-scoped endpoints follow `/workspaces/{workspace_id}/...`. Exceptions are documented:

- `GET /conversations/{id}/stream` — not workspace-scoped in the path; reason documented in Notes.
- `POST /conversations/{id}/pause`, `POST /conversations/{id}/resume`, `POST /conversations/{id}/cancel` — not workspace-scoped; same pattern as stream endpoint (control signals keyed by conversation_id only).
- `POST /personas/{persona_id}/test` — not workspace-scoped in path; reason documented in Notes.
- `POST /conversations/{id}/suggestions/{suggestion_id}/accept|dismiss` — not workspace-scoped; suggestion is keyed by conversation.

**Minor gap**: The contract's workspace-scoping note only appears on the stream endpoint. The same explanation applies to the four control signal endpoints and the two suggestion endpoints but is not restated there. This is a documentation gap; it does not affect API correctness. The implementation plan must address workspace context resolution uniformly for all non-workspace-scoped endpoints.

### 2.2 Type name consistency

- `conversation_persona_id` is used consistently throughout (participants, remove, refresh, token SSE event).
- `message_subtype` values are consistently past-tense: `persona_joined`, `persona_left`, `chapter_boundary`, `orchestrator_suggestion_accepted`, `mode_changed`.
- `auto_summary` is consistently nullable on all Conversation response shapes.
- `is_mentor_conversation` is consistently present on list and detail Conversation responses.
- `context_panel_max_chars` is consistently present on all four Workspace response shapes (list, get, create, patch).

### 2.3 HTTP method consistency

- All creation endpoints use `POST` returning `201 Created`.
- All update endpoints use `PATCH` returning `200 OK`.
- All delete endpoints use `DELETE` returning `204 No Content`, except:
  - `DELETE /folders/{id}` returns `200 OK` with `unassigned_conversation_ids`. Deliberate design choice; documented in Notes.
  - `POST /conversations/{id}/end` returns `200 OK` with a discriminated body. Correct and documented.
- All trigger/action endpoints use `POST`.

### 2.4 Error code consistency

All error codes are `SCREAMING_SNAKE_CASE`. The full set defined in the contract is:

- `PERSONA_ACTIVE_IN_CONVERSATION`
- `MENTOR_ALREADY_EXISTS`
- `MENTOR_NAME_IMMUTABLE`
- `MENTOR_CANNOT_BE_DELETED`
- `LAST_PERSONA_IN_CONVERSATION`
- `CONVERSATION_NOT_IDLE`
- `CONVERSATION_BUSY`
- `CONVERSATION_NOT_PAUSED`
- `CONTEXT_PANEL_TOO_LONG`
- `REPORT_GENERATION_IN_PROGRESS`
- `REVIEW_AGENT_ALREADY_RUNNING`
- `FINDING_NOT_ACTIVE`
- `SUGGESTION_ALREADY_RESOLVED`
- `INVALID_MODE_FOR_PARTICIPANT_COUNT`

Complete and consistent. No error condition in the contract is left without a code.

---

## 3. Ambiguity

### 3.1 Workspace context for non-workspace-scoped endpoints

**Issue**: `GET /conversations/{id}/stream`, `POST /conversations/{id}/pause`, `POST /conversations/{id}/resume`, `POST /conversations/{id}/cancel`, `POST /conversations/{id}/suggestions/{id}/accept`, and `POST /conversations/{id}/suggestions/{id}/dismiss` are not under `/workspaces/{workspace_id}/`. The workspace-scoping note appears only on the stream endpoint.

**Impact**: The implementation plan must define a single consistent mechanism (e.g. `X-Workspace-ID` header or query parameter) for all six endpoints. The contract correctly defers this to the plan.

**Severity**: Low — both parties agree conversation_id is sufficient for routing. Implementation detail.

### 3.2 Mentor `conversation_persona_id` in SSE token events

**Issue**: The `token` and `response_complete` SSE events carry `conversation_persona_id` to identify the speaker. For the Mentor Conversation, there is no `conversation_personas` row. The contract states: "the `conversation_persona_id` value is a stable identifier derived from the Mentor Persona ID — the implementation plan must define this."

**Impact**: The frontend cannot implement Mentor stream rendering until this format is defined. The implementation plan must resolve the format and the decision must be communicated to the frontend team before they implement the Mentor stream.

**Severity**: Medium — cross-team dependency. Deferred to implementation plan; contract note is clear.

### 3.3 `@Orchestrator` detection is server-side

**Issue**: US-O2 and US-O3 rely on the user typing `@Orchestrator`. The contract does not explicitly state that this detection is server-side within the LangGraph graph.

**Impact**: Could be misread as requiring frontend preprocessing. A clarifying note on `POST /messages` would remove any ambiguity.

**Severity**: Low.

### 3.4 Persona test session workspace resolution

**Issue**: `POST /personas/{persona_id}/test` is not under a workspace path. The contract states workspace scoping is enforced by the ORM listener but does not explicitly confirm the mechanism applies here.

**Severity**: Low — implementation detail to confirm in plan.

---

## 4. Scope Gaps

### 4.1 `POST /end` behaviour during an active P2P exchange

**Issue**: US-L1 states that ending a Conversation during an autonomous P2P exchange pauses the exchange first, then ends. The contract's Notes section for `POST /end` does not address this case. The frontend needs to know whether it must call `POST /cancel` before `POST /end`, or whether `POST /end` handles this internally.

**Impact**: If the frontend must call cancel first, this is a required two-step flow not documented in the contract. If the backend handles it internally, the frontend calls `POST /end` as a single action.

**Recommended addition to `POST /end` Notes**: "If a P2P autonomous exchange is in progress when this endpoint is called, the backend cancels the exchange internally before proceeding with the end-of-conversation flow. The frontend calls `POST /end` as a single action regardless of Conversation state."

**Severity**: Medium — must be resolved before implementation.

### 4.2 Conversation auto-naming side-effect (US-O2)

**Issue**: When the first targeted summary is generated via `@Orchestrator`, the Conversation is auto-named if it has not been manually named. The contract has no SSE event for a title change. The frontend discovers the new name only on the next `GET /conversations/{id}`.

**Impact**: The frontend will display the default title (`"New Conversation [timestamp]"`) until it re-fetches the Conversation. This is acceptable but should be stated in the contract so the frontend knows not to expect a push notification.

**Severity**: Low — implementation plan should note; no contract endpoint change needed.

### 4.3 No workspace-level findings aggregate

Per-Persona findings only. No story requires a cross-Persona view. Intentional and correct.

### 4.4 No Report export endpoint

US-R2 specifies Report export as Markdown. The frontend assembles the download from `content_markdown` client-side. No dedicated export endpoint is needed. Consistent with the Conversation export pattern. Correct.

### 4.5 `chapter_prompt_required` UTC comparison

The contract states comparison is relative to today in UTC. The implementation plan must confirm UTC is used consistently. Not a contract gap.

---

## 5. Summary Assessment

**Items that must be addressed before developer approval:**

1. **Section 4.1 — `POST /end` during P2P exchange**: Add one sentence to the `POST /end` Notes clarifying that the backend cancels an in-progress P2P exchange internally, so the frontend calls `POST /end` as a single action.

**Items deferred to the implementation plan (non-blocking for contract approval):**

- 3.1 — Workspace context mechanism must be documented uniformly in the plan.
- 3.2 — Mentor `conversation_persona_id` format must be defined in the plan and communicated to the frontend team.
- 3.3 — Note that `@Orchestrator` detection is entirely server-side should be added to the plan.
- 3.4 — ORM workspace isolation coverage for the test endpoint must be confirmed in the plan.
- 4.2 — Auto-naming side-effect: plan must document no SSE event; frontend re-fetches to discover new title.

**Overall assessment**: The contract is substantively complete and consistent. One sentence needs to be added to resolve the P2P/end interaction ambiguity. After that addition, the contract is ready for developer approval.
