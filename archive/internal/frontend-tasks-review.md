# Task List Self-Review — Frontend Service

## Date

2026-04-29

## Evaluation

### Completeness

Every major implementation area from the plan is accounted for:

| Plan area | Task(s) |
| --- | --- |
| Project scaffolding (Vite, React, TanStack Router, Tailwind, aliases) | F-001 |
| Config loader (nconf, Zod, Vite define) | F-002 |
| `openapi-typescript` generation script + `types/app.ts` | F-003 |
| `apiClient` + `lib/apiError.ts` | F-004 |
| Testing infrastructure (Vitest, MSW, vitest-axe) | F-005 |
| `lib/sseEvents.ts` + type guards | F-006 |
| All 14 SWR hooks + SWR global config + polling for async ops | F-007 |
| `ConversationStream`, `useConversationStream`, `openEphemeralStream` | F-008 |
| Conversation state machine reducer | F-009 |
| TanStack Router setup + root layout + `__root.tsx` + `routes/index.tsx` | F-010 |
| Shared components (ConfirmDialog, InlineEditable, MarkdownRenderer, EmptyState, ErrorBanner, LoadingSpinner) | F-011 |
| Workspace shell `_layout.tsx` + DiscussionsSidebar + sub-components | F-012 |
| Workspace management UI (switcher, create/rename/delete modals) | F-013 |
| `exportHelpers.ts` | F-014 |
| Unit tests (apiError, sseEvents, state machine, sidebar ordering, config, useMessages pagination) | F-015 |
| Hook tests for all 14 SWR hooks | F-016 |
| SSE hook tests (`useConversationStream`) | F-017 |
| ConversationView stub wired to state machine | F-018 |
| Component + accessibility tests for shared components | F-019 |
| Full ConversationView tree (all conversation sub-components) | F-020 |
| MentorConversationView + ChapterPromptDialog | F-021 |
| Persona area (list, detail, form, TemperatureSlider, TestPanel) | F-022 |
| Review Agent UI (FindingCard, RecommendationsSection, ConsultationPanel) | F-023 |
| Memory Inspector panel + source-type grouping | F-024 |
| Component + accessibility tests for feature components | F-025 |
| Documents area (list, card, view) | F-026 |
| Error handling wiring (error boundaries, 409 dialogs, SSE reconnect banner) | F-027 |
| Docker multi-stage build + Compose integration | F-028 |

No plan section has been left without a corresponding task.

### Consistency

- Task IDs are F-001 through F-028 with no gaps.
- All `**Status**` fields are `not_started`.
- All dependency references use valid task IDs within the range F-001–F-028. No dependency reference points to a non-existent task ID.
- Dependency chain check:
  - F-001 (no deps) → F-002 → F-003 → F-004 → F-005, F-006, F-007
  - F-007 → F-008 (also needs F-006), F-010
  - F-009 (needs F-006)
  - F-010 (needs F-007) → F-012 → F-013 → F-022 → F-023 → F-024
  - F-011 (needs F-004, F-005)
  - F-012 (needs F-010, F-011) — correct; workspace shell needs routing and shared components
  - F-014 (needs F-004)
  - F-015 (needs F-002, F-004, F-005, F-006, F-007, F-009, F-012) — gathers existing unit test coverage; no circular deps
  - F-016 (needs F-005, F-007)
  - F-017 (needs F-005, F-008)
  - F-018 (needs F-009, F-010, F-012) — correct
  - F-019 (needs F-005, F-011)
  - F-020 (needs F-008, F-009, F-011, F-012, F-014, F-018) — correct; full ConversationView needs SSE, state machine, shared components, layout, export
  - F-021 (needs F-020)
  - F-022 (needs F-013, F-014)
  - F-023 (needs F-022)
  - F-024 (needs F-007, F-022)
  - F-025 (needs F-005, F-019, F-020, F-021, F-022, F-023, F-024) — correct; tests components from those tasks
  - F-026 (needs F-014, F-012)
  - F-027 (needs F-013, F-020, F-022)
  - F-028 (needs F-001, F-002, F-003)

No circular dependencies identified. No dependency references a task that appears later in the order without being listed as a dependency.

### Ambiguity

- F-003: Noted that `src/api/schema.ts` requires the backend to be running. The description instructs the Implementer to document this and use a placeholder — no ambiguity.
- F-007: `useConversation` and `useDocument` polling behaviour is described in sufficient detail (conditions and interval). The Implementer can implement without reading the full plan.
- F-008: The `"mentor:{uuid}"` key format is fully described by reference to plan Sections 6.4 and 6.5. No additional look-up required.
- F-015: This task is a collection task for unit tests whose primary code was delivered in earlier tasks. The description is explicit that the Implementer must confirm which tests already exist and fill gaps. This is intentional — unit tests for core logic (apiError, sseEvents, state machine) were specified as part of their respective implementation tasks, and F-015 prevents them being silently skipped.
- F-018: The stub task is explicitly scoped to wiring the state machine; full UI is deferred to F-020. The Implementer will not mistake this for a partial implementation error.
- F-028: Docker Compose file path (`repository root or apps/`) is left open. **Flag**: the plan says "Docker Compose" but does not specify whether the Compose file already exists at the repository root or is to be created from scratch. This is a minor uncertainty — the Implementer should check whether a `docker-compose.yml` exists at the repo root before creating one. Not blocking.

### Ordering

- The first task (F-001) has no dependencies and can be started immediately.
- Testing infrastructure (F-005) is available after the API client layer is established (F-004), meaning hook tests (F-016, F-017) and component tests (F-019, F-025) can be written as soon as their implementation counterparts are done.
- The `ConversationView` split across F-018 (wiring stub) and F-020 (full implementation) is intentional: it allows the state machine integration to be verified in isolation before the large full-implementation task begins. No ordering problem.
- F-015 collects unit tests that were seeded across F-002, F-004, F-006, F-009, and F-012. It depends on all of them and is correctly ordered after each.

### Flagged issues

None blocking. One minor open item noted in the Ambiguity section above:

> **F-028 minor**: The task description says to create or update `docker-compose.yml` at the repository root or `apps/`. The Implementer should check whether a root-level `docker-compose.yml` already exists before creating one, to avoid duplicating the backend service definition.
