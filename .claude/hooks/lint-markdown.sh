#!/bin/bash
# PostToolUse hook: run markdownlint after any Write or Edit tool call.
# Blocks (exit 2) if lint errors are found, feeding the error output back to Claude.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Skip non-markdown files
[[ "$FILE_PATH" != *.md ]] && exit 0

# Skip files that don't exist (e.g. deletions)
[[ ! -f "$FILE_PATH" ]] && exit 0

# Skip files outside the project directory (e.g. plan files in ~/.claude/plans/)
[[ "$FILE_PATH" != "$CLAUDE_PROJECT_DIR"/* ]] && exit 0

if ! OUTPUT=$(markdownlint "$FILE_PATH" 2>&1); then
  echo "markdownlint failed for $FILE_PATH — fix these errors:" >&2
  echo "$OUTPUT" >&2
  exit 2
fi

exit 0
