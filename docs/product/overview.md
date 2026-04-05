# AI Council: System Overview

**Role:** Project Manager  
**Status:** In Review  
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
- **Deleting a Workspace** permanently removes all content within it — all Personas, Conversations, Folders, Documents, Mentor history, and Review Agent findings. A confirmation dialog is presented before deletion.

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

- **Folders (Top):** A user may group related Conversations into named Folders. Each Folder is shown collapsed by default, displaying the folder name and the number of Conversations inside. Clicking a Folder expands it inline to reveal its Conversations.
- **Pinned Conversations:** Any Conversation that the user has pinned appears in a dedicated section above the unpinned standalone Conversations, ensuring important Conversations are always easy to find.
- **Standalone Conversations (Middle):** Any unpinned Conversation not assigned to a Folder is listed below all Folders, individually, in a vertical list.
- **Mentor Conversation (Bottom, Pinned):** Pinned permanently to the very bottom of the sidebar is the Mentor Conversation. It is visually distinct from all other items and is always accessible. There is exactly one Mentor Conversation per Workspace (see Section 8).

### 3.2 Conversations and Folders

- A **Conversation** is a single, threaded interaction involving the user and one or more Personas.
- A **Folder** is a user-created grouping that can hold one or more Conversations. Folders help organise related Conversations (e.g., all Conversations relating to one product feature).
- A Conversation can exist with or without a Folder. It can be moved into or out of a Folder at any time.
- Users can create, rename, and delete both Folders and Conversations.
- Deleting a Folder does not automatically delete the Conversations within it; the Conversations become standalone.
- Deleting a Conversation does not delete any Review Agent findings that were derived from it. Those findings persist independently on the relevant Persona's Recommendations section.
- A user can **pin** or **unpin** any Conversation to keep it easily accessible at the top of the sidebar.
- A user can **export** any Conversation as a raw Markdown file containing all messages in order with speaker labels (see Section 6.5).

---

## 4. The Personas Area

The Personas area is the configuration and curation centre for all Personas within the current Workspace. It functions like a settings page for the advisory characters available to the user in their Conversations.

### 4.1 What a Persona Is

A Persona is a virtual character with a defined advisory perspective and style. The user gives it a name, writes its instructions (a System Prompt), and configures its creative behaviour. In a Conversation, the Persona responds to the user and to other Personas according to the rules set in its System Prompt.

There are no built-in or default Personas. Every Persona is created from scratch by the user.

The **Mentor** also appears in the Personas area as a special-purpose Persona with restrictions (see Section 8). Its System Prompt and configuration are managed here, while its ongoing Conversation is accessed from the Discussions sidebar.

### 4.2 Creating and Configuring a Persona

When creating a Persona, the user defines:

- **Name:** A clear, identifiable name for the Persona (e.g., "Devil's Advocate", "Financial Critic").
- **Description:** An optional short summary of the Persona's role, visible in the UI to remind the user of its purpose.
- **System Prompt:** The full instruction set for the Persona. This is the most important field and defines how the Persona thinks, what it focuses on, and what it avoids.
- **Temperature:** A single slider controlling the Persona's creative variability. Labelled from "Precise & Analytical" at one end to "Creative & Exploratory" at the other.

### 4.3 Persona Scope

- Personas are Workspace-specific. A Persona created in one Workspace is not visible in or accessible from any other Workspace.
- In Version 1, there is no mechanism to copy, share, or export a Persona to another Workspace.
- In Version 1, there is no template library of pre-built Personas.

### 4.4 Persona Recommendations (Review Agent Integration)

Each Persona in the Personas area has a **Recommendations** section (described in detail in Section 7). This is where the Review Agent surfaces its findings and suggested improvements for that specific Persona, based on analysis of past Conversations it participated in. The Mentor also has a Recommendations section.

### 4.5 Persona Testing (Preview Mode)

The Personas area includes a lightweight **Test** feature for each Persona. The user can send a quick test message directly from the Persona's configuration page and see how the Persona responds, without needing to start a full Conversation. This allows the user to rapidly iterate on a Persona's System Prompt during creation or refinement.

---

## 5. Starting and Running a Conversation

### 5.1 Starting a New Conversation

A user initiates a new Conversation by clicking a "New Conversation" button within the Discussions area. At this point, the user:

1. Chooses the **Conversation Mode** (see Section 5.2).
2. Selects the initial **Personas** to include.
3. Optionally assigns the Conversation to a **Folder**.
4. Begins the Conversation by typing their first message.

### 5.2 Conversation Modes

AI Council supports three distinct Conversation modes, which define how Personas participate.

#### Mode 1: 1:1 Conversation
A private, direct interaction between the user and exactly one Persona. The user sends a message and the single Persona responds. Simple and focused. The Orchestrator (see Section 5.4) observes but rarely needs to interject.

#### Mode 2: Round-Robin (Structured Multi-Persona)
The user selects multiple Personas before the Conversation begins. Responses follow a structured, repeating turn order: the user sends a message, then each selected Persona responds in sequence (e.g., Persona A → Persona B → Persona C), before the cycle returns to the user. Each Persona sees the full Conversation history up to that point, including all messages from the user and from other Personas. Personas see each other's messages but not each other's System Prompts. This mode is useful when the user wants to hear from each Persona in a predictable, structured order.

#### Mode 3: Peer-to-Peer (Dynamic Multi-Persona)
Multiple Personas participate and may respond to the user *or to each other* as the Conversation flows naturally. The user can address a specific Persona directly, which may then prompt a response to the user or trigger a response from a different Persona.

> **Note:** The Peer-to-Peer mode requires further technical research to fully define. Key areas still under exploration include: the precise turn-taking mechanism (how the system decides which Persona speaks next), how to prevent infinite Persona-to-Persona loops, and how context is shared between Personas in this mode. The Orchestrator (Section 5.4) may play a role in routing and throttling Persona turns. If the Peer-to-Peer mode proves technically infeasible in Version 1, the Round-Robin mode serves as a capable fallback for multi-Persona Conversations.

#### Adding and Removing Personas Mid-Conversation
A user is not locked into the Personas or mode chosen at the start of a Conversation. Additional Personas can be added, and existing Personas can be removed, at any point during an active Conversation. The Conversation mode can also be changed mid-Conversation (e.g., elevating a 1:1 into a Round-Robin by adding Personas).

When a Persona is removed from a Conversation, its previous messages remain visible in the Conversation history and continue to be part of the context available to the remaining Personas. The removed Persona simply stops participating in future exchanges.

### 5.3 Conversation Context Panel

Every Conversation has a user-editable **Conversation Context Panel**. This is a dedicated, visible section of the Conversation view where the user can write and maintain a short, structured summary of the key points, decisions, and constraints from the Conversation so far.

**Purpose:** The Context Panel exists because the AI model has a limited context window. Not all messages from a long Conversation can be included when generating a Persona's response. The Context Panel allows the user to explicitly define and preserve the most important information, ensuring it is always included in the context sent to the model — even as older messages are dropped.

**Behaviour:**
- The Context Panel is entirely **user-owned**. The user writes and edits its contents. The system never writes to the Context Panel automatically.
- After a **targeted summary** (see Section 6.3), the system may offer a one-click option to add key points from the summary into the Context Panel. The user always reviews and confirms before anything is added.
- The Context Panel has a **maximum length**, configured to ensure sufficient context window space remains for Conversation history and Persona responses. The specific limit is determined by the deployed model's capacity and defined during architecture.
- The contents of the Context Panel are always included in the context sent to the model when generating a Persona's response, taking priority over older messages.

**Context Window Management:** When the Conversation history grows beyond what the model's context window can accommodate, the system handles this behind the scenes — summarising or dropping older messages while preserving the Context Panel and the most recent exchanges. The detailed mechanics of this process are defined during architecture and are configurable based on the deployed model.

### 5.4 The Orchestrator

All Conversation modes include a background **Orchestrator**. The Orchestrator is not a visible participant in the Conversation — it is a background process that monitors the interaction.

**The Orchestrator's primary user-facing responsibility is to suggest additional Personas to bring into the Conversation.** It does this by:
- Continuously monitoring the topic and direction of the Conversation.
- Comparing the emerging topics against the Personas available in the Workspace.
- Surfacing a non-intrusive suggestion when it determines a Persona could add meaningful value (e.g., "Your Risk Analyst Persona may be relevant given the current direction").

**Rules governing the Orchestrator:**
- The Orchestrator will **never** automatically add a Persona to a live Conversation. Every addition requires explicit user confirmation.
- If the user dismisses a suggestion, the Orchestrator will not immediately re-suggest the same Persona.
- The Orchestrator may re-suggest a dismissed Persona if the topic of the Conversation shifts substantially.

**Peer-to-Peer Role:** In the Peer-to-Peer Conversation mode, the Orchestrator may also take on a behind-the-scenes role in managing the routing and pacing of Persona turns. This aspect of its behaviour is subject to ongoing technical research (see Section 5.2, Mode 3).

### 5.5 Conversation Lifecycle

- A Conversation remains **open and resumable** until the user explicitly ends it. The user can close the application, return days later, and continue the Conversation from where they left off.
- There is **no inactivity timeout** for standard Conversations.
- Once a Conversation is **ended** (see Section 6.1), it becomes **read-only**. It can be viewed but no new messages can be added. A Conversation cannot be re-opened once ended.

---

## 6. Ending a Conversation and Managing Output

### 6.1 Ending a Conversation

The user explicitly ends a Conversation by clicking an "End Conversation" button. Upon ending:

1. The Conversation becomes **read-only**.
2. The system generates an automatic **Summary** (see Section 6.2).
3. The user is presented with the option to generate a formal **Report** (see Section 6.4).
4. The Conversation becomes part of the concluded Conversation history available for the Review Agent to analyse.

### 6.2 Automatic Summary

Upon ending a Conversation, the system generates a concise summary containing:
- **Key Takeaways:** The most important conclusions reached.
- **Points of Agreement:** Topics where the Personas aligned.
- **Points of Disagreement:** Topics where Personas held conflicting views.
- **Action Items:** Any next steps or decisions that emerged.

The summary is displayed within the Conversation view and can be copied as Markdown for use elsewhere.

### 6.3 Targeted Summaries (During a Conversation)

At any point during an active Conversation, the user can request a targeted summary by typing a natural language prompt such as "Summarise what was said about X so far." The system will parse the Conversation history and return a summary focused specifically on the requested topic.

Targeted summaries serve a dual purpose: they provide a focused view of part of the Conversation, and they can also be used to help maintain the **Conversation Context Panel** (Section 5.3). After generating a targeted summary, the system may offer a one-click option to add the key points to the Context Panel, subject to user confirmation.

### 6.4 Formal Reports

Following a concluded Conversation, the user can optionally request a formal **Report**. A Report is a comprehensive, structured Markdown document that includes:
- An overview of the Conversation
- A list of participating Personas
- Key points documented by topic
- The perspectives each Persona took
- Outcomes, decisions, and recommended next steps
- Metadata (date, Workspace, Conversation title)

Reports are saved to the **Documents area** within the current Workspace (see Section 6.6). Each Report is linked back to its source Conversation, so the user can navigate between the Report and the original Conversation.

### 6.5 Raw Conversation Export

At any time, the user can export any Conversation — whether active or ended — as a raw Markdown file. This export contains all messages in chronological order with speaker labels (user and Persona names). It is a simple, unformatted record of the Conversation, distinct from the structured formal Report (Section 6.4).

### 6.6 The Documents Area

The Documents area is a workspace-level collection of all system-generated documents, primarily **Reports** (Section 6.4). It is accessible from the main Workspace navigation alongside the Discussions and Personas areas.

- Documents are **Workspace-scoped** and subject to the same total isolation rules as all other Workspace content.
- Within an active or ended Conversation, the user can view any documents related to that Conversation (e.g., its generated Report) directly from the Conversation view.
- The Documents area does not support user-uploaded files in Version 1. It contains only system-generated content.

---

## 7. The Review Agent

### 7.1 Purpose

The Review Agent is a background system that runs a nightly analysis of concluded Conversations within a Workspace. Its purpose is to prevent Personas from drifting off-topic or underperforming over time, by evaluating them against their defined System Prompts and surfacing improvement suggestions.

### 7.2 How It Works

The Review Agent runs once per night, asynchronously, so it never interrupts live Conversations. It processes all Conversations that concluded since its last run. Each concluded Conversation is processed independently.

If no Conversations have concluded since the last run, the Review Agent skips.

As a special case, the **Mentor Conversation** never formally concludes, so the Review Agent also reviews the Mentor Conversation on an ongoing basis — analysing the most recent activity since its last review.

For each Persona that appeared in those Conversations, it evaluates:
- **Relevance:** Were the Persona's responses on-topic for the Conversation?
- **Role Adherence:** Did the Persona stay within the boundaries of its System Prompt?
- **Missed Opportunities:** Were there moments in the Conversation where the Persona could have contributed meaningfully but did not?
- **Engagement:** Did the user respond to or engage with the Persona's contributions?

### 7.3 Findings and Recommendations

Findings are surfaced in the **Recommendations** section of the Persona's profile within the Personas area. Key characteristics:

- **Persona-Specific:** Each Persona has its own independent set of findings. This includes the Mentor.
- **Evidence-Linked:** Every finding links to the specific Conversation(s) from which it was derived, so the user can review the evidence themselves.
- **Actionable:** Each finding comes with a specific, human-readable suggestion for how to update the Persona's System Prompt to improve future performance.
- **1-Click Application:** The user can click **Apply** to immediately update the Persona's prompt with the suggested change, or **Dismiss** to reject it.
- **Persistent:** Findings remain visible until the user explicitly acts on them (applies or dismisses).
- **Evolving:** The nightly run may expand existing findings with new evidence, or mark them as resolved if the issue is no longer apparent after recent Conversations.

### 7.4 Interactive Persona Shaping (Natural Language Consultation)

In addition to the automated nightly findings, the user can engage in a direct, natural language conversation with the Review Agent within any Persona's Recommendations section. This allows the user to proactively request help shaping a Persona that is not behaving as expected — even if the automated review has not yet detected a pattern.

For example, a user might type: *"This Persona keeps being too agreeable. I want it to challenge my assumptions more forcefully. Can you suggest how I should update its System Prompt?"*

**Context available to the Review Agent in this mode:**
- The Persona's current System Prompt.
- Any existing findings and recommendations for that Persona.
- The Review Agent does **not** have access to full Conversation histories in this mode. If the user wants to reference specific Conversation excerpts, they should paste the relevant content into the chat.

These interactive consultations are stored as persistent conversations associated with the Persona. Older consultations may be hidden from the default view but remain accessible.

This mode of interaction is initiated by the user on demand and is separate from the automated nightly batch process.

---

## 8. The Mentor

### 8.1 What the Mentor Is

The Mentor is a special-purpose Persona that exists within the normal Persona framework but has unique properties. It is a dedicated, long-running personal coach for the current Workspace. Unlike standard Personas, the Mentor accumulates a persistent, structured memory of the user's context, goals, decisions, and history within the Workspace over time.

There is exactly one Mentor per Workspace. It cannot be renamed, deleted, or replaced, and no other Personas can participate in a Mentor Conversation.

### 8.2 Mentor Configuration

The Mentor is configured in the **Personas area** alongside all other Personas. Its System Prompt and settings are managed there. The Mentor's System Prompt should include relevant background about the user for this Workspace's context — for example, the user's role, experience, technical skills, and goals that would help the Mentor provide useful guidance (e.g., "The user is a web developer with 10 years of TypeScript experience and a reasonable grasp of DevOps principles with AWS").

In Version 1, the Mentor is created like any other Persona — the user writes a System Prompt and configures its settings. A guided Mentor creation wizard is planned for a future version.

The Mentor does not exist until the user creates it. If the user attempts to access the Mentor Conversation before the Mentor has been configured, the system directs them to the Personas area to set up the Mentor.

### 8.3 The Mentor Conversation UI

The Mentor Conversation is always pinned to the bottom of the Discussions sidebar, visually distinct from all standard Folders and Conversations. Clicking it opens the dedicated Mentor chat view.

Unlike standard Conversations, the Mentor Conversation is a single, ongoing, long-lived session. There is no "start new Conversation" option — the user always returns to the same session. This continuity is what allows the Mentor to build up deep context over time.

### 8.4 Session Continuity and Chapters

If the user returns to the Mentor Conversation after a significant period of inactivity, the system prompts them with a choice:
- **Continue where we left off** — the Mentor picks up with awareness of the last topic discussed.
- **Start a fresh chapter** — the session advances to a new chapter. The previous content is not removed from the Conversation — it remains fully visible and scrollable in the chat history. The chapter marker is a semantic boundary that helps the Mentor and the Review Agent understand the structure of the user's sessions over time. It signals a natural break point, allowing the Mentor to begin a new line of enquiry without assuming continuity with the previous topic.

### 8.5 Three-Layer Memory

The Mentor operates an automatic, three-layer memory system that runs transparently in the background:

1. **Working Memory**  
   The exact, verbatim dialogue from the most recent portion of the current session. This gives the Mentor immediate, precise awareness of the current Conversation. When this grows beyond the available capacity, the oldest messages are compressed into Episodic Memory.

2. **Episodic Memory**  
   A rolling set of structured summaries derived from the most recent sessions and chapters. Each summary captures the key topics discussed, challenges raised, decisions made, and conclusions reached. Episodic memories are automatically removed after 30 days of inactivity.

3. **Semantic (Long-Term) Memory**  
   Permanent, structured facts extracted from Conversations and stored as Knowledge Documents. Examples include user preferences, confirmed decisions, recurring priorities, and important constraints. Unlike Episodic Memory, Semantic Memory does not decay. It forms the Mentor's persistent understanding of the user within this Workspace.

The Mentor uses all three layers to compose contextually-aware, highly personalised responses. The user does not need to manage this memory directly — it is handled automatically. The system manages transitions between memory layers based on capacity constraints; specific thresholds are defined during architecture and are configurable based on the deployed model.

### 8.6 Mentor Memory Inspector

The Mentor includes a read-only **Memory Inspector** panel, accessible from the Mentor's section in the Personas area. This panel shows the user what Episodic and Semantic memories the Mentor currently holds — what it "knows" about the user and the Workspace context. This transparency helps the user understand why the Mentor gives certain advice and builds trust in the Mentor's accumulated knowledge.

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

In Version 1, the Mentor is created by writing a System Prompt like any other Persona. A future version should provide a guided creation wizard that helps the user define their background, goals, and context for the Workspace in a structured way, automatically generating an appropriate Mentor System Prompt.

### 9.7 Multi-Model Support

In Version 1, a single AI model powers all system functions. A future version may allow different components (Personas, Mentor, Review Agent, Orchestrator) to use different models — for example, a larger model for the Mentor and a smaller, faster model for the Orchestrator's suggestion logic.

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
|------|------------|
| **Workspace** | The top-level organisational unit. Represents a distinct advisory context with its own isolated set of Personas, Conversations, Documents, and Mentor. |
| **Discussions Area** | The primary section of the application where all Conversations take place. One of the three main navigation areas within a Workspace. |
| **Conversation** | A single, threaded interaction between the user and one or more Personas. Takes place within the Discussions area. |
| **Folder** | A user-created grouping within the Discussions area that can hold one or more related Conversations. |
| **Persona** | A virtual character with a defined advisory perspective and style, created and configured by the user. Responds in Conversations according to its System Prompt. |
| **System Prompt** | The full instruction set for a Persona, defining how it thinks, what it focuses on, and what it avoids. |
| **Mentor** | A special-purpose Persona with a long-lived, ongoing Conversation and a three-layer memory system. One per Workspace. Provides personalised, context-aware guidance. |
| **Orchestrator** | A background process that monitors active Conversations and suggests additional Personas that could add value. Never adds Personas without user confirmation. |
| **Review Agent** | A background system that analyses concluded Conversations nightly and surfaces improvement suggestions for each Persona's System Prompt. |
| **Context Panel** | A user-owned, editable section within each Conversation where the user maintains key points, decisions, and constraints. Always included in the context sent to the AI model. |
| **Documents Area** | A workspace-level collection of system-generated documents, primarily Reports. One of the three main navigation areas within a Workspace. |
| **Report** | A comprehensive, structured Markdown document generated from a concluded Conversation, containing an overview, perspectives, outcomes, and metadata. |
| **Targeted Summary** | An on-demand, topic-specific summary of part of a Conversation, requested by the user during an active Conversation. |
