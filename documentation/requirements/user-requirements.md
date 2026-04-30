# User Requirements

**Role:** Product Owner
**Status:** Approved
**Source document:** `documentation/project/overview.md` (Approved 2026-04-15)
**Date produced:** 2026-04-15

---

## User Types

| User Type | Description |
| --- | --- |
| **Solo Operator** | The single person who installs, configures, and uses the self-hosted application. They are simultaneously the end-user and the system operator. Version 1 has no authentication or multi-user support; all requirements below apply to this one user type. |

---

## Non-Goals

The following capabilities are explicitly out of scope for Version 1 and must not be built or designed as first-class features, though the system architecture must not foreclose them.

| Out of Scope | Rationale |
| --- | --- |
| Multi-user support or authentication | V1 is a local, single-user deployment. Authentication and multi-tenancy are future capabilities. The data model must include `user_id` from day one to allow this to be added later. |
| Persona templates, sharing, or duplication | Personas cannot be shared between Workspaces, duplicated within a Workspace, or exported in V1. These are explicitly deferred. |
| Webhooks or external integrations | No event-driven integrations with external systems are in scope for V1. |
| Public API access | No externally-accessible API surface is in scope for V1. |
| Conversation history search or tagging | No search index or tagging mechanism for Conversations is in scope for V1. |
| Full guided onboarding wizard | V1 provides empty states and calls-to-action only; a structured onboarding wizard is deferred. A Mentor creation wizard is specifically deferred to a future version. |
| User-uploaded documents | The Documents area contains only system-generated content in V1. User file uploads are not supported. |
| Multi-model routing | A single AI model powers all system functions in V1. Different models per component are a future consideration. |
| PDF export of Reports | Reports are exported as Markdown only in V1. PDF export is a future consideration. |
| Conversation archiving and retention policy | Concluded Conversations remain in the system indefinitely in V1. Formal archiving and auto-deletion policies are deferred. |
| Persona version history UI | The data model must support versioned System Prompt saves, but no UI for reviewing or reverting Persona history will be built in V1. |
| Persona persistent memory (canonisation) | Personas have no persistent memory across Conversations in V1. The canonisation UI placeholder is present but non-functional. |
| Institutional Knowledge Document | The shared Workspace-level knowledge document is a future feature; no implementation is in scope for V1. |
| Automatic edit or regenerate of Automatic Summary | The end-of-conversation Automatic Summary is a fixed, system-generated record in V1 with no user controls to edit or regenerate it. |

---

## Open Questions

The following questions could not be resolved from the overview and should be answered before implementation begins.

1. **OQ-01 — Context Panel character limit:** The overview states the maximum Context Panel length is an "operator-configurable value set in a configuration file." What is the default value? Is there a minimum or maximum allowable value for the configurable range?
2. **OQ-02 — Orchestrator re-suggestion threshold:** The overview defers the precise threshold for re-suggesting a dismissed Orchestrator recommendation to implementation. Does the developer have a preferred starting heuristic (e.g., number of turns, topic change detection)?
3. **OQ-03 — Review Agent dismissed-finding re-raise threshold:** Same deferral as OQ-02 but for the Review Agent. Should the threshold be the same mechanism, or different?
4. **OQ-04 — Episodic Memory window size (N):** The overview states N is "configurable, defined during architecture." Is there a target default value the developer wants to aim for?
5. **OQ-05 — Working Memory compression trigger ordering:** The overview lists three triggers (capacity threshold, new chapter, end of session) but does not define priority when multiple triggers coincide. Does ordering matter?
6. **OQ-06 — Near-capacity warning threshold for Context Panel:** The overview states the threshold is "fixed in Version 1" but does not give a value. What percentage or character count should trigger the warning?
7. **OQ-07 — Nightly Review Agent schedule:** The overview says "nightly" but does not specify the time. Should this be configurable per deployment, or fixed (e.g., 02:00 local time)?

---

## Functional Requirements

### FR-1: Workspaces

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-1.1 | Must | Solo Operator | The system must allow the user to create multiple named Workspaces. | Workspaces represent distinct advisory contexts; users need at least one per context group. |
| FR-1.2 | Must | Solo Operator | The system must allow the user to rename an existing Workspace. | Names will need to evolve as the user's context changes. |
| FR-1.3 | Must | Solo Operator | The system must allow the user to delete a Workspace, permanently removing all Personas, Conversations, Folders, Documents, the Mentor Conversation, all three Mentor memory layers, and all Review Agent findings within it. | Workspace deletion must be complete and leave no orphaned data. |
| FR-1.4 | Must | Solo Operator | Before deleting a Workspace, the system must present a confirmation dialog requiring explicit user confirmation. | Deletion is irreversible; the user must not trigger it accidentally. |
| FR-1.5 | Must | Solo Operator | The system must allow the user to switch between Workspaces via a top-level navigation control. Switching must immediately update the entire interface to reflect the selected Workspace. | Users work across multiple advisory contexts. |
| FR-1.6 | Must | Solo Operator | All content within a Workspace (Personas, Conversations, Folders, Documents, Mentor, memory, Review Agent findings) must be completely inaccessible from any other Workspace. | Total isolation is a core architectural boundary; leakage would violate user privacy and advisory coherence. |
| FR-1.7 | Should | Solo Operator | When the application is first launched with no Workspaces, the system must present an empty state with a clear call-to-action to create the first Workspace. | First-use experience must guide the user without requiring prior knowledge. |
| FR-1.8 | Should | Solo Operator | If a Workspace is deleted while a Review Agent run is in progress for it, the run must be stopped immediately and all partial results discarded. | Partial results from a deleted Workspace must not persist. |

### FR-2: Discussions Area and Sidebar Navigation

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-2.1 | Should | Solo Operator | The Discussions sidebar must display Folders at the top (ordered by creation date, oldest first), followed by Pinned Conversations (ordered by pin date, oldest first), followed by standalone unpinned Conversations (ordered by most recent activity, most recent first), followed by the Mentor Conversation slot fixed to the very bottom. | Consistent, predictable navigation reduces cognitive load. |
| FR-2.2 | Must | Solo Operator | The Mentor Conversation slot must always be visible in the sidebar regardless of scroll position, even before the Mentor has been configured. | The Mentor is a primary navigational destination. |
| FR-2.3 | Must | Solo Operator | Clicking the Mentor Conversation slot before the Mentor is configured must direct the user to the Personas area with guidance to set up the Mentor first. | Prevents a dead-end navigation experience. |
| FR-2.4 | Should | Solo Operator | Each Folder must default to a collapsed state in the sidebar, displaying the folder name and a count of Conversations inside. | Reduces visual noise in workspaces with many Conversations. |
| FR-2.5 | Must | Solo Operator | Clicking a collapsed Folder must expand it inline to reveal its Conversations. | Standard tree navigation behaviour. |

### FR-3: Conversations and Folders

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-3.1 | Must | Solo Operator | The system must allow the user to create, rename, and delete Folders. | Folders are the primary grouping mechanism for Conversations. |
| FR-3.2 | Must | Solo Operator | Deleting a Folder must not delete the Conversations within it; those Conversations must become standalone. | Prevents accidental data loss when reorganising. |
| FR-3.3 | Must | Solo Operator | The system must allow the user to move a Conversation into or out of a Folder at any time. | Users reorganise their work as topics evolve. |
| FR-3.4 | Must | Solo Operator | The system must allow the user to create, rename, and delete Conversations. | Core content management. |
| FR-3.5 | Should | Solo Operator | A newly created Conversation must be named "New Conversation [timestamp]" by default. If the user has not manually renamed it, the system must auto-generate a name on first summarisation of the Conversation (whichever comes first: automatic context compression or the first user-requested targeted summary). | Default names avoid blank states; auto-naming reduces manual overhead. |
| FR-3.6 | Should | Solo Operator | The system must allow the user to pin and unpin any Conversation. | Pinning keeps important Conversations readily accessible. |
| FR-3.7 | Should | Solo Operator | A Conversation pinned within a Folder must stay within that Folder and be pinned to the top of its Folder's list — it must not move to the global Pinned Conversations section. | Pinning within a Folder is a local operation, not a global one. |
| FR-3.8 | Must | Solo Operator | Deleting a Conversation must not delete Review Agent findings derived from it; those findings must persist independently on the relevant Persona's Recommendations section. | Findings have independent value once generated. |
| FR-3.9 | Must | Solo Operator | Deleting a Conversation must not delete any Reports generated from it; those Reports must remain in the Documents area, though any link back to the source Conversation will no longer resolve. | Reports are standalone outputs, not Conversation-dependent. |
| FR-3.10 | Must | Solo Operator | The system must allow the user to export any Conversation (active or ended) as a raw Markdown file containing all messages in chronological order with speaker labels and system messages, when the system is idle. | Users need a portable record of their Conversations. |

### FR-4: Personas

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-4.1 | Must | Solo Operator | The system must allow the user to create Personas within a Workspace. Each Persona must have: a Name (required), an optional Description, a System Prompt (required), and a Temperature setting. | These four fields fully define a Persona's identity and behaviour. |
| FR-4.2 | Must | Solo Operator | The Temperature setting must be presented as a slider labelled from "Precise & Analytical" at one end to "Creative & Exploratory" at the other. | Descriptive labels make the setting meaningful without exposing raw model parameters. |
| FR-4.3 | Must | Solo Operator | The system must allow the user to edit any field of an existing Persona, with changes saved via an explicit Save action. | Personas are refined iteratively over time. |
| FR-4.4 | Must | Solo Operator | The system must allow the user to delete a Persona. Deleting a Persona must not affect any concluded Conversations it participated in — their snapshots, message history, and any Reports generated from them must remain fully intact. | Personas may be retired without losing historical records. |
| FR-4.5 | Must | Solo Operator | The system must prevent deletion of a Persona that is currently active in an open Conversation. It must display a warning identifying which Conversation(s) the Persona is active in and instruct the user to end or remove it from those Conversations first. | Prevents breaking an in-progress Conversation. |
| FR-4.6 | Must | Solo Operator | Personas must be scoped to their Workspace and inaccessible from any other Workspace. | Workspace isolation requirement. |
| FR-4.7 | Must | Solo Operator | There must be no built-in or default Personas — every Persona is created from scratch by the user. | The system does not constrain the user's advisory context with preset characters. |
| FR-4.8 | Should | Solo Operator | The Personas area must include a Test (Preview) feature for each Persona, allowing the user to send test messages and receive responses without starting a full Conversation. | Users must be able to iterate on a System Prompt before deploying it in a Conversation. |
| FR-4.9 | Should | Solo Operator | The Persona Test panel must run against the currently saved System Prompt and must be disabled while unsaved edits exist in the System Prompt editor. Once saved, the panel must re-enable. | Ensures the test reflects what was actually saved, not a transient draft. |
| FR-4.10 | Should | Solo Operator | The Persona Test panel must maintain a short back-and-forth session, allowing follow-up messages within a single test session. The test session must be discarded when the user navigates away from the Persona's page. | Multi-turn testing is more useful than single-shot; no persistence prevents confusion. |

### FR-5: Starting and Configuring a Conversation

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-5.1 | Must | Solo Operator | The system must allow the user to start a new Conversation by selecting one or more Personas, choosing a Conversation mode, optionally assigning the Conversation to a Folder, and sending the first message. | These are the required steps to initialise a Conversation. |
| FR-5.2 | Must | Solo Operator | The "New Conversation" button must always be visible and accessible, but if no Personas exist in the Workspace, clicking it must show a prompt directing the user to create a Persona first rather than opening the Conversation setup. | The button must not be disabled, but it cannot proceed without a Persona. |
| FR-5.3 | Must | Solo Operator | The system must support three Conversation modes: 1:1 (one Persona), Round-Robin (multiple Personas in fixed turn order), and Peer-to-Peer (multiple Personas with autonomous turn-taking). | These are the three defined interaction models, each serving a distinct purpose. |
| FR-5.4 | Must | Solo Operator | 1:1 mode must only be available when exactly one Persona is selected. Round-Robin and Peer-to-Peer modes must require multiple Personas and must not appear in the mode selection if only one Persona exists in the Workspace. | Mode options must reflect what is actually possible given the current Persona selection and Workspace. |
| FR-5.5 | Should | Solo Operator | The user must be able to add Personas to or remove Personas from an active Conversation at any time, subject to a minimum of one active Persona remaining. | Conversations evolve; the user must be able to adapt the advisory group dynamically. |
| FR-5.6 | Should | Solo Operator | The user must not be able to remove the last remaining Persona from a Conversation. | A Conversation without any Persona is not meaningful; deletion is the correct path. |
| FR-5.7 | Should | Solo Operator | When a Persona joins or leaves a Conversation, the system must insert a system message in the Conversation thread recording the event. | Provides a clear audit trail of participation changes. |
| FR-5.8 | Must | Solo Operator | Controls for adding, removing, or changing Personas and modes must only be available when the system is idle (all in-progress AI responses have completed). No action queue is supported — a second action cannot be triggered until the first has resolved. | Prevents race conditions and ambiguous Conversation state. |
| FR-5.9 | Should | Solo Operator | If removing a Persona drops the active Persona count below the minimum required for the current mode, the mode must automatically adjust (e.g., dropping to 1:1 if only one Persona remains in Round-Robin). | Prevents the Conversation from reaching an invalid state. |
| FR-5.10 | Should | Solo Operator | The user must be able to change the Conversation mode mid-Conversation using a mode switch control, only when the system is idle. | Users may decide the mode no longer fits the direction of the Conversation. |
| FR-5.11 | Should | Solo Operator | When switching to a mode requiring more Personas than are currently active (e.g. 1:1 to Round-Robin), the user must be prompted to add Personas before the switch takes effect. | Cannot enter Round-Robin or P2P with insufficient Personas. |
| FR-5.12 | Should | Solo Operator | When switching to a mode requiring fewer Personas (e.g. Round-Robin to 1:1), the system must display a popup asking which Persona(s) to remove. The mode change must take effect once the removal is confirmed. | The user must choose which Persona(s) to retain. |
| FR-5.13 | Should | Solo Operator | When a Persona is removed from a Conversation, its prior messages must remain visible in the Conversation history and continue to be included in the context available to remaining Personas. | Historical messages retain their value for ongoing context. |
| FR-5.14 | Should | Solo Operator | Accepting an Orchestrator suggestion to add a Persona to a 1:1 Conversation must trigger a mode switch to Round-Robin, with acceptance of the suggestion serving as the confirmation. | Accepting the suggestion is the implicit confirmation of both the Persona addition and the mode change. |
| FR-5.15 | Must | Solo Operator | In Round-Robin mode, after the user sends a message, each selected Persona must respond in the order they were added to the Conversation, completing the full cycle before the turn returns to the user. The user must not be able to send another message until all Personas in the current cycle have responded. | The fixed, sequential cycle is the defining property of Round-Robin mode. Users expect a complete response set before continuing. |
| FR-5.16 | Must | Solo Operator | The system must never include any Persona's System Prompt in the context provided to other Personas. Each Persona must receive the full Conversation message history (including messages from all Personas) but must not have visibility of any other Persona's System Prompt. | System Prompts are the user's private configuration for each Persona. Exposing them to other Personas would violate the user's intent and could alter the behaviour of the recipient Persona. |

### FR-6: Conversation Snapshots

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-6.1 | Must | Solo Operator | At the start of a Conversation, the system must capture a snapshot of each participating Persona's Name, System Prompt, and Temperature. The Conversation must run against these snapshots for its entire duration. | Snapshots ensure Conversation stability; changes to a Persona elsewhere do not retroactively affect a running Conversation. |
| FR-6.2 | Must | Solo Operator | When a Persona is added mid-Conversation, the system must capture a snapshot of that Persona at the point they join. | Mid-conversation additions must also be snapshotted. |
| FR-6.3 | Must | Solo Operator | Snapshots must persist independently of the source Persona. If a Persona is later deleted, any concluded Conversations it participated in must remain fully intact and readable. | Concluded Conversations are permanent records. |
| FR-6.4 | Should | Solo Operator | The system must allow the user to manually refresh a Persona's snapshot within an active Conversation when the system is idle, to adopt changes made to the Persona's configuration since the Conversation began. This must always be a deliberate, user-initiated action. | The user may want to pick up Persona improvements mid-Conversation without ending and restarting. |
| FR-6.5 | Must | Solo Operator | The snapshot refresh control must not be available on ended Conversations. | Ended Conversations are read-only; their snapshots are fixed. |

### FR-7: Conversation Context Panel

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-7.1 | Must | Solo Operator | Every Conversation must include a user-editable Context Panel where the user can write and maintain a structured summary of key points, decisions, and constraints. | The Context Panel preserves critical information across context window boundaries. |
| FR-7.2 | Must | Solo Operator | The Context Panel must always be included in the context sent to the AI model when generating a Persona's response. When context window space is constrained, older Conversation messages must be dropped before the Context Panel is affected. The Context Panel must be the last element evicted. | The Context Panel's value depends entirely on its guaranteed presence in every model call. |
| FR-7.3 | Must | Solo Operator | The system must never write to the Context Panel automatically. All contents are exclusively user-authored. | The Context Panel is the user's owned record; automatic changes would violate that ownership. |
| FR-7.4 | Must | Solo Operator | The Context Panel must enforce a configurable maximum character limit (operator-set in a configuration file, system-wide). The current character count and remaining capacity must be displayed to the user within the Context Panel UI. | Users must be able to see how much space they have. [See OQ-01 for default value question.] |
| FR-7.5 | Must | Solo Operator | If the user types beyond the Context Panel character limit, the input must accept the overflow but display an error. The user must manually reduce the content to within the limit before saving is permitted. | Overflow must not be silently truncated; the user must decide what to remove. |
| FR-7.6 | Should | Solo Operator | After a targeted summary, the system should offer a one-click option to add key points from the summary into the Context Panel. The user must always review and confirm before anything is added. This offer must be one-time per targeted summary — if the user declines, the offer must not persist. | Reduces friction in maintaining the Context Panel without removing user control. |
| FR-7.7 | Should | Solo Operator | If the Context Panel is near its character limit when the user attempts to add content from a targeted summary, the system should warn the user rather than truncating. The user must decide which existing content to remove to make space. [See OQ-06 for threshold value question.] | Silent truncation of user-authored content is not acceptable. |

### FR-8: The Orchestrator

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-8.1 | Must | Solo Operator | The system must include a background Orchestrator that monitors active Conversations and suggests relevant Personas from the Workspace that are not yet participating. | The Orchestrator's core value is surfacing overlooked advisory perspectives. |
| FR-8.2 | Must | Solo Operator | The Orchestrator must never automatically add a Persona to a live Conversation. Every addition must require explicit user confirmation. | Uninvited additions would disrupt the user's chosen advisory group. |
| FR-8.3 | Must | Solo Operator | The Orchestrator must be silent when no other Personas are available to suggest (all Workspace Personas are already in the Conversation, or only one Persona exists in the Workspace). | Suggestions are only useful if there is something to suggest. |
| FR-8.4 | Should | Solo Operator | In 1:1 mode, the Orchestrator must apply a higher threshold before suggesting an additional Persona, to respect the user's deliberate choice of a focused Conversation. | 1:1 is a deliberate choice; aggressive suggestions undermine it. |
| FR-8.5 | Should | Solo Operator | If the user dismisses an Orchestrator suggestion, the Orchestrator must suppress that specific suggestion. The suppression is prompt-driven rather than a permanent rule — the intent is to avoid repeated prompting, not permanent suppression. [See OQ-02 for threshold question.] | Repeated suggestions after dismissal are disruptive. |
| FR-8.6 | Must | Solo Operator | The Orchestrator must support a user-addressable `@Orchestrator` mention for requesting targeted summaries and, in P2P mode, for pausing autonomous Persona exchanges. | Direct user interaction with the Orchestrator enables on-demand functionality. |
| FR-8.7 | Must | Solo Operator | In P2P mode, an `@Orchestrator` mention must pause the autonomous Persona exchange. Once the Orchestrator has responded, the user must explicitly resume the exchange — it must not restart automatically. | Preserves user control over P2P flow. |
| FR-8.8 | Must | Solo Operator | In Round-Robin mode, an `@Orchestrator` mention must interrupt the current cycle — the current in-flight response completes, then the Orchestrator responds. | Consistent interrupt behaviour across modes. |
| FR-8.9 | Should | Solo Operator | The Orchestrator suggestions must be non-intrusive in presentation (e.g., not blocking the user's input or the Conversation flow). | Suggestions should inform, not interrupt. |

### FR-9: Conversation Lifecycle

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-9.1 | Must | Solo Operator | A Conversation must remain open and resumable until the user explicitly ends it. There must be no inactivity timeout for standard Conversations. | Users may return to a Conversation after days or weeks. |
| FR-9.2 | Must | Solo Operator | The user must be able to end a Conversation at any time using an "End Conversation" button, including during active AI generation. | The user must always have the ability to conclude a Conversation on their own terms. |
| FR-9.3 | Should | Solo Operator | In standard and Round-Robin mode, ending a Conversation during active generation must allow the current in-flight response to complete before the end-of-conversation flow begins. | Responses should not be cut off mid-generation by the end action. |
| FR-9.4 | Should | Solo Operator | In P2P mode, triggering "End Conversation" during an autonomous exchange must pause the exchange, allow the system to reach an idle state, and then begin the end-of-conversation flow. | P2P requires graceful interruption to avoid losing in-progress content. |
| FR-9.5 | Should | Solo Operator | If a Conversation contains no user or Persona messages (including Conversations containing only system messages), triggering "End Conversation" must delete the Conversation rather than creating an empty concluded record. | Empty concluded Conversations have no value and should not pollute the concluded history. |
| FR-9.6 | Must | Solo Operator | Once a Conversation is ended, it must become permanently read-only. It must not be possible to re-open an ended Conversation. | Ended Conversations are immutable records. |
| FR-9.7 | Should | Solo Operator | If the user switches to a different Workspace while a Conversation is open, the current in-flight AI response must complete in the background. In Round-Robin mode, the remaining Personas in the current cycle must not respond until the user returns and explicitly resumes. In P2P mode, the autonomous exchange must pause and not continue in the background. | Workspace switching must not leave uncontrolled background processing. |

### FR-10: End-of-Conversation Flow

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-10.1 | Must | Solo Operator | Upon ending a Conversation, the system must automatically generate a summary containing: Key Takeaways, Points of Agreement, Points of Disagreement, and Action Items. | The automatic summary is the primary output of every concluded Conversation. |
| FR-10.2 | Must | Solo Operator | The Automatic Summary must be persisted as part of the ended Conversation and always visible when the user returns to it. The user must be able to copy the summary as Markdown. | The summary's value is permanent; users need to access it later. |
| FR-10.3 | Must | Solo Operator | In Version 1, the Automatic Summary must be a fixed system-generated record with no edit or regenerate controls in the UI. | V1 scope constraint. |
| FR-10.4 | Should | Solo Operator | The end-of-conversation flow must present the user with the option to generate a formal Report. | Report generation is an immediate post-conversation opportunity. |
| FR-10.5 | Could | Solo Operator | The end-of-conversation flow must present a "Canonise this conversation" option. In Version 1, this option must be present in the UI but not functional — it is a placeholder for a future capability. | The placeholder communicates intent without implementing the full feature. |
| FR-10.6 | Must | Solo Operator | The ended Conversation must become part of the concluded Conversation history available for the Review Agent to analyse. | Review Agent processes only concluded Conversations. |

### FR-11: Targeted Summaries

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-11.1 | Should | Solo Operator | At any point during an active Conversation, the user must be able to request a topic-focused targeted summary by addressing the Orchestrator with an explicit `@Orchestrator` mention (e.g., `@Orchestrator Summarise what was said about X so far`). | On-demand summaries help users track progress on specific themes without ending the Conversation. |
| FR-11.2 | Should | Solo Operator | The system must not attempt to detect summary requests from natural language passively — all Orchestrator interactions must require an explicit `@Orchestrator` mention. | Passive detection would be unreliable and could trigger unexpected behaviour. |

### FR-12: Formal Reports

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-12.1 | Should | Solo Operator | The user must be able to generate a formal Report from any concluded Conversation at any time — not only immediately after ending. | Report generation is a permanent option on concluded Conversations. |
| FR-12.2 | Should | Solo Operator | A Report must be a structured Markdown document containing: an overview of the Conversation, a list of participating Personas, key points by topic, perspectives taken by each Persona, outcomes and recommended next steps, and metadata (date, Workspace, Conversation title). | These fields define the minimum content of a useful Report. |
| FR-12.3 | Should | Solo Operator | Multiple Reports must be generatable from the same Conversation (e.g. with different focus areas). | Different stakeholders or purposes may require different Report framings. |
| FR-12.4 | Should | Solo Operator | Only one Report may be generated for a given Conversation at a time — triggering a second generation while one is in progress must be blocked until the first completes. | Concurrent Report generation would produce race conditions. |
| FR-12.5 | Should | Solo Operator | Reports must be saved to the Documents area within the current Workspace. | Reports are workspace-scoped outputs. |
| FR-12.6 | Should | Solo Operator | Each Report must be linked back to its source Conversation for navigation between the Report and the original Conversation, for as long as the Conversation exists. | Direct navigation between Report and source improves usability. |
| FR-12.7 | Should | Solo Operator | Within an active or ended Conversation view, the user must be able to view any Reports related to that Conversation directly from the Conversation view. | Contextual access to Reports without navigating away. |

### FR-13: Documents Area

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-13.1 | Should | Solo Operator | The Documents area must be accessible from the main Workspace navigation alongside Discussions and Personas. | Documents are a primary navigation area. |
| FR-13.2 | Should | Solo Operator | The Documents area must support the following actions on Reports: view, rename, export as Markdown, and delete. | These are the four defined operations on Reports. |
| FR-13.3 | Should | Solo Operator | Deleting a Report must be permanent in Version 1 — there must be no recovery path. | V1 scope constraint; simplicity over reversibility. |
| FR-13.4 | Should | Solo Operator | If all Reports for a Conversation have been deleted, the Conversation view must revert to showing only the "generate a report" option. | The UI must reflect the current state of available Reports. |
| FR-13.5 | Must | Solo Operator | The Documents area must not support user-uploaded files in Version 1. It must contain only system-generated content. | V1 scope constraint. |

### FR-14: The Review Agent

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-14.1 | Should | Solo Operator | The system must include a Review Agent that runs a nightly analysis of concluded Conversations within a Workspace, evaluating each participating Persona against its configuration snapshot from that Conversation. | Nightly analysis catches Persona drift without requiring user action. |
| FR-14.2 | Should | Solo Operator | The Review Agent must evaluate Personas on: Relevance, Role Adherence, Missed Opportunities, and Engagement. | These four dimensions define what "good Persona performance" means. |
| FR-14.3 | Should | Solo Operator | The Review Agent must process all Conversations that concluded since its last run. On the very first run for a Workspace (no prior run), it must process all concluded Conversations with no time-based filter. | Ensures no concluded Conversations are missed on first run. |
| FR-14.4 | Should | Solo Operator | The Review Agent must run asynchronously on a nightly schedule so it never interrupts live Conversations. If the system is not running at the scheduled time, the run must be skipped — there must be no catch-up mechanism. [See OQ-07 for schedule configuration question.] | Background processing must not degrade the user experience. |
| FR-14.5 | Should | Solo Operator | The user must be able to manually trigger a Review Agent run at any time via a "Run now" control in the Personas area. A manual run must cover all Personas in the Workspace, equivalent to the nightly batch. | Users may want immediate analysis without waiting for the nightly run. |
| FR-14.6 | Should | Solo Operator | When a Review Agent run is in progress (whether manual or nightly), the "Run now" button must be disabled until the run completes. Only one run may be in progress at a time — a second triggered run must be blocked and skipped. | Prevents concurrent runs producing inconsistent findings. |
| FR-14.7 | Should | Solo Operator | The Review Agent must also review the Mentor Conversation on an ongoing basis — analysing the most recent activity since its last review. If the Mentor Conversation has had no new activity since the last run, it must be skipped. | The Mentor's conversation never formally concludes, so it requires a separate review mechanism. |
| FR-14.8 | Should | Solo Operator | The Review Agent must skip the Mentor review silently if no Mentor has been configured in the Workspace. | Skipping should not surface an error or notification when the Mentor simply does not exist. |
| FR-14.9 | Should | Solo Operator | If no Conversations have concluded since the last run and the Mentor has no new activity, the Review Agent must skip entirely. | No unnecessary processing when there is nothing to review. |
| FR-14.10 | Should | Solo Operator | If the system shuts down mid-run, partial results must be discarded. The next scheduled trigger must start a fresh run with no attempt to resume. | Partial results are unreliable and should not be surfaced. |
| FR-14.11 | Should | Solo Operator | Active Conversations (not yet ended) and deleted Conversations must not be included in Review Agent processing. | Only formally concluded Conversations are valid inputs for Review Agent analysis. |

### FR-15: Review Agent Findings and Recommendations

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-15.1 | Should | Solo Operator | Findings must be surfaced in a Recommendations section within each Persona's profile in the Personas area. | Recommendations are displayed in the context of the Persona they relate to. |
| FR-15.2 | Should | Solo Operator | Each finding must be persona-specific, include embedded evidence (a quote or description of the relevant exchange inline — not a navigable link), and include a specific, human-readable suggestion for updating the Persona's System Prompt. | Evidence-backed, actionable recommendations are more useful and remain valid even after Conversation deletion. |
| FR-15.3 | Should | Solo Operator | Each finding must offer an Apply and a Dismiss action. When either is taken, the finding card must immediately disappear from the list. | Clear, binary resolution of each finding. |
| FR-15.4 | Should | Solo Operator | Applying a finding must update the Persona's live System Prompt. If the Persona is active in an open Conversation, applying the finding must update the live System Prompt but must leave that Conversation's snapshot unaffected. | Live prompt improvements must not destabilise running Conversations. |
| FR-15.5 | Should | Solo Operator | Findings must persist as visible cards until the user explicitly applies or dismisses them. The list must be refreshed on page load; there must be no real-time updating between page loads. | Findings are stable between sessions; real-time updates are not required. |
| FR-15.6 | Should | Solo Operator | The Review Agent should be able to expand existing findings with new evidence or drop findings that are no longer apparent after recent Conversations. Changes should appear on the next page load. There must be no visible "resolved" state — findings that have been dropped must simply not appear. | Findings should evolve with the evidence base rather than remain static. |
| FR-15.7 | Should | Solo Operator | If a user dismisses a finding, the Review Agent must treat this as a deliberate user preference and suppress that type of suggestion. This suppression is prompt-driven, not a permanent rule — the intent is to avoid repeated prompting, not to permanently suppress valid concerns. [See OQ-03 for threshold question.] | Respects user judgement on dismissed findings. |

### FR-16: Interactive Persona Shaping (Review Agent Consultation)

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-16.1 | Could | Solo Operator | The system must allow the user to engage in a natural language consultation with the Review Agent from within any Persona's Recommendations section. This interface must be an expandable right-hand panel visible when a Persona is selected. | Users need a proactive way to shape Personas without waiting for the nightly run. |
| FR-16.2 | Could | Solo Operator | In interactive consultation mode, the Review Agent must have access to: the Persona's current System Prompt and any existing findings and recommendations for that Persona. It must not have access to full Conversation histories. | This is a distinct access boundary from the automated nightly batch. |
| FR-16.3 | Could | Solo Operator | The interactive consultation session must be discarded when the user navigates away from the Persona's page — no history must be retained. | Sessions are ephemeral by design; no persistence required. |
| FR-16.4 | Could | Solo Operator | The interactive consultation must be fully accessible while the user is on the Persona's page and must be separate from the automated nightly batch process. | Consultation is user-initiated and independent of the automated schedule. |
| FR-16.5 | Must | Solo Operator | When applying a Review Agent finding for the Mentor, the change must be applied directly to the Mentor's live System Prompt and take effect immediately in the ongoing Mentor Conversation. | The Mentor has no snapshot; changes are always live. |

### FR-17: The Mentor

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-17.1 | Must | Solo Operator | Each Workspace must have exactly one Mentor, accessible from the Discussions sidebar. | The Mentor is a per-Workspace construct. |
| FR-17.2 | Must | Solo Operator | The Mentor must be configured in the Personas area alongside all other Personas. Its System Prompt and Temperature must be configurable there. | Consistent configuration UX across all Persona types. |
| FR-17.3 | Must | Solo Operator | The Mentor must not be renameable or deleteable as a standalone action. These controls must be shown as disabled with a tooltip explaining they are not available for the Mentor. The Mentor must only be removed as part of a full Workspace deletion. | The Mentor's identity is fixed within a Workspace; its lifecycle is tied to the Workspace. |
| FR-17.4 | Must | Solo Operator | No Personas other than the Mentor may participate in a Mentor Conversation. | The Mentor Conversation is an exclusive one-to-one channel between the user and the Mentor. |
| FR-17.5 | Must | Solo Operator | The Mentor Conversation must be a single, ongoing, long-lived session. There must be no "start new Conversation" option for the Mentor. | Continuity is the Mentor's defining property. |
| FR-17.6 | Should | Solo Operator | If the user returns to the Mentor Conversation on a different calendar day from their last session and the Mentor Conversation has prior content, the system must present a prompt offering: "Continue where we left off" or "Start a fresh chapter." If the user begins typing without interacting with the prompt, the system must assume continuation. | Chapter boundaries structure the long-running session without forcing the user to choose. |
| FR-17.7 | Should | Solo Operator | The user must be able to manually start a new chapter at any time via a dedicated control in the Mentor Conversation view. | Users may want a chapter break at a point other than day boundaries. |
| FR-17.8 | Should | Solo Operator | A visible chapter marker must be inserted in the Conversation thread at each chapter boundary. The chapter marker must function as a semantic boundary helping the Mentor and Review Agent understand session structure. | Chapter markers are both visual and semantic. |
| FR-17.9 | Must | Solo Operator | Previous chapter content must remain fully visible and scrollable in the Conversation history after a chapter boundary is created. | Chapter boundaries do not delete or hide past content. |

### FR-18: Mentor Three-Layer Memory

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-18.1 | Must | Solo Operator | The Mentor must operate a three-layer memory system: Working Memory (verbatim recent dialogue), Episodic Memory (rolling structured summaries of recent sessions), and Semantic Memory (permanent structured knowledge documents). | The three-layer system enables the Mentor to be both immediately contextual and long-term knowledgeable. |
| FR-18.2 | Must | Solo Operator | Working Memory must be automatically compressed into Episodic Memory, triggered by any of: hitting a capacity threshold mid-session, the start of a new chapter, or the end of a session. [See OQ-05 for ordering question.] | Automatic compression ensures Working Memory does not overflow. |
| FR-18.3 | Must | Solo Operator | Episodic Memory must hold summaries for the most recent N sessions, where N is a configurable window size. When a new session is summarised and the window is full, the system must first check whether any facts in the oldest episodic entry should be promoted to Semantic Memory before retiring it. [See OQ-04 for default N question.] | Prevents silent loss of important long-term information when episodic entries age out. |
| FR-18.4 | Must | Solo Operator | Semantic Memory must not decay — it forms the Mentor's permanent understanding of the user within the Workspace. | Semantic Memory is designed for long-term retention. |
| FR-18.5 | Must | Solo Operator | The Mentor must use all three memory layers to compose contextually-aware, personalised responses. The user must not need to manage the memory directly. | Memory management must be fully automatic from the user's perspective. |

### FR-19: Mentor Memory Inspector

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-19.1 | Should | Solo Operator | The system must provide a read-only Memory Inspector panel accessible from the Mentor's section in the Personas area, showing the user what Episodic and Semantic memories the Mentor currently holds. | Transparency builds user trust in the Mentor's accumulated knowledge. |
| FR-19.2 | Should | Solo Operator | The Memory Inspector must have two sections: Episodic Memory (summary view of recent sessions) and Semantic Memory (the structured Markdown knowledge document displayed as-is). Working Memory must not be shown — it is the live Conversation thread the user can already read. | Working Memory is already visible; only the non-obvious layers need surfacing. |

### FR-20: Context Window Management

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-20.1 | Must | Solo Operator | The system must automatically manage Conversation history when it grows beyond what the model's context window can accommodate, summarising or dropping older messages while preserving the Context Panel and the most recent exchanges. | Long Conversations must remain functional regardless of model context limits. |
| FR-20.2 | Must | Solo Operator | Context window management behaviour must be configurable based on the deployed model. The specific mechanics must be defined during the architecture phase. | Different models have different context capacities; the mechanism cannot be hardcoded. [ARCHITECTURAL FLAG — for Head of Development] |
| FR-20.3 | Should | Solo Operator | When a Conversation is auto-named (see FR-3.5), context compression serves as one trigger for auto-naming in addition to the first targeted summary. | Both events indicate the Conversation has substantive content worth naming. |

### FR-21: AI Model Integration

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-21.1 | Must | Solo Operator | A single, configurable AI model must power all Personas, the Mentor, the Review Agent, the Orchestrator, and all other system functions in Version 1. | Single-model V1 simplifies deployment and configuration. |
| FR-21.2 | Must | Solo Operator | The AI model integration must be abstracted so that a locally-hosted LLM can be swapped for a cloud-based API via configuration alone, with no code changes required. | Model swappability is a core architectural constraint. [ARCHITECTURAL FLAG — for Head of Development] |
| FR-21.3 | Must | Solo Operator | The system must not support different models for different components in Version 1. | V1 scope constraint; multi-model support is a future consideration. |

### FR-22: Deployment and Operability

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-22.1 | Must | Solo Operator | In Version 1, the system must be operable locally on a single machine with no authentication required. | V1 is a local self-hosted deployment; no login is in scope. |
| FR-22.2 | Must | Solo Operator | The system must be architected so it can be deployed to a cloud environment in a future phase without fundamental rework. | Future cloud deployment is a stated product direction. [ARCHITECTURAL FLAG — for Head of Development] |
| FR-22.3 | Must | Solo Operator | The system's data model must include a `user_id` concept from day one — even if that ID is simply a fixed local default in Version 1 — so that multi-user support can be layered on without a data migration. | Retrofitting a `user_id` after the fact requires a data migration; building it in from the start avoids this cost. [ARCHITECTURAL FLAG — for Head of Development] |

### FR-23: Persona Version History (Data Model Readiness)

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| FR-23.1 | Could | Solo Operator | The data model must be designed to support Persona version history (timestamped snapshots of each System Prompt save) from the outset, even if the UI for reviewing or reverting history is not built in Version 1. | A future version history feature requires a data model that tracks save history. Building it in avoids a costly migration. [ARCHITECTURAL FLAG — for Head of Development] |

---

## Non-Functional Requirements

| ID | Priority | User Type | Requirement | Rationale |
| --- | --- | --- | --- | --- |
| NFR-1 | Should | Solo Operator | All user actions that modify data (creating, renaming, deleting Workspaces, Personas, Conversations, Folders, Reports; applying or dismissing findings; saving System Prompts) must complete without requiring a page reload. | A web application must feel responsive and not interrupt the user's flow. |
| NFR-2 | Must | Solo Operator | The system must not lose user-authored content (Context Panel entries, System Prompt edits, Conversation messages) due to transient errors. | Data integrity is critical for a tool the user depends on for advisory work. |
| NFR-3 | Must | Solo Operator | All configuration values (Context Panel character limit, Episodic Memory window size, model endpoint) must be settable in a configuration file without code changes. | The Solo Operator must be able to adapt the system to their model and environment. [ARCHITECTURAL FLAG — for Head of Development] |
| NFR-4 | Must | Solo Operator | The system must handle concurrent background processes (Review Agent nightly run, in-flight AI responses, Workspace switching) without data corruption or loss. | Background and foreground operations must not interfere with each other. |
| NFR-5 | Should | Solo Operator | The system should be deployable from a single machine with minimal setup steps — ideally a single command or a small number of documented steps. | The Solo Operator is likely not a professional system administrator; setup must be accessible. |
| NFR-6 | Should | Solo Operator | Response latency for Persona replies must be acceptable for conversational use, subject to the performance of the configured AI model. The system itself must not introduce unnecessary latency beyond model inference time. | A slow UI would make the advisory conversation experience frustrating. |
| NFR-7 | Must | Solo Operator | All data must be stored locally in Version 1. No user data must be transmitted to third-party services unless the configured model endpoint is a cloud API (which is the user's deliberate choice). | Privacy and data sovereignty for local deployments. |
| NFR-8 | Could | Solo Operator | The system architecture should allow independent scaling of the frontend and backend in a future cloud deployment. | Supports the future cloud deployment direction without constraining V1. [ARCHITECTURAL FLAG — for Head of Development] |

---

## Architectural Flags

The following requirements have architectural implications and are flagged for the Head of Development to resolve:

| ID | Requirement | Architectural Implication |
| --- | --- | --- |
| FR-20.2 | Context window management must be configurable based on the deployed model. | The mechanism for summarising or dropping messages, and the thresholds involved, must be designed as a configurable strategy — not hardcoded logic. |
| FR-21.2 | AI model integration must be abstracted for local/cloud swap via configuration. | Requires a defined model abstraction layer (adapter or provider pattern) that exposes a consistent interface regardless of whether the underlying model is local or cloud-hosted. |
| FR-22.2 | System must be deployable to a cloud environment in future without fundamental rework. | Deployment architecture (containerisation, stateless/stateful split, secrets management) must be considered from day one even though cloud deployment is out of V1 scope. |
| FR-22.3 | Data model must include `user_id` from day one. | All entities (Workspaces, Personas, Conversations, etc.) must be modelled with a `user_id` foreign key. The V1 default value must be defined and consistently applied. |
| FR-23.1 | Data model must support Persona version history from day one. | The Persona table or equivalent must be designed to accommodate save-timestamped versions rather than a single-row overwrite model. |
| NFR-3 | All configuration values must be settable in a config file without code changes. | A configuration schema must be defined and documented. Configuration loading must be part of the application bootstrap. |
| NFR-8 | Architecture should allow independent scaling of frontend and backend. | Frontend and backend must be separate deployable units (not a monolith), even if deployed together in V1. |
| FR-5.3 (Mode 3) | Peer-to-Peer mode turn-taking mechanism requires further technical research. | How the system decides which Persona speaks next, how context is shared between Personas, and how the Orchestrator's role in P2P throttling works must be defined during the architecture phase. |
