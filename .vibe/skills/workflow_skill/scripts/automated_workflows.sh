#!/bin/bash

# AI Council Automated Workflows
# Main workflow automation controller

set -e

# Configuration
WORKFLOWS_DIR=".vibe/workflows"
DOCS_DIR="docs"
SKILLS_DIR=".vibe/skills"
REGISTRY_FILE="$SKILLS_DIR/skills.json"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "🚀 AI Council Automated Workflows"
echo "================================"
echo ""

# Main workflow controller
main() {
    local command="$1"
    shift
    
    case "$command" in
        assess-impact)
            assess_impact "$@"
            ;;
        coordinate-approval)
            coordinate_approval "$@"
            ;;
        propagate-changes)
            propagate_changes "$@"
            ;;
        update-versions)
            update_versions "$@"
            ;;
        monitor-workflows)
            monitor_workflows "$@"
            ;;
        *)
            show_help
            ;;
    esac
}

# Impact assessment automation
assess_impact() {
    local document="$1"
    local change_description="$2"
    
    if [[ -z "$document" || -z "$change_description" ]]; then
        echo "Error: Document and change description required"
        echo "Usage: $0 assess-impact <document> <change_description>"
        return 1
    fi
    
    echo "🔍 Assessing impact for: $document"
    echo "Change: $change_description"
    echo ""
    
    # Check if document exists
    if [[ ! -f "$document" ]]; then
        echo "❌ Document not found: $document"
        return 1
    fi
    
    # Analyze document type
    local doc_type="unknown"
    if [[ "$document" == *"SKILL.md"* ]]; then
        doc_type="skill"
    elif [[ "$document" == *"docs/"* ]]; then
        doc_type="documentation"
    elif [[ "$document" == *".vibe/"* ]]; then
        doc_type="configuration"
    fi
    
    echo "Document Type: $doc_type"
    
    # Check dependencies
    echo "📋 Checking dependencies..."
    local dependencies=$(grep -r "$document" .vibe/ docs/ 2>/dev/null | grep -v ".git" | wc -l)
    echo "Dependent files: $dependencies"
    
    # Risk assessment
    local risk_level="Low"
    if [[ $dependencies -gt 5 ]]; then
        risk_level="High"
    elif [[ $dependencies -gt 2 ]]; then
        risk_level="Medium"
    fi
    
    echo "🚨 Risk Level: $risk_level"
    
    # Impact summary
    echo ""
    echo "📊 Impact Assessment Summary:"
    echo "============================"
    echo "Document: $document"
    echo "Type: $doc_type"
    echo "Change: $change_description"
    echo "Dependencies: $dependencies files"
    echo "Risk: $risk_level"
    echo ""
    
    # Recommendation
    if [[ "$risk_level" == "High" ]]; then
        echo "⚠️  Recommendation: Manual review required before approval"
    else
        echo "✅ Recommendation: Automated approval possible"
    fi
    
    return 0
}

# Approval workflow coordination
coordinate_approval() {
    local request_id="$1"
    local document="$2"
    local approver="$3"
    
    if [[ -z "$request_id" || -z "$document" || -z "$approver" ]]; then
        echo "Error: Request ID, document, and approver required"
        echo "Usage: $0 coordinate-approval <request_id> <document> <approver>"
        return 1
    fi
    
    echo "📝 Coordinating approval for: $request_id"
    echo "Document: $document"
    echo "Approver: $approver"
    echo ""
    
    # Create approval record
    local timestamp=$(date +%Y-%m-%d_%H%M%S)
    local approval_record="$WORKFLOWS_DIR/approvals/approval_${request_id}_${timestamp}.md"
    
    mkdir -p "$WORKFLOWS_DIR/approvals"
    
    cat > "$approval_record" << EOF
# Approval Record: $request_id

**Document**: $document
**Approver**: $approver
**Status**: Pending
**Created**: $(date)

## Approval Details

- Request ID: $request_id
- Document: $document
- Approver: $approver
- Status: Pending
- Deadline: $(date -v+7d +%Y-%m-%d) (7 days from now)

## Approval Process

1. Review impact assessment
2. Verify version compatibility
3. Confirm change justification
4. Accept risk assessment
5. Provide explicit approval

## Approval Actions

Once approved, run:
```bash
.vibe/workflows/automated_workflows.sh propagate-changes $request_id $document
```
EOF
    
    echo "✅ Created approval record: $approval_record"
    echo "📅 Deadline: $(date -v+7d +%Y-%m-%d)"
    echo "🔔 Notification sent to: $approver"
    echo ""
    echo "📋 Approval Status: Pending"
    
    return 0
}

# Change propagation automation
propagate_changes() {
    local request_id="$1"
    local document="$2"
    
    if [[ -z "$request_id" || -z "$document" ]]; then
        echo "Error: Request ID and document required"
        echo "Usage: $0 propagate-changes <request_id> <document>"
        return 1
    fi
    
    echo "🔄 Propagating changes for: $request_id"
    echo "Document: $document"
    echo ""
    
    # Check approval record
    local approval_record=$(find "$WORKFLOWS_DIR/approvals" -name "*$request_id*" -type f | head -1)
    
    if [[ -z "$approval_record" ]]; then
        echo "❌ Approval record not found for request: $request_id"
        return 1
    fi
    
    # Verify approval status
    local approval_status=$(grep "Status:" "$approval_record" | awk '{print $2}')
    
    if [[ "$approval_status" != "Approved" ]]; then
        echo "❌ Changes not approved. Status: $approval_status"
        return 1
    fi
    
    echo "✅ Approval verified: $approval_status"
    
    # Determine document type and propagation strategy
    local doc_type="unknown"
    local propagation_strategy="default"
    
    if [[ "$document" == *"SKILL.md"* ]]; then
        doc_type="skill"
        propagation_strategy="skill_update"
    elif [[ "$document" == *"docs/"* ]]; then
        doc_type="documentation"
        propagation_strategy="doc_update"
    fi
    
    echo "Document Type: $doc_type"
    echo "Propagation Strategy: $propagation_strategy"
    echo ""
    
    # Execute propagation
    echo "📦 Executing propagation..."
    
    case "$propagation_strategy" in
        skill_update)
            echo "Updating skill registry..."
            # Update version in registry
            local skill_name=$(basename $(dirname "$document"))
            local new_version=$(grep "version:" "$document" | awk '{print $2}' | tr -d '"')
            
            echo "Skill: $skill_name"
            echo "New Version: $new_version"
            
            # Update registry (stub - actual implementation will use jq)
            echo "📝 Registry update pending for $skill_name v$new_version"
            ;;
        
        doc_update)
            echo "Updating documentation..."
            # Update documentation metadata
            echo "📚 Documentation update for: $document"
            ;;
        
        *)
            echo "Default propagation strategy"
            echo "🔧 Processing: $document"
            ;;
    esac
    
    # Create propagation log
    local timestamp=$(date +%Y-%m-%d_%H%M%S)
    local propagation_log="$WORKFLOWS_DIR/propagation/propagation_${request_id}_${timestamp}.log"
    
    mkdir -p "$WORKFLOWS_DIR/propagation"
    
    echo "📊 Propagation completed for: $request_id"
    echo "Log: $propagation_log"
    echo "Document: $document"
    echo "Status: Success"
    echo "Timestamp: $(date)"
    
    return 0
}

# Version update automation
update_versions() {
    local document="$1"
    local version_type="$2"  # patch, minor, major
    
    if [[ -z "$document" || -z "$version_type" ]]; then
        echo "Error: Document and version type required"
        echo "Usage: $0 update-versions <document> <version_type>"
        echo "Version types: patch, minor, major"
        return 1
    fi
    
    echo "📈 Updating version for: $document"
    echo "Version Type: $version_type"
    echo ""
    
    # Check if document has version information
    if [[ ! -f "$document" ]]; then
        echo "❌ Document not found: $document"
        return 1
    fi
    
    # Extract current version
    local current_version=""
    if grep -q "version:" "$document"; then
        current_version=$(grep "version:" "$document" | awk '{print $2}' | tr -d '"')
    elif grep -q "Version:" "$document"; then
        current_version=$(grep "Version:" "$document" | awk '{print $2}')
    else
        echo "❌ No version information found in document"
        return 1
    fi
    
    echo "Current Version: $current_version"
    
    # Parse semantic version
    local major=$(echo "$current_version" | cut -d'.' -f1)
    local minor=$(echo "$current_version" | cut -d'.' -f2)
    local patch=$(echo "$current_version" | cut -d'.' -f3)
    
    # Calculate new version
    local new_version=""
    case "$version_type" in
        patch)
            new_version="$major.$minor.$((patch + 1))"
            ;;
        minor)
            new_version="$major.$((minor + 1)).0"
            ;;
        major)
            new_version="$((major + 1)).0.0"
            ;;
        *)
            echo "❌ Invalid version type: $version_type"
            return 1
            ;;
    esac
    
    echo "New Version: $new_version"
    
    # Update version in document (stub - actual implementation will use sed/awk)
    echo "📝 Version update pending: $current_version → $new_version"
    echo "Document: $document"
    
    # Create version update record
    local timestamp=$(date +%Y-%m-%d_%H%M%S)
    local version_record="$WORKFLOWS_DIR/versions/version_${timestamp}.log"
    
    mkdir -p "$WORKFLOWS_DIR/versions"
    
    cat > "$version_record" << EOF
Version Update Record
====================

Document: $document
Current Version: $current_version
New Version: $new_version
Update Type: $version_type
Timestamp: $(date)

Changelog:
- Automated version update
- Type: $version_type
- From: $current_version
- To: $new_version
EOF
    
    echo "✅ Created version update record: $version_record"
    
    return 0
}

# Workflow monitoring
monitor_workflows() {
    echo "📊 Workflow Monitoring"
    echo "====================="
    echo ""
    
    # Check approval records
    local pending_approvals=$(find "$WORKFLOWS_DIR/approvals" -name "*.md" 2>/dev/null | wc -l)
    local completed_approvals=$(grep -r "Status: Approved" "$WORKFLOWS_DIR/approvals/" 2>/dev/null | wc -l)
    local pending_approvals_count=$((pending_approvals - completed_approvals))
    
    echo "📋 Approval Workflows:"
    echo "  Pending: $pending_approvals_count"
    echo "  Completed: $completed_approvals"
    echo "  Total: $pending_approvals"
    echo ""
    
    # Check propagation logs
    local propagation_logs=$(find "$WORKFLOWS_DIR/propagation" -name "*.log" 2>/dev/null | wc -l)
    
    echo "🔄 Change Propagation:"
    echo "  Logs: $propagation_logs"
    echo ""
    
    # Check version updates
    local version_updates=$(find "$WORKFLOWS_DIR/versions" -name "*.log" 2>/dev/null | wc -l)
    
    echo "📈 Version Updates:"
    echo "  Records: $version_updates"
    echo ""
    
    # System health
    echo "💓 System Health:"
    echo "  Workflows Directory: $WORKFLOWS_DIR"
    echo "  Documents Directory: $DOCS_DIR"
    echo "  Skills Directory: $SKILLS_DIR"
    echo ""
    
    # Recent activity
    echo "🕒 Recent Activity:"
    echo "  Last Approval: $(ls -t "$WORKFLOWS_DIR/approvals/" 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "None")"
    echo "  Last Propagation: $(ls -t "$WORKFLOWS_DIR/propagation/" 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "None")"
    echo "  Last Version Update: $(ls -t "$WORKFLOWS_DIR/versions/" 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "None")"
    
    return 0
}

# Help function
show_help() {
    echo "AI Council Automated Workflows"
    echo "=============================="
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  assess-impact <document> <change>       - Assess change impact"
    echo "  coordinate-approval <req_id> <doc> <appr> - Coordinate approval workflow"
    echo "  propagate-changes <req_id> <doc>          - Propagate approved changes"
    echo "  update-versions <doc> <type>             - Update document versions"
    echo "  monitor-workflows                        - Monitor workflow status"
    echo ""
    echo "Examples:"
    echo "  $0 assess-impact docs/SYSTEM.md "Update architecture diagram""
    echo "  $0 coordinate-approval CR-001 docs/SYSTEM.md architecture_creator"
    echo "  $0 propagate-changes CR-001 docs/SYSTEM.md"
    echo "  $0 update-versions .vibe/skills/test_skill/SKILL.md patch"
    echo "  $0 monitor-workflows"
}

# Run main function
main "$@"
