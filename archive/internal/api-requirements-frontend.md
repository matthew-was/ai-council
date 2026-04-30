# API Requirements — Frontend

## Status

Draft — 2026-04-23

---

## General API Requirements

### Base URL and Transport

**What the frontend needs to do**: Construct all API calls against a configurable base URL so that the application can point at different backend addresses (local development, local production, future cloud) without code changes.

**Data involved**: A single `apiBaseUrl` key read from `frontend/config.json` (or `frontend/config.override.json`).

**Expected behaviour**: Every REST and SSE request is prefixed with this base URL. The frontend must never hardcode a host, port, or path prefix.

**Notes**: This is a hard constraint derived from the Infrastructure as Configuration principle. The base URL must be baked into the Vite build at build time from the config file. See architecture section 11.2.

---

### Content Type

**What the frontend needs to do**: Send `Content-Type: application/json` on all POST and PATCH requests. Expect `Content-Type: application/json` on all REST responses.

**Data involved**: Request and response bodies.

**Expected behaviour**: All request bodies are JSON-encoded. All response bodies are JSON-decoded. The SSE stream uses `text/event-stream`.

---

### Error Response Shape

**What the frontend needs to do**: Handle errors consistently across all endpoints using a predictable error shape. The frontend will display user-facing error messages and, for validation errors, highlight the specific fields that failed.

**Data involved**: HTTP status codes and error body.

**Expected behaviour**: The frontend expects:
- `4xx` errors to carry a JSON body with at minimum a human-readable `message` string and an optional `code` string for programmatic handling.
- `422` validation errors to include a `detail` array where each entry identifies the field that failed and why, so the frontend can map errors back to form fields.
- `5xx` errors to carry a JSON body with a `message` string; the frontend will show a generic error state.
- Unexpected non-JSON responses (e.g. a gateway 502) to be handled gracefully — the frontend must not crash on non-JSON error bodies.

**Notes**: The exact field names (`message`, `code`, `detail`) are the backend's decision, but the frontend has a strong preference for a consistent envelope across all endpoints. FastAPI's default Pydantic validation error format is acceptable if kept consistent.

---

### Authentication (V1 Stub)

**What the frontend needs to do**: In V1, the frontend sends no authentication headers. All requests are unauthenticated.

**Data involved**: None.

**Expected behaviour**: The backend accepts all requests without an `Authorization` header in V1. The frontend must not be written in a way that makes adding token-based auth later require component-level rewrites — the auth concern should be centralised in a single request-construction utility.

**Notes**: This is a V1 constraint. The architecture (ADR-016) documents the upgrade path: the only backend change is the body of `resolve_current_user()`. The frontend's equivalent seam is the centralised request utility that adds headers.

---

### CORS

**What the frontend needs to do**: Make cross-origin requests from the browser to the backend in local development (frontend on one port, backend on another).

**Data involved**: N/A — this is a transport concern.

**Expected behaviour**: The backend must include appropriate CORS headers to allow requests from the frontend's origin in local development. The `Access-Control-Allow-Origin` value should be configurable rather than wildcard-only.

**Notes**: In the Docker Compose production deployment (architecture section 12), the frontend and backend may be on different ports or domains depending on the compose setup. CORS must be handled for both cases.

---

### OpenAPI Spec Availability

**What the frontend needs to do**: The Vite build step runs `openapi-typescript` against the backend's `/openapi.json` endpoint to generate `src/api/schema.ts`. This generated file provides all TypeScript types used in API calls.

**Data involved**: The full OpenAPI 3.x spec.

**Expected behaviour**:
- `/openapi.json` must be served without authentication so the build step can fetch it.
- Every request and response schema in the spec must have complete, explicit type definitions. The use of `any`, untyped `object`, or `additionalProperties: true` without a defined schema is a hard constraint violation — the generated TypeScript types will be `unknown` or `any`, which defeats the purpose.
- The SSE stream endpoint must be represented in the spec even if its event payload types cannot be fully expressed in OpenAPI 3.x (SSE is not natively supported). The frontend will use manually-typed event payloads for SSE events and reference the contract document directly.
- All enum values (e.g. `mode`, `status`, `role`, `pause_reason`) must be expressed as enum strings in the spec so the generated types are string literal unions, not plain `string`.

**Notes**: The OpenAPI spec is a build artefact generated from the FastAPI implementation. The `api-contract.md` document is the source of truth. Any schema inconsistency between the spec and the contract is a bug in the backend.

---

## Workspaces

### List All Workspaces

**What the frontend needs to do**: Populate the top-level Workspace navigation dropdown with all available Workspaces.

**Data involved**: For each Workspace: `id`, `name`, `created_at`.

**Expected behaviour**: The frontend expects a list of all Workspaces. No pagination is required — the number of Workspaces per user is expected to remain small in V1.

**Notes**: The list is ordered by the frontend (by `created_at` ascending or by name). The backend should return creation timestamps.

---

### Get a Single Workspace

**What the frontend needs to do**: Load the active Workspace's details when the user switches to it.

**Data involved**: `id`, `name`, `created_at`.

**Expected behaviour**: Returns the Workspace for the given ID. Returns a clear error if the Workspace does not exist.

---

### Create a Workspace

**What the frontend needs to do**: Create a new Workspace when the user provides a name.

**Data involved**: Sends: `name`. Receives: the newly created Workspace including its `id` and `created_at`.

**Expected behaviour**: On success, the frontend immediately sets the new Workspace as active and navigates to it. On validation failure (e.g. empty name), the backend returns a field-level error.

---

### Rename a Workspace

**What the frontend needs to do**: Update a Workspace's name when the user edits it.

**Data involved**: Sends: `name`. Receives: the updated Workspace.

**Expected behaviour**: On success, the frontend updates the Workspace name everywhere it appears (navigation dropdown, page title). On validation failure, a field-level error is returned.

---

### Delete a Workspace

**What the frontend needs to do**: Permanently delete a Workspace and all its content after user confirmation.

**Data involved**: Workspace `id`.

**Expected behaviour**: The backend deletes the Workspace and all Workspace-scoped content (Personas, Conversations, Folders, Documents, Mentor Conversation, all three Mentor memory layers, Review Agent runs and findings). On success, the frontend navigates to another Workspace or the empty state. If a Review Agent run is in progress for the deleted Workspace, the backend must stop it immediately (the frontend does not need to poll for this — it is a backend responsibility).

**Notes**: This is a cascading delete. The frontend has no visibility into the cascade; it only needs confirmation that the delete succeeded.

---

### Context Panel Character Limit

**What the frontend needs to do**: Display a live remaining-character count in the Context Panel UI and block saving when the user exceeds the configured limit. The character limit is enforced by the backend (`CONTEXT_PANEL_MAX_CHARS` in backend config). The frontend must not hard-code this value or read it from `frontend/config.json` — it must obtain it from the backend API so the two sides are always in sync.

**Data involved**: The `CONTEXT_PANEL_MAX_CHARS` integer value.

**Expected behaviour**: The frontend reads `CONTEXT_PANEL_MAX_CHARS` from the API response when it loads a Workspace, so the value is available before the user can open any Conversation. The preferred approach is for the backend to embed this value directly in the Workspace response — for example as a top-level `config` object or a `context_panel_max_chars` field — so no additional API call is needed. A separate `GET /config` endpoint would also be acceptable if the backend prefers to keep configuration separate from resource responses, but the frontend has a strong preference for the value arriving with the Workspace payload to avoid a second round-trip on every Workspace switch. The frontend then uses this value client-side to compute the remaining character count and to block the save action when the limit is exceeded. The backend remains the authoritative enforcer and will return a validation error if the limit is exceeded in the request body regardless of what the frontend displays.

**Notes**: Architecture section 11.7 explicitly resolves that `CONTEXT_PANEL_MAX_CHARS` is a backend config key only and is not duplicated in `frontend/config.json`. This requirement is the mechanism by which the frontend obtains the value at runtime.

---

## Personas

### List Personas in a Workspace

**What the frontend needs to do**: Populate the Personas area list and also populate Persona selection controls in the new Conversation flow.

**Data involved**: For each Persona: `id`, `name`, `description` (nullable), `system_prompt`, `temperature`, `is_mentor`, `created_at`, `updated_at`.

**Expected behaviour**: Returns all Personas for the active Workspace, ordered by `created_at` ascending. The `is_mentor` flag distinguishes the Mentor from standard Personas. The frontend uses this list both for the Personas area and for Persona selection when starting a Conversation.

**Notes**: The frontend needs `updated_at` to determine whether a Persona's configuration has changed since a Conversation's snapshot was taken (for the snapshot refresh control, US-C5). The backend must keep `updated_at` current on every edit.

---

### Get a Single Persona

**What the frontend needs to do**: Load the full Persona configuration when the user opens a Persona's profile page.

**Data involved**: `id`, `name`, `description`, `system_prompt`, `temperature`, `is_mentor`, `created_at`, `updated_at`.

**Expected behaviour**: Returns the Persona for the given ID within the active Workspace. Returns a clear error if not found.

---

### Create a Persona

**What the frontend needs to do**: Create a new Persona when the user completes the creation form. Also used to create the Mentor (with `is_mentor: true`).

**Data involved**: Sends: `name` (required), `system_prompt` (required), `description` (optional), `temperature` (required, numeric value). Receives: the newly created Persona including `id`, `is_mentor`, `created_at`, `updated_at`.

**Expected behaviour**: On success, the frontend adds the new Persona to the list and navigates to its profile. On validation failure, field-level errors are returned for `name` and `system_prompt`. Only one Mentor may exist per Workspace — if a second Persona is submitted with `is_mentor: true`, the backend returns a clear error.

**Notes**: The frontend enforces `is_mentor: true` only when the user is creating the Mentor through the designated Mentor creation flow. The frontend will not allow creating a second Mentor, but the backend must also enforce this constraint.

---

### Update a Persona

**What the frontend needs to do**: Save edits to an existing Persona's fields.

**Data involved**: Sends: any combination of `name`, `description`, `system_prompt`, `temperature`. Receives: the updated Persona including updated `updated_at`.

**Expected behaviour**: On success, the frontend reflects the changes immediately. The backend must record the new System Prompt version in `persona_system_prompt_versions` (for future version history — US-DM2) in the same transaction as the Persona update.

**Notes**: The Mentor's `name` field is not editable after creation (US-M1). The frontend will not send a `name` change for a Mentor Persona, but the backend should reject it if received.

---

### Delete a Persona

**What the frontend needs to do**: Delete a Persona that is not active in any open Conversation.

**Data involved**: Persona `id`.

**Expected behaviour**: On success, the Persona is removed from the list. If the Persona is active in one or more open Conversations, the backend returns an error that includes the IDs (and ideally titles) of the blocking Conversations, so the frontend can display an informative warning message to the user (US-P4). The frontend must not disable the delete button preemptively — it shows the warning only after the blocked-delete error is received.

**Notes**: The Mentor cannot be deleted (US-M1). The backend must reject a delete request for a Persona with `is_mentor: true` and return an appropriate error. The frontend will hide the delete control for the Mentor, but the backend must enforce this.

---

### Check Whether a Persona is Active in Open Conversations

**What the frontend needs to do**: Display the snapshot-refresh control (US-C5) for Personas whose configuration has changed since the Conversation snapshot was taken. The frontend also needs to know, for each Persona in the active Conversation, whether its live configuration differs from the snapshot.

**Data involved**: The active Conversation's `conversation_personas` rows (see Conversations section) carry `snapshot_name`, `snapshot_system_prompt`, `snapshot_temperature`. The Persona list carries `updated_at`. The frontend compares `persona.updated_at` against `conversation_persona.joined_at` to determine staleness.

**Expected behaviour**: No separate endpoint is required — the frontend derives staleness from data already present in the Conversation detail and Persona list responses.

**Notes**: This is a frontend-computed state. The backend does not need a dedicated "is stale" field, provided `updated_at` is reliably maintained on the Persona record.

---

## Persona Test (Preview Mode)

### Start and Continue a Persona Test Session

**What the frontend needs to do**: Send test messages to a Persona and receive streamed responses, without creating a persistent Conversation record.

**Data involved**: Sends: `persona_id`, `message` (string), and a `session_id` generated by the frontend to maintain turn context across multiple messages. Receives: streamed token response (same SSE mechanism as regular Conversations, or a synchronous response if SSE is not used for test sessions).

**Expected behaviour**: The backend runs the test message against the Persona's current saved System Prompt and temperature. The test session maintains a short multi-turn context for the duration of the session. The backend must not persist test session messages to the `messages` table — test sessions leave no trace in the database. On session discard (the user navigates away), the frontend simply stops sending requests; there is no explicit session-close call needed.

**Notes**: The architecture (Section 6.1 ModelGateway) notes that the Test panel uses `ModelGateway.stream`. The frontend needs a streaming response for the Test panel for a consistent typing experience. Whether this uses SSE or a different streaming mechanism is the backend's decision, but the frontend has a strong preference for SSE (same client-side handling path as Conversations). The `session_id` is a frontend-generated ephemeral identifier — the backend uses it to scope working context for the test session without persisting anything.

---

## Conversations

### List Conversations in a Workspace

**What the frontend needs to do**: Populate the Discussions sidebar with all Conversations, correctly ordered and grouped into Pinned, Standalone, Folder-assigned sections.

**Data involved**: For each Conversation: `id`, `title`, `mode` (enum: `one_to_one | round_robin | p2p`), `status` (enum: `active | ended`), `folder_id` (nullable), `pinned_at` (nullable timestamptz), `created_at`, `last_message_at` (the timestamp of the most recent message — for ordering Standalone Conversations).

**Expected behaviour**: Returns all Conversations for the active Workspace. No pagination is required at the list level — the frontend renders the full sidebar. The frontend performs all client-side sorting (Standalone by `last_message_at` DESC, Pinned by `pinned_at` ASC). The backend must keep `last_message_at` current as messages are added.

**Notes**: The frontend needs `last_message_at` rather than `updated_at` because sorting by activity means sorting by when the last message was received, not by when the Conversation record was last touched. If the backend cannot maintain a separate `last_message_at`, it must provide an equivalent field. This is a constraint the frontend places on the data shape.

---

### Get a Single Conversation (with Participants)

**What the frontend needs to do**: Load the full Conversation detail when the user opens a Conversation, including its current Persona participants and their snapshots.

**Data involved**:
- Conversation fields: `id`, `title`, `mode`, `status`, `context_panel`, `folder_id`, `pinned_at`, `created_at`, `ended_at` (nullable), `last_message_at`.
- Participants array: for each active participant: `conversation_persona_id`, `persona_id` (nullable — may be null if the Persona was deleted), `snapshot_name`, `snapshot_system_prompt`, `snapshot_temperature`, `joined_at`, `left_at` (nullable).
- Summary (if ended): `auto_summary` (the auto-generated end-of-conversation summary).

**Expected behaviour**: Returns the full Conversation including all active participants. The frontend uses `left_at` to distinguish currently active participants from those who have left. The frontend needs `persona_id` (even if nullable) to check for snapshot staleness — if `persona_id` is null (Persona deleted), the refresh control is suppressed.

**Notes**: The frontend does not need the full message list in this response — messages are fetched separately. The participant snapshots are needed upfront to render Persona avatars and names correctly.

---

### Create a Conversation

**What the frontend needs to do**: Create a new Conversation when the user completes the new Conversation flow (Persona selection, mode selection, optional Folder assignment, first message).

**Data involved**: Sends: `mode` (enum), `persona_ids` (array of Persona IDs to add as initial participants), `folder_id` (nullable). Receives: the newly created Conversation including `id`, `title`, `status`, `mode`, `folder_id`, `created_at`, plus the created `conversation_personas` entries with their snapshots.

**Expected behaviour**: On success, the frontend navigates to the new Conversation view and opens the SSE stream. The backend creates the Conversation, takes snapshots of all specified Personas, and returns the full detail. The first user message is sent separately via the message endpoint.

**Notes**: The title is not sent by the frontend — the backend sets it to "New Conversation [timestamp]" on creation (US-C1). The frontend sends `persona_ids` as an array; the backend is responsible for validating that these Personas exist in the Workspace and creating the snapshots.

---

### Update a Conversation (Title, Context Panel, Folder, Pin Status, Mode)

**What the frontend needs to do**: Update individual Conversation fields as the user interacts — renaming a Conversation, saving Context Panel edits, moving to a Folder, pinning or unpinning, switching the mode.

**Data involved**: Sends: any combination of `title`, `context_panel`, `folder_id` (nullable — null means remove from Folder), `pinned_at` (nullable — null means unpin), `mode` (enum). Receives: the updated Conversation.

**Expected behaviour**: Each field can be updated independently. The backend validates that a mode change is valid given the current participant count — e.g. switching to `round_robin` or `p2p` requires at least two active participants; switching to `one_to_one` requires removing excess participants first (the frontend handles the removal separately before sending the mode update).

**Notes**: The frontend sends `context_panel` updates on an explicit user save action — not on every keystroke. The backend enforces the Context Panel character limit (read from configuration) and returns a validation error if exceeded. The frontend displays a character count and blocks saving when over-limit, but the backend is the authoritative enforcer.

---

### End a Conversation

**What the frontend needs to do**: Transition a Conversation to `ended` status, trigger the automatic structured summary generation, and display the summary in the right-hand panel of the ended Conversation view.

**Data involved**: Sends: nothing beyond the Conversation ID. Receives: either (a) the updated Conversation with `status: ended`, `ended_at`, and a structured summary object (nullable — null while still generating), or (b) a response indicating the Conversation was deleted because it was empty.

**Expected behaviour**: The `POST /conversations/{id}/end` endpoint has two possible outcomes that the frontend must be able to distinguish:

**Normal case (Conversation has user/persona/mentor messages):** The backend sets the Conversation to `ended` and triggers summary generation asynchronously. The endpoint returns immediately with the updated Conversation. The frontend renders the ended Conversation view with a "summary being generated" placeholder in the right-hand panel. When the user returns to the Conversation (on refresh or re-navigation), `GET /conversations/{id}` returns the completed structured summary. The summary is always visible on any subsequent load of the ended Conversation. From this point, the Conversation is read-only.

**Empty case (Conversation has no user/persona/mentor messages):** The backend deletes the Conversation entirely — it does not transition to `ended`. The frontend must detect this outcome and respond by: removing the Conversation from the sidebar, navigating away from the Conversation view, and not attempting to render a read-only ended view (there is nothing to show).

The response must allow the frontend to distinguish which outcome occurred. A suggested approach is a `deleted: true` flag on the response body, or using HTTP 204 No Content for the delete case vs. HTTP 200 with the Conversation body for the normal case. The exact mechanism is the Backend Senior Developer's decision, but the frontend has a hard requirement to know which outcome occurred — it cannot safely assume one path or the other.

**Structured summary shape** (per overview.md Section 6.2):
- `key_takeaways`: array of strings — the most important conclusions reached
- `points_of_agreement`: array of strings — topics where Personas aligned
- `points_of_disagreement`: array of strings — topics where Personas held conflicting views
- `action_items`: array of strings — next steps or decisions that emerged

The summary can be copied as Markdown — the frontend assembles the Markdown from the structured fields. No edit or regenerate controls in V1.

**Notes**: The structured end-of-conversation summary is a distinct field from the internal `conversation_summaries` rolling context window summary. The rolling summary is never exposed in API responses. The structured summary is stored separately on the Conversation record (or a related table) and returned in all Conversation detail responses once generated.

**Canonise button**: Section 6.1 of the overview specifies a "Canonise this conversation" option in the end-of-conversation UI. In V1 this is a **non-functional placeholder** — the button must be present but does nothing. No backend endpoint is required for canonisation in V1.

**Flagged concern**: The timing and delivery mechanism for the auto-summary is not fully specified in the architecture. This needs to be confirmed in the contract.

**Developer decision (FC-1 — revised)**: The structured auto-summary IS user-facing (overview.md Section 6.2). It is distinct from the internal `conversation_summaries` table. `POST /conversations/{id}/end` returns immediately with `status: ended`; summary generation is async. The frontend shows a placeholder until the summary is available. The summary is retrieved via `GET /conversations/{id}` on return — same "check back" pattern as FC-3 (Report generation). The Conversation detail response must include the structured summary object (null while pending, populated once complete).

---

### Delete a Conversation

**What the frontend needs to do**: Permanently delete a Conversation and navigate back to the sidebar.

**Data involved**: Conversation `id`.

**Expected behaviour**: On success, the Conversation is removed from the sidebar. Any Reports generated from this Conversation remain in the Documents area (their `source_conversation_id` becomes a dangling reference, but the Documents themselves are not deleted — US-R2).

---

### Add a Persona to a Conversation

**What the frontend needs to do**: Add a Persona to an active Conversation when the system is idle.

**Data involved**: Sends: `persona_id`. Receives: the new `conversation_personas` entry (with `id`, `snapshot_name`, `snapshot_system_prompt`, `snapshot_temperature`, `joined_at`) and the system message that was inserted into the thread.

**Expected behaviour**: The backend takes a snapshot of the Persona at the moment of joining, inserts a system message into the Conversation thread, and returns both. The frontend adds the Persona to the active participants display and inserts the system message into the message list.

---

### Remove a Persona from a Conversation

**What the frontend needs to do**: Remove a Persona from an active Conversation when the system is idle, provided it is not the last remaining Persona.

**Data involved**: Sends: `conversation_persona_id` (the snapshot row ID, not the raw Persona ID). Receives: the updated `conversation_personas` row (with `left_at` set) and the system message that was inserted.

**Expected behaviour**: The backend sets `left_at` on the `conversation_personas` row, inserts a system message, and returns both. If removing this Persona would leave zero active participants, the backend returns an error (the frontend should prevent this, but the backend must enforce it). If the remaining participant count drops below the mode minimum, the backend also applies the mode downgrade and returns the updated Conversation `mode`.

---

### Refresh a Persona Snapshot

**What the frontend needs to do**: Replace a Persona's snapshot in an active Conversation with the Persona's current live configuration.

**Data involved**: Sends: `conversation_persona_id`. Receives: the updated `conversation_personas` row with the new `snapshot_name`, `snapshot_system_prompt`, `snapshot_temperature`.

**Expected behaviour**: The backend creates a new `conversation_personas` row for the same Persona with a new `joined_at` (the old row is not deleted — the history is preserved). The frontend updates its display of the Persona's snapshot state and hides the refresh control.

---

## Messages

### List Messages in a Conversation

**What the frontend needs to do**: Load the full message history when the user opens a Conversation, and page backward through older messages as the user scrolls up.

**Data involved**: For each message: `id`, `conversation_id`, `conversation_persona_id` (nullable), `role` (enum: `user | persona | mentor | system`), `content`, `created_at`.

**Expected behaviour**:
- The frontend loads messages in descending order (newest first) for initial render, then renders them ascending (oldest at top) for display.
- Cursor-based pagination is required: the frontend requests a page of N messages starting from a cursor (the oldest message ID already loaded), and the backend returns the next N older messages and a cursor for the next page.
- The frontend determines which Persona name to display by cross-referencing `conversation_persona_id` with the participants list. If `conversation_persona_id` is null (user or system message), the role determines display.
- System messages (`role: system`) are displayed as event markers (e.g. "Risk Analyst joined", "Mode changed to Round-Robin").

**Notes**: The frontend needs a way to resolve `conversation_persona_id` to a display name for each message. This comes from the participants list fetched with the Conversation detail. The backend does not need to embed the name in each message row.

---

### Send a User Message

**What the frontend needs to do**: Submit a user message to the Conversation and trigger the AI response cycle.

**Data involved**: Sends: `content` (string). Receives: the persisted user message (`id`, `role: user`, `content`, `created_at`).

**Expected behaviour**: The backend persists the user message and triggers the LangGraph graph to begin the response cycle. The frontend receives the persisted message in the response (for display) and then waits for SSE events on the stream for the AI response. The backend returns promptly after persisting — it does not block waiting for the AI response.

**Notes**: This is `POST /conversations/{id}/messages`. It also serves as the P2P recovery endpoint when `pause_reason` is `turn_cap` or `repetition_detected` (architecture section 10.3). The frontend sends a regular message in these cases — the backend detects the recovery context from graph state and resets the relevant counter.

---

## Folders

### List Folders in a Workspace

**What the frontend needs to do**: Populate the Folders section in the Discussions sidebar and the Folder selection control in the new Conversation flow.

**Data involved**: For each Folder: `id`, `name`, `created_at`, `conversation_count` (the number of Conversations currently assigned to the Folder, for display in the sidebar).

**Expected behaviour**: Returns all Folders for the active Workspace, ordered by `created_at` ascending (oldest first). No pagination required.

**Notes**: The `conversation_count` field is a frontend display requirement for the collapsed Folder row. If the backend cannot provide this as a computed field in the list response, the frontend can derive it from the Conversation list by counting `folder_id` occurrences — but a dedicated field is preferred for efficiency.

---

### Create a Folder

**What the frontend needs to do**: Create a new Folder when the user provides a name.

**Data involved**: Sends: `name`. Receives: the newly created Folder including `id`, `created_at`.

**Expected behaviour**: On success, the frontend adds the Folder to the sidebar. On validation failure (empty name), a field-level error is returned.

---

### Rename a Folder

**What the frontend needs to do**: Update a Folder's name.

**Data involved**: Sends: `name`. Receives: the updated Folder.

---

### Delete a Folder

**What the frontend needs to do**: Delete a Folder. Conversations within the Folder become standalone (they are not deleted).

**Data involved**: Folder `id`.

**Expected behaviour**: On success, the backend removes the Folder and sets `folder_id` to null on all Conversations that were in it. The frontend moves those Conversations to the Standalone section. The frontend needs to either refetch the Conversation list or receive the list of affected Conversation IDs in the delete response so it can update the sidebar without a full refetch.

**Notes**: The frontend has a preference for receiving the list of affected Conversation IDs in the delete response (e.g. `{ "unassigned_conversation_ids": ["..."] }`), but will accept a full Conversation list refetch if the backend does not return this.

---

## Documents (Reports)

### List Documents in a Workspace

**What the frontend needs to do**: Populate the Documents area with all Reports for the active Workspace.

**Data involved**: For each Document: `id`, `type` (always `report` in V1), `title`, `source_conversation_id` (nullable — null if source Conversation was deleted), `created_at`.

**Expected behaviour**: Returns all Documents for the active Workspace, ordered by `created_at` descending (newest first). No pagination required in V1.

**Notes**: The `content_markdown` field is not needed in the list response — only in the detail view. The frontend uses `source_conversation_id` to determine whether a "View source conversation" link should be shown. If `source_conversation_id` is present but the Conversation no longer exists, the link is suppressed.

---

### Get a Single Document

**What the frontend needs to do**: Display the full Report content when the user opens a Document.

**Data involved**: `id`, `type`, `title`, `content_markdown`, `source_conversation_id` (nullable), `created_at`.

---

### Generate a Report from a Conversation

**What the frontend needs to do**: Trigger Report generation from a concluded Conversation and receive the generated Report.

**Data involved**: Sends: `conversation_id`. Receives: the newly created Document including `id`, `title`, `content_markdown`, `created_at`.

**Expected behaviour**: Report generation may take several seconds. The frontend needs to know when it is complete. Two acceptable approaches: (1) synchronous response (simplest — the endpoint blocks until the Report is generated and returns the complete Document); (2) the endpoint returns immediately with a pending Document ID, and the frontend polls or receives a notification when complete.

Given the "keep simple things simple" principle, the synchronous approach is preferred for V1, with the frontend showing a loading state. The backend must confirm which approach it will implement.

**Notes**: Only one Report can be in progress at a time per Conversation (US-R1). If the user attempts to generate a second Report while one is in progress, the backend returns a `409 Conflict`. The frontend disables the generate button while generation is in progress, but the backend must enforce the constraint.

**Developer decision (FC-3)**: Async with refresh. The endpoint returns immediately with a pending Document record (e.g. `status: "pending"`). The frontend shows a placeholder — "Report is being generated, check back later." The user refreshes or uses a manual refresh button to re-fetch the Document. No SSE event or polling required. The Document detail response includes a `status` field so the frontend can distinguish a completed Report from one still generating.

---

### List Documents for a Specific Conversation

**What the frontend needs to do**: Show links to all Reports generated from a specific Conversation within the Conversation view.

**Data involved**: For each Document associated with the Conversation: `id`, `title`, `created_at`.

**Expected behaviour**: Returns all Documents with `source_conversation_id` matching the given Conversation ID. The frontend uses this to display "View Report" links within the Conversation view and to show whether the "Generate Report" option should be shown alongside them.

**Notes**: This could be implemented as a filter on the main Documents list endpoint (e.g. `?source_conversation_id=...`), or as a separate sub-resource endpoint. The frontend has no preference — either approach works provided the filter is available.

---

### Rename a Document

**What the frontend needs to do**: Update a Document's title.

**Data involved**: Sends: `title`. Receives: the updated Document.

---

### Delete a Document

**What the frontend needs to do**: Permanently delete a Report.

**Data involved**: Document `id`.

**Expected behaviour**: On success, the Document is removed from the Documents area and all "View Report" links to it from the Conversation view are gone. The source Conversation is unaffected.

---

## Review Agent

### Get Review Agent Run Status for a Workspace

**What the frontend needs to do**: Determine whether a Review Agent run is currently in progress so that the "Run now" button can be shown as disabled when appropriate (US-RA2).

**Data involved**: `status` (enum: `pending | running | complete | failed`), `started_at`, `completed_at` (nullable).

**Expected behaviour**: Returns the most recent Review Agent run for the active Workspace (or a "no runs yet" state). The frontend checks this on page load of the Personas area to set the initial button state. The frontend does not poll in real time — it re-checks on user interaction (e.g. navigating back to the Personas area).

**Notes**: The frontend only needs to know whether a run is currently `running`. The button is disabled if and only if `status === 'running'`.

---

### Manually Trigger a Review Agent Run

**What the frontend needs to do**: Trigger a Review Agent run covering all Personas in the Workspace when the user clicks "Run now".

**Data involved**: Sends: nothing beyond the Workspace context (derived from the active Workspace in middleware). Receives: confirmation that the run was accepted, or a `409 Conflict` if a run is already in progress.

**Expected behaviour**: On success (`202 Accepted` or equivalent), the frontend disables the "Run now" button. On `409`, the frontend shows a message that a run is already in progress.

---

### List Findings for a Persona

**What the frontend needs to do**: Display all Review Agent findings for a specific Persona in its Recommendations section, including both actionable findings and those that have become stale (US-RA3).

**Data involved**: For each finding: `id`, `persona_id`, `evidence_text` (the quoted or described exchange), `suggestion_text` (the specific suggestion for the System Prompt), `status` (enum: `active | stale | actioned | dismissed`), `created_at`.

**Expected behaviour**: Returns all findings for the given Persona with `status` of `active` or `stale`. (Findings with status `actioned` or `dismissed` do not need to appear in the list — they are historical records only.) The list is refreshed on page load — there is no real-time updating.

The frontend renders `active` and `stale` findings differently:
- `active` findings are displayed in the normal card style with Apply and Dismiss action controls available.
- `stale` findings are displayed visually distinct from active ones — for example, greyed out or with a warning indicator — to communicate that they can no longer be applied to the current System Prompt. The Apply and Dismiss controls are not available on stale findings. Each stale finding displays a message prompting the user to run the Review Agent to refresh (e.g. "This suggestion is outdated — run the Review Agent to update it"). The existing "Run now" control in the Personas area is the mechanism for this action; no separate button is needed within the stale finding card.
- Stale findings remain visible in the list until the user runs the Review Agent. The nightly run or a manual "Run now" will either drop the stale finding (if the underlying issue is resolved) or regenerate it as a new active finding against the current System Prompt.

**Notes**: A finding becomes `stale` automatically when the Persona's System Prompt is edited and the finding's `target_passage` is no longer present in the new prompt (architecture section 5.5). The backend sets this status; the frontend only needs to read and render it correctly. The exact schema of `review_agent_findings` is to be finalised by the Senior Developer (Backend) — the architecture notes this explicitly. The frontend needs at minimum: an identifier, evidence text, suggestion text, and status. The suggestion text must contain the proposed System Prompt change so the Apply action knows what to write for `active` findings.

---

### Apply a Finding

**What the frontend needs to do**: Apply a Review Agent finding to a Persona's live System Prompt with a single click.

**Data involved**: Sends: `finding_id`. Receives: the updated Persona (with new `system_prompt` and `updated_at`), and confirmation that the finding has been removed.

**Expected behaviour**: The backend applies the suggested change to the Persona's `system_prompt`, updates `updated_at`, records the new version in `persona_system_prompt_versions`, marks the finding as actioned (removing it from future list responses), and returns the updated Persona. The frontend removes the finding card immediately and updates its local copy of the Persona's System Prompt.

**Notes**: The exact mechanism for "applying" the suggestion (full replacement vs. append vs. diff-application) is the backend's implementation decision. The frontend only needs the resulting `system_prompt` returned in the response. The Apply action is only available on findings with `status: active`. The frontend must not render or enable the Apply control for `stale` findings; the backend must also reject apply requests for stale findings.

---

### Dismiss a Finding

**What the frontend needs to do**: Dismiss a Review Agent finding so it disappears from the list and is suppressed by the Review Agent.

**Data involved**: Sends: `finding_id`. Receives: confirmation.

**Expected behaviour**: The backend marks the finding as dismissed and communicates the dismissal context to the Review Agent (so it can apply its prompt-driven suppression logic). The frontend removes the card immediately.

**Notes**: The Dismiss action is only available on findings with `status: active`. The frontend must not render or enable the Dismiss control for `stale` findings; the backend must also reject dismiss requests for stale findings.

---

### Interactive Consultation (Review Agent Chat)

**What the frontend needs to do**: Support a multi-turn chat session with the Review Agent within the Persona's Recommendations section (US-RA4). This is an expandable right-hand panel in the Personas area.

**Data involved**: Sends: `persona_id`, `message` (string), `session_id` (frontend-generated ephemeral identifier for turn context). Receives: streamed or single-shot text response from the Review Agent.

**Expected behaviour**: The backend calls the Review Agent with the Persona's current System Prompt and existing findings as context (but not Conversation histories — this is explicitly excluded, US-RA4). The session is ephemeral — no history is persisted. The frontend discards the session on navigation. The backend must not persist consultation messages to the database.

**Notes**: The architecture notes that this mode is powered by the same AI model as all other functions. Whether responses are streamed or returned as a single response is the backend's decision. The frontend prefers streaming for a better interactive feel, but will accept a single-response pattern.

---

## Mentor

### Mentor as a Persona

The Mentor is managed as a Persona with `is_mentor: true` (see Personas section above). Mentor creation, System Prompt editing, temperature configuration, deletion blocking, and rename blocking are all handled via the Persona endpoints.

---

### Get the Mentor Conversation

**What the frontend needs to do**: Load the single, ongoing Mentor Conversation when the user clicks the Mentor slot in the sidebar (US-M3).

**Data involved**: The Mentor Conversation is a Conversation record with a special marker. The frontend needs: `id`, `status` (always `active`), `last_session_date` (the calendar date of the most recent message, for the chapter prompt logic), and the full message history (via the Messages endpoint).

**Expected behaviour**: Returns the Mentor Conversation for the active Workspace. If no Mentor has been configured (no Persona with `is_mentor: true` exists), the endpoint returns a clear "mentor not configured" response that the frontend uses to redirect the user to the Personas area.

**Notes**: The Mentor Conversation is a regular Conversation record linked to the Mentor Persona. The frontend distinguishes it by checking whether the Conversation's associated Persona has `is_mentor: true`. The exact mechanism (a dedicated endpoint vs. a flag on the Conversation) is the backend's decision, but the frontend needs a reliable way to identify and fetch the Mentor Conversation by Workspace without knowing its ID in advance.

**Flagged concern**: The architecture does not specify whether there is a dedicated `GET /mentor-conversation` endpoint or whether the frontend must discover the Mentor Conversation's ID from the Conversation list. A dedicated endpoint is strongly preferred by the frontend — it avoids loading the full Conversation list just to find the Mentor Conversation ID.

**Developer decision (FC-2)**: No dedicated endpoint is needed. The Conversation list is always loaded to populate the sidebar, so the Mentor Conversation is already present in that payload. The backend should include an `is_mentor_conversation: true` flag (or equivalent) on Conversation list and detail responses. The frontend identifies the Mentor Conversation from this flag without an additional API call.

---

### Start a New Mentor Chapter

**What the frontend needs to do**: Insert a chapter marker into the Mentor Conversation thread when the user selects "Start a fresh chapter" or uses the manual chapter control (US-M4).

**Data involved**: Sends: nothing beyond the Conversation ID. Receives: the system message that was inserted as the chapter marker, including `id`, `content`, `created_at`.

**Expected behaviour**: The backend inserts a system message of a defined type (e.g. `role: system`, `content: "[Chapter boundary]"` or equivalent) into the Mentor Conversation at the current point. The frontend displays this as a visual chapter marker in the thread. This endpoint also triggers the Working Memory → Episodic Memory compression for the chapter boundary (architecture section 8.3, US-MM1) — this is a backend side-effect and the frontend does not need to know about it.

**Notes**: The frontend needs a reliable way to identify chapter marker messages so it can render them differently from other system messages (e.g. Persona join/leave events). A distinct `content` prefix, a separate `message_type` field, or a flag on the message is needed. The exact approach is the backend's decision.

---

## Mentor Memory Inspector

### Get Episodic Memory Entries

**What the frontend needs to do**: Display the Episodic Memory section of the Memory Inspector panel (US-M5).

**Data involved**: For each episodic entry: `id`, `sequence_number`, `summary_text`, `created_at`.

**Expected behaviour**: Returns all Episodic Memory entries for the Mentor Persona in the active Workspace, ordered by `sequence_number` ascending. The panel is read-only — no write operations are needed from the frontend.

**Notes**: In V1, all entries are loaded ("load all" retrieval per architecture section 8.2). The frontend renders them as a list of summary cards.

---

### Get Semantic Memory Documents

**What the frontend needs to do**: Display the Semantic Memory section of the Memory Inspector panel (US-M5).

**Data involved**: For each semantic document: `id`, `title`, `content_markdown`, `created_at`, `updated_at`.

**Expected behaviour**: Returns all Semantic Memory documents for the Mentor Persona in the active Workspace. The panel renders `content_markdown` as formatted Markdown. The panel is read-only.

---

## SSE Streaming

### Open a Conversation Stream

**What the frontend needs to do**: Open a long-lived SSE stream per open Conversation to receive AI response tokens and orchestrator events in real time (US-O1, US-O3).

**Endpoint structure**: `GET /conversations/{id}/stream`

**Reconnection requirement**: The frontend uses `@microsoft/fetch-event-source` which handles reconnection natively using the `Last-Event-ID` header. The backend must assign a server-side event ID to every event so the client can resume from the correct point after a disconnect.

**When the frontend opens the stream**: Immediately when the user opens a Conversation view, before the user has sent any messages. The stream remains open for the duration of the Conversation view. When the user navigates away from the Conversation, the frontend closes the stream.

**When the frontend closes the stream**: On navigation away from the Conversation view. For the Mentor Conversation, a stream close on page navigation constitutes a "session end" signal — the backend should use this (or the `pagehide` beacon mentioned in architecture section 8.3) to trigger the Episodic → Semantic memory promotion. The frontend will send a `POST /mentor-conversation/session-end` (or equivalent) on page unload if the backend cannot reliably detect stream close. Whether a dedicated session-end signal is required is a question for the contract.

---

### Named SSE Event Types

The frontend expects the following named event types on the stream:

#### `token`

**Payload the frontend expects**:
- `content`: string — the incremental token text to append to the current response being built in the UI.
- `conversation_persona_id`: string — identifies which Persona (or Mentor) is speaking, so the frontend can attribute the tokens to the correct message bubble.

**Frontend behaviour**: Appends `content` to the in-progress message bubble for the identified speaker. If no in-progress bubble exists, creates one.

---

#### `response_complete`

**Payload the frontend expects**:
- `message_id`: string — the ID of the persisted message that was just completed, so the frontend can replace its optimistic/streaming version with the canonical persisted record.
- `conversation_persona_id`: string — the speaker.
- `content`: string — the full content of the completed message (for replacing the streaming buffer).

**Frontend behaviour**: Finalises the message bubble, replaces streaming content with the canonical `content`, and stores the `message_id` for future reference (e.g. export ordering).

---

#### `orchestrator_suggestion`

**Payload the frontend expects**:
- `suggested_persona_id`: string — the ID of the Persona being suggested.
- `suggested_persona_name`: string — the display name (for use in the suggestion UI without requiring a separate lookup).
- `reason`: string — a human-readable explanation of why this Persona is being suggested (e.g. "Your Risk Analyst Persona may be relevant given the current direction").
- `suggestion_id`: string — a stable identifier for this suggestion, used when the user accepts or dismisses it so the backend can track suppression.

**Frontend behaviour**: Displays a non-intrusive suggestion banner or card. The user can accept (adding the Persona and switching mode if in 1:1) or dismiss. On acceptance or dismissal, the frontend calls the appropriate control endpoint.

---

#### `busy`

**Payload the frontend expects**: None required beyond the event type.

**Frontend behaviour**: Sets the system state to "busy" — disables send controls, hides Persona add/remove/mode-switch controls, shows a loading indicator on the Conversation.

---

#### `idle`

**Payload the frontend expects**: None required beyond the event type.

**Frontend behaviour**: Sets the system state to "idle" — re-enables send controls, shows Persona add/remove/mode-switch controls, hides loading indicators.

---

#### `paused`

**Payload the frontend expects**: None required beyond the event type.

**Frontend behaviour**: Indicates the Conversation has been paused (e.g. Round-Robin cycle paused due to Workspace switch). The frontend shows a "Conversation paused — resume to continue" state. A Resume button becomes visible.

---

#### `exchange_paused`

**Payload the frontend expects**:
- `pause_reason`: string enum — one of `user_pause | turn_cap | repetition_detected`.

**Frontend behaviour**: Varies by `pause_reason`:
- `user_pause`: User pressed Pause. Show a "Paused" state with a Resume button. Recovery is via `POST /conversations/{id}/resume`.
- `turn_cap`: The P2P exchange hit the turn cap. Show a message explaining the exchange paused to check in. A text input is shown prompting the user to send a message (e.g. "continue" or a new direction) to reset the counter and resume. Recovery is via `POST /conversations/{id}/messages`.
- `repetition_detected`: The system detected repetitive responses. Show a message explaining this and prompt the user to send a steering input. Recovery is via `POST /conversations/{id}/messages`.

**Notes**: The frontend must show distinct UI for each `pause_reason` because the recovery paths differ. `user_pause` recovery is `resume`; `turn_cap` and `repetition_detected` recovery is a new message.

---

### Orchestrator Suggestion Accept/Dismiss

**What the frontend needs to do**: Signal to the backend that the user accepted or dismissed an Orchestrator suggestion.

**Data involved**: Sends: `suggestion_id`. For accept: also sends `persona_id` (the suggested Persona to add). Receives: for accept — the updated Conversation (with the new participant added and mode updated if applicable); for dismiss — confirmation.

**Expected behaviour**: Accept triggers the same backend logic as a manual Persona addition (snapshot taken, system message inserted, mode updated if switching from 1:1). Dismiss marks the suggestion as suppressed in the Orchestrator's context.

**Notes**: The frontend may implement accept as two sequential calls (add Persona, then dismiss suggestion) or as a single accept endpoint. A single endpoint is preferred. Whether this is a dedicated `POST /conversations/{id}/suggestions/{suggestion_id}/accept` pattern or something different is the backend's decision.

---

## Control Signal Endpoints

### Pause a Conversation (User-Initiated)

**What the frontend needs to do**: Set `pause_requested = true` in the LangGraph graph state so the current P2P exchange pauses at the next turn boundary.

**Data involved**: No body required.

**Expected behaviour**: The backend sets the flag via the LangGraph checkpointer. The frontend receives confirmation that the pause was requested. The actual `exchange_paused` event with `pause_reason: user_pause` arrives on the SSE stream when the graph observes the flag.

**Notes**: This is `POST /conversations/{id}/pause`.

---

### Resume a Paused Conversation

**What the frontend needs to do**: Clear `pause_requested` and resume the Conversation or P2P exchange from the last checkpoint.

**Data involved**: No body required.

**Expected behaviour**: The backend clears the pause flag via the checkpointer and resumes the graph. The frontend receives the `busy` event on the SSE stream when the exchange resumes.

**Notes**: This is `POST /conversations/{id}/resume`. This endpoint handles two pause origins that converge on the same resume path:

- **User-initiated pause** (`pause_reason: user_pause`): The user pressed the Pause button. The frontend shows a Resume button; clicking it calls this endpoint.
- **Workspace-switch interrupt**: When the user navigates to a different Workspace while a Conversation is open, the backend automatically sets `pause_requested = true` at the next turn boundary (architecture section 10.6). When the user returns to the Conversation and the SSE stream re-opens, the Conversation will be in a paused state. The frontend must present the resume prompt when it opens any Conversation that is in a paused state, regardless of what caused the pause. Recovery is via this same endpoint — no special handling or separate endpoint is required for the Workspace-switch case.

This endpoint is only for pauses that use the `pause_requested` flag. It is not used for `turn_cap` or `repetition_detected` recovery — those are recovered via `POST /conversations/{id}/messages`.

---

### Cancel the P2P Exchange

**What the frontend needs to do**: End the autonomous P2P exchange and return to idle state. Messages produced so far are preserved.

**Data involved**: No body required.

**Expected behaviour**: The backend transitions the graph to idle. The `idle` event arrives on the SSE stream. The frontend re-enables controls.

**Notes**: This is `POST /conversations/{id}/cancel`.

---

## Pagination and Filtering

### Conversation Message Pagination

**What the frontend needs to do**: Load messages in pages as the user scrolls up through a long Conversation history.

**Expected approach**: Cursor-based pagination. The frontend sends a `before` cursor (the ID of the oldest message currently loaded) and a `limit`. The backend returns the N messages older than the cursor, plus a `has_more` boolean and the next cursor.

**Notes**: The frontend renders messages in ascending order (oldest at top). It loads the most recent page first, then fetches older pages as the user scrolls up. The cursor must be stable across requests — using message ID (UUID v7, time-ordered) as the cursor is strongly preferred over offset-based pagination, which is unreliable when new messages arrive concurrently.

---

### Documents List (No Pagination Required in V1)

The Documents list is not paginated in V1. The number of Reports per Workspace is expected to remain manageable. If the backend implements optional pagination, the frontend will use it, but it is not required.

---

### Findings List (No Pagination Required in V1)

The findings list per Persona is not paginated in V1.

---

### Filtering: Documents by Source Conversation

As noted in the Documents section, the frontend needs to retrieve all Documents for a specific `source_conversation_id`. This must be available as a query filter on the Documents list endpoint.

---

## Real-Time Considerations

### One SSE Stream Per Open Conversation

The frontend holds one SSE stream per open Conversation. In normal usage this is one stream (the user has one Conversation open at a time). In theory the user could open multiple browser tabs, each with a different Conversation — the backend must support concurrent streams.

### Stream Lifecycle

- **Open**: When the user navigates to a Conversation view.
- **Close**: When the user navigates away from a Conversation view, or closes the tab.
- **Reconnect**: `@microsoft/fetch-event-source` handles reconnection automatically using `Last-Event-ID`. The backend must assign monotonically increasing event IDs per Conversation stream so reconnection can resume from the correct position.

### Mentor Session-End Signal

The Mentor Conversation's stream close is a semantically meaningful event (it triggers Working → Episodic compression if a session end is inferred). The frontend will attempt to send a session-end signal on page unload using the browser `pagehide` event and a `fetch` with `keepalive: true`. Whether the backend requires this explicit signal or can infer session end from stream disconnection is a backend design decision that must be specified in the contract.

### Review Agent Findings: No Real-Time Update

The findings list is not updated in real time. The frontend refreshes it on page load only. The backend does not need to push finding updates via SSE.

---

## Flagged Concerns

### FC-1: Auto-Summary Delivery Mechanism

The end-of-conversation auto-summary generation (US-L2) requires several seconds of model processing. The architecture does not specify whether this is synchronous (endpoint blocks until complete) or asynchronous (returns immediately with a pending state). The frontend needs a clear decision in the contract. Synchronous is preferred for V1 simplicity, but the endpoint must return the completed summary or an explicit error — the frontend cannot display the end-of-conversation flow until the summary is available.

---

### FC-2: Mentor Conversation Discovery

The architecture does not specify a dedicated endpoint for the Mentor Conversation. The frontend needs a reliable way to load the Mentor Conversation without scanning the full Conversation list. A dedicated `GET /workspaces/{id}/mentor-conversation` endpoint (or equivalent) is strongly preferred. If the backend instead returns a `is_mentor_conversation: true` flag on Conversation records, the frontend will use the Conversation list endpoint with a filter, but this requires the Conversation list to be loaded before the Mentor slot can be activated.

---

### FC-3: Report Generation Delivery Mechanism

Similar to FC-1: Report generation (US-R1) may take several seconds. Synchronous is preferred. If asynchronous, the frontend needs a defined way to receive the completed Report (SSE event or polling endpoint). The contract must specify this.

---

### FC-4: Chapter Marker Message Differentiation

The frontend needs to render chapter marker system messages differently from other system messages (Persona join/leave events). The contract must define how the frontend distinguishes a chapter boundary message from other system messages — whether by a dedicated `message_subtype` field, a conventional `content` prefix, or another mechanism.

**Developer preference (FC-4)**: A `message_subtype` field is preferred (e.g. `message_subtype: "chapter_boundary" | "persona_joined" | "persona_left" | "mode_changed"`) as it is extensible and avoids content parsing. The Senior Developer (Backend) may override this if there is a technical reason to prefer a different approach.

---

### FC-5: Mentor Session-End Signal Protocol

The architecture references both stream disconnection detection and a `pagehide` beacon as potential session-end signals for triggering Episodic → Semantic promotion (architecture section 8.3). The exact protocol must be specified in the contract: does the frontend need to send an explicit `POST` on session end, or is stream disconnection sufficient? This affects what the frontend implements on page unload.

**Developer decision (FC-5)**: Episodic → Semantic promotion runs on a scheduled overnight job only (same pattern as the Review Agent), not on session end. The frontend sends no session-end signal. The backend does not need to detect stream disconnection for this purpose. FC-5 is resolved — no frontend action required.

---

### FC-6: Persona Test Session Streaming Mechanism

The architecture specifies `ModelGateway.stream` for the Test panel. The frontend assumes SSE is used for consistency with Conversation streaming. If the backend uses a different mechanism (e.g. chunked HTTP response), the frontend needs advance notice to use a different client implementation.

**Developer preference (FC-6)**: SSE is preferred — the frontend already has `@microsoft/fetch-event-source` set up and the Test panel can reuse the same client code path as Conversations. The Senior Developer (Backend) may override this if there is a technical reason to prefer a different approach, but must confirm the mechanism in the contract so the frontend can implement accordingly.

---

### FC-7: Review Agent Finding Schema

The architecture explicitly defers the `review_agent_findings` table field details to the Senior Developer (Backend). The frontend requires at minimum: `id`, `persona_id`, evidence text, suggestion text, and `status` (enum: `active | stale | actioned | dismissed`). The contract must define these fields before implementation.

**Developer decision (FC-7)**: Left entirely to the Senior Developer (Backend). The minimum frontend requirements above are the only constraint.

---

### FC-8: Orchestrator Suggestion Accept/Dismiss Protocol

The frontend needs a specified endpoint for accepting or dismissing Orchestrator suggestions. Two patterns are possible: (a) separate `accept` and `dismiss` endpoints on the suggestion resource, or (b) the accept is implemented as a Persona addition (which the frontend already calls) and dismiss is a separate signal. The contract must clarify whether a dedicated suggestion resource with a `suggestion_id` is required, or whether the frontend manages suggestion state purely client-side and only calls the Persona addition endpoint on accept.

**Developer decision (FC-8)**: Option A — server-side tracking with `suggestion_id`. The `suggestion_id` is already included in the `orchestrator_suggestion` SSE event payload. The backend must provide dedicated accept and dismiss endpoints. Dismissals should be persisted so the Orchestrator can suppress repeated suggestions in future evaluations — the exact suppression mechanism is left to the Senior Developer (Backend) to design, but the data must be captured to keep this option open.
