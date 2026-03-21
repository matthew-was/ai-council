---
name: automation_skill
description: Provides session management, status tracking, and workflow automation tools for the AI Council project. Contains scripts and documentation to streamline development workflows.
metadata:
  author: ai-council
  version: "1.0"
  license: MIT
---

# Automation Skill

## 🎯 Purpose

The Automation Skill provides session management, status tracking, and workflow automation tools for the AI Council project. It contains scripts and documentation to streamline development workflows.

## 📁 Structure

```bash
automation_skill/
├── SKILL.md                # This file
├── AUTOMATION_GUIDE.md     # Comprehensive automation guide
└── scripts/
    ├── start_session.sh    # Session initialization script
    ├── status.sh           # Project status reporting
    ├── update_log.sh       # Session log update tool
    └── auto_update.sh      # Automated update script
```

## 🚀 Usage

### Starting a Session

```bash
.vibe/skills/automation_skill/scripts/start_session.sh
```

### Checking Project Status

```bash
.vibe/skills/automation_skill/scripts/status.sh
```

### Updating Session Log

```bash
.vibe/skills/automation_skill/scripts/update_log.sh
```

## 📊 Features

### Session Management
- **start_session.sh**: Initializes development sessions with reminders and status checks
- **update_log.sh**: Creates structured session log entries with templates

### Project Monitoring
- **status.sh**: Provides comprehensive project status including:
  - Documentation metrics
  - Git status
  - Markdown linting results
  - Roadmap progress
  - Recent session history

### Automation
- **auto_update.sh**: Handles automated updates and maintenance tasks

## 🔧 Configuration

The skill works with the top-level `.vibe/config.json` file for project-specific settings.

## 📖 Documentation

- **AUTOMATION_GUIDE.md**: Detailed guide to all automation features and workflows
- **Session Logs**: Maintained in `.vibe/session_log.md` at project root
- **Roadmap**: Tracked in `.vibe/roadmap.md` at project root

## 🎯 Integration

This skill integrates with:
- `.vibe/rules.md` for workflow guidelines
- `.vibe/session_log.md` for progress tracking
- `.vibe/roadmap.md` for milestone tracking
- `.vibe/config.json` for project configuration

## 🧪 Testing

All scripts are self-contained and can be tested individually:

```bash
# Test session startup
.vibe/skills/automation_skill/scripts/start_session.sh

# Test status reporting  
.vibe/skills/automation_skill/scripts/status.sh

# Test log updating
.vibe/skills/automation_skill/scripts/update_log.sh
```

## 🔄 Maintenance

- Update scripts as project requirements evolve
- Add new automation tools to the scripts directory
- Keep AUTOMATION_GUIDE.md updated with new features
- Ensure compatibility with project workflow changes

## 📝 Notes

- Scripts assume standard Unix environment (bash, grep, sed, etc.)
- Designed for macOS/Linux compatibility
- Follows project markdown and documentation standards
- Integrates with Git for version control awareness
