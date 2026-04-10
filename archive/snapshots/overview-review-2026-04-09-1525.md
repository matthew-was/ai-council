# Overview Review

## Status: All Items Resolved

All contradictions, missing information items, undocumented edge cases, and ambiguities identified in the initial review have been resolved by the developer. The decisions have been incorporated directly into `documentation/project/overview.md`.

---

## Resolution Summary

### Contradictions

- **C1 — Deleted Conversation vs. linked Review Agent findings:** Resolved. Section 7.3 updated. Findings now embed evidence inline by quoting or describing the relevant exchange. There is no navigable link to the source Conversation. Deletion of a Conversation does not affect findings.

- **C2 — Mentor "cannot be deleted" constraint scope:** Resolved. Section 8.1 updated to clarify the constraint applies to standalone deletion within the Personas area. The Mentor is removed as part of a full Workspace deletion — this is not a contradiction.

- **C3 — Peer-to-Peer feasibility and mode selection UI:** Resolved. The fallback sentence has been removed from Section 5.2. Peer-to-Peer is a V1 feature. The research caveat note is retained.

### Missing Information

- **M1 — Mentor chapter prompt threshold:** Resolved. Section 8.4 updated. The inactivity threshold is one calendar day — defined as a change of date, not a 24-hour elapsed period.

- **M2 — Episodic Memory retention policy:** Resolved. Section 8.5 updated. The 30-day inactivity rule has been replaced with a rolling conversation-count window of N sessions. When the window is full, the oldest entry is retired. N is configurable and defined during architecture.

- **M3 — Automatic Summary persistence:** Resolved. Section 6.2 updated. The Automatic Summary is persisted as part of the ended Conversation and is always visible when the user returns to it.

- **M4 — Review Agent scheduling on local machine:** Resolved. Section 7.2 updated. The Review Agent runs on a fixed nightly schedule. If the system was not running, the run is skipped with no catch-up. The user can manually trigger a review via a "Run now" control in the Personas area.

- **M5 — Conversation ordering in sidebar:** Resolved. Section 3.1 updated. Within each sidebar section, Conversations are ordered by most recent activity (most recent first), with the exception of Pinned Conversations which are ordered by pin date.

- **M6 — Default Conversation name:** Resolved. Section 3.2 updated. A new Conversation is named "New Conversation [timestamp]". If not manually renamed, the system auto-generates a name on first summarisation.

- **M7 — Context Panel length limit scope:** Resolved. Section 5.3 updated. The maximum length is a global configuration variable derived from the deployed model's context window capacity.

- **M8 — Persona Test session behaviour:** Resolved. Section 4.5 updated. The Test panel maintains a short back-and-forth session, allowing follow-up messages and iterative refinement of the System Prompt.

### Undocumented Edge Cases

- **E1 — Starting a Conversation with no Personas:** Resolved. Section 5.1 updated. Clicking "New Conversation" with no Personas shows a prompt directing the user to create one first. The button is always accessible.

- **E2 — Deleting a Persona active in an open Conversation:** Resolved. Section 4.2 updated. A Persona cannot be deleted while active in an open Conversation. A warning is shown identifying the affected Conversations.

- **E3 — Deleted Conversation and findings:** Resolved by C1 decision. No additional change needed.

- **E4 — Proactive Mentor chapter:** Resolved. Section 8.4 updated. The user can manually start a new chapter at any time via a dedicated control, independently of the inactivity prompt.

- **E5 — Limits on Workspaces, Personas, Conversations, and Folders:** Resolved. Added as Section 9.8 (Future Considerations). Configurable limits are a future feature to support resource management and multi-user deployments.

- **E6 — Ending a Conversation with no messages:** Resolved. Section 5.5 updated. Triggering "End Conversation" on an empty Conversation deletes it rather than creating an empty ended record.

- **E7 — Review Agent findings after apply vs. dismiss:** Resolved. Section 7.3 updated. Applying a finding and having the issue recur produces a new finding. Dismissing a finding is treated as a deliberate user preference and the same type of suggestion is not resurfaced for that Persona.

### Ambiguities

- **A1 — Orchestrator trigger logic across modes:** Resolved. Sections 5.2 and 5.4 updated. The Orchestrator's suggestions are driven by Conversation topic. In 1:1 mode, a higher threshold is applied before suggesting an additional Persona.

- **A2 — Context Panel eviction priority:** Resolved. Section 5.3 updated. Older Conversation messages are dropped before the Context Panel is affected. The Context Panel is the last element to be evicted.

- **A3 — Targeted summary trigger mechanism:** Resolved. Section 6.3 updated. The Orchestrator detects targeted summary requests from natural language. The user can also address the Orchestrator directly using `@Orchestrator`.

- **A4 — Review Agent consultation UI:** Resolved. Section 7.4 updated. The consultation interface is an expandable right-hand panel in the Personas area, visible when a Persona is selected. The Review Agent is a distinct system component, not a user-created Persona.

- **A5 — Mentor control restrictions in UI:** Resolved. Section 8.1 updated. Rename and delete controls for the Mentor are shown as disabled with a tooltip explaining they are not available for the Mentor.

- **A6 — Sidebar ordering — Pinned vs Folders:** Resolved. Section 3.1 updated. Folders appear at the top. Pinned Conversations appear below Folders, ordered by pin date (most recently pinned first). Standalone Conversations appear below Pinned, ordered by most recent activity.
