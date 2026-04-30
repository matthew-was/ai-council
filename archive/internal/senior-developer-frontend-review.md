# Senior Developer Review — API Requirements (Frontend)

**Document reviewed**: `documentation/tasks/api-requirements-frontend.md`
**Review date**: 2026-04-23
**Reviewer**: Senior Developer (Frontend)

---

## Completeness

### Feature area coverage

| Feature area | Covered | Notes |
| --- | --- | --- |
| General API requirements (base URL, errors, auth, CORS, OpenAPI spec) | Yes | All covered in opening section |
| Workspaces (list, get, create, rename, delete, switch) | Yes | US-W1 through US-W4 |
| Personas (list, get, create, update, delete) | Yes | US-P1 through US-P4 |
| Persona temperature | Yes | Covered under Persona create/update (field: `temperature`) |
| Persona Test / Preview mode | Yes | US-P5 — ephemeral session, streaming preference flagged |
| Start Conversation (mode selection, Persona selection, Folder) | Yes | US-C1, US-C2 |
| Add/Remove Personas mid-Conversation | Yes | US-C3 |
| Switch Conversation mode mid-Conversation | Yes | US-C4 — covered under Conversation update |
| Refresh Persona snapshot | Yes | US-C5 |
| Pin / Unpin Conversation | Yes | US-C6 — covered under Conversation update (`pinned_at`) |
| Context Panel (maintain, character limit) | Yes | US-CP1 — covered under Conversation update |
| Context Panel from targeted summary | Yes | US-CP2 — this is a UI-only flow triggered by the `@Orchestrator` response; no separate API call needed; confirmed not flagged as a gap |
| Orchestrator suggestions (receive, accept, dismiss) | Yes | US-O1 — SSE event `orchestrator_suggestion` + accept/dismiss protocol flagged as concern FC-8 |
| Targeted summary via `@Orchestrator` | Partially | US-O2 — a targeted summary is requested by the user via a regular message (`@Orchestrator` text), which goes through `POST /conversations/{id}/messages`. The response arrives on the SSE stream as a `response_complete` event like any other Persona/Orchestrator response. No separate endpoint is needed. This is correct — no gap. |
| P2P `@Orchestrator` pause | Yes | US-O3 — `exchange_paused` event + pause/resume control signals covered |
| End Conversation | Yes | US-L1 |
| Automatic summary | Yes | US-L2 — FC-1 flagged for delivery mechanism |
| Canonise placeholder | Yes | US-L3 — this is purely a frontend UI placeholder with no API call. Correctly omitted from API requirements. |
| Generate Report | Yes | US-R1 — FC-3 flagged for delivery mechanism |
| Manage Reports (list, view, rename, export, delete) | Yes | US-R2 — export is a client-side action on `content_markdown`; no separate endpoint needed |
| Export Conversation as raw Markdown | Yes | US-R3 — export is a client-side action on the messages list; no separate endpoint needed beyond the messages list |
| Review Agent run status | Yes | US-RA1, US-RA2 |
| Manual trigger | Yes | US-RA2 |
| View and act on findings (apply, dismiss) | Yes | US-RA3 — FC-7 flagged for finding schema |
| Interactive consultation | Yes | US-RA4 |
| Review Agent Mentor analysis | Yes | US-RA5 — Mentor findings use the same findings endpoint with the Mentor's `persona_id`; covered |
| Create Mentor | Yes | US-M1 — covered via Persona create with `is_mentor: true` |
| Configure Mentor System Prompt | Yes | US-M2 — covered via Persona update |
| Use Mentor Conversation | Yes | US-M3 — FC-2 flagged for discovery mechanism |
| Start new chapter | Yes | US-M4 — dedicated chapter endpoint described |
| Memory Inspector (Episodic, Semantic) | Yes | US-M5 |
| Working Memory compression (system behaviour) | Yes | US-MM1 — backend side-effect of chapter/session-end; frontend only triggers via chapter endpoint or session-end signal (FC-5) |
| Episodic window and Semantic promotion | Yes | US-MM2 — backend side-effect; no frontend API requirement beyond Memory Inspector read endpoints |
| Configure AI model endpoint | Not in scope | US-AI1 is configuration-file only (no API call); correctly omitted |
| User ID in data model | Not in scope | US-DM1 is a backend/data model concern; correctly omitted |
| Persona version history readiness | Partially | US-DM2 — the requirement that the backend records `persona_system_prompt_versions` in the same transaction as a Persona update is called out in the Persona update section. This is the correct extent of frontend involvement. |

### Phase 1 user stories with no API requirement (correctly omitted)

- US-L3 Canonise placeholder — UI only, no API call
- US-R3 Conversation export — client-side render of fetched messages
- US-AI1 Model configuration — config file only
- US-DM1 User ID — data model only
- US-MM1/MM2 Memory compression/promotion — backend side-effects

All omissions are justified.

---

## Consistency

- All API call descriptions are consistent with the approved architecture. No endpoint is described that contradicts an ADR.
- The SSE event types (`token`, `response_complete`, `orchestrator_suggestion`, `busy`, `idle`, `paused`, `exchange_paused`) match exactly the named event types in architecture section 10.2.
- The `pause_reason` enum values (`user_pause | turn_cap | repetition_detected`) match architecture section 10.2 and ADR-017 exactly.
- The P2P recovery paths (message POST for `turn_cap`/`repetition_detected`, resume POST for `user_pause`) match architecture section 10.3 exactly.
- UUID v7 for primary keys is consistent with architecture section 5.8 — the cursor-based pagination recommendation correctly notes UUID v7's time-ordered property.
- The `is_mentor` flag on Personas is consistent with the `personas` table schema in architecture section 5.2.
- The `conversation_personas` snapshot fields (`snapshot_name`, `snapshot_system_prompt`, `snapshot_temperature`, `joined_at`, `left_at`) are consistent with architecture section 5.2.
- The three-layer memory (Working/Episodic/Semantic) aligns with architecture sections 8.1–8.2.
- `roles` enum (`user | persona | mentor | system`) is consistent with architecture section 5.3.

One minor inconsistency to note: the architecture section 5.3 lists `conversation_summaries` as a separate table (not a field on `conversations`). The API requirements do not ask for a separate summary endpoint — the summary is requested as part of the Conversation detail response. This is architecturally valid (the backend can join the summary into the Conversation response), but the contract should confirm this.

---

## Ambiguity

The following areas could be implemented in more than one way without further guidance. All have been captured as flagged concerns in the document:

1. **FC-1** (Auto-summary delivery) — synchronous vs. asynchronous. Preference expressed clearly.
2. **FC-2** (Mentor Conversation discovery) — dedicated endpoint vs. list filter. Preference expressed clearly.
3. **FC-3** (Report generation delivery) — synchronous vs. asynchronous. Preference expressed clearly.
4. **FC-4** (Chapter marker differentiation) — `message_subtype` vs. conventional content. No preference expressed beyond "needs to be defined."
5. **FC-5** (Mentor session-end signal) — explicit POST vs. stream disconnect. No preference expressed; both are valid.
6. **FC-6** (Test session streaming mechanism) — SSE preference expressed.
7. **FC-7** (Finding schema) — minimum fields specified; backend to define the rest.
8. **FC-8** (Orchestrator suggestion accept/dismiss) — two patterns described; no preference expressed.

No other ambiguities identified.

---

## Scope Gaps

No scope gaps identified. All Phase 1 user stories are covered, either by an explicit API requirement or by a justified omission (where the requirement is UI-only or configuration-only).

---

## Minor Issues

1. The `conversation_summaries` table (a separate row per Conversation) is not surfaced as a separate endpoint in the requirements. The rolling summary is needed only for context window management (backend) and the end-of-conversation auto-summary (frontend). The frontend only needs the auto-summary as part of the Conversation detail response. This is correct — no gap.

2. The `persona_system_prompt_versions` table is write-only from the frontend's perspective (the frontend triggers writes via Persona update). No read requirement is stated. This is correct for V1 — there is no version history UI in V1 (US-DM2).

3. The documents section states `content_markdown` is not needed in the list response. This is correct and consistent with efficient list API design.

4. The Folder delete response note (preferred: return list of unassigned Conversation IDs) is a frontend preference that may impose additional backend work. It is correctly flagged as a preference, not a hard requirement.

---

## Verdict

The document is complete, consistent with the approved architecture, and has no scope gaps. All ambiguities are captured as flagged concerns for the backend to resolve in the contract. The document is ready for developer review and approval.
