# AI Council Project Rules

## Project Overview
Self-hosted multi-agent system for institutional knowledge using Mistral 7B, FastAPI, PostgreSQL, and Streamlit.

## Development Guidelines

### 1. Documentation Standards

**Markdown Formatting:**
- Use `.markdownlint.json` configuration for consistent linting
- Line length rule (MD013) is disabled for tables
- Emphasis-as-heading rule (MD036) is disabled for stylistic text
- Always run `markdownlint` before committing
- Tables should have proper pipe alignment

**Document Structure:**

```text
docs/
├── requirements.md          # Functional/non-functional requirements
├── architecture.md          # System architecture (to be created)
├── technical_spec.md        # Detailed technical design (to be created)
└── api_specification.md      # OpenAPI documentation (to be created)
```

### 2. Code Quality

**Python Standards:**
- Follow PEP 8 style guide
- Use type hints for function signatures
- Include docstrings for all public functions/classes
- Maximum line length: 100 characters (flexible for readability)

**Commit Standards:**
- Use conventional commit messages
- Reference issue numbers when applicable
- Keep commits atomic and focused
- Include relevant documentation updates
- **NEVER auto-commit** - Always ask user before committing changes
- **NEVER assume commit grouping** - Let user decide when/what to commit

### 3. Project Structure

```text
ai-council/
├── .vibe/                    # Vibe-specific configuration
│   └── rules.md              # This rules document
├── .markdownlint.json        # Markdown linting configuration
├── docs/                     # Project documentation
├── src/                      # Source code (to be created)
│   ├── backend/              # FastAPI backend
│   ├── frontend/             # Streamlit UI
│   └── database/             # Database models
├── docker/                   # Docker configuration (to be created)
├── config/                   # Configuration files (to be created)
└── reports/                  # Generated reports (auto-created)
```

### 4. Workflow Rules

**Session Start:**
1. Read this rules document
2. Check git status for any changes
3. Review open issues/tasks
4. Run markdown linting on documentation

**Implementation Order:**
1. Documentation first (requirements → architecture → technical spec)
2. Database schema and models
3. Backend API endpoints
4. Frontend components
5. Integration and testing

**Code Reviews:**
- All major changes require review
- Documentation updates must accompany code changes
- Test coverage for new features
- Performance considerations for LLM interactions

### 5. Technology Stack

**Core Technologies:**
- **LLM**: Mistral 7B via Ollama
- **Backend**: FastAPI + Python 3.9+
- **Database**: PostgreSQL 14+
- **Frontend**: Streamlit
- **Containerization**: Docker + Docker Compose
- **Documentation**: Markdown with linting

**Development Tools:**
- Markdownlint for documentation
- Python type checking (mypy)
- Code formatting (black, isort)
- Git for version control

### 6. Naming Conventions

**Variables & Functions:**
- `snake_case` for variables and functions
- `CamelCase` for class names
- `UPPER_CASE` for constants
- Prefix boolean variables with `is_`, `has_`, `can_`

**Files & Directories:**
- `snake_case` for Python files
- `kebab-case` for directories
- Meaningful, descriptive names

**Database:**
- `snake_case` for table and column names
- Primary keys: `{table_name}_id`
- Foreign keys: `{referenced_table}_id`

### 7. Error Handling

**Best Practices:**
- Use specific exception types
- Include context in error messages
- Log errors with appropriate severity
- Provide user-friendly error messages
- Implement graceful degradation

**LLM-Specific:**
- Handle token limit exceptions
- Manage context overflow gracefully
- Provide fallback responses
- Log LLM performance metrics

### 8. Testing Strategy

**Test Types:**
- Unit tests for individual components
- Integration tests for API endpoints
- End-to-end tests for user flows
- Performance tests for LLM interactions
- Documentation tests for examples

**Coverage Goals:**
- 80%+ unit test coverage
- Critical paths: 100% coverage
- Edge cases documented

### 9. Security Considerations

**Data Protection:**
- User data isolation
- Secure authentication
- Input validation
- SQL injection prevention
- Rate limiting for API endpoints

**LLM Security:**
- Prompt injection protection
- Content filtering
- Usage monitoring
- Access controls

### 10. Performance Guidelines

**Optimization Targets:**
- Response time: <5s for 90% of requests
- Context summarization: <2s
- Database queries: <100ms
- Memory usage: Monitor for leaks

**LLM-Specific:**
- Context window management
- Efficient token usage
- Caching frequent responses
- Batch processing where possible

## Session Checklist

**Starting Work:**
- [ ] Read `.vibe/rules.md`
- [ ] Check git status
- [ ] Review open tasks
- [ ] Run `markdownlint .`
- [ ] Update documentation as needed

**Ending Work:**
- [ ] Run all tests
- [ ] Run markdown linting
- [ ] Commit changes with clear message
- [ ] Update task status
- [ ] Document any blocking issues

## Decision Log

**Key Decisions Made:**
- 2024-03-14: Disabled MD013 (line length) for tables
- 2024-03-14: Disabled MD036 (emphasis-as-heading) for stylistic text
- 2024-03-14: Fixed glossary table formatting in overview.md

**Open Questions:**
- Authentication strategy (basic vs advanced)
- Exact token limits and chunking parameters
- Backup frequency and retention policy

## Maintenance

**Update This Document When:**
- New technologies are adopted
- Coding standards change
- Workflow processes evolve
- New team members join
- Lessons learned from production

**Review Frequency:** Monthly or as needed
