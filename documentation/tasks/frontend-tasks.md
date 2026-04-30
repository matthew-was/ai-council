# Task List — Frontend Service

## Status

Draft — 2026-04-29

## Source plan

`documentation/tasks/senior-developer-frontend-plan.md`

## Flagged issues

None.

---

## Tasks

### Task F-001: Project scaffolding — Vite, React, TanStack Router, Tailwind, path aliases

**Description**: Initialise the `apps/frontend/` directory with all project-level config files. Create:
- `package.json` with all Phase 1 dependencies: React 19, Vite, `@vitejs/plugin-react`, TanStack Router, SWR, Base UI, Tailwind CSS, `@microsoft/fetch-event-source`, nconf, Zod, `openapi-typescript`, `react-markdown`, TypeScript, Vitest, MSW, `@testing-library/react`, `vitest-axe`.
- `vite.config.ts` with `@vitejs/plugin-react`, the `@/` → `src/` path alias, and a pre-build plugin stub that will run `scripts/generate-types.sh` (can be a no-op placeholder until F-003 is done).
- `tsconfig.json` with strict mode, path aliases matching `vite.config.ts`, and `noEmit: true`.
- `tailwind.config.ts` with the `src/` content glob.
- `index.html` with a `<div id="root">` mount point.
- `src/main.tsx` mounting a minimal React 19 app (no router yet — a `<div>Hello</div>` placeholder is fine).
- `.gitignore` entries for `node_modules/`, `dist/`, `config.override.json`, `src/api/schema.ts`.

Do not implement routing, config loading, or type generation in this task — those are F-002 and F-003.

**Depends on**: none

**Complexity**: S

**Acceptance condition**: `npm run dev` starts the Vite dev server without errors and the browser shows the placeholder page. `npm run build` completes without TypeScript errors. All listed files exist at the correct paths.

**Condition type**: manual

**Status**: not_started

---

### Task F-002: Config loader — nconf + Zod schema, build-time injection via Vite define

**Description**: Implement the frontend configuration system as described in plan Section 15.

Create:
- `apps/frontend/config.json` with `{ "api_base_url": "http://localhost:8000" }`.
- `apps/frontend/src/config/schema.ts` — the Zod schema `FrontendConfigSchema` validating `api_base_url` as a URL string, and the exported `FrontendConfig` type.
- `apps/frontend/src/config/index.ts` — nconf loader that reads `config.json` and (if present) `config.override.json`, merges them, runs `FrontendConfigSchema.parse()` on the result (throwing a build error on failure), and exports the validated object as `config`.

Update `vite.config.ts` to run the nconf loader at build time and expose the result as `__APP_CONFIG__` via Vite's `define` plugin. The app reads `config` from the export in `config/index.ts`; the `__APP_CONFIG__` global is what backs it at runtime.

Unit tests (in `apps/frontend/tests/`): valid config parses without error; missing `api_base_url` throws; non-URL `api_base_url` throws; `config.override.json` values override `config.json` values.

**Depends on**: F-001

**Complexity**: S

**Acceptance condition**: All unit tests pass. `vite build` fails with a clear error when `api_base_url` is removed from `config.json`. `vite build` succeeds with a valid config. `config.override.json` values override base config values (verified by the unit test for the merge behaviour).

**Condition type**: both

**Status**: not_started

---

### Task F-003: `openapi-typescript` type generation script and `src/api/schema.ts` stub

**Description**: Implement the type generation pipeline as described in plan Sections 7.1 and 13.2.

Create:
- `apps/frontend/scripts/generate-types.sh` — the shell script that reads `api_base_url` from `config.json` (with `config.override.json` override), then calls `npx openapi-typescript "$API_BASE_URL/openapi.json" --output src/api/schema.ts`.
- Update `vite.config.ts` to call `scripts/generate-types.sh` as a pre-build Vite plugin step (replacing the stub from F-001), so type generation runs automatically on `vite build` and `vite dev`.
- Create `apps/frontend/src/types/app.ts` with type aliases derived from `schema.ts` for: `Workspace`, `Persona`, `Conversation`, `ConversationDetail`, `Message`, `Folder`, `Document`, `Finding`, `ReviewAgentStatus`, `EpisodicMemoryEntry`, `SemanticMemoryEntry`. These aliases are the types used throughout the codebase — `schema.ts` must not be imported outside `types/app.ts` and `api/client.ts`.

**Note**: `src/api/schema.ts` is generated, not hand-written. If the backend is not running during development, the script will fail — document this dependency in a comment at the top of the script. A committed placeholder `schema.ts` is acceptable for initial scaffolding; the real file is generated before any feature work.

**Depends on**: F-002

**Complexity**: S

**Acceptance condition**: Running `scripts/generate-types.sh` (with the backend running) produces a non-empty `src/api/schema.ts`. `src/types/app.ts` compiles without errors when `schema.ts` is present. `vite build` runs `generate-types.sh` automatically (confirmed by observing the script execute during `vite build`).

**Condition type**: manual

**Status**: not_started

---

### Task F-004: `apiClient` — base fetch wrapper with error normalisation and `X-Workspace-ID` injection

**Description**: Implement the central HTTP client as described in plan Sections 5.1 and 12.1.

Create `apps/frontend/src/api/client.ts`:
- `apiClient.get(url)`, `apiClient.post(url, body)`, `apiClient.patch(url, body)`, `apiClient.delete(url)` methods.
- Prefixes all URLs with `config.api_base_url`.
- Sets `Content-Type: application/json` on POST/PATCH.
- On non-2xx responses, calls `normaliseApiError(response)` and throws the result.
- `X-Workspace-ID` header injection: for requests to the non-workspace-scoped endpoint prefixes listed in Section 5.1 (`/personas/{id}/test`, `/personas/{id}/consultation`, `/conversations/{id}/stream`, `/conversations/{id}/pause`, `/conversations/{id}/resume`, `/conversations/{id}/cancel`, `/conversations/{id}/suggestions/`), reads the active `workspaceId` from TanStack Router's route context and injects it as `X-Workspace-ID`. All other requests do not include this header.

Create `apps/frontend/src/lib/apiError.ts`:
- `ApiError` type with `status`, `message`, `code?`, `blocking_conversations?`, `validationErrors?`.
- `normaliseApiError(response: Response): Promise<ApiError>` that reads the body, attempts JSON parse, handles Pydantic 422 `detail` array format (mapping to `validationErrors`), and falls back to a generic message for non-JSON bodies.

**Depends on**: F-003

**Complexity**: S

**Acceptance condition**: Unit tests pass covering: JSON error body is parsed correctly; 422 Pydantic shape is mapped to `validationErrors`; non-JSON body (HTML string) falls back to a generic message with the correct status code; `X-Workspace-ID` is present on a request to `/conversations/{id}/resume` and absent on a request to `/workspaces/{id}`.

**Condition type**: automated

**Status**: not_started

---

### Task F-005: Testing infrastructure — Vitest setup, MSW server, `vitest-axe` extend-expect

**Description**: Wire up the test infrastructure as described in plan Sections 14.5 and 14.1.

Create:
- `apps/frontend/tests/setup.ts` — Vitest global setup file that: starts the MSW server before all tests, resets handlers between tests, stops the server after all tests, and calls `vitest-axe/extend-expect` to extend Vitest's `expect` with `toHaveNoViolations`.
- `apps/frontend/tests/handlers/workspaces.ts` — MSW handlers for workspace endpoints (`GET /workspaces`, `GET /workspaces/:id`, `POST /workspaces`, `PATCH /workspaces/:id`, `DELETE /workspaces/:id`). Handlers return minimal valid fixture responses typed against `src/api/schema.ts`.
- `apps/frontend/tests/handlers/personas.ts` — MSW handlers for persona endpoints.
- `apps/frontend/tests/handlers/conversations.ts` — MSW handlers for conversation endpoints.
- `apps/frontend/tests/handlers/messages.ts` — MSW handlers for message endpoints.
- `apps/frontend/tests/handlers/documents.ts` — MSW handlers for document endpoints.
- `apps/frontend/tests/handlers/reviewAgent.ts` — MSW handlers for Review Agent endpoints.
- `apps/frontend/tests/handlers/mentorMemory.ts` — MSW handlers for episodic/semantic memory endpoints.

Update `vite.config.ts` (or a `vitest.config.ts`) to reference `tests/setup.ts` as the Vitest `setupFiles` entry.

A smoke test that asserts `expect(true).toBe(true)` must pass, and `toHaveNoViolations` must be available in that test file, confirming the extend-expect wiring is correct.

**Depends on**: F-004

**Complexity**: S

**Acceptance condition**: `npm run test` runs without setup errors. The smoke test passes. A test calling `expect(await axe(document.body)).toHaveNoViolations()` does not throw a "matcher not found" error.

**Condition type**: automated

**Status**: not_started

---

### Task F-006: SSE types and `lib/sseEvents.ts`

**Description**: Define the hand-typed SSE event payload types as described in plan Section 7.4.

Create `apps/frontend/src/lib/sseEvents.ts` with:
- `TokenEvent`, `ResponseCompleteEvent`, `OrchestratorSuggestionEvent`, `ExchangePausedEvent` types exactly as specified in Section 7.4.
- A type guard for each event type (`isTokenEvent`, `isResponseCompleteEvent`, etc.) that narrows an `unknown` value to the typed payload.
- A comment on each type referencing the API contract section that defines the event.

Unit tests: each type guard returns `true` for a valid payload and `false` for a payload missing a required field or with a wrong field type.

**Depends on**: F-004

**Complexity**: S

**Acceptance condition**: All type guard unit tests pass. `sseEvents.ts` compiles without errors against the project's `tsconfig.json`.

**Condition type**: automated

**Status**: not_started

---

### Task F-007: SWR global config and all data-fetching hooks

**Description**: Implement the SWR configuration provider and all 14 data-fetching hooks as described in plan Sections 4.1, 5.2, and 5.3.

Create the SWR global config provider (as a wrapper component or in `main.tsx`) with:
- `fetcher: (url: string) => apiClient.get(url)`
- `revalidateOnFocus: false`
- `dedupingInterval: 2000`
- `shouldRetryOnError: false`

Create one file per hook in `apps/frontend/src/hooks/`:
- `useWorkspaces.ts` — `GET /workspaces`
- `useWorkspace.ts` — `GET /workspaces/${id}`
- `usePersonas.ts` — `GET /workspaces/${wsId}/personas`
- `usePersona.ts` — `GET /workspaces/${wsId}/personas/${pid}`
- `useConversations.ts` — `GET /workspaces/${wsId}/conversations`
- `useConversation.ts` — `GET /workspaces/${wsId}/conversations/${cid}` — with the polling behaviour for `status: ended && auto_summary === null` (3000ms `refreshInterval`, stops when `auto_summary` is populated, per Section 5.6).
- `useMessages.ts` — cursor-based pagination hook per Section 5.5. Manages a local page array, `oldestLoadedMessageId` cursor, `hasMore`, and `isLoadingMore`. Exposes a `loadMore()` function.
- `useFolders.ts` — `GET /workspaces/${wsId}/folders`
- `useDocuments.ts` — `GET /workspaces/${wsId}/documents`
- `useDocument.ts` — `GET /workspaces/${wsId}/documents/${did}` — with polling for `status: pending` (3000ms `refreshInterval`, stops on `complete` or `failed`, per Section 5.6).
- `useFindings.ts` — `GET /workspaces/${wsId}/personas/${pid}/findings`
- `useReviewAgentStatus.ts` — `GET /workspaces/${wsId}/review-agent/status`
- `useEpisodicMemory.ts` — `GET /workspaces/${wsId}/personas/${pid}/memory/episodic` — guard: only fetches when the persona has `is_mentor: true`; conditionally passes `null` SWR key otherwise.
- `useSemanticMemory.ts` — `GET /workspaces/${wsId}/personas/${pid}/memory/semantic` — same `is_mentor` guard.

Each hook returns `{ data, error, isLoading }` and exposes a `mutate` function for cache invalidation.

**Depends on**: F-004

**Complexity**: M

**Acceptance condition**: All 14 hook files exist and compile. `useConversation` polling behaviour is present in the source. `useDocument` polling behaviour is present in the source. `useEpisodicMemory` and `useSemanticMemory` conditionally pass `null` as the SWR key when `is_mentor` is false (confirmed by reading the code). Hook tests in F-016 will exercise the runtime behaviour.

**Condition type**: manual

**Status**: not_started

---

### Task F-008: SSE client — `ConversationStream` class and `useConversationStream` hook

**Description**: Implement the SSE client and its React hook as described in plan Sections 6.1–6.5.

Create `apps/frontend/src/api/sse.ts`:
- `ConversationStream` class with `open(conversationId, workspaceId, handlers)` and `close()` methods.
- `SSEHandlers` type as specified in Section 6.1.
- `openEphemeralStream(url, body, handlers, workspaceId)` function for one-shot POST SSE (used by TestPanel and ConsultationPanel per Section 6.6).
- All stream handlers parse raw SSE event data through the type guards from `lib/sseEvents.ts` and dispatch to the appropriate `SSEHandlers` callback.
- `X-Workspace-ID` is included in the `fetch-event-source` request headers for `ConversationStream.open()` (workspaceId passed as parameter) and `openEphemeralStream` (workspaceId passed as parameter).

Create `apps/frontend/src/hooks/useConversationStream.ts`:
- Signature: `function useConversationStream(conversationId: string | null, workspaceId: string, handlers: SSEHandlers): { isConnected: boolean }`.
- Opens stream on mount or when `conversationId` changes from null to a value.
- Closes stream on unmount or when `conversationId` becomes null.
- Stabilises `handlers` via a ref to avoid re-opening the stream on handler identity change.
- Token accumulation: maintains a `streamingBufferRef` keyed by `conversation_persona_id` (full key including `"mentor:{uuid}"` prefix where applicable). Buffer is flushed to React state on `requestAnimationFrame` cadence as described in Section 6.4. Buffer is cleared on `response_complete`.

**Depends on**: F-006, F-007

**Complexity**: M

**Acceptance condition**: `sse.ts` and `useConversationStream.ts` compile without TypeScript errors. The `"mentor:"` prefix detection logic (Section 6.5) is present and commented in `useConversationStream.ts`. The streaming buffer uses `requestAnimationFrame` cadence (confirmed by code review). SSE hook tests in F-017 will verify runtime behaviour.

**Condition type**: manual

**Status**: not_started

---

### Task F-009: Conversation state machine (`stores/conversationState.ts`)

**Description**: Implement the conversation state machine as described in plan Sections 8.1–8.4.

Create `apps/frontend/src/stores/conversationState.ts`:
- `ConversationStatus` enum/union type with all seven states: `idle`, `busy`, `paused`, `exchange_paused_user`, `exchange_paused_turn_cap`, `exchange_paused_repetition`, `ended`.
- `ConversationUIState` type: `{ status: ConversationStatus; pendingSuggestion: OrchestratorSuggestionEvent | null; streamingPersonaId: string | null }`.
- `ConversationAction` discriminated union covering: `SSE_BUSY`, `SSE_IDLE`, `SSE_PAUSED`, `SSE_EXCHANGE_PAUSED` (with `pause_reason`), `SSE_ORCHESTRATOR_SUGGESTION`, `SSE_RESPONSE_COMPLETE`, `USER_SEND`, `USER_RESUME`, `POST_END_RECEIVED` (with `deleted: boolean`), `USER_CLEAR_SUGGESTION`.
- `conversationReducer(state: ConversationUIState, action: ConversationAction): ConversationUIState` — pure function implementing all transitions from Section 8.2.
- `initialConversationState: ConversationUIState` = `{ status: 'idle', pendingSuggestion: null, streamingPersonaId: null }`.

Invalid transitions (e.g. `SSE_BUSY` when already `busy`) must be no-ops (return current state unchanged), not errors.

Unit tests must cover all valid state × action transitions from Section 8.2, plus all seven invalid-transition no-op cases.

**Depends on**: F-006

**Complexity**: M

**Acceptance condition**: All unit tests pass, covering every documented transition and every invalid-transition no-op case. The reducer is a pure function with no side effects (verified by inspection). `stores/conversationState.ts` compiles without TypeScript errors.

**Condition type**: automated

**Status**: not_started

---

### Task F-010: TanStack Router setup and root layout (`__root.tsx`)

**Description**: Wire up TanStack Router and implement the root layout as described in plan Sections 2 and 3.1.

- Add TanStack Router to `src/main.tsx`: create the router with the full route tree (all routes as stubs that render `<div>TODO</div>` — real implementations come in later tasks). Mount `<RouterProvider router={router} />` in `main.tsx`.
- Implement `src/routes/__root.tsx`: top navigation bar containing the workspace switcher area (a placeholder for now; `WorkspaceSwitcher` is implemented in F-013) and `<Outlet />`.
- Implement `src/routes/index.tsx`: empty-state page shown when no workspace is active. Shows a "No workspace selected" message and a CTA to create one (button wired to no-op until F-013).
- Implement the navigation guard logic: if navigating to a `$workspaceId` route and the API returns 404, redirect to `/` with an error notification.
- Implement the `?action=create-mentor` search parameter handling: if the Mentor slot is clicked and no Mentor exists, navigate to the personas route with this search param; the personas route reads it and triggers the creation flow (creation flow is a stub for now).

All route files for subsequent tasks must be created as stubs in this task so the route tree compiles.

**Depends on**: F-007

**Complexity**: M

**Acceptance condition**: `npm run dev` loads the app. Navigating to `/` renders the empty-state page. Navigating to `/workspaces/some-id` does not crash (renders stub). All route stubs compile. TanStack Router devtools are visible in dev mode.

**Condition type**: manual

**Status**: not_started

---

### Task F-028: Docker multi-stage build and Compose integration

**Description**: Implement the Docker build pipeline as described in plan Section 13.3.

Create `apps/frontend/Dockerfile`:
- Stage 1 (build): `node:20-alpine` base; copies source; optionally mounts `config.override.json`; runs `npm ci`; runs `vite build` (which triggers `generate-types.sh` and config validation as a pre-build step).
- Stage 2 (serve): `nginx:alpine` base; copies `/dist` from Stage 1; exposes port 80; includes a minimal `nginx.conf` for SPA routing (all routes rewrite to `index.html`).

Update the `docker-compose.yml` at the repository root (created by B-023) to replace the frontend stub service with the real frontend service:
- `frontend` service using the multi-stage Dockerfile.
- `depends_on: backend` (condition: `service_healthy`) to ensure the backend is available when `generate-types.sh` runs.
- Volume mount for `config.override.json` if present.
- Exposes port `3000`.

The frontend container must serve the built SPA correctly at `http://localhost:3000`.

**Depends on**: F-001, F-002, F-003, F-010

**Complexity**: S

**Acceptance condition**: `docker compose up frontend` (with backend running) builds and serves the SPA without errors. The app is accessible at `http://localhost:3000`. A non-existent route (e.g. `/workspaces/anything/discussions`) served directly (without a client-side navigation) returns `index.html` (SPA routing works via nginx rewrite).

**Condition type**: manual

**Status**: not_started

---

### Task F-011: Shared components — `ConfirmDialog`, `InlineEditable`, `MarkdownRenderer`, `EmptyState`, `ErrorBanner`, `LoadingSpinner`

**Description**: Implement the six shared components described in plan Section 3.9.

Create in `apps/frontend/src/components/shared/`:
- `ConfirmDialog.tsx` — Base UI Dialog. Props: `title: string`, `description: string`, `confirmLabel: string`, `onConfirm: () => void`, `onCancel: () => void`. Renders a modal with the two action buttons.
- `InlineEditable.tsx` — Renders as a `<span>` when idle; switches to a controlled `<input>` on click. Props: `value: string`, `onSave: (newValue: string) => void`, `aria-label: string`. Saves on Enter or blur; cancels on Escape.
- `MarkdownRenderer.tsx` — Wraps `react-markdown` with HTML sanitisation. Props: `content: string`, `className?: string`.
- `EmptyState.tsx` — Props: `icon?: ReactNode`, `heading: string`, `description: string`, `cta?: { label: string; onClick: () => void }`.
- `ErrorBanner.tsx` — Props: `error: ApiError`. Renders the error `message`; if `validationErrors` are present, lists field errors below.
- `LoadingSpinner.tsx` — No props. Simple accessible spinner with `role="status"` and a visually-hidden label.

**Depends on**: F-004, F-005

**Complexity**: S

**Acceptance condition**: All six components compile and render without errors in isolation (manual check by importing in a dev page). Component tests and accessibility tests in F-019 will verify rendered behaviour and axe compliance.

**Condition type**: manual

**Status**: not_started

---

### Task F-012: Workspace shell layout (`_layout.tsx`) and `DiscussionsSidebar`

**Description**: Implement the workspace shell and sidebar as described in plan Sections 3.2 and 3.3.

Create `apps/frontend/src/routes/workspaces/$workspaceId/_layout.tsx`:
- Fetches workspace detail, persona list, conversation list, and folder list via SWR hooks.
- Renders the three-area navigation tabs (Discussions, Personas, Documents) and `DiscussionsSidebar`.
- Provides `<Outlet />` for the main area.
- Shows `<LoadingSpinner />` while any of the four critical SWR keys are loading.
- Shows `<ErrorBanner />` if any SWR key errors.
- The workspace's `context_panel_max_chars` is read from `useWorkspace(workspaceId)` and passed down to descendants that need it.

Create `apps/frontend/src/components/sidebar/`:
- `DiscussionsSidebar.tsx` — implements the full ordering logic from Section 3.3: folders (`created_at` asc), pinned standalone (`pinned_at` asc), standalone (`last_message_at` desc, nulls last), folder conversations (pinned by `pinned_at` asc, then unpinned by `last_message_at` desc). Renders `FolderRow`, `ConversationRow`, `MentorSlot` sub-components.
- `FolderRow.tsx` — expandable row showing folder name and child conversations. `isExpanded` state is local.
- `ConversationRow.tsx` — Props: `conversation`, `isActive` (matched against current route), `workspaceId`. Renders conversation title, with active highlight.
- `MentorSlot.tsx` — always pinned at the bottom of the sidebar. Props: `mentorConversation` (or null), `workspaceId`. If `mentorConversation` is null, clicking navigates to personas with `?action=create-mentor`.

Unit tests: the sidebar ordering logic (given a mixed fixture of conversations, assert sort order output) as described in plan Section 14.1.

**Depends on**: F-010, F-011

**Complexity**: M

**Acceptance condition**: The workspace shell renders with sidebar visible when navigating to `/workspaces/$workspaceId`. Sidebar ordering unit tests pass. Conversations appear in the correct order per the ordering rules (verified by unit test). The `MentorSlot` renders at the bottom.

**Condition type**: both

**Status**: not_started

---

### Task F-013: Workspace management UI — `WorkspaceSwitcher` and create/rename/delete modals

**Description**: Implement workspace management UI as described in plan Sections 3.1 and the workspace area.

Create in `apps/frontend/src/components/workspace/`:
- `WorkspaceSwitcher.tsx` — Dropdown in the root nav bar showing all workspaces from `useWorkspaces()`. Clicking a workspace navigates to `/workspaces/$workspaceId/discussions`. Includes "Create workspace" action. Includes rename and delete actions per workspace (accessible from the dropdown).
- `CreateWorkspaceModal.tsx` — Modal with a name input field. On submit: `POST /workspaces`. On 422: shows inline field error. On success: navigates to the new workspace.
- `RenameWorkspaceModal.tsx` — Modal pre-filled with current name. On submit: `PATCH /workspaces/$id` (optimistic update). On 422: shows inline field error.
- `DeleteWorkspaceModal.tsx` — Uses `ConfirmDialog`. On confirm: `DELETE /workspaces/$id`. On success: navigates to `/`.

Wire `WorkspaceSwitcher` into `__root.tsx` (replacing the placeholder from F-010).

Navigation guard: if `GET /workspaces/$id` returns 404, redirect to `/` with an error notification (this guard was stubbed in F-010; wire it fully here).

**Depends on**: F-012

**Complexity**: M

**Acceptance condition**: A workspace can be created, renamed, and deleted through the UI. After create, the app navigates to the new workspace. After delete, the app navigates to `/`. Inline 422 errors appear on the name field when the name is empty. The confirmation step for delete is shown.

**Condition type**: manual

**Status**: not_started

---

### Task F-014: `exportHelpers.ts` and `lib/` utilities

**Description**: Implement the export helper and complete the `lib/` directory as described in plan cross-cutting concerns and Section 1.

Create `apps/frontend/src/lib/exportHelpers.ts`:
- `downloadBlob(response: Response): Promise<void>` — reads the `Content-Disposition` header to extract the filename, creates an object URL from the response blob, attaches a temporary `<a>` element with `download` set, clicks it programmatically, and revokes the URL.
- Used for both Conversation export (`GET /workspaces/$wsId/conversations/$cid/export`) and Document export.

Ensure `apps/frontend/src/lib/apiError.ts` (created in F-004) and `apps/frontend/src/lib/sseEvents.ts` (created in F-006) are complete and their unit tests pass.

**Depends on**: F-004

**Complexity**: S

**Acceptance condition**: `exportHelpers.ts` compiles without errors. Unit test: given a mock `Response` with `Content-Disposition: attachment; filename="test.md"` and a blob body, `downloadBlob` creates and clicks an anchor element with the correct `download` attribute (use a jsdom-compatible approach to assert the anchor creation without a real browser click). Test is automated.

**Condition type**: automated

**Status**: not_started

---

### Task F-015: Unit tests — `lib/apiError.ts`, `lib/sseEvents.ts`, `stores/conversationState.ts`, sidebar ordering, config loading, `useMessages` pagination

**Description**: Implement all unit tests described in plan Section 14.1 (to the extent not already written in earlier tasks).

This task collects and completes unit tests that were specified in the plan but were not the primary deliverable of an earlier task:

- `lib/apiError.ts` normalisation tests (may already exist from F-004 — confirm and fill gaps):
  - JSON error body → correct `ApiError` fields.
  - 422 Pydantic shape → `validationErrors` array.
  - Non-JSON HTML body → generic message, correct status code.
  - 409 with `blocking_conversations` → `blocking_conversations` field populated.
- `lib/sseEvents.ts` type guard tests (may already exist from F-006 — confirm and fill gaps).
- `stores/conversationState.ts` reducer tests (may already exist from F-009 — confirm and fill gaps):
  - All documented state × action transitions from plan Section 8.2.
  - All invalid-transition no-op cases.
- `DiscussionsSidebar` ordering logic tests (may already exist from F-012 — confirm and fill gaps):
  - Given a fixture with folders, pinned, and standalone conversations, assert the ordering output matches the rules in Section 3.3.
- Config loading tests (may already exist from F-002 — confirm and fill gaps).
- `useMessages` pagination tests:
  - First fetch returns first page; `hasMore` is true when `has_more: true` in response.
  - `loadMore()` sends the correct `before` cursor.
  - Pages are prepended (oldest first order maintained).
  - `hasMore` becomes false when `has_more: false`.

All tests in this task use Vitest with MSW where network calls are involved.

**Depends on**: F-002, F-004, F-005, F-006, F-007, F-009, F-012

**Complexity**: M

**Acceptance condition**: `npm run test` passes with all unit tests in this task green. Coverage must include every case listed above. No test asserts internal implementation details — only observable outputs.

**Condition type**: automated

**Status**: not_started

---

### Task F-016: Hook tests — all 14 SWR hooks (happy path + error paths)

**Description**: Implement hook tests as described in plan Section 14.2, covering all 14 SWR data-fetching hooks.

Create one test file per hook in `apps/frontend/tests/hooks/`:

For each hook, test:
- **Happy path**: MSW handler returns the contract `200` response; assert returned `data` matches the fixture.
- **Loading state**: assert `isLoading` is `true` before the MSW response resolves.
- **404 Not Found**: MSW returns 404 with `{ message: "...", code: "..." }`; assert `error` is a normalised `ApiError` with the correct `code`.
- **403 Forbidden**: for `useEpisodicMemory` and `useSemanticMemory` — MSW returns 403; assert `error` is surfaced correctly.
- **Network error**: MSW handler throws; assert `error` has `code: 'network_error'` (or equivalent normalised form).
- `useEpisodicMemory` and `useSemanticMemory`: assert that when called with a non-Mentor persona (`is_mentor: false`), no fetch is made (SWR key is null).

Test fixtures must be typed against `src/api/schema.ts` (the generated types).

Full coverage table per plan Section 14.2.

**Depends on**: F-005, F-007

**Complexity**: M

**Acceptance condition**: All hook tests pass. Each of the 14 hooks has a dedicated test file. The `useEpisodicMemory`/`useSemanticMemory` guard test passes (no fetch on non-Mentor persona).

**Condition type**: automated

**Status**: not_started

---

### Task F-017: SSE hook tests — `useConversationStream` event dispatch

**Description**: Test the SSE hook and `ConversationStream` class as described in plan Section 14.5 (SSE mocking pattern).

Create `apps/frontend/tests/hooks/useConversationStream.test.ts`:
- Mock `@microsoft/fetch-event-source`'s `fetch` to return a `ReadableStream` emitting pre-defined SSE-framed event sequences.
- For each SSE event type (`token`, `response_complete`, `orchestrator_suggestion`, `busy`, `idle`, `paused`, `exchange_paused`), assert that the corresponding `SSEHandlers` callback is called with the correct parsed payload.
- Assert that `isConnected` is `true` after the stream opens and `false` (or the stream is closed) after unmount.
- Assert that the streaming buffer accumulates tokens correctly for a multi-token sequence and is cleared on `response_complete`.
- Assert that `"mentor:{uuid}"` keys in the buffer are stored and cleared without modification.
- Assert that the `handlers` ref stabilisation means changing the `handlers` object reference does not reopen the stream.

**Depends on**: F-005, F-008

**Complexity**: M

**Acceptance condition**: All SSE hook tests pass. Each SSE event type has at least one test. Buffer accumulation and clearance are tested. The handler-ref stability test passes.

**Condition type**: automated

**Status**: not_started

---

### Task F-018: Conversation state machine integration in `ConversationView` stub

**Description**: Wire the conversation state machine into a `ConversationView` component stub and confirm the reducer integrates with `useConversationStream` dispatch.

Create `apps/frontend/src/components/conversation/ConversationView.tsx` as a functional component (stub — does not render message list or input yet; those are F-020):
- Uses `useReducer(conversationReducer, initialConversationState)` for local state.
- Uses `useConversationStream(conversationId, workspaceId, handlers)` where `handlers` dispatch actions into the reducer.
- Renders the current `status` value as a `data-testid="conversation-status"` attribute on the root element (for testability).
- Renders `<OrchestratorSuggestionBanner>` when `pendingSuggestion` is non-null (component is a stub for now).
- Renders `<ExchangePausedBanner>` when status is any `exchange_paused_*` variant (component is a stub for now).
- `POST /end` response handling: on `deleted: true`, navigates away; on `deleted: false`, dispatches `POST_END_RECEIVED`.

This task does not implement the full conversation UI — it establishes the wiring so that SSE events flow into the reducer correctly.

**Depends on**: F-009, F-010, F-012

**Complexity**: S

**Acceptance condition**: `ConversationView` compiles and mounts without errors. An integration test (or manual check) confirms that a mocked `busy` SSE event changes `data-testid="conversation-status"` to `busy`, and a subsequent `idle` event changes it back to `idle`.

**Condition type**: manual

**Status**: not_started

---

### Task F-019: Component tests and accessibility tests — shared components

**Description**: Implement component tests and accessibility tests for all shared components, as described in plan Sections 14.3 and 14.4.

Create test files in `apps/frontend/tests/components/shared/`:

- `ConfirmDialog.test.tsx`:
  - Renders `title`, `description`, `confirmLabel`.
  - Clicking confirm calls `onConfirm`.
  - Clicking cancel calls `onCancel`.
  - Accessibility: `axe` passes on default render.
- `InlineEditable.test.tsx`:
  - Renders as text when idle.
  - Switches to input on click.
  - Enter key calls `onSave` with new value.
  - Escape key cancels and reverts to original value.
  - Accessibility: `axe` passes on idle state; `axe` passes on editing state.
- `MarkdownRenderer.test.tsx`:
  - Renders `**bold**` as a `<strong>` element.
  - Strips dangerous HTML (script injection) without crashing.
  - Accessibility: `axe` passes.
- `EmptyState.test.tsx`:
  - Renders heading and description.
  - Renders CTA button when `cta` prop is provided; button calls `onClick`.
  - Accessibility: `axe` passes with and without CTA.
- `ErrorBanner.test.tsx`:
  - Renders error message.
  - Renders `validationErrors` list when present.
  - Accessibility: `axe` passes.
- `LoadingSpinner.test.tsx`:
  - Has `role="status"`.
  - Has a visually-hidden label.
  - Accessibility: `axe` passes.

**Depends on**: F-005, F-011

**Complexity**: S

**Acceptance condition**: All component tests and accessibility tests pass. No `axe` violations on any asserted state.

**Condition type**: automated

**Status**: not_started

---

### Task F-020: Conversation view — full implementation (message list, input, header, context panel, participant panel)

**Description**: Implement the full `ConversationView` component tree as described in plan Sections 3.4, 5.4, 5.5, and 12.3.

Implement all conversation components in `apps/frontend/src/components/conversation/`:
- `MessageList.tsx` — renders messages top-to-bottom oldest-first. Scroll-up trigger calls `loadMore()` from `useMessages`. Renders `MessageBubble`, `SystemMessageMarker`, `ChapterBoundaryMarker` per message `role`/`message_subtype`.
- `MessageBubble.tsx` — renders user/persona/mentor messages. Shows sender name and content.
- `SystemMessageMarker.tsx` — renders generic system messages (join/leave events etc.).
- `ChapterBoundaryMarker.tsx` — renders `message_subtype: 'chapter_boundary'` as a full-width horizontal rule with "New Chapter" label.
- `StreamingBubble.tsx` — rendered below MessageList while a streaming response is in progress. Shows speaker name (resolved from SWR personas cache; handles `"mentor:{uuid}"` prefix per Section 6.5) and accumulated token buffer. Disappears on `idle`.
- `MessageInput.tsx` — controlled textarea. Hidden when `status: ended`. Disabled when `status: busy`. On submit: `POST /workspaces/$wsId/conversations/$cid/messages`.
- `ConversationHeader.tsx` — shows conversation title via `InlineEditable` (calls `PATCH /workspaces/$wsId/conversations/$cid` optimistically), `ModeSelector`, export button (calls `exportHelpers.downloadBlob` on `GET /conversations/$cid/export`; hidden when `busy`), End Conversation button. End Conversation shows `ConfirmDialog` then calls `POST /workspaces/$wsId/conversations/$cid/end`.
- `ModeSelector.tsx` — dropdown or segmented control. Options: `one_to_one`, `round_robin`. Calls `PATCH /workspaces/$wsId/conversations/$cid`. Hidden when `busy` or `ended`.
- `ParticipantPanel.tsx` — shows active participants. `SnapshotRefreshControl` shown per participant when `isStale && status === 'idle'` (staleness computed per the plan's cross-cutting concern section). Add Persona button shown when `idle` and conversation is `active`.
- `SnapshotRefreshControl.tsx` — button that calls `POST /workspaces/$wsId/conversations/$cid/participants/$cpId/refresh`.
- `ContextPanel.tsx` — collapsible right-hand panel. Shows character count vs `context_panel_max_chars`. Counter turns red when over-limit; Save disabled when over-limit. On Save: `PATCH /workspaces/$wsId/conversations/$cid/context-panel`. Shows `CONTEXT_PANEL_TOO_LONG` 422 error inline.
- `OrchestratorSuggestionBanner.tsx` — non-modal banner at top of message thread. Shows suggestion and reason. Accept button disabled when `status !== 'idle'`. Calls `POST /conversations/$cid/suggestions/$sid/accept` or `dismiss`. On accept: mutates `useConversation` cache with new participant and system message; updates mode if `updated_mode` differs.
- `ExchangePausedBanner.tsx` — renders correct message and recovery path per `pause_reason`:
  - `user_pause`: shows Resume button (calls `POST /conversations/$cid/resume`).
  - `turn_cap`: shows message input with "continue the exchange" prompt.
  - `repetition_detected`: shows message input with steering prompt.
- `AutoSummaryPanel.tsx` — rendered when `status: ended`. Shows the four `auto_summary` fields. Copy-as-Markdown button. Shows placeholder when `auto_summary` is null.
- `CanonisePlaceholder.tsx` — rendered when `status: ended`. Static message about archiving.
- `EndConversationFlow.tsx` — orchestrates the `ConfirmDialog` shown before ending, and triggers the `POST /end` call.

Update `ConversationView.tsx` (stub from F-018) with the full component tree.

Implement `src/routes/workspaces/$workspaceId/discussions/$conversationId/index.tsx` as the route that loads conversation detail and renders `ConversationView` or `MentorConversationView` (based on `is_mentor_conversation`).

**Depends on**: F-008, F-009, F-011, F-012, F-014, F-018

**Complexity**: L

**Acceptance condition**: Navigating to a conversation URL renders the message list, message input, header, context panel, and participant panel. Sending a message triggers the correct API call. Ending a conversation shows the confirm dialog then transitions to `ended` state with read-only view. The context panel enforces the character limit client-side. Export triggers a file download.

**Condition type**: manual

**Status**: not_started

---

### Task F-021: Mentor conversation view — `MentorConversationView`, `ChapterPromptDialog`, chapter boundary handling

**Description**: Implement Mentor-specific conversation UI as described in plan Sections 3.5, 9.1–9.5.

Create in `apps/frontend/src/components/mentor/`:
- `MentorConversationView.tsx` — wraps the `ConversationView` rendering path but suppresses: participant controls (no add/remove), mode selector, End Conversation button. Adds "New Chapter" button in the conversation header (calls `POST /workspaces/$wsId/conversations/$cid/chapter`). Detects `chapter_prompt_required: true` on conversation load and renders `ChapterPromptDialog`.
- `ChapterPromptDialog.tsx` — modal offering "Continue where we left off" (dismiss dialog, no API call) or "Start a fresh chapter" (calls `POST /workspaces/$wsId/conversations/$cid/chapter`). If the user begins typing before choosing, the dialog is dismissed (continuation assumed — listen for focus in `MessageInput`).

Chapter boundary rendering: confirm `ChapterBoundaryMarker` (implemented in F-020) is correctly rendered for messages with `message_subtype: 'chapter_boundary'` in the Mentor Conversation.

**Depends on**: F-020

**Complexity**: S

**Acceptance condition**: Navigating to the Mentor Conversation shows the Mentor-specific controls (no participant panel, no mode selector, no End button, New Chapter button present). If `chapter_prompt_required: true`, the `ChapterPromptDialog` appears immediately. "Start fresh chapter" calls the chapter endpoint. Typing in the message input before choosing dismisses the dialog.

**Condition type**: manual

**Status**: not_started

---

### Task F-022: Persona area — list, detail form, temperature slider, test panel

**Description**: Implement the Persona area as described in plan Sections 3.6 and parts of 10.

Implement:
- `src/routes/workspaces/$workspaceId/personas/index.tsx` — renders `PersonaList`. Contains "New Persona" button (`POST /workspaces/$wsId/personas`), "Create Mentor" button (only if no Mentor exists; navigates to the Mentor creation flow), and "Run now" Review Agent button.
- `apps/frontend/src/components/persona/PersonaList.tsx` — list of personas. Mentor persona is visually distinct. Clicking a persona navigates to persona detail.
- `apps/frontend/src/components/persona/PersonaCard.tsx` — a single persona item in the list.
- `apps/frontend/src/components/persona/PersonaForm.tsx` — controlled form with: Name field (disabled for Mentor, with tooltip), Description field, System Prompt textarea, `TemperatureSlider`, Save and Discard buttons. `isDirty` is tracked and passed to `TestPanel` as a prop. Save calls `PATCH /workspaces/$wsId/personas/$pid`. Validation: Name and System Prompt must not be empty (client-side; also shows 422 errors from server).
- `apps/frontend/src/components/persona/TemperatureSlider.tsx` — Base UI Slider, range 0.0–2.0, step 0.1. Labels "Precise & Analytical" at 0.0 and "Creative & Exploratory" at 2.0.
- `apps/frontend/src/components/persona/TestPanel.tsx` — disabled when `isDirty` is true. Generates `sessionId` (UUID v7) on mount. Sends `POST /personas/$pid/test` with SSE response via `openEphemeralStream`. Maintains local message list and streaming buffer. `X-Workspace-ID` header is included (non-workspace-scoped endpoint).
- `src/routes/workspaces/$workspaceId/personas/$personaId/index.tsx` — renders `PersonaForm`, `TestPanel`, `RecommendationsSection`, and (if Mentor) `MemoryInspectorPanel`.

**Depends on**: F-013, F-014

**Complexity**: L

**Acceptance condition**: The persona list renders all personas. Clicking a persona navigates to its detail page. The form saves correctly (with inline validation errors on empty fields). The temperature slider emits float values between 0.0 and 2.0. The test panel is disabled when the form has unsaved changes and sends messages via the SSE stream when enabled.

**Condition type**: manual

**Status**: not_started

---

### Task F-023: Review Agent UI — findings, `ConsultationPanel`, run status

**Description**: Implement the Review Agent UI as described in plan Sections 10.1–10.3.

Create:
- `apps/frontend/src/components/persona/RecommendationsSection.tsx` — renders active findings (`status: 'active'`) and stale findings (`status: 'stale'`) in two groups. Contains the "Run now" button (disabled when `latest_run?.status === 'running'`; triggers `POST /workspaces/$wsId/review-agent/run`; button is immediately disabled after click with no background polling). Re-uses the same `useReviewAgentStatus` SWR cache as the `PersonaList` page.
- `apps/frontend/src/components/persona/FindingCard.tsx` — active state: shows `evidence_text`, `suggestion_text`, Apply and Dismiss buttons with in-progress spinner. Dismiss: `POST /findings/$fid/dismiss`. Apply: `POST /findings/$fid/apply`; on success, removes card and updates `usePersona` SWR cache with the new `system_prompt`. Stale state: reduced opacity, amber border, "outdated" badge, no action buttons, inline "run Review Agent" prompt.
- `apps/frontend/src/components/persona/ConsultationPanel.tsx` — expandable right-hand panel on the Persona detail page. Generates `sessionId` on expansion (if not already set for this mount). Sends `POST /personas/$pid/consultation` with `{ message, session_id }` and `X-Workspace-ID` header via `openEphemeralStream`. Maintains local message history. Session is discarded on unmount.

**Depends on**: F-022

**Complexity**: M

**Acceptance condition**: Active findings show Apply/Dismiss buttons. Stale findings show the outdated badge and no action buttons. Applying a finding updates the system prompt field in `PersonaForm`. Dismissing a finding removes its card. The consultation panel opens, sends messages, and receives streaming responses. The Run now button is disabled while `status: running`.

**Condition type**: manual

**Status**: not_started

---

### Task F-024: Memory Inspector panel — `MemoryInspectorPanel` with source-type grouping

**Description**: Implement the Memory Inspector panel as described in plan Sections 3.8, 9.4, and the component test spec in 14.3.

Create `apps/frontend/src/components/mentor/MemoryInspectorPanel.tsx`:
- Collapsible panel, rendered only on the Mentor's Persona detail page (`persona.is_mentor === true`).
- Fetches `useEpisodicMemory` and `useSemanticMemory` only when expanded (pass `null` SWR key when collapsed).
- Episodic section: splits entries by `source_type`. Renders `"From Mentor sessions"` heading for `source_type: 'self'` entries (ordered by `sequence_number` asc) and `"From observed conversations"` heading for `source_type: 'observed'` entries (ordered by `sequence_number` asc). Each `'observed'` entry card shows `source_conversation_id` (and resolved Conversation title from SWR cache if available).
- Semantic section: renders each document via `MarkdownRenderer`, ordered by `updated_at` desc. No source grouping.

**Depends on**: F-007, F-022

**Complexity**: S

**Acceptance condition**: The Memory Inspector panel is only visible on the Mentor's Persona detail page. It does not fetch data until expanded. Episodic entries with `source_type: 'self'` appear under the "From Mentor sessions" heading and entries with `source_type: 'observed'` appear under "From observed conversations". Component tests in F-025 will verify the source-type grouping.

**Condition type**: manual

**Status**: not_started

---

### Task F-025: Component tests and accessibility tests — feature components

**Description**: Implement component tests and accessibility tests for feature components as described in plan Sections 14.3 and 14.4.

Create test files in `apps/frontend/tests/components/`:

- `conversation/FindingCard.test.tsx`:
  - Active finding: renders `evidence_text`, `suggestion_text`; shows Apply and Dismiss buttons.
  - Stale finding: shows "outdated" badge; no Apply/Dismiss buttons; shows stale prompt text.
  - Accessibility: `axe` passes on active state; `axe` passes on stale state.
- `persona/TemperatureSlider.test.tsx`:
  - Renders with "Precise & Analytical" label at low end and "Creative & Exploratory" at high end.
  - Emits correct float value on change (e.g. slider at midpoint emits ~1.0).
  - Accessibility: `axe` passes.
- `conversation/ContextPanel.test.tsx`:
  - Character count updates as content changes.
  - Over-limit: counter is visually distinguished; Save button is disabled.
  - Under-limit: Save button is enabled.
  - Accessibility: `axe` passes on under-limit state; `axe` passes on over-limit state.
- `conversation/ExchangePausedBanner.test.tsx`:
  - `pause_reason: 'user_pause'`: shows Resume button.
  - `pause_reason: 'turn_cap'`: shows message input with continuation prompt.
  - `pause_reason: 'repetition_detected'`: shows message input with steering prompt.
  - Accessibility: `axe` passes for each `pause_reason`.
- `conversation/OrchestratorSuggestionBanner.test.tsx`:
  - Renders `suggested_persona_name` and `reason`.
  - Accept button calls the accept endpoint with the correct `suggestion_id`.
  - Dismiss button calls the dismiss endpoint.
  - Accept button is disabled when `conversationStatus !== 'idle'`.
  - Accessibility: `axe` passes.
- `mentor/ChapterPromptDialog.test.tsx`:
  - Renders "Continue" and "Start fresh chapter" options.
  - "Continue" dismisses the dialog without making an API call.
  - "Start fresh chapter" calls the chapter endpoint.
  - Accessibility: `axe` passes.
- `conversation/AutoSummaryPanel.test.tsx`:
  - Renders all four `auto_summary` fields when populated.
  - Copy-as-Markdown button produces correct Markdown output.
  - Shows placeholder when `auto_summary` is null.
  - Accessibility: `axe` passes.
- `persona/PersonaForm.test.tsx`:
  - Save button is disabled when Name field is empty.
  - Save button is disabled when System Prompt field is empty.
  - `isDirty: true` is passed to `TestPanel` (verified via prop or test double).
  - Accessibility: `axe` passes.
- `mentor/MemoryInspectorPanel.test.tsx`:
  - Episodic entries with `source_type: 'self'` render under "From Mentor sessions" heading.
  - Episodic entries with `source_type: 'observed'` render under "From observed conversations" heading with `source_conversation_id` visible.
  - Accessibility: `axe` passes.

**Depends on**: F-005, F-019, F-020, F-021, F-022, F-023, F-024

**Complexity**: M

**Acceptance condition**: All component tests and accessibility tests pass. No `axe` violations in any asserted state. All nine component test files exist with the cases listed above.

**Condition type**: automated

**Status**: not_started

---

### Task F-026: Documents area — list, card, document view

**Description**: Implement the Documents area as described in plan Section 3.7.

Implement:
- `src/routes/workspaces/$workspaceId/documents/index.tsx` — renders `DocumentList`. Contains "Generate Report" button (`POST /workspaces/$wsId/documents/generate`; button is replaced with "Generation in progress" when `status: pending` exists for the workspace or a 409 conflict is returned).
- `apps/frontend/src/components/documents/DocumentList.tsx` — lists documents ordered `created_at` desc. Shows title, `status` badge (pending/complete/failed), creation date. Links to document view for `complete` documents.
- `apps/frontend/src/components/documents/DocumentCard.tsx` — a single document item in the list.
- `apps/frontend/src/components/documents/DocumentView.tsx` — renders `content_markdown` via `MarkdownRenderer` when `status: complete`. Shows "pending generation" placeholder when `status: pending` (SWR polling is active via `useDocument`). Shows failure message when `status: failed`. Provides rename (`PATCH /workspaces/$wsId/documents/$did` via `InlineEditable`), export (calls `exportHelpers.downloadBlob`), and delete (`DELETE /workspaces/$wsId/documents/$did` via `ConfirmDialog`) actions.
- `src/routes/workspaces/$workspaceId/documents/$documentId/index.tsx` — route that renders `DocumentView`.

**Depends on**: F-014, F-012

**Complexity**: S

**Acceptance condition**: The documents list shows all documents with status badges. Navigating to a complete document renders the Markdown content. Renaming and deleting a document work. Export triggers a download. The pending placeholder is shown for in-progress documents.

**Condition type**: manual

**Status**: not_started

---

### Task F-027: Error handling wiring — `ErrorBanner` integration, route-level error boundaries

**Description**: Implement comprehensive error handling wiring as described in plan Section 12.

This task wires error handling across the application:
- Add TanStack Router `errorComponent` at the workspace shell level (`_layout.tsx`) and conversation route level — renders `ErrorBanner` with the caught error.
- Confirm `ErrorBanner` is shown for `isLoading: false, error: present` states in all views that use SWR hooks (workspace shell, conversation view, persona area, documents area).
- Wire the 409 Persona-deletion conflict display: when `DELETE /workspaces/$wsId/personas/$pid` returns 409 with `blocking_conversations`, show a dialog listing the conversations by title.
- Wire the Mentor deletion blocked tooltip on the Persona detail page's delete button.
- Wire the SSE reconnection `ErrorBanner` with "Reconnect" button (Section 12.3) — show when `useConversationStream` calls `onError` after retries exhausted; clicking Reconnect calls `stream.close()` then `stream.open()`.
- Confirm `CONTEXT_PANEL_TOO_LONG` 422 error is displayed inline below the Context Panel (Section 12.4).
- Wire "Conversation busy" toast for 409 on participant add/remove when a response is in progress.

**Depends on**: F-013, F-020, F-022

**Complexity**: S

**Acceptance condition**: A simulated 5xx from any SWR hook shows an `ErrorBanner`. A 409 Persona deletion conflict shows the blocking conversations dialog. The SSE reconnection banner appears and the Reconnect button restores the stream. The context panel shows the inline 422 error when the backend rejects content as too long.

**Condition type**: manual

**Status**: not_started

---
