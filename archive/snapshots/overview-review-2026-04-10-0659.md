# Overview Review

## Contradictions

- **Section 3.1 — Pinned Conversations ordering rule is self-contradicting.** The sidebar ordering description states that within the Folders section and Pinned section, items are ordered by most recent activity — but then immediately carves out an exception that Pinned Conversations are ordered by pin date, most recently pinned first. A statement that says "items in the Pinned section are ordered by most recent activity, except that Pinned Conversations are ordered by pin date" is circular: the Pinned section _is_ the Pinned Conversations. The rule needs to be stated once, cleanly. Based on the content, the intended rule appears to be: pinned Conversations are ordered by pin date (most recently pinned first), not by last activity — but this needs confirming.

- **Section 5.1 — Conversation Mode selection flow vs. Section 5.2 Mode description.** Section 5.1 says the user chooses the Conversation Mode before selecting Personas. Section 5.2 (Mode 2: Round-Robin) says the user selects multiple Personas before the Conversation begins. The implication of Mode selection before Persona selection is that the user picks "1:1" before knowing they can only select one Persona — or picks "Round-Robin" before selecting how many. The flow could mean mode + persona selection happen on the same screen, or sequentially. This needs clarifying so that the new-conversation flow can be specified as a requirement without ambiguity.

- **Section 5.3 — Context Panel maximum length is described as a "global configuration variable" but the behaviour is user-facing.** The document states the maximum length is "defined during architecture." This is an architectural flag (see below), but there is also a product question embedded in it: does the system surface this limit to the user in any way (e.g., a character counter, a warning when approaching the limit)? The overview does not say, yet this is a user-facing behaviour that requirements will need to cover.

---

## Missing information

- **What does "active in an open Conversation" mean for deletion prevention (Section 4.2)?** The document says a Persona cannot be deleted while it is "active in an open Conversation." It is not clear whether "open" means any Conversation that has not been ended (including long-idle Conversations), or only Conversations the user currently has open on screen. This distinction matters for the deletion-block requirement.

- **What happens when you try to change mode mid-Conversation (Section 5.2)?** The overview states that the Conversation mode can be changed mid-Conversation. There is no description of what triggers this, how the user initiates it, what happens to the turn order when switching from Round-Robin to Peer-to-Peer (or vice versa), or whether there are any restrictions on which mode transitions are permitted. Requirements cannot be written for this without answers.

- **Persona removal from a Conversation — whose turn is it? (Section 5.2)** If a Persona is removed from an active Round-Robin Conversation mid-cycle (e.g., Persona B is removed while it is Persona B's turn), the overview does not say what happens. Does the turn skip? Does the cycle restructure? This is an edge case with a user-visible consequence.

- **Targeted Summary triggering via natural language — what counts as a request? (Section 6.3)** The Orchestrator detects targeted summary requests from natural language. The overview gives one example phrase but does not define where this detection sits, how confident the system must be before acting, or whether a false positive (treating a message as a summary request when it was not) produces any UX consequence. A requirement for this feature needs a clearer boundary.

- **`@Orchestrator` — is this a keyword or a UI element? (Section 6.3)** The overview introduces `@Orchestrator` as a way to address the Orchestrator directly. It is not clear whether this is a freeform text convention, an autocomplete mention, or a dedicated UI control. This distinction affects both requirements and UX design.

- **Automatic Summary — user actions (Section 6.2).** The overview says the Automatic Summary is persisted and can be copied as Markdown. It does not say whether the user can edit, regenerate, or delete it. Requirements for this feature need to specify what the user can and cannot do with the summary beyond reading and copying.

- **Formal Report generation — when and how many times? (Section 6.4).** The overview says the user is presented with the option to generate a Report upon ending a Conversation. It does not say whether the user can generate a second Report later (e.g., if they dismissed the option initially), whether a Conversation can have multiple Reports, or whether Reports can be deleted or renamed in the Documents area.

- **Documents area — what user actions are available? (Section 6.6).** Beyond viewing and navigating to the source Conversation, the overview does not describe what the user can do with Documents (rename, delete, export, search). This gap will produce incomplete requirements for the Documents area.

- **Review Agent "Run now" — scope and feedback (Section 7.2).** The manual "Run now" control is mentioned but the overview does not describe what feedback the user receives (e.g., does the UI indicate the run is in progress? does it report when it finishes? does it show what was processed?). Requirements cannot be written for this interaction without knowing the expected UX.

- **Review Agent findings — what does "Evolving" mean in practice? (Section 7.3).** The overview says nightly runs may "expand existing findings with new evidence" or "mark them as resolved." The user-facing representation of these state changes is not described. Does an expanded finding show a diff? Does a resolved finding disappear or move to a separate section? This detail is needed to write acceptance criteria.

- **Interactive consultation — how are older consultations accessed? (Section 7.4).** The overview says older consultations "may be hidden from the default view but remain accessible." It does not describe the mechanism for accessing them (a "show more" control, a separate history view, etc.). This is a missing interaction pattern for requirements.

- **Mentor — what happens if the user tries to add another Persona to the Mentor Conversation? (Section 8.3).** The overview states no other Personas can participate in a Mentor Conversation. It does not describe what the UI shows (is there no option to add Personas at all, or does the system show an error if the user attempts it?).

- **Mentor Memory Inspector — read-only is stated, but what does the user see? (Section 8.6).** The overview says the inspector shows Episodic and Semantic memories. It does not describe the format, how items are organised, or whether the user can take any actions from this view (e.g., flag a memory item for review, even if they cannot directly edit it). A read-only view still requires a requirements specification.

- **Mentor session chapter prompt — what if the system was not running at the date boundary? (Section 8.4).** The chapter prompt is triggered by a change of calendar day. If the user returns after several days (not just one), is a single chapter prompt shown, or is the logic sensitive to how many days have elapsed? The overview does not say.

- **Conversation export (Section 6.5) — file naming.** The export produces a Markdown file, but the overview does not specify the file name format. This is a small but concrete requirement that is currently unspecified.

- **Workspace deletion — what happens to in-progress Review Agent runs? (Section 2.1).** If a nightly run is processing Conversations in a Workspace that the user simultaneously deletes, the outcome is not described.

---

## Undocumented edge cases

- **Empty Workspace after last Persona is deleted.** If a user deletes all Personas from a Workspace, any existing Conversations that were in progress become orphaned — the Personas in them no longer exist as live Personas. The overview covers Persona deletion blocking for active Conversations, but does not address what happens to ended Conversations whose Personas are later fully deleted (beyond stating that snapshots persist). The question is whether the UI renders those Conversations cleanly when the Persona no longer exists.

- **Pinning the Mentor Conversation.** The Mentor Conversation is permanently pinned to the bottom of the sidebar. The overview does not say whether the user can also manually pin it through the standard pin control, or whether the pin control is absent/disabled for the Mentor entry.

- **Folder ordering when it contains only Conversations with no messages.** The sidebar orders Folders by most recent activity. A Folder containing only new, message-less Conversations has no "activity." The ordering rule in this edge case is not defined.

- **Context Panel and the Targeted Summary one-click add — what if the Context Panel is at capacity?** Section 5.3 states the Context Panel has a maximum length. Section 6.3 says a targeted summary can offer a one-click option to add key points to the Context Panel. What happens if the Context Panel is already full when the user tries to add from a summary?

- **Conversation with zero Personas (after all participating Personas are removed).** Section 5.2 allows Personas to be removed mid-Conversation. If the user removes all Personas from an active Conversation, the Conversation has no participants. The overview does not say whether the system prevents removing the last Persona or what state the Conversation enters.

- **Ending a Conversation with the Orchestrator active mid-suggestion.** If the Orchestrator has just surfaced a Persona suggestion and the user immediately clicks "End Conversation," the outcome of the pending suggestion is not defined.

- **The Review Agent and the Persona snapshot.** When the Review Agent analyses a concluded Conversation, it evaluates how a Persona performed — but against which version of the Persona's System Prompt? The Conversation used a snapshot taken at the start; the Persona's current System Prompt may differ. The document does not clarify whether the Review Agent evaluates against the snapshot (historical) or the current System Prompt (live). This has implications for the accuracy and relevance of findings.

- **Multiple simultaneous Workspaces navigation during an active Conversation.** The overview does not describe what happens to an active Conversation if the user switches Workspaces — does the Conversation auto-pause, does it continue in background, or does the UI prevent workspace switching while a Conversation is in progress?

---

## Ambiguities

- **"Concluded Conversations" — does this mean ended Conversations only, or any past Conversation? (Sections 7.1, 7.2).** The Review Agent processes "Conversations that concluded since its last run." The term "concluded" appears to mean explicitly ended (Section 5.5), but this is not stated definitively. If a Conversation is deleted before being ended, it never "concluded" — does the Review Agent ever see it? The distinction matters for the Review Agent's scope.

- **Persona Test panel — does it use a snapshot or live config? (Section 4.5).** The Test feature allows the user to send messages and see how the Persona responds. The overview does not state whether the Test runs against the current (unsaved) state of the System Prompt, the last saved version, or something else. This matters especially when the user is actively editing a System Prompt and wants to test before saving.

- **"The user can manually trigger a review at any time" — which Personas does this cover? (Section 7.2).** The manual trigger is described as a control in the "Personas area." It is ambiguous whether this triggers a review of all Personas across all concluded Conversations not yet reviewed, or only the Persona currently selected in the Personas area. The scope of the manual trigger needs to be defined.

- **Orchestrator suggestion dismissal and re-suggestion threshold (Section 5.4).** The overview says the Orchestrator will not "immediately re-suggest" a dismissed Persona, and may re-suggest after a "substantial" topic shift. "Substantial" is undefined. This ambiguity does not need to be fully resolved in product requirements (it may be a model-tuning matter), but the product intent — and whether the user has any visibility into or control over this threshold — should be stated explicitly.

- **Mentor Chapter prompt — "different calendar day" (Section 8.4).** "Different calendar day" is defined as a date change, not a 24-hour period. The overview does not clarify what timezone governs this. For a locally-hosted system running on the user's machine, the system clock is the obvious answer, but this should be stated to avoid implementation ambiguity.

- **"Nightly schedule" — what time? (Section 7.2).** The Review Agent runs on a "fixed nightly schedule." The time is not specified. Is this configurable by the user? Is there a default? This affects whether users can predict when findings will appear, and whether they can rely on findings being present by morning.

- **Conversation auto-naming — "first summarisation" (Section 3.2).** A Conversation is auto-named on "first summarisation." It is not clear whether this refers only to the Automatic Summary generated on ending the Conversation, or also to a Targeted Summary requested mid-Conversation. If a Targeted Summary triggers auto-naming, the name may be generated before the Conversation is complete.

- **The Orchestrator's role in Peer-to-Peer mode (Sections 5.2, 5.4).** The overview explicitly marks Peer-to-Peer as requiring further technical research and defers its full specification. This creates a genuine gap: requirements for Mode 3 cannot be written in the same depth as Modes 1 and 2. The developer should confirm whether Phase 1 user stories should treat Mode 3 as out of scope, as a defined-behaviour MVP, or as a research spike.
