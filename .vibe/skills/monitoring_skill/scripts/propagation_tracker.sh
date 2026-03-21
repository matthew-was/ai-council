#!/bin/bash

# Change Propagation Tracking
# Track and monitor change propagation status

set -e

echo "📦 Change Propagation Tracking"
echo "============================="
echo ""

# Configuration
MONITORING_DIR=".vibe/monitoring"
WORKFLOWS_DIR=".vibe/workflows"
PROPAGATION_DIR="$WORKFLOWS_DIR/propagation"
TRACKING_DIR="$MONITORING_DIR/propagation_tracking"

# Create directories
mkdir -p "$TRACKING_DIR"

# Main function
main() {
    local command="$1"
    shift
    
    case "$command" in
        track)
            track_propagation "$@"
            ;;
        monitor)
            monitor_propagations "$@"
            ;;
        status)
            propagation_status "$@"
            ;;
        report)
            generate_tracking_report "$@"
            ;;
        *)
            show_help
            ;;
    esac
}

# Track propagation
track_propagation() {
    local request_id="$1"
    local document="$2"
    
    if [[ -z "$request_id" || -z "$document" ]]; then
        echo "Error: Request ID and document required"
        echo "Usage: $0 track <request_id> <document>"
        return 1
    fi
    
    echo "📍 Tracking propagation for: $request_id"
    echo "Document: $document"
    echo ""
    
    # Create tracking record
    local timestamp=$(date +%Y-%m-%d_%H%M%S)
    local tracking_file="$TRACKING_DIR/tracking_${request_id}_${timestamp}.md"
    
    cat > "$tracking_file" << EOF
# Propagation Tracking: $request_id

**Status**: In Progress ⏳
**Started**: $(date)
**Request ID**: $request_id
**Document**: $document

## Propagation Timeline

### Initiation
- **Time**: $(date)
- **Status**: Propagation initiated
- **Document**: $document
- **Request ID**: $request_id

### Current Status
- **Phase**: Initialization
- **Progress**: 0%
- **Estimated Completion**: <calculating>

## Propagation Details

### Document Information
- **Path**: $document
- **Type**: <detecting>
- **Size**: <calculating> lines

### Propagation Plan
- **Plan File**: Pending
- **Strategy**: <determining>
- **Steps**: <planning>

## Tracking Log

EOF

    # Add initial tracking entry
    echo "[$(date)] Propagation tracking initiated for $request_id" >> "$tracking_file"
    
    # Determine document type
    local doc_type="unknown"
    if [[ "$document" == *"SKILL.md"* ]]; then
        doc_type="skill"
    elif [[ "$document" == *"docs/"* ]]; then
        doc_type="documentation"
    fi
    
    # Update tracking file
    sed -i "s|<detecting>|$doc_type|" "$tracking_file"
    
    if [[ -f "$document" ]]; then
        local doc_size=$(wc -l < "$document")
        sed -i "s|<calculating>|$doc_size|" "$tracking_file"
    fi
    
    echo "✅ Propagation tracking initiated"
    echo "📄 Tracking file: $tracking_file"
    
    return 0
}

# Monitor propagations
monitor_propagations() {
    echo "👁️  Monitoring all propagations..."
    echo "================================"
    echo ""
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local summary_report="$TRACKING_DIR/tracking_summary_${timestamp}.md"
    
    # Initialize summary report
    cat > "$summary_report" << EOF
# Propagation Tracking Summary Report

**Generated**: $(date)
**Total Propagations**: 0
**In Progress**: 0
**Completed**: 0
**Failed**: 0

## Propagation Overview

EOF
    
    local total_propagations=0
    local in_progress=0
    local completed=0
    local failed=0
    
    # Check propagation directory
    if [[ -d "$PROPAGATION_DIR" ]]; then
        # Count propagation files
        local plans=$(ls "$PROPAGATION_DIR"/plan_* 2>/dev/null | wc -l)
        local logs=$(ls "$PROPAGATION_DIR"/log_* 2>/dev/null | wc -l)
        local completions=$(ls "$PROPAGATION_DIR"/completion_* 2>/dev/null | wc -l)
        
        total_propagations=$((plans + logs + completions))
        
        # Analyze propagation status
        for plan_file in "$PROPAGATION_DIR"/plan_*.md; do
            if [[ -f "$plan_file" ]]; then
                local status=$(grep "Status:" "$plan_file" | awk '{print $2}')
                local request_id=$(basename "$plan_file" | cut -d'_' -f2)
                
                case "$status" in
                    "Planned"|"Initiated")
                        in_progress=$((in_progress + 1))
                        ;;
                    "Completed")
                        completed=$((completed + 1))
                        ;;
                    "Failed")
                        failed=$((failed + 1))
                        ;;
                esac
                
                # Add to summary
                local document=$(grep "Document:" "$plan_file" | awk '{print $2}')
                echo "### Request: $request_id" >> "$summary_report"
                echo "- **Document**: $document" >> "$summary_report"
                echo "- **Status**: $status" >> "$summary_report"
                echo "- **File**: $(basename "$plan_file")" >> "$summary_report"
                echo "" >> "$summary_report"
            fi
        done
        
        # Check for log files
        for log_file in "$PROPAGATION_DIR"/log_*.log; do
            if [[ -f "$log_file" ]]; then
                local request_id=$(basename "$log_file" | cut -d'_' -f2)
                local status=$(grep "Status:" "$log_file" | awk '{print $2}')
                
                if [[ "$status" == "Success" ]]; then
                    completed=$((completed + 1))
                else
                    failed=$((failed + 1))
                fi
            fi
        done
        
        # Check for completion files
        for completion_file in "$PROPAGATION_DIR"/completion_*.md; do
            if [[ -f "$completion_file" ]]; then
                completed=$((completed + 1))
            fi
        done
    fi
    
    # Update summary statistics
    sed -i "s/Total Propagations: 0/Total Propagations: $total_propagations/" "$summary_report"
    sed -i "s/In Progress: 0/In Progress: $in_progress/" "$summary_report"
    sed -i "s/Completed: 0/Completed: $completed/" "$summary_report"
    sed -i "s/Failed: 0/Failed: $failed/" "$summary_report"
    
    # Calculate success rate
    local success_rate=0
    if [[ $total_propagations -gt 0 ]]; then
        success_rate=$((completed * 100 / total_propagations))
    fi
    
    cat >> "$summary_report" << EOF

## Propagation Statistics

- **Total Propagations**: $total_propagations
- **In Progress**: $in_progress
- **Completed**: $completed
- **Failed**: $failed
- **Success Rate**: $success_rate%

## Status Distribution

EOF
    
    if [[ $success_rate -ge 90 ]]; then
        echo "🟢 **Overall Status: Excellent**" >> "$summary_report"
    elif [[ $success_rate -ge 70 ]]; then
        echo "🟡 **Overall Status: Good**" >> "$summary_report"
    elif [[ $success_rate -ge 50 ]]; then
        echo "🟠 **Overall Status: Fair**" >> "$summary_report"
    else
        echo "🔴 **Overall Status: Poor**" >> "$summary_report"
    fi
    
    cat >> "$summary_report" << 'EOF'

## Recommendations

EOF
    
    if [[ $in_progress -gt 0 ]]; then
        echo "- Monitor $in_progress propagation(s) in progress" >> "$summary_report"
    fi
    
    if [[ $failed -gt 0 ]]; then
        echo "- Review $failed failed propagation(s)" >> "$summary_report"
    fi
    
    echo "- Maintain propagation tracking" >> "$summary_report"
    echo "- Verify completion status" >> "$summary_report"
    echo "- Archive completed propagations" >> "$summary_report"
    
    cat >> "$summary_report" << 'EOF'

## Tracking Metadata

- **Summary ID**: $(basename "$summary_report" .md)
- **Generated**: $(date)
- **Total Propagations**: $total_propagations
- **Status**: Completed ✅

---

*Propagation tracking summary report generated by AI Council Monitoring System*
EOF

    echo "📊 Propagation Monitoring Summary:"
    echo "  Total Propagations: $total_propagations"
    echo "  In Progress: $in_progress"
    echo "  Completed: $completed"
    echo "  Failed: $failed"
    echo "  Success Rate: $success_rate%"
    echo ""
    echo "✅ Propagation monitoring completed"
    echo "📄 Summary report: $summary_report"
    
    return 0
}

# Propagation status
propagation_status() {
    local request_id="$1"
    
    if [[ -z "$request_id" ]]; then
        echo "Error: Request ID required"
        echo "Usage: $0 status <request_id>"
        return 1
    fi
    
    echo "📍 Checking status for propagation: $request_id"
    echo "=============================================="
    echo ""
    
    # Find tracking file
    local tracking_file=$(find "$TRACKING_DIR" -name "*$request_id*" -type f | head -1)
    
    if [[ -z "$tracking_file" ]]; then
        echo "❌ No tracking record found for: $request_id"
        return 1
    fi
    
    # Display tracking information
    cat "$tracking_file"
    
    # Check propagation files
    echo ""
    echo "📋 Related Propagation Files:"
    
    local plan_file=$(find "$PROPAGATION_DIR" -name "*$request_id*" -type f | grep "plan" | head -1)
    local log_file=$(find "$PROPAGATION_DIR" -name "*$request_id*" -type f | grep "log" | head -1)
    local completion_file=$(find "$PROPAGATION_DIR" -name "*$request_id*" -type f | grep "completion" | head -1)
    
    if [[ -n "$plan_file" ]]; then
        echo "  📋 Plan: $(basename "$plan_file")"
    else
        echo "  📋 Plan: Not found"
    fi
    
    if [[ -n "$log_file" ]]; then
        echo "  📊 Log: $(basename "$log_file")"
    else
        echo "  📊 Log: Not found"
    fi
    
    if [[ -n "$completion_file" ]]; then
        echo "  ✅ Completion: $(basename "$completion_file")"
    else
        echo "  ✅ Completion: Not found"
    fi
    
    return 0
}

# Generate tracking report
generate_tracking_report() {
    echo "📊 Generating comprehensive tracking report..."
    
    # Run full monitoring
    monitor_propagations
    
    # Find the most recent summary report
    local summary_report=$(ls -t "$TRACKING_DIR"/tracking_summary_*.md | head -1)
    
    if [[ -f "$summary_report" ]]; then
        echo "📄 Tracking report generated: $summary_report"
        cat "$summary_report"
    else
        echo "❌ No tracking report found"
        return 1
    fi
    
    return 0
}

# Help function
show_help() {
    echo "AI Council Change Propagation Tracking"
    echo "======================================="
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  track <req_id> <doc>           - Track new propagation"
    echo "  monitor                        - Monitor all propagations"
    echo "  status <req_id>               - Check propagation status"
    echo "  report                         - Generate tracking report"
    echo ""
    echo "Examples:"
    echo "  $0 track CR-001 docs/SYSTEM.md"
    echo "  $0 monitor"
    echo "  $0 status CR-001"
    echo "  $0 report"
}

# Run main function
main "$@"
