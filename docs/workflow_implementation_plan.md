# AI Council: Project Workflow

## Executive Summary

This document defines the complete workflow for the AI Council project, from initial overview to production deployment. The workflow leverages specialized agents and skills to ensure quality, consistency, and user control at every stage.

## Project Overview

### System Components
- **Frontend:** Streamlit web interface
- **Backend:** FastAPI with LangChain orchestration
- **Database:** PostgreSQL for data persistence
- **LLM Integration:** Mistral 7B via Ollama
- **Deployment:** Docker containers with docker-compose

### Key Principles
- **User Control:** All decisions escalated to user
- **Quality Assurance:** Automated validation at each phase
- **Clear Separation:** Agents for orchestration, Skills for automation
- **Traceability:** Complete audit trail of decisions

## Current Workflow

```mermaid
graph LR
    A[Overview] --> B[system_doc_creator]
    B --> C[document_review_agent]
    C --> D[System Document]
    D --> E[architecture_creator]
    E --> F[document_review_agent]
    F --> G[Architecture Document]
    G --> H[arch_skill]
    H --> I[arch_task_generator]
    I --> J[document_review_agent]
    J --> K[Implementation Tasks]
    K --> L[Development]
    L --> M[Testing]
    M --> N[Deployment]
    N --> O[Production]
```

## Agent/Skill Inventory

### Agents (Complex Transformation)

| Component | Purpose | Workflow Phase | Complexity |
| --------- | ------- | -------------- | ---------- |
| system_doc_creator | User requirements → system specification | Overview → System Doc | High |
| architecture_creator | System requirements → technical architecture | System Doc → Architecture | High |
| arch_task_generator | Architecture → implementation tasks | Architecture → Tasks | High |
| deployment_validator | Deployment setup validation | Development → Deployment | Medium |
| db_migration_manager | Database migration management | Development | Medium |
| ci_cd_integrator | CI/CD pipeline management | All phases | High |
| backup_manager | Backup/restore operations | Production | Medium |
| security_auditor | Security scanning | All phases | High |
| dependency_analyzer | Dependency analysis | Development | High |

### Skills (Focused Automation)

| Component | Purpose | Workflow Phase | Complexity |
| --------- | ------- | -------------- | ---------- |
| doc_skill | Documentation validation | All phases | Low |
| code_skill | Code quality checks | Development | Low |
| test_skill | Testing and coverage | Testing | Low |
| arch_skill | Architecture validation | Architecture | Low |
| deployment_skill | Deployment validation | Deployment | Low |
| database_skill | Database management | Development | Low |
| security_skill | Security scanning | All phases | Low |
| performance_skill | Performance testing | Testing | Low |
| backup_skill | Backup operations | Production | Low |

## Quality Gates

1. **Overview Review** - Conceptual validation
2. **System Document** - document_review_agent validation
3. **System Approval** - User sign-off
4. **Architecture Creation** - architecture_creator quality
5. **Architecture Review** - document_review_agent validation
6. **Architecture Approval** - User sign-off
7. **Architecture Validation** - arch_skill compliance
8. **Task Generation** - arch_task_generator breakdown
9. **Task Review** - document_review_agent validation
10. **Task Approval** - User sign-off
11. **Code Quality** - Automated checks
12. **Security Review** - Vulnerability scanning
13. **Performance Review** - Performance testing
14. **Dependency Review** - Impact analysis
15. **Deployment Validation** - Environment readiness
16. **Production Sign-off** - Final approval

## Document Types

1. **Overview Document** - High-level concepts and goals
2. **System Document** - User requirements and workflows
3. **Architecture Document** - Technical design and components
4. **Implementation Tasks** - Development work breakdown
5. **Validation Reports** - Quality assurance outputs

## Future Roadmap

### Phase 1: Core Workflow (Complete ✅)
- system_doc_creator agent
- architecture_creator agent
- arch_task_generator agent
- document_review_agent integration

### Phase 2: Supporting Agents
- deployment_validator agent
- db_migration_manager agent
- ci_cd_integrator agent
- backup_manager agent
- security_auditor agent
- dependency_analyzer agent

### Phase 3: Implementation
- Backend API development
- Frontend UI components
- Database schema implementation
- Integration and testing

## Key Features

- **User-Centric:** All agents ask for confirmation
- **Quality-First:** Validation at every stage
- **Flexible:** Easy to adjust workflow
- **Traceable:** Complete decision documentation
- **Scalable:** Designed for project growth

## Getting Started

1. **Review Overview:** Ensure overview.md is complete
2. **Run Agents:** Execute agents in sequence
3. **Approve Outputs:** Sign off on each deliverable
4. **Implement:** Build from approved tasks
5. **Validate:** Test and deploy with confidence

## Maintenance

- **Agent Updates:** Enhance prompts as needed
- **Workflow Refinement:** Adjust based on feedback
- **Documentation:** Keep workflow plan current
- **Testing:** Validate changes thoroughly

---

*Last Updated: 2024-03-15*
*Status: Implementation Ready*
