#!/bin/bash
# Master Agent Runner
# Executes all skills based on configuration for multi-service project

set -e

echo "🚀 Running AI Council development skills..."

# Load skill configuration
CONFIG_FILE=".vibe/skills/skills.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Agent configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Run skills based on trigger type
if [ "$1" = "all" ] || [ "$1" = "pre-commit" ]; then
    echo "📝 Running documentation skills..."
    .vibe/skills/doc_skill/lint_docs.sh
    .vibe/skills/doc_skill/check_docs.sh
    
    echo "🐍 Running code quality skills..."
    .vibe/skills/code_skill/lint_code.sh
    # .vibe/skills/code_skill/format_code.sh  # Typically not in pre-commit
fi

if [ "$1" = "all" ] || [ "$1" = "pre-push" ]; then
    echo "🧪 Running test skills..."
    .vibe/skills/test_skill/run_tests.sh
    .vibe/skills/test_skill/check_coverage.sh
fi

if [ "$1" = "all" ] || [ "$1" = "manual" ]; then
    echo "🏗️  Running architecture skills..."
    .vibe/skills/arch_skill/validate_architecture.sh
    .vibe/skills/arch_skill/generate_diagram.sh
fi

if [ "$1" = "init" ]; then
    echo "📋 Initializing project structure..."
    .vibe/skills/test_skill/generate_tests.sh
    .vibe/skills/arch_skill/generate_diagram.sh
fi

echo "✅ All skills completed successfully"
exit 0