---
name: lab-entry-skill
description: Creates structured lab entries for development tracking. Generates Notion-compatible markdown with GitHub commit links for daily development work. Use when you need to track development progress, create structured notes, or document daily work.
license: MIT
metadata:
  author: ai-council
  version: "1.0"
---

# Lab Entry Skill

## Purpose
This skill creates structured lab entries for tracking development work throughout the day.

## When to Use
- When starting daily development work
- When adding notes about completed work
- When documenting commits and changes
- When finishing work for the day
- When you need structured development tracking

## How It Works
1. Start a new lab entry at the beginning of the day
2. Add blocks (notes, commits, or combined) as work is completed
3. Finish the entry at the end of the day to generate JSON and Notion markdown
4. Output includes proper GitHub commit links and structured formatting

## Requirements
- Git repository with commits
- GitHub remote (for generating commit links)
- jq (for JSON processing)

## Usage

```bash
# Start a new lab entry
.vibe/skills/lab_entry/scripts/lab_entry.sh start

# Add a note block
.vibe/skills/lab_entry/scripts/lab_entry.sh note "Implemented feature X"

# Add a commits block
.vibe/skills/lab_entry/scripts/lab_entry.sh commits abc123 def456

# Add a combined block (note + commits)
.vibe/skills/lab_entry/scripts/lab_entry.sh combined "Fixed bugs" gh1234 jk5678

# Show current status
.vibe/skills/lab_entry/scripts/lab_entry.sh status

# Finish and generate output files
.vibe/skills/lab_entry/scripts/lab_entry.sh finish
```

## Output
- Creates lab_entry_YYYYMMDD.json with complete JSON data
- Creates lab_entry_YYYYMMDD.md with Notion-compatible markdown
- Includes proper GitHub commit links
- Generates structured blocks with timestamps

## Key Features
- Multiple blocks per day
- Note-only blocks
- Commit-only blocks
- Combined note + commit blocks
- Automatic GitHub URL generation
- Notion-compatible markdown output
- JSON data preservation

## Common Use Cases
- Daily development tracking
- Commit documentation
- Progress reporting
- Team communication
- Personal productivity tracking

## Workflow Rules
1. Start once at beginning of day
2. Add blocks multiple times as work completes
3. Finish once at end of day (explicit request only)
4. Never suggests finishing early - you decide when day is complete
