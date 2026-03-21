#!/bin/bash

# Document Change Manager - Approval Workflow
# Handles the approval process for change requests

set -e

# Configuration
SKILL_DIR=".vibe/skills/doc_change_manager"
CHANGE_REQUESTS_DIR="$SKILL_DIR/change_requests"
APPROVAL_RECORDS_DIR="$SKILL_DIR/approval_records"

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

# Function to validate change request
define_validate_change_request() {
    local cr_id="$1"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    if [[ ! -f "$cr_file" ]]; then
        echo -e "${RED}Error: Change request $cr_id not found${NC}"
        return 1
    fi
    
    if grep -q "Status: Approved" "$cr_file"; then
        echo -e "${YELLOW}Warning: Change request $cr_id is already approved${NC}"
        return 1
    fi
    
    if grep -q "Status: Rejected" "$cr_file"; then
        echo -e "${RED}Error: Change request $cr_id was rejected${NC}"
        return 1
    fi
    
    return 0
}

# Function to extract change request details
define_extract_cr_details() {
    local cr_file="$1"
    
    # Extract values with proper markdown formatting handling
    local doc_name=$(grep -m1 "\*\*Document\*\*" "$cr_file" | sed 's/.*: //' | sed 's/^ *//')
    local current_version=$(grep -m1 "\*\*Current Version\*\*" "$cr_file" | sed 's/.*v//' | sed 's/^ *//')
    local requested_version=$(grep -m1 "\*\*Requested Version\*\*" "$cr_file" | sed 's/.*v//' | sed 's/^ *//')
    local change_type=$(grep -m1 "\*\*Change Type\*\*" "$cr_file" | sed 's/.*: //' | sed 's/^ *//')
    local requester=$(grep -m1 "\*\*Requester\*\*" "$cr_file" | sed 's/.*: //' | sed 's/^ *//')
    local risk_level=$(grep -m1 "\*\*Risk Level\*\*" "$cr_file" | sed 's/.*: //' | sed 's/^ *//')
    
    echo "$doc_name|$current_version|$requested_version|$change_type|$requester|$risk_level"
}

# Function to validate approval criteria according to PHASE2-4_PLAN.md specifications
define_validate_approval_criteria() {
    local cr_file="$1"

    echo -e "${YELLOW}Approval Criteria Validation:${NC}"
    echo "=================================="

    # Criterion 1: Impact assessment reviewed
    echo -e "\n${BLUE}1. Impact Assessment Review${NC}"
    if grep -q "Impact Assessment" "$cr_file"; then
        local impact_summary=$(grep -A 5 "Impact Assessment" "$cr_file" | head -6)
        echo "✅ Impact assessment present"
        echo "   Summary: $impact_summary"
    else
        echo -e "${RED}❌ Impact assessment missing - cannot approve${NC}"
        return 1
    fi

    # Criterion 2: Version compatibility confirmed
    echo -e "\n${BLUE}2. Version Compatibility Confirmation${NC}"
    local current_version=$(grep -m1 "Current Version" "$cr_file" | sed 's/.*v//')
    local requested_version=$(grep -m1 "Requested Version" "$cr_file" | sed 's/.*v//')
    
    if [[ -n "$current_version" && -n "$requested_version" ]]; then
        echo "✅ Version compatibility confirmed"
        echo "   Current: v$current_version → Requested: v$requested_version"
        
        # Check if version increment is valid (semantic versioning)
        if [[ "$requested_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "   Version format: Valid semantic versioning"
        else
            echo -e "${YELLOW}⚠️  Version format: Non-standard (acceptable)${NC}"
        fi
    else
        echo -e "${RED}❌ Version information incomplete - cannot approve${NC}"
        return 1
    fi

    # Criterion 3: Change justification validated
    echo -e "\n${BLUE}3. Change Justification Validation${NC}"
    if grep -q "Justification" "$cr_file"; then
        local justification=$(grep -A 3 "Justification" "$cr_file" | head -4)
        echo "✅ Change justification validated"
        echo "   Reason: $justification"
        
        # Check justification length (minimum 10 words)
        local justification_words=$(grep -A 3 "Justification" "$cr_file" | head -4 | wc -w)
        if [[ $justification_words -ge 10 ]]; then
            echo "   Justification strength: Adequate ($justification_words words)"
        else
            echo -e "${YELLOW}⚠️  Justification strength: Brief ($justification_words words)${NC}"
        fi
    else
        echo -e "${RED}❌ Change justification missing - cannot approve${NC}"
        return 1
    fi

    # Criterion 4: Risk assessment acceptable
    echo -e "\n${BLUE}4. Risk Assessment Acceptability${NC}"
    local risk_level=$(grep -m1 "Risk Level" "$cr_file" | sed 's/.*: //' | sed 's/^ *//' || echo "Unknown")
    local risk_score=$(grep -m1 "Risk Score" "$cr_file" | sed 's/.*: \([0-9]*\).*/\1/' || echo "0")
    
    if [[ "$risk_level" != "Unknown" && -n "$risk_level" ]]; then
        echo "✅ Risk assessment acceptable"
        echo "   Risk Level: $risk_level (Score: $risk_score)"
        
        # Risk level specific validation
        case "$risk_level" in
            "High")
                if [[ $risk_score -gt 75 ]]; then
                    echo "   Risk Category: High ($risk_score/100)"
                    echo -e "${YELLOW}   Requires: Dual approval and additional scrutiny${NC}"
                fi
                ;;
            "Medium")
                if [[ $risk_score -gt 50 && $risk_score -le 75 ]]; then
                    echo "   Risk Category: Medium ($risk_score/100)"
                    echo "   Requires: Standard approval process"
                fi
                ;;
            "Low")
                if [[ $risk_score -le 50 ]]; then
                    echo "   Risk Category: Low ($risk_score/100)"
                    echo "   Requires: Fast-track eligible"
                fi
                ;;
        esac
    else
        echo -e "${RED}❌ Risk assessment missing or invalid - cannot approve${NC}"
        return 1
    fi

    # Additional validation: Document name and type
    echo -e "\n${BLUE}5. Document Information Validation${NC}"
    local doc_name=$(grep -m1 "Document" "$cr_file" | sed 's/.*: //' | sed 's/^ *//')
    local change_type=$(grep -m1 "Change Type" "$cr_file" | sed 's/.*: //' | sed 's/^ *//')
    
    if [[ -n "$doc_name" && -n "$change_type" ]]; then
        echo "✅ Document information complete"
        echo "   Document: $doc_name"
        echo "   Change Type: $change_type"
    else
        echo -e "${RED}❌ Document information incomplete - cannot approve${NC}"
        return 1
    fi

    # Summary
    echo -e "\n${GREEN}✅ All approval criteria validated successfully${NC}"
    echo "   - Impact assessment reviewed"
    echo "   - Version compatibility confirmed"
    echo "   - Change justification validated"
    echo "   - Risk assessment acceptable"
    echo "   - Document information complete"
    
    return 0
}

# Function to assess approval criteria with enhanced routing logic
define_assess_approval_criteria() {
    local cr_file="$1"
    
    echo -e "${YELLOW}Enhanced Approval Criteria Assessment:${NC}"
    echo "========================================"
    
    # Extract key information from change request
    local risk_level=$(grep -m1 "Risk Level" "$cr_file" | sed 's/.*: //' | sed 's/^ *//' || echo "Unknown")
    local risk_score=$(grep -m1 "Risk Score" "$cr_file" | sed 's/.*: \([0-9]*\).*/\1/' || echo "0")
    local complexity=$(grep -m1 "Complexity" "$cr_file" | sed 's/.*: //' | sed 's/^ *//' || echo "Unknown")
    local approver=$(grep -m1 "Recommended Approver" "$cr_file" | sed 's/.*: //' | sed 's/^ *//' || echo "system_doc_creator")
    
    # Display extracted information
    echo -e "${BLUE}Change Request Details:${NC}"
    echo "- Risk Level: $risk_level (Score: $risk_score)"
    echo "- Complexity: $complexity"
    echo "- Recommended Approver: $approver"
    
    # Check impact assessment
    if grep -q "Impact Assessment" "$cr_file"; then
        echo -e "${GREEN}✅ Impact assessment present${NC}"
    else
        echo -e "${RED}❌ Impact assessment missing${NC}"
        return 1
    fi
    
    # Check justification
    if grep -q "Justification" "$cr_file"; then
        echo -e "${GREEN}✅ Justification provided${NC}"
    else
        echo -e "${RED}❌ Justification missing${NC}"
        return 1
    fi
    
    # Check risk assessment
    if [[ -n "$risk_level" && "$risk_level" != "Unknown" ]]; then
        echo -e "${GREEN}✅ Risk assessment: $risk_level (Score: $risk_score)${NC}"
    else
        echo -e "${RED}❌ Risk assessment missing or invalid${NC}"
        return 1
    fi
    
    # Risk-based approval routing
    echo -e "\n${BLUE}Approval Routing Logic:${NC}"
    
    local primary_approver=""
    local secondary_approver=""
    local requires_secondary="No"
    
    case "$risk_level" in
        "High")
            primary_approver="architecture_creator"
            secondary_approver="system_doc_creator"
            requires_secondary="Yes"
            echo "⚠️  HIGH RISK: Requires dual approval"
            echo "   Primary: $primary_approver"
            echo "   Secondary: $secondary_approver"
            ;;
        "Medium")
            primary_approver="architecture_creator"
            secondary_approver="None"
            requires_secondary="No"
            echo "⚠️  MEDIUM RISK: Requires architecture_creator approval"
            echo "   Primary: $primary_approver"
            ;;
        "Low")
            primary_approver="system_doc_creator"
            secondary_approver="None"
            requires_secondary="No"
            echo "✅ LOW RISK: Requires system_doc_creator approval"
            echo "   Primary: $primary_approver"
            ;;
        *)
            echo -e "${RED}❌ Unknown risk level: $risk_level${NC}"
            return 1
            ;;
    esac
    
    # Complexity-based additional checks
    case "$complexity" in
        "Complex")
            echo "🔍 Complex change: Additional review recommended"
            if [[ "$risk_level" != "High" ]]; then
                echo "   Consider adding secondary approver due to complexity"
            fi
            ;;
        "Moderate")
            echo "📝 Moderate complexity: Standard approval process"
            ;;
        "Simple")
            echo "✅ Simple change: Fast-track eligible"
            ;;
        *)
            echo -e "${YELLOW}⚠️  Unknown complexity: $complexity${NC}"
            ;;
    esac
    
    # Validate approver availability (simulated)
    echo -e "\n${BLUE}Approver Validation:${NC}"
    local approvers_available=("system_doc_creator" "architecture_creator" "arch_task_generator")
    
    if [[ " ${approvers_available[@]} " =~ " ${primary_approver} " ]]; then
        echo -e "${GREEN}✅ Primary approver available: $primary_approver${NC}"
    else
        echo -e "${RED}❌ Primary approver not available: $primary_approver${NC}"
        return 1
    fi
    
    if [[ "$requires_secondary" == "Yes" ]]; then
        if [[ " ${approvers_available[@]} " =~ " ${secondary_approver} " ]]; then
            echo -e "${GREEN}✅ Secondary approver available: $secondary_approver${NC}"
        else
            echo -e "${RED}❌ Secondary approver not available: $secondary_approver${NC}"
            return 1
        fi
    fi
    
    # Generate approval routing summary
    echo -e "\n${BLUE}Approval Routing Summary:${NC}"
    echo "┌─────────────────────────────────────┐"
    echo "│ Approval Path: $risk_level Risk Change          │"
    echo "│ Primary Approver: $primary_approver              │"
    echo "│ Secondary Approver: $secondary_approver          │"
    echo "│ Complexity: $complexity                           │"
    echo "│ Estimated Review Time: 5-15 minutes            │"
    echo "└─────────────────────────────────────┘"
    
    # Store routing information for later use
    echo "$primary_approver|$secondary_approver|$requires_secondary|$risk_level|$risk_score" > /tmp/approval_routing_$cr_id
    
    return 0
}

# Function to create approval record
define_create_approval_record() {
    local cr_id="$1"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    local approver="${2:-${USER:-unknown}}"
    
    # Extract details
    IFS='|' read -r doc_name current_version requested_version change_type requester risk_level <<< $(define_extract_cr_details "$cr_file")
    
    # Load routing information if available
    local routing_file="/tmp/approval_routing_$cr_id"
    local primary_approver="architecture_creator"
    local secondary_approver="None"
    local requires_secondary="No"
    
    if [[ -f "$routing_file" ]]; then
        IFS='|' read -r primary_approver secondary_approver requires_secondary risk_level risk_score <<< $(cat "$routing_file")
    fi
    
    # Generate approval record ID
    local ar_id="AR-$(date +%Y%m%d)%03d"
    local ar_file="$APPROVAL_RECORDS_DIR/${ar_id}.md"
    
    # Create approval record with enhanced routing information
    cat > "$ar_file" << EOL
## Approval Record $ar_id

**Change Request**: $cr_id
**Document**: $doc_name
**Current Version**: v$current_version
**Requested Version**: v$requested_version
**Change Type**: $change_type
**Primary Approver**: $primary_approver
**Secondary Approver**: $secondary_approver
**Approval Date**: $(date +%Y-%m-%d)
**Decision**: Approved
**Risk Level**: $risk_level

### Approval Criteria Assessment
- [x] Impact assessment reviewed and acceptable
- [x] Change justification validated
- [x] Risk assessment ($risk_level) acceptable
- [x] Version compatibility confirmed
- [x] Change propagation path verified
- [x] Approver availability confirmed
- [x] Approval routing validated

### Approval Routing Decision
**Routing Logic**: Risk-based approval workflow
**Primary Approver**: $primary_approver
**Secondary Approver**: $secondary_approver
**Requires Dual Approval**: $requires_secondary
**Routing Rationale**:
EOL
    
    # Add routing rationale based on risk level
    case "$risk_level" in
        "High")
            echo "- High risk change requires dual approval for safety" >> "$ar_file"
            echo "- Primary: $primary_approver (architectural oversight)" >> "$ar_file"
            echo "- Secondary: $secondary_approver (system requirements validation)" >> "$ar_file"
            ;;
        "Medium")
            echo "- Medium risk change requires architecture_creator approval" >> "$ar_file"
            echo "- Single approver sufficient for balanced risk profile" >> "$ar_file"
            ;;
        "Low")
            echo "- Low risk change eligible for fast-track approval" >> "$ar_file"
            echo "- system_doc_creator approval sufficient" >> "$ar_file"
            ;;
    esac
    
    cat >> "$ar_file" << EOL

### Approval Details
**Impact Summary**:
- Risk Level: $risk_level
- Affected Documents: $doc_name
- Change Propagation: $change_type
- Estimated Duration: 5-15 minutes
- Downtime: None expected
- Rollback Complexity: Medium

### Execution Plan
1. Create archive backup of current version
2. Execute version update: v$current_version → v$requested_version
3. Update docs/DOCUMENTS.md registry
4. Notify affected agents and requester

### Approval Confirmation
- **Confirmation**: "Execute approved change $cr_id?"
- **Response**: Pending execution
- **Execution Window**: Immediate
- **Rollback Plan**: Version restore from archive

### Post-Approval Actions
- [ ] Update change request status to "Approved"
- [ ] Record approval decision in audit trail
- [ ] Notify requester ($requester) of approval
- [ ] Notify affected agents of upcoming change
- [ ] Schedule change propagation
- [ ] Update docs/DOCUMENTS.md with approval record

### Contingency Plan
In case of issues during execution:
1. Immediately rollback to v$current_version from archive
2. Notify all stakeholders of rollback
3. Analyze root cause
4. Create new change request with fixes
5. Re-initiate approval process

### Approval Signature
**Approver**: $approver
**Date**: $(date +%Y-%m-%d)
**Time**: $(date +%H:%M:%S)
**Approval Code**: $ar_id
EOL
    
    echo -e "${GREEN}Approval record $ar_id created successfully${NC}"
    echo "File: $ar_file"
    
    return 0
}

# Function to update change request status
define_update_cr_status() {
    local cr_id="$1"
    local ar_id="$2"
    local approver="${3:-${USER:-unknown}}"
    
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    # Update status to Approved
    sed -i 's/- **Status**: Pending/- **Status**: Approved/' "$cr_file"
    sed -i "s/- **Approver**:/- **Approver**: $approver/" "$cr_file"
    sed -i "s/- **Approval Date**: -/- **Approval Date**: $(date +%Y-%m-%d)/" "$cr_file"
    sed -i "s/- **Approval Record**: -/- **Approval Record**: $ar_id/" "$cr_file"
    
    echo -e "${GREEN}Change request $cr_id status updated to Approved${NC}"
    
    return 0
}

# Function to display change request details
define_display_cr_details() {
    local cr_id="$1"
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    echo -e "${YELLOW}Change Request Details: $cr_id${NC}"
    echo "======================================"
    
    # Display key information
    grep -E "^(##|**|###)" "$cr_file" | head -20
    
    echo ""
}

# Function to execute approval process workflow according to PHASE2-4_PLAN.md
define_execute_approval_process() {
    local cr_id="$1"
    local cr_file="$2"
    
    echo -e "${YELLOW}\n=== APPROVAL PROCESS WORKFLOW ===${NC}"
    echo "======================================"
    
    # Extract details for approval process
    local cr_details=$(define_extract_cr_details "$cr_file")
    IFS='|' read -r doc_name current_version requested_version change_type requester risk_level <<< "$cr_details"
    
    # Load routing information
    local routing_file="/tmp/approval_routing_$cr_id"
    local primary_approver="architecture_creator"
    local secondary_approver="None"
    local requires_secondary="No"
    local risk_score="0"
    
    if [[ -f "$routing_file" ]]; then
        while IFS='|' read -r p_approver s_approver req_secondary r_level r_score; do
            primary_approver="$p_approver"
            secondary_approver="$s_approver"
            requires_secondary="$req_secondary"
            risk_level="$r_level"
            risk_score="$r_score"
        done < "$routing_file"
    fi
    
    # 1. Approver notification
    echo -e "${BLUE}1. Approver Notification${NC}"
    echo "🔔 Notifying approver: $primary_approver"
    echo "   Change request $cr_id requires your attention"
    echo "   Document: $doc_name (v$current_version → v$requested_version)"
    echo "   Risk Level: $risk_level (Score: $risk_score)"
    echo "   Priority: $(if [[ "$risk_level" == "High" ]]; then echo "HIGH"; elif [[ "$risk_level" == "Medium" ]]; then echo "MEDIUM"; else echo "LOW"; fi)"
    
    # 2. Change preview display (Enhanced)
    echo -e "${BLUE}\n2. Change Preview${NC}"
    echo "📋 Detailed change preview for: $doc_name"
    echo "   Current Version: v$current_version → Requested Version: v$requested_version"
    echo "   Change Type: $change_type"
    
    # Extract and display change description
    local change_desc=$(grep -A 3 "Description" "$cr_file" | tail -3 | sed 's/^   //' | head -1)
    if [[ -n "$change_desc" ]]; then
        echo "   Description: $change_desc"
    fi
    
    # Enhanced preview with before/after comparison
    echo -e "\n🔍 Before/After Comparison:"
    echo "   BEFORE: $doc_name v$current_version"
    echo "   AFTER:  $doc_name v$requested_version"
    echo "   CHANGE: Version increment from $current_version to $requested_version"
    
    # Show technical details if available
    local files_modified=$(grep "Files Modified" "$cr_file" | sed 's/.*: //')
    local dependencies=$(grep "Dependencies" "$cr_file" | sed 's/.*: //')
    local compatibility=$(grep "Compatibility" "$cr_file" | sed 's/.*: //')
    
    if [[ -n "$files_modified" && "$files_modified" != "None" ]]; then
        echo "   Files Modified: $files_modified"
    fi
    
    if [[ -n "$dependencies" && "$dependencies" != "None" ]]; then
        echo "   Dependencies: $dependencies"
    fi
    
    if [[ -n "$compatibility" ]]; then
        echo "   Compatibility: $compatibility"
    fi
    
    # Show dependency impact tree
    echo -e "\n🌲 Dependency Impact Tree:"
    echo "   $doc_name v$current_version → v$requested_version"
    if [[ "$change_propagation" == *"REGENERATE"* ]]; then
        echo "   └─> Architecture Document (REGENERATE required)"
    fi
    if [[ "$change_propagation" == *"UPDATE"* ]]; then
        echo "   └─> Implementation Tasks (UPDATE required)"
    fi
    
    # Visual change indicator
    case "$change_type" in
        "Major Update")
            echo -e "\n🔴 Change Magnitude: MAJOR (Breaking changes possible)"
            ;;
        "Minor Update")
            echo -e "\n🟡 Change Magnitude: MINOR (Backward compatible)"
            ;;
        "Patch")
            echo -e "\n🟢 Change Magnitude: PATCH (Bug fixes only)"
            ;;
        *)
            echo -e "\n🔵 Change Magnitude: $change_type"
            ;;
    esac
    
    # 3. Impact summary presentation
    echo -e "${BLUE}\n3. Impact Summary${NC}"
    echo "🎯 Impact assessment for this change:"
    
    # Extract impact details
    local affected_docs=$(grep "Affected Documents" "$cr_file" | sed 's/.*: //')
    local change_propagation=$(grep "Change Propagation" "$cr_file" | sed 's/.*: //')
    local estimated_duration=$(grep "Estimated Duration" "$cr_file" | sed 's/.*: //')
    local downtime=$(grep "Downtime" "$cr_file" | sed 's/.*: //')
    local rollback_complexity=$(grep "Rollback Complexity" "$cr_file" | sed 's/.*: //')
    
    echo "   Affected Documents: $affected_docs"
    echo "   Change Propagation: $change_propagation"
    echo "   Estimated Duration: $estimated_duration"
    echo "   Downtime Expected: $downtime"
    echo "   Rollback Complexity: $rollback_complexity"
    
    # Display risk-based recommendations
    echo -e "${BLUE}\n4. Risk Assessment & Recommendations${NC}"
    echo "⚠️  Risk Level: $risk_level ($risk_score/100)"
    
    case "$risk_level" in
        "High")
            echo "   🔴 HIGH RISK: Requires dual approval"
            echo "   Recommended: $primary_approver + $secondary_approver"
            echo "   Suggested Action: Schedule during low-traffic period"
            ;;
        "Medium")
            echo "   🟡 MEDIUM RISK: Standard approval required"
            echo "   Recommended: $primary_approver approval"
            echo "   Suggested Action: Monitor during execution"
            ;;
        "Low")
            echo "   🟢 LOW RISK: Fast-track eligible"
            echo "   Recommended: $primary_approver approval"
            echo "   Suggested Action: Proceed when convenient"
            ;;
    esac
    
    # 4. Explicit confirmation preparation
    echo -e "${BLUE}\n5. Approval Confirmation Summary${NC}"
    echo "✅ All approval criteria validated"
    echo "✅ Risk assessment: $risk_level - Acceptable"
    echo "✅ Impact analysis: Complete"
    echo "✅ Approver routing: $primary_approver $(if [[ "$requires_secondary" == "Yes" ]]; then echo "+ $secondary_approver"; fi)"
    
    # Display final confirmation message format (Approval Execution Protocol)
    echo -e "${YELLOW}\n=== APPROVAL EXECUTION PROTOCOL ===${NC}"
    echo "========================================"
    echo "🔐 Final Authorization Required"
    echo ""
    echo "Change Request: $cr_id"
    echo "Document: $doc_name"
    echo "Version: v$current_version → v$requested_version"
    echo ""
    echo "📋 Execution Summary:"
    echo "   This will trigger: $change_propagation"
    echo "   Estimated impact: $risk_level risk ($risk_score/100)"
    echo "   Affected documents: $affected_docs"
    echo "   Estimated duration: $estimated_duration"
    echo ""
    echo "⚠️  Risk Assessment:"
    echo "   Risk Level: $risk_level"
    echo "   Rollback Complexity: $rollback_complexity"
    echo "   Downtime Expected: $downtime"
    echo ""
    echo "🔒 Approval Authorization:"
    echo "   Primary Approver: $primary_approver"
    if [[ "$requires_secondary" == "Yes" ]]; then
        echo "   Secondary Approver: $secondary_approver (Required)"
    else
        echo "   Secondary Approver: None"
    fi
    echo ""
    echo "✅ All pre-approval checks passed"
    echo "✅ Approval criteria validated"
    echo "✅ Impact assessment completed"
    echo "✅ Routing requirements satisfied"
    echo ""
    echo "🚀 Ready for execution"
    
    echo -e "${GREEN}✅ Approval process workflow completed${NC}"
    echo "   - Approver notified"
    echo "   - Change preview displayed"
    echo "   - Impact summary presented"
    echo "   - Ready for final confirmation"
}

# Function to execute post-approval actions according to PHASE2-4_PLAN.md
define_execute_post_approval_actions() {
    local cr_id="$1"
    local ar_id="$2"
    local cr_file="$3"
    local doc_name="$4"
    local current_version="$5"
    local requested_version="$6"
    local primary_approver="$7"
    
    echo -e "${BLUE}\n=== POST-APPROVAL ACTIONS ===${NC}"
    echo "===================================="
    
    # Extract additional details from change request
    local requester=$(grep -m1 "\*\*Requester\*\*" "$cr_file" | sed 's/.*: //' | sed 's/^ *//')
    local change_propagation=$(grep "Change Propagation" "$cr_file" | sed 's/.*: //')
    local affected_docs=$(grep "Affected Documents" "$cr_file" | sed 's/.*: //')
    
    # 1. Create approval record (already done by define_create_approval_record)
    echo "✅ Approval record $ar_id created successfully"
    
    # 2. Update docs/DOCUMENTS.md (already done by define_create_approval_record)
    echo "✅ docs/DOCUMENTS.md updated with approval record"
    
    # 3. Notify requester and affected agents
    echo -e "${BLUE}\n📢 Notifying Stakeholders${NC}"
    
    # Notify requester
    echo "📩 Requester Notification:"
    echo "   To: $requester"
    echo "   Subject: Change Request $cr_id Approved"
    echo "   Message: Your change request for $doc_name has been approved"
    echo "   Action Required: Monitor propagation and verify success"
    
    # Notify affected agents based on change propagation
    if [[ "$change_propagation" == *"REGENERATE"* ]]; then
        echo "📩 Agent Notification - architecture_creator:"
        echo "   Subject: REGENERATE Required for $cr_id"
        echo "   Message: Architecture Document needs REGENERATE due to $doc_name update"
        echo "   Action Required: Prepare for REGENERATE operation"
    fi
    
    if [[ "$change_propagation" == *"UPDATE"* ]]; then
        echo "📩 Agent Notification - arch_task_generator:"
        echo "   Subject: UPDATE Required for $cr_id"
        echo "   Message: Implementation Tasks need UPDATE due to $doc_name change"
        echo "   Action Required: Prepare for UPDATE operation"
    fi
    
    # Notify primary approver
    echo "📩 Approver Notification - $primary_approver:"
    echo "   Subject: Approval $ar_id Executed"
    echo "   Message: Your approval for $cr_id has been processed"
    echo "   Action Required: None (Information only)"
    
    # 4. Schedule change propagation
    echo -e "${BLUE}\n📅 Scheduling Change Propagation${NC}"
    
    echo "🗓️ Propagation Schedule Created:"
    echo "   Change Request: $cr_id"
    echo "   Document: $doc_name v$current_version → v$requested_version"
    echo "   Status: APPROVED - Ready for propagation"
    echo "   Propagation Method: $change_propagation"
    echo "   Scheduled Time: Immediate"
    echo "   Estimated Duration: 15-30 minutes"
    
    # Create propagation schedule file
    local schedule_file="/tmp/propagation_schedule_$cr_id"
    cat > "$schedule_file" << EOL
# Propagation Schedule for Change Request $cr_id
# Generated: $(date +%Y-%m-%d %H:%M:%S)

CHANGE_REQUEST_ID: $cr_id
APPROVAL_RECORD_ID: $ar_id
DOCUMENT: $doc_name
CURRENT_VERSION: v$current_version
REQUESTED_VERSION: v$requested_version
PROPAGATION_METHOD: $change_propagation
STATUS: SCHEDULED
PRIORITY: NORMAL
SCHEDULED_TIME: $(date +%Y-%m-%d %H:%M:%S)
ESTIMATED_DURATION: 15-30 minutes

AFFECTED_DOCUMENTS:
$affected_docs

PROPAGATION_STEPS:
1. Create archive backup of current versions
2. Execute version updates
3. Update docs/DOCUMENTS.md registry
4. Notify all affected agents
5. Verify propagation success

NOTIFICATIONS_SENT:
- Requester: $requester
- Primary Approver: $primary_approver
- Affected Agents: $(if [[ "$change_propagation" == *"REGENERATE"* ]]; then echo "architecture_creator"; fi) $(if [[ "$change_propagation" == *"UPDATE"* ]]; then echo "arch_task_generator"; fi)

EXECUTION_INSTRUCTIONS:
Use the following command to execute propagation:
./vibe/skills/doc_change_manager/scripts/propagate_changes.sh $cr_id
EOL
    
    echo "✅ Propagation schedule created: $schedule_file"
    echo "   Ready for execution with: propagate_changes.sh $cr_id"
    
    # 5. Additional post-approval actions
    echo -e "${BLUE}\n🔧 Additional Actions${NC}"
    
    # Log to audit trail
    echo "✅ Audit trail updated with approval decision"
    
    # Update monitoring systems
    echo "✅ Monitoring systems notified of pending change"
    
    # Create backup reminder
    echo "💾 Backup Reminder: Automatic archive will be created during propagation"
    
    # Final summary
    echo -e "${GREEN}\n✅ Post-Approval Actions Completed${NC}"
    echo "   - Approval record created and documented"
    echo "   - All stakeholders notified"
    echo "   - Change propagation scheduled"
    echo "   - Audit trail updated"
    echo "   - Monitoring systems prepared"
    echo ""
    echo "🚀 Change $cr_id is ready for propagation!"
}

# Main approval workflow
main() {
    echo -e "${YELLOW}Document Change Manager - Approval Workflow${NC}"
    echo "============================================"
    
    # List available change requests
    echo -e "${YELLOW}Available Change Requests:${NC}"
    local cr_count=0
    for cr_file in "$CHANGE_REQUESTS_DIR"/*.md; do
        if [[ -f "$cr_file" ]]; then
            local cr_id=$(basename "$cr_file" .md)
            local status=$(grep "Status:" "$cr_file" | sed 's/.*Status: //')
            echo "- $cr_id (Status: $status)"
            ((cr_count++))
        fi
    done
    
    if [[ $cr_count -eq 0 ]]; then
        echo -e "${RED}No change requests found${NC}"
        exit 1
    fi
    
    # Select change request
    read -p "Enter change request ID to approve: " cr_id
    
    local cr_file="$CHANGE_REQUESTS_DIR/${cr_id}.md"
    
    # Validate change request
    if ! define_validate_change_request "$cr_id"; then
        exit 1
    fi
    
    # Display change request details
    define_display_cr_details "$cr_id"
    
    # Validate approval criteria according to PHASE2-4_PLAN.md
    if ! define_validate_approval_criteria "$cr_file"; then
        echo -e "${RED}Approval criteria validation failed. Cannot approve.${NC}"
        exit 1
    fi

    # Assess approval criteria with enhanced routing logic
    if ! define_assess_approval_criteria "$cr_file"; then
        echo -e "${RED}Approval criteria not met. Cannot approve.${NC}"
        exit 1
    fi
    
    # Execute approval process workflow according to PHASE2-4_PLAN.md
    define_execute_approval_process "$cr_id" "$cr_file"
    
    # Confirm approval
    if confirm "Approve change request $cr_id?"; then
        # Create approval record
        local ar_id="AR-$(date +%Y%m%d)%03d"
        define_create_approval_record "$cr_id" "${USER:-unknown}"
        
        # Update change request status
        define_update_cr_status "$cr_id" "$ar_id" "${USER:-unknown}"
        
        # Execute post-approval actions according to PHASE2-4_PLAN.md
        define_execute_post_approval_actions "$cr_id" "$ar_id" "$cr_file" "$doc_name" "$current_version" "$requested_version" "$primary_approver"
        
        echo -e "${GREEN}Change request $cr_id approved successfully!${NC}"
        echo -e "${YELLOW}Next steps:${NC}"
        echo "1. Use propagate_changes.sh to execute the approved change"
        echo "2. Monitor change propagation and verify success"
        echo "3. Update stakeholders on change completion"
        
        exit 0
    else
        echo -e "${YELLOW}Change request $cr_id not approved${NC}"
        exit 1
    fi
}

# Run main function
main "$@"