# Development Principles — Frontend

Frontend-specific principles for `apps/frontend/`. Read this file alongside `development-principles.md` for every frontend task.

This file is populated as principles are identified and approved through the Principles Guardian workflow. The confirmed tech stack is React 19, Vite, TanStack Router, SWR, Base UI + Tailwind, openapi-typescript, Vitest, MSW, and vitest-axe. Principles are added here as patterns emerge from completed tasks.

---

## How Principles Are Added

Principles are proposed by the Principles Guardian after every 5 completed frontend tasks. The developer approves or rejects each proposal. Approved principles are added here.

Do not restate universal principles from `development-principles.md` — reference them if needed.

---

## Framework and Rendering

*(To be populated)*

---

## State Management

*(To be populated)*

---

## Data Fetching and API Calls

*(To be populated)*

---

## Component Design

*(To be populated)*

---

## Frontend Testing Strategy

*(To be populated)*

---

## Security at the Frontend Boundary

*(To be populated)*

---

## What These Principles Rule Out (Frontend-Specific)

*This section is populated as anti-patterns are identified through the Principles Guardian workflow.*

| Anti-pattern | Why prohibited | Principle violated |
| --- | --- | --- |
| Direct database connections from frontend components | All data access must go via the backend API | Infrastructure as Configuration / Clear Boundaries |
