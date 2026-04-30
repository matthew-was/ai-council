# Implementation Plan Review

**Date produced:** 2026-04-28
**Documents reviewed:**
- `documentation/tasks/senior-developer-backend-plan.md`
- `documentation/tasks/senior-developer-frontend-plan.md`
**Reviewed against:** `documentation/project/architecture.md`

---

## Overall Verdict

Both plans are substantially complete and largely consistent with the architecture and with each other. Twelve issues were identified, grouped below by severity. Items in **Section 1 (Blockers)** must be resolved before the plans are approved for task decomposition. Items in **Section 2 (Cross-Plan Misalignments)** are straightforward fixes. Items in **Section 3 (Minor Details)** can be resolved at implementation time.

---

## 1. Blockers

These four items represent genuine gaps or ambiguities that could cause incorrect implementation if left unresolved.

### B-1 — Backend: Review Agent reconciliation step incomplete

**Location:** Backend plan Section 9.3 (Review Agent — Reconciliation)

**Issue:** The plan describes the reconciliation step as checking whether `target_passage` is still present in the current `system_prompt` and setting the finding to `stale` if not. This covers only the staleness detection case. The architecture (Section 5.5) requires two additional outcomes from the reconciliation step:

- **Issue resolved:** If the underlying issue no longer appears in recent Conversations, the finding should be dropped entirely (deleted or set to `dismissed`).
- **Passage moved:** If the issue persists but the passage has changed (e.g. the user manually edited the System Prompt), the Review Agent should update `target_passage` and `suggestion_text` to match the current System Prompt rather than simply marking the finding stale.

The apply endpoint relies on the guarantee that `target_passage` is always valid — this guarantee comes from reconciliation. Without the update-passage logic, that guarantee does not hold.

**Resolution needed:** Backend plan Section 9.3 must be updated to document all three reconciliation outcomes: drop (issue resolved), update (issue persists, passage moved), and stale (issue persists, passage gone without a clear replacement).

---

### B-2 — Backend/Frontend: Workspace-switch resume flow ambiguous

**Location:** Backend plan Section 10.6 / Frontend plan Section 8.4

**Issue:** The two plans describe the workspace-switch resume flow in ways that are not clearly reconciled:

- The **backend plan** (Section 10.6) states that after detecting no SSE listener, the graph sets `pause_requested = true` and routes to `await_user`. No SSE event is emitted at that point (no listener to receive it).
- The **frontend plan** (Section 8.4) states: *"If the backend emits a `paused` event immediately on stream open...the state transitions to `paused`."* This implies `paused` is emitted when the stream re-opens.

These are contradictory. If no event is emitted until the stream re-opens, the backend would need to emit `paused` immediately upon the client reconnecting — but neither plan specifies this handshake. The architecture (Section 10.6) says only that the user explicitly resumes via `POST /conversations/{id}/resume` on return, without specifying how the frontend knows to show the Resume button.

**Resolution needed:** Both plans must agree on the exact protocol:
- Option A: On stream re-open, the backend immediately emits a `paused` event if the conversation is in a paused state. The frontend renders the Resume button. The user calls `/resume`. The graph resumes and emits `busy`/`idle`.
- Option B: The frontend checks `GET /conversations/{id}` on navigation to the conversation. If `status` indicates paused state, it shows the Resume button before opening the stream. The stream is then opened after `/resume` is called.

The chosen option must be stated consistently in both plans.

---

### B-3 — Backend: Workspace-switch interrupt detection mechanism unclear

**Location:** Backend plan Section 6.6 (SSE Manager / Workspace-switch interrupt)

**Issue:** The plan mentions the SSE manager's `has_listener()` method but does not specify where in the graph this check is performed. The architecture (Section 10.6) states: *"After the in-flight response completes, the graph checks for an active SSE listener on this Conversation. Finding none, it sets `pause_requested = true`."* This implies the check is inside a LangGraph conditional edge or post-response node — not a polling mechanism running outside the graph.

The current plan description is ambiguous: it could be interpreted as:
- A conditional edge at the end of each Persona response node (inside the graph), or
- A separate asyncio task polling `has_listener()` after each response (outside the graph).

These have materially different implementations and different edge-case behaviours (e.g. race conditions if the client reconnects mid-response).

**Resolution needed:** The backend plan must specify exactly where `has_listener()` is called — inside a LangGraph node/edge or outside — and how the call result feeds into `pause_requested` being set.

---

### B-4 — Backend: Repetition detection algorithm underspecified

**Location:** Backend plan Section 6.9 (P2P — Repetition-hash throttle)

**Issue:** The plan describes two distinct concepts without clearly separating them:

1. A SHA256 hash of the raw response text (exact match).
2. A character-normalised or similarity-based comparison (near-match, using Jaccard or Hamming distance).

The plan stores hashes in the LangGraph state but then describes comparing via similarity threshold — it is not clear which is stored, which is computed at comparison time, or how a similarity threshold applies to a hash. If the intent is fuzzy matching (the architecture says "near-match"), then storing a SHA256 hash and comparing hashes would only detect exact duplicates, not near-duplicates.

**Resolution needed:** The backend plan must define:
- What is stored per response in the rolling window (raw hash, normalised text, a shingle set, or similar).
- What comparison algorithm is used (`P2P_REPETITION_THRESHOLD` implies a continuous similarity score, not a binary hash match).
- Whether the threshold applies to a similarity score (e.g. Jaccard ≥ 0.85) or an edit distance.

---

## 2. Cross-Plan Misalignments

These items are inconsistencies between the two plans that require one or both plans to be updated for alignment. They are straightforward fixes.

### M-1 — Mentor `conversation_persona_id` format

**Location:** Backend plan Section 8.5 / Frontend plan Section 6.5

**Issue:** The backend plan defines the Mentor's synthetic `conversation_persona_id` in SSE `token` events as the string `"mentor:{persona_id}"` (a prefixed string). The frontend plan describes handling this by *"checking whether the value matches the Mentor Persona's ID"* — implying a direct UUID equality check, which would not match the prefixed string format.

**Resolution needed:** The frontend plan must be updated to parse the `"mentor:{persona_id}"` format (strip the prefix to extract the persona ID for display name lookup), rather than performing a direct equality check.

---

### M-2 — Test and Consultation endpoint workspace context

**Location:** Backend plan Section 4.3 / Frontend plan Open Question 2 and 3

**Issue:** The backend plan defines a PK-lookup bootstrap mechanism for non-workspace-scoped endpoints (including `POST /personas/{id}/test`, `POST /personas/{id}/consultation`, `GET /conversations/{id}/stream`, and the control signal endpoints). The frontend plan correctly identifies this as an open question but defers it.

Now that the backend plan has defined the mechanism, the frontend plan must be updated to specify how `apiClient` and the SSE client pass workspace context for these endpoints (e.g. whether an `X-Workspace-ID` header, a query parameter, or another mechanism is used, per the backend plan's chosen approach).

**Resolution needed:** Frontend plan Sections 5.1 (apiClient), 6.1 (sse.ts), and 9.3 (ConsultationPanel) must document the agreed workspace context mechanism once confirmed from the backend plan.

---

## 3. Minor Details

These items are small gaps or under-specified details that do not block implementation but should be resolved either before approval or early in the implementation sprint.

### D-1 — Backend: Consultation mode system prompt versioning

**Location:** Backend plan Section 9.7

**Issue:** The plan describes consultation-mode suggestion application but does not explicitly state that it follows the universal system prompt versioning rule (insert a `persona_system_prompt_versions` row in the same transaction). The plan implies it via the `update_system_prompt()` helper but should state it explicitly.

---

### D-2 — Backend: `@Orchestrator` mention case-sensitivity

**Location:** Backend plan Section 6.8

**Issue:** The plan specifies `content.lstrip().startswith("@Orchestrator")` but does not state whether the check is case-sensitive. If the user types `@orchestrator`, the behaviour is undefined.

---

### D-3 — Backend: P2P `p2p_turn_count` reset timing

**Location:** Backend plan Section 6.10

**Issue:** The plan states `p2p_turn_count` resets to 0 "only when recovering from `repetition_detected`." The architecture (Section 10.5) implies the turn cap and repetition recovery are both via user message. It should be clarified whether `p2p_turn_count` resets on every user message in P2P mode or only on recovery from specific pause states — this affects how quickly the hard cap re-triggers after the user continues.

---

### D-4 — Frontend: Stale finding visual treatment and wording

**Location:** Frontend plan Section 10.1

**Issue:** The plan states stale findings are rendered "visually distinct" with no Apply/Dismiss controls, and that a prompt to run the Review Agent is shown. The exact visual treatment (opacity, colour, badge) and the wording of the prompt are not specified. These are implementation decisions, but the wording should be agreed before the UI task is written to avoid back-and-forth.

---

### D-5 — Frontend: `target_passage` visibility in finding cards

**Location:** Frontend plan Section 10.1

**Issue:** The plan shows `FindingCard` displaying `evidence_text` and `suggestion_text` but does not mention `target_passage`. The architecture (Section 5.5) defines `target_passage` as the specific excerpt from the current System Prompt to be replaced. It is not specified whether the frontend should display this field to the user (so they can see what part of the System Prompt will be changed) or keep it as a backend-only field used only during Apply.

---

### D-6 — Backend: ORM listener bind variable approach

**Location:** Backend plan Section 3.3

**Issue:** The plan states the listener "appends `WHERE workspace_id = :workspace_id`" but does not specify whether the injection uses SQLAlchemy's parameterised bind variable API or direct string interpolation. Parameterised binding is the correct approach; the plan should confirm this to prevent any ambiguity during implementation.

---

### D-7 — Backend: Episodic entries in Mentor context during pending promotion

**Location:** Backend plan Section 8.1

**Issue:** The plan's `AllEntriesRetriever` loads all episodic entries with no filter on `pending_promotion`. The architecture does not explicitly state whether entries currently pending Episodic→Semantic promotion should be included in the Mentor's context. Clarify whether `pending_promotion=True` entries appear in Mentor responses (they should, as they are valid episodic content awaiting extraction — not errors).

---

## Resolution Tracking

| ID | Area | Severity | Status |
| --- | --- | --- | --- |
| B-1 | Backend — Reconciliation step | Blocker | Resolved |
| B-2 (Frontend) | Frontend — Workspace-switch resume protocol | Blocker | Resolved |
| B-2 (Backend) | Backend — Workspace-switch resume protocol | Blocker | Resolved |
| B-3 | Backend — Interrupt detection mechanism | Blocker | Resolved |
| B-4 | Backend — Repetition detection algorithm | Blocker | Resolved |
| M-1 (Frontend) | Frontend — Mentor SSE ID format | Misalignment | Resolved |
| M-2 (Frontend) | Frontend — Test/Consultation workspace context | Misalignment | Resolved |
| M-2 (Backend) | Backend — Test/Consultation workspace context (`X-Workspace-ID` header) | Misalignment | Resolved |
| D-1 | Backend — Consultation versioning rule | Detail | Resolved |
| D-2 | Backend — @Orchestrator case-sensitivity | Detail | Resolved |
| D-3 | Backend — P2P turn count reset | Detail | Resolved |
| D-4 | Frontend — Stale finding UI | Detail | Open |
| D-5 | Frontend — target_passage display | Detail | Open |
| D-6 | Backend — ORM listener bind vars | Detail | Resolved |
| D-7 | Backend — Episodic entries in pending promotion | Detail | Resolved |
