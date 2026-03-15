#!/bin/bash
# Architecture Diagram Generator
# Creates simple architecture diagrams

echo "🏗️  Generating architecture diagram..."

# Simple ASCII architecture diagram
cat > architecture_diagram.txt << 'EOF'
AI COUNCIL ARCHITECTURE
=======================

┌───────────────────────────────────────────────────────┐
│                    AI Council System                  │
├─────────────────┬─────────────────┬───────────────────┤
│   Frontend     │    Backend      │     Database      │
│  (Streamlit)    │   (FastAPI)     │   (PostgreSQL)    │
└─────────┬───────┴─────────┬───────┴───────┬───────────┘
          │                 │               │
          ▼                 ▼               ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│  User Interface  │ │   API Endpoints  │ │  Data Storage    │
└─────────────────┘ └─────────────────┘ └─────────────────┘
       ▲                 ▲               ▲
       │                 │               │
┌──────┴───────┐ ┌─────────┴───────┐ ┌─────┴───────┐
│   Agents     │ │  Context Mgmt   │ │  Reports     │
│ (7 types)    │ │ (Summarization) │ │ (Markdown)   │
└──────────────┘ └─────────────────┘ └─────────────┘

KEY COMPONENTS:
- Frontend: Streamlit UI with skill interfaces
- Backend: FastAPI with skill orchestration
- Database: PostgreSQL for conversations/threads
- Agents: 7 specialized AI skills
- Context: Automatic summarization and chunking
- Reports: Markdown-based report generation

DATA FLOW:
User → Frontend → Backend → Agents → Database
       ↑               ↑               ↑
       └───────────────┘               │
               Reports ←──────────────┘
EOF

echo "✅ Architecture diagram created: architecture_diagram.txt"
cat architecture_diagram.txt
exit 0