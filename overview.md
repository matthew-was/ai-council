# 🏢 AI Council: System Design & Implementation Plan

*(Self-Hosted System for Institutional Knowledge with Specialized Personas)*

---

## 1. Executive Summary

### Purpose

Build a **self-hosted AI Council system** to simulate conversations with specialized personas (e.g., user research panel, senior management) for validating ideas before real meetings. The system helps users:

- Test assumptions with diverse perspectives.
- Identify risks and opportunities early.
- Generate actionable insights and reports.

### Key Outcomes

1. **Persona-Based Guidance:** Simulate interactions with roles like Vision Keeper, Technical Mentor, and Business Strategist.
2. **Threaded Conversations:** Organize discussions into folders for context.
3. **Context Optimization:** Handle local LLM context windows with summarization and chunking.
4. **User-Specific Data:** Segregate data for multiple users (e.g., Matthew, Rosie).
5. **Dynamic Agent Involvement:** Orchestrator manages agent hand-offs and flags gaps in real time.
6. **Continuous Improvement:** Post-session reviews optimize agent prompts and involvement rules.

---

## 2. User Journeys

### Journey 1: Creating a Conversation (Main User Journey)

1. User starts on the **Conversations/Folders page**.
2. Clicks **"New Conversation"** (no folder required).
3. Enters a query in the input area.
4. Conversation appears in the **left sidebar** (simple list).

### Journey 2: Creating an Agent

1. User opens the **Personas/Agents page**.
2. Clicks **"New Agent"**.
3. Sets the agent’s role, color, and instructions.
4. Agent is now available for use in conversations.

### Journey 3: Managing Documents

1. User uploads or generates a document.
2. Document appears in the **left sidebar** (Documents page).
3. Clicking it loads the content; user can delete it via the button at the bottom.

### Journey 4: Using the Mentor Agent

1. User starts a **regular conversation** with the Mentor Agent.
2. On first use, if the user hasn’t defined the Mentor:
    - The system **creates the Mentor Agent** with:
        - Knowledge about the user (e.g., background, needs).
        - Knowledge about where the user needs guidance.
3. Mentor Agent replies with **personalized suggestions**.
4. User references past conversations (e.g., *"How did I handle the Vision Keeper in this folder?"*).

### Journey 5: Ending a Conversation

1. User clicks **"End conversation"** in the header.
2. System generates a **summary** (key takeaways, disagreements, action items).
3. User can:
    - View the summary in the conversation view.
    - Generate a **report** (saved as `/reports/{user_id}/{conversation_id}/report.md`).
    - Access **Review Agent’s suggestions** in the Agent Page.

---

## 3. UI/UX Design

### 3.1 Left Sidebar

- **Folders:** Create, rename, delete, or archive folders.
- **Conversations:** List of all conversations, including those not in folders.
- **Documents:** Simple list of documents (e.g., reports).

### 3.2 Main Panel

- **Conversation View:**
  - Displays active conversation (Markdown-rendered).
  - **"End Conversation"** button generates a summary.
  - **"Copy Summary as Markdown"** for reuse.
  - **"Create Report"** option (if more detail is needed).
- **Mentor Conversations:** Special UI—no other agents allowed.

### 3.3 Right Sidebar

- **Active Agents:** List of agents in the current conversation.
- **Agent Management:** Add/remove agents, update instructions.

### 3.4 Navigation

Toggle between:

- **Conversations/Folders** (default).
- **Documents** (list with delete option).
- **Agents/Personas** (management page).

---

## 4. Agent/Persona Management

### 4.1 Agent Roles

| **Panel** | **Persona** | **Focus Areas** |
| --- | --- | --- |
| **User Research** | Early Adopter Alex | Feature novelty, innovation. |
| | Budget-Conscious Priya | Cost, ROI, alternatives. |
| | Power User Maya | Performance, customization. |
| | Non-Technical Jamie | Usability, clear instructions. |
| | Privacy-Focused Sam | Data handling, compliance. |
| **Senior Management** | Vision Keeper | Mission alignment, ethics. |
| | Technical Mentor | APIs, scalability, trade-offs. |
| | Business Strategist | Pricing, competition, go-to-market. |
| | Devil’s Advocate | Risks, worst-case scenarios. |
| | Process Optimizer | Workflows, automation. |

### 4.2 Mentor Agent

- **Special Conversation:** No other agents allowed.
- **Knowledge Base:** Includes user background and past interactions for personalized guidance.
- **First-Use Creation:** System creates the Mentor Agent on first use with user-specific knowledge.

### 4.3 Review Agent

- **Optimization:** Analyzes ended conversations.
- **Storage:** Stores reviews in the **Agent Page**.

#### Review Agent Analysis Process

The Review Agent evaluates agent performance by:

1. **Comparing Agent Purpose to Conversation:**
    - Uses the **agent’s defined purpose** (not full instructions) to assess whether the agent:
        - **Overstepped boundaries** (e.g., a Technical Mentor discussing marketing).
        - **Missed opportunities** (e.g., a Privacy-Focused agent not addressing compliance in a data-related discussion).
2. **Suggesting Instruction Updates:**
    - Queries an LLM to determine if the agent’s instructions should be refined to better align with its purpose.
    - Example suggestion:

        > *"The Privacy-Focused agent missed addressing GDPR compliance in the data storage discussion. Suggest updating its instructions to explicitly include 'compliance' as a focus area."*
        >

---

## 5. Context Optimization

### 5.1 Automatic Summarization

- **Trigger:** When context exceeds token limits or conversation ends.
- **Output:** Key takeaways, disagreements, action items.
- **Example:**

    > *"Key Takeaways: The team agreed on a hybrid API approach. Alex emphasized scalability, while Priya raised cost concerns. Action Item: Test the hybrid approach by EOD Friday."*
    >

### 5.2 User-Requested Summarization

- **Trigger:** User types:
  - *"Summarize this discussion so far."*
  - *"Summarize the conversation so far specifically referencing the discussion about the GraphQL API."*
- **Output:** Prioritizes the requested topic in the summary.

#### Example of Targeted Summarization

**User Request:**

> *"Summarize the discussion about the GraphQL API."*

**System Response:**

> *"Key Points on GraphQL API:
>
> - Alex (Early Adopter) advocated for GraphQL due to its flexibility for front-end queries.
> - Maya (Power User) raised concerns about over-fetching and suggested a hybrid REST/GraphQL approach.
> - Action Item: Prototyping a hybrid API by EOD Friday (Owner: Technical Mentor)."*

### 5.3 Copy Summary as Markdown

- **Feature:** Users can copy the summary as Markdown for reuse in new conversations.

### 5.4 Chunking

- **Older Messages:** Summarized and archived to stay within token limits.
- **Fallback Behavior:** Partial context + guidance if full history can’t fit.

---

## 6. Core Components

| **Component** | **Technology Stack** | **Responsibility** |
| --- | --- | --- |
| **AI Model** | Mistral 7B (Ollama) | Backend LLM for persona interactions. |
| **Backend** | FastAPI + LangGraph | Orchestrate services, manage context, and handle dynamic agent workflows. |
| **Database** | PostgreSQL | Store conversations, folders, summaries, and reports. |
| **UI** | Streamlit | Interface for users to interact with personas and manage folders. |
| **Reports** | Markdown Files | Save persona-generated reports to `/reports/{user_id}/{conversation_id}/`. |
| **Deployment** | Docker + Docker Compose | Containerize services for portability and backups. |

---

## 7. System Architecture

### 7.1 Folders and Conversations

- **Folders:** High-level groups of related discussions (e.g., "API Design").
- **Conversations:** Individual chats within a folder (e.g., with the Vision Keeper).

### 7.2 Agent Suggestion Logic

The orchestrator (LangGraph) suggests agents based on:

- **Conversation Purpose:** Matches keywords/topics in the conversation to the **purpose of available agents**.
  - Example: A discussion about "API scalability" triggers a suggestion to involve the **Technical Mentor** (purpose: "APIs, scalability, trade-offs").
- **Review Agent Feedback:** The Review Agent may refine agent purposes over time to improve suggestions.

### 7.3 Post-Session Review Process

- **Goal:** Improve agent prompts and involvement rules.
- **Analysis:** Logs conversation history (topics, agents, user feedback) and flags underutilized agents.

---

## 8. Data Model

### 8.1 Core Entities

| **Entity** | **Key Columns** | **Purpose** |
| --- | --- | --- |
| **Users** | `id`, `name`, `email` | Store user information. |
| **Folders** | `id`, `user_id`, `title`, `created_at` | Group related conversations. |
| **Conversations** | `id`, `user_id`, `folder_id`, `query`, `response`, `context_summary`, `token_count` | Store individual chats and their context. |
| **Documents** | `id`, `user_id`, `title`, `path`, `timestamp` | Track user-uploaded or generated reports. |
| **Agents** | `agent_id`, `role`, `color`, `instructions` | Define personas with roles/instructions. |
| **Review Agent Data** | `review_id`, `conversation_id`, `agent_id`, `recommendation`, `timestamp` | Store reviews and recommendations. |

### 8.2 File Structure

- **Reports:** `/reports/{user_id}/{conversation_id}/report.md`
- **Backups:** Docker volumes for PostgreSQL data and reports.

---

## 9. Implementation Roadmap

### Phase 1: Core System (1–2 Weeks)

1. **Set Up Infrastructure:** Dockerize PostgreSQL, FastAPI, Streamlit; configure Ollama.
2. **Define Persona Roles:** Hardcode agent prompts; test responses.
3. **Build Folder/Conversation Management:** Implement PostgreSQL tables and FastAPI endpoints.
4. **Develop Streamlit UI:** Folder selection, conversation display, query input.

### Phase 2: Multi-User Support (1 Week)

1. **Extend Database Schema:** Add `user_id` to all tables.
2. **Update UI:** User selection dropdown, user-specific views.
3. **Test with Multiple Users:** Verify data segregation and context retention.

### Phase 3: Dynamic Agents and Continuous Improvement (Future)

1. **Move Agent Configs to Database:** Create an `agents` table.
2. **Implement Post-Session Review:** Log and analyze agent involvement.
3. **Refine Orchestrator Logic:** Update gap-flagging rules.

---

## 10. Key Decisions

| **Decision Point** | **Resolution** | **Alternatives Considered** | **Rationale** |
| --- | --- | --- | --- |
| **Agent Hand-offs** | Hybrid: Agents suggest hand-offs, but users must confirm. | Automatic hand-offs or user-only hand-offs. | Balances automation with user control; avoids misrouting. |
| **Report Automation** | Manual loading with smart suggestions. | Auto-loading reports or no suggestions. | Avoids clutter; user-driven aligns with flexibility preferences. |
| **Review Scope** | Focus on improving agent prompts and involvement rules. | Cross-user analysis for system-wide improvements. | Aligns with user-specific agents; avoids privacy/complexity concerns. |
| **Folder Descriptions** | Add a `description` field to folders. | No descriptions or mandatory descriptions. | Low effort, adds useful context for user-specific folders. |
| **Summarization Granularity** | Per-conversation summaries. | Per-folder summaries. | Simpler to implement; aligns with local LLM context needs. |
| **UI for Editing Summaries** | Inline edit with UI swap (view/edit toggle). | Separate modal or no editing. | Clean UI with flexibility for edits. |
| **Agent Storage** | Phased approach: Start hardcoded, move to database soon (user-specific only). | Database from start or hardcoded indefinitely. | Avoids early complexity; aligns with phased approach. |
| **Framework Choice** | **LangGraph** for dynamic agent workflows. | AutoGen or LangChain. | Best for hybrid orchestrator/P2P modes and stateful conversations. |
| **Mentor Agent UI** | Special UI: No other agents allowed in Mentor conversations. | Allow other agents in Mentor conversations. | Ensures focused guidance without distractions. |
| **Summaries vs Reports** | Summaries always generated; reports only on user request. | Always generate both or only reports. | Balances automation with user control. |

---

## 11. Failure Modes and Mitigations

| **Failure Mode** | **Primary Mitigation** | **Fallback Action** |
| --- | --- | --- |
| Token Limit Exceeded | Preemptive chunking + fallback prompts. | Show last N messages. |
| Low-Quality Summaries | Structured prompts + user validation. | Highlight uncertainties. |
| Database Errors | Retry logic + local cache. | Notify user of local save. |
| Model Hallucinations | Constrained prompts. | Fallback to truncation. |
| Race Conditions | Database locks or task queue. | Notify user of conflict. |
| Missing Context | Overlap chunks + key phrase extraction. | Link to full history. |
| Language/Format Issues | Prompt constraints + user preferences. | Let user reformat. |
| Dependency Failures | Health checks + graceful degradation. | Show raw snippets. |

---

## 12. Glossary

| **Term** | **Definition** | **Documentation** |
| --- | --- | --- |
| **Folder** | A group of related conversations (e.g., "API Design"). | |
| **Conversation** | An individual chat within a folder (e.g., with the Vision Keeper). | |
| **Context Summary** | A condensed version of older messages to fit the model’s context window. | |
| **Persona Role** | The specific function of an agent (e.g., Technical Mentor). | |
| **Hand-off** | Transferring a conversation from one agent to another. | |
| **LangGraph** | A framework for managing dynamic agent workflows and stateful conversations. | [LangGraph GitHub](https://github.com/langchain-ai/langgraph) |
| **Ollama** | A tool for running large language models (e.g., Mistral 7B) locally. | [Ollama GitHub](https://github.com/jmorganca/ollama) |

---

## 13. Appendices

### A. Example Agent Workflow

1. User starts a folder: "Semantic Search Feature".
2. Vision Keeper discusses high-level goals.
3. Context is summarized and passed to the Technical Mentor for API design.
4. Reports are generated and saved to `/reports/{user_id}/{conversation_id}/`.

### B. Backup Strategy

- **PostgreSQL:** Daily backups of the database volume.
- **Reports:** Version-controlled Markdown files in `/reports/`.

---

## 14. Resources

- **Mistral 7B Documentation:** [Ollama Docs](https://github.com/jmorganca/ollama)
- **FastAPI Tutorials:** [FastAPI Guide](https://fastapi.tiangolo.com/)
- **Streamlit Examples:** [Streamlit Gallery](https://streamlit.io/gallery)
- **PostgreSQL Best Practices:** [PostgreSQL Docs](https://www.postgresql.org/docs/)
- **LangGraph Documentation:** [LangGraph GitHub](https://github.com/langchain-ai/langgraph)
