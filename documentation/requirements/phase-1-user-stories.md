# Phase 1 User Stories

**Role:** Product Owner
**Status:** Approved
**Source document:** `documentation/requirements/user-requirements.md`
**Date produced:** 2026-04-15

---

## Notes on Story Scope

All stories in this document are Phase 1 unless marked Phase 2+. Phase 1 represents the full Version 1 scope as defined in `documentation/project/overview.md`. Phase 2+ stories capture capabilities that must be designed for in V1 (data model readiness, placeholders) but whose UI or full implementation is deferred.

User type for all stories: **Solo Operator** (the single self-hosted user).

INVEST criteria were applied to each story before writing. Stories that could not be made independently deliverable have been split accordingly.

---

## Epic 1: Workspaces

### US-W1: Create a Workspace

As a Solo Operator, I want to create a named Workspace so that I can establish a distinct advisory context with its own isolated set of Personas and Conversations.

**Acceptance criteria**
- [ ] Given no Workspaces exist, when the application is first launched, then an empty state is displayed with a clear call-to-action to create the first Workspace.
- [ ] Given the user initiates Workspace creation, when they provide a name and confirm, then a new Workspace is created and immediately becomes the active Workspace.
- [ ] Given the user creates a new Workspace, when they open it, then the Discussions area is empty with a prompt to start a first Conversation, and the Personas area is empty.
- [ ] Given the user creates a new Workspace, when the Mentor has not been configured, then clicking the Mentor slot in the Discussions sidebar directs the user to the Personas area to set up the Mentor first.

**Definition of done**: A new Workspace can be created from the empty state and from within an existing Workspace. The new Workspace is immediately active and its three areas (Discussions, Personas, Documents) are empty with appropriate empty-state guidance.

**Phase**: Phase 1

---

### US-W2: Rename a Workspace

As a Solo Operator, I want to rename an existing Workspace so that its name stays meaningful as my advisory context evolves.

**Acceptance criteria**
- [ ] Given an existing Workspace, when the user renames it and saves, then the Workspace displays the new name immediately in the top-level navigation.
- [ ] Given the user is renaming a Workspace, when they cancel without saving, then the Workspace name is unchanged.

**Definition of done**: A Workspace name can be changed and the change is reflected everywhere the name appears immediately after saving.

**Phase**: Phase 1

---

### US-W3: Delete a Workspace

As a Solo Operator, I want to delete a Workspace so that I can remove an advisory context I no longer need, along with all its content.

**Acceptance criteria**
- [ ] Given the user initiates Workspace deletion, when the confirmation dialog is shown, then the user must explicitly confirm before deletion proceeds.
- [ ] Given the user confirms Workspace deletion, when deletion completes, then all Personas, Conversations, Folders, Documents, the Mentor Conversation, all three Mentor memory layers, and all Review Agent findings within that Workspace are permanently removed.
- [ ] Given a Review Agent run is in progress for the Workspace, when the Workspace is deleted, then the run is stopped immediately and all partial results are discarded.
- [ ] Given the deleted Workspace was the active Workspace, when deletion completes, then the application navigates the user to another Workspace or the empty state.

**Definition of done**: A Workspace and all its content can be deleted after explicit confirmation. No orphaned data from the deleted Workspace remains.

**Phase**: Phase 1

---

### US-W4: Switch Between Workspaces

As a Solo Operator, I want to switch between my Workspaces so that I can move between different advisory contexts.

**Acceptance criteria**
- [ ] Given multiple Workspaces exist, when the user selects a different Workspace from the top-level navigation, then the entire interface immediately updates to reflect the selected Workspace's content.
- [ ] Given an in-flight AI response is running when the user switches Workspaces, when the Workspace switch occurs, then the in-flight response completes in the background, and in Round-Robin mode the remaining Personas in the current cycle do not respond until the user returns and explicitly resumes.
- [ ] Given a P2P autonomous exchange is running when the user switches Workspaces, when the Workspace switch occurs, then the exchange is paused and does not continue in the background.

**Definition of done**: Workspaces switch cleanly with no content bleeding between them. Background AI activity is handled correctly on switch.

**Phase**: Phase 1

---

## Epic 2: Personas

### US-P1: Create a Persona

As a Solo Operator, I want to create a Persona so that I have a virtual advisory character I can use in Conversations.

**Acceptance criteria**
- [ ] Given the user opens the Personas area and initiates Persona creation, when they provide a Name (required) and System Prompt (required), an optional Description, and a Temperature setting, then the Persona is created and appears in the Personas list.
- [ ] Given the user attempts to save a new Persona, when the Name or System Prompt is empty, then saving is blocked and an appropriate validation message is shown.
- [ ] Given a newly created Persona, when it is created, then it is scoped to the current Workspace only and not visible in any other Workspace.
- [ ] Given the user creates a Persona, when there are no built-in or default Personas in the system, then every Persona in the list was created explicitly by the user.

**Definition of done**: A Persona can be created with all four fields. Saving is blocked without required fields. The Persona is immediately available for use in Conversations within the current Workspace.

**Phase**: Phase 1

---

### US-P2: Configure Persona Temperature

As a Solo Operator, I want to set a Persona's Temperature using a descriptively labelled slider so that I can control its creative variability without needing to understand raw model parameters.

**Acceptance criteria**
- [ ] Given the Persona configuration form, when the Temperature field is displayed, then it is shown as a slider labelled "Precise & Analytical" at one end and "Creative & Exploratory" at the other.
- [ ] Given the user adjusts the Temperature slider and saves, when the Persona is used in a Conversation, then the configured temperature value is passed to the AI model.

**Definition of done**: The Temperature slider is present and labelled correctly. Its value is persisted on save and applied in model calls.

**Phase**: Phase 1

---

### US-P3: Edit a Persona

As a Solo Operator, I want to edit an existing Persona's configuration so that I can refine its behaviour over time.

**Acceptance criteria**
- [ ] Given an existing Persona, when the user edits any field and clicks Save, then the changes are persisted and the Persona's live System Prompt is updated.
- [ ] Given the user edits a Persona while it is active in an open Conversation, when they save the changes, then the running Conversation's snapshot is unaffected — the running Conversation continues using the version snapshotted when the Conversation began.
- [ ] Given the user edits a Persona and navigates away without saving, then the changes are discarded and the Persona retains its previous configuration.

**Definition of done**: Persona fields can be edited and saved. Running Conversations are not disrupted by edits to the live Persona.

**Phase**: Phase 1

---

### US-P4: Delete a Persona

As a Solo Operator, I want to delete a Persona I no longer need so that my Personas list stays relevant.

**Acceptance criteria**
- [ ] Given a Persona that is not active in any open Conversation, when the user deletes it, then the Persona is removed from the Workspace.
- [ ] Given a deleted Persona, when the user views concluded Conversations it participated in, then those Conversations and their message history remain fully intact.
- [ ] Given a deleted Persona, when Reports generated from Conversations it participated in exist in the Documents area, then those Reports remain intact.
- [ ] Given a Persona that is active in one or more open Conversations, when the user attempts to delete it, then a warning is displayed identifying the Conversations it is active in, and deletion is blocked until the Persona is removed from or those Conversations are ended.

**Definition of done**: A Persona can be deleted. Historical records (Conversations, Reports) are unaffected. Deletion of an active Persona is blocked with a clear explanation.

**Phase**: Phase 1

---

### US-P5: Test a Persona in Preview Mode

As a Solo Operator, I want to send test messages to a Persona from its configuration page so that I can iterate on its System Prompt before using it in a real Conversation.

**Acceptance criteria**
- [ ] Given a Persona with a saved System Prompt, when the user opens the Test panel and sends a message, then the Persona responds according to its saved System Prompt.
- [ ] Given the user has unsaved edits in the System Prompt editor, when they look at the Test panel, then the Test panel is disabled and cannot be used.
- [ ] Given the user saves their System Prompt edits, when the save completes, then the Test panel re-enables.
- [ ] Given an active test session, when the user sends a follow-up message, then the Persona responds with awareness of the prior test messages (multi-turn session).
- [ ] Given an active test session, when the user navigates away from the Persona's page, then the test session is discarded and no history is retained.

**Definition of done**: The Test panel supports multi-turn interaction, is locked during unsaved edits, and is discarded on navigation. It runs against the saved System Prompt only.

**Phase**: Phase 1

---

## Epic 3: Starting and Managing Conversations

### US-C1: Start a New Conversation

As a Solo Operator, I want to start a new Conversation so that I can begin an advisory session with one or more Personas.

**Acceptance criteria**
- [ ] Given at least one Persona exists in the Workspace, when the user clicks "New Conversation", then they are presented with: Persona selection, Conversation mode selection, an optional Folder assignment, and a first message input.
- [ ] Given no Personas exist in the Workspace, when the user clicks "New Conversation", then a prompt is shown directing the user to create a Persona first. The button itself must not be disabled.
- [ ] Given the user selects exactly one Persona, when the mode selection is shown, then only 1:1 mode is offered.
- [ ] Given only one Persona exists in the Workspace, when the mode selection is shown, then Round-Robin and Peer-to-Peer modes do not appear.
- [ ] Given the user selects multiple Personas, when the mode selection is shown, then Round-Robin and Peer-to-Peer modes are available in addition to 1:1.
- [ ] Given a new Conversation is started, when it is created, then it is named "New Conversation [timestamp]" by default.

**Definition of done**: A Conversation can be started with correct mode options for the selected Personas. The button is always visible. Default naming is applied.

**Phase**: Phase 1

---

### US-C2: Assign or Move a Conversation to a Folder

As a Solo Operator, I want to assign a Conversation to a Folder (at creation or later) so that I can keep related Conversations organised.

**Acceptance criteria**
- [ ] Given the user is starting a new Conversation, when Folder assignment is offered, then they can optionally select an existing Folder.
- [ ] Given an existing Conversation, when the user moves it into a Folder, then it appears within that Folder in the sidebar and is removed from its previous location.
- [ ] Given a Conversation in a Folder, when the user moves it out of the Folder, then it appears as a standalone Conversation in the sidebar.

**Definition of done**: Conversations can be assigned to Folders at creation and moved freely between Folders and standalone status at any time.

**Phase**: Phase 1

---

### US-C3: Add or Remove Personas Mid-Conversation

As a Solo Operator, I want to add or remove Personas from an active Conversation so that I can adapt my advisory group as the Conversation evolves.

**Acceptance criteria**
- [ ] Given an active Conversation and the system is idle, when the user adds a Persona, then the Persona joins the Conversation, a snapshot is taken of that Persona at the point of joining, and a system message is inserted in the Conversation thread recording the event.
- [ ] Given an active Conversation with more than one Persona and the system is idle, when the user removes a Persona, then the Persona leaves the Conversation and a system message is inserted in the thread recording the event.
- [ ] Given the user attempts to remove the last remaining Persona from a Conversation, then removal is blocked — the minimum is one active Persona.
- [ ] Given the user removes a Persona, when previous messages from that Persona exist in the thread, then those messages remain visible and continue to be part of the context available to remaining Personas.
- [ ] Given removing a Persona drops the active count below the minimum required for the current mode, when the removal occurs, then the mode automatically adjusts (e.g., drops to 1:1 if only one Persona remains in Round-Robin).
- [ ] Given the system is not idle (an AI response is in progress), when the user attempts to add or remove a Persona, then the control is unavailable until the system returns to idle.

**Definition of done**: Personas can be added and removed mid-Conversation when idle. System messages record all changes. Mode auto-adjusts when Persona count drops below mode minimum. Removed Personas' history is preserved.

**Phase**: Phase 1

---

### US-C4: Switch Conversation Mode Mid-Conversation

As a Solo Operator, I want to switch the Conversation mode mid-Conversation so that I can change the interaction structure as the Conversation evolves.

**Acceptance criteria**
- [ ] Given an active Conversation and the system is idle, when the user uses the mode switch control to switch from 1:1 to Round-Robin or Peer-to-Peer, then they are prompted to add one or more Personas before the switch takes effect.
- [ ] Given an active Conversation with multiple Personas, when the user switches from Round-Robin to Peer-to-Peer or vice versa, then the switch takes effect immediately via the mode switch control.
- [ ] Given the user switches to a mode requiring fewer Personas (e.g. Round-Robin to 1:1), when the mode switch is initiated, then a popup is shown asking which Persona(s) to remove; the mode change takes effect once removal is confirmed.
- [ ] Given the system is not idle, when the user attempts to use the mode switch control, then the control is unavailable.

**Definition of done**: All three mode-switching transitions work correctly, including the required Persona add/remove steps. The mode switch control is gated on system idle state.

**Phase**: Phase 1

---

### US-C5: Refresh a Persona Snapshot Mid-Conversation

As a Solo Operator, I want to manually refresh a Persona's snapshot in an active Conversation so that I can adopt improvements I have made to a Persona's configuration without ending the Conversation.

**Acceptance criteria**
- [ ] Given an active Conversation where a Persona's configuration has been updated since the Conversation began, when the system is idle, then a refresh control is available for that Persona within the Conversation view.
- [ ] Given the user triggers a snapshot refresh, when it completes, then previous messages in the Conversation are unaffected and future responses from that Persona use the refreshed configuration.
- [ ] Given an ended Conversation, when the user views it, then the snapshot refresh control is not present.

**Definition of done**: The snapshot refresh is available on active Conversations when idle, updates only future responses, and is absent from ended Conversations.

**Phase**: Phase 1

---

### US-C6: Pin and Unpin a Conversation

As a Solo Operator, I want to pin a Conversation so that it remains easily accessible regardless of activity recency.

**Acceptance criteria**
- [ ] Given a standalone Conversation, when the user pins it, then it appears in the Pinned Conversations section of the sidebar, ordered by pin date (oldest first).
- [ ] Given a pinned standalone Conversation, when the user unpins it, then it returns to the standalone Conversations section ordered by most recent activity.
- [ ] Given a Conversation inside a Folder, when the user pins it, then it is pinned to the top of its Folder's Conversation list and does not move to the global Pinned Conversations section.
- [ ] Given multiple pinned Conversations within a Folder, when they are displayed, then they are ordered by pin date, oldest first.

**Definition of done**: Pinning works correctly for both standalone and Folder-contained Conversations, with correct ordering and section placement.

**Phase**: Phase 1

---

## Epic 4: Conversation Context Panel

### US-CP1: Maintain the Conversation Context Panel

As a Solo Operator, I want to write and update a Context Panel within each Conversation so that I can preserve the most important information across context window boundaries.

**Acceptance criteria**
- [ ] Given an active Conversation, when the user writes content in the Context Panel and saves it, then the content is persisted and always included in the context sent to the AI model for that Conversation.
- [ ] Given the Context Panel has content, when context window space is constrained, then older Conversation messages are dropped before the Context Panel — the Context Panel is the last element evicted.
- [ ] Given the user types beyond the Context Panel character limit, when the limit is exceeded, then the input accepts the overflow but displays an error, and saving is blocked until the content is within the limit.
- [ ] Given the Context Panel UI is displayed, when the user views it, then the current character count and remaining capacity are shown.
- [ ] Given a concluded Conversation, when the user views the Context Panel, then its content is visible but read-only (the Conversation is ended and read-only).

**Definition of done**: The Context Panel can be written, saved, and is always included in model context. Character limit enforcement works correctly. Count display is accurate.

**Phase**: Phase 1

---

### US-CP2: Add Targeted Summary Key Points to the Context Panel

As a Solo Operator, I want to be offered a one-click option to add key points from a targeted summary into the Context Panel so that I can update my context notes with less manual effort.

**Acceptance criteria**
- [ ] Given a targeted summary has been generated, when the summary is displayed, then a one-time offer is shown to add the key points to the Context Panel.
- [ ] Given the user accepts the offer, when the key points are proposed, then the user must review and confirm before anything is added to the Context Panel.
- [ ] Given the user declines the offer, then the offer does not persist — it does not appear again for that targeted summary.
- [ ] Given the Context Panel is near its character limit when the user attempts to add content from a targeted summary, then the system warns the user rather than truncating, and the user must decide which existing content to remove.

**Definition of done**: The one-time offer appears after each targeted summary, requires user confirmation before adding, and handles the near-capacity case with a warning.

**Phase**: Phase 1

---

## Epic 5: The Orchestrator

### US-O1: Receive Orchestrator Persona Suggestions

As a Solo Operator, I want to receive non-intrusive suggestions from the Orchestrator about Personas that could add value to my current Conversation so that I can expand my advisory group at the right moment.

**Acceptance criteria**
- [ ] Given an active Conversation where Workspace Personas are not all participating, when the Orchestrator determines a Persona could add meaningful value, then a non-intrusive suggestion is displayed (e.g., "Your Risk Analyst Persona may be relevant given the current direction").
- [ ] Given the user is in a 1:1 Conversation, when the Orchestrator monitors the Conversation, then it applies a higher threshold before suggesting an additional Persona compared to multi-Persona modes.
- [ ] Given the user dismisses an Orchestrator suggestion, when the Orchestrator continues monitoring, then that specific suggestion is suppressed (prompt-driven, not permanently blocked).
- [ ] Given all Workspace Personas are already in the Conversation, when the Orchestrator monitors the Conversation, then no Persona suggestions are made.
- [ ] Given only one Persona exists in the Workspace, when the Orchestrator monitors the Conversation, then no suggestions are made.
- [ ] Given the user accepts an Orchestrator suggestion to add a Persona to a 1:1 Conversation, when the suggestion is accepted, then the Persona is added and the mode switches to Round-Robin. Acceptance of the suggestion serves as the confirmation.

**Definition of done**: Orchestrator suggestions appear at appropriate moments, are suppressible on dismissal, respect the 1:1 threshold, and correctly trigger Persona addition and mode switching on acceptance.

**Phase**: Phase 1

---

### US-O2: Request a Targeted Summary via @Orchestrator

As a Solo Operator, I want to request a topic-focused summary by addressing the Orchestrator with an `@Orchestrator` mention so that I can get a focused view of how a specific topic has been discussed so far.

**Acceptance criteria**
- [ ] Given an active Conversation, when the user types `@Orchestrator Summarise what was said about X so far`, then the Orchestrator generates a summary focused on the specified topic.
- [ ] Given a Round-Robin Conversation when a targeted summary is requested, when the current in-flight response completes, then the Orchestrator responds before the Round-Robin cycle continues.
- [ ] Given the first targeted summary is generated for a Conversation, when the auto-name trigger fires, then the Conversation is auto-named (if not already manually named).
- [ ] Given the system does not detect `@Orchestrator` in a message, then no Orchestrator action is triggered — all Orchestrator interactions require the explicit mention.

**Definition of done**: Targeted summaries are generated on explicit `@Orchestrator` mention. Round-Robin interruption works correctly. Auto-naming is triggered.

**Phase**: Phase 1

---

### US-O3: Pause and Resume P2P Exchange via @Orchestrator

As a Solo Operator, I want to pause an autonomous Peer-to-Peer exchange by mentioning `@Orchestrator` so that I can ask a question or redirect the conversation without the Personas continuing to respond.

**Acceptance criteria**
- [ ] Given an active P2P Conversation with an ongoing autonomous exchange, when the user types `@Orchestrator [any message]`, then the autonomous exchange is paused.
- [ ] Given the exchange is paused and the Orchestrator has responded, when the user wants to resume the autonomous exchange, then they must explicitly resume it — it does not restart automatically.

**Definition of done**: `@Orchestrator` in P2P mode pauses the autonomous exchange. Resumption is always an explicit user action.

**Phase**: Phase 1

---

## Epic 6: Conversation Lifecycle

### US-L1: End a Conversation

As a Solo Operator, I want to end a Conversation so that I can conclude an advisory session and produce its outputs.

**Acceptance criteria**
- [ ] Given an active Conversation, when the user clicks "End Conversation", then the end-of-conversation flow begins (subject to in-flight response handling below).
- [ ] Given the user ends a Conversation during an in-flight response in standard or Round-Robin mode, when the end action is triggered, then the in-flight response completes before the end-of-conversation flow begins.
- [ ] Given the user ends a Conversation during an autonomous P2P exchange, when the end action is triggered, then the exchange is paused, the system reaches an idle state, and then the end-of-conversation flow begins.
- [ ] Given a Conversation with no user or Persona messages (only system messages or empty), when the user triggers "End Conversation", then the Conversation is deleted rather than creating an empty concluded record.
- [ ] Given a Conversation that has been ended, when the user views it, then it is permanently read-only and cannot be re-opened.

**Definition of done**: Conversations can be ended at any time. In-flight responses and P2P exchanges are handled gracefully. Empty Conversations are deleted rather than concluded. Ended Conversations are permanently read-only.

**Phase**: Phase 1

---

### US-L2: View the Automatic Conversation Summary

As a Solo Operator, I want to see an automatic summary generated when I end a Conversation so that I have an immediate record of the key outcomes without reviewing the full transcript.

**Acceptance criteria**
- [ ] Given the user ends a Conversation, when the end-of-conversation flow completes, then the system automatically generates a summary containing: Key Takeaways, Points of Agreement, Points of Disagreement, and Action Items.
- [ ] Given a concluded Conversation, when the user returns to it, then the automatic summary is visible.
- [ ] Given the automatic summary is displayed, when the user clicks a copy action, then the summary is copied as Markdown.
- [ ] Given Version 1 constraints, when the automatic summary is generated, then no edit or regenerate controls are present in the UI.

**Definition of done**: An automatic summary is generated on Conversation end, is persisted, always visible on return, and copyable as Markdown. No edit/regenerate controls exist in V1.

**Phase**: Phase 1

---

### US-L3: Canonise Placeholder in End-of-Conversation Flow

As a Solo Operator, I want to see a "Canonise this conversation" option in the end-of-conversation UI so that I am aware this capability exists and will be available in a future version.

**Acceptance criteria**
- [ ] Given the end-of-conversation flow is presented, when the user views it, then a "Canonise this conversation" option is visible.
- [ ] Given the user interacts with the canonise option in Version 1, when they click it, then it is clearly non-functional (e.g. shown as disabled or with a "coming soon" indicator).

**Definition of done**: The canonise placeholder is present in the end-of-conversation UI and clearly non-functional in V1.

**Phase**: Phase 1

---

## Epic 7: Summaries and Reports

### US-R1: Generate a Formal Report from a Concluded Conversation

As a Solo Operator, I want to generate a formal Report from a concluded Conversation so that I have a structured, portable document of the session's outcomes.

**Acceptance criteria**
- [ ] Given a concluded Conversation, when the user requests a Report, then a Report is generated containing: an overview, a list of participating Personas, key points by topic, perspectives taken by each Persona, outcomes and recommended next steps, and metadata (date, Workspace, Conversation title).
- [ ] Given a concluded Conversation, when the user requests a Report, then the option to generate a Report is available at any time — not only immediately after ending.
- [ ] Given a Report is being generated for a Conversation, when the user attempts to generate a second Report for the same Conversation while the first is in progress, then the second generation is blocked until the first completes.
- [ ] Given a concluded Conversation, when multiple Reports have been generated from it (e.g. with different focus areas), then all Reports are available and linked from the Documents area.
- [ ] Given a Report has been generated, when the user navigates between the Report in Documents and the source Conversation, then they can navigate directly between the two (for as long as the Conversation exists).

**Definition of done**: Reports can be generated at any time from concluded Conversations, contain the required fields, are stored in the Documents area, and link back to the source Conversation. Concurrent generation is blocked.

**Phase**: Phase 1

---

### US-R2: Manage Reports in the Documents Area

As a Solo Operator, I want to view, rename, export, and delete Reports in the Documents area so that I can manage my accumulated report library.

**Acceptance criteria**
- [ ] Given the Documents area, when the user opens it, then all Reports for the current Workspace are listed.
- [ ] Given a Report, when the user chooses to view it, then the full Report content is displayed.
- [ ] Given a Report, when the user renames it and saves, then the Report displays the new name.
- [ ] Given a Report, when the user exports it, then it is exported as a Markdown file.
- [ ] Given a Report, when the user deletes it, then it is permanently removed from the Documents area with no recovery path.
- [ ] Given the user deletes all Reports for a Conversation, when the user views that Conversation, then the Conversation view shows only the "generate a report" option with no links to deleted Reports.
- [ ] Given one or more Reports remain for a Conversation, when the user deletes one Report, then the remaining Reports are still linked from the Conversation view alongside the option to generate another.

**Definition of done**: All four Report operations (view, rename, export as Markdown, delete) work correctly. Deletion is permanent. Conversation view updates correctly based on remaining Reports.

**Phase**: Phase 1

---

### US-R3: Export a Conversation as Raw Markdown

As a Solo Operator, I want to export any Conversation as a raw Markdown file so that I have a portable, unformatted record of the full exchange.

**Acceptance criteria**
- [ ] Given any Conversation (active or ended) and the system is idle, when the user triggers the export, then a Markdown file is produced containing all messages in chronological order with speaker labels and system messages (Persona join/leave events).
- [ ] Given the system is not idle (an AI response is in progress), when the user attempts to export, then the export control is unavailable until the system returns to idle.

**Definition of done**: Any Conversation can be exported as raw Markdown when the system is idle. The export includes all message types including system messages.

**Phase**: Phase 1

---

## Epic 8: Review Agent

### US-RA1: Nightly Review Agent Run

As a Solo Operator, I want the Review Agent to automatically analyse concluded Conversations overnight so that I receive Persona improvement suggestions without having to initiate the analysis myself.

**Acceptance criteria**
- [ ] Given concluded Conversations exist in a Workspace, when the nightly Review Agent run executes, then each participating Persona is evaluated against: Relevance, Role Adherence, Missed Opportunities, and Engagement, using the Persona's configuration snapshot from that Conversation.
- [ ] Given the nightly run executes, when it runs, then it processes all Conversations that concluded since the last run. On the very first run for a Workspace, all concluded Conversations are processed with no time-based filter.
- [ ] Given the system is not running at the scheduled nightly time, when the schedule fires, then the run is skipped with no catch-up mechanism.
- [ ] Given a nightly run is in progress, when a manual run is triggered, then the manual run is blocked and skipped.
- [ ] Given the system shuts down mid-run, when the next scheduled trigger fires, then a fresh run starts with no attempt to resume from where it stopped. Partial results from the incomplete run are discarded.
- [ ] Given no Conversations have concluded since the last run and the Mentor has no new activity, when the nightly trigger fires, then the run is skipped entirely.

**Definition of done**: The nightly run executes, evaluates correctly using snapshots, handles edge cases (no new activity, concurrent runs, mid-run shutdown) correctly.

**Phase**: Phase 1

---

### US-RA2: Manually Trigger a Review Agent Run

As a Solo Operator, I want to manually trigger a Review Agent run so that I can get immediate analysis without waiting for the nightly schedule.

**Acceptance criteria**
- [ ] Given the Personas area, when the user clicks "Run now", then a Review Agent run is triggered covering all Personas in the Workspace, equivalent to the nightly batch.
- [ ] Given a run is already in progress (nightly or manual), when the user sees the "Run now" button, then it is disabled until the run completes.
- [ ] Given the manual run completes, when the user views the Personas area, then the button re-enables.

**Definition of done**: "Run now" triggers a full Workspace review and is disabled while any run is in progress.

**Phase**: Phase 1

---

### US-RA3: View and Act on Persona Recommendations

As a Solo Operator, I want to view Review Agent findings in each Persona's Recommendations section so that I can see specific, evidenced suggestions for improving that Persona's System Prompt.

**Acceptance criteria**
- [ ] Given the user opens a Persona's profile in the Personas area, when findings exist for that Persona, then each finding is displayed as a card showing: embedded evidence (a quote or description of the relevant exchange), and a specific suggestion for updating the System Prompt.
- [ ] Given a finding card, when the user clicks Apply, then the Persona's live System Prompt is updated with the suggested change and the finding card immediately disappears.
- [ ] Given the user applies a finding while the Persona is active in an open Conversation, when the apply completes, then the live System Prompt is updated but the running Conversation's snapshot is unaffected.
- [ ] Given a finding card, when the user clicks Dismiss, then the finding card immediately disappears and the Review Agent treats this as a deliberate user preference, suppressing that type of suggestion.
- [ ] Given the user navigates away from the Persona page and returns, when the Recommendations section is loaded, then the current list of findings is refreshed from the latest state.
- [ ] Given findings that have been dropped by the Review Agent (no longer apparent after recent Conversations), when the page loads, then those findings simply do not appear — there is no "resolved" state shown.

**Definition of done**: Findings are displayed per-Persona with evidence and suggestions. Apply and Dismiss work correctly. Running Conversations are unaffected by Apply. List refreshes on page load.

**Phase**: Phase 1

---

### US-RA4: Interactive Persona Shaping via Review Agent Consultation

As a Solo Operator, I want to engage in a natural language consultation with the Review Agent from within a Persona's Recommendations section so that I can proactively shape a Persona's behaviour without waiting for the nightly run.

**Acceptance criteria**
- [ ] Given the user has selected a Persona in the Personas area, when they expand the right-hand consultation panel, then they can type natural language questions or requests about shaping that Persona.
- [ ] Given the consultation is active, when the Review Agent responds, then it has access to: the Persona's current System Prompt and any existing findings and recommendations. It does not have access to full Conversation histories.
- [ ] Given the user navigates away from the Persona's page, when they return, then the consultation session is discarded and no history is retained.
- [ ] Given the consultation is powered by the same AI model as all other system functions, when the user sends a message, then the Review Agent's response is generated by that model.

**Definition of done**: The consultation panel is available per-Persona, uses only the defined context (no Conversation histories), is discarded on navigation, and is powered by the configured AI model.

**Phase**: Phase 1

---

### US-RA5: Review Agent Mentor Analysis

As a Solo Operator, I want the Review Agent to analyse the Mentor Conversation alongside standard Personas so that the Mentor also receives improvement suggestions over time.

**Acceptance criteria**
- [ ] Given the Mentor has been configured and has new activity since the last Review Agent run, when the run executes, then the Mentor Conversation is included in the analysis.
- [ ] Given the Mentor Conversation has had no new activity since the last run, when the run executes, then the Mentor is skipped silently.
- [ ] Given no Mentor has been configured in the Workspace, when the run executes, then the Mentor review is skipped silently with no error or notification.
- [ ] Given the Review Agent produces findings for the Mentor, when the user views the Mentor's profile in the Personas area, then findings are displayed in the Mentor's Recommendations section identically to standard Persona findings.
- [ ] Given the user applies a Review Agent finding for the Mentor, when the apply completes, then the change is applied directly to the Mentor's live System Prompt and takes effect immediately in the ongoing Mentor Conversation. (The Mentor has no snapshot — its Conversation never ends.)

**Definition of done**: Mentor analysis runs correctly alongside standard Persona analysis. The Mentor's Recommendations section works identically to standard Personas. Applying findings updates the live prompt immediately.

**Phase**: Phase 1

---

## Epic 9: The Mentor

### US-M1: Create the Mentor

As a Solo Operator, I want to create a Mentor within my Workspace so that I have a dedicated, long-running personal guide.

**Acceptance criteria**
- [ ] Given the Personas area, when the user creates the Mentor, then it appears in the Personas list visually distinct from standard Personas.
- [ ] Given the Mentor creation flow, when the user creates the Mentor, then they provide a Name (as with any other Persona) and the Name is set at that point. The Mentor is created like any other Persona — the user writes a System Prompt and configures its settings.
- [ ] Given the Mentor has been created, when the user views the Mentor's configuration, then the rename control is disabled (the Name cannot be changed after creation) with a tooltip explaining it is not available for the Mentor.
- [ ] Given the Mentor exists, when the user views its controls, then the delete control is shown as disabled with a tooltip explaining it is not available for the Mentor.
- [ ] Given no Mentor has been created, when the user clicks the Mentor slot in the Discussions sidebar, then they are directed to the Personas area to set up the Mentor.

**Definition of done**: The Mentor can be created with a user-provided name. After creation, the rename and delete controls are correctly disabled with explanatory tooltips. The Mentor appears distinctly in the Personas area.

**Phase**: Phase 1

---

### US-M2: Configure the Mentor's System Prompt

As a Solo Operator, I want to write and save the Mentor's System Prompt so that it understands my background, goals, and context for this Workspace.

**Acceptance criteria**
- [ ] Given the Mentor's configuration page in the Personas area, when the user writes a System Prompt and saves it, then the System Prompt is persisted and immediately active in the Mentor Conversation.
- [ ] Given the Mentor's System Prompt is saved, when the user opens the Mentor Conversation, then the Mentor responds according to the saved System Prompt.

**Definition of done**: The Mentor's System Prompt can be written, saved, and immediately used in the Mentor Conversation.

**Phase**: Phase 1

---

### US-M3: Use the Mentor Conversation

As a Solo Operator, I want to have an ongoing conversation with my Mentor so that I can receive personalised guidance that builds on our accumulated history.

**Acceptance criteria**
- [ ] Given the Mentor has been configured, when the user clicks the Mentor slot in the Discussions sidebar, then the dedicated Mentor chat view opens showing the full Conversation history.
- [ ] Given the Mentor Conversation, when the user sends a message, then the Mentor responds using all three memory layers (Working, Episodic, Semantic) to compose a contextually-aware response.
- [ ] Given the Mentor Conversation, when the user views it, then there is no "start new Conversation" option — the user always returns to the same session.
- [ ] Given no other Personas can participate in the Mentor Conversation, when the user views Persona controls in the Mentor view, then there is no option to add other Personas.

**Definition of done**: The Mentor Conversation is a single, ongoing session with no new-Conversation option. Mentor responses are contextually informed by the three-layer memory. No other Personas can join.

**Phase**: Phase 1

---

### US-M4: Start a New Mentor Chapter

As a Solo Operator, I want to start a new chapter in the Mentor Conversation so that I can signal a fresh line of enquiry without losing the history of previous sessions.

**Acceptance criteria**
- [ ] Given the user returns to the Mentor Conversation on a different calendar day from their last session, and the Mentor Conversation has prior content, when the view loads, then a prompt is shown offering "Continue where we left off" or "Start a fresh chapter."
- [ ] Given the prompt is shown and the user begins typing without selecting an option, when the first message is sent, then the system assumes continuation.
- [ ] Given the user selects "Start a fresh chapter" or manually triggers a new chapter via the dedicated control, when the chapter begins, then a visible chapter marker is inserted in the Conversation thread at the boundary point.
- [ ] Given a chapter boundary has been created, when the user scrolls the Conversation history, then all previous content remains fully visible and scrollable.
- [ ] Given a chapter marker is inserted, when the Mentor responds in the new chapter, then the chapter marker functions as a semantic boundary — the Mentor begins a fresh line of enquiry without assuming continuity with the previous topic (unless the user explicitly continues).
- [ ] Given the user is on the same calendar day as their last session, when they return to the Mentor Conversation, then no chapter prompt is shown.

**Definition of done**: Chapter prompts appear on day changes with prior content. Manual chapter creation is available. Chapter markers are visible and semantic. All history remains visible.

**Phase**: Phase 1

---

### US-M5: View the Mentor Memory Inspector

As a Solo Operator, I want to view what the Mentor currently remembers in its Episodic and Semantic memory so that I understand why it gives the advice it does and can trust its accumulated knowledge.

**Acceptance criteria**
- [ ] Given the Mentor's section in the Personas area, when the user opens the Memory Inspector panel, then it displays two sections: Episodic Memory (summary view of recent session entries) and Semantic Memory (the structured Markdown knowledge document displayed as-is).
- [ ] Given the Memory Inspector is displayed, when the user views it, then Working Memory is absent — it is the live Conversation thread the user can already read.
- [ ] Given the Memory Inspector, when the user attempts to edit either Episodic or Semantic memory, then editing is not possible — the panel is read-only.

**Definition of done**: The Memory Inspector shows Episodic and Semantic memory in a read-only panel. Working Memory is not shown.

**Phase**: Phase 1

---

## Epic 10: Mentor Three-Layer Memory (System Behaviour)

### US-MM1: Mentor Working Memory Compression

As a Solo Operator, I want Working Memory to be automatically compressed into Episodic Memory so that the Mentor can handle long sessions without losing continuity.

**Acceptance criteria**
- [ ] Given the Working Memory reaches its capacity threshold mid-session, when the threshold is hit, then compression to Episodic Memory is triggered automatically without user intervention.
- [ ] Given the user starts a new chapter, when the chapter boundary is created, then Working Memory is compressed into Episodic Memory.
- [ ] Given the user ends a session (closes the Mentor Conversation), when the session ends, then Working Memory is compressed into Episodic Memory.

**Definition of done**: Working Memory compression is triggered by all three defined events (capacity threshold, new chapter, session end) and runs automatically without user intervention.

**Phase**: Phase 1

---

### US-MM2: Episodic Memory Window and Semantic Promotion

As a Solo Operator, I want the Episodic Memory window to roll forward and promote important facts to Semantic Memory before retiring old entries so that the Mentor does not silently lose important long-term information.

**Acceptance criteria**
- [ ] Given the Episodic Memory window is full (N sessions) and a new session is ready to be summarised, when the new entry is added, then the system first checks whether facts in the oldest episodic entry should be promoted to Semantic Memory before retiring that entry.
- [ ] Given facts are promoted to Semantic Memory, when the user views the Memory Inspector, then the promoted facts appear in the Semantic Memory section.
- [ ] Given facts are not promoted (nothing worth retaining in the oldest entry), when the oldest entry is retired, then it is discarded silently.

**Definition of done**: The episodic window rolls correctly. Promotion to Semantic Memory occurs before retirement of the oldest entry. The Memory Inspector reflects the current Semantic Memory state.

**Phase**: Phase 1

---

## Epic 11: AI Model Integration

### US-AI1: Configure the AI Model Endpoint

As a Solo Operator, I want to configure the AI model endpoint in a configuration file so that I can point the system at a locally-hosted LLM or a cloud API without touching application code.

**Acceptance criteria**
- [ ] Given a configuration file exists, when the user sets the model endpoint (and any required credentials or parameters), then the application uses that endpoint for all AI calls on next start.
- [ ] Given the configured endpoint is a local LLM, when the user switches the endpoint configuration to a cloud API (or vice versa), then no code changes are required — only the configuration file changes.
- [ ] Given the configuration file contains the Context Panel character limit setting, when the application starts, then that limit is applied system-wide.

**Definition of done**: All operator-configurable values (model endpoint, Context Panel limit, memory window sizes) are set in a configuration file. Swapping between local and cloud model requires only a config change.

**Phase**: Phase 1

---

## Epic 12: Data Model Readiness (Phase 1 Implementation, No V1 UI)

### US-DM1: User ID in Data Model

As a Solo Operator, I want the data model to include a `user_id` field on all entities from day one so that multi-user support can be added in a future phase without a data migration.

**Acceptance criteria**
- [ ] Given the V1 data model, when any entity (Workspace, Persona, Conversation, Folder, Report, memory entry, etc.) is created, then it is associated with a `user_id` field.
- [ ] Given Version 1 operates in single-user local mode, when `user_id` is applied, then all entities use a fixed default `user_id` value consistently throughout V1.

**Definition of done**: All entities in the data model carry a `user_id`. A fixed local default is used throughout V1. No user-facing UI change is required.

**Phase**: Phase 1

---

### US-DM2: Persona Version History Data Model Readiness

As a Solo Operator, I want the data model to be structured so that Persona version history (timestamped saves of System Prompt changes) can be added in a future version without a data migration.

**Acceptance criteria**
- [ ] Given the V1 data model for Personas, when it is designed, then the schema supports storing multiple timestamped versions of a Persona's System Prompt rather than a single overwrite model.
- [ ] Given V1 does not implement a version history UI, when the user saves a Persona's System Prompt, then the behaviour from the user's perspective is a simple overwrite (no version history UI is presented).

**Definition of done**: The Persona data model supports versioned System Prompt saves. V1 user experience is unchanged (no version history UI). The data structure is ready for the future feature.

**Phase**: Phase 1

---

## Story Index

| Story ID | Title | Epic | Phase |
| --- | --- | --- | --- |
| US-W1 | Create a Workspace | Workspaces | Phase 1 |
| US-W2 | Rename a Workspace | Workspaces | Phase 1 |
| US-W3 | Delete a Workspace | Workspaces | Phase 1 |
| US-W4 | Switch Between Workspaces | Workspaces | Phase 1 |
| US-P1 | Create a Persona | Personas | Phase 1 |
| US-P2 | Configure Persona Temperature | Personas | Phase 1 |
| US-P3 | Edit a Persona | Personas | Phase 1 |
| US-P4 | Delete a Persona | Personas | Phase 1 |
| US-P5 | Test a Persona in Preview Mode | Personas | Phase 1 |
| US-C1 | Start a New Conversation | Conversations | Phase 1 |
| US-C2 | Assign or Move a Conversation to a Folder | Conversations | Phase 1 |
| US-C3 | Add or Remove Personas Mid-Conversation | Conversations | Phase 1 |
| US-C4 | Switch Conversation Mode Mid-Conversation | Conversations | Phase 1 |
| US-C5 | Refresh a Persona Snapshot Mid-Conversation | Conversations | Phase 1 |
| US-C6 | Pin and Unpin a Conversation | Conversations | Phase 1 |
| US-CP1 | Maintain the Conversation Context Panel | Context Panel | Phase 1 |
| US-CP2 | Add Targeted Summary Key Points to the Context Panel | Context Panel | Phase 1 |
| US-O1 | Receive Orchestrator Persona Suggestions | Orchestrator | Phase 1 |
| US-O2 | Request a Targeted Summary via @Orchestrator | Orchestrator | Phase 1 |
| US-O3 | Pause and Resume P2P Exchange via @Orchestrator | Orchestrator | Phase 1 |
| US-L1 | End a Conversation | Lifecycle | Phase 1 |
| US-L2 | View the Automatic Conversation Summary | Lifecycle | Phase 1 |
| US-L3 | Canonise Placeholder in End-of-Conversation Flow | Lifecycle | Phase 1 |
| US-R1 | Generate a Formal Report | Reports | Phase 1 |
| US-R2 | Manage Reports in the Documents Area | Reports | Phase 1 |
| US-R3 | Export a Conversation as Raw Markdown | Reports | Phase 1 |
| US-RA1 | Nightly Review Agent Run | Review Agent | Phase 1 |
| US-RA2 | Manually Trigger a Review Agent Run | Review Agent | Phase 1 |
| US-RA3 | View and Act on Persona Recommendations | Review Agent | Phase 1 |
| US-RA4 | Interactive Persona Shaping via Consultation | Review Agent | Phase 1 |
| US-RA5 | Review Agent Mentor Analysis | Review Agent | Phase 1 |
| US-M1 | Create the Mentor | Mentor | Phase 1 |
| US-M2 | Configure the Mentor's System Prompt | Mentor | Phase 1 |
| US-M3 | Use the Mentor Conversation | Mentor | Phase 1 |
| US-M4 | Start a New Mentor Chapter | Mentor | Phase 1 |
| US-M5 | View the Mentor Memory Inspector | Mentor | Phase 1 |
| US-MM1 | Mentor Working Memory Compression | Mentor Memory | Phase 1 |
| US-MM2 | Episodic Memory Window and Semantic Promotion | Mentor Memory | Phase 1 |
| US-AI1 | Configure the AI Model Endpoint | AI Integration | Phase 1 |
| US-DM1 | User ID in Data Model | Data Model | Phase 1 |
| US-DM2 | Persona Version History Data Model Readiness | Data Model | Phase 1 |
