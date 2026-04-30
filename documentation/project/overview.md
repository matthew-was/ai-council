# AI Council: System Overview

**Role:** Product Owner  
**Status:** Approved  
**Description:** This document provides a comprehensive, human-readable overview of the AI Council system from the perspective of a Product Owner. It describes what the system does and how a user interacts with it in full detail, without prescribing technical implementation choices. It is the primary source of truth for deriving User Stories and User Requirements, and will be handed to a Head of Development alongside the archived reference documents when producing the system architecture.

---

## 1. Executive Summary

AI Council is a self-hosted web application designed to help a user validate ideas, stress-test strategies, and anticipate objections before real-world meetings. It achieves this by simulating conversations with a curated set of virtual **Personas** — characters with defined perspectives, viewpoints, and advisory styles that the user creates and manages themselves.

The system allows a user to "pitch" an idea or problem to a selected group of Personas and receive structured, perspective-driven feedback. Conversations can be as simple as a one-on-one chat with a single Persona, or as complex as a multi-way debate between several Personas who challenge and respond to each other.

Beyond individual Conversations, the system includes a **Mentor** — a dedicated, long-running personal guide that builds up a deep contextual understanding of the user's goals over time. It also includes a **Review Agent**, a background process that analyses concluded Conversations and suggests improvements to Persona behaviour.

The system is designed around a single, configurable AI model that powers all Personas, the Mentor, the Review Agent, and all other system functions. The model integration is abstracted so that a locally-hosted LLM can be swapped for a cloud-based API without changes to the rest of the system. Supporting different models for different components is a future consideration, not in scope for Version 1.

In its initial phase the system is designed to run locally on a single machine with no authentication required. It must be architected, however, so that it can be deployed to a cloud environment (such as an AWS EC2 instance) in a future phase without fundamental rework.

---

## 2. Core Organisation: Workspaces

The primary organisational unit of the system is a **Workspace**. A Workspace represents a distinct **advisory context** — a curated set of Personas that the user consults together. A Workspace is not tied to a single project or task; it is defined by the perspective group the user wants to work with.

For example, a user might have one Workspace populated with Personas representing their immediate day-to-day colleagues (project manager, designer, developer, team lead), and a completely separate Workspace populated with Personas representing senior leadership (CEO, CTO, finance, marketing). Within each Workspace, individual Conversations and Folders are used to organise the specific topics and projects being worked on.

### 2.1 Workspace Boundaries

- A Workspace is a fully self-contained environment.
- **Total Isolation:** All Personas, Conversations, Documents, and accumulated memory within one Workspace are completely inaccessible to any other Workspace.
- A user switches between Workspaces via a top-level navigation dropdown. The entire interface immediately updates to reflect the selected Workspace.
- Users can create, rename, and delete Workspaces.
- **Deleting a Workspace** permanently removes all content within it — all Personas, Conversations, Folders, Documents, the Mentor Conversation, the Mentor's Working Memory, Episodic Memory, and Semantic Memory, and all Review Agent findings. A confirmation dialog is presented before deletion.

### 2.2 Content Structure within a Workspace

Within a single Workspace, the content is divided into three primary areas accessible from the main navigation:

- **Discussions:** The primary working area where all Conversations with Personas take place.
- **Personas:** The configuration and curation centre for all Personas within the Workspace.
- **Documents:** A workspace-level collection of all system-generated documents such as Reports.

### 2.3 First-Use Experience

When the system is first launched, the user is presented with an empty state and a clear call-to-action to create their first Workspace. Within a new Workspace:

- The Discussions area is empty, with a prompt to start a first Conversation.
- The Personas area is empty. The user must create at least one Persona before they can start a Conversation. The user may create several named Personas upfront and then configure their System Prompts individually.
- The Mentor does not exist until the user creates it. If the user attempts to access the Mentor Conversation before the Mentor has been configured, the system directs them to the Personas area to set up the Mentor first (see Section 8).

---

## 3. The Discussions Area

The Discussions area is the primary working area of the application. It is the home for all Conversations with Personas.

### 3.1 Left-Hand Navigation (Discussions Sidebar)

The Discussions area presents a left-hand sidebar column that lists all Conversations in the current Workspace, structured as follows from top to bottom:

- **Folders (Top):** A user may group related Conversations into named Folders. Each Folder is shown collapsed by default, displaying the folder name and the number of Conversations inside. Clicking a Folder expands it inline to reveal its Conversations. Folders appear at the top of the sidebar.
- **Pinned Conversations:** Any Conversation that the user has pinned appears in a dedicated section below Folders. Pinned Conversations are ordered by pin date — oldest pin first, so the most recently pinned item appears at the bottom of the pinned section.
- **Standalone Conversations (Middle):** Any unpinned Conversation not assigned to a Folder is listed below all Pinned Conversations, individually, in a vertical list. Within this section, Conversations are ordered by most recent activity — defined as the timestamp of the last message received — most recent first.
- **Mentor Conversation (Bottom):** The Mentor Conversation occupies its own distinct zone, permanently fixed to the very bottom of the sidebar and visually separate from all other sections including Pinned Conversations. It is always accessible regardless of scroll position. There is exactly one Mentor Conversation per Workspace (see Section 8). Before the Mentor has been configured, clicking this slot directs the user to the Personas area to set it up.

Within the Folders section, Folders are ordered by creation date, oldest first.

### 3.2 Conversations and Folders

- A **Conversation** is a single, threaded interaction involving the user and one or more Personas.
- A **Folder** is a user-created grouping that can hold one or more Conversations. Folders help organise related Conversations (e.g., all Conversations relating to one product feature).
- A Conversation can exist with or without a Folder. It can be moved into or out of a Folder at any time.
- Users can create, rename, and delete both Folders and Conversations.
- Deleting a Folder does not automatically delete the Conversations within it; the Conversations become standalone.
- Deleting a Conversation does not delete any Review Agent findings that were derived from it. Those findings persist independently on the relevant Persona's Recommendations section. Deleting a Conversation also does not delete any Reports generated from it — those Reports remain in the Documents area, though their link back to the source Conversation will no longer resolve.
- A newly created Conversation is named "New Conversation [timestamp]". If the user has not manually renamed it, the system automatically generates a name on first summarisation of the Conversation — whichever comes first: automatic context compression or the first user-requested targeted summary.
- A user can **pin** or **unpin** any Conversation to keep it easily accessible. A pinned Conversation inside a Folder stays within that Folder and is pinned to the top of the Folder's Conversation list — it does not move to the global Pinned Conversations section. Multiple pinned Conversations within a Folder are ordered by pin date, oldest first. Non-pinned Conversations within a Folder are ordered by most recent activity (last message received), most recent first — the same ordering as standalone unpinned Conversations.
- A user can **export** any Conversation as a raw Markdown file containing all messages in order with speaker labels (see Section 6.5).

---

## 4. The Personas Area

The Personas area is the configuration and curation centre for all Personas within the current Workspace. It functions like a settings page for the advisory characters available to the user in their Conversations.

### 4.1 What a Persona Is

A Persona is a virtual character with a defined advisory perspective and style. The user gives it a name, writes its instructions (a System Prompt), and configures its creative behaviour. In a Conversation, the Persona responds to the user and to other Personas according to the rules set in its System Prompt.

There are no built-in or default Personas. Every Persona is created from scratch by the user.

The **Mentor** also appears in the Personas area list alongside standard Personas, but is visually distinct from them (see Section 8). Its System Prompt and configuration are managed here, while its ongoing Conversation is accessed from the Discussions sidebar.

### 4.2 Creating and Configuring a Persona

When creating a Persona, the user defines:

- **Name:** A clear, identifiable name for the Persona (e.g., "Devil's Advocate", "Financial Critic").
- **Description:** An optional short summary of the Persona's role, visible in the UI to remind the user of its purpose.
- **System Prompt:** The full instruction set for the Persona. This is the most important field and defines how the Persona thinks, what it focuses on, and what it avoids.
- **Temperature:** A single slider controlling the Persona's creative variability. Labelled from "Precise & Analytical" at one end to "Creative & Exploratory" at the other.

A Persona cannot be deleted while it is active in an open Conversation. A Persona is considered active in a Conversation if it has been added as a participant, has not been subsequently removed, and that Conversation has not yet been ended. Attempting to delete such a Persona shows a warning indicating which Conversation(s) it is currently active in, and instructs the user to end or remove the Persona from those Conversations first. Deleting a Persona does not affect any concluded Conversations it participated in — their snapshots, message history, and any Reports generated from them remain fully intact.

### 4.3 Persona Scope

- Personas are Workspace-specific. A Persona created in one Workspace is not visible in or accessible from any other Workspace.
- In Version 1, there is no mechanism to copy, share, or export a Persona to another Workspace.
- In Version 1, there is no template library of pre-built Personas.

### 4.4 Persona Recommendations (Review Agent Integration)

Each Persona in the Personas area has a **Recommendations** section (described in detail in Section 7). This is where the Review Agent surfaces its findings and suggested improvements for that specific Persona, based on analysis of past Conversations it participated in. The Mentor also has a Recommendations section.

### 4.5 Persona Testing (Preview Mode)

The Personas area includes a lightweight **Test** feature for each Persona. The user can send test messages directly from the Persona's configuration page and see how the Persona responds, without needing to start a full Conversation. Saving a System Prompt is an explicit action — the user clicks a Save button. The Test panel runs against the currently saved System Prompt and is disabled while the user has unsaved edits in the System Prompt editor. Once the user saves, the Test panel re-enables. The Test panel maintains a short back-and-forth session, allowing the user to send follow-up messages and iterate on the Persona's System Prompt during creation or refinement. The test session is discarded when the user navigates away from the Persona's page — no history is retained.

---

## 5. Starting and Running a Conversation

### 5.1 Starting a New Conversation

A user initiates a new Conversation by clicking a "New Conversation" button within the Discussions area.

If no Personas exist in the Workspace, clicking "New Conversation" shows a prompt directing the user to create a Persona first. The button is always accessible — it is not disabled — but no Conversation can begin until at least one Persona exists.

When at least one Persona exists, clicking "New Conversation" presents the user with:

1. Selecting the initial **Personas** to include.
2. Choosing the **Conversation Mode** (see Section 5.2). The modes available are informed by the number of Personas selected — 1:1 mode is only offered when exactly one Persona is selected; Round-Robin and Peer-to-Peer require multiple. If only one Persona exists in the Workspace, Round-Robin and Peer-to-Peer do not appear in the mode selection at all.
3. Optionally assigning the Conversation to a **Folder**.
4. Beginning the Conversation by typing their first message.

### 5.2 Conversation Modes

AI Council supports three distinct Conversation modes, which define how Personas participate.

#### Mode 1: 1:1 Conversation

A private, direct interaction between the user and exactly one Persona. The user sends a message and the single Persona responds. Simple and focused. The Orchestrator (see Section 5.4) observes but applies a higher threshold before suggesting an additional Persona, to respect the user's deliberate choice of a focused conversation.

#### Mode 2: Round-Robin (Structured Multi-Persona)

The user selects multiple Personas before the Conversation begins. Responses follow a structured, repeating turn order: the user sends a message, then each selected Persona responds in sequence (e.g., Persona A → Persona B → Persona C), before the cycle returns to the user. Each Persona sees the full Conversation history up to that point, including all messages from the user and from other Personas. Personas see each other's messages but not each other's System Prompts. This mode is useful when the user wants to hear from each Persona in a predictable, structured order.

#### Mode 3: Peer-to-Peer (Dynamic Multi-Persona)

Peer-to-Peer mode is designed to feel more natural than Round-Robin. Multiple Personas participate and respond to the user *or to each other* without requiring the user to prompt each turn. The conversation flows autonomously between Personas, but the user can interject at any point to redirect or contribute. The Orchestrator (Section 5.4) throttles the exchange to prevent runaway Persona-to-Persona loops where two Personas respond to each other indefinitely without meaningful progress.

> **Note:** The precise turn-taking mechanism — how the system decides which Persona speaks next and how context is shared between Personas — requires further technical research and will be defined during the architecture phase.

#### Adding and Removing Personas Mid-Conversation

A user is not locked into the Personas or mode chosen at the start of a Conversation. Additional Personas can be added, and existing Personas can be removed, at any point during an active Conversation. The minimum number of active Personas in a Conversation is one — the user cannot remove the last remaining Persona. If the user wishes to abandon a Conversation entirely, they should delete it rather than stripping it of all Personas.

When a Persona joins or leaves a Conversation, a system message is shown in the Conversation thread to mark the event. Controls for adding, removing, or changing Personas and modes are only available when the system is idle — that is, when all in-progress AI responses have completed and the system is waiting for the next user input. There is no queue; a second action cannot be triggered until the first has resolved. If a Persona is removed and the resulting Persona count drops below the minimum for the current mode (e.g. only one Persona remains in a Round-Robin), the mode automatically adjusts — dropping to 1:1 in this case. System messages in the Conversation thread are included in raw Conversation exports (see Section 6.5).

The Conversation mode can also be changed mid-Conversation using a mode switch control at the top of the Conversation view. This control is only available when the system is idle:

- **1:1 → Round-Robin or Peer-to-Peer**: the user selects the target mode via the mode switch control and is prompted to add one or more Personas before the switch takes effect. Also triggered automatically when the user accepts an Orchestrator suggestion to add a Persona to a 1:1 Conversation — accepting the suggestion is the confirmation, and Round-Robin mode is assumed.
- **Round-Robin → Peer-to-Peer** (or vice versa): triggered by the user via the mode switch control.
- **Switching to a mode requiring fewer Personas** (e.g. switching to 1:1 from Round-Robin): a popup is shown asking the user which Persona(s) to remove. The mode change takes effect once the removal is confirmed.

When a Persona is removed from a Conversation, its previous messages remain visible in the Conversation history and continue to be part of the context available to the remaining Personas. The removed Persona simply stops participating in future exchanges.

### 5.3 Conversation Context Panel

Every Conversation has a user-editable **Conversation Context Panel**. This is a dedicated, visible section of the Conversation view where the user can write and maintain a short, structured summary of the key points, decisions, and constraints from the Conversation so far.

**Purpose:** The Context Panel exists because the AI model has a limited context window. Not all messages from a long Conversation can be included when generating a Persona's response. The Context Panel allows the user to explicitly define and preserve the most important information, ensuring it is always included in the context sent to the model — even as older messages are dropped.

**Behaviour:**

- The Context Panel is entirely **user-owned**. The user writes and edits its contents. The system never writes to the Context Panel automatically.
- After a **targeted summary** (see Section 6.3), the system may offer a one-click option to add key points from the summary into the Context Panel. The user always reviews and confirms before anything is added.
- The Context Panel has a **maximum length**. This limit is a system-wide, operator-configurable value — set in a configuration file to match the deployed model's context window capacity. It cannot be configured per Workspace. It is converted to a character count and displayed to the user within the Context Panel UI, so they can see how much space remains. If the user types beyond the character limit, the input accepts the overflow but displays an error — the user must manually reduce the content to within the limit before it can be saved.
- The contents of the Context Panel are always included in the context sent to the model when generating a Persona's response. When context window space is constrained, older Conversation messages are dropped before the Context Panel is affected. The Context Panel is the last element to be evicted.

**Context Window Management:** When the Conversation history grows beyond what the model's context window can accommodate, the system handles this behind the scenes — summarising or dropping older messages while preserving the Context Panel and the most recent exchanges. The detailed mechanics of this process are defined during architecture and are configurable based on the deployed model.

### 5.4 The Orchestrator

All Conversation modes include a background **Orchestrator**. The Orchestrator is not a visible participant in the Conversation — it is a background process that monitors the interaction.

**The Orchestrator's primary user-facing responsibility is to suggest additional Personas to bring into the Conversation.** Its suggestions are driven by Conversation topic, not by the number of active Personas. It does this by:

- Continuously monitoring the topic and direction of the Conversation.
- Comparing the emerging topics against the Personas available in the Workspace.
- Surfacing a non-intrusive suggestion when it determines a Persona could add meaningful value (e.g., "Your Risk Analyst Persona may be relevant given the current direction").

In 1:1 mode, the Orchestrator applies a higher threshold before suggesting an additional Persona, to respect the user's deliberate choice of a focused conversation. This applies only when other Personas exist in the Workspace but are not yet in the Conversation.

**Rules governing the Orchestrator:**

- The Orchestrator will **never** automatically add a Persona to a live Conversation. Every addition requires explicit user confirmation.
- The Orchestrator is silent whenever there are no other Personas available to suggest — whether because all Workspace Personas are already in the Conversation, or because only one Persona exists in the Workspace.
- If the user dismisses a suggestion, the Orchestrator suppresses that suggestion. This suppression is prompt-driven rather than rule-based, allowing the Orchestrator to exercise judgement — the intent is to avoid spamming the user, not to permanently suppress a valid suggestion. The precise threshold for re-suggesting is defined during implementation.
- In P2P mode, an `@Orchestrator` mention pauses the autonomous Persona exchange. Once the Orchestrator has responded, the user must explicitly resume the exchange — it does not restart automatically.
- When all Workspace Personas are already in the Conversation, the Orchestrator's primary available function via `@Orchestrator` is requesting a targeted summary. Additional functions may emerge as the system is built.

**Peer-to-Peer Role:** Whether the Orchestrator plays a role in managing P2P turn routing and throttling is an open question, dependent on how the technical solution handles the use case. This will be determined during the architecture phase (see Section 5.2, Mode 3).

### 5.5 Conversation Lifecycle

- A Conversation remains **open and resumable** until the user explicitly ends it. The user can close the application, return days later, and continue the Conversation from where they left off.
- If the user switches to a different Workspace while a Conversation is open, switching acts as an interrupt. The current in-flight AI response completes in the background. In Round-Robin mode, the rest of the current cycle is paused — the remaining Personas do not respond until the user returns and explicitly resumes. In P2P mode, the autonomous exchange is paused and does not continue in the background. In all cases, the user must explicitly resume when they return to that Workspace and Conversation.
- There is **no inactivity timeout** for standard Conversations.
- If a Conversation has no user or Persona messages — including Conversations that contain only system messages (e.g. join/leave events) — triggering "End Conversation" deletes the Conversation rather than creating an empty ended record.
- Once a Conversation is **ended** (see Section 6.1), it becomes **read-only**. It can be viewed but no new messages can be added. A Conversation cannot be re-opened once ended.

### 5.6 Conversation Snapshots

When a Conversation begins, the system captures a snapshot of each participating Persona's Name, System Prompt, and Temperature at that moment. The Conversation runs against those snapshots for its entire duration — if the user or the Review Agent modifies a Persona's configuration while a Conversation is active, the running Conversation is unaffected and continues using the version of the Persona from when it started. Each concluded Conversation is therefore a self-contained, stable record: the Persona's name as displayed in the Conversation thread, and the instructions and settings used to generate its responses, are fixed for that Conversation. Snapshots persist independently of the source Persona — if a Persona is later deleted, any concluded Conversations it participated in remain fully intact and readable. When a Persona is added mid-Conversation, their snapshot is taken at the point they join.

If a Persona's configuration has been updated since a Conversation began and the user wants the active Conversation to use the newer version, they can manually refresh that Persona's snapshot from within the Conversation view. The refresh control is only available when the system is idle and the Conversation is active — ended Conversations are read-only and their snapshots are fixed. Previous messages in the Conversation are unaffected by a refresh. This is always a deliberate, user-initiated action — the system never automatically updates a snapshot mid-Conversation.

---

## 6. Ending a Conversation and Managing Output

### 6.1 Ending a Conversation

The user explicitly ends a Conversation by clicking an "End Conversation" button. This control is available at any time, including during active AI generation. In standard and Round-Robin mode, the current in-flight response completes before the end-of-conversation flow begins. In P2P mode, triggering "End Conversation" during an autonomous exchange acts as an interrupt — the Orchestrator pauses the exchange, the system reaches an idle state, and then the end-of-conversation flow begins. Upon ending:

1. The Conversation becomes **read-only**.
2. The system generates an automatic **Summary** (see Section 6.2).
3. The user is presented with the option to generate a formal **Report** (see Section 6.4).
4. The Conversation becomes part of the concluded Conversation history available for the Review Agent to analyse.
5. The user is presented with a **"Canonise this conversation"** option. In Version 1, this option is present in the end-of-conversation UI but is not yet functional. It is a placeholder for a future capability (see Section 9.9). The exact presentation and wording of this placeholder will be determined during implementation.

Canonisation represents a deliberate user choice to make the outcomes of a Conversation part of the participating Personas' persistent memory — distinguishing a productive session whose conclusions should carry forward from a rehearsal whose outcomes should not. In Version 1, all Conversations behave as rehearsals: nothing from them carries over into a Persona's future behaviour.

### 6.2 Automatic Summary

Upon ending a Conversation, the system generates a concise summary containing:

- **Key Takeaways:** The most important conclusions reached.
- **Points of Agreement:** Topics where the Personas aligned.
- **Points of Disagreement:** Topics where Personas held conflicting views.
- **Action Items:** Any next steps or decisions that emerged.

The Automatic Summary is persisted as part of the ended Conversation. It is always visible when the user returns to the Conversation. The summary can also be copied as Markdown for use elsewhere. In Version 1, the summary is a fixed system-generated record — no edit or regenerate controls are provided in the UI. A future version may allow the user to regenerate it with an optional focus prompt to direct what the summary emphasises.

### 6.3 Targeted Summaries (During a Conversation)

At any point during an active Conversation, the user can request a targeted summary by addressing the Orchestrator directly using `@Orchestrator` (e.g., `@Orchestrator Summarise what was said about X so far`). The Orchestrator does not attempt to detect summary requests from natural language passively — all Orchestrator interactions require an explicit `@Orchestrator` mention. In Round-Robin mode, an `@Orchestrator` mention interrupts the current cycle — the current in-flight response completes, then the Orchestrator responds. The system will parse the Conversation history and return a summary focused specifically on the requested topic.

Targeted summaries serve a dual purpose: they provide a focused view of part of the Conversation, and they can also be used to help maintain the **Conversation Context Panel** (Section 5.3). After generating a targeted summary, the system may offer a one-click option to add the key points to the Context Panel, subject to user confirmation. This offer is one-time per targeted summary — if the user declines, the offer does not persist. The user can request another targeted summary, but the output will not be identical due to the nature of LLM generation. If the Context Panel is near its character limit, the system warns the user rather than truncating — the user must decide manually which existing content to remove to make space. The exact threshold at which the near-capacity warning appears is an implementation decision; it is fixed in Version 1 and may become configurable in a future version.

### 6.4 Formal Reports

Following a concluded Conversation, the user can optionally request a formal **Report** at any time — the option remains available permanently on any concluded Conversation, not only immediately after ending. A Report is a comprehensive, structured Markdown document that includes:

- An overview of the Conversation
- A list of participating Personas
- Key points documented by topic
- The perspectives each Persona took
- Outcomes, decisions, and recommended next steps
- Metadata (date, Workspace, Conversation title)

Reports are saved to the **Documents area** within the current Workspace (see Section 6.6). Each Report is linked back to its source Conversation — the user can navigate directly between the Report and the original Conversation for any intact concluded Conversation. Multiple Reports can be generated from the same Conversation — for example, with different focus areas.

### 6.5 Raw Conversation Export

At any time, the user can export any Conversation — whether active or ended — as a raw Markdown file. The export control is only available when the system is idle, ensuring all in-progress responses are captured before the export executes. The export contains all messages in chronological order with speaker labels (user and Persona names), including system messages such as Persona join and leave events. It is a simple, unformatted record of the Conversation, distinct from the structured formal Report (Section 6.4).

### 6.6 The Documents Area

The Documents area is a workspace-level collection of all system-generated documents, primarily **Reports** (Section 6.4). It is accessible from the main Workspace navigation alongside the Discussions and Personas areas.

- Documents are **Workspace-scoped** and subject to the same total isolation rules as all other Workspace content.
- Within an active or ended Conversation, the user can view any documents related to that Conversation (e.g., its generated Reports) directly from the Conversation view.
- The following actions are available on Reports in the Documents area: **view**, **rename**, **export** (as Markdown in Version 1; PDF export is a future consideration), and **delete**. Deletion is permanent in Version 1 — there is no recovery path. Only one Report can be generated for a given Conversation at a time — triggering a second generation while one is in progress is blocked until the first completes. Deleting a Report removes it from the Documents area. If other Reports for the same Conversation remain, the Conversation view continues to show links to them alongside the option to generate another. The Conversation view reverts to showing only the "generate a report" option if all Reports for that Conversation have been deleted.
- The Documents area does not support user-uploaded files in Version 1. It contains only system-generated content.

---

## 7. The Review Agent

### 7.1 Purpose

The Review Agent is a background system that runs a nightly analysis of concluded Conversations within a Workspace. Its purpose is to prevent Personas from drifting off-topic or underperforming over time, by evaluating them against their defined System Prompts and surfacing improvement suggestions.

### 7.2 How It Works

The Review Agent runs on a fixed nightly schedule, asynchronously, so it never interrupts live Conversations. If the system was not running at the scheduled time, the run is skipped — there is no catch-up mechanism. The user can manually trigger a review at any time via a "Run now" control in the Personas area. When a run is in progress (whether triggered manually or by the nightly schedule), the "Run now" button is disabled until the run completes. A manual run covers all Personas in the Workspace, equivalent to the nightly batch.

A **concluded Conversation** is one the user has explicitly ended via the End Conversation button. Active Conversations (not yet ended) and deleted Conversations are not included in Review Agent processing. It processes all Conversations that concluded since its last run. Each concluded Conversation is processed independently. On the very first run for a Workspace (no prior run has ever occurred), the Review Agent processes all concluded Conversations in the Workspace with no time-based filter.

The Review Agent evaluates standard Conversations and the Mentor independently — it runs for whichever has new activity, regardless of the other. If no Conversations have concluded since the last run and the Mentor has no new activity, the Review Agent skips entirely. Only one run can be in progress at a time — if a manual run is triggered while a nightly run is already in progress (or vice versa), the second run is blocked and skipped. If a Workspace is deleted while a Review Agent run is in progress for it, the run is stopped immediately. If the system shuts down mid-run, partial results are discarded — the run starts fresh on the next scheduled trigger with no attempt to resume. Any in-progress model response that was generating in the background (due to a Workspace switch) is also discarded when the Workspace is deleted. If no Mentor has been configured in the Workspace, the Mentor review is silently skipped.

**Important:** The automated Review Agent run has access to full concluded Conversation histories — this is its primary input. The interactive consultation mode (Section 7.4) does **not** have access to Conversation histories. These are two distinct access rules for the same component.

As a special case, the **Mentor Conversation** never formally concludes, so the Review Agent also reviews the Mentor Conversation on an ongoing basis — analysing the most recent activity since its last review. If the Mentor Conversation has had no new activity since the last run, it is skipped.

For each Persona that appeared in those Conversations, it evaluates performance against the Persona's configuration snapshot from that Conversation (see Section 5.6) — ensuring the assessment reflects the instructions the Persona was actually operating under at the time. Any suggested improvements are proposed as changes to the Persona's current live System Prompt. The Mentor has no snapshot (its Conversation never ends), so it is evaluated against its current live System Prompt directly.

The Review Agent evaluates:

- **Relevance:** Were the Persona's responses on-topic for the Conversation?
- **Role Adherence:** Did the Persona stay within the boundaries of its System Prompt?
- **Missed Opportunities:** Were there moments in the Conversation where the Persona could have contributed meaningfully but did not?
- **Engagement:** Did the user respond to or engage with the Persona's contributions?

### 7.3 Findings and Recommendations

Findings are surfaced in the **Recommendations** section of the Persona's profile within the Personas area. Key characteristics:

- **Persona-Specific:** Each Persona has its own independent set of findings. This includes the Mentor.
- **Evidence-Embedded:** Every finding references its source interaction by quoting or describing the relevant exchange inline. There is no navigable link to the source Conversation — the evidence is embedded in the finding itself. Deletion of a Conversation therefore does not affect the finding.
- **Actionable:** Each finding comes with a specific, human-readable suggestion for how to update the Persona's System Prompt to improve future performance.
- **1-Click Application:** The user can click **Apply** to immediately update the Persona's live System Prompt with the suggested change, or **Dismiss** to reject it. When either action is taken, the finding card fades out and disappears from the list immediately. If the Persona is currently active in an open Conversation, applying the finding updates the live System Prompt but leaves that Conversation's snapshot unaffected — the running Conversation continues using the snapshot taken when it started.
- **Persistent:** Findings remain visible as cards until the user explicitly acts on them (applies or dismisses). The list is refreshed on page load — there is no real-time updating between page loads.
- **Evolving:** The nightly run may expand existing findings with new evidence, or drop findings that are no longer apparent after recent Conversations. Changes appear on the next page load; there is no visible "resolved" state — findings that have been dropped simply do not appear. Whether an updated finding refreshes its existing card or appears as a new card is implementation-defined.
- **Post-apply behaviour:** If a user applies a finding and the issue persists in subsequent Conversations, the Review Agent may raise a new finding with further refinement suggestions. If a user dismisses a finding, the Review Agent treats this as a deliberate user preference and suppresses that type of suggestion. This suppression is prompt-driven rather than rule-based, allowing the Review Agent to exercise judgement — the intent is to avoid spamming the user, not to permanently suppress a valid concern. The precise threshold for re-raising a dismissed finding is defined during implementation.

### 7.4 Interactive Persona Shaping (Natural Language Consultation)

In addition to the automated nightly findings, the user can engage in a direct, natural language conversation with the Review Agent within any Persona's Recommendations section. This interactive consultation interface is embedded in the Personas area as an expandable right-hand panel, visible when a Persona is selected. The Review Agent is a distinct system component, not a user-created Persona.

This allows the user to proactively request help shaping a Persona that is not behaving as expected — even if the automated review has not yet detected a pattern.

For example, a user might type: *"This Persona keeps being too agreeable. I want it to challenge my assumptions more forcefully. Can you suggest how I should update its System Prompt?"*

**Context available to the Review Agent in this mode:**

- The Persona's current System Prompt.
- Any existing findings and recommendations for that Persona.
- The Review Agent does **not** have access to full Conversation histories in this mode. If the user wants to reference specific Conversation excerpts, they should paste the relevant content into the chat.

In a future version, when Persona Memory is introduced (see Section 9.9), the Review Agent's interactive consultation mode will also have access to the Persona's current memory. This is important because the Review Agent will need to help the user understand the distinction between what belongs in the System Prompt (persistent behavioural traits and instructions) and what belongs in memory (specific facts and outcomes from past Conversations) — and to propose changes to either accordingly.

The interactive consultation is fully accessible while the user is on the Persona's page. When the user navigates away, the consultation is discarded — no history is retained. The consultation is powered by the same single AI model as all other system functions. This mode of interaction is initiated by the user on demand and is separate from the automated nightly batch process.

**Applying findings to the Mentor:** When the user applies a Review Agent finding for the Mentor, the change is applied directly to the Mentor's live System Prompt and takes effect immediately in the ongoing Mentor Conversation. Unlike standard Personas, the Mentor has no snapshot — its Conversation never ends — so there is no snapshot to update.

### 7.5 Future Expansion of Review Agent Responsibilities

In a future version of the system, the Review Agent's responsibilities will expand beyond prompt analysis to include two additional functions. First, **memory canonisation**: when the user chooses to canonise a concluded Conversation (see Sections 6.1 and 9.9), the Review Agent processes the Conversation's outcomes and proposes what should be added to each participating Persona's persistent memory. Second, **memory correction**: when a user reports that a Persona is acting on incorrect or outdated information, the Review Agent proposes a corrective update to that Persona's memory. In all cases, the established user experience pattern is preserved — the Review Agent proposes a change, and the user approves or dismisses it.

---

## 8. The Mentor

### 8.1 What the Mentor Is

The Mentor is a special-purpose Persona that exists within the normal Persona framework but has unique properties. It is a dedicated, long-running personal coach for the current Workspace. Unlike standard Personas, the Mentor accumulates a persistent, structured memory of the user's context, goals, decisions, and history within the Workspace over time.

There is exactly one Mentor per Workspace. It cannot be renamed or deleted as a standalone action within the Personas area — these controls are shown as disabled with a tooltip explaining that these actions are not available for the Mentor. The Mentor is removed only as part of a full Workspace deletion. No other Personas can participate in a Mentor Conversation.

### 8.2 Mentor Configuration

The Mentor is configured in the **Personas area** alongside all other Personas. Its System Prompt and settings are managed there.

The Mentor's configuration has a deliberate two-part structure:

- **System Prompt — who the Mentor is as a coach.** This defines the Mentor's coaching character: its style, focus areas, how it challenges the user, and what it avoids. For example: "You are a direct, Socratic coach who challenges assumptions rather than validates them. You focus on communication clarity, strategic thinking, and how the user presents ideas to others." The System Prompt should remain stable once written.

- **Context Panel — who the user is.** The Mentor Conversation's Context Panel (see Section 8.3) is where the user maintains their background, experience, current goals, and standing constraints for this Workspace. For example: "I'm a web developer with 10 years of TypeScript experience. I'm working on improving how I communicate technical decisions to non-technical stakeholders." This evolves naturally as the user's context shifts, and can be updated directly without editing the System Prompt.

In Version 1, the Mentor is created like any other Persona — the user writes a System Prompt and populates the Context Panel manually. A guided Mentor creation wizard is planned for a future version, which would help the user define both the coaching character and their personal context through a structured flow.

The Mentor does not exist until the user creates it. The Mentor Conversation slot in the sidebar is always present and directs the user to the Personas area if the Mentor has not yet been configured (see Section 3.1).

### 8.3 The Mentor Conversation UI

The Mentor Conversation is always pinned to the bottom of the Discussions sidebar, visually distinct from all standard Folders and Conversations. Clicking it opens the dedicated Mentor chat view.

Unlike standard Conversations, the Mentor Conversation is a single, ongoing, long-lived session. There is no "start new Conversation" option — the user always returns to the same session. This continuity is what allows the Mentor to build up deep context over time.

Like all Conversations, the Mentor Conversation has a **Context Panel**. For the Mentor, this panel serves a distinct purpose: it is where the user maintains their standing personal context — role, background, experience, current goals, and constraints — rather than a summary of the current discussion. The Mentor always has this context available regardless of how far back in the Conversation history it can reach. See Section 8.2 for guidance on what to put here.

### 8.4 Session Continuity and Chapters

If the user returns to the Mentor Conversation on a different calendar day from their last session (a change of date, not a 24-hour elapsed period), and the Mentor Conversation has prior content, the system presents a prompt at load time with a choice:

- **Continue where we left off** — the Mentor picks up with awareness of the last topic discussed.
- **Start a fresh chapter** — the session advances to a new chapter.

If the user does not interact with the prompt and begins typing, the system assumes continuation. The previous content is not removed from the Conversation — it remains fully visible and scrollable in the chat history. A visible chapter marker is inserted in the Conversation thread at the boundary point; the exact visual treatment is an implementation decision. The chapter marker is also a semantic boundary that helps the Mentor and the Review Agent understand the structure of the user's sessions over time. It signals a natural break point, allowing the Mentor to begin a new line of enquiry without assuming continuity with the previous topic.

In addition to the inactivity prompt, the user can manually start a new chapter at any time via a dedicated control in the Mentor Conversation view.

### 8.5 Three-Layer Memory

The Mentor operates an automatic, three-layer memory system that runs transparently in the background:

1. **Working Memory**
   The exact, verbatim dialogue from the most recent portion of the current session. This gives the Mentor immediate, precise awareness of the current Conversation. Working Memory is compressed into Episodic Memory automatically — triggered by either hitting a capacity threshold mid-session or the start of a new chapter. The specific thresholds are defined during architecture.

2. **Episodic Memory**
   A rolling set of structured entries covering two distinct sources:

   - **Session summaries** — compressed records of the Mentor's own Conversation, promoted from Working Memory at chapter boundaries or compression thresholds. Each captures the key topics discussed, challenges raised, decisions made, and conclusions reached within a session.
   - **Conversation observations** — structured observations generated by the Conversation Observer (see Section 8.7) when a non-Mentor Conversation concludes. These record how the user communicated in that Conversation: how they structured their arguments, whether they had to re-explain themselves, and what techniques they used to bridge expertise gaps. These observations are stored in Episodic Memory alongside session summaries and feed into the same Semantic promotion process.

   Episodic Memory holds entries within a configurable window size defined during architecture. When the window is full, the system first checks whether any facts in the oldest entry should be promoted to Semantic Memory before retiring it.

3. **Semantic (Long-Term) Memory**
   Permanent, structured facts extracted from both session summaries and Conversation observations, and stored as Knowledge Documents. Examples include the user's communication patterns, confirmed decisions, recurring priorities, and important constraints. Unlike Episodic Memory, Semantic Memory does not decay. It forms the Mentor's persistent understanding of the user within this Workspace.

The Mentor uses all three layers to compose contextually-aware, highly personalised responses. The user does not need to manage this memory directly — it is handled automatically. The system manages transitions between memory layers based on capacity constraints; specific thresholds are defined during architecture and are configurable based on the deployed model.

### 8.6 Mentor Memory Inspector

The Mentor includes a read-only **Memory Inspector** panel, accessible from the Mentor's section in the Personas area. This panel shows the user what Episodic and Semantic memories the Mentor currently holds — what it "knows" about the user and the Workspace context. This transparency helps the user understand why the Mentor gives certain advice and builds trust in the Mentor's accumulated knowledge.

The panel is divided into two sections:

- **Episodic Memory:** A summary view of all episodic entries, clearly labelled by source. Entries originating from the Mentor's own Conversation sessions are shown separately from entries generated by the Conversation Observer from non-Mentor Conversations. The source label for each observed entry identifies the Conversation it came from, so the user can understand what the Mentor learned and where it came from.
- **Semantic Memory:** The structured Markdown knowledge document displayed directly, as-is. This is the Mentor's long-term understanding of the user — preferences, confirmed decisions, recurring priorities, communication patterns, and important constraints. Semantic facts drawn from Conversation observations are included here alongside those drawn from the Mentor's own sessions.

Working Memory is intentionally absent from the Memory Inspector — it is the live Conversation thread itself, which the user can already read directly. Only Episodic and Semantic memory are surfaced here.

### 8.7 Conversation Observer

The **Conversation Observer** is a background process that runs automatically whenever a non-Mentor Conversation is concluded. Its purpose is to give the Mentor awareness of the user's communication patterns across all their advisory Conversations — not just what they discuss with the Mentor directly.

**What it observes:** The Conversation Observer does not analyse Persona behaviour or evaluate the quality of Persona responses — that is the Review Agent's job. Instead, it looks at the Conversation from the user's perspective:

- How the user structured their discussion points and arguments for the Personas they were talking to.
- Whether the user had to repeat or re-explain themselves during the Conversation.
- What techniques the user employed to bridge expertise gaps — for example, the use of analogies or concrete examples to explain technical concepts to non-technical Personas.
- How effectively those techniques appeared to land.

**When it runs:** The Conversation Observer runs fire-and-forget at the moment a Conversation is concluded (the same trigger as the automatic Summary). It analyses the Conversation and writes a single structured observation entry to the Mentor's Episodic Memory, with `source_conversation_id` recording which Conversation it came from.

**Relationship to the Review Agent:** Both the Conversation Observer and the Review Agent process the same concluded Conversations, but they produce entirely different outputs. The Review Agent produces findings about Persona behaviour and suggests System Prompt improvements. The Conversation Observer produces observations about the user's communication and feeds them to the Mentor's memory. They are independent processes with no shared output.

**If no Mentor is configured:** If the Workspace has no Mentor, the Conversation Observer skips silently — there is nowhere to write the observation.

**On Mentor creation:** When the user creates the Mentor for the first time in a Workspace, the Conversation Observer runs a one-time backfill — processing all concluded Conversations in the Workspace that pre-date the Mentor's creation. This ensures the Mentor begins with a useful starting context about the user's communication patterns, rather than starting cold with no episodic history.

---

## 9. Future Considerations

The following capabilities are not in scope for Version 1 of the system but have been considered as part of the overall product direction. The system should be designed in a way that allows these to be added in future without requiring fundamental architectural changes.

### 9.1 Persona Version History

In Version 1, saving changes to a Persona's System Prompt overwrites the previous version. In a future version, each save should create a versioned snapshot with a timestamp, allowing the user to review the history of changes to a Persona's configuration and revert to a previous version if needed. The data model should be designed to support this from the outset even if the UI for it is not built yet.

### 9.2 Multi-User Authentication

Version 1 will run in a local, single-user mode with no login required. The system should be designed with a clear path to add OAuth2-based authentication in a future version for cloud deployment or multi-user scenarios. The underlying data model should use a `user_id` concept internally from day one, even if that ID is simply a fixed local default in Version 1, so that multi-user support can be layered on without a data migration.

### 9.3 Conversation Archiving and Retention

In Version 1, concluded Conversations will remain in the system indefinitely. A future version should introduce a formal archiving policy (e.g., Conversations moved to a read-only archive after a period of inactivity, with eventual permanent deletion). This should be user-configurable on a per-Conversation or per-Workspace basis. Pinned Conversations should be exempt from automatic archiving.

### 9.4 User Onboarding

Version 1 provides a lightweight first-use experience (see Section 2.3) with empty states and clear calls-to-action. A future version may benefit from a more structured onboarding flow, such as a guided wizard to help new users create their first Workspace, Personas, and Mentor.

### 9.5 Persona Sharing, Templates, and Duplication

In Version 1, Personas cannot be shared between Workspaces, duplicated, or exported. A future version should allow a user to copy a Persona from one Workspace to another, duplicate a Persona within the same Workspace to create variations, and potentially support a library of community-contributed Persona templates.

### 9.6 Mentor Creation Wizard

In Version 1, the Mentor is created by writing a System Prompt (the coaching character) and populating the Context Panel (the user's background and goals) manually. A future version should provide a guided creation wizard with two distinct phases: first, helping the user define the Mentor's coaching character and style to generate an appropriate System Prompt; second, walking the user through their background, goals, and constraints to seed the Context Panel. This two-phase structure maps directly to the deliberate separation between who the Mentor is and who the user is.

### 9.7 Multi-Model Support

In Version 1, a single AI model powers all system functions. A future version may allow different components (Personas, Mentor, Review Agent, Orchestrator) to use different models — for example, a larger model for the Mentor and a smaller, faster model for the Orchestrator's suggestion logic.

### 9.8 Resource Limits

A future version should introduce configurable limits on the number of Workspaces, Personas, Conversations, and Folders a user can create, to support resource management and multi-user deployments.

### 9.9 Persona Memory

In Version 1, a Persona's knowledge is limited to its System Prompt and the history of the current Conversation. In a future version, Personas would gain persistent memory that carries across Conversations — allowing them to "remember" what was established in past sessions and behave consistently over time.

The mechanism for controlling this is **canonisation** (see Section 6.1): at the end of a Conversation, the user explicitly chooses whether its outcomes become part of the participating Personas' memory. Conversations that are not canonised function as rehearsals — the Personas are unaffected by them going forward. This deliberate, opt-in model ensures that practice sessions and exploratory conversations do not accidentally pollute a Persona's understanding of the user's context.

Persona memory would work in two layers: a record of recent canonised Conversation outcomes, and a synthesised summary of those records that is included in the Persona's context when it responds. Older records age out gradually — deliberate forgetting is a feature, not a limitation, as it prevents stale context from accumulating and degrading a Persona's usefulness over time. This two-layer model is intentionally simpler and shallower than the Mentor's three-layer memory system (see Section 8.5): Personas have narrower, more focused advisory roles and benefit from shorter-horizon memory, whereas the Mentor's value comes from deep, long-term understanding of the user.

When a user notices a Persona behaving on the basis of incorrect or outdated information, they report this through the interactive consultation interface in the Persona's Recommendations section (see Section 7.4). The Review Agent proposes a correction, which takes precedence until the older incorrect record ages out naturally.

Persona memory would not be directly editable by the user — all additions and corrections happen through the Review Agent interface, consistent with the existing pattern. The memory is not hidden, however: a read-only memory inspector for Personas (similar to the Mentor's Memory Inspector described in Section 8.6) could be introduced in a future version to give the user transparency into what a Persona currently knows.

### 9.10 Alternative Use Cases

AI Council as currently designed positions the user as a participant inside an advisory context — in the room with the Personas, subject to the same dynamics they would face in reality. The same underlying architecture, with different Persona design conventions, could support meaningfully different use case patterns. Two directions worth exploring are strategic command practice and role-playing game facilitation.

In a **strategic command practice (war gaming)** mode, Personas would be designed as rational actors with defined positions and information asymmetries to defend, rather than advisory voices. The user would practise how to direct, influence, and respond to people with competing priorities — making the system a tool for developing leadership and negotiation skills rather than purely an advisory sounding board.

In an **RPG or Game Master facilitation** mode, Personas would take on NPC or player character roles, with one Persona configured by convention to act as the Game Master — holding narrative state and world context through its System Prompt and memory. This is a standard Persona used with a specific design intent (typically with a higher Temperature for creative variability), not a structurally distinct role. An RPG campaign would span multiple Conversations — one per session — making Persona Memory (Section 9.9) essential: all Personas, including the GM, would need to remember what happened in previous sessions. This use case also points toward a further-future requirement: the ability to configure the episodic memory window size at the Workspace level, so that long-running campaigns can retain a deeper history than the default advisory use case requires. A useful framework for understanding how these use cases differ from each other and from the core advisory mode is to map them across two axes: whether the user is an observer of the simulation or an active participant within it, and whether the Personas are operating as logical actors with defined objectives or as characters with personality and evolving emotional states.

These are potential future directions enabled by the existing architecture, not committed roadmap items.

### 9.11 Institutional Knowledge Document

In Version 1, Personas have no shared persistent state — each Persona knows only what is in the current Conversation history and its own configuration. A future extension would introduce an **Institutional Knowledge Document** at the Workspace level: a persistent, system-managed document capturing what has been decided, what positions each Persona has taken, and what the user has committed to across past Conversations. All Personas in the Workspace would have read access to this document, functioning as a shared institutional memory that allows them to behave as if they inhabit the same world and have a shared history with each other.

The Institutional Knowledge Document would be maintained through the canonisation process (Section 9.9, Section 6.1). When a Conversation is canonised, the Review Agent produces two sets of proposals for the user to approve: per-Persona memory entries capturing what was established for each participating Persona, and an update to the Institutional Knowledge Document capturing the higher-level outcomes relevant to the Workspace as a whole. Both are proposed for user approval, consistent with the existing Review Agent pattern. Initially the document would be system-managed and read-only for the user; direct user editing is a further future consideration.

The Institutional Knowledge Document would be particularly important for the war gaming and RPG use cases described in Section 9.10, where consistency of shared world knowledge across all Personas is essential to the experience.

---

## 10. Out of Scope for Version 1

The following capabilities will **not** be included in Version 1:

- Multi-user support or authentication
- Persona templates, sharing, or duplication
- Webhooks or external integrations
- Public API access
- Conversation history search or tagging
- Full guided onboarding wizard
- User-uploaded documents
- Multi-model routing (different models for different components)

---

## 11. Glossary

| Term | Definition |
| --- | --- |
| **Workspace** | The top-level organisational unit. Represents a distinct advisory context with its own isolated set of Personas, Conversations, Documents, and Mentor. |
| **Discussions Area** | The primary section of the application where all Conversations take place. One of the three main navigation areas within a Workspace. |
| **Conversation** | A single, threaded interaction between the user and one or more Personas. Takes place within the Discussions area. |
| **Concluded Conversation** | A Conversation that the user has explicitly ended via the End Conversation button. Concluded Conversations are read-only and are the primary input for the Review Agent's nightly analysis. Active and deleted Conversations are not concluded. |
| **Folder** | A user-created grouping within the Discussions area that can hold one or more related Conversations. |
| **Persona** | A virtual character with a defined advisory perspective and style, created and configured by the user. Responds in Conversations according to its System Prompt. |
| **System Prompt** | The full instruction set for a Persona, defining how it thinks, what it focuses on, and what it avoids. |
| **Mentor** | A special-purpose Persona with a long-lived, ongoing Conversation and a three-layer memory system. One per Workspace. Provides personalised, context-aware guidance. |
| **Orchestrator** | A background process that monitors active Conversations and suggests additional Personas that could add value. Never adds Personas without user confirmation. |
| **Review Agent** | A background system that analyses concluded Conversations nightly and surfaces improvement suggestions for each Persona's System Prompt. |
| **Conversation Observer** | A background process that runs when a non-Mentor Conversation is concluded. Analyses the user's communication patterns in that Conversation and writes a structured observation to the Mentor's Episodic Memory. Distinct from the Review Agent, which analyses the same Conversations for Persona improvement. |
| **Context Panel** | A user-owned, editable section within each Conversation where the user maintains key points, decisions, and constraints. Always included in the context sent to the AI model. |
| **Documents Area** | A workspace-level collection of system-generated documents, primarily Reports. One of the three main navigation areas within a Workspace. |
| **Report** | A comprehensive, structured Markdown document generated from a concluded Conversation, containing an overview, perspectives, outcomes, and metadata. |
| **Targeted Summary** | An on-demand, topic-specific summary of part of a Conversation, requested by the user during an active Conversation. |
| **Conversation Snapshot** | A record of each participating Persona's Name, System Prompt, and Temperature captured at the moment a Conversation begins (or when a Persona joins mid-Conversation). The Conversation runs against these snapshots for its full duration; edits to a Persona elsewhere in the system do not affect an already-running Conversation. Snapshots persist independently of the source Persona. |
| **Canonisation** | A deliberate user action taken at the end of a Conversation to make its outcomes part of the participating Personas' persistent memory and the Institutional Knowledge Document. Conversations that are not canonised function as rehearsals with no lasting effect on Persona behaviour. A future feature; a UI placeholder is present in Version 1. |
| **Persona Memory** | A future capability giving standard Personas persistent memory that carries across Conversations. Operates in two layers: a record of recent canonised Conversation outcomes, and a synthesised summary included in the Persona's context when it responds. Managed exclusively through the Review Agent interface. |
| **Institutional Knowledge Document** | A future Workspace-level document maintained by the system that captures shared history, decisions, and context across all Personas. Updated through the canonisation process. All Personas in the Workspace have read access to it; it is not directly editable by the user in its initial form. |
