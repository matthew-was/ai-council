---
name: workflow_skill
description: Coordinates automated workflows for document changes, approvals, and propagations within the AI Council system.
metadata:
  version: "1.0.0"
  author: ai-council
  license: MIT
  created: 2026-03-19
  updated: 2026-03-19
  category: workflow-automation
  compatibility:
    - automated_workflows
    - impact_assessment
    - approval_coordination
    - change_propagation
    - version_updates
    - workflow_monitor
---

# Workflow Automation Skill

## Purpose

Coordinates and automates workflow processes for document changes, approvals, and propagations within the AI Council system. This skill provides the core workflow automation capabilities that integrate with the skills registry and other system components.

## Capabilities

- **Impact Assessment** - Automated risk analysis for document changes
- **Approval Coordination** - Manage approval workflows with status tracking
- **Change Propagation** - Execute and verify change propagation
- **Version Management** - Semantic version updates and tracking
- **Workflow Monitoring** - Track and report workflow execution status

## When to Use

- When you need to assess the impact of document changes
- When coordinating approval processes for changes
- When propagating approved changes across the system
- When managing document versions and updates
- When monitoring workflow execution and health

## Safety Features

- Requires explicit approval for all changes
- Provides comprehensive impact assessment before changes
- Validates all changes before propagation
- Maintains complete audit trails
- Provides rollback capabilities

## Usage

### Impact Assessment

```bash
# Assess impact of a proposed change
.vibe/skills/workflow_skill/scripts/impact_assessment.sh docs/SYSTEM.md "Update architecture"
```

### Approval Coordination

```bash
# Create approval request
.vibe/skills/workflow_skill/scripts/approval_coordination.sh create CR-001 docs/SYSTEM.md "Update architecture" reviewer

# Approve request
.vibe/skills/workflow_skill/scripts/approval_coordination.sh approve CR-001
```

### Change Propagation

```bash
# Propagate approved changes
.vibe/skills/workflow_skill/scripts/change_propagation.sh propagate CR-001 docs/SYSTEM.md
```

### Version Updates

```bash
# Bump version
.vibe/skills/workflow_skill/scripts/version_updates.sh bump docs/SYSTEM.md patch
```

### Workflow Monitoring

```bash
# Monitor workflow status
.vibe/skills/workflow_skill/scripts/workflow_monitor.sh status
```

## Integration

Integrates with:
- **Skills Registry** - `.vibe/skills/skills.json` for skill management
- **Documentation** - `docs/` for system documentation
- **CI/CD Workflows** - `.github/workflows/` for automated execution
- **Monitoring System** - `.vibe/monitoring/` for system health tracking

## Dependencies

- **jq** - JSON processing
- **bash** - Script execution
- **git** - Version control
- **date** - Timestamp generation

## Status

- **Operational**: ✅ Fully functional
- **Tested**: ✅ All tests passing
- **Documented**: ✅ Complete documentation
- **Maintained**: ✅ Actively maintained

## Metadata

- **Skill Type**: Workflow Automation
- **Category**: Core System
- **Priority**: High
- **Stability**: Stable
- **Support**: Full

---

*Workflow Automation Skill v1.0.0 | AI Council Automation System*
