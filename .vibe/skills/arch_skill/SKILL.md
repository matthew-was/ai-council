---
name: arch-skill
description: Generates and validates architecture diagrams. Creates ASCII-based architecture diagrams showing system components and their relationships. Use when you need to visualize system architecture, validate component relationships, or document technical design.
license: MIT
metadata:
  author: ai-council
  version: "1.0"
---

# Architecture Skill

## Purpose
This skill generates ASCII-based architecture diagrams to visualize system components and their relationships.

## When to Use
- When documenting system architecture
- During architecture design phase
- When validating component relationships
- To create visual documentation for technical design
- When requested to generate architecture diagrams

## How It Works
1. Generates an ASCII diagram showing the AI Council system architecture
2. Includes frontend, backend, database, and agent components
3. Shows data flow between components
4. Outputs the diagram to architecture_diagram.txt
5. Displays the diagram in the console

## Requirements
- None (uses basic shell commands)

## Usage

```bash
.vibe/skills/arch_skill/scripts/generate_diagram.sh
```

## Output
- Creates architecture_diagram.txt file
- Displays ASCII architecture diagram in console
- Shows system components and their relationships
- Includes key components: Frontend, Backend, Database, Agents

## Diagram Components
- Frontend: Streamlit UI with skill interfaces
- Backend: FastAPI with skill orchestration
- Database: PostgreSQL for conversations/threads
- Agents: 7 specialized AI skills
- Context: Automatic summarization and chunking
- Reports: Markdown-based report generation

## Common Use Cases
- Architecture documentation
- Technical design reviews
- System component visualization
- Onboarding new developers
- Architecture validation
