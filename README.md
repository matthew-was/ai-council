# AI Council

## 🎯 Project Overview

AI Council is a self-hosted system for institutional knowledge with specialized personas. It enables users to simulate conversations with diverse perspectives to validate ideas before real meetings.

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.9+
- PostgreSQL
- Ollama with Mistral 7B model

### Installation

```bash
# Clone the repository
git clone https://github.com/your-repo/ai-council.git
cd ai-council

# Set up environment
docker-compose up -d

# Install Python dependencies
pip install -r requirements.txt
```

## 📁 Project Structure

```text
.
├── backend/                    # FastAPI backend
├── frontend/                   # Streamlit UI
├── docs/                       # Documentation
├── tests/                      # Test suite
├── .vibe/                      # Development automation tools
├── docker-compose.yml          # Container configuration
└── README.md                   # This file
```

## 🎯 Core Features

### Persona-Based Guidance
- Simulate conversations with specialized roles (Vision Keeper, Technical Mentor, Business Strategist, etc.)
- Test assumptions with diverse perspectives
- Identify risks and opportunities early

### Threaded Conversations
- Organize discussions into folders
- Manage multiple conversation threads
- Context-aware interactions

### Context Optimization
- Automatic summarization when context exceeds token limits
- User-requested targeted summarization
- Chunking of older messages
- Copy summaries as Markdown for reuse

### Continuous Improvement
- Post-session reviews by Review Agent
- Agent performance optimization
- Instruction refinement based on conversation analysis

## 📊 System Architecture

### Core Components
- **AI Model**: Mistral 7B (Ollama) - Backend LLM for persona interactions
- **Backend**: FastAPI + LangGraph - Orchestrate services and manage context
- **Database**: PostgreSQL - Store conversations, folders, summaries, and reports
- **UI**: Streamlit - User interface for persona interactions
- **Reports**: Markdown files - Saved persona-generated reports

### Key Workflows
1. **Conversation Management**: Create, organize, and end conversations
2. **Agent Orchestration**: Dynamic agent involvement based on conversation context
3. **Context Handling**: Automatic summarization and chunking
4. **Review Process**: Post-session analysis and agent optimization

## 🧪 Testing

```bash
# Run backend tests
cd backend
pytest tests/

# Run frontend tests  
cd frontend
pytest tests/
```

## 📖 Usage

### Starting a Conversation
1. Navigate to Conversations/Folders page
2. Click "New Conversation"
3. Enter your query
4. Select personas to involve

### Managing Agents
1. Go to Personas/Agents page
2. Create new agents with roles and instructions
3. Add agents to conversations as needed

### Ending a Conversation
1. Click "End conversation"
2. Review auto-generated summary
3. Optionally create detailed report

## 🔧 Development

### Backend Development

```bash
cd backend
uvicorn main:app --reload
```

### Frontend Development

```bash
cd frontend
streamlit run app.py
```

## 📚 Documentation

- [System Overview](overview.md) - Detailed system design and architecture
- [User Journeys](overview.md#user-journeys) - Complete user workflows
- [Agent Roles](overview.md#agentpersona-management) - Persona definitions and purposes

## 🎯 Project Status

- ✅ Core conversation system implemented
- ✅ Basic persona management complete
- ✅ Context optimization framework in place
- ⏳ Advanced agent orchestration in development
- ⏳ Review agent system being implemented

---

**AI Council** © 2026 | All rights reserved

*Self-hosted institutional knowledge system with specialized personas*
