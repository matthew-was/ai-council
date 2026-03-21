#!/bin/bash

# AI Council Skill Scanner
# Scans for skill directories and discovers new skills

set -e

# Configuration
SKILLS_DIR=".vibe/skills"
REGISTRY_FILE=".vibe/skills/skills.json"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to scan for all skill directories
scan_skills_directory() {
    local found_skills=()
    
    # Find all directories containing SKILL.md files
    while IFS= read -r skill_dir; do
        local skill_name=$(basename "$skill_dir")
        
        # Skip special directories
        if [[ "$skill_name" != "notifications" && "$skill_name" != "backup" && "$skill_name" != "archive" ]]; then
            found_skills+=("$skill_name")
        fi
    done < <(find "$SKILLS_DIR" -name "SKILL.md" | xargs dirname)
    
    # Debug output
    if [[ ${#found_skills[@]} -eq 0 ]]; then
        echo "Debug: No skills found" >&2
    else
        echo "Debug: Found ${#found_skills[@]} skills" >&2
    fi
    echo "${found_skills[@]}"
}

# Function to discover new (unregistered) skills
discover_new_skills() {
    local found_skills=($(scan_skills_directory))
    local new_skills=()
    
    # Get currently registered skills
    local registered_skills=()
    if [[ -f "$REGISTRY_FILE" ]]; then
        registered_skills=($(jq -r '.skills | keys[]' "$REGISTRY_FILE" 2>/dev/null))
    fi
    
    # Find skills that are not registered
    for skill in "${found_skills[@]}"; do
        local is_registered=false
        
        # Check if skill is already registered
        for registered in "${registered_skills[@]}"; do
            if [[ "$skill" == "$registered" ]]; then
                is_registered=true
                break
            fi
        done
        
        if [[ "$is_registered" == "false" ]]; then
            new_skills+=("$skill")
        fi
    done
    
    echo "${new_skills[@]}"
}

# Function to list all discovered skills
list_discovered_skills() {
    echo -e "${BLUE}Listing discovered skills...${NC}"
    
    local found_skills=($(scan_skills_directory))
    
    if [[ ${#found_skills[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No skills found${NC}"
        return 1
    fi
    
    echo "Discovered Skills:"
    echo "=================="
    
    for skill in "${found_skills[@]}"; do
        local skill_dir="$SKILLS_DIR/$skill"
        local skill_file="$skill_dir/SKILL.md"
        
        # Get skill version if available
        local version="unknown"
        if [[ -f "$skill_file" ]]; then
            version=$(grep -m1 'version:' "$skill_file" 2>/dev/null | sed 's/.*version: //' | tr -d '"' || echo "unknown")
        fi
        
        echo "- $skill (v$version)"
    done
    
    return 0
}

# Function to show detailed skill information
show_skill_details() {
    local skill_name="$1"
    
    if [[ -z "$skill_name" ]]; then
        echo -e "${RED}Error: Skill name required${NC}"
        echo "Usage: $0 show <skill_name>"
        return 1
    fi
    
    local skill_dir="$SKILLS_DIR/$skill_name"
    local skill_file="$skill_dir/SKILL.md"
    
    if [[ ! -d "$skill_dir" ]]; then
        echo -e "${RED}Error: Skill directory not found: $skill_dir${NC}"
        return 1
    fi
    
    if [[ ! -f "$skill_file" ]]; then
        echo -e "${RED}Error: SKILL.md not found in $skill_dir${NC}"
        return 1
    fi
    
    echo -e "${BLUE}Skill Details: $skill_name${NC}"
    echo "============================"
    
    # Show basic information
    echo "Directory: $skill_dir"
    echo "SKILL.md: $skill_file"
    
    # Extract and show metadata
    echo -e "\nMetadata:"
    echo "---------"
    
    # Use Python for YAML parsing if available
    if command -v python3 &> /dev/null; then
        python3 -c "
import yaml
try:
    with open('$skill_file', 'r') as f:
        content = f.read()
    if content.startswith('---'):
        yaml_end = content.find('---', 3)
        yaml_content = content[3:yaml_end].strip()
        data = yaml.safe_load(yaml_content)
        print(f\"Name: {data.get('name', 'N/A')}\")
        print(f\"Description: {data.get('description', 'N/A')}\")
        if 'metadata' in data:
            print(f\"Version: {data['metadata'].get('version', 'N/A')}\")
            print(f\"Author: {data['metadata'].get('author', 'N/A')}\")
            print(f\"License: {data['metadata'].get('license', 'N/A')}\")
except Exception as e:
    print(f\"Error parsing YAML: {e}\", file=sys.stderr)
" 2>/dev/null || echo "YAML parsing not available"
    else
        echo "Name: $(grep -m1 'name:' "$skill_file" | sed 's/.*name: //')"
        echo "Description: $(grep -m1 'description:' "$skill_file" | sed 's/.*description: //')"
        echo "Version: $(grep -A5 'metadata:' "$skill_file" | grep 'version:' | sed 's/.*version: //' | tr -d '"')"
    fi
    
    # Show scripts
    echo -e "\nScripts:"
    echo "--------"
    if [[ -d "$skill_dir/scripts" ]]; then
        find "$skill_dir/scripts" -type f -name "*.sh" | while read script; do
            echo "- $(basename "$script")"
        done
    else
        echo "No scripts directory"
    fi
    
    return 0
}

# Function to check skill registration status
check_registration_status() {
    local skill_name="$1"
    
    if [[ -z "$skill_name" ]]; then
        echo -e "${RED}Error: Skill name required${NC}"
        return 1
    fi
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${YELLOW}Registry file not found - skill not registered${NC}"
        return 1
    fi
    
    # Check if skill is registered
    if jq -e ".skills[\"$skill_name\"]" "$REGISTRY_FILE" >/dev/null 2>&1; then
        local version=$(jq -r ".skills[\"$skill_name\"].metadata.version" "$REGISTRY_FILE")
        local status=$(jq -r ".skills[\"$skill_name\"].metadata.status" "$REGISTRY_FILE")
        
        echo -e "${GREEN}✅ Skill is registered${NC}"
        echo "   Version: $version"
        echo "   Status: $status"
        return 0
    else
        echo -e "${YELLOW}⚠️  Skill is not registered${NC}"
        return 1
    fi
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
        scan)
            scan_skills_directory "$@"
            ;;
        discover)
            discover_new_skills "$@"
            ;;
        list)
            list_discovered_skills "$@"
            ;;
        show)
            show_skill_details "$@"
            ;;
        check)
            check_registration_status "$@"
            ;;
        *)
            echo "AI Council Skill Scanner"
            echo "========================"
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  scan          - Scan for all skill directories"
            echo "  discover      - Discover new (unregistered) skills"
            echo "  list          - List all discovered skills with details"
            echo "  show <name>   - Show detailed information about a skill"
            echo "  check <name>  - Check registration status of a skill"
            echo ""
            echo "Examples:"
            echo "  $0 scan"
            echo "  $0 discover"
            echo "  $0 list"
            echo "  $0 show doc_skill"
            echo "  $0 check doc_skill"
            ;;
    esac
}

# Run main function with all arguments
main "$@"
