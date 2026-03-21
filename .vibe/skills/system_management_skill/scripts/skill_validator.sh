#!/bin/bash

# Skill Validator
# Validates skill structure, metadata, and requirements

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to validate skill structure
validate_skill_structure() {
    local skill_dir="$1"
    local skill_name=$(basename "$skill_dir")

    # Check directory structure
    if [[ ! -d "$skill_dir" ]]; then
        echo "❌ Skill directory not found: $skill_dir"
        return 1
    fi

    # Check SKILL.md exists
    if [[ ! -f "$skill_dir/SKILL.md" ]]; then
        echo "❌ SKILL.md not found in $skill_dir"
        return 1
    fi

    # Check scripts directory exists
    if [[ ! -d "$skill_dir/scripts" ]]; then
        echo "⚠️  No scripts directory in $skill_dir"
    fi

    # Parse and validate metadata
    if ! .vibe/skills/system_management_skill/scripts/skill_parser.sh validate "$skill_dir" >/dev/null 2>&1; then
        echo "❌ Invalid metadata in $skill_dir/SKILL.md"
        return 1
    fi

    echo "✅ Valid skill structure: $skill_name"
    return 0
}

# Function to validate skill requirements
validate_skill_requirements() {
    local skill_dir="$1"

    # Parse metadata
    local version=$(.vibe/skills/system_management_skill/scripts/skill_parser.sh extract "$skill_dir" "version")

    # Validate version format (allow both X.Y and X.Y.Z formats)
    if [[ -n "$version" && "$version" != "unknown" ]]; then
        # Check if version matches X.Y or X.Y.Z pattern
        if [[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
            echo "✅ Valid skill requirements"
            return 0
        else
            echo "❌ Invalid version format: $version"
            return 1
        fi
    fi

    echo "✅ Valid skill requirements"
    return 0
}

# Function to validate all skills
validate_all_skills() {
    local skills_dir=".vibe/skills"
    local all_valid=true

    # Find all skill directories
    find "$skills_dir" -name "SKILL.md" | while read skill_file; do
        local skill_dir=$(dirname "$skill_file")
        local skill_name=$(basename "$skill_dir")

        # Skip special directories
        if [[ "$skill_name" == "notifications" || "$skill_name" == "backup" || "$skill_name" == "archive" ]]; then
            continue
        fi

        if validate_skill_structure "$skill_dir"; then
            echo "✅ $skill_name: Valid structure"
        else
            echo "❌ $skill_name: Validation failed"
            all_valid=false
        fi
    done

    if [[ "$all_valid" == "true" ]]; then
        echo "✅ All skills validated successfully"
        return 0
    else
        echo "❌ Some skills failed validation"
        return 1
    fi
}

# Function to check if skill is registrable
check_registrable() {
    local skill_dir="$1"
    local skill_name=$(basename "$skill_dir")

    # Check if already registered
    if jq -e ".skills[\"$skill_name\"]" .vibe/skills/skills.json >/dev/null 2>&1; then
        echo "⚠️  Skill already registered: $skill_name"
        return 1
    fi

    # Validate structure and requirements
    if validate_skill_structure "$skill_dir" && validate_skill_requirements "$skill_dir"; then
        echo "✅ Skill is registrable: $skill_name"
        return 0
    else
        echo "❌ Skill not registrable: $skill_name"
        return 1
    fi
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
        validate)
            if [[ -n "$1" ]]; then
                validate_skill_structure "$1"
            else
                validate_all_skills
            fi
            ;;
        requirements)
            validate_skill_requirements "$1"
            ;;
        registrable)
            check_registrable "$1"
            ;;
        *)
            echo "AI Council Skill Validator"
            echo "=========================="
            echo ""
            echo "Usage: $0 <command> [skill_dir]"
            echo ""
            echo "Commands:"
            echo "  validate <dir>      - Validate skill structure"
            echo "  requirements <dir>  - Validate skill requirements"
            echo "  registrable <dir>  - Check if skill is registrable"
            echo "  validate            - Validate all skills"
            echo ""
            echo "Examples:"
            echo "  $0 validate .vibe/skills/doc_skill"
            echo "  $0 requirements .vibe/skills/doc_skill"
            echo "  $0 registrable .vibe/skills/doc_skill"
            echo "  $0 validate"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
