#!/bin/bash

# Version Compatibility Alerts
# Monitor version compatibility and generate alerts

set -e

echo "🔔 Version Compatibility Alerts"
echo "==============================="
echo ""

# Configuration
MONITORING_DIR=".vibe/monitoring"
SKILLS_DIR=".vibe/skills"
REGISTRY_FILE="$SKILLS_DIR/skills.json"
ALERTS_DIR="$MONITORING_DIR/version_alerts"

# Create directories
mkdir -p "$ALERTS_DIR"

# Main function
main() {
    local command="$1"
    shift
    
    case "$command" in
        check)
            check_version_compatibility "$@"
            ;;
        monitor)
            monitor_all_versions "$@"
            ;;
        alerts)
            generate_alerts_report "$@"
            ;;
        *)
            show_help
            ;;
    esac
}

# Check version compatibility
check_version_compatibility() {
    local skill_name="$1"
    local target_version="$2"
    local output_file="$3"
    
    if [[ -z "$skill_name" || -z "$target_version" ]]; then
        echo "Error: Skill name and target version required"
        echo "Usage: $0 check <skill_name> <target_version> [output_file]"
        return 1
    fi
    
    echo "🔍 Checking compatibility for: $skill_name v$target_version"
    
    # Set default output file
    if [[ -z "$output_file" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        output_file="$ALERTS_DIR/compatibility_${skill_name}_${timestamp}.md"
    fi
    
    # Check if skill exists in registry
    if ! jq -e ".skills[\"$skill_name\"]" "$REGISTRY_FILE" >/dev/null 2>&1; then
        echo "❌ Skill not found in registry: $skill_name"
        return 1
    fi
    
    # Get current version
    local current_version=$(jq -r ".skills[\"$skill_name\"].metadata.version" "$REGISTRY_FILE")
    
    echo "Current Version: $current_version"
    echo "Target Version: $target_version"
    
    # Compare versions
    local comparison=$(compare_versions "$current_version" "$target_version")
    
    # Generate compatibility report
    cat > "$output_file" << EOF
# Version Compatibility Report: $skill_name

**Generated**: $(date)
**Skill**: $skill_name
**Current Version**: $current_version
**Target Version**: $target_version
**Compatibility**: Pending analysis

## Version Comparison

### Version Details
- **Current**: $current_version
- **Target**: $target_version
- **Comparison**: $comparison

### Semantic Version Analysis

EOF
    
    # Parse versions
    local current_major=$(echo "$current_version" | cut -d'.' -f1)
    local current_minor=$(echo "$current_version" | cut -d'.' -f2)
    local current_patch=$(echo "$current_version" | cut -d'.' -f3)
    
    local target_major=$(echo "$target_version" | cut -d'.' -f1)
    local target_minor=$(echo "$target_version" | cut -d'.' -f2)
    local target_patch=$(echo "$target_version" | cut -d'.' -f3)
    
    cat >> "$output_file" << EOF
- **Major Version**: $current_major → $target_major
- **Minor Version**: $current_minor → $target_minor
- **Patch Version**: $current_patch → $target_patch

### Compatibility Assessment

EOF
    
    # Assess compatibility
    local compatible="✅ Compatible"
    local compatibility_score=100
    
    if [[ "$comparison" == "greater" ]]; then
        echo "⚠️  Target version is older than current version" >> "$output_file"
        compatible="⚠️  Downgrade"
        compatibility_score=80
    elif [[ "$comparison" == "equal" ]]; then
        echo "✅ Versions are identical" >> "$output_file"
    else
        echo "✅ Target version is newer" >> "$output_file"
        
        # Check for major version changes
        if [[ $target_major -gt $current_major ]]; then
            echo "⚠️  Major version upgrade detected" >> "$output_file"
            compatible="⚠️  Major Upgrade"
            compatibility_score=60
        elif [[ $target_minor -gt $current_minor ]]; then
            echo "ℹ️  Minor version upgrade detected" >> "$output_file"
            compatible="✅ Minor Upgrade"
            compatibility_score=90
        else
            echo "ℹ️  Patch version upgrade detected" >> "$output_file"
            compatible="✅ Patch Upgrade"
            compatibility_score=95
        fi
    fi
    
    cat >> "$output_file" << EOF

### Dependency Compatibility

EOF
    
    # Check dependencies
    local dependencies=$(jq -r ".skills[\"$skill_name\"].dependencies.skills[]" "$REGISTRY_FILE")
    if [[ -n "$dependencies" && "$dependencies" != "null" ]]; then
        echo "Dependent skills: $dependencies" >> "$output_file"
        
        # Check if dependencies would be affected
        for dep in $dependencies; do
            if jq -e ".skills[\"$dep\"]" "$REGISTRY_FILE" >/dev/null 2>&1; then
                local dep_version=$(jq -r ".skills[\"$dep\"].metadata.version" "$REGISTRY_FILE")
                echo "  - $dep: v$dep_version" >> "$output_file"
            fi
        done
    else
        echo "No dependencies found" >> "$output_file"
    fi
    
    cat >> "$output_file" << EOF

## Compatibility Recommendations

EOF
    
    if [[ "$compatible" == "✅ Compatible" || "$compatible" == "✅ Minor Upgrade" || "$compatible" == "✅ Patch Upgrade" ]]; then
        echo "✅ **Compatibility Status: $compatible**" >> "$output_file"
        echo "- Proceed with upgrade" >> "$output_file"
        echo "- Test affected functionality" >> "$output_file"
        echo "- Update documentation" >> "$output_file"
    else
        echo "⚠️  **Compatibility Status: $compatible**" >> "$output_file"
        echo "- Review breaking changes" >> "$output_file"
        echo "- Test thoroughly before deployment" >> "$output_file"
        echo "- Update dependent skills" >> "$output_file"
    fi
    
    cat >> "$output_file" << EOF

- Monitor system behavior
- Check version matrix compatibility
- Validate registry updates

## Compatibility Score

**Score**: $compatibility_score%

### Score Breakdown
- Version Comparison: 25%
- Dependency Impact: 25%
- Upgrade Type: 25%
- Risk Assessment: 25%

### Alert Level

EOF
    
    if [[ $compatibility_score -ge 90 ]]; then
        echo "🟢 **LOW**: Safe to upgrade" >> "$output_file"
    elif [[ $compatibility_score -ge 70 ]]; then
        echo "🟡 **MEDIUM**: Review required" >> "$output_file"
    else
        echo "🔴 **HIGH**: Caution advised" >> "$output_file"
    fi
    
    cat >> "$output_file" << 'EOF'

## Version Metadata

- **Report ID**: $(basename "$output_file" .md)
- **Generated**: $(date)
- **Skill**: $skill_name
- **Current Version**: $current_version
- **Target Version**: $target_version
- **Compatibility**: $compatible

---

*Version compatibility report generated by AI Council Monitoring System*
EOF

    echo "✅ Compatibility check completed"
    echo "📄 Report saved to: $output_file"
    echo "Compatibility: $compatible"
    
    return 0
}

# Monitor all versions
monitor_all_versions() {
    echo "🔄 Monitoring all version compatibilities..."
    echo "=========================================="
    echo ""
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local summary_report="$ALERTS_DIR/version_summary_${timestamp}.md"
    
    # Initialize summary report
    cat > "$summary_report" << EOF
# Version Compatibility Summary Report

**Generated**: $(date)
**Total Skills**: 0
**Compatible**: 0
**Needs Review**: 0

## Version Compatibility Overview

EOF
    
    local total_skills=0
    local compatible_skills=0
    local needs_review=0
    
    # Get all skills from registry
    local skills=$(jq -r '.skills | keys[]' "$REGISTRY_FILE")
    
    for skill in $skills; do
        if [[ "$skill" != "null" ]]; then
            total_skills=$((total_skills + 1))
            
            # Get current version
            local current_version=$(jq -r ".skills[\"$skill\"].metadata.version" "$REGISTRY_FILE")
            
            # Simulate target version (in real implementation, this would come from requirements)
            local target_version="1.1.0"  # Default target for testing
            
            # Generate compatibility report
            local report="$ALERTS_DIR/compatibility_${skill}_${timestamp}.md"
            check_version_compatibility "$skill" "$target_version" "$report"
            
            # Extract compatibility status
            local compatibility_status=$(grep "Compatibility Status" "$report" | awk '{print $3}')
            
            echo "  • $skill ($current_version → $target_version): $compatibility_status"
            
            # Add to summary
            echo "### $skill" >> "$summary_report"
            echo "- **Current**: v$current_version" >> "$summary_report"
            echo "- **Target**: v$target_version" >> "$summary_report"
            echo "- **Status**: $compatibility_status" >> "$summary_report"
            echo "- **Report**: $(basename "$report")" >> "$summary_report"
            echo "" >> "$summary_report"
            
            if [[ "$compatibility_status" == "✅"* ]]; then
                compatible_skills=$((compatible_skills + 1))
            else
                needs_review=$((needs_review + 1))
            fi
        fi
    done
    
    # Update summary statistics
    sed -i "s/Total Skills: 0/Total Skills: $total_skills/" "$summary_report"
    sed -i "s/Compatible: 0/Compatible: $compatible_skills/" "$summary_report"
    sed -i "s/Needs Review: 0/Needs Review: $needs_review/" "$summary_report"
    
    # Calculate overall compatibility
    local overall_compatibility=$((compatible_skills * 100 / total_skills))
    
    cat >> "$summary_report" << EOF

## Summary Statistics

- **Total Skills Monitored**: $total_skills
- **Compatible Upgrades**: $compatible_skills
- **Needs Review**: $needs_review
- **Overall Compatibility**: $overall_compatibility%

## Compatibility Distribution

EOF
    
    if [[ $overall_compatibility -ge 90 ]]; then
        echo "🟢 **Overall Compatibility: Excellent**" >> "$summary_report"
    elif [[ $overall_compatibility -ge 70 ]]; then
        echo "🟡 **Overall Compatibility: Good**" >> "$summary_report"
    elif [[ $overall_compatibility -ge 50 ]]; then
        echo "🟠 **Overall Compatibility: Fair**" >> "$summary_report"
    else
        echo "🔴 **Overall Compatibility: Poor**" >> "$summary_report"
    fi
    
    cat >> "$summary_report" << 'EOF'

## Recommendations

EOF
    
    if [[ $needs_review -gt 0 ]]; then
        echo "- Review $needs_review skill(s) with compatibility concerns" >> "$summary_report"
    fi
    
    echo "- Maintain version compatibility matrix" >> "$summary_report"
    echo "- Regularly update skills to latest versions" >> "$summary_report"
    echo "- Test upgrades in staging environment first" >> "$summary_report"
    
    cat >> "$summary_report" << 'EOF'

## Alerts Summary

### High Priority Alerts

EOF
    
    # Find high priority alerts
    local high_priority=0
    for report in "$ALERTS_DIR"/compatibility_*.md; do
        if grep -q "🔴" "$report"; then
            local skill_name=$(basename "$report" | cut -d'_' -f2)
            echo "- ❌ $skill_name: High risk upgrade" >> "$summary_report"
            high_priority=$((high_priority + 1))
        fi
    done
    
    if [[ $high_priority -eq 0 ]]; then
        echo "None" >> "$summary_report"
    fi
    
    cat >> "$summary_report" << 'EOF'

### Medium Priority Alerts

EOF
    
    # Find medium priority alerts
    local medium_priority=0
    for report in "$ALERTS_DIR"/compatibility_*.md; do
        if grep -q "🟡" "$report"; then
            local skill_name=$(basename "$report" | cut -d'_' -f2)
            echo "- ⚠️  $skill_name: Review required" >> "$summary_report"
            medium_priority=$((medium_priority + 1))
        fi
    done
    
    if [[ $medium_priority -eq 0 ]]; then
        echo "None" >> "$summary_report"
    fi
    
    cat >> "$summary_report" << 'EOF'

## Monitoring Metadata

- **Summary ID**: $(basename "$summary_report" .md)
- **Generated**: $(date)
- **Total Skills**: $total_skills
- **Status**: Completed ✅

---

*Version compatibility summary report generated by AI Council Monitoring System*
EOF

    echo ""
    echo "📊 Version Monitoring Summary:"
    echo "  Total Skills: $total_skills"
    echo "  Compatible: $compatible_skills"
    echo "  Needs Review: $needs_review"
    echo "  Overall Compatibility: $overall_compatibility%"
    echo ""
    echo "✅ Version monitoring completed"
    echo "📄 Summary report: $summary_report"
    
    return 0
}

# Generate alerts report
generate_alerts_report() {
    echo "🚨 Generating version alerts report..."
    
    # Run full version monitoring
    monitor_all_versions
    
    # Find the most recent summary report
    local summary_report=$(ls -t "$ALERTS_DIR"/version_summary_*.md | head -1)
    
    if [[ -f "$summary_report" ]]; then
        echo "📄 Alerts report generated: $summary_report"
        
        # Extract key information
        local total_skills=$(grep "Total Skills" "$summary_report" | awk '{print $3}')
        local compatible_skills=$(grep "Compatible" "$summary_report" | awk '{print $3}')
        local needs_review=$(grep "Needs Review" "$summary_report" | awk '{print $3}')
        
        echo ""
        echo "📊 Version Alerts Summary:"
        echo "  Total Skills: $total_skills"
        echo "  Compatible: $compatible_skills"
        echo "  Needs Review: $needs_review"
        
        # Check for high priority alerts
        local high_alerts=$(grep -c "❌" "$summary_report" || echo "0")
        local medium_alerts=$(grep -c "⚠️" "$summary_report" || echo "0")
        
        if [[ $high_alerts -gt 0 ]]; then
            echo "  🔴 High Priority Alerts: $high_alerts"
        fi
        
        if [[ $medium_alerts -gt 0 ]]; then
            echo "  🟡 Medium Priority Alerts: $medium_alerts"
        fi
        
        if [[ $needs_review -eq 0 && $high_alerts -eq 0 && $medium_alerts -eq 0 ]]; then
            echo "  ✅ All systems compatible"
        fi
        
        cat "$summary_report"
    else
        echo "❌ No alerts report found"
        return 1
    fi
    
    return 0
}

# Compare versions
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    # Convert versions to comparable format
    local v1_major=$(echo "$v1" | cut -d'.' -f1)
    local v1_minor=$(echo "$v1" | cut -d'.' -f2)
    local v1_patch=$(echo "$v1" | cut -d'.' -f3)
    
    local v2_major=$(echo "$v2" | cut -d'.' -f1)
    local v2_minor=$(echo "$v2" | cut -d'.' -f2)
    local v2_patch=$(echo "$v2" | cut -d'.' -f3)
    
    # Compare major versions
    if [[ $v2_major -gt $v1_major ]]; then
        echo "greater"
    elif [[ $v2_major -lt $v1_major ]]; then
        echo "less"
    else
        # Compare minor versions
        if [[ $v2_minor -gt $v1_minor ]]; then
            echo "greater"
        elif [[ $v2_minor -lt $v1_minor ]]; then
            echo "less"
        else
            # Compare patch versions
            if [[ $v2_patch -gt $v1_patch ]]; then
                echo "greater"
            elif [[ $v2_patch -lt $v1_patch ]]; then
                echo "less"
            else
                echo "equal"
            fi
        fi
    fi
}

# Help function
show_help() {
    echo "AI Council Version Compatibility Alerts"
    echo "========================================"
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  check <skill> <version> [output] - Check version compatibility"
    echo "  monitor                         - Monitor all version compatibilities"
    echo "  alerts                          - Generate alerts report"
    echo ""
    echo "Examples:"
    echo "  $0 check test_skill 2.0.0"
    echo "  $0 check doc_skill 1.5.0 compatibility_report.md"
    echo "  $0 monitor"
    echo "  $0 alerts"
}

# Run main function
main "$@"
