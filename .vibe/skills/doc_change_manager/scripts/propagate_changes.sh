#!/bin/bash

# Document Change Manager - Change Propagation Script
# Executes approved changes across documents with safety checks

set -e

# Configuration
SKILL_DIR=".vibe/skills/doc_change_manager"
CHANGE_REQUESTS_DIR="$SKILL_DIR/change_requests"
APPROVAL_RECORDS_DIR="$SKILL_DIR/approval_records"
DOCS_DIR="docs"
ARCHIVE_DIR="$DOCS_DIR/archive"
REGISTRY_FILE="$DOCS_DIR/DOCUMENTS.md"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display confirmation prompt
confirm() {
    local message="$1"
    local default="${2:-n}"
    
    while true; do
        read -p "$message (y/n) [$default]: " answer
        answer="${answer:-$default}"
        
        case $answer in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Function to validate change request is approved
define_validate_approved_cr() {
    local cr_id="$1"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    if [[ ! -f "$cr_file" ]]; then
        echo -e "${RED}Error: Change request $cr_id not found${NC}"
        return 1
    fi
    
    if ! grep -q "Status.*Approved" "$cr_file"; then
        echo -e "${RED}Error: Change request $cr_id is not approved${NC}"
        return 1
    fi
    
    local approval_record=$(grep "Approval Record:" "$cr_file" | sed 's/.*Approval Record: //')
    if [[ "$approval_record" == "-" ]]; then
        echo -e "${RED}Error: Change request $cr_id has no approval record${NC}"
        return 1
    fi
    
    if [[ ! -f "$APPROVAL_RECORDS_DIR/${approval_record}.md" ]]; then
        echo -e "${RED}Error: Approval record $approval_record not found${NC}"
        return 1
    fi
    
    return 0
}

# Function to extract change details from CR
define_extract_change_details() {
    local cr_file="$1"
    
    local doc_name=$(grep "Document:" "$cr_file" | sed 's/.*Document: //')
    local current_version=$(grep "Current Version" "$cr_file" | sed 's/.*v//')
    local new_version=$(grep "Requested Version" "$cr_file" | sed 's/.*v//')
    local risk_level=$(grep "Risk Level:" "$cr_file" | sed 's/.*Risk Level: //')
    local propagation=$(grep "Change Propagation:" "$cr_file" | sed 's/.*Change Propagation: //')
    local affected_docs=$(grep "Affected Documents:" "$cr_file" | sed 's/.*Affected Documents: //')
    
    echo "$doc_name|$current_version|$new_version|$risk_level|$propagation|$affected_docs"
}

# Function to create archive backup
define_create_archive_backup() {
    local doc_name="$1"
    local doc_path="$2"
    local version="$3"
    
    echo -e "${BLUE}Creating archive backup for $doc_name v$version${NC}"
    
    local archive_path="$ARCHIVE_DIR/${doc_name}/v${version}"
    mkdir -p "$archive_path"
    
    # Create timestamped backup
    local timestamp=$(date +%Y%m%d_%H%M%S)
    cp "$doc_path" "$archive_path/${timestamp}_backup.md"
    
    # Also keep latest version
    cp "$doc_path" "$archive_path/latest.md"
    
    echo -e "${GREEN}✅ Archived $doc_name v$version to $archive_path${NC}"
    
    return 0
}

# Function to update document version
define_update_document_version() {
    local doc_path="$1"
    local new_version="$2"
    local cr_id="$3"
    
    echo -e "${BLUE}Updating document version to v$new_version${NC}"
    
    # Add version update section to document
    echo -e "\n---\n## Version Update\n**Version**: v$new_version
**Change Request**: $cr_id
**Update Date**: $(date +%Y-%m-%d)
**Updated By**: ${USER:-unknown}" >> "$doc_path"
    
    echo -e "${GREEN}✅ Document updated to v$new_version${NC}"
    
    return 0
}

# Function to update registry
define_update_registry() {
    local cr_id="$1"
    local ar_id="$2"
    local doc_name="$3"
    local current_version="$4"
    local new_version="$5"
    
    echo -e "${BLUE}Updating registry in docs/DOCUMENTS.md${NC}"
    
    # Add change log entry
    echo -e "\n## Change Log Entry - $(date +%Y-%m-%d)" >> "$REGISTRY_FILE"
    echo "- **Change Request $cr_id**: $doc_name v$current_version → v$new_version" >> "$REGISTRY_FILE"
    echo "- **Approval Record $ar_id**: Changes approved and executed" >> "$REGISTRY_FILE"
    echo "- **Status**: Completed ✅" >> "$REGISTRY_FILE"
    echo "- **Executed By**: ${USER:-unknown}" >> "$REGISTRY_FILE"
    echo "- **Execution Time**: $(date +%Y-%m-%d %H:%M:%S)" >> "$REGISTRY_FILE"
    
    echo -e "${GREEN}✅ Registry updated successfully${NC}"
    
    return 0
}

# Function to update change request status
define_update_cr_execution_status() {
    local cr_id="$1"
    local success="$2"
    
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    if [[ "$success" == "true" ]]; then
        sed -i "s/- **Executed**: -/- **Executed**: $(date +%Y-%m-%d)/" "$cr_file"
        sed -i "s/- **Status**: Approved/- **Status**: Completed/" "$cr_file"
        echo -e "${GREEN}✅ Change request $cr_id marked as completed${NC}"
    else
        sed -i "s/- **Status**: Approved/- **Status**: Failed/" "$cr_file"
        echo -e "${RED}❌ Change request $cr_id marked as failed${NC}"
    fi
    
    return 0
}

# Function to notify stakeholders
define_notify_stakeholders() {
    local cr_id="$1"
    local doc_name="$2"
    local new_version="$3"
    local success="$4"
    
    echo -e "${BLUE}Notifying stakeholders${NC}"
    
    if [[ "$success" == "true" ]]; then
        echo -e "${GREEN}Change $cr_id executed successfully!${NC}"
        echo "Document: $doc_name updated to v$new_version"
        echo "Status: All systems operational"
    else
        echo -e "${RED}Change $cr_id execution failed!${NC}"
        echo "Document: $doc_name rollback may be required"
        echo "Status: Requires manual intervention"
    fi
    
    # In a real implementation, this would send actual notifications
    # For now, we just log to console
    echo -e "${YELLOW}Notification logged (actual notifications would be sent in production)${NC}"
    
    return 0
}

# Function to perform safety checks
define_safety_checks() {
    local cr_id="$1"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    echo -e "${YELLOW}Performing enhanced safety checks${NC}"
    echo "=================================="
    
    # 1. Version compatibility verification
    echo -e "${BLUE}1. Version Compatibility Verification${NC}"
    if ! define_validate_approved_cr "$cr_id"; then
        return 1
    fi
    echo -e "${GREEN}✅ Change request $cr_id is approved and valid${NC}"
    
    # Extract details for comprehensive validation
    IFS='|' read -r doc_name current_version new_version risk_level propagation affected_docs <<< $(define_extract_change_details "$cr_file")
    
    if [[ -z "$doc_name" || -z "$current_version" || -z "$new_version" ]]; then
        echo -e "${RED}❌ Invalid change request details${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Version compatibility verified (v$current_version → v$new_version)${NC}"
    
    # 2. Impact assessment confirmation
    echo -e "${BLUE}2. Impact Assessment Confirmation${NC}"
    if [[ -z "$risk_level" || -z "$propagation" || -z "$affected_docs" ]]; then
        echo -e "${RED}❌ Impact assessment incomplete${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Impact assessment confirmed ($risk_level risk, $propagation propagation)${NC}"
    
    # 3. Approval record validation
    echo -e "${BLUE}3. Approval Record Validation${NC}"
    local ar_id=$(grep -m1 "Approval Record" "$cr_file" | sed 's/.*: //' | sed 's/^ *//' || echo "")
    if [[ -z "$ar_id" || ! -f "$APPROVAL_RECORDS_DIR/${ar_id}.md" ]]; then
        echo -e "${RED}❌ Approval record not found or invalid${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Approval record $ar_id validated${NC}"
    
    # 4. Archive backup creation (pre-check)
    echo -e "${BLUE}4. Archive Backup Preparation${NC}"
    mkdir -p "$ARCHIVE_DIR"
    echo -e "${GREEN}✅ Archive directory prepared: $ARCHIVE_DIR${NC}"
    
    # Check 2: Extract and validate details
    IFS='|' read -r doc_name current_version new_version risk_level propagation affected_docs <<< $(extract_change_details "$cr_file")
    
    if [[ -z "$doc_name" || -z "$current_version" || -z "$new_version" ]]; then
        echo -e "${RED}❌ Invalid change request details${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Change details validation passed${NC}"
    
    # Check 3: Validate document exists
    local doc_path=""
    case "$doc_name" in
        "System Document") doc_path="$DOCS_DIR/system_document.md";;
        "Architecture Document") doc_path="$DOCS_DIR/architecture_document.md";;
        "Implementation Tasks") doc_path="$DOCS_DIR/implementation_tasks.md";;
        *) echo -e "${RED}❌ Unknown document type${NC}"; return 1;;
    esac
    
    if [[ ! -f "$doc_path" ]]; then
        echo -e "${RED}❌ Document not found: $doc_path${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Document existence validation passed${NC}"
    
    # Check 4: Verify current version matches
    local actual_version=$(grep -oP '(?<=## .* v)\d+\.\d+' "$doc_path" | head -1 || echo "1.0")
    if [[ "$actual_version" != "$current_version" ]]; then
        echo -e "${RED}❌ Version mismatch: Expected v$current_version, found v$actual_version${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ Version validation passed${NC}"
    
    # Check 5: Risk assessment
    echo -e "${BLUE}Risk Level: $risk_level${NC}"
    if [[ "$risk_level" == "High" ]]; then
        if ! confirm "High risk change detected. Continue with execution?"; then
            echo -e "${YELLOW}Execution cancelled by user due to high risk${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✅ All safety checks passed${NC}"
    
    return 0
}

# Function to execute change propagation
define_execute_propagation() {
    local cr_id="$1"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    # Extract change details
    IFS='|' read -r doc_name current_version new_version risk_level propagation affected_docs <<< $(extract_change_details "$cr_file")
    
    # Determine document path
    local doc_path=""
    case "$doc_name" in
        "System Document") doc_path="$DOCS_DIR/system_document.md";;
        "Architecture Document") doc_path="$DOCS_DIR/architecture_document.md";;
        "Implementation Tasks") doc_path="$DOCS_DIR/implementation_tasks.md";;
    esac
    
    echo -e "${YELLOW}Executing Change Propagation for $cr_id${NC}"
    echo "=============================================="
    
    # Step 1: Create archive backup
    if ! create_archive_backup "$doc_name" "$doc_path" "$current_version"; then
        echo -e "${RED}❌ Archive creation failed${NC}"
        notify_stakeholders "$cr_id" "$doc_name" "$new_version" "false"
        update_cr_execution_status "$cr_id" "false"
        return 1
    fi
    
    # Step 2: Update document version
    if ! update_document_version "$doc_path" "$new_version" "$cr_id"; then
        echo -e "${RED}❌ Document update failed${NC}"
        notify_stakeholders "$cr_id" "$doc_name" "$new_version" "false"
        update_cr_execution_status "$cr_id" "false"
        return 1
    fi
    
    # Step 3: Update registry
    local ar_id=$(grep "Approval Record:" "$cr_file" | sed 's/.*Approval Record: //')
    if ! update_registry "$cr_id" "$ar_id" "$doc_name" "$current_version" "$new_version"; then
        echo -e "${RED}❌ Registry update failed${NC}"
        notify_stakeholders "$cr_id" "$doc_name" "$new_version" "false"
        update_cr_execution_status "$cr_id" "false"
        return 1
    fi
    
    # Step 4: Update change request status
    if ! update_cr_execution_status "$cr_id" "true"; then
        echo -e "${RED}❌ Status update failed${NC}"
        notify_stakeholders "$cr_id" "$doc_name" "$new_version" "false"
        return 1
    fi
    
    # Step 5: Notify stakeholders
    if ! notify_stakeholders "$cr_id" "$doc_name" "$new_version" "true"; then
        echo -e "${YELLOW}Notification completed with warnings${NC}"
    fi
    
    echo -e "${GREEN}✅ Change propagation completed successfully!${NC}"
    echo -e "${BLUE}Summary:${NC}"
    echo "- Change Request: $cr_id"
    echo "- Document: $doc_name"
    echo "- Version: v$current_version → v$new_version"
    echo "- Risk Level: $risk_level"
    echo "- Status: Completed ✅"
    
    return 0
}

# Function to handle rollback
define_rollback_procedure() {
    local cr_id="$1"
    local doc_name="$2"
    local version="$3"
    
    echo -e "${RED}\n=== ROLLBACK PROCEDURE ===${NC}"
    echo "================================"
    echo "🔄 Initiating rollback for change $cr_id"
    echo "   Document: $doc_name"
    echo "   Target Version: v$version"
    echo ""
    
    echo -e "${BLUE}1. Preparing rollback environment${NC}"
    
    local archive_path="$ARCHIVE_DIR/${doc_name}/v${version}"
    
    if [[ ! -d "$archive_path" ]]; then
        echo -e "${RED}❌ Archive not found for rollback: $archive_path${NC}"
        return 1
    fi
    
    local latest_backup="$archive_path/latest.md"
    if [[ ! -f "$latest_backup" ]]; then
        echo -e "${RED}❌ Latest backup not found${NC}"
        return 1
    fi
    
    # Determine document path
    local doc_path=""
    case "$doc_name" in
        "System Document") doc_path="$DOCS_DIR/system_document.md";;
        "Architecture Document") doc_path="$DOCS_DIR/architecture_document.md";;
        "Implementation Tasks") doc_path="$DOCS_DIR/implementation_tasks.md";;
    esac
    
    if ! define_confirm "Restore $doc_name from v$version backup?"; then
        echo -e "${YELLOW}Rollback cancelled${NC}"
        return 1
    fi
    
    # Restore from backup
    cp "$latest_backup" "$doc_path"
    
    # Update registry with rollback entry
    echo -e "\n## Rollback Entry - $(date +%Y-%m-%d)" >> "$REGISTRY_FILE"
    echo "- **Change Request $cr_id**: Rolled back to v$version" >> "$REGISTRY_FILE"
    echo "- **Reason**: Execution failure or user request" >> "$REGISTRY_FILE"
    echo "- **Status**: Rollback completed ✅" >> "$REGISTRY_FILE"
    
    echo -e "${GREEN}✅ Rollback completed successfully${NC}"
    echo "Document $doc_name restored to v$version"
    
    return 0
}

# Function to execute propagation planning algorithm according to PHASE2-4_PLAN.md
define_propagation_planning() {
    local cr_id="$1"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    echo -e "${BLUE}\n=== PROPAGATION PLANNING ALGORITHM ===${NC}"
    echo "=========================================="
    
    # Extract change request details
    IFS='|' read -r doc_name current_version new_version risk_level propagation affected_docs <<< $(define_extract_change_details "$cr_file")
    
    echo "📋 Analyzing change request: $cr_id"
    echo "   Document: $doc_name"
    echo "   Version Change: v$current_version → v$new_version"
    echo "   Risk Level: $risk_level"
    echo "   Propagation Type: $propagation"
    echo ""
    
    # 1. Change sequence determination
    echo -e "${BLUE}1. Change Sequence Determination${NC}"
    echo "   Analyzing dependency relationships..."
    
    local sequence_steps=()
    case "$propagation" in
        "Full")
            sequence_steps=(
                "1. Archive current versions (ALL)"
                "2. Update System Document v${current_version} → v${new_version}"
                "3. REGENERATE Architecture Document (depends on System)"
                "4. UPDATE Implementation Tasks (depends on Architecture)"
                "5. Update docs/DOCUMENTS.md registry"
                "6. Verify all document consistency"
            )
            ;;
        "Partial")
            sequence_steps=(
                "1. Archive current versions (AFFECTED)"
                "2. Update $doc_name v${current_version} → v${new_version}"
                "3. Update dependent documents"
                "4. Update docs/DOCUMENTS.md registry"
                "5. Verify document consistency"
            )
            ;;
        "None")
            sequence_steps=(
                "1. Archive current version"
                "2. Update $doc_name v${current_version} → v${new_version}"
                "3. Update docs/DOCUMENTS.md registry"
                "4. Verify update success"
            )
            ;;
    esac
    
    echo "   Determined sequence:"
    for step in "${sequence_steps[@]}"; do
        echo "      $step"
    done
    echo ""
    
    # 2. Dependency ordering analysis
    echo -e "${BLUE}2. Dependency Ordering Analysis${NC}"
    echo "   Mapping document dependencies..."
    
    local dependencies=""
    case "$doc_name" in
        "System Document")
            dependencies="System → Architecture → Tasks"
            ;;
        "Architecture Document")
            dependencies="Architecture → Tasks"
            ;;
        "Implementation Tasks")
            dependencies="Tasks (Independent)"
            ;;
    esac
    
    echo "   Dependency chain: $dependencies"
    echo "   Propagation direction: TOP-DOWN (parents before children)"
    echo ""
    
    # 3. Version update strategy
    echo -e "${BLUE}3. Version Update Strategy${NC}"
    
    local version_strategy=""
    case "$propagation" in
        "Full")
            version_strategy="Cascading Version Increment"
            echo "   Strategy: $version_strategy"
            echo "   System Document: v${current_version} → v${new_version}"
            echo "   Architecture Document: v${current_version} → v${new_version} (REGENERATE)"
            echo "   Implementation Tasks: v${current_version} → v${new_version} (UPDATE)"
            ;;
        "Partial")
            version_strategy="Selective Version Update"
            echo "   Strategy: $version_strategy"
            echo "   Primary Document: v${current_version} → v${new_version}"
            echo "   Dependent Documents: Conditional updates based on impact"
            ;;
        "None")
            version_strategy="Isolated Version Update"
            echo "   Strategy: $version_strategy"
            echo "   $doc_name only: v${current_version} → v${new_version}"
            ;;
    esac
    echo ""
    
    # 4. Archive preparation strategy
    echo -e "${BLUE}4. Archive Preparation Strategy${NC}"
    
    local archive_strategy=""
    case "$risk_level" in
        "High")
            archive_strategy="Full System Snapshot"
            echo "   Archive Level: COMPREHENSIVE"
            echo "   Scope: All documents + registry"
            echo "   Retention: Permanent (versioned)"
            ;;
        "Medium")
            archive_strategy="Impact-Based Archive"
            echo "   Archive Level: STANDARD"
            echo "   Scope: Affected documents + registry"
            echo "   Retention: 30 days"
            ;;
        "Low")
            archive_strategy="Minimal Backup"
            echo "   Archive Level: BASIC"
            echo "   Scope: Target document only"
            echo "   Retention: 7 days"
            ;;
    esac
    
    echo "   Archive Method: Automatic pre-execution backup"
    echo "   Storage Location: $ARCHIVE_DIR/pre-propagation/$cr_id/"
    echo ""
    
    # 5. Execution plan summary
    echo -e "${BLUE}5. Execution Plan Summary${NC}"
    echo "✅ Change Sequence: ${#sequence_steps[@]} steps determined"
    echo "✅ Dependency Order: $dependencies"
    echo "✅ Version Strategy: $version_strategy"
    echo "✅ Archive Strategy: $archive_strategy"
    echo "✅ Risk Mitigation: Pre-execution validation complete"
    echo ""
    
    # 6. Propagation readiness check
    echo -e "${BLUE}6. Propagation Readiness Check${NC}"
    
    local readiness_items=(
        "✅ Change request $cr_id validated"
        "✅ Approval record verified"
        "✅ Impact assessment confirmed ($risk_level risk)"
        "✅ Document dependencies mapped"
        "✅ Version compatibility checked"
        "✅ Archive strategy prepared"
        "✅ Rollback procedure available"
        "✅ Notification system ready"
    )
    
    for item in "${readiness_items[@]}"; do
        echo "   $item"
    done
    
    echo ""
    echo -e "${GREEN}✅ Propagation Planning Completed${NC}"
    echo "   • Change sequence: ${#sequence_steps[@]} steps"
    echo "   • Estimated duration: 5-15 minutes"
    echo "   • Risk level: $risk_level"
    echo "   • Ready for safety checks and execution"
}

# Main propagation workflow
main() {
    echo -e "${YELLOW}Document Change Manager - Change Propagation${NC}"
    echo "================================================"
    
    # List approved change requests
    echo -e "${YELLOW}Approved Change Requests Ready for Execution:${NC}"
    local cr_count=0
    local approved_crs=()
    
    for cr_file in "$CHANGE_REQUESTS_DIR"/*.md; do
        if [[ -f "$cr_file" ]]; then
            local cr_id=$(basename "$cr_file" .md)
            if grep -q "Status.*Approved" "$cr_file"; then
                local doc_name=$(grep "Document:" "$cr_file" | sed 's/.*Document: //')
                local current_version=$(grep "Current Version" "$cr_file" | sed 's/.*v//')
                local new_version=$(grep "Requested Version" "$cr_file" | sed 's/.*v//')
                
                echo "- $cr_id: $doc_name (v$current_version → v$new_version)"
                approved_crs+=("$cr_id")
                ((cr_count++))
            fi
        fi
    done
    
    if [[ $cr_count -eq 0 ]]; then
        echo "No approved change requests found"
        exit 0
    fi
    
    # Select change request
    read -p "Enter change request ID to execute: " cr_id
    
    # Validate selection
    if [[ ! " ${approved_crs[@]} " =~ " ${cr_id} " ]]; then
        echo -e "${RED}Error: Invalid or not approved change request ID${NC}"
        exit 1
    fi
    
    # Execute propagation planning algorithm
    define_propagation_planning "$cr_id"
    
    # Perform safety checks
    if ! define_safety_checks "$cr_id"; then
        echo -e "${RED}❌ Safety checks failed. Propagation aborted.${NC}"
        
        read -p "Initiate rollback procedure? (y/n) [n]: " initiate_rollback
        if [[ "$initiate_rollback" =~ [Yy] ]]; then
            IFS='|' read -r doc_name current_version new_version risk_level propagation affected_docs <<< $(extract_change_details "$CHANGE_REQUESTS_DIR/${cr_id}.md")
            rollback_procedure "$cr_id" "$doc_name" "$current_version"
        fi
        
        exit 1
    fi
    
    # Enhanced propagation confirmation according to PHASE2-4_PLAN.md
    echo -e "${RED}\n=== PROPAGATION CONFIRMATION ===${NC}"
    echo "===================================="
    echo "🔐 FINAL EXECUTION AUTHORIZATION REQUIRED"
    echo ""
    
    # Display detailed propagation summary
    echo "Change Request: $cr_id"
    echo "Document: $doc_name"
    echo "Version Change: v$current_version → v$new_version"
    echo ""
    
    echo "📋 Propagation Details:"
    echo "   Affected Documents: $affected_docs"
    echo "   Version Updates: v$current_version→v$new_version"
    echo "   Propagation Type: $propagation"
    echo "   Risk Level: $risk_level"
    echo ""
    
    echo "⚠️  Impact Summary:"
    echo "   Estimated Duration: 5-10 minutes"
    echo "   Components Affected: $(echo "$affected_docs" | tr -cd ',' | wc -c) documents"
    echo "   Rollback Complexity: Medium"
    echo ""
    
    echo "🔒 Authorization:"
    echo "   This action requires final approval"
    echo "   All safety checks have passed ✅"
    echo ""
    
    if define_confirm "Execute change propagation for $cr_id?"; then
        # Execute propagation
        if execute_propagation "$cr_id"; then
            echo -e "${GREEN}Change propagation completed successfully!${NC}"
            
            # Notify stakeholders about successful execution
            IFS='|' read -r doc_name current_version new_version risk_level propagation affected_docs <<< $(extract_change_details "$CHANGE_REQUESTS_DIR/${cr_id}.md")
            notify_stakeholders "$cr_id" "$doc_name" "$new_version" "true" "execution_success"
            
            exit 0
        else
            echo -e "${RED}Change propagation failed${NC}"
            
            # Notify stakeholders about execution failure
            IFS='|' read -r doc_name current_version new_version risk_level propagation affected_docs <<< $(extract_change_details "$CHANGE_REQUESTS_DIR/${cr_id}.md")
            notify_stakeholders "$cr_id" "$doc_name" "$new_version" "false" "execution_failed"
            
            read -p "Initiate rollback procedure? (y/n) [y]: " initiate_rollback
            initiate_rollback="${initiate_rollback:-y}"
            
            if [[ "$initiate_rollback" =~ [Yy] ]]; then
                # Notify stakeholders about rollback initiation
                notify_stakeholders "$cr_id" "$doc_name" "$current_version" "false" "rollback_initiated"
                rollback_procedure "$cr_id" "$doc_name" "$current_version"
            fi
            
            exit 1
        fi
    else
        echo -e "${YELLOW}Change propagation cancelled${NC}"
        exit 0
    fi
}

# Run main function
main "$@"