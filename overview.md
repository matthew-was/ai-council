# AI Council: Project Overview & Implementation Plan

*(Self-Hosted System for Institutional Knowledge with Specialized Personas)*

---

## 1. Project Goals

**Purpose:**

Build a self-hosted system with specialized personas to support decision-making, technical guidance, and strategic planning for the Institutional Knowledge project.

**Key Outcomes:**

- **Persona-Based Guidance:** Specialized personas with distinct roles (e.g., Vision Keeper, Technical Mentor) provide focused expertise.
- **Threaded Conversations:** Group related discussions (e.g., "Semantic Search Feature") for context.
- **Context Optimization:** Handle small context windows (e.g., Mistral 7B) with summarization and chunking.
- **Multi-User Support:** Segregate data for multiple users (e.g., Matthew, Rosie).
- **Self-Hosted & Secure:** Full control over data and infrastructure.

---

## 2. Core Components

| Component | Technology Stack | Responsibility |
| --- | --- | --- |
| **AI Model** | Mistral 7B (Ollama) | Backend LLM for persona interactions. |
| **Backend** | FastAPI + LangChain | Orchestrate services, manage context, and interact with the database. |
| **Database** | PostgreSQL | Store conversations, threads, summaries, and reports. |
| **UI** | Streamlit | Interface for users to interact with personas and manage threads. |
| **Reports** | Markdown Files | Save persona-generated reports to `/reports/{user_id}/{thread_id}/`. |
| **Deployment** | Docker + Docker Compose | Containerize services for portability and backups. |

---

## 3. System Architecture

### A. Threads and Conversations

- **Threads:** High-level groups of related discussions (e.g., "API Design").
  - Example threads: "Semantic Search Feature", "Marketing Strategy".
- **Conversations:** Individual chats within a thread (e.g., a discussion with the Vision Keeper persona).
  - Linked to a `thread_id` and `conversation_id`.

### B. Persona Roles

| Persona Role | Responsibility | Example Tasks |
| --- | --- | --- |
| **Vision Keeper** | Ensures alignment with long-term project goals. | "Does this feature align with our mission to democratize knowledge?" |
| **Technical Mentor** | Provides technical guidance on architecture, scalability, and trade-offs. | "Should we use vector databases for semantic search?" |
| **Business Strategist** | Focuses on market fit, pricing, and scaling strategies. | "What’s the target audience for this feature?" |
| **Devil’s Advocate** | Challenges assumptions to stress-test decisions. | "What are the risks of prioritizing this over user onboarding?" |
| **Process Optimizer** | Reviews workflows and suggests efficiency improvements. | "Your last sprint had 3 blocked tasks—how can we streamline dependencies?" |
| **Mentor/Coach** | Identifies personal growth opportunities and recommends resources. | "Try the ‘Pyramid Principle’ for structuring arguments." |
| **Review Persona** | Analyzes past conversations to optimize agent performance and suggest improvements. | "Technical Mentor’s responses lack trade-off discussions—update its prompt." |

### C. Context Optimization

- **Summarization:** Auto-generate summaries when conversation context exceeds 70% of the model’s token limit (e.g., 2867/4096 tokens for Mistral 7B).
- **Chunking:** Keep only the last 3–5 messages in full; prepend summaries for older context.
- **Token Counting:** Track context size to enforce limits.

---

## 4. Data Model

### A. Database Tables

| Table | Key Columns | Purpose |
| --- | --- | --- |
| **Users** | `id`, `name`, `email` | Store user information (e.g., Matthew, Rosie). |
| **Threads** | `id`, `user_id`, `title`, `description`, `created_at` | Group related conversations. |
| **Conversations** | `id`, `user_id`, `thread_id`, `conversation_id`, `agent_role`, `query`, `response`, `context_summary`, `token_count` | Store individual chats and their context. |
| **Reports** | `id`, `user_id`, `agent_role`, `title`, `path`, `timestamp` | Track persona-generated reports (saved as Markdown files). |

### B. File System

- **Reports:** Saved as Markdown files in `/reports/{user_id}/{thread_id}/`.
- **Backups:** Docker volumes for PostgreSQL data and reports.

---

## 5. Implementation Roadmap

### Phase 1: Core System (1–2 Weeks)

1. **Set Up Infrastructure:**
    - Dockerize PostgreSQL, FastAPI backend, and Streamlit frontend.
    - Configure Ollama to run Mistral 7B locally.
2. **Define Persona Roles:**
    - Hardcode agent prompts in the backend (e.g., `AGENT_PROMPTS` dictionary).
    - Test agent responses in isolation.
3. **Build Thread/Conversation Management:**
    - Implement PostgreSQL tables for threads and conversations.
    - Create FastAPI endpoints for:
        - Starting/continuing conversations.
        - Generating summaries.
4. **Develop Streamlit UI:**
    - Thread selection dropdown.
    - Conversation display with summary editing.
    - Query input for agents.

### Phase 2: Multi-User Support (1 Week)

1. **Extend Database Schema:**
    - Add `user_id` to all tables for data segregation.
2. **Update UI:**
    - User selection dropdown.
    - User-specific thread/conversation views.
3. **Test with Multiple Users:**
    - Verify data segregation and context retention.

### Phase 3: Dynamic Agents (Future)

1. **Move Agent Configs to Database:**
    - Create an `agents` table to store roles, prompts, and settings.
2. **Enable Review Persona:**
    - Allow the Review Persona to read/modify other agents’ instructions.
3. **Implement Agent Updates:**
    - UI/endpoints for updating agent prompts.

---

## 6. Key Decisions

*(With Alternatives and Rationale)*

| **Decision Point** | **Resolution** | **Alternatives Considered** | **Rationale** |
| --- | --- | --- | --- |
| **Agent Hand-offs** | Hybrid: Agents suggest hand-offs, but users must confirm. | Automatic hand-offs (no confirmation) or user-only hand-offs (no agent suggestions). | Balances automation with user control; avoids misrouting. |
| **Report Automation** | Manual loading with smart suggestions. | Auto-loading reports or no suggestions. | Avoids clutter; user-driven aligns with flexibility preferences. |
| **Review Persona Scope** | Individual-user focus (no cross-user analysis). | Cross-user analysis for system-wide improvements. | Aligns with user-specific agents; avoids privacy/complexity concerns. |
| **Thread Descriptions** | Add a `description` field to threads. | No descriptions or mandatory descriptions. | Low effort, adds useful context for user-specific threads. |
| **Summarization Granularity** | Per-conversation summaries. | Per-thread summaries. | Simpler to implement; aligns with local LLM context needs. |
| **UI for Editing Summaries** | Inline edit with UI swap (view/edit toggle). | Separate modal or no editing. | Clean UI with flexibility for edits. |
| **Failed Summaries** | Detailed fallbacks (retry logic, fallback prompts, user notifications). | Skip summarization or truncate aggressively. | Preserves context where possible; transparent to users. |
| **Agent Storage** | Phased approach: Start hardcoded, move to database soon (user-specific only). | Database from start or hardcoded indefinitely. | Avoids early complexity; aligns with phased approach. |

---

## 7. Failure Modes and Mitigations

| Failure Mode | Primary Mitigation | Fallback Action |
| --- | --- | --- |
| Token Limit Exceeded | Preemptive chunking + fallback prompts. | Show last N messages. |
| Low-Quality Summaries | Structured prompts + human-in-the-loop. | Highlight uncertainties. |
| Database Errors | Retry logic + local cache. | Notify user of local save. |
| Model Hallucinations | Constrained prompts + user validation. | Fallback to truncation. |
| Race Conditions | Database locks or task queue. | Notify user of conflict. |
| Missing Context | Overlap chunks + key phrase extraction. | Link to full history. |
| Language/Format Issues | Prompt constraints + user preferences. | Let user reformat. |
| Dependency Failures | Health checks + graceful degradation. | Show raw snippets. |

---

## 8. Open Questions

*(All resolved—see Key Decisions above.)*

---

## 9. Next Steps

1. **Finalize Persona Roles:** Review and refine the responsibilities for each agent.
2. **Design Database Schema:** Confirm tables/columns with your team (if applicable).
3. **Prioritize Phase 1 Tasks:** Start with the backend and PostgreSQL setup.
4. **Prototype Components:** Use the finalized decisions to guide implementation.

---

## 10. Glossary

| Term | Definition |  |  |
| --- | --- |
| **Thread** | A group of related conversations (e.g., "API Design"). |  |  |
| **Conversation** | An individual chat within a thread (e.g., with the Vision Keeper). |  |  |
| **Context Summary** | A condensed version of older messages to fit the model’s context window. |  |  |
| **Persona Role** | The specific function of an agent (e.g., Technical Mentor). |  |  |
| **Hand-off** | Transferring a conversation from one agent to another. |  |  |

---

## 11. Appendices

### A. Example Agent Workflow

1. User starts a thread: "Semantic Search Feature".
2. Vision Keeper discusses high-level goals.
3. Context is summarized and passed to the Technical Mentor for API design.
4. Reports are generated and saved to `/reports/matthew/semantic_search/`.

### B. Backup Strategy

- **PostgreSQL:** Daily backups of the database volume.
- **Reports:** Version-controlled Markdown files in `/reports/`.

---

## 12. Resources

- **Mistral 7B Documentation:** [Ollama Docs](https://github.com/jmorganca/ollama)
- **FastAPI Tutorials:** [FastAPI Guide](https://fastapi.tiangolo.com/)
- **Streamlit Examples:** [Streamlit Gallery](https://streamlit.io/gallery)
- **PostgreSQL Best Practices:** [PostgreSQL Docs](https://www.postgresql.org/docs/)
