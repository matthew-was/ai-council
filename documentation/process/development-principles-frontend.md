# Development Principles — Frontend

Frontend-specific principles for `apps/frontend/`. Read this file alongside `development-principles.md` for every frontend task.

This file is populated as principles are identified and approved through the Principles Guardian workflow. The structure below shows the expected categories based on the confirmed tech stack. Content is added after the architecture phase confirms the frontend technology choices.

---

## How Principles Are Added

Principles are proposed by the Principles Guardian after every 5 completed frontend tasks. The developer approves or rejects each proposal. Approved principles are added here.

Do not restate universal principles from `development-principles.md` — reference them if needed.

---

## Framework and Rendering

*(To be populated after architecture phase confirms frontend framework)*

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

*(To be populated after architecture phase confirms testing tools)*

---

## Security at the Frontend Boundary

*(To be populated)*

---

## What These Principles Rule Out (Frontend-Specific)

*This section is populated as anti-patterns are identified through the Principles Guardian workflow.*

| Anti-pattern | Why prohibited | Principle violated |
| --- | --- | --- |
| Direct database connections from frontend components | All data access must go via the backend API | Infrastructure as Configuration / Clear Boundaries |
