# Overview Review

Fifth review pass. The document is substantially complete and well-structured. The issues below are the remaining items that would produce ambiguous or conflicting requirements if left unresolved.

---

## Contradictions

- **Orchestrator silence vs. higher-threshold in 1:1 mode.** Section 5.2 (Mode 1) and Section 5.4 both state the Orchestrator applies a "higher threshold" before suggesting a Persona in 1:1 mode, implying suggestions are still possible. Section 5.4 also states that when all Personas in the Workspace are already participating, the Orchestrator makes no suggestions at all. In a 1:1 Conversation where the sole Persona in the Workspace is the selected participant, both rules apply simultaneously — the Orchestrator would be completely silent yet the "higher threshold" language implies it remains suggestive. These two descriptions conflict in the case of a 1:1 Conversation with the only Workspace Persona.

- **Round-Robin Workspace-switch behaviour is underspecified relative to P2P.** Section 5.5 explicitly states that an autonomous P2P exchange pauses on Workspace switch and does not continue in the background. For Round-Robin, Section 5.5 states only that "any in-progress model response completes in the background." Round-Robin involves multiple sequential responses per cycle — the document does not state whether only the currently-generating response completes, or whether the full cycle completes in the background. This creates a gap that will produce conflicting interpretations when writing requirements for Round-Robin behaviour on Workspace switch.

---

## Missing information

- **Ordering of non-pinned Conversations within a Folder.** The sidebar ordering rules are fully specified for Standalone Conversations (most recent activity first) and for Pinned Conversations in a Folder (pin date, oldest first). The ordering of non-pinned Conversations inside a Folder is not stated. Requirements cannot be written for Folder-internal list rendering without this.

- **`@Orchestrator` availability and behaviour in Round-Robin mid-cycle.** Section 6.3 states that targeted summaries via `@Orchestrator` are available "at any point during an active Conversation" without mode restriction. Section 5.4 states that `@Orchestrator` in P2P pauses the autonomous exchange. The document does not describe what happens when a user invokes `@Orchestrator` in Round-Robin mode mid-cycle (e.g., Persona A and B have responded, Persona C is still pending). Does the Orchestrator respond immediately and interrupt the cycle? Does it wait for the current cycle to complete? This must be defined to write clear requirements.

- **Save mechanism for Persona System Prompt.** Section 4.5 states the Test panel "is disabled while the user has unsaved edits in the System Prompt editor." The document does not describe how the System Prompt is saved — whether the save is automatic (e.g., on blur or on change) or requires an explicit user action (e.g., a Save button). This determines when the Test panel becomes re-enabled and is needed for requirements on the Persona configuration UI.

- **Report-to-Conversation link state for concluded (non-deleted) Conversations.** Section 3.2 states that a deleted Conversation's link from its Report "will no longer resolve." Section 6.4 states Reports are "linked back to the source Conversation." The document does not explicitly state whether the link is navigable for Conversations that are ended but not deleted. This is likely the intended "happy path" but is unconfirmed and should be stated to avoid requirement gaps.

- **New Mentor with no prior content and the chapter prompt.** Section 8.4 states the chapter prompt appears when the user returns on a different calendar day. The document does not specify whether the prompt appears if the Mentor Conversation has no prior content — i.e., the Mentor was configured but no messages were ever sent, and the user opens it on a subsequent day. Clarification is needed.

---

## Undocumented edge cases

- **"End Conversation" triggered before a pending snapshot refresh reaches idle.** Section 5.6 states a snapshot refresh takes effect when the system is next idle. Section 6.1 states that triggering "End Conversation" during a P2P exchange acts as an interrupt and waits for idle before beginning end-of-conversation flow. If a snapshot refresh is pending and the user triggers "End Conversation," it is unclear whether the refresh is applied before the end-of-conversation flow begins (both waiting for idle) or discarded. The same ambiguity applies in Round-Robin and 1:1 mode.

- **Conversations with system messages only treated as "no messages."** Section 6.1 states that if a Conversation has no messages and the user triggers "End Conversation," the Conversation is deleted. A Conversation could contain only system messages (e.g., a Persona was added and then immediately removed, generating join and leave system messages, but no user or Persona text). Whether this counts as "no messages" for the purpose of this rule is not stated.

- **Mode selection when only one Persona exists in the Workspace.** Section 5.1 states that the modes available are "informed by the number of Personas selected" and that Round-Robin and P2P "require multiple." If only one Persona exists in the Workspace, the user cannot select more than one, making Round-Robin and P2P structurally unavailable. The document does not describe whether these modes are hidden, disabled, or simply not offered in this case. Requirements for the "New Conversation" UI cannot be written without this.

- **Review Agent run interrupted by system shutdown.** Section 7.2 states that if the system was not running at the scheduled time, the nightly run is skipped. It does not address the case where a run begins but the system shuts down partway through. Whether a partial run is discarded, retried, or results in partial findings being persisted needs to be defined.

---

## Ambiguities

- **"Configuration variable" vs. hardcoded constant for Context Panel limit.** Section 5.3 states the Context Panel maximum length "cannot be configured per Workspace" and is "a system-wide configuration variable, derived from the deployed model's context window capacity and defined during architecture." It is ambiguous whether this value is operator-configurable (e.g., editable in a config file or environment variable) or a constant derived by formula at build/deploy time. The distinction matters for deployability requirements and operator documentation.

- **Finding update behaviour: modification in place vs. card replacement.** Section 7.3 states the nightly run "may expand existing findings with new evidence, or drop findings that are no longer apparent." It is unclear whether findings are updated in place on their existing card (the card content changes) or whether a new card is issued and the old one removed. "Changes appear on the next page load" is consistent with both interpretations. Requirements for the Recommendations UI cannot be written without knowing whether a finding has a stable identity across runs.

- **Auto-naming trigger: does context compression count as "summarisation"?** Section 3.2 states a Conversation is auto-named on "first summarisation of the Conversation — whichever comes first: automatic context compression or the first user-requested targeted summary." Section 5.3 describes context window management as "summarising or dropping older messages." Whether background context compression constitutes a "summarisation" event that triggers auto-naming — and if so, what content is used to generate the name — is ambiguous. If context compression does trigger auto-naming, it would happen silently in the background with no user action, which may be the intended behaviour but should be confirmed.

- **`@Orchestrator` utility when all Personas are active.** Section 5.4 states the Orchestrator "remains active and responsive to explicit `@Orchestrator` mentions" even when all Workspace Personas are already in the Conversation — but its primary stated function (suggesting Personas) is unavailable in this state. The document does not define what actions or responses the Orchestrator provides when `@Orchestrator` is invoked in this state beyond targeted summaries (Section 6.3). If targeted summaries are the only remaining function, this should be stated. If other functions exist, they should be described.
