# Lab Entry Skill

## Purpose

Manages multi-session lab notebook entries that can be published to Notion. Maintains a draft file locally and generates Notion-compatible markdown when complete.

## Usage

### Start a new entry
```bash
.vibe/skills/lab_entry/manage_entry.sh start "Entry Title"
```

### Append a note
```bash
.vibe/skills/lab_entry/manage_entry.sh note "Your note text here"
```

### Append Git commits
```bash
.vibe/skills/lab_entry/manage_entry.sh commits abc1234 def5678
```

### Finish and generate markdown
```bash
.vibe/skills/lab_entry/manage_entry.sh finish
```

## Features

- **Project-local storage**: Draft file stored in project root
- **Git integration**: Automatically fetches commit details
- **Notion-compatible**: Generates proper markdown format
- **Multi-session**: Maintains state across sessions

## Output Format

The `finish` command produces markdown like:

```markdown
# Lab Entry: [Your Title]

## What was done

### 14:30 UTC
Note text here

### 15:45 UTC
- abc1234 — Fixed bug in workflow
- def5678 — Added documentation

## Next steps
- Review and refine
- Test implementation
- Document workflow
```

## Configuration

Draft files are stored in: `.lab-entry-draft.json` (added to .gitignore)

## Example Workflow

1. Start session: `manage_entry.sh start "AI Council Setup"`
2. Add work: `manage_entry.sh note "Configured agents"`
3. Add commits: `manage_entry.sh commits abc1234 def5678`
4. Finish: `manage_entry.sh finish` → Creates markdown file
5. Paste markdown into Notion

## Requirements

- `jq` for JSON processing
- `git` for commit details
- Bash 4.0+

## Notes

- One active draft at a time
- Draft file persists across sessions
- Automatically cleans up on finish
- GitHub URLs auto-detected
