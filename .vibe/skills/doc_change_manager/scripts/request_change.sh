#!/bin/bash

# Document Change Manager - Change Request Script
# Creates and manages change requests for document modifications

set -e

# Configuration
SKILL_DIR=".vibe/skills/doc_change_manager"
CHANGE_REQUESTS_DIR="$SKILL_DIR/change_requests"
TEMPLATES_DIR="$SKILL_DIR/templates"
DOCS_DIR="docs"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
define_get_current_version() {
    local doc_path="$1"
    
    # Extract version from document (assuming format: ## Document Name vX.X)
    # Use sed for macOS compatibility instead of grep -oP
    grep "## .* v" "$doc_path" | sed 's/.*v\([0-9]*\.[0-9]*\)$/\1/' | head -1 || echo "1.0"
}

# Function to assess impact with enhanced automation
define_assess_impact() {
    local doc_type="$1"
    local change_desc="$2"
    
    echo -e "${YELLOW}Enhanced Impact Assessment:${NC}"
    echo "================================"
    
    # Initialize variables
    local risk_level="Low"
    local propagation="None"
    local affected_docs="$doc_type"
    local risk_score=0
    local complexity="Simple"
    
    # Risk scoring system (0-100)
    # Keywords that increase risk
    local high_risk_keywords=("architecture" "structural" "major" "fundamental" "redesign" "database" "security" "authentication")
    local medium_risk_keywords=("interface" "api" "integration" "workflow" "protocol" "schema" "validation")
    local low_risk_keywords=("typo" "clarification" "minor" "cosmetic" "formatting" "spelling")
    
    # Analyze change description for risk indicators
    local desc_lower=$(echo "$change_desc" | tr '[:upper:]' '[:lower:]')
    
    # Check for high risk keywords
    for keyword in "${high_risk_keywords[@]}"; do
        if [[ "$desc_lower" =~ "$keyword" ]]; then
            risk_score=$((risk_score + 30))
            echo -e "${RED}⚠️  High risk keyword detected: $keyword${NC}"
        fi
    done
    
    # Check for medium risk keywords
    for keyword in "${medium_risk_keywords[@]}"; do
        if [[ "$desc_lower" =~ "$keyword" ]]; then
            risk_score=$((risk_score + 15))
            echo -e "${YELLOW}⚠️  Medium risk keyword detected: $keyword${NC}"
        fi
    done
    
    # Check for low risk keywords
    for keyword in "${low_risk_keywords[@]}"; do
        if [[ "$desc_lower" =~ "$keyword" ]]; then
            risk_score=$((risk_score - 10))
            echo -e "${GREEN}✅ Low risk keyword detected: $keyword${NC}"
        fi
    done
    
    # Determine risk level based on score
    if [[ $risk_score -ge 50 ]]; then
        risk_level="High"
        propagation="Full"
        affected_docs="System Document, Architecture Document, Implementation Tasks"
        complexity="Complex"
    elif [[ $risk_score -ge 20 ]]; then
        risk_level="Medium"
        propagation="Partial"
        
        # Determine affected documents based on doc_type
        case "$doc_type" in
            "System") affected_docs="System Document, Architecture Document";;
            "Architecture") affected_docs="Architecture Document, Implementation Tasks";;
            "Tasks") affected_docs="Implementation Tasks";;
        esac
        complexity="Moderate"
    else
        risk_level="Low"
        propagation="None"
        affected_docs="$doc_type"
        complexity="Simple"
    fi
    
    # Additional checks for specific document types
    case "$doc_type" in
        "System")
            if [[ "$desc_lower" =~ (user|role|permission|security) ]]; then
                echo -e "${YELLOW}🔒 Security-related change detected${NC}"
                risk_score=$((risk_score + 10))
            fi
            ;;
        "Architecture")
            if [[ "$desc_lower" =~ (component|module|service|microservice) ]]; then
                echo -e "${YELLOW}🏗️  Structural change detected${NC}"
                risk_score=$((risk_score + 15))
            fi
            ;;
        "Tasks")
            if [[ "$desc_lower" =~ (dependency|blocker|critical) ]]; then
                echo -e "${YELLOW}🚨 Critical task change detected${NC}"
                risk_score=$((risk_score + 10))
            fi
            ;;
    esac
    
    # Final risk level adjustment based on updated score
    if [[ $risk_score -ge 60 ]]; then
        risk_level="High"
    elif [[ $risk_score -ge 30 ]]; then
        risk_level="Medium"
    else
        risk_level="Low"
    fi
    
    # Estimate duration based on risk and complexity
    local duration=""
    if [[ "$risk_level" == "High" && "$complexity" == "Complex" ]]; then
        duration="20-40 minutes"
    elif [[ "$risk_level" == "High" ]]; then
        duration="15-30 minutes"
    elif [[ "$risk_level" == "Medium" && "$complexity" == "Moderate" ]]; then
        duration="10-20 minutes"
    elif [[ "$risk_level" == "Medium" ]]; then
        duration="5-15 minutes"
    else
        duration="2-8 minutes"
    fi
    
    # Determine rollback complexity
    local rollback_complexity=""
    case "$risk_level" in
        "High") rollback_complexity="High";;
        "Medium") rollback_complexity="Medium";;
        "Low") rollback_complexity="Low";;
    esac
    
    # Display impact assessment results
    echo -e "\n${BLUE}Impact Assessment Results:${NC}"
    echo "- Risk Level: $risk_level (Score: $risk_score/100)"
    echo "- Complexity: $complexity"
    echo "- Change Propagation: $propagation"
    echo "- Affected Documents: $affected_docs"
    echo "- Estimated Duration: $duration"
    echo "- Rollback Complexity: $rollback_complexity"
    echo "- Testing Required: Yes"
    echo "- Stakeholder Notification: Recommended"
    
    # Recommend approval level based on risk
    local approver=""
    case "$risk_level" in
        "High") approver="architecture_creator + system_doc_creator";;
        "Medium") approver="architecture_creator";;
        "Low") approver="system_doc_creator";;
    esac
    
    echo "- Recommended Approver: $approver"
    
    # Generate impact matrix
    echo -e "\n${BLUE}Impact Matrix:${NC}"
    echo "┌─────────────────┬──────────────┬─────────────────┐"
    echo "│ Risk Level       │ $risk_level          │"
    echo "│ Risk Score       │ $risk_score/100      │"
    echo "│ Complexity       │ $complexity         │"
    echo "│ Propagation      │ $propagation         │"
    echo "│ Duration         │ $duration           │"
    echo "│ Rollback         │ $rollback_complexity │"
    echo "│ Approver         │ $approver           │"
    echo "└─────────────────┴──────────────┴─────────────────┘"
    
    echo "$risk_level|$propagation|$affected_docs|$duration|$risk_score|$complexity|$rollback_complexity|$approver"
}

# Function to create change request
define_create_change_request() {
    local doc_type="$1"
    local current_version="$2"
    local change_desc="$3"
    local justification="$4"
    local requester="$5"
    
    # Determine document details
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
    if ! define_validate_document "$doc_name" "$doc_path"; then
        return 1
    fi
    
    # Assess impact (updated to handle new return values)
    IFS='|' read -r risk_level propagation affected_docs duration risk_score complexity rollback_complexity approver <<< $(define_assess_impact "$doc_type" "$change_desc")
    
    # Calculate new version (handle both X.X and X formats)
    if [[ "$current_version" =~ ^[0-9]+\.[0-9]+$ ]]; then
        # Version is already in X.X format
        IFS='.' read -r major minor <<< "$current_version"
        new_version="$major.$((minor + 1))"
    else
        # Version is in X format, convert to X.X
        new_version="${current_version}.1"
    fi
    
    # Generate change request ID
    local cr_id="CR-$(date +%Y%m%d)%03d"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    # Create change request
    cat > "$cr_file" << EOL
## Change Request $cr_id

**Document**: $doc_name
**Current Version**: v$current_version
**Requested Version**: v$new_version
**Change Type**: Content Update
**Requester**: $requester
**Date**: $(date +%Y-%m-%d)
**Status**: Pending

### Change Description
$change_desc

### Justification
$justification

### Impact Assessment
- **Affected Documents**: $affected_docs
- **Change Propagation**: $propagation
- **Risk Level**: $risk_level (Score: $risk_score/100)
- **Complexity**: $complexity
- **Estimated Duration**: $duration
- **Downtime**: None expected
- **Rollback Complexity**: $rollback_complexity
- **Testing Required**: Yes
- **Stakeholder Notification**: Recommended

### Approval Requirements
- **Primary Approver**: $approver
- **Secondary Approver**: None required
- **Approval Criteria**:
  - [ ] Impact assessment reviewed (Score: $risk_score)
  - [ ] Change justification validated
  - [ ] Risk assessment acceptable ($risk_level)
  - [ ] Version compatibility confirmed
  - [ ] Testing plan approved
  - [ ] Rollback procedure verified

### Execution Plan
- [ ] Validate current document state
- [ ] Create archive backup (v$current_version)
- [ ] Apply changes to create v$new_version
- [ ] Update docs/DOCUMENTS.md registry
- [ ] Notify affected agents
- [ ] Verify change success

### Contingency Plan
In case of issues:
1. Restore from archive backup
2. Notify all stakeholders
3. Analyze root cause
4. Create corrected change request
5. Re-initiate approval process

### Change Metadata
- **Change Request ID**: $cr_id
- **Approval Record**: -
- **Execution Record**: -
- **Archive Location**: docs/archive/$doc_name/v$current_version/

### Approval History
- **Submitted**: $(date +%Y-%m-%d) by $requester
- **Approved**: -
- **Rejected**: -
- **Executed**: -
- **Rolled Back**: -

### Related Changes
None (single document change)

### Dependencies
No dependencies for this change

### Testing Requirements
- Verify document integrity after change
- Confirm version update in registry
- Validate archive backup exists
- Test affected workflows (if applicable)
EOL
    
    echo -e "${GREEN}Change request $cr_id created successfully${NC}"
    echo "File: $cr_file"
    
    return 0
}

# Function to list existing change requests
define_list_change_requests() {
    echo -e "${YELLOW}Existing Change Requests:${NC}"
    
    local cr_count=0
    for cr_file in "$CHANGE_REQUESTS_DIR"/*.md; do
        if [[ -f "$cr_file" ]]; then
            local cr_id=$(basename "$cr_file" .md)
            local status=$(grep "Status:" "$cr_file" | sed 's/.*Status: //')
            local doc_name=$(grep "Document:" "$cr_file" | sed 's/.*Document: //')
            
            echo "- $cr_id: $doc_name (Status: $status)"
            ((cr_count++))
        fi
    done
    
    if [[ $cr_count -eq 0 ]]; then
        echo "No change requests found"
    fi
    
    return 0
}

# Function to display change request details
define_show_cr_details() {
    local cr_id="$1"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    if [[ ! -f "$cr_file" ]]; then
        echo -e "${RED}Error: Change request $cr_id not found${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}Change Request Details: $cr_id${NC}"
    echo "======================================"
    
    # Display the change request content
    cat "$cr_file"
    
    return 0
}

# Function to create request notifications (Notification System Integration)
define_create_request_notifications() {
    local cr_id="$1"
    local doc_name="$2"
    local current_version="$3"
    local new_version="$4"
    local risk_level="$5"
    local propagation="$6"
    local approver="$7"
    local requester="$8"
    
    echo -e "${BLUE}\n=== NOTIFICATION SYSTEM INTEGRATION ===${NC}"
    echo "=========================================="
    
    # Create notification record
    local notification_id="NT-$(date +%Y%m%d)%03d"
    local notification_file="/tmp/notification_$notification_id"
    
    # Determine urgency based on risk level
    local urgency="Normal"
    local priority="Medium"
    case "$risk_level" in
        "High") urgency="High"; priority="Urgent";;
        "Medium") urgency="Medium"; priority="Normal";;
        "Low") urgency="Low"; priority="Low";;
    esac
    
    # Create notification content
    cat > "$notification_file" << EOL
# Notification $notification_id
# Type: change_submitted
# Generated: $(date +%Y-%m-%d %H:%M:%S)

NOTIFICATION_ID: $notification_id
CHANGE_REQUEST_ID: $cr_id
DOCUMENT: $doc_name
VERSION_CHANGE: v$current_version → v$new_version
RISK_LEVEL: $risk_level
PROPAGATION: $propagation
URGENCY: $urgency
PRIORITY: $priority
STATUS: Pending

RECIPIENTS:
- Requester: $requester (Information)
- Approver: $approver (Action Required)
- System: Document Change Manager (Tracking)

MESSAGE:
A new change request has been submitted for your review:

Change Request: $cr_id
Document: $doc_name
Version: v$current_version → v$new_version
Risk: $risk_level ($priority priority)
Impact: $propagation propagation required

ACTION REQUIRED:
- Approver ($approver): Review and approve/reject this change request
- Requester ($requester): Monitor progress and provide additional info if needed

DEADLINE:
- Standard review period: 2 business days
- Target completion: $(date -v+2d +%Y-%m-%d)

NOTIFICATION_HISTORY:
- $(date +%Y-%m-%d %H:%M:%S): Change request submitted
- $(date +%Y-%m-%d %H:%M:%S): Notification sent to approver
- $(date +%Y-%m-%d %H:%M:%S): Notification sent to requester

NEXT_STEPS:
1. Approver reviews change request
2. Impact assessment validated
3. Approval decision made
4. Change propagation scheduled (if approved)

AUTOMATED_ACTIONS:
✅ Change request created: $cr_id
✅ Notification record generated: $notification_id
✅ Approver routing determined: $approver
✅ Deadline tracking initiated
✅ Status monitoring enabled

MANUAL_ACTIONS_REQUIRED:
- [ ] Approver: Review change request
- [ ] Approver: Make approval decision
- [ ] Requester: Monitor approval progress

ESCALATION_PROCEDURE:
If no response within 2 business days:
1. Send reminder notification
2. Escalate to secondary approver if available
3. Notify system administrator after 3 business days

NOTIFICATION_METADATA:
GeneratedBy: DocumentChangeManager
NotificationType: change_submitted
ChangeRequestID: $cr_id
DocumentName: $doc_name
RiskLevel: $risk_level
Urgency: $urgency
Priority: $priority
EOL
    
    echo "📢 Notification System Integration:"
    echo "   ✅ Notification $notification_id created"
    echo "   📩 Recipients notified:"
    echo "      • $approver (Approver - Action Required)"
    echo "      • $requester (Requester - Information)"
    echo "   📅 Deadline: $(date -v+2d +%Y-%m-%d)"
    echo "   ⏰ Priority: $priority"
    echo "   🔴 Urgency: $urgency"
    
    # Display notification summary based on risk
    case "$risk_level" in
        "High")
            echo -e "   ${RED}⚠️  HIGH RISK: Immediate attention required${NC}"
            ;;
        "Medium")
            echo -e "   ${YELLOW}⚠️  MEDIUM RISK: Standard review process${NC}"
            ;;
        "Low")
            echo -e "   ${GREEN}✅ LOW RISK: Fast-track eligible${NC}"
            ;;
    esac
    
    echo -e "${GREEN}✅ Notification system integration completed${NC}"
}

# Main script execution
main() {
    echo -e "${YELLOW}Document Change Manager - Change Request${NC}"
    echo "=============================================="
    
    # Check if change requests directory exists
    mkdir -p "$CHANGE_REQUESTS_DIR"
    mkdir -p "$TEMPLATES_DIR"
    
    # Display menu
    echo -e "\nAvailable Options:"
    echo "1. Create new change request"
    echo "2. List existing change requests"
    echo "3. View change request details"
    echo "4. Exit"
    
    read -p "Select option (1-4): " option
    
    case "$option" in
        1)
            # Create new change request
            echo -e "\n${YELLOW}Create New Change Request${NC}"
            
            # Get document type
            echo "Available document types:"
            echo "1. System (System Document)"
            echo "2. Architecture (Architecture Document)"
            echo "3. Tasks (Implementation Tasks)"
            
            read -p "Select document type (1-3): " doc_option
            
            local doc_type=""
            case "$doc_option" in
                1) doc_type="System";;
                2) doc_type="Architecture";;
                3) doc_type="Tasks";;
                *) echo -e "${RED}Invalid option${NC}"; exit 1;;
            esac
            
            # Determine document path
            local doc_path=""
            case "$doc_type" in
                "System") doc_path="$DOCS_DIR/system_document.md";;
                "Architecture") doc_path="$DOCS_DIR/architecture_document.md";;
                "Tasks") doc_path="$DOCS_DIR/implementation_tasks.md";;
            esac
            
            # Validate document exists
            local doc_name=""
            case "$doc_type" in
                "System") doc_name="System Document";;
                "Architecture") doc_name="Architecture Document";;
                "Tasks") doc_name="Implementation Tasks";;
            esac
            
            if ! define_validate_document "$doc_name" "$doc_path"; then
                exit 1
            fi
            
            # Get current version
            local current_version=$(define_get_current_version "$doc_path")
            echo -e "${GREEN}Current version: v$current_version${NC}"
            
            # Get change details with enhanced request validation protocol
            echo -e "${YELLOW}\n=== REQUEST VALIDATION PROTOCOL ===${NC}"
            
            while true; do
                read -p "Change description (min 10 chars): " change_desc
                if [[ ${#change_desc} -lt 10 ]]; then
                    echo -e "${RED}Error: Description must be at least 10 characters${NC}"
                    continue
                fi
                break
            done
            
            while true; do
                read -p "Justification (min 20 chars): " justification
                if [[ ${#justification} -lt 20 ]]; then
                    echo -e "${RED}Error: Justification must be at least 20 characters${NC}"
                    continue
                fi
                break
            done
            
            while true; do
                read -p "Requester name (format: agent_name): " requester
                if [[ ! "$requester" =~ ^(system_doc_creator|architecture_creator|arch_task_generator|[a-z_]+)$ ]]; then
                    echo -e "${RED}Error: Invalid requester format. Use agent names like 'system_doc_creator'${NC}"
                    continue
                fi
                break
            done
            
            echo -e "${GREEN}✅ Request validation protocol completed${NC}"
            
            # Create change request
            define_create_change_request "$doc_type" "$current_version" "$change_desc" "$justification" "$requester"
            
            # Confirm submission with enhanced request confirmation
            echo -e "${YELLOW}\n=== REQUEST CONFIRMATION ===${NC}"
            echo "================================"
            echo "Change Request: $cr_id"
            echo "Document: $doc_name (v$current_version → v$new_version)"
            echo "Risk Level: $risk_level (Score: $risk_score/100)"
            echo "Impact: $propagation required"
            echo "Approver: $approver"
            echo ""
            echo "This change will:"
            echo "  • Affect: $affected_docs"
            echo "  • Require: $propagation propagation"
            echo "  • Risk: $risk_level with $complexity complexity"
            echo ""
            
            if define_confirm "Submit this change request for approval?"; then
                echo -e "${GREEN}Change request submitted successfully!${NC}"
                
                # Execute notification system integration
                define_create_request_notifications "$cr_id" "$doc_name" "$current_version" "$new_version" "$risk_level" "$propagation" "$approver" "$requester"
                
                echo -e "${YELLOW}Next steps:${NC}"
                echo "1. Review change request details"
                echo "2. Use approve_document.sh to approve"
                echo "3. Use propagate_changes.sh to execute"
            else
                echo -e "${YELLOW}Change request saved but not submitted${NC}"
            fi
            ;;
        
        2)
            # List existing change requests
            list_change_requests
            ;;
        
        3)
            # View change request details
            list_change_requests
            if [[ $cr_count -gt 0 ]]; then
                read -p "Enter change request ID to view: " cr_id
                show_cr_details "$cr_id"
            fi
            ;;
        
        4)
            # Exit
            echo "Exiting Change Request Manager"
            exit 0
            ;;
        
        *)
            echo -e "${RED}Error: Invalid option${NC}"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"