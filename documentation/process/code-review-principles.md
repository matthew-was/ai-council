# Code Review Principles

Numbered principles for the Code Reviewer agent. Each principle has a CR-number so it can be referenced in review files and tracked over time. The Code Reviewer reads this document at the start of every session.

Principles are proposed by the Principles Guardian after every 5 completed tasks per service, based on patterns observed across post-completion-review files. The developer approves or rejects each proposal.

---

## How to Add a New Principle

When the Principles Guardian proposes a new principle, use this format:

```markdown
## CR-NNN — [Short title]

**Principle**: [What the rule is — stated generically enough to cover most edge cases]

**Why**: [The reason this principle exists — the problem it prevents]

**How to apply**:

- [Specific check to perform]
- If [condition]: **blocking** finding — [what must change]
- If [condition]: **Suggestion** — [recommended improvement]
```

Number principles sequentially from CR-001. Do not reuse numbers. If a principle is superseded, mark it as `[Superseded by CR-NNN]` rather than deleting it — the history is useful.

Cross-reference universal principles from `development-principles.md` rather than restating them here. Use the form: "See `development-principles.md` §[Section]."

---

## Principles

*No principles have been recorded yet. Principles are added here as patterns emerge from completed tasks via the Principles Guardian workflow.*

---

## Superseded Principles

*None yet.*
