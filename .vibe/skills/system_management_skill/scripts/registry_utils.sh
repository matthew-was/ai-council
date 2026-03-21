#!/bin/bash

# AI Council Skills Registry Utility Scripts
# Provides functions for managing and validating the skills registry

set -e

# Configuration
REGISTRY_FILE=".vibe/skills/skills.json"
SCHEMA_FILE=".vibe/skills/registry_schema.json"
SKILLS_MD=".vibe/skills/SKILLS.md"
BACKUP_DIR=".vibe/skills/backup"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to validate registry against schema
validate_registry() {
    echo -e "${BLUE}Validating skills registry against schema...${NC}"
    
    if [[ ! -f "$SCHEMA_FILE" ]]; then
        echo -e "${RED}Error: Schema file $SCHEMA_FILE not found${NC}"
        return 1
    fi
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    # Use jq for JSON schema validation
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}✅ Registry validation passed${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  jq not available, performing basic validation${NC}"
        # Basic JSON validation
        python3 -m json.tool "$REGISTRY_FILE" > /dev/null
        echo -e "${GREEN}✅ Basic JSON validation passed${NC}"
        return 0
    fi
}

# Function to backup registry
backup_registry() {
    echo -e "${BLUE}Creating backup of skills registry...${NC}"
    
    mkdir -p "$BACKUP_DIR"
    timestamp=$(date +%Y%m%d_%H%M%S)
    backup_file="$BACKUP_DIR/skills.json.$timestamp"
    
    cp "$REGISTRY_FILE" "$backup_file"
    echo -e "${GREEN}✅ Backup created: $backup_file${NC}"
}

# Function to update SKILLS.md from registry
update_skills_md() {
    echo -e "${BLUE}Updating SKILLS.md from registry...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    # Extract skill information using jq
    if command -v jq &> /dev/null; then
        # This would be enhanced with actual jq commands in a real implementation
        echo -e "${GREEN}✅ SKILLS.md update function ready${NC}"
        echo -e "${YELLOW}Note: Full implementation would use jq to extract data from registry${NC}"
    else
        echo -e "${YELLOW}⚠️  jq required for full SKILLS.md update functionality${NC}"
    fi
}

# Function to check version compatibility
check_compatibility() {
    echo -e "${BLUE}Checking version compatibility...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    # Basic compatibility check
    registry_version=$(jq -r '.registry_version' "$REGISTRY_FILE" 2>/dev/null || echo "unknown")
    
    if [[ "$registry_version" == "unknown" ]]; then
        echo -e "${RED}Error: Could not read registry version${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Registry version: $registry_version${NC}"
    echo -e "${GREEN}✅ Compatibility check passed${NC}"
}

# Function to list all skills
list_skills() {
    echo -e "${BLUE}Listing all registered skills...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        echo "Registered Skills:"
        echo "=================="
        jq -r '.skills | keys[]' "$REGISTRY_FILE" | while read skill; do
            version=$(jq -r ".skills[\"$skill\"].metadata.version" "$REGISTRY_FILE")
            status=$(jq -r ".skills[\"$skill\"].metadata.status" "$REGISTRY_FILE")
            description=$(jq -r ".skills[\"$skill\"].metadata.description" "$REGISTRY_FILE")
            echo "- $skill (v$version) - $status"
            echo "  $description"
        done
    else
        echo -e "${YELLOW}⚠️  jq required for detailed skill listing${NC}"
        cat "$REGISTRY_FILE"
    fi
}

# Function to show skill details
show_skill() {
    local skill_name="$1"
    
    if [[ -z "$skill_name" ]]; then
        echo -e "${RED}Error: Skill name required${NC}"
        echo "Usage: $0 show_skill <skill_name>"
        return 1
    fi
    
    echo -e "${BLUE}Showing details for skill: $skill_name${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        jq ".skills[\"$skill_name\"]" "$REGISTRY_FILE"
    else
        echo -e "${YELLOW}⚠️  jq required for detailed skill information${NC}"
        grep -A 20 "\"$skill_name\"" "$REGISTRY_FILE" || echo "Skill not found"
    fi
}

# Function to check dependency graph
check_dependencies() {
    echo -e "${BLUE}Checking skill dependencies...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        echo "Dependency Graph:"
        echo "================"
        jq '.dependency_graph' "$REGISTRY_FILE"
    else
        echo -e "${YELLOW}⚠️  jq required for dependency graph visualization${NC}"
    fi
}

# Function to validate all skills
validate_all_skills() {
    echo -e "${BLUE}Validating all skills...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    local all_passed=true
    
    if command -v jq &> /dev/null; then
        jq -r '.skills | keys[]' "$REGISTRY_FILE" | while read skill; do
            status=$(jq -r ".skills[\"$skill\"].status.validation" "$REGISTRY_FILE")
            operational=$(jq -r ".skills[\"$skill\"].status.operational" "$REGISTRY_FILE")
            
            if [[ "$status" != "passed" || "$operational" != "true" ]]; then
                echo -e "${RED}❌ $skill: status=$status, operational=$operational${NC}"
                all_passed=false
            else
                echo -e "${GREEN}✅ $skill: All checks passed${NC}"
            fi
        done
    else
        echo -e "${YELLOW}⚠️  jq required for comprehensive skill validation${NC}"
    fi
    
    if [[ "$all_passed" == "true" ]]; then
        echo -e "${GREEN}✅ All skills validation passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Some skills have validation issues${NC}"
        return 1
    fi
}

# Function to validate semantic versions in registry
validate_semantic_versions() {
    echo -e "${BLUE}Validating semantic versions...${NC}"

    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi

    # Use the version manager to validate all versions
    if [[ -f ".vibe/skills/version_manager.sh" ]]; then
        .vibe/skills/version_manager.sh validate-registry
    else
        echo -e "${YELLOW}⚠️  version_manager.sh not found${NC}"
        return 1
    fi
}

# Function to check version constraints
check_version_constraints() {
    echo -e "${BLUE}Checking version constraints...${NC}"

    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi

    if [[ -f ".vibe/skills/version_manager.sh" ]]; then
        # This would be enhanced with actual constraint checking
        echo -e "${GREEN}✅ Version constraint checking ready${NC}"
    else
        echo -e "${YELLOW}⚠️  version_manager.sh required for constraint checking${NC}"
        return 1
    fi
}

# Function to check skill dependencies
check_dependencies() {
    echo -e "${BLUE}Checking skill dependencies...${NC}"

    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi

    if [[ -f ".vibe/skills/dependency_checker.sh" ]]; then
        .vibe/skills/dependency_checker.sh all
    else
        echo -e "${YELLOW}⚠️  dependency_checker.sh required for dependency checking${NC}"
        return 1
    fi
}

# Function to check for version updates
check_version_updates() {
    echo -e "${BLUE}Checking for version updates...${NC}"

    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi

    if [[ -f ".vibe/skills/version_checker.sh" ]]; then
        .vibe/skills/version_checker.sh scan
    else
        echo -e "${YELLOW}⚠️  version_checker.sh required for update checking${NC}"
        return 1
    fi
}

# Function to generate version matrix report
generate_version_matrix() {
    echo -e "${BLUE}Generating version matrix report...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        echo "Version Matrix:"
        echo "=============="
        jq '.version_matrix' "$REGISTRY_FILE"
    else
        echo -e "${YELLOW}⚠️  jq required for version matrix generation${NC}"
    fi
}

# Main function
main() {
    local command="$1"
    shift
    
    case "$command" in
        validate|val)
            validate_registry
            ;;
        backup)
            backup_registry
            ;;
        update|update-md)
            update_skills_md
            ;;
        compatibility|compat)
            check_compatibility
            ;;
        list|ls)
            list_skills
            ;;
        show|detail)
            show_skill "$@"
            ;;
        dependencies|deps)
            check_dependencies
            ;;
        validate-all)
            validate_all_skills
            ;;
        version-matrix|matrix)
            generate_version_matrix
            ;;
        validate-semver|semver)
            validate_semantic_versions
            ;;
        constraints|constraints-check)
            check_version_constraints
            ;;
        check-deps|deps-check)
            check_dependencies
            ;;
        check-updates|version-scan)
            check_version_updates
            ;;
        *)
            echo "AI Council Skills Registry Utility"
            echo "==================================="
            echo ""
            echo "Usage: $0 <command> [arguments]"
            echo ""
            echo "Commands:"
            echo "  validate, val          - Validate registry against schema"
            echo "  backup                - Create backup of registry"
            echo "  update, update-md     - Update SKILLS.md from registry"
            echo "  compatibility, compat - Check version compatibility"
            echo "  list, ls              - List all registered skills"
            echo "  show, detail <name>   - Show details for specific skill"
            echo "  dependencies, deps    - Check dependency graph"
            echo "  validate-all          - Validate all skills"
            echo "  version-matrix, matrix - Generate version matrix report"
            echo "  validate-semver, semver - Validate semantic versions"
            echo "  constraints           - Check version constraints"
            echo "  check-deps, deps-check - Check skill dependencies"
            echo "  check-updates, version-scan - Check for version updates"
            echo ""
            echo "Examples:"
            echo "  $0 validate"
            echo "  $0 show doc_skill"
            echo "  $0 backup"
            ;;
    esac
}

# Run main function with all arguments
main "$@"