# Cursor Review: `docs/system_document.md`

## Scope
This review checks `docs/system_document.md` for correctness/consistency/ambiguity, after consulting:
- `overview.md`
- `docs/archive/open_questions.md`
- `docs/archive/open_questions_v2.md`
- `backend_tech.md`

## Doc boundary mismatch (high-level vs implementation)
`docs/system_document.md` is meant to be high level, but it still contains an implementation-oriented section (`## 7. Implementation Details`). Implementation detail should live in `docs/architecture_reference.md` (and then be used by the architecture author).

## Status-claim inconsistency (correctness)
The document states `FINAL - No ambiguities` and `No questions remaining`, but there are still open architecture-level areas that are not fully specified. This conflicts with the status language and should be corrected.

## Open items still needed for the architecture document
1. Multi-agent conversation execution protocol
   - exact turn-taking/iteration and how multiple agent outputs are merged into conversation state
   - triggers/logic for gap-flagging (what constitutes "missing viewpoints") and when summaries are generated during an active conversation
2. Terminology/object-model reconciliation for architecture
   - consistent definitions and mappings for persona labels vs agent instances vs the team-specific mentor component
3. Safety/security and prompt-injection/data leakage guardrails
   - input/output filtering strategy, prompt injection resilience, and handling of sensitive data in logs/artifacts
4. Operational mechanics for nightly jobs and retention
   - scheduling mechanism (cron vs worker), idempotency/deduping, retries/failure handling, and partial-write behavior
5. Observability/tracing/audit logging
   - which events are logged (conversation runs, hand-offs, nightly jobs), and how correlation ids/audits are propagated end-to-end
6. LLM engineering integration details
   - model/version tracking for reproducibility, timeouts and concurrency/queueing strategy, and routing/versioning across mentor/agents/review/report flows

## Notes for the architect
Many items are already decided (auth v1 behavior, report template structure/versioning, mentor memory lifecycle, review rubric/finding lifecycle, accept/dismiss semantics, retention windows). Those decisions should be referenced from `docs/architecture_reference.md` rather than re-listed as open questions here.
