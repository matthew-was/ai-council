#!/bin/bash
# Python Code Linter
# Runs pylint on Python source files using pyproject.toml config

echo "🐍 Running Python linting..."

# Find Python files in backend/src/ and frontend/src/
PYTHON_FILES=$(find backend/src/ frontend/src/ -name "*.py" -type f 2>/dev/null)

if [ -z "$PYTHON_FILES" ]; then
    echo "⚠️  No Python files found in backend/src/ or frontend/src/"
    exit 0
fi

# Run pylint using project configuration
pylint $PYTHON_FILES

if [ $? -eq 0 ]; then
    echo "✅ Python linting passed"
    exit 0
else
    echo "❌ Python linting failed"
    exit 1
fi