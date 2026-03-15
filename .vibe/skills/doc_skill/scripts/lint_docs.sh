#!/bin/bash
# Documentation Linter
# Runs markdownlint on all documentation files

echo "📝 Starting documentation linting..."

# Find all markdown files in docs/ and .vibe/
MARKDOWN_FILES=$(find docs/ .vibe/ -name "*.md" -type f)

if [ -z "$MARKDOWN_FILES" ]; then
    echo "⚠️  No markdown files found"
    exit 0
fi

# Run markdownlint with project configuration
markdownlint --config .markdownlint.json $MARKDOWN_FILES

if [ $? -eq 0 ]; then
    echo "✅ Documentation linting passed"
    exit 0
else
    echo "❌ Documentation linting failed"
    exit 1
fi