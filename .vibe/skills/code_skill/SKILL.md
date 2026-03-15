---
name: code-skill
description: Validates Python code quality using pylint. Runs pylint on all Python source files in backend/src/ and frontend/src/ directories. Use when you need to check code quality, enforce coding standards, or before committing Python code changes.
license: MIT
metadata:
  author: ai-council
  version: "1.0"
---

# Code Skill

## Purpose
This skill validates Python code quality and enforces coding standards using pylint.

## When to Use
- Before committing Python code changes
- During CI/CD pipeline execution
- When requested to validate code quality
- As part of pre-commit hooks
- To enforce consistent code style across the project

## How It Works
1. Finds all Python files (.py) in backend/src/ and frontend/src/ directories
2. Runs pylint with project configuration (pyproject.toml or .pylintrc)
3. Reports code quality issues, style violations, and potential bugs
4. Returns success (0) if all files pass linting, failure (1) if any issues are found

## Requirements
- pylint installed
- Python project with pylint configuration (pyproject.toml or .pylintrc)

## Usage

```bash
.vibe/skills/code_skill/scripts/lint_code.sh
```

## Output
- Success: "✅ Python linting passed"
- Failure: "❌ Python linting failed" followed by specific linting errors
- Warning: "⚠️ No Python files found in backend/src/ or frontend/src/" if no .py files exist

## Common Issues
- Missing docstrings
- Unused imports or variables
- Line too long violations
- Inconsistent naming conventions
- Missing type hints
- Complex code structures

## Configuration
The skill uses pylint configuration from pyproject.toml or .pylintrc. Common configuration options include:
- Maximum line length
- Allowed variable naming conventions
- Required docstring formats
- Disabled checks for specific rules
