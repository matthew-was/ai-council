#!/bin/bash

# Document Change Manager - Main Script
# Coordinates document changes with approval workflows and audit trails

set -e  # Exit on error

# Configuration
SKILL_DIR=".vibe/skills/doc_change_manager"
TEMPLATES_DIR="$SKILL_DIR/templates"
DOCS_DIR="docs"
ARCHIVE_DIR="$DOCS_DIR/archive"
REGISTRY_FILE="$DOCS_DIR/DOCUMENTS.md"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to display confirmation prompt
define_confirm() {
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

# Function to validate document exists
define_validate_document() {
    local doc_name="$1"
    local doc_path="$2"
    
    if [[ ! -f "$doc_path" ]]; then
        echo -e "${RED}Error: Document '$doc_name' not found at $doc_path${NC}"
        return 1
    fi
    
    if [[ ! -s "$doc_path" ]]; then
        echo -e "${RED}Error: Document '$doc_name' is empty${NC}"
        return 1
    fi
    
    return 0
}

# Function to get current version from document
define_get_version() {
    local doc_path="$1"
    
    # Extract version from document (assuming format: ## Document Name vX.X)
    grep -oP '(?<=## .* v)\d+\.\d+' "$doc_path" | head -1 || echo "1.0"
}

# Function to update registry
define_update_registry() {
    local change_request="$1"
    local approval_record="$2"
    local timestamp="$3"
    
    echo -e "\n## Change Log Entry - $timestamp\n" >> "$REGISTRY_FILE"
    echo "- **Change Request $change_request**: Document changes executed" >> "$REGISTRY_FILE"
    echo "- **Approval Record $approval_record**: Changes approved and propagated" >> "$REGISTRY_FILE"
    echo "- **Status**: Completed ✅" >> "$REGISTRY_FILE"
}

# Function to create archive backup
define_create_archive() {
    local doc_name="$1"
    local doc_path="$2"
    local version="$3"
    
    local archive_path="$ARCHIVE_DIR/${doc_name}/v${version}"
    mkdir -p "$archive_path"
    
    cp "$doc_path" "$archive_path/"
    echo -e "${GREEN}Archived $doc_name v$version to $archive_path${NC}"
}

# Notification system function
# Function to notify stakeholders with enhanced notification system
define_notify_stakeholders() {
    local cr_id="$1"
    local doc_name="$2"
    local new_version="$3"
    local success="$4"
    local notification_type="$5"
    
    echo -e "${BLUE}=== NOTIFICATION SYSTEM ===${NC}"
    echo -e "Type: $notification_type"
    
    # Create notifications directory
    local NOTIFICATIONS_DIR="$SKILL_DIR/notifications"
    mkdir -p "$NOTIFICATIONS_DIR"
    
    # Generate notification ID
    local notification_id="NT-$(date +%Y%m%d)%03d"
    local notification_file="$NOTIFICATIONS_DIR/${notification_id}_${cr_id}.md"
    
    # Determine notification details based on type
    local subject=""
    local message=""
    local urgency=""
    local recipients=()
    
    case "$notification_type" in
        "change_submitted")
            subject="📝 Change Request Submitted: $cr_id"
            message="A new change request has been submitted and requires your review."
            urgency="Medium"
            recipients=("architecture_creator" "system_doc_creator")
            ;;
        "approval_granted")
            subject="✅ Change Approved: $cr_id"
            message="Change request $cr_id has been approved and is ready for execution."
            urgency="Medium"
            recipients=("requester" "architecture_creator" "arch_task_generator")
            ;;
        "execution_success")
            subject="🎉 Change Executed Successfully: $cr_id"
            message="Change request $cr_id has been executed. Document $doc_name updated to v$new_version."
            urgency="Low"
            recipients=("requester" "all_agents" "system_admin")
            ;;
        "execution_failed")
            subject="❌ Change Execution Failed: $cr_id"
            message="URGENT: Change request $cr_id failed during execution. Manual intervention required."
            urgency="High"
            recipients=("requester" "architecture_creator" "system_doc_creator" "system_admin")
            ;;
        "rollback_initiated")
            subject="🔙 Rollback Initiated: $cr_id"
            message="Rollback procedure started for failed change $cr_id. System restoring to previous state."
            urgency="High"
            recipients=("all_agents" "system_admin")
            ;;
        *)
            subject="📢 Notification: $cr_id"
            message="Change request $cr_id status updated."
            urgency="Low"
            recipients=("system_admin")
            ;;
    esac
    
    # Create notification record
    cat > "$notification_file" << EOL
## Notification $notification_id

**Timestamp**: $(date +%Y-%m-%d %H:%M:%S)
**Change Request**: $cr_id
**Document**: $doc_name
**Version**: v$new_version
**Type**: $notification_type
**Subject**: $subject
**Urgency**: $urgency
**Status**: $success

### Notification Message
$message

### Details
- **Notification ID**: $notification_id
- **Generated By**: doc_change_manager
- **Generated For**: ${recipients[*]}
- **Change Request**: $cr_id
- **Document**: $doc_name
- **Version**: v$new_version

### Recipients
$(printf "- %s\n" "${recipients[@]}")

### Additional Information
EOL
    
    # Add type-specific information
    if [[ "$notification_type" == "execution_success" || "$notification_type" == "execution_failed" ]]; then
        echo "- Execution Status: $success" >> "$notification_file"
        echo "- New Version: v$new_version" >> "$notification_file"
        echo "- Timestamp: $(date +%Y-%m-%d %H:%M:%S)" >> "$notification_file"
    fi
    
    cat >> "$notification_file" << EOL

### Action Required
$(case "$urgency" in
    "High") echo "IMMEDIATE ACTION REQUIRED";;
    "Medium") echo "Review recommended within 24 hours";;
    "Low") echo "Information only - no action required";;
esac)

### Notification Log
- **Sent**: $(date +%Y-%m-%d %H:%M:%S)
- **Method**: [System Log - would be email/API in production]
- **Status**: Recorded

---
*This is an automated notification from the AI Council Document Change Manager*
EOL
    
    # Display notification summary
    echo -e "${GREEN}✅ Notification $notification_id created${NC}"
    echo "Type: $notification_type"
    echo "Subject: $subject"
    echo "Urgency: $urgency"
    echo "Recipients: ${recipients[*]}"
    echo "File: $notification_file"
    
    # Log to main registry
    echo -e "\n## Notification Log - $(date +%Y-%m-%d)" >> "$REGISTRY_FILE"
    echo "- **Notification $notification_id**: $subject" >> "$REGISTRY_FILE"
    echo "- **Change Request**: $cr_id" >> "$REGISTRY_FILE"
    echo "- **Document**: $doc_name" >> "$REGISTRY_FILE"
    echo "- **Status**: $success" >> "$REGISTRY_FILE"
    echo "- **Urgency**: $urgency" >> "$REGISTRY_FILE"
    
    # In a real implementation, this would send actual notifications
    # For now, we log to console and create notification records
    echo -e "${YELLOW}Notification recorded (would send to ${recipients[*]} in production)${NC}"
    
    return 0
}

# Main workflow functions

# MODE 1: REQUEST - Create change request
define_mode_request() {
    echo -e "${YELLOW}=== MODE 1: REQUEST - Change Request Creation ===${NC}"
    
    # Get change details
    read -p "Document name (System/Architecture/Tasks): " doc_type
    read -p "Current version (e.g., 1.1): " current_version
    read -p "Change description: " change_desc
    read -p "Justification: " justification
    read -p "Requester: " requester
    
    # Validate input
    if [[ -z "$doc_type" || -z "$current_version" || -z "$change_desc" || -z "$justification" || -z "$requester" ]]; then
        echo -e "${RED}Error: All fields are required${NC}"
        return 1
    fi
    
    # Determine document path
    local doc_name=""
    local doc_path=""
    case "$doc_type" in
        "System")
            doc_name="System Document"
            doc_path="$DOCS_DIR/system_document.md"
            ;;
        "Architecture")
            doc_name="Architecture Document"
            doc_path="$DOCS_DIR/architecture_document.md"
            ;;
        "Tasks")
            doc_name="Implementation Tasks"
            doc_path="$DOCS_DIR/implementation_tasks.md"
            ;;
        *)
            echo -e "${RED}Error: Invalid document type${NC}"
            return 1
            ;;
    esac
    
    # Validate document exists
    if ! validate_document "$doc_name" "$doc_path"; then
        return 1
    fi
    
    # Generate change request ID
    local cr_id="CR-$(date +%Y%m%d)%03d"
    
    # Create change request
    local template="$TEMPLATES_DIR/change_request.md"
    local cr_file="$SKILL_DIR/change_requests/${cr_id}.md"
    
    mkdir -p "$SKILL_DIR/change_requests"
    
    cat > "$cr_file" << EOL
## Change Request $cr_id

**Document**: $doc_name
**Current Version**: v$current_version
**Requested Version**: v$((current_version + 0.1))
**Change Type**: Content Update
**Requester**: $requester
**Date**: $(date +%Y-%m-%d)

### Change Description
$change_desc

### Justification
$justification

### Impact Assessment
- **Affected Documents**: $doc_name
- **Change Propagation**: None (single document)
- **Risk Level**: Low
- **Estimated Duration**: 2-5 minutes

### Approval Status
- **Status**: Pending
- **Approver**: 
- **Approval Date**: -
- **Approval Record**: -

### Execution Plan
- [ ] $doc_name v$current_version → v$((current_version + 0.1))
- [ ] Update docs/DOCUMENTS.md registry
- [ ] Archive previous version
EOL
    
    echo -e "${GREEN}Change request $cr_id created successfully${NC}"
    echo "File: $cr_file"
    
    # Confirm submission
    if confirm "Submit change request $cr_id for approval?"; then
        echo -e "${GREEN}Change request $cr_id submitted for approval${NC}"
        
        # Notify stakeholders about new change request
        notify_stakeholders "$cr_id" "$doc_name" "$current_version" "true" "change_submitted"
        
        return 0
    else
        echo -e "${YELLOW}Change request $cr_id saved but not submitted${NC}"
        return 1
    fi
}

# MODE 2: APPROVE - Approve change request
define_mode_approve() {
    echo -e "${YELLOW}=== MODE 2: APPROVE - Change Approval ===${NC}"
    
    # List available change requests
    echo "Available change requests:"
    ls -1 "$SKILL_DIR/change_requests/" 2>/dev/null || echo "No change requests found"
    
    read -p "Enter change request ID (e.g., CR-20260317001): " cr_id
    
    local cr_file="$SKILL_DIR/change_requests/${cr_id}.md"
    
    if [[ ! -f "$cr_file" ]]; then
        echo -e "${RED}Error: Change request $cr_id not found${NC}"
        return 1
    fi
    
    # Extract document info from change request
    local doc_name=$(grep -m1 "Document:" "$cr_file" | sed 's/.*Document: //')
    local current_version=$(grep -m1 "Current Version:" "$cr_file" | sed 's/.*v//')
    local requester=$(grep -m1 "Requester:" "$cr_file" | sed 's/.*Requester: //')
    
    # Display change request details
    echo -e "\n${YELLOW}Change Request Details:${NC}"
    echo "Document: $doc_name"
    echo "Current Version: v$current_version"
    echo "Requested By: $requester"
    
    # Confirm approval
    if confirm "Approve change request $cr_id?"; then
        # Generate approval record ID
        local ar_id="AR-$(date +%Y%m%d)%03d"
        
        # Create approval record
        local ar_file="$SKILL_DIR/approval_records/${ar_id}.md"
        mkdir -p "$SKILL_DIR/approval_records"
        
        cat > "$ar_file" << EOL
## Approval Record $ar_id

**Change Request**: $cr_id
**Document**: $doc_name
**Approver**: ${USER:-unknown}
**Approval Date**: $(date +%Y-%m-%d)
**Decision**: Approved

### Approval Criteria
- [x] Impact assessment reviewed
- [x] Version compatibility confirmed
- [x] Change justification validated
- [x] Risk assessment acceptable

### Approval Details
**Impact Summary**:
- Single document update
- Low risk change
- Estimated duration: 2-5 minutes

**Execution Confirmation**:
- "Execute approved change $cr_id?"
- Response: Pending
- Execution Time: -

### Post-Approval Actions
- [ ] Update change request status to "Approved"
- [ ] Notify requester ($requester)
- [ ] Schedule change propagation
- [ ] Update docs/DOCUMENTS.md registry
EOL
        
        # Update change request status
        sed -i 's/- **Status**: Pending/- **Status**: Approved/' "$cr_file"
        sed -i "s/- **Approver**:/- **Approver**: ${USER:-unknown}/" "$cr_file"
        sed -i "s/- **Approval Date**: -/- **Approval Date**: $(date +%Y-%m-%d)/" "$cr_file"
        sed -i "s/- **Approval Record**: -/- **Approval Record**: $ar_id/" "$cr_file"
        
        # Notify stakeholders about approval
        notify_stakeholders "$cr_id" "$doc_name" "$new_version" "true" "approval_granted"
        
        echo -e "${GREEN}Change request $cr_id approved (Approval Record: $ar_id)${NC}"
        echo "Approval record: $ar_file"
        return 0
    else
        echo -e "${YELLOW}Change request $cr_id not approved${NC}"
        return 1
    fi
}

# MODE 3: PROPAGATE - Execute approved changes
define_mode_propagate() {
    echo -e "${YELLOW}=== MODE 3: PROPAGATE - Change Execution ===${NC}"
    
    # List approved change requests
    echo "Approved change requests:"
    grep -l "Status: Approved" "$SKILL_DIR/change_requests/" 2>/dev/null | xargs -n1 basename || echo "No approved change requests found"
    
    read -p "Enter approved change request ID: " cr_id
    
    local cr_file="$SKILL_DIR/change_requests/${cr_id}.md"
    
    if [[ ! -f "$cr_file" ]]; then
        echo -e "${RED}Error: Change request $cr_id not found${NC}"
        return 1
    fi
    
    # Check if approved
    if ! grep -q "Status: Approved" "$cr_file"; then
        echo -e "${RED}Error: Change request $cr_id is not approved${NC}"
        return 1
    fi
    
    # Extract change details
    local doc_name=$(grep -m1 "Document:" "$cr_file" | sed 's/.*Document: //')
    local current_version=$(grep -m1 "Current Version:" "$cr_file" | sed 's/.*v//')
    local new_version=$((current_version + 0.1))
    
    # Determine document path
    local doc_path=""
    case "$doc_name" in
        "System Document")
            doc_path="$DOCS_DIR/system_document.md"
            ;;
        "Architecture Document")
            doc_path="$DOCS_DIR/architecture_document.md"
            ;;
        "Implementation Tasks")
            doc_path="$DOCS_DIR/implementation_tasks.md"
            ;;
        *)
            echo -e "${RED}Error: Unknown document type: $doc_name${NC}"
            return 1
            ;;
    esac
    
    # Validate document exists
    if ! validate_document "$doc_name" "$doc_path"; then
        return 1
    fi
    
    echo -e "\n${YELLOW}Change Execution Plan:${NC}"
    echo "Document: $doc_name"
    echo "Current Version: v$current_version"
    echo "New Version: v$new_version"
    echo "Change Request: $cr_id"
    
    # Confirm execution
    if confirm "Execute approved change $cr_id?"; then
        # Create archive backup
        create_archive "$doc_name" "$doc_path" "$current_version"
        
        # Update document version (simplified - actual implementation would modify document)
        echo -e "\n---\n## Version Update\n**Previous Version**: v$current_version\n**New Version**: v$new_version\n**Change Request**: $cr_id\n**Update Date**: $(date +%Y-%m-%d)" >> "$doc_path"
        
        # Update registry
        update_registry "$cr_id" "$ar_id" "$(date +%Y-%m-%d)"
        
        # Update change request
        sed -i "s/- \[\] $doc_name v$current_version → v$new_version/- [x] $doc_name v$current_version → v$new_version/" "$cr_file"
        sed -i "s/- \[\] Update docs\/DOCUMENTS.md registry/- [x] Update docs\/DOCUMENTS.md registry/" "$cr_file"
        sed -i "s/- \[\] Archive previous version/- [x] Archive previous version/" "$cr_file"
        
        echo -e "${GREEN}Change $cr_id executed successfully${NC}"
        echo "$doc_name updated from v$current_version to v$new_version"
        return 0
    else
        echo -e "${YELLOW}Change execution cancelled${NC}"
        return 1
    fi
}

# Main script execution
main() {
    echo -e "${YELLOW}Document Change Manager v1.0${NC}"
    echo "================================"
    
    # Check if skill directory exists
    if [[ ! -d "$SKILL_DIR" ]]; then
        echo -e "${RED}Error: Skill directory not found: $SKILL_DIR${NC}"
        exit 1
    fi
    
    # Create necessary directories
    mkdir -p "$SKILL_DIR/change_requests"
    mkdir -p "$SKILL_DIR/approval_records"
    mkdir -p "$ARCHIVE_DIR"
    
    # Display menu
    echo -e "\nAvailable Modes:"
    echo "1. REQUEST - Create change request"
    echo "2. APPROVE - Approve change request"
    echo "3. PROPAGATE - Execute approved changes"
    echo "4. EXIT"
    
    read -p "Select mode (1-4): " mode
    
    case "$mode" in
        1)
            mode_request
            ;;
        2)
            mode_approve
            ;;
        3)
            mode_propagate
            ;;
        4)
            echo "Exiting Document Change Manager"
            exit 0
            ;;
        *)
            echo -e "${RED}Error: Invalid mode selected${NC}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"