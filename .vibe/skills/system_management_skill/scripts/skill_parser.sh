#!/bin/bash

# SKILL.md Parser
# Extracts metadata from SKILL.md files

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to parse skill metadata
parse_skill_metadata() {
    local skill_dir="$1"
    local skill_file="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
        echo "Error: SKILL.md not found in $skill_dir" >&2
        return 1
    fi

    # Check if file has YAML frontmatter
    if head -1 "$skill_file" | grep -q "^---$"; then
        # Use Python script for YAML parsing if available
        if command -v python3 &> /dev/null; then
            if [ -f ".vibe/skills/system_management_skill/scripts/parse_skill_yaml.py" ]; then
                python3 ".vibe/skills/system_management_skill/scripts/parse_skill_yaml.py" "$skill_file"
                return $?
            fi
        fi
    fi

    # Fallback: Simple parsing with grep/sed
    echo "name=$(grep -m1 'name:' "$skill_file" | sed 's/.*name: //')"
    echo "description=$(grep -m1 'description:' "$skill_file" | sed 's/.*description: //')"
    echo "version=$(grep -A5 'metadata:' "$skill_file" | grep 'version:' | sed 's/.*version: //' | tr -d '"')"
    echo "author=$(grep -A5 'metadata:' "$skill_file" | grep 'author:' | sed 's/.*author: //')"
    echo "license=$(grep -A5 'metadata:' "$skill_file" | grep 'license:' | sed 's/.*license: //')"
}

# Function to validate skill metadata
validate_skill_metadata() {
    local skill_dir="$1"

    # Parse metadata
    local metadata
    metadata=$(parse_skill_metadata "$skill_dir")

    # Validate required fields
    if echo "$metadata" | grep -q "name="; then
        echo "✅ Valid SKILL.md structure"
        return 0
    else
        echo "❌ Invalid SKILL.md: Missing required fields"
        return 1
    fi
}

# Function to extract specific metadata fields
extract_skill_metadata() {
    local skill_dir="$1"
    local field="$2"

    if [[ -z "$field" ]]; then
        # Extract all fields if no specific field requested
        parse_skill_metadata "$skill_dir"
    else
        # Extract specific field
        local metadata
        metadata=$(parse_skill_metadata "$skill_dir")

        if [[ -n "$metadata" ]]; then
            echo "$metadata" | grep "^$field=" | cut -d'=' -f2-
        fi
    fi
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
        parse)
            parse_skill_metadata "$@"
            ;;
        validate)
            validate_skill_metadata "$@"
            ;;
        extract)
            extract_skill_metadata "$@"
            ;;
        *)
            echo "AI Council SKILL.md Parser"
            echo "=========================="
            echo ""
            echo "Usage: $0 <command> [skill_dir] [field]"
            echo ""
            echo "Commands:"
            echo "  parse <dir>      - Parse all metadata from SKILL.md"
            echo "  validate <dir>   - Validate SKILL.md structure"
            echo "  extract <dir> [field] - Extract specific metadata field"
            echo ""
            echo "Examples:"
            echo "  $0 parse .vibe/skills/doc_skill"
            echo "  $0 validate .vibe/skills/doc_skill"
            echo "  $0 extract .vibe/skills/doc_skill name"
            echo "  $0 extract .vibe/skills/doc_skill"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
