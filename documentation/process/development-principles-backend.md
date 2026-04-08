# Development Principles — Backend

Backend-specific principles for `apps/backend/`. Read this file alongside `development-principles.md` for every backend task.

This file is populated as principles are identified and approved through the Principles Guardian workflow. The structure below shows the expected categories based on the confirmed tech stack. Content is added after the architecture phase confirms the backend technology choices.

---

## How Principles Are Added

Principles are proposed by the Principles Guardian after every 5 completed backend tasks. The developer approves or rejects each proposal. Approved principles are added here.

Do not restate universal principles from `development-principles.md` — reference them if needed.

---

## API Design

*(To be populated after architecture phase confirms API approach)*

The backend produces an OpenAPI spec as a build artefact that must match the approved API contract document (`documentation/tasks/api-contract.md`). The Code Reviewer validates the generated spec against the contract.

---

## Data Access and Database

*(To be populated)*

---

## Service and Repository Patterns

*(To be populated)*

---

## Dependency Injection

*(To be populated — see `.claude/skills/dependency-composition-pattern.md`)*

---

## Backend Testing Strategy

*(To be populated after architecture phase confirms testing tools)*

---

## Configuration

*(To be populated — see `.claude/skills/configuration-patterns.md`)*

---

## Security at the Backend Boundary

*(To be populated)*

---

## What These Principles Rule Out (Backend-Specific)

*This section is populated as anti-patterns are identified through the Principles Guardian workflow.*

| Anti-pattern | Why prohibited | Principle violated |
| --- | --- | --- |
| Ad-hoc SQL queries outside defined data access patterns | Creates brittle coupling to the schema; bypasses transaction boundaries | Clear Boundaries |
| Hardcoded AI model names or endpoint URLs | Prevents swapping the AI model via configuration | Infrastructure as Configuration |
