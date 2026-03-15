# Example Lab Entry Format

This template shows the preferred format for lab entries.

## What was done

### HH:MM UTC
[Detailed description of what was accomplished]

- [sha](url) — Commit message (Backend Task X)

### HH:MM UTC
[Another accomplishment]

- [sha](url) — Commit message (Backend Task Y)

## Next steps
- Next action item
- Next action item
- Next action item

---

**Notes:**
- Use 24-hour UTC time format
- Group related work in single blocks
- Include commit SHAs with links when available
- List next steps explicitly

**Example:**
```bash
.vibe/skills/lab_entry/manage_entry.sh start "Task Title"
.vibe/skills/lab_entry/manage_entry.sh note "Detailed description"
.vibe/skills/lab_entry/manage_entry.sh commits sha1 sha2
.vibe/skills/lab_entry/manage_entry.sh finish
```