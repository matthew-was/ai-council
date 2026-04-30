# Backend Task List — Self-Review

**Reviewed**: 2026-04-29
**Task list path**: `documentation/tasks/backend-tasks.md`
**Plan source**: `documentation/tasks/senior-developer-backend-plan.md`

---

## Completeness

Every major section of the plan is covered:

| Plan section | Task(s) |
| --- | --- |
| 1. Project Structure | B-001 |
| 2. Initial Alembic Migration | B-002 |
| 3. SQLAlchemy Models | B-003 |
| 4. FastAPI App Factory / Composition Root | B-007 |
| 4.6 results.py / errors.py | B-005 |
| 5. ModelGateway | B-006 |
| 6. ConversationOrchestrator | B-010 |
| 7. Context Window Management | B-011 |
| 8.1–8.3 Mentor Memory (Retriever + Promoter) | B-012 |
| 8.4 Conversation Observer | B-013 |
| 8.5–8.6 Chapter detection / Mentor SSE ID format | B-018, B-014 |
| 9. Review Agent | B-015 |
| 9.0 Conversation Observer wiring | B-013 |
| 9.1 APScheduler wiring | B-016 |
| 10. SSE Streaming | B-009, B-014 |
| 11.1 Workspaces router | B-017 |
| 11.2–11.3 Personas router | B-017 |
| 11.4–11.6 Conversations router | B-018 |
| 11.7 Messages router | B-019 |
| 11.8 Folders router | B-019 |
| 11.9 Documents router | B-019 |
| 11.10 Review Agent router | B-020 |
| 11.11 Mentor Memory Inspector router | B-020 |
| 11.12 Control signals router | B-021 |
| 11.13 Orchestrator suggestion responses | B-018 |
| 11.14 Conversation export | B-018 |
| 12. Configuration | B-001, B-007 |
| 13. Background job harnesses | B-016 |
| 13.2 update_system_prompt helper | B-005 |
| 14. Testing strategy | B-004, B-006, B-010, B-011, B-012, B-013, B-015, B-017, B-018, B-019, B-020, B-021 |

All plan sections have at least one corresponding task. No plan section is unaccounted for.

---

## Consistency

**Dependency field accuracy check:**

| Task | Declared dependencies | Verified |
| --- | --- | --- |
| B-001 | none | Correct — first task |
| B-002 | B-001 | Correct — needs pyproject and constants |
| B-003 | B-002 | Correct — needs migration to match |
| B-004 | B-003 | Correct — fakes need models to exist |
| B-005 | B-003 | Correct — helpers reference model classes |
| B-006 | B-005 | Correct — uses `Ok`/`Err` result types |
| B-007 | B-006 | Correct — composition root builds ModelGateway |
| B-008 | B-005 | Correct — schemas use no services, just Pydantic |
| B-009 | B-007 | Correct — SseManager wired into app startup |
| B-010 | B-009 | Correct — graph publishes to SseManager |
| B-011 | B-010 | Correct — ContextAssembler calls MentorMemoryRetriever (stub acceptable at this stage); RollingSummary calls into the graph context |
| B-012 | B-011 | Correct — MentorPromoter triggered from RollingSummary.compress() |
| B-013 | B-012 | Correct — ConversationObserver uses MentorPromoter infrastructure |
| B-014 | B-010, B-009 | Correct — stream endpoint uses graph and SSE manager |
| B-015 | B-005, B-006 | Correct — runner uses result types and ModelGateway |
| B-016 | B-015, B-013, B-007 | Correct — wires all three into lifespan |
| B-017 | B-008, B-007, B-013 | Correct — routers need schemas, app factory, and observer task for backfill |
| B-018 | B-008, B-007, B-012, B-013 | Correct — conversations needs MentorPromoter for chapter and Observer for end |
| B-019 | B-008, B-007, B-010 | Correct — messages router uses orchestrator for busy check |
| B-020 | B-008, B-007, B-015, B-012 | Correct — Review Agent and Mentor routers need runner and promoter |
| B-021 | B-018, B-019, B-010 | Correct — control signals are post-conversation and message routers |
| B-022 | B-021, B-020, B-017 | Correct — smoke test needs all routers registered |

All task numbers in dependency fields match actual task IDs. All statuses are `not_started`.

---

## Ambiguity

Reviewed each task description for whether the Implementer could begin work without reading the full plan. Findings:

- **B-010 (ConversationOrchestrator)** is the most complex task (L). The description references the full graph edge structure from Section 6.3 and multiple sub-sections. The task includes direct plan section references so the Implementer knows exactly where to look. This is acceptable given the inherent complexity of LangGraph graph implementation — no further splitting is warranted as the graph must be built as a unit.

- **B-017 (Workspaces and Personas routers)** is also L complexity. The description is intentionally detailed to make it self-contained. The Implementer should be able to build this without re-reading the plan from scratch.

- **B-018 (Conversations router)** is L and dense. It covers multiple plan sections (11.4, 11.5, 11.6, 11.13, 11.14). This consolidation is justified because all these handlers share state (conversation row, participant list, idle checks) and splitting them would require partial router file creation — which is harder to implement than a single focused session on one router.

- No task description contains subjective judgement in its acceptance condition. All conditions are specific and runnable.

---

## Ordering

The dependency chain from the graph perspective:

```text
B-001 → B-002 → B-003 → B-004 (parallel with B-005)
                         B-005 → B-006 → B-007 → B-009 → B-010 → B-011 → B-012 → B-013
                         B-005 → B-008
                         B-007 → B-014 (needs B-010 also)
                         B-005 → B-015 → B-016 (needs B-013, B-007 also)
                         B-007, B-008, B-013 → B-017
                         B-007, B-008, B-012, B-013 → B-018 → B-021
                         B-007, B-008, B-010 → B-019 → B-021
                         B-007, B-008, B-015, B-012 → B-020
                         B-017, B-020, B-021 → B-022
```

No circular dependencies. B-001 has no dependencies and can be started immediately. The critical path is:

`B-001 → B-002 → B-003 → B-005 → B-006 → B-007 → B-009 → B-010 → B-011 → B-012 → B-013 → B-018 → B-021 → B-022`

The first blocking task is B-001. The Implementer can begin immediately.

---

## One potential concern noted

**B-011 depends on B-010**: `ContextAssembler` calls `MentorMemoryRetriever.load_context()` (from B-012, which follows B-011). This creates an apparent circular tension: B-011 is ordered before B-012, but B-011's assembler calls into B-012's retriever.

Resolution: `ContextAssembler` depends on the `MentorMemoryRetriever` interface (an ABC), not the concrete implementation. The ABC is defined in B-012's `retriever.py`. The dependency ordering is therefore:
- B-011 can implement `ContextAssembler` with the `MentorMemoryRetriever` ABC as a type annotation (passed as constructor argument)
- B-012 provides the concrete `AllEntriesRetriever` implementation
- This is standard dependency inversion — no circular dependency in implementation order

This is correctly handled. No flagged issue needed — the ABC pattern means B-011 can be implemented first with the concrete retriever passed in by the composition root (B-007, updated in B-016).

---

## Conclusion

The task list is complete, consistent, unambiguous, and correctly ordered. All 22 tasks are ready for developer review and approval.
