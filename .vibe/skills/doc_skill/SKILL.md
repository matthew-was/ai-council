---
name: doc-skill
description: Validates and lints documentation files. Runs markdownlint on all markdown files in the docs/ and .vibe/ directories to ensure consistent formatting and quality. Use when you need to check documentation quality or before committing documentation changes.
license: MIT
metadata:
  author: ai-council
  version: "1.0"
---

# Documentation Skill

## Purpose
This skill validates and lints all markdown documentation files to ensure consistent formatting, proper structure, and quality standards.

## When to Use
- Before committing documentation changes
- During CI/CD pipeline execution
- When requested to validate documentation quality
- As part of pre-commit hooks

## How It Works
1. Finds all markdown files (.md) in the docs/ and .vibe/ directories
2. Runs markdownlint with the project's configuration (.markdownlint.json)
3. Reports any formatting issues or violations
4. Returns success (0) if all files pass linting, failure (1) if any issues are found

## Requirements
- markdownlint CLI tool installed
- .markdownlint.json configuration file in project root

## Usage

```bash
.vibe/skills/doc_skill/scripts/lint_docs.sh
```

## Output
- Success: "✅ Documentation linting passed"
- Failure: "❌ Documentation linting failed" followed by specific linting errors
- Warning: "⚠️ No markdown files found" if no .md files exist

## Common Issues
- Inconsistent heading formatting
- Trailing whitespace
- Improper list formatting
- Line length violations
- Incorrect emphasis formatting

## Configuration
The skill uses .markdownlint.json for configuration. Common rules include:
- MD007: Unordered list indentation
- MD012: Maximum line length
- MD024: Multiple headings with same content
- MD025: Single title per file
- MD041: First line in file should be top level heading
