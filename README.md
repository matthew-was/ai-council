# AI Council - Multi-Agent System

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose installed
- Python 3.13+ (for local development)

### 1. Clone the repository

```bash
git clone https://github.com/yourusername/ai-council.git
cd ai-council
```

### 2. Install development tools

```bash
pip install pylint black isort pytest pytest-cov
```

### 3. Start the services

```bash
docker-compose up --build
```

### 4. Access the applications
- **Frontend**: <http://localhost:8501>
- **Backend API**: <http://localhost:8000>
- **Backend Docs**: <http://localhost:8000/docs>
- **Database Admin**: <http://localhost:5050> (email: <admin@ai-council.com>, password: admin123)

## 📂 Project Structure

```text
ai-council/
├── backend/              # FastAPI backend service
│   ├── src/
│   │   ├── main.py       # Backend entry point
│   │   └── agents/       # AI agents (future implementation)
│   │       └── agent_template.md
│   ├── requirements.txt  # Backend dependencies
│   └── Dockerfile         # Backend build config
├── frontend/             # Streamlit UI service
│   ├── src/main.py        # Frontend entry point
│   ├── requirements.txt  # Frontend dependencies
│   └── Dockerfile         # Frontend build config
├── docker-compose.yml    # Service orchestration (4 services)
├── .vibe/                # Vibe development tools
│   └── skills/           # Development assistance skills
│       ├── arch_skill/   # Architecture validation
│       ├── code_skill/   # Code quality checks
│       ├── doc_skill/    # Documentation tools
│       ├── test_skill/   # Testing framework
│       ├── run.sh        # Master skill runner
│       └── skills.json   # Skill configuration
├── .gitignore            # Git ignore rules
├── .markdownlint.json    # Markdown linting config
├── docs/                 # Project documentation
│   └── requirements.md   # System requirements
├── overview.md           # Project overview
└── README.md              # This file
```

## 🧪 Development Workflow

### Run quality checks

```bash
# Run all skills
.vibe/skills/run.sh all

# Run specific checks
.vibe/skills/doc_skill/lint_docs.sh
.vibe/skills/code_skill/lint_code.sh
```

### Work with services

```bash
# Start specific service
cd backend && uvicorn src.main:app --reload
cd frontend && streamlit run src/main.py

# Rebuild containers
docker-compose build

# View logs
docker-compose logs -f
```

## 🔧 Configuration

### Environment Variables

**Backend** (in docker-compose.yml or .env):
- `DATABASE_URL`: PostgreSQL connection string
- `ENVIRONMENT`: development/production

**Frontend** (in docker-compose.yml or .env):
- `BACKEND_URL`: Backend API endpoint
- `ENVIRONMENT`: development/production

### Database
- **PostgreSQL**: Accessible on port 5432
- **pgAdmin**: <http://localhost:5050> (<admin@ai-council.com>/admin123)

## 📊 Services

| Service | Port | URL |
| ------- | ---- | --- |
| Frontend | 8501 | <http://localhost:8501> |
| Backend | 8000 | <http://localhost:8000> |
| Backend Docs | 8000 | <http://localhost:8000/docs> |
| PostgreSQL | 5432 | postgres://user:password@localhost:5432/ai_council |
| pgAdmin | 5050 | <http://localhost:5050> |

## 🎯 Roadmap

- [x] Basic backend API structure
- [x] Basic frontend UI structure
- [x] Docker Compose setup
- [x] Development agents configuration
- [ ] Database models and migrations
- [ ] Agent implementation
- [ ] Thread management
- [ ] User authentication
- [ ] Production deployment

## 🤝 Contributing

1. Run quality checks before committing
2. Update documentation as you go
3. Follow the existing code style
4. Write tests for new features

## 📄 License

MIT License - See LICENSE file for details.
