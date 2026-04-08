# Development Principles

## Why This Document Exists

These principles are established as patterns emerge during design and implementation. They represent hard-won knowledge from code reviews, task completions, and architectural decisions. Changes to existing principles require justification — they are not casual style preferences.

## How to Use This File Family

This file (`development-principles.md`) contains **universal principles** that apply across all services. Agents and implementers must read this file for every task, regardless of service.

Service-specific principles are in separate files. Read the file for the service you are working on:

- Frontend (`apps/frontend/`): `development-principles-frontend.md`
- Backend (`apps/backend/`): `development-principles-backend.md`

Both this file and the relevant service-specific file are the source of truth. Agent definitions reference this file — they do not restate its content.

## How Principles Are Added

Principles are proposed by the Principles Guardian after every 5 completed tasks per service, based on patterns observed in post-completion-review files. The developer approves or rejects each proposal. Approved principles are added here by the Principles Guardian.

When adding a new principle:

1. Decide whether it is universal (all services) or service-specific
2. Add it to the appropriate file, in the most relevant section, at the right level of generality
3. If it is an instance of a more general pattern already documented here, extend that section rather than adding a new one
4. In `code-review-principles.md`, add only a cross-reference — do not restate the rule
5. In agent definitions, do not add the pattern — the reading list already includes these files

**Avoid**:

- Adding the same rule to multiple files (duplication causes drift)
- Over-specifying (prefer generic principles that catch most edge cases over narrow rules that get worked around)
- Adding a new section when the pattern belongs in an existing one

---

## Core Architectural Principle: Infrastructure as Configuration

Every external service must be accessed through an abstraction interface. The concrete implementation is determined by configuration at runtime, not hardcoded in application logic.

**What this means in practice**:

Application code calls an interface. Configuration determines which implementation loads. The application code never changes between environments — only the configuration changes.

**Why this matters for AI Council**: The AI model integration must be swappable between a locally-hosted LLM and a cloud API without changes to application code. This is a first-class architectural constraint, not a future consideration.

**Implementation approach**:

- Well-defined interfaces + factory pattern or dependency injection
- Runtime selection via environment variables or config files
- Never branch on environment name (e.g. `if (NODE_ENV === 'production')`)

See `.claude/skills/configuration-patterns.md` for implementation patterns (populated after architecture phase).

---

## AI Development Philosophy

### Human-in-the-Loop

Agents analyse, synthesise, and present options. The developer makes all final decisions. This applies to:

- Architecture (Head of Development presents options; developer decides)
- Code quality (Code Reviewer flags issues; developer resolves)
- Scope (Product Owner flags ambiguities; developer resolves)

Agents are informed participants, not autonomous decision-makers for ambiguous questions.

### Clarity Over Speed

The project will be paused and resumed many times. Clear documentation, defined agent roles, and explicit decision records are more valuable than fast implementation. A well-documented incomplete system is better than a working undocumented one.

### Clear Boundaries Prevent Rework

Explicit component boundaries and data contracts defined before implementation prevent integration surprises. The API contract document (owned by the Senior Developer Backend) enforces this at the service boundary. Each implementation plan defines its input and output contracts.

### Document During Build

Documentation written as decisions are made, not after. Architecture decisions recorded in `documentation/decisions/architecture-decisions.md`. Unresolved questions tracked before they become assumptions embedded in code.

---

## Software Development Principles

*This section is populated as principles are identified and approved through the Principles Guardian workflow. The structure below shows the expected categories.*

### Type Safety

*(To be populated)*

### Error Handling

*(To be populated)*

### Configuration

*(To be populated)*

### Testing

*(To be populated)*

### Security at Boundaries

*(To be populated)*

---

## What These Principles Rule Out (Universal)

*This section is populated as anti-patterns are identified and approved through the Principles Guardian workflow.*

| Anti-pattern | Why prohibited | Principle violated |
| --- | --- | --- |
| Code branching on environment name | Prevents seamless migration; different code paths in different environments | Infrastructure as Configuration |
| Hardcoded provider names, model names, or API endpoints | Prevents runtime swapping of AI model or other services | Infrastructure as Configuration |
| Secrets or sensitive data in logs | Security boundary violation | Security at Boundaries |
