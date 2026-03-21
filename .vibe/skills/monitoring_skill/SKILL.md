---
name: monitoring_skill
description: Provides comprehensive monitoring and health tracking for the AI Council automation system.
metadata:
  version: "1.0.0"
  author: ai-council
  license: MIT
  created: 2026-03-19
  updated: 2026-03-19
  category: system-monitoring
  compatibility:
    - approval_monitor
    - document_health
    - propagation_tracker
    - version_alerts
---

# Monitoring Skill

## Purpose

Provides comprehensive monitoring, health tracking, and alerting capabilities for the AI Council automation system. This skill ensures system reliability, tracks workflow execution, and provides early warning for potential issues.

## Capabilities

- **Approval Monitoring** - Track approval workflow status and completion
- **Document Health** - Monitor documentation integrity and consistency
- **Propagation Tracking** - Track change propagation across system components
- **Version Alerts** - Monitor and alert on version changes and updates

## When to Use

- When you need to monitor approval workflow progress
- When tracking document health and consistency
- When monitoring change propagation status
- When you need alerts for version changes
- When ensuring overall system reliability

## Safety Features

- Non-invasive monitoring (read-only operations)
- Comprehensive logging and audit trails
- Early warning system for potential issues
- Integration with system health checks
- Configurable alert thresholds

## Usage

### Approval Monitoring

```bash
# Monitor approval status
.vibe/skills/monitoring_skill/scripts/approval_monitor.sh status

# Check specific approval request
.vibe/skills/monitoring_skill/scripts/approval_monitor.sh check CR-001
```

### Document Health

```bash
# Check document health
.vibe/skills/monitoring_skill/scripts/document_health.sh check docs/

# Validate documentation consistency
.vibe/skills/monitoring_skill/scripts/document_health.sh validate docs/SYSTEM.md
```

### Propagation Tracking

```bash
# Track propagation status
.vibe/skills/monitoring_skill/scripts/propagation_tracker.sh status

# Check specific propagation
.vibe/skills/monitoring_skill/scripts/propagation_tracker.sh check CR-001
```

### Version Alerts

```bash
# Check for version changes
.vibe/skills/monitoring_skill/scripts/version_alerts.sh check

# Monitor specific document versions
.vibe/skills/monitoring_skill/scripts/version_alerts.sh monitor docs/SYSTEM.md
```

## Integration

Integrates with:
- **Skills Registry** - `.vibe/skills/skills.json` for skill management
- **Workflow System** - `.vibe/skills/workflow_skill/` for workflow coordination
- **Documentation** - `docs/` for system documentation
- **CI/CD Workflows** - `.github/workflows/` for automated monitoring

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

- **Skill Type**: System Monitoring
- **Category**: Core System
- **Priority**: High
- **Stability**: Stable
- **Support**: Full

---

*Monitoring Skill v1.0.0 | AI Council Automation System*
