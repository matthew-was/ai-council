#!/bin/bash

# Skill Registrar
# Automates skill registration in skills.json

set -e

# Configuration
REGISTRY_FILE=".vibe/skills/skills.json"
SKILL_PARSER=".vibe/skills/system_management_skill/scripts/skill_parser.sh"
SKILL_VALIDATOR=".vibe/skills/system_management_skill/scripts/skill_validator.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to register a single skill
register_skill() {
    local skill_dir="$1"
    local skill_name=$(basename "$skill_dir")

    # Check if already registered
    if jq -e ".skills[\"$skill_name\"]" "$REGISTRY_FILE" >/dev/null 2>&1; then
        echo "⚠️  Skill already registered: $skill_name"
        return 1
    fi

    # Validate skill before registration
    if ! "$SKILL_VALIDATOR" validate "$skill_dir" >/dev/null 2>&1; then
        echo "❌ Cannot register invalid skill: $skill_name"
        return 1
    fi

    # Parse metadata
    local name=$("$SKILL_PARSER" extract "$skill_dir" "name")
    local description=$("$SKILL_PARSER" extract "$skill_dir" "description")
    local version=$("$SKILL_PARSER" extract "$skill_dir" "version")

    # Default values
    local author="ai-council"
    local license="MIT"
    local timestamp=$(date +%Y-%m-%d)

    # Create backup
    cp "$REGISTRY_FILE" "$REGISTRY_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "📦 Created backup: $REGISTRY_FILE.backup.$(date +%Y%m%d_%H%M%S)"

    # Add skill to registry using jq
    jq --arg name "$name" \
       --arg desc "$description" \
       --arg version "$version" \
       --arg author "$author" \
       --arg license "$license" \
       --arg timestamp "$timestamp" \
       '.skills += {($name): {
           metadata: {
             name: $name,
             description: $desc,
             version: $version,
             status: "active",
             license: $license,
             author: $author,
             created: $timestamp,
             updated: $timestamp
           },
           capabilities: ["unknown"],
           dependencies: {
             tools: [],
             files: [],
             skills: []
           },
           compatibility: {
             min_version: "1.0",
             max_version: "1.0",
             semver: $version
           },
           scripts: [],
           status: {
             operational: true,
             validation: "pending",
             last_test: $timestamp,
             issues: []
           },
           documentation: {
             skill_file: (".vibe/skills/" + $name + "/SKILL.md"),
             coverage: "unknown",
             examples: false
           }
         }}' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && \
    mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

    # Update version matrix
    local version_major_minor="${version%.*}"  # Remove patch version if present
    jq --arg ver "$version_major_minor" \
       --arg name "$name" \
       '.version_matrix[$ver] = (if .version_matrix[$ver] then (.version_matrix[$ver] + [$name]) else [$name] end | unique)' \
       "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && \
    mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

    # Update dependency graph
    jq --arg name "$name" '.dependency_graph += {($name): {
           depends_on: [],
           required_by: []
         }}' "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && \
    mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

    echo "✅ Registered skill: $skill_name v$version"

    # Update SKILLS.md documentation
    .vibe/skills/registry_utils.sh update-md >/dev/null 2>&1

    return 0
}

# Function to register all unregistered skills
register_all_skills() {
    local skills_dir=".vibe/skills"
    local registered_count=0
    local skipped_count=0

    # Find unregistered skills
    local new_skills=($(.vibe/skills/skill_scanner.sh discover))

    if [[ ${#new_skills[@]} -eq 0 ]]; then
        echo "✅ No new skills to register"
        return 0
    fi

    echo "Registering new skills..."
    echo "========================"

    for skill in "${new_skills[@]}"; do
        local skill_dir="$skills_dir/$skill"

        if register_skill "$skill_dir"; then
            echo "✅ Registered: $skill"
            registered_count=$((registered_count + 1))
        else
            echo "❌ Skipped: $skill"
            skipped_count=$((skipped_count + 1))
        fi
    done

    echo ""
    echo "Registration Summary:"
    echo "===================="
    echo "Registered: $registered_count"
    echo "Skipped: $skipped_count"

    if [[ $registered_count -gt 0 ]]; then
        echo "✅ Registration complete"
    else
        echo "⚠️  No skills were registered"
    fi

    return 0
}

# Function to update skill registration
update_skill_registration() {
    local skill_name="$1"
    local updates="$2"

    if [[ -z "$skill_name" || -z "$updates" ]]; then
        echo "Error: Skill name and updates required"
        echo "Usage: $0 update <skill_name> '<updates>'"
        return 1
    fi

    echo "⚠️  Skill registration updates not yet implemented"
    return 1
}

# Function to remove skill registration
remove_skill_registration() {
    local skill_name="$1"

    if [[ -z "$skill_name" ]]; then
        echo "Error: Skill name required"
        echo "Usage: $0 remove <skill_name>"
        return 1
    fi

    echo "⚠️  Skill removal not yet implemented"
    return 1
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
        register)
            if [[ -n "$1" ]]; then
                register_skill "$1"
            else
                echo "Error: Skill directory required"
                echo "Usage: $0 register <skill_dir>"
                exit 1
            fi
            ;;
        register-all)
            register_all_skills
            ;;
        update)
            update_skill_registration "$@"
            ;;
        remove)
            remove_skill_registration "$@"
            ;;
        *)
            echo "AI Council Skill Registrar"
            echo "========================="
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  register <dir>      - Register a single skill"
            echo "  register-all        - Register all unregistered skills"
            echo "  update <name> <updates> - Update skill registration"
            echo "  remove <name>       - Remove skill registration"
            echo ""
            echo "Examples:"
            echo "  $0 register .vibe/skills/new_skill"
            echo "  $0 register-all"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
