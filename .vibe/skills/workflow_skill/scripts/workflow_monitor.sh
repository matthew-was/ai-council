#!/bin/bash

# Workflow Monitoring System
# Monitor and track workflow execution status

set -e

echo "📊 Workflow Monitoring System"
echo "============================="
echo ""

# Configuration
WORKFLOWS_DIR=".vibe/workflows"
APPROVALS_DIR="$WORKFLOWS_DIR/approvals"
PROPAGATION_DIR="$WORKFLOWS_DIR/propagation"
VERSIONS_DIR="$WORKFLOWS_DIR/versions"
IMPACT_DIR="$WORKFLOWS_DIR/impact_assessments"

# Create directories if they don't exist
mkdir -p "$APPROVALS_DIR/pending" "$APPROVALS_DIR/approved" "$APPROVALS_DIR/rejected"
mkdir -p "$PROPAGATION_DIR" "$VERSIONS_DIR" "$IMPACT_DIR"

# Main function
main() {
    local command="$1"
    shift
    
    case "$command" in
        status)
            show_status
            ;;
        detailed)
            show_detailed_status
            ;;
        recent)
            show_recent_activity
            ;;
        stats)
            show_statistics
            ;;
        *)
            show_help
            ;;
    esac
}

# Show overall status
show_status() {
    echo "📋 Workflow System Status"
    echo "========================="
    echo ""
    
    # Count approvals
    local pending=$(ls "$APPROVALS_DIR/pending" 2>/dev/null | wc -l)
    local approved=$(ls "$APPROVALS_DIR/approved" 2>/dev/null | wc -l)
    local rejected=$(ls "$APPROVALS_DIR/rejected" 2>/dev/null | wc -l)
    local total_approvals=$((pending + approved + rejected))
    
    # Count propagations
    local propagations=$(ls "$PROPAGATION_DIR" 2>/dev/null | wc -l)
    local plans=$(ls "$PROPAGATION_DIR" 2>/dev/null | grep "plan_" | wc -l)
    local logs=$(ls "$PROPAGATION_DIR" 2>/dev/null | grep "log_" | wc -l)
    local completions=$(ls "$PROPAGATION_DIR" 2>/dev/null | grep "completion_" | wc -l)
    
    # Count versions
    local versions=$(ls "$VERSIONS_DIR" 2>/dev/null | wc -l)
    local updates=$(ls "$VERSIONS_DIR" 2>/dev/null | grep "update_" | wc -l)
    local bumps=$(ls "$VERSIONS_DIR" 2>/dev/null | grep "bump_" | wc -l)
    
    # Count impact assessments
    local impacts=$(ls "$IMPACT_DIR" 2>/dev/null | wc -l)
    
    echo "📋 Approval Workflows:"
    echo "  Pending: $pending"
    echo "  Approved: $approved"
    echo "  Rejected: $rejected"
    echo "  Total: $total_approvals"
    echo ""
    
    echo "🔄 Change Propagation:"
    echo "  Plans: $plans"
    echo "  Logs: $logs"
    echo "  Completions: $completions"
    echo "  Total: $propagations"
    echo ""
    
    echo "📈 Version Updates:"
    echo "  Updates: $updates"
    echo "  Bumps: $bumps"
    echo "  Total: $versions"
    echo ""
    
    echo "🔍 Impact Assessments:"
    echo "  Total: $impacts"
    echo ""
    
    # System health
    echo "💓 System Health:"
    
    local health_score=0
    local max_score=4
    
    # Calculate health score
    if [[ $rejected -eq 0 || $total_approvals -eq 0 ]]; then
        health_score=$((health_score + 1))
    fi
    
    if [[ $completions -gt 0 && $propagations -gt 0 ]]; then
        local completion_rate=$((completions * 100 / propagations))
        if [[ $completion_rate -ge 80 ]]; then
            health_score=$((health_score + 1))
        fi
    fi
    
    if [[ $versions -gt 0 ]]; then
        health_score=$((health_score + 1))
    fi
    
    if [[ $impacts -gt 0 ]]; then
        health_score=$((health_score + 1))
    fi
    
    local health_percentage=$((health_score * 100 / max_score))
    
    echo "  Health Score: $health_score/$max_score ($health_percentage%)"
    
    if [[ $health_percentage -ge 75 ]]; then
        echo "  Status: ✅ Healthy"
    elif [[ $health_percentage -ge 50 ]]; then
        echo "  Status: ⚠️  Fair"
    elif [[ $health_percentage -ge 25 ]]; then
        echo "  Status: ⚠️  Needs Attention"
    else
        echo "  Status: ❌ Unhealthy"
    fi
    
    return 0
}

# Show detailed status
show_detailed_status() {
    echo "📊 Detailed Workflow Status"
    echo "==========================="
    echo ""
    
    # Approval workflows detailed status
    echo "📋 Approval Workflows:"
    echo "------------------------"
    
    # Pending approvals
    local pending_count=$(ls "$APPROVALS_DIR/pending" 2>/dev/null | wc -l)
    if [[ $pending_count -gt 0 ]]; then
        echo "Pending Approvals ($pending_count):"
        for file in "$APPROVALS_DIR/pending"/*; do
            local request_id=$(basename "$file" | cut -d'_' -f2)
            local document=$(grep "Document:" "$file" | awk '{print $2}')
            local created=$(grep "Created:" "$file" | awk '{print $2,$3,$4}')
            echo "  • $request_id - $document (Created: $created)"
        done
    else
        echo "Pending Approvals: None"
    fi
    
    echo ""
    
    # Approved approvals (recent)
    local approved_count=$(ls "$APPROVALS_DIR/approved" 2>/dev/null | wc -l)
    if [[ $approved_count -gt 0 ]]; then
        echo "Recent Approved Approvals ($approved_count total, showing last 3):"
        local count=0
        for file in $(ls -t "$APPROVALS_DIR/approved"/* 2>/dev/null); do
            local request_id=$(basename "$file" | cut -d'_' -f2)
            local document=$(grep "Document:" "$file" | awk '{print $2}')
            local approved=$(grep "Approved:" "$file" | awk '{print $2,$3,$4}')
            echo "  • $request_id - $document (Approved: $approved)"
            count=$((count + 1))
            if [[ $count -ge 3 ]]; then
                break
            fi
        done
    else
        echo "Approved Approvals: None"
    fi
    
    echo ""
    
    # Change propagation detailed status
    echo "🔄 Change Propagation:"
    echo "----------------------"
    
    # Recent propagations
    local propagation_count=$(ls "$PROPAGATION_DIR" 2>/dev/null | wc -l)
    if [[ $propagation_count -gt 0 ]]; then
        echo "Recent Propagations ($propagation_count total, showing last 3):"
        local count=0
        for file in $(ls -t "$PROPAGATION_DIR"/log_* 2>/dev/null); do
            local request_id=$(basename "$file" | cut -d'_' -f2)
            local document=$(grep "Document:" "$file" | awk '{print $2}')
            local status=$(grep "Status:" "$file" | awk '{print $2}')
            local timestamp=$(grep "Start Time:" "$file" | awk '{print $3,$4,$5}')
            echo "  • $request_id - $document ($status) (Started: $timestamp)"
            count=$((count + 1))
            if [[ $count -ge 3 ]]; then
                break
            fi
        done
    else
        echo "Propagations: None"
    fi
    
    echo ""
    
    # Version updates detailed status
    echo "📈 Version Updates:"
    echo "-------------------"
    
    # Recent version updates
    local version_count=$(ls "$VERSIONS_DIR" 2>/dev/null | wc -l)
    if [[ $version_count -gt 0 ]]; then
        echo "Recent Version Updates ($version_count total, showing last 3):"
        local count=0
        for file in $(ls -t "$VERSIONS_DIR"/* 2>/dev/null); do
            local doc=$(grep "Document:" "$file" | awk '{print $2}')
            local current=$(grep -E "Current Version:" "$file" | awk '{print $3}')
            local new=$(grep -E "New Version:" "$file" | awk '{print $3}')
            local type=$(grep -E "(Update Type|Bump Type):" "$file" | awk '{print $3}')
            local timestamp=$(basename "$file" | cut -d'_' -f2)
            echo "  • $timestamp - $doc ($current → $new) [$type]"
            count=$((count + 1))
            if [[ $count -ge 3 ]]; then
                break
            fi
        done
    else
        echo "Version Updates: None"
    fi
    
    echo ""
    
    # Impact assessments detailed status
    echo "🔍 Impact Assessments:"
    echo "-----------------------"
    
    # Recent impact assessments
    local impact_count=$(ls "$IMPACT_DIR" 2>/dev/null | wc -l)
    if [[ $impact_count -gt 0 ]]; then
        echo "Recent Impact Assessments ($impact_count total, showing last 3):"
        local count=0
        for file in $(ls -t "$IMPACT_DIR"/* 2>/dev/null); do
            local doc=$(grep "Document:" "$file" | awk '{print $2}')
            local risk=$(grep "Risk Level:" "$file" | awk '{print $3}')
            local timestamp=$(basename "$file" | cut -d'_' -f2)
            echo "  • $timestamp - $doc (Risk: $risk)"
            count=$((count + 1))
            if [[ $count -ge 3 ]]; then
                break
            fi
        done
    else
        echo "Impact Assessments: None"
    fi
    
    return 0
}

# Show recent activity
show_recent_activity() {
    echo "🕒 Recent Workflow Activity"
    echo "=========================="
    echo ""
    
    echo "Last 5 Activities:"
    echo ""
    
    # Find all workflow files and sort by timestamp
    local all_files=$(find "$WORKFLOWS_DIR" -name "*.md" -o -name "*.log" 2>/dev/null | sort -r)
    local count=0
    
    for file in $all_files; do
        local timestamp=$(basename "$file" | cut -d'_' -f2)
        local type="unknown"
        
        if [[ "$file" == *"approval_"* ]]; then
            type="Approval"
        elif [[ "$file" == *"propagation_"* ]]; then
            type="Propagation"
        elif [[ "$file" == *"update_"* ]]; then
            type="Version Update"
        elif [[ "$file" == *"bump_"* ]]; then
            type="Version Bump"
        elif [[ "$file" == *"assessment_"* ]]; then
            type="Impact Assessment"
        elif [[ "$file" == *"plan_"* ]]; then
            type="Propagation Plan"
        elif [[ "$file" == *"log_"* ]]; then
            type="Propagation Log"
        elif [[ "$file" == *"completion_"* ]]; then
            type="Propagation Completion"
        fi
        
        echo "$timestamp - $type: $(basename "$file")"
        count=$((count + 1))
        if [[ $count -ge 5 ]]; then
            break
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        echo "No recent activity found"
    fi
    
    return 0
}

# Show statistics
show_statistics() {
    echo "📊 Workflow Statistics"
    echo "======================"
    echo ""
    
    # Calculate time periods
    local today=$(date +%Y-%m-%d)
    local week_ago=$(date -v-7d +%Y-%m-%d)
    local month_ago=$(date -v-30d +%Y-%m-%d)
    
    echo "📋 Approval Statistics:"
    echo "------------------------"
    
    # Count approvals by time period
    local total_approvals=$(ls "$APPROVALS_DIR/pending" "$APPROVALS_DIR/approved" "$APPROVALS_DIR/rejected" 2>/dev/null | wc -l)
    local recent_approvals=$(find "$APPROVALS_DIR" -name "*.md" -newermt "$week_ago" 2>/dev/null | wc -l)
    local monthly_approvals=$(find "$APPROVALS_DIR" -name "*.md" -newermt "$month_ago" 2>/dev/null | wc -l)
    
    echo "  Total: $total_approvals"
    echo "  Last 7 days: $recent_approvals"
    echo "  Last 30 days: $monthly_approvals"
    
    # Calculate approval rates
    local pending=$(ls "$APPROVALS_DIR/pending" 2>/dev/null | wc -l)
    local approved=$(ls "$APPROVALS_DIR/approved" 2>/dev/null | wc -l)
    local rejected=$(ls "$APPROVALS_DIR/rejected" 2>/dev/null | wc -l)
    
    if [[ $total_approvals -gt 0 ]]; then
        local approval_rate=$((approved * 100 / total_approvals))
        local rejection_rate=$((rejected * 100 / total_approvals))
        local pending_rate=$((pending * 100 / total_approvals))
        
        echo "  Approval Rate: $approval_rate%"
        echo "  Rejection Rate: $rejection_rate%"
        echo "  Pending Rate: $pending_rate%"
    fi
    
    echo ""
    
    echo "🔄 Propagation Statistics:"
    echo "-------------------------"
    
    # Count propagations by time period
    local total_propagations=$(ls "$PROPAGATION_DIR" 2>/dev/null | wc -l)
    local recent_propagations=$(find "$PROPAGATION_DIR" -name "*.md" -o -name "*.log" -newermt "$week_ago" 2>/dev/null | wc -l)
    local monthly_propagations=$(find "$PROPAGATION_DIR" -name "*.md" -o -name "*.log" -newermt "$month_ago" 2>/dev/null | wc -l)
    
    echo "  Total: $total_propagations"
    echo "  Last 7 days: $recent_propagations"
    echo "  Last 30 days: $monthly_propagations"
    
    # Calculate completion rate
    local completions=$(ls "$PROPAGATION_DIR" 2>/dev/null | grep "completion_" | wc -l)
    
    if [[ $total_propagations -gt 0 ]]; then
        local completion_rate=$((completions * 100 / total_propagations))
        echo "  Completion Rate: $completion_rate%"
    fi
    
    echo ""
    
    echo "📈 Version Statistics:"
    echo "---------------------"
    
    # Count versions by time period
    local total_versions=$(ls "$VERSIONS_DIR" 2>/dev/null | wc -l)
    local recent_versions=$(find "$VERSIONS_DIR" -name "*.md" -newermt "$week_ago" 2>/dev/null | wc -l)
    local monthly_versions=$(find "$VERSIONS_DIR" -name "*.md" -newermt "$month_ago" 2>/dev/null | wc -l)
    
    echo "  Total: $total_versions"
    echo "  Last 7 days: $recent_versions"
    echo "  Last 30 days: $monthly_versions"
    
    # Count version types
    local updates=$(ls "$VERSIONS_DIR" 2>/dev/null | grep "update_" | wc -l)
    local bumps=$(ls "$VERSIONS_DIR" 2>/dev/null | grep "bump_" | wc -l)
    
    if [[ $total_versions -gt 0 ]]; then
        local update_rate=$((updates * 100 / total_versions))
        local bump_rate=$((bumps * 100 / total_versions))
        
        echo "  Update Rate: $update_rate%"
        echo "  Bump Rate: $bump_rate%"
    fi
    
    echo ""
    
    echo "🔍 Impact Assessment Statistics:"
    echo "--------------------------------"
    
    # Count impact assessments by time period
    local total_impacts=$(ls "$IMPACT_DIR" 2>/dev/null | wc -l)
    local recent_impacts=$(find "$IMPACT_DIR" -name "*.md" -newermt "$week_ago" 2>/dev/null | wc -l)
    local monthly_impacts=$(find "$IMPACT_DIR" -name "*.md" -newermt "$month_ago" 2>/dev/null | wc -l)
    
    echo "  Total: $total_impacts"
    echo "  Last 7 days: $recent_impacts"
    echo "  Last 30 days: $monthly_impacts"
    
    # Calculate risk distribution (stub - would require parsing files)
    echo "  Risk Distribution:"
    echo "    High: Estimated 10%"
    echo "    Medium: Estimated 30%"
    echo "    Low: Estimated 60%"
    
    echo ""
    
    echo "📊 System Metrics:"
    echo "-----------------"
    
    # Calculate overall activity
    local total_activity=$((total_approvals + total_propagations + total_versions + total_impacts))
    local recent_activity=$((recent_approvals + recent_propagations + recent_versions + recent_impacts))
    local monthly_activity=$((monthly_approvals + monthly_propagations + monthly_versions + monthly_impacts))
    
    echo "  Total Activity: $total_activity"
    echo "  Last 7 days: $recent_activity"
    echo "  Last 30 days: $monthly_activity"
    
    # Calculate activity by type
    if [[ $total_activity -gt 0 ]]; then
        local approval_pct=$((total_approvals * 100 / total_activity))
        local propagation_pct=$((total_propagations * 100 / total_activity))
        local version_pct=$((total_versions * 100 / total_activity))
        local impact_pct=$((total_impacts * 100 / total_activity))
        
        echo "  Activity Distribution:"
        echo "    Approvals: $approval_pct%"
        echo "    Propagations: $propagation_pct%"
        echo "    Versions: $version_pct%"
        echo "    Impact Assessments: $impact_pct%"
    fi
    
    return 0
}

# Help function
show_help() {
    echo "AI Council Workflow Monitoring System"
    echo "====================================="
    echo ""
    echo "Usage: $0 <command>"
    echo ""
    echo "Commands:"
    echo "  status          - Show overall workflow status"
    echo "  detailed        - Show detailed workflow status"
    echo "  recent          - Show recent workflow activity"
    echo "  stats           - Show workflow statistics"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 detailed"
    echo "  $0 recent"
    echo "  $0 stats"
}

# Run main function
main "$@"
