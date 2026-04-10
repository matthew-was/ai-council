# Overview Review

Second review pass, conducted 2026-04-10 against the current approved `documentation/project/overview.md`.

---

## Contradictions

1. **Pinned Conversations and the Mentor's position in the sidebar.** Section 3.1 defines the Pinned Conversations section as sitting below Folders, with standalone Conversations below that, and the Mentor pinned permanently at the very bottom. However, the ordering rule for Pinned Conversations states "oldest pin first, so the most recently pinned item appears at the bottom of the pinned section." Because the Mentor sits below the standalone Conversations section rather than inside the Pinned Conversations section, this is structurally consistent — but the document never explicitly states that the Mentor is *excluded* from the Pinned Conversations section and is instead a separate fourth zone. This distinction should be made explicit to avoid ambiguity when writing sidebar layout requirements.

2. **Snapshot refresh and "concluded" Conversations.** Section 5.6 states a user can "manually refresh that Persona's snapshot from within the Conversation view." Section 5.5 states that once a Conversation is ended it becomes "read-only." It is not stated whether the snapshot refresh control is available only while the Conversation is active (which would be consistent with read-only post-end), or whether it has any relevance to ended Conversations. If it is only available during active Conversations, this should be stated to prevent ambiguity.

3. **Review Agent and dismissed findings.** Section 7.3 states: "If a user dismisses a finding, the Review Agent treats this as a deliberate user preference and does not resurface the same type of suggestion for that Persona." Section 7.3 also states the nightly run "may drop findings that are no longer apparent after recent Conversations." It is not clear whether "the same type of suggestion" is a permanent suppression for that Persona, or whether it decays over time (e.g., after many subsequent Conversations). If the user's behaviour changes and the issue genuinely re-emerges, it is unclear whether the dismissed finding type could ever return. This creates a potential contradiction with the general principle that the Review Agent adapts to changing Conversation patterns.

---

## Missing Information

1. **Targeted summary trigger mechanism — natural language vs. explicit command.** Section 6.3 states the Orchestrator "detects targeted summary requests from natural language" and also supports the explicit `@Orchestrator` command. It is not stated how reliable the natural-language detection is expected to be, what happens when the Orchestrator misidentifies a message as a summary request, and whether the user can correct a false positive. This is needed to write a complete requirement around the targeted summary feature.

2. **Interactive consultation persistence and discoverability.** Section 7.4 states "older consultations may be hidden from the default view but remain accessible." The mechanism by which older consultations become hidden (time-based? count-based? user action?) and how the user accesses them is not defined. This is needed to write requirements for the interactive consultation history UI.

3. **What happens to the Mentor slot in the sidebar before the Mentor is created.** Section 2.3 states that if the user attempts to access the Mentor Conversation before configuration, the system directs them to the Personas area. Section 8.3 states the Mentor Conversation "is always pinned to the bottom of the sidebar." These are reconcilable if the sidebar item exists but clicking it redirects — but the document does not state whether the Mentor entry appears in the sidebar before the Mentor Persona is created, or whether it only appears once the Mentor exists. This is needed to write requirements for the sidebar and first-use experience.

4. **Persona deletion during an ended Conversation.** Section 4.2 defines "active in a Conversation" as "added as a participant and that Conversation has not yet been ended." This implies a Persona can be deleted freely once all Conversations it participated in have been ended. However, Section 5.6 states that concluded Conversation snapshots "persist independently of the source Persona." The document should confirm that deleting a Persona does not remove it from concluded Conversation snapshots or their associated Reports, and that no warning or consequence applies beyond active Conversations. This is needed to write complete requirements for Persona deletion.

5. **The Documents area and Report link behaviour on Report deletion.** Section 6.6 states: "Deleting a Report removes it from the Documents area and reverts the linked Conversation view to showing the option to generate a new Report." It is not stated what happens if multiple Reports exist for the same Conversation and only one is deleted — does the Conversation view revert to "generate a new Report," or does it show the remaining Reports? This gap is needed to write unambiguous requirements for multi-Report management.

6. **Chapter markers — what is displayed in the UI.** Section 8.4 describes chapters as "semantic boundaries" visible in the chat history, but does not describe how they are rendered in the Conversation view (e.g., a visual divider, a timestamp label, a heading). This is needed to write UI-facing acceptance criteria for the chapter feature.

7. **Episodic Memory retirement — when does a session become an episodic entry?** Section 8.5 states episodic memory holds "summaries for the most recent N sessions" and that "when a new session is summarised and the window is full, the oldest episodic entry is retired." It is not stated when a session is summarised into episodic form — is it at the end of a chapter, at the start of a new day's session, on some other trigger? This information is needed to write requirements for episodic memory creation.

8. **Workspace switching — what constitutes "paused."** Section 5.5 states that switching Workspaces while a Conversation is open "pauses" it. What "paused" means behaviourally is not defined: does the in-progress model response complete before pausing? Does an in-flight response get cancelled? Does the Conversation remain in the same state as when the user left? This is needed to write requirements for the Workspace-switching behaviour.

9. **"Near-capacity" threshold for the Context Panel warning.** Section 5.3 states the system warns the user when the Context Panel is "near its character limit." The threshold at which this warning appears (e.g., 90% full, 100 characters remaining) is not defined. While the precise value may be an implementation detail, the overview should at minimum state whether this is a configurable value or a fixed product decision, so requirements can be written accordingly.

10. **Review Agent — Mentor Conversation review scope.** Section 7.2 states the Review Agent reviews "the most recent activity since its last review" for the Mentor Conversation. It is not stated how the Review Agent determines what counts as "recent activity" or whether an entirely inactive Mentor session since the last review is skipped. This is a smaller gap but may affect requirements around the nightly run's skip logic.

---

## Undocumented Edge Cases

1. **What happens when a Conversation Mode is changed mid-Conversation and the new mode has requirements the current Persona set does not meet.** For example: if a user is in Round-Robin mode with multiple Personas, then removes all but one, and then attempts to switch to Peer-to-Peer mode, is the mode change blocked? The overview documents that mode changes are available but does not address the constraint that P2P requires multiple Personas.

2. **Orchestrator suggestion when all Personas in the Workspace are already in the Conversation.** Section 5.4 describes the Orchestrator comparing topics against "Personas available in the Workspace." If all available Workspace Personas are already active in the Conversation, can the Orchestrator still fire? Should it suppress suggestions entirely in that case?

3. **The "Run now" button and a concurrently scheduled nightly run.** Section 7.2 states the "Run now" button is disabled while a run is in progress. It does not address what happens if the nightly scheduled run starts while a manual run is already in progress, or vice versa. Whether these are serialised, merged, or one pre-empts the other is not stated.

4. **Deleting a Workspace while the Review Agent is mid-run.** The nightly run processes Conversations across the Workspace. What happens if the Workspace is deleted while a run is in progress? The document does not address this edge case.

5. **Adding a Persona mid-Conversation in Round-Robin mode.** Section 5.2 (Mode 2) defines a fixed turn order set before the Conversation begins. Section 5.2 (Adding mid-Conversation) states Personas can be added at any point. It is not stated how a mid-Conversation addition is inserted into the existing Round-Robin turn order — does the new Persona go to the end of the cycle, or does the user specify their position?

6. **Exporting a Conversation that contains system messages.** Section 5.2 states that join/leave events produce "system messages" in the thread. Section 6.5 describes the raw export as "all messages in chronological order with speaker labels." It is not stated whether system messages are included in the export and, if so, what speaker label they carry.

7. **Snapshot refresh and the Round-Robin turn order.** If a Persona's snapshot is refreshed mid-Conversation while that Persona is mid-cycle in Round-Robin mode (i.e., after some Personas in the current cycle have already responded), it is not stated whether the refresh takes effect for the current cycle or only from the next cycle onwards.

8. **Multiple Reports and "the option to generate a new Report."** Section 6.4 states multiple Reports can be generated from the same Conversation. Section 6.1 step 3 states the user is "presented with the option to generate a formal Report" upon ending. It is not stated whether this prompt appears again when the user returns to a concluded Conversation, or only once at the moment of ending — and how the UI handles a Conversation that already has one or more Reports when the user returns.

---

## Ambiguities

1. **"Concluded" vs. "ended" — consistency of terminology.** The document uses both terms. Section 6.1 defines "concluded" as explicitly ended by the user. The Glossary does not include a "Concluded" entry. Section 7.2 uses "concluded Conversation" throughout as the operative term for Review Agent processing. Because "concluded" carries a defined meaning distinct from simply being closed or inactive, adding it to the Glossary would prevent ambiguity in downstream requirements.

2. **The Discussions area's three sections vs. the Mentor Conversation sidebar entry.** Section 2.2 defines three content areas: Discussions, Personas, and Documents. The Mentor Conversation lives in the Discussions sidebar. However, the Mentor's configuration lives in the Personas area. A user navigates to the Mentor from two different areas for two different purposes. It is not stated whether the Mentor appears as a distinct item in the Personas area list (alongside regular Personas) or whether it has a separate sub-section. This could produce conflicting layout requirements.

3. **Whether the Review Agent's interactive consultation (Section 7.4) uses the same underlying AI model as Personas and the Mentor.** The document states the Review Agent is "a distinct system component, not a user-created Persona" but does not specify whether it is powered by the same single AI model. This matters because Section 1 describes a single abstracted model — but requirements writers should not assume without it being stated. This may be an architectural flag, but the product-level intent should be clear.

4. **"Workspace-switching pauses Conversation" — scope of "Conversation."** Section 5.5 says switching Workspaces pauses an open Conversation. It is not clear whether "open" means: (a) the user has a specific Conversation visible and active in the UI, (b) any Conversation in the Workspace that has an in-progress model response, or (c) something else. This affects what "paused" means in practice and how requirements around Workspace switching should be written.

5. **The Mentor's presence in the Review Agent's findings.** Section 4.4 and 7.3 both confirm the Mentor has a Recommendations section and that the Review Agent produces findings for the Mentor. However, Section 8.1 states the Mentor "cannot be renamed or deleted." The Recommendations section for the Mentor shows suggested changes to its System Prompt. It is not stated whether "Apply" on a Mentor finding updates the Mentor's live System Prompt via the same mechanism as for standard Personas, or whether there is any restriction. This should be confirmed.
