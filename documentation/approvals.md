# Approvals

This file tracks the approval status of all documents in the development workflow. It is maintained by all agents using the `approval-workflow` skill. Do not edit the audit log — entries are append-only.

---

## Status Table

| Document | Status | Last Updated |
| --- | --- | --- |
| `documentation/project/overview.md` | Approved | 2026-04-29 |
| `documentation/requirements/user-requirements.md` | Approved | 2026-04-15 |
| `documentation/requirements/phase-1-user-stories.md` | Approved | 2026-04-15 |
| `documentation/decisions/architecture-decisions.md` | Unapproved | — |
| `documentation/project/architecture.md` | Approved | 2026-04-29 |
| `documentation/project/system-diagrams.md` | Approved | 2026-04-23 |
| `documentation/tasks/api-requirements-frontend.md` | Archived | 2026-04-28 |
| `documentation/tasks/api-contract.md` | Approved | 2026-04-29 |
| `documentation/tasks/senior-developer-backend-plan.md` | Approved | 2026-04-29 |
| `documentation/tasks/senior-developer-frontend-plan.md` | Approved | 2026-04-29 |
| `documentation/tasks/backend-tasks.md` | Approved | 2026-04-30 |
| `documentation/tasks/frontend-tasks.md` | Approved | 2026-04-30 |

---

## Audit Log

<!-- Entries are appended below, one per status change. Format:
YYYY/MM/DD HH:MM - [document] [action] - [requestor] - [reason]
-->
2026/04/15 - documentation/project/overview.md approved - Developer - Approved by user after Product Owner review.
2026/04/15 - documentation/requirements/user-requirements.md approved - Developer - Approved after review, gap fixes (Non-Goals, System Prompt isolation, Round-Robin behaviour, Mentor naming), and MoSCoW reprioritisation.
2026/04/15 - documentation/requirements/phase-1-user-stories.md approved - Developer - Approved after review and story corrections (US-M1 Mentor name criterion).
2026/04/23 - documentation/project/architecture.md approved - Developer - Approved after architecture review (8 points), frontend library decisions (SWR, Base UI + Tailwind, openapi-typescript), config rename (config.override.json), P2P pause_reason and message-based recovery, UUID v7 for all primary keys, and future upgrades table.
2026/04/23 - documentation/project/system-diagrams.md approved - Developer - Approved after minor Mermaid syntax fix (semicolons removed).
2026/04/24 - documentation/project/architecture.md unapproved - Developer - Unapproved to incorporate 9 gaps identified by comparing overview.md against architecture.md post-api-contract work: data model fields missing from Section 5 (auto_summary, last_message_at, is_mentor_conversation, message_subtype, documents.status, orchestrator_suggestions table); ModelGateway call sites missing auto-summary; Orchestrator 1:1 threshold and @Orchestrator behaviour undocumented; auto-naming trigger mis-specified; Mentor chapter detection mechanism missing.
2026/04/27 - documentation/project/architecture.md approved - Developer - Re-approved after full architecture review (18 findings resolved): review_agent_findings schema defined; Mentor snapshot exception documented; Workspace-switch interrupt behaviour added; auto_summary naming standardised; conversation_summaries marked internal-only; is_mentor_conversation resolved as persisted column; Persona deletion enforcement defined; empty-conversation delete-on-end rule added; message_subtype values standardised to past tense; active-participants canonical query defined; Orchestrator counter reset clarified; parallel streaming removed as future upgrade; config key schema added (Section 11.7); session-end trigger removed from promotion paths; universal System Prompt versioning rule stated; frontend config clarified with CONTEXT_PANEL_MAX_CHARS via API.
2026/04/27 - documentation/tasks/api-requirements-frontend.md approved - Developer - Approved after Senior Developer Frontend added 4 targeted gaps: CONTEXT_PANEL_MAX_CHARS via backend API; End Conversation two-outcome paths (ended vs. deleted-if-empty); stale finding status with distinct rendering; Workspace-switch pause converges on standard resume endpoint.
2026/04/28 - documentation/tasks/api-contract.md approved - Developer - Approved after Senior Developer Backend produced 1,789-line contract covering all endpoints; self-review identified and fixed one blocking issue (POST /end during P2P exchange); all FC-1–FC-8 concerns resolved; 5 non-blocking items deferred to implementation plan.
2026/04/28 - documentation/tasks/api-requirements-frontend.md archived - Developer - Intermediate artefact; purpose fulfilled by api-contract.md. Frontend builds from OpenAPI spec, not this document. Moved to archive/internal/.
2026/04/29 - documentation/project/overview.md unapproved - Developer - Unapproved to incorporate Conversation Observer mechanism (Mentor observation of non-Mentor conversations), Mentor System Prompt / Context Panel separation, Memory Inspector source distinction, and Working Memory trigger clarification.
2026/04/29 - documentation/project/overview.md approved - Developer - Approved after adding Conversation Observer (Section 8.7), Mentor System Prompt / Context Panel separation (Sections 8.2, 8.3), two-source episodic memory description (Section 8.5), Memory Inspector source labelling (Section 8.6), Mentor creation wizard update (Section 9.6), and Conversation Observer glossary entry.
2026/04/29 - documentation/project/architecture.md unapproved - Developer - Unapproved to incorporate Conversation Observer job, source_type column on mentor_episodic_memories, and related Mentor memory section updates.
2026/04/29 - documentation/project/architecture.md approved - Developer - Approved after adding Conversation Observer (Section 9.4), source_type to mentor_episodic_memories (Section 5.4), ModelGateway call site update (Section 6.1), three-layer memory and promotion path updates (Sections 8.1, 8.2, 8.3), and APScheduler job list update (Section 4.5).
2026/04/29 - documentation/tasks/api-contract.md unapproved - Developer - Unapproved to add source_type field to episodic memory response schema.
2026/04/29 - documentation/tasks/api-contract.md approved - Developer - Approved after adding source_type and source_conversation_id fields to episodic memory response schema in the Memory Inspector endpoint.
2026/04/29 - documentation/tasks/senior-developer-backend-plan.md approved - Developer - Approved after adding Conversation Observer (Section 8.4, Section 9.0), source_type to migration and SQLAlchemy model, ModelGateway purpose string, Working→Episodic source_type annotation, EpisodicMemoryResponse schema update, unit test spec, and section renumbering.
2026/04/29 - documentation/tasks/senior-developer-frontend-plan.md approved - Developer - Approved after adding hook tests (Section 14.2) covering all SWR hooks with happy path and error paths, accessibility testing with vitest-axe (Section 14.4), MSW handlers directory to project structure, and MemoryInspectorPanel source-type grouping component test.
2026/04/30 - documentation/tasks/backend-tasks.md approved - Developer - Approved after fixing three issues: B-001 section references corrected from 12.x to 11.x; ConversationSummary schema ownership clarified (canonical in conversation.py, sse.py imports from there); B-020 start_chapter overlap resolved (already in B-018); B-023 Docker task added between B-001 and B-002.
2026/04/30 - documentation/tasks/frontend-tasks.md approved - Developer - Approved after moving F-028 Docker task to after F-010 (depends on F-001–F-003, F-010) so the containerised app is available early; updated to replace B-023's frontend stub in docker-compose.yml rather than create the file from scratch. Task review files moved to archive/internal/.
2026/04/30 - documentation/tasks/backend-tasks.md amended - Developer - B-024 (GitHub Actions backend CI) added after B-004; B-024 updated to include publish-openapi job that starts uvicorn, fetches /openapi.json, and uploads as workflow artifact for frontend consumption. Critical path updated.
2026/04/30 - documentation/tasks/frontend-tasks.md amended - Developer - F-029 (GitHub Actions frontend CI) added after F-005; F-029 updated to download openapi-spec artifact from backend CI and generate real types via openapi-typescript, falling back to schema.stub.ts when no artifact available.
