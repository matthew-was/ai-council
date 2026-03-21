---
name: system_management_skill
description: Core system management and skill registry operations for the AI Council automation system.
metadata:
  version: "1.0.0"
  author: ai-council
  license: MIT
  created: 2026-03-19
  updated: 2026-03-19
  category: system-management
  compatibility:
    - skill_registrar
    - skill_scanner
    - skill_parser
    - skill_validator
    - registry_utils
    - version_manager
    - dependency_checker
    - version_checker
    - update_notifier
    - test_integration
    - test_semver
    - test_phase3_completion
---

# System Management Skill

## Purpose

Provides core system management capabilities including skill registry operations, version management, dependency checking, and system validation. This skill is the foundation for the AI Council automation system's self-management and operational integrity.

## Capabilities

- **Skill Registry Management** - Register, validate, and manage skills
- **Skill Discovery** - Scan and discover available skills
- **Metadata Processing** - Parse and validate SKILL.md files
- **Version Management** - Track and manage system versions
- **Dependency Checking** - Validate skill dependencies
- **System Validation** - Comprehensive system health checks
- **Testing Framework** - Integration and semantic version testing

## When to Use

- When registering new skills with the system
- When validating skill structure and metadata
- When managing system versions and dependencies
- When performing system health checks
- When running integration tests
- When managing skill lifecycle operations

## Safety Features

- Comprehensive validation before any system changes
- Dry-run modes for critical operations
- Detailed logging and audit trails
- Dependency conflict detection
- Version compatibility checking
- Rollback capabilities for registry operations

## Usage

### Skill Registration

```bash
# Register a new skill
.vibe/skills/system_management_skill/scripts/skill_registrar.sh register .vibe/skills/new_skill/

# Update existing skill registration
.vibe/skills/system_management_skill/scripts/skill_registrar.sh update new_skill
```

### Skill Discovery

```bash
# Scan for available skills
.vibe/skills/system_management_skill/scripts/skill_scanner.sh scan .vibe/skills/

# Discover new skills
.vibe/skills/system_management_skill/scripts/skill_scanner.sh discover
```

### Metadata Processing

```bash
# Parse SKILL.md metadata
.vibe/skills/system_management_skill/scripts/skill_parser.sh parse .vibe/skills/workflow_skill/SKILL.md

# Validate skill structure
.vibe/skills/system_management_skill/scripts/skill_validator.sh validate workflow_skill
```

### Version Management

```bash
# Check system versions
.vibe/skills/system_management_skill/scripts/version_checker.sh status

# Manage version updates
.vibe/skills/system_management_skill/scripts/version_manager.sh update
```

### Dependency Management

```bash
# Check skill dependencies
.vibe/skills/system_management_skill/scripts/dependency_checker.sh check

# Validate dependency graph
.vibe/skills/system_management_skill/scripts/dependency_checker.sh validate
```

### System Utilities

```bash
# Registry utilities
.vibe/skills/system_management_skill/scripts/registry_utils.sh backup

# Update notifications
.vibe/skills/system_management_skill/scripts/update_notifier.sh check
```

### Testing Framework

```bash
# Run integration tests
.vibe/skills/system_management_skill/scripts/test_integration.sh run

# Semantic version tests
.vibe/skills/system_management_skill/scripts/test_semver.sh validate

# Phase 3 completion tests
.vibe/skills/system_management_skill/scripts/test_phase3_completion.sh verify
```

## Integration

Integrates with:
- **Skills Registry** - `.vibe/skills/skills.json` for skill management
- **All Skills** - Manages lifecycle of all registered skills
- **System Configuration** - `.vibe/config.json` for system settings
- **CI/CD Workflows** - `.github/workflows/` for automated operations

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

- **Skill Type**: System Management
- **Category**: Core System
- **Priority**: Critical
- **Stability**: Stable
- **Support**: Full

---

*System Management Skill v1.0.0 | AI Council Automation System*
