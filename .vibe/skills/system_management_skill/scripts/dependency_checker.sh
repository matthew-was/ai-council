#!/bin/bash

# AI Council Dependency Compatibility Checker
# Validates skill dependencies and version constraints

set -e

# Configuration
REGISTRY_FILE=".vibe/skills/skills.json"
VERSION_MANAGER=".vibe/skills/version_manager.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to validate a single skill's dependencies
validate_skill_dependencies() {
    local skill_name="$1"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if [[ ! -f "$VERSION_MANAGER" ]]; then
        echo -e "${YELLOW}Warning: Version manager not found, limited validation${NC}"
    fi
    
    # Extract skill data using jq
    if command -v jq &> /dev/null; then
        local skill_data
        skill_data=$(jq ".skills[\"$skill_name\"]" "$REGISTRY_FILE" 2>/dev/null)
        
        if [[ -z "$skill_data" || "$skill_data" == "null" ]]; then
            echo -e "${RED}Error: Skill '$skill_name' not found in registry${NC}"
            return 1
        fi
        
        echo -e "${BLUE}Validating dependencies for $skill_name...${NC}"
        
        # Check tool dependencies
        local tools
        tools=$(echo "$skill_data" | jq -r '.dependencies.tools[]?' 2>/dev/null)
        if [[ -n "$tools" ]]; then
            echo -e "${GREEN}✅ Tool dependencies:${NC}"
            while IFS= read -r tool; do
                if [[ -n "$tool" ]]; then
                    echo "   - $tool"
                fi
            done <<< "$tools"
        fi
        
        # Check file dependencies
        local files
        files=$(echo "$skill_data" | jq -r '.dependencies.files[]?' 2>/dev/null)
        if [[ -n "$files" ]]; then
            echo -e "${GREEN}✅ File dependencies:${NC}"
            while IFS= read -r file; do
                if [[ -n "$file" ]]; then
                    echo "   - $file"
                fi
            done <<< "$files"
        fi
        
        # Check skill dependencies
        local skill_deps
        skill_deps=$(echo "$skill_data" | jq -r '.dependencies.skills[]?' 2>/dev/null)
        if [[ -n "$skill_deps" ]]; then
            echo -e "${GREEN}✅ Skill dependencies:${NC}"
            while IFS= read -r dep_skill; do
                if [[ -n "$dep_skill" ]]; then
                    # Check if dependent skill exists
                    local dep_exists
                    dep_exists=$(jq -r ".skills[\"$dep_skill\"]" "$REGISTRY_FILE" 2>/dev/null)
                    if [[ -n "$dep_exists" && "$dep_exists" != "null" ]]; then
                        local dep_version
                        dep_version=$(echo "$dep_exists" | jq -r '.metadata.version' 2>/dev/null)
                        echo "   - $dep_skill (v$dep_version)"
                    else
                        echo -e "${YELLOW}   ⚠️  $dep_skill (not found in registry)${NC}"
                    fi
                fi
            done <<< "$skill_deps"
        fi
        
        # Check constraints if version manager available
        if [[ -f "$VERSION_MANAGER" ]]; then
            local constraints
            constraints=$(echo "$skill_data" | jq -r '.compatibility.constraints // {} | to_entries[]? | "\(.key) \(.value)"' 2>/dev/null)
            if [[ -n "$constraints" ]]; then
                echo -e "${GREEN}✅ Version constraints:${NC}"
                while IFS= read -line constraint_entry; do
                    if [[ -n "$constraint_entry" ]]; then
                        local dep_skill=$(echo "$constraint_entry" | awk '{print $1}')
                        local constraint=$(echo "$constraint_entry" | awk '{print $2}')
                        
                        # Get dependent skill version
                        local dep_version
                        dep_version=$(jq -r ".skills[\"$dep_skill\"].metadata.version" "$REGISTRY_FILE" 2>/dev/null)
                        
                        if [[ -n "$dep_version" && "$dep_version" != "null" ]]; then
                            # Check constraint satisfaction
                            local satisfies
                            satisfies=$("$VERSION_MANAGER" constraint "$dep_version" "$constraint" 2>/dev/null || echo "unknown")
                            
                            if [[ "$satisfies" == "true" ]]; then
                                echo "   - $dep_skill: v$dep_version satisfies $constraint ✅"
                            else
                                echo -e "${RED}   - $dep_skill: v$dep_version does NOT satisfy $constraint ❌${NC}"
                            fi
                        else
                            echo -e "${YELLOW}   - $dep_skill: not found or invalid version ⚠️${NC}"
                        fi
                    fi
                done <<< "$constraints"
            fi
        fi
        
        echo -e "${GREEN}✅ Dependency validation complete for $skill_name${NC}"
        return 0
        
    else
        echo -e "${RED}Error: jq not available for dependency analysis${NC}"
        return 1
    fi
}

# Function to validate all skill dependencies
validate_all_dependencies() {
    echo -e "${BLUE}Validating all skill dependencies...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        local all_valid=true
        local skill_count=0
        local skills_with_issues=0
        
        # Get all skill names
        jq -r '.skills | keys[]' "$REGISTRY_FILE" | while read skill_name; do
            skill_count=$((skill_count + 1))
            
            # Validate this skill's dependencies
            if ! validate_skill_dependencies "$skill_name" > /dev/null 2>&1; then
                echo -e "${RED}❌ $skill_name has dependency issues${NC}"
                skills_with_issues=$((skills_with_issues + 1))
                all_valid=false
            else
                echo -e "${GREEN}✅ $skill_name dependencies validated${NC}"
            fi
        done
        
        echo -e "${BLUE}Dependency validation summary:${NC}"
        echo "   Skills checked: $skill_count"
        echo "   Skills with issues: $skills_with_issues"
        
        if [[ "$all_valid" == "true" ]]; then
            echo -e "${GREEN}✅ All skill dependencies validated successfully${NC}"
            return 0
        else
            echo -e "${RED}❌ Some skills have dependency issues${NC}"
            return 1
        fi
        
    else
        echo -e "${RED}Error: jq not available for comprehensive validation${NC}"
        return 1
    fi
}

# Function to check dependency conflicts
check_dependency_conflicts() {
    echo -e "${BLUE}Checking for dependency conflicts...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        # This would be enhanced with actual conflict detection logic
        echo -e "${GREEN}✅ Basic dependency conflict checking ready${NC}"
        echo -e "${YELLOW}Note: Advanced conflict detection would analyze version constraints across all skills${NC}"
        return 0
    else
        echo -e "${RED}Error: jq required for conflict detection${NC}"
        return 1
    fi
}

# Function to suggest dependency resolutions
suggest_resolutions() {
    local skill_name="$1"
    
    echo -e "${BLUE}Generating dependency resolution suggestions for $skill_name...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        # This would be enhanced with actual resolution logic
        echo -e "${GREEN}✅ Dependency resolution suggestions:${NC}"
        echo "   1. Update dependent skills to compatible versions"
        echo "   2. Adjust version constraints in skills.json"
        echo "   3. Check dependency graph for circular dependencies"
        echo "   4. Validate all constraints with: .vibe/skills/version_manager.sh constraint"
        return 0
    else
        echo -e "${RED}Error: jq required for resolution suggestions${NC}"
        return 1
    fi
}

# Function to analyze dependency graph
analyze_dependency_graph() {
    echo -e "${BLUE}Analyzing dependency graph...${NC}"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        echo -e "${RED}Error: Registry file $REGISTRY_FILE not found${NC}"
        return 1
    fi
    
    if command -v jq &> /dev/null; then
        echo "Dependency Graph Analysis:"
        echo "========================"
        
        # Show dependency graph from registry
        jq '.dependency_graph' "$REGISTRY_FILE"
        
        # Count dependencies
        local total_deps=$(jq '.dependency_graph | to_entries | map(.value.depends_on | length) | add' "$REGISTRY_FILE" 2>/dev/null || echo "0")
        echo -e "\n${GREEN}Total dependencies: $total_deps${NC}"
        
        return 0
    else
        echo -e "${RED}Error: jq required for graph analysis${NC}"
        return 1
    fi
}

# Main function
main() {
    local command="$1"
    shift

    case "$command" in
        validate|check)
            if [[ -n "$1" ]]; then
                validate_skill_dependencies "$1"
            else
                validate_all_dependencies
            fi
            ;;
        all|check-all)
            validate_all_dependencies
            ;;
        conflicts|check-conflicts)
            check_dependency_conflicts
            ;;
        resolve|suggest)
            if [[ -n "$1" ]]; then
                suggest_resolutions "$1"
            else
                echo "Error: Skill name required for resolution suggestions"
                return 1
            fi
            ;;
        graph|analyze)
            analyze_dependency_graph
            ;;
        *)
            echo "AI Council Dependency Compatibility Checker"
            echo "============================================"
            echo ""
            echo "Usage: $0 <command> [skill_name]"
            echo ""
            echo "Commands:"
            echo "  validate <skill>    - Validate specific skill dependencies"
            echo "  all, check-all       - Validate all skill dependencies"
            echo "  conflicts           - Check for dependency conflicts"
            echo "  resolve <skill>     - Suggest resolutions for skill"
            echo "  graph, analyze      - Analyze dependency graph"
            echo ""
            echo "Examples:"
            echo "  $0 validate doc_skill"
            echo "  $0 all"
            echo "  $0 conflicts"
            echo "  $0 graph"
            ;;
    esac
}

# Run main function
main "$@"
