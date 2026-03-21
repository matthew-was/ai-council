#!/bin/bash

# Approval Workflow Monitoring
# Monitor and track approval workflow status

set -e

echo "📋 Approval Workflow Monitoring"
echo "================================"
echo ""

# Configuration
MONITORING_DIR=".vibe/monitoring"
WORKFLOWS_DIR=".vibe/workflows"
APPROVALS_DIR="$WORKFLOWS_DIR/approvals"
MONITORING_DIR="$MONITORING_DIR/approval_monitoring"

# Create directories
mkdir -p "$MONITORING_DIR"

# Main function
main() {
    local command="$1"
    shift
    
    case "$command" in
        monitor)
            monitor_approvals "$@"
            ;;
        status)
            approval_status "$@"
            ;;
        report)
            generate_monitoring_report "$@"
            ;;
        alerts)
            check_approval_alerts "$@"
            ;;
        *)
            show_help
            ;;
    esac
}

# Monitor approvals
monitor_approvals() {
    echo "👁️  Monitoring all approval workflows..."
    echo "======================================="
    echo ""
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local summary_report="$MONITORING_DIR/approval_summary_${timestamp}.md"
    
    # Initialize summary report
    cat > "$summary_report" << EOF
# Approval Workflow Monitoring Report

**Generated**: $(date)
**Total Requests**: 0
**Pending**: 0
**Approved**: 0
**Rejected**: 0
**Overdue**: 0

## Approval Workflow Overview

EOF
    
    local total_requests=0
    local pending=0
    local approved=0
    local rejected=0
    local overdue=0
    
    # Check approval directories
    if [[ -d "$APPROVALS_DIR" ]]; then
        # Count requests by status
        pending=$(ls "$APPROVALS_DIR/pending" 2>/dev/null | wc -l)
        approved=$(ls "$APPROVALS_DIR/approved" 2>/dev/null | wc -l)
        rejected=$(ls "$APPROVALS_DIR/rejected" 2>/dev/null | wc -l)
        
        total_requests=$((pending + approved + rejected))
        
        # Check for overdue requests
        local today=$(date +%Y-%m-%d)
        for file in "$APPROVALS_DIR/pending"/*; do
            if [[ -f "$file" ]]; then
                local deadline=$(grep "Deadline:" "$file" | awk '{print $2}')
                if [[ "$deadline" < "$today" ]]; then
                    overdue=$((overdue + 1))
                fi
            fi
        done
        
        # Add pending requests to summary
        if [[ $pending -gt 0 ]]; then
            echo "### Pending Requests ($pending)" >> "$summary_report"
            echo "" >> "$summary_report"
            
            for file in "$APPROVALS_DIR/pending"/*; do
                if [[ -f "$file" ]]; then
                    local request_id=$(basename "$file" | cut -d'_' -f2)
                    local document=$(grep "Document:" "$file" | awk '{print $2}')
                    local created=$(grep "Created:" "$file" | awk '{print $2,$3,$4}')
                    local deadline=$(grep "Deadline:" "$file" | awk '{print $2}')
                    
                    echo "#### $request_id" >> "$summary_report"
                    echo "- **Document**: $document" >> "$summary_report"
                    echo "- **Created**: $created" >> "$summary_report"
                    echo "- **Deadline**: $deadline" >> "$summary_report"
                    
                    if [[ "$deadline" < "$today" ]]; then
                        echo "- **Status**: ❌ OVERDUE" >> "$summary_report"
                    else
                        echo "- **Status**: ⏳ Pending" >> "$summary_report"
                    fi
                    
                    echo "- **File**: $(basename "$file")" >> "$summary_report"
                    echo "" >> "$summary_report"
                fi
            done
        fi
        
        # Add approved requests to summary
        if [[ $approved -gt 0 ]]; then
            echo "### Approved Requests ($approved)" >> "$summary_report"
            echo "" >> "$summary_report"
            
            local count=0
            for file in $(ls -t "$APPROVALS_DIR/approved"/* 2>/dev/null); do
                if [[ -f "$file" ]]; then
                    local request_id=$(basename "$file" | cut -d'_' -f2)
                    local document=$(grep "Document:" "$file" | awk '{print $2}')
                    local approved_date=$(grep "Approved:" "$file" | awk '{print $2,$3,$4}')
                    
                    echo "#### $request_id" >> "$summary_report"
                    echo "- **Document**: $document" >> "$summary_report"
                    echo "- **Approved**: $approved_date" >> "$summary_report"
                    echo "- **Status**: ✅ Approved" >> "$summary_report"
                    echo "- **File**: $(basename "$file")" >> "$summary_report"
                    echo "" >> "$summary_report"
                    
                    count=$((count + 1))
                    if [[ $count -ge 5 ]]; then
                        break
                    fi
                fi
            done
        fi
        
        # Add rejected requests to summary
        if [[ $rejected -gt 0 ]]; then
            echo "### Rejected Requests ($rejected)" >> "$summary_report"
            echo "" >> "$summary_report"
            
            local count=0
            for file in $(ls -t "$APPROVALS_DIR/rejected"/* 2>/dev/null); do
                if [[ -f "$file" ]]; then
                    local request_id=$(basename "$file" | cut -d'_' -f2)
                    local document=$(grep "Document:" "$file" | awk '{print $2}')
                    local rejected_date=$(grep "Rejected:" "$file" | awk '{print $2,$3,$4}')
                    local reason=$(grep -A 1 "Rejection Reason" "$file" | tail -1)
                    
                    echo "#### $request_id" >> "$summary_report"
                    echo "- **Document**: $document" >> "$summary_report"
                    echo "- **Rejected**: $rejected_date" >> "$summary_report"
                    echo "- **Reason**: $reason" >> "$summary_report"
                    echo "- **Status**: ❌ Rejected" >> "$summary_report"
                    echo "- **File**: $(basename "$file")" >> "$summary_report"
                    echo "" >> "$summary_report"
                    
                    count=$((count + 1))
                    if [[ $count -ge 5 ]]; then
                        break
                    fi
                fi
            done
        fi
    fi
    
    # Update summary statistics
    sed -i "s/Total Requests: 0/Total Requests: $total_requests/" "$summary_report"
    sed -i "s/Pending: 0/Pending: $pending/" "$summary_report"
    sed -i "s/Approved: 0/Approved: $approved/" "$summary_report"
    sed -i "s/Rejected: 0/Rejected: $rejected/" "$summary_report"
    sed -i "s/Overdue: 0/Overdue: $overdue/" "$summary_report"
    
    # Calculate metrics
    local approval_rate=0
    local rejection_rate=0
    local overdue_rate=0
    
    if [[ $total_requests -gt 0 ]]; then
        approval_rate=$((approved * 100 / total_requests))
        rejection_rate=$((rejected * 100 / total_requests))
        overdue_rate=$((overdue * 100 / pending))
    fi
    
    cat >> "$summary_report" << EOF

## Approval Statistics

- **Total Requests**: $total_requests
- **Pending**: $pending
- **Approved**: $approved
- **Rejected**: $rejected
- **Overdue**: $overdue
- **Approval Rate**: $approval_rate%
- **Rejection Rate**: $rejection_rate%
- **Overdue Rate**: ${overdue_rate}%

## Performance Metrics

EOF
    
    if [[ $total_requests -gt 0 ]]; then
        # Calculate average approval time (stub - would require date parsing)
        echo "- **Average Approval Time**: <calculating>" >> "$summary_report"
        echo "- **Fastest Approval**: <calculating>" >> "$summary_report"
        echo "- **Slowest Approval**: <calculating>" >> "$summary_report"
    else
        echo "- **Average Approval Time**: No data" >> "$summary_report"
    fi
    
    cat >> "$summary_report" << 'EOF'

## Status Assessment

EOF
    
    if [[ $overdue -gt 0 ]]; then
        echo "🔴 **Critical**: $overdue overdue approval(s) require immediate attention" >> "$summary_report"
    elif [[ $pending -gt 5 ]]; then
        echo "🟡 **Warning**: High number of pending approvals ($pending)" >> "$summary_report"
    else
        echo "✅ **Healthy**: Approval workflows operating normally" >> "$summary_report"
    fi
    
    cat >> "$summary_report" << 'EOF'

## Recommendations

EOF
    
    if [[ $overdue -gt 0 ]]; then
        echo "- ❌ **URGENT**: Process $overdue overdue approval request(s) immediately" >> "$summary_report"
    fi
    
    if [[ $pending -gt 3 ]]; then
        echo "- ⚠️  Review $pending pending approval request(s)" >> "$summary_report"
    fi
    
    echo "- ✅ Maintain regular approval workflow monitoring" >> "$summary_report"
    echo "- ✅ Process approvals within deadline periods" >> "$summary_report"
    echo "- ✅ Archive completed approval records" >> "$summary_report"
    
    cat >> "$summary_report" << 'EOF'

## Monitoring Metadata

- **Monitoring ID**: $(basename "$summary_report" .md)
- **Generated**: $(date)
- **Total Requests**: $total_requests
- **Status**: Completed ✅

---

*Approval workflow monitoring report generated by AI Council Monitoring System*
EOF

    echo "📊 Approval Monitoring Summary:"
    echo "  Total Requests: $total_requests"
    echo "  Pending: $pending"
    echo "  Approved: $approved"
    echo "  Rejected: $rejected"
    echo "  Overdue: $overdue"
    echo "  Approval Rate: $approval_rate%"
    echo ""
    
    if [[ $overdue -gt 0 ]]; then
        echo "❌ CRITICAL: $overdue overdue approval(s) require immediate attention"
    elif [[ $pending -gt 5 ]]; then
        echo "⚠️  WARNING: High number of pending approvals ($pending)"
    else
        echo "✅ Healthy: Approval workflows operating normally"
    fi
    
    echo ""
    echo "✅ Approval monitoring completed"
    echo "📄 Summary report: $summary_report"
    
    return 0
}

# Approval status
approval_status() {
    local request_id="$1"
    
    if [[ -z "$request_id" ]]; then
        echo "Error: Request ID required"
        echo "Usage: $0 status <request_id>"
        return 1
    fi
    
    echo "📍 Checking status for approval: $request_id"
    echo "============================================="
    echo ""
    
    # Search in all approval directories
    local request_file=$(find "$APPROVALS_DIR" -name "*$request_id*" -type f | head -1)
    
    if [[ -z "$request_file" ]]; then
        echo "❌ Approval request not found: $request_id"
        return 1
    fi
    
    # Display request details
    cat "$request_file"
    
    # Extract key information
    local status=$(grep "Status:" "$request_file" | awk '{print $2}')
    local document=$(grep "Document:" "$request_file" | awk '{print $2}')
    local deadline=$(grep "Deadline:" "$request_file" | awk '{print $2}')
    local today=$(date +%Y-%m-%d)
    
    echo ""
    echo "📋 Status Summary:"
    echo "  Request ID: $request_id"
    echo "  Document: $document"
    echo "  Status: $status"
    echo "  Deadline: $deadline"
    
    if [[ "$deadline" < "$today" && "$status" == "Pending" ]]; then
        echo "  🔴 ALERT: This request is OVERDUE"
    fi
    
    return 0
}

# Generate monitoring report
generate_monitoring_report() {
    echo "📊 Generating comprehensive monitoring report..."
    
    # Run full monitoring
    monitor_approvals
    
    # Find the most recent summary report
    local summary_report=$(ls -t "$MONITORING_DIR"/approval_summary_*.md | head -1)
    
    if [[ -f "$summary_report" ]]; then
        echo "📄 Monitoring report generated: $summary_report"
        cat "$summary_report"
    else
        echo "❌ No monitoring report found"
        return 1
    fi
    
    return 0
}

# Check approval alerts
check_approval_alerts() {
    echo "🚨 Checking for approval alerts..."
    echo "=================================="
    echo ""
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local alerts_report="$MONITORING_DIR/alerts_${timestamp}.md"
    
    # Initialize alerts report
    cat > "$alerts_report" << EOF
# Approval Alerts Report

**Generated**: $(date)
**Critical Alerts**: 0
**Warning Alerts**: 0
**Informational**: 0

## Alerts Summary

EOF
    
    local critical_alerts=0
    local warning_alerts=0
    local informational=0
    
    # Check for overdue requests
    local today=$(date +%Y-%m-%d)
    local overdue_count=0
    
    if [[ -d "$APPROVALS_DIR/pending" ]]; then
        for file in "$APPROVALS_DIR/pending"/*; do
            if [[ -f "$file" ]]; then
                local deadline=$(grep "Deadline:" "$file" | awk '{print $2}')
                if [[ "$deadline" < "$today" ]]; then
                    overdue_count=$((overdue_count + 1))
                    
                    local request_id=$(basename "$file" | cut -d'_' -f2)
                    local document=$(grep "Document:" "$file" | awk '{print $2}')
                    local created=$(grep "Created:" "$file" | awk '{print $2,$3,$4}')
                    
                    echo "### 🔴 CRITICAL: Overdue Approval" >> "$alerts_report"
                    echo "" >> "$alerts_report"
                    echo "**Request ID**: $request_id" >> "$alerts_report"
                    echo "**Document**: $document" >> "$alerts_report"
                    echo "**Created**: $created" >> "$alerts_report"
                    echo "**Deadline**: $deadline" >> "$alerts_report"
                    echo "**Status**: ❌ OVERDUE by $((($(date +%s) - $(date -j -f "%Y-%m-%d" "$deadline" +%s)) / 86400)) day(s)" >> "$alerts_report"
                    echo "" >> "$alerts_report"
                    
                    critical_alerts=$((critical_alerts + 1))
                fi
            fi
        done
    fi
    
    # Check for high number of pending requests
    local pending_count=$(ls "$APPROVALS_DIR/pending" 2>/dev/null | wc -l)
    if [[ $pending_count -gt 5 ]]; then
        echo "### 🟡 WARNING: High Pending Requests" >> "$alerts_report"
        echo "" >> "$alerts_report"
        echo "**Pending Count**: $pending_count" >> "$alerts_report"
        echo "**Threshold**: 5" >> "$alerts_report"
        echo "**Recommendation**: Review and process pending approvals" >> "$alerts_report"
        echo "" >> "$alerts_report"
        
        warning_alerts=$((warning_alerts + 1))
    fi
    
    # Check for low approval rate
    local total_requests=$(ls "$APPROVALS_DIR/pending" "$APPROVALS_DIR/approved" "$APPROVALS_DIR/rejected" 2>/dev/null | wc -l)
    local approved_count=$(ls "$APPROVALS_DIR/approved" 2>/dev/null | wc -l)
    
    if [[ $total_requests -gt 0 ]]; then
        local approval_rate=$((approved_count * 100 / total_requests))
        
        if [[ $approval_rate -lt 50 ]]; then
            echo "### 🟡 WARNING: Low Approval Rate" >> "$alerts_report"
            echo "" >> "$alerts_report"
            echo "**Approval Rate**: $approval_rate%" >> "$alerts_report"
            echo "**Threshold**: 50%" >> "$alerts_report"
            echo "**Recommendation**: Review approval criteria and processes" >> "$alerts_report"
            echo "" >> "$alerts_report"
            
            warning_alerts=$((warning_alerts + 1))
        fi
    fi
    
    # Update alerts count
    sed -i "s/Critical Alerts: 0/Critical Alerts: $critical_alerts/" "$alerts_report"
    sed -i "s/Warning Alerts: 0/Warning Alerts: $warning_alerts/" "$alerts_report"
    
    # Calculate total alerts
    local total_alerts=$((critical_alerts + warning_alerts))
    sed -i "s/Informational: 0/Informational: $((informational))/
    
    cat >> "$alerts_report" << EOF

## Alerts Statistics

- **Critical Alerts**: $critical_alerts
- **Warning Alerts**: $warning_alerts
- **Total Alerts**: $total_alerts

## Alert Severity

EOF
    
    if [[ $critical_alerts -gt 0 ]]; then
        echo "🔴 **CRITICAL**: Immediate action required" >> "$alerts_report"
    elif [[ $warning_alerts -gt 0 ]]; then
        echo "🟡 **WARNING**: Review recommended" >> "$alerts_report"
    else
        echo "✅ **HEALTHY**: No active alerts" >> "$alerts_report"
    fi
    
    cat >> "$alerts_report" << 'EOF'

## Recommendations

EOF
    
    if [[ $critical_alerts -gt 0 ]]; then
        echo "- ❌ **CRITICAL**: Process $critical_alerts overdue approval(s) immediately" >> "$alerts_report"
    fi
    
    if [[ $warning_alerts -gt 0 ]]; then
        echo "- ⚠️  Review $warning_alerts warning alert(s)" >> "$alerts_report"
    fi
    
    echo "- ✅ Monitor approval workflows regularly" >> "$alerts_report"
    echo "- ✅ Maintain approval deadlines" >> "$alerts_report"
    echo "- ✅ Review approval processes periodically" >> "$alerts_report"
    
    cat >> "$alerts_report" << 'EOF'

## Alerts Metadata

- **Alerts ID**: $(basename "$alerts_report" .md)
- **Generated**: $(date)
- **Critical Alerts**: $critical_alerts
- **Warning Alerts**: $warning_alerts
- **Status**: Completed ✅

---

*Approval alerts report generated by AI Council Monitoring System*
EOF

    echo "🚨 Approval Alerts Summary:"
    echo "  Critical Alerts: $critical_alerts"
    echo "  Warning Alerts: $warning_alerts"
    echo "  Total Alerts: $total_alerts"
    echo ""
    
    if [[ $critical_alerts -gt 0 ]]; then
        echo "🔴 CRITICAL: $critical_alerts alert(s) require immediate action"
    elif [[ $warning_alerts -gt 0 ]]; then
        echo "🟡 WARNING: $warning_alerts alert(s) recommend review"
    else
        echo "✅ Healthy: No active alerts"
    fi
    
    echo ""
    echo "✅ Alerts check completed"
    echo "📄 Alerts report: $alerts_report"
    
    return 0
}

# Help function
show_help() {
    echo "AI Council Approval Workflow Monitoring"
    echo "======================================="
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  monitor                        - Monitor all approval workflows"
    echo "  status <request_id>           - Check approval request status"
    echo "  report                         - Generate monitoring report"
    echo "  alerts                         - Check for approval alerts"
    echo ""
    echo "Examples:"
    echo "  $0 monitor"
    echo "  $0 status CR-001"
    echo "  $0 report"
    echo "  $0 alerts"
}

# Run main function
main "$@"
