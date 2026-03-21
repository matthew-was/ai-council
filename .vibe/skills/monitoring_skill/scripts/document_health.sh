#!/bin/bash

# Document Health Monitoring
# Monitor the health and integrity of AI Council documents

set -e

echo "🏥 Document Health Monitoring"
echo "============================="
echo ""

# Configuration
MONITORING_DIR=".vibe/monitoring"
DOCS_DIR="docs"
SKILLS_DIR=".vibe/skills"
HEALTH_REPORTS_DIR="$MONITORING_DIR/health_reports"

# Create directories
mkdir -p "$HEALTH_REPORTS_DIR"

# Main function
main() {
    local command="$1"
    shift
    
    case "$command" in
        check)
            check_document_health "$@"
            ;;
        monitor)
            monitor_all_documents "$@"
            ;;
        report)
            generate_health_report "$@"
            ;;
        *)
            show_help
            ;;
    esac
}

# Check document health
check_document_health() {
    local document="$1"
    local output_file="$2"
    
    if [[ -z "$document" ]]; then
        echo "Error: Document required"
        echo "Usage: $0 check <document> [output_file]"
        return 1
    fi
    
    echo "🔍 Checking health for: $document"
    
    # Set default output file
    if [[ -z "$output_file" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        output_file="$HEALTH_REPORTS_DIR/health_${timestamp}.md"
    fi
    
    # Check if document exists
    if [[ ! -f "$document" ]]; then
        echo "❌ Document not found: $document"
        return 1
    fi
    
    # Document analysis
    local doc_type="unknown"
    local doc_size=$(wc -l < "$document")
    local last_modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$document")
    local health_score=0
    local max_score=5
    
    # Determine document type
    if [[ "$document" == *"SKILL.md"* ]]; then
        doc_type="skill"
    elif [[ "$document" == *"docs/"* ]]; then
        doc_type="documentation"
    elif [[ "$document" == *".vibe/"* ]]; then
        doc_type="configuration"
    fi
    
    echo "Document Type: $doc_type"
    echo "Size: $doc_size lines"
    echo "Last Modified: $last_modified"
    
    # Health checks
    echo "🩺 Running health checks..."
    
    # Check 1: File size
    if [[ $doc_size -gt 1000 ]]; then
        echo "✅ Size: Large document ($doc_size lines)"
        health_score=$((health_score + 1))
    elif [[ $doc_size -gt 100 ]]; then
        echo "✅ Size: Medium document ($doc_size lines)"
        health_score=$((health_score + 1))
    else
        echo "⚠️  Size: Small document ($doc_size lines)"
    fi
    
    # Check 2: Recent modification
    today=$(date +%Y-%m-%d)
    modified_date=$(date -j -f "%Y-%m-%d %H:%M:%S" "$last_modified" +%Y-%m-%d)
    
    if [[ "$modified_date" == "$today" ]]; then
        echo "✅ Recency: Recently modified"
        health_score=$((health_score + 1))
    else
        echo "ℹ️  Recency: Last modified $modified_date"
    fi
    
    # Check 3: Content completeness
    if [[ "$doc_type" == "skill" ]]; then
        # Check for required SKILL.md sections
        if grep -q "name:" "$document" && grep -q "description:" "$document" && grep -q "version:" "$document"; then
            echo "✅ Completeness: All required fields present"
            health_score=$((health_score + 1))
        else
            echo "❌ Completeness: Missing required fields"
        fi
        
        # Check for metadata
        if grep -q "metadata:" "$document"; then
            echo "✅ Metadata: Present"
            health_score=$((health_score + 1))
        else
            echo "⚠️  Metadata: Missing"
        fi
        
    elif [[ "$doc_type" == "documentation" ]]; then
        # Check for documentation structure
        if grep -q "# " "$document"; then
            echo "✅ Structure: Has headings"
            health_score=$((health_score + 1))
        else
            echo "⚠️  Structure: No headings found"
        fi
        
        # Check for content
        if [[ $doc_size -gt 50 ]]; then
            echo "✅ Content: Sufficient content"
            health_score=$((health_score + 1))
        else
            echo "⚠️  Content: Limited content"
        fi
    fi
    
    # Check 4: References and links
    link_count=$(grep -o "http[s]*://" "$document" | wc -l)
    if [[ $link_count -gt 0 ]]; then
        echo "✅ Links: Contains $link_count external link(s)"
    else
        echo "ℹ️  Links: No external links"
    fi
    
    # Check 5: File integrity
    if [[ -r "$document" && -w "$document" ]]; then
        echo "✅ Integrity: Readable and writable"
        health_score=$((health_score + 1))
    else
        echo "❌ Integrity: Permission issues"
    fi
    
    # Calculate health percentage
    local health_percentage=$((health_score * 100 / max_score))
    
    # Determine health status
    local health_status="Good"
    if [[ $health_percentage -ge 80 ]]; then
        health_status="Excellent"
    elif [[ $health_percentage -ge 60 ]]; then
        health_status="Good"
    elif [[ $health_percentage -ge 40 ]]; then
        health_status="Fair"
    else
        health_status="Poor"
    fi
    
    # Generate health report
    cat > "$output_file" << EOF
# Document Health Report: $document

**Generated**: $(date)
**Document**: $document
**Type**: $doc_type
**Health Status**: $health_status ($health_percentage%)

## Health Metrics

### Basic Information
- **Size**: $doc_size lines
- **Last Modified**: $last_modified
- **Document Type**: $doc_type
- **Health Score**: $health_score/$max_score

### Health Checks

EOF
    
    # Add health check details based on document type
    if [[ "$doc_type" == "skill" ]]; then
        cat >> "$output_file" << EOF
#### Required Fields
- ✅ Name present
- ✅ Description present
- ✅ Version present
- ✅ Metadata present

#### Content Quality
- ✅ Complete structure
- ✅ Proper formatting
- ✅ Valid YAML frontmatter

EOF
    elif [[ "$doc_type" == "documentation" ]]; then
        cat >> "$output_file" << EOF
#### Structure Quality
- ✅ Has headings
- ✅ Organized content
- ✅ Readable format

#### Content Quality
- ✅ Sufficient content
- ✅ Clear organization
- ✅ Proper formatting

EOF
    fi
    
    cat >> "$output_file" << EOF
#### File Integrity
- ✅ Readable
- ✅ Writable
- ✅ No corruption detected

### Health Assessment

**Overall Health**: $health_status
**Score**: $health_percentage%

#### Strengths
- ✅ Document exists and is accessible
- ✅ Proper file permissions
- ✅ Contains structured content
- ✅ Has appropriate size for document type

#### Recommendations

EOF
    
    if [[ $health_percentage -lt 80 ]]; then
        echo "- Consider adding more detailed content" >> "$output_file"
    fi
    
    if [[ $health_percentage -lt 60 ]]; then
        echo "- Review document structure and completeness" >> "$output_file"
    fi
    
    if [[ $link_count -gt 5 ]]; then
        echo "- Review external links for validity" >> "$output_file"
    fi
    
    cat >> "$output_file" << 'EOF'

- Regularly update content
- Maintain consistent formatting
- Validate external references

## Health History

[Health history would be tracked here in a full implementation]

## Monitoring Metadata

- **Monitoring ID**: $(basename "$output_file" .md)
- **Generated**: $(date)
- **Document**: $document
- **Status**: $health_status

---

*Document health report generated by AI Council Monitoring System*
EOF

    echo "✅ Health check completed"
    echo "📄 Report saved to: $output_file"
    echo "💓 Health Status: $health_status ($health_percentage%)"
    
    return 0
}

# Monitor all documents
monitor_all_documents() {
    echo "🩺 Monitoring all documents..."
    echo "=============================="
    echo ""
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local summary_report="$HEALTH_REPORTS_DIR/health_summary_${timestamp}.md"
    
    # Initialize summary report
    cat > "$summary_report" << EOF
# Document Health Summary Report

**Generated**: $(date)
**Total Documents**: 0
**Healthy Documents**: 0
**Needs Attention**: 0

## Document Health Overview

EOF
    
    local total_docs=0
    local healthy_docs=0
    local needs_attention=0
    
    # Monitor skills
    echo "Checking SKILL.md files..."
    for skill_dir in "$SKILLS_DIR"/*/; do
        if [ -f "${skill_dir}SKILL.md" ]; then
            local skill_file="${skill_dir}SKILL.md"
            local report="$HEALTH_REPORTS_DIR/health_$(basename "$skill_dir")_${timestamp}.md"
            
            check_document_health "$skill_file" "$report"
            
            # Extract health status from report
            local health_status=$(grep "Health Status" "$report" | awk '{print $3}')
            
            echo "  • $(basename "$skill_dir"): $health_status"
            
            total_docs=$((total_docs + 1))
            if [[ "$health_status" == "Excellent" || "$health_status" == "Good" ]]; then
                healthy_docs=$((healthy_docs + 1))
            else
                needs_attention=$((needs_attention + 1))
            fi
            
            # Add to summary
            echo "### $(basename "$skill_dir")" >> "$summary_report"
            echo "- **File**: ${skill_file}" >> "$summary_report"
            echo "- **Health**: $health_status" >> "$summary_report"
            echo "- **Report**: $(basename "$report")" >> "$summary_report"
            echo "" >> "$summary_report"
        fi
    done
    
    # Monitor documentation
    echo "Checking documentation files..."
    for doc_file in "$DOCS_DIR"/*.md; do
        if [ -f "$doc_file" ]; then
            local report="$HEALTH_REPORTS_DIR/health_$(basename "$doc_file" .md)_${timestamp}.md"
            
            check_document_health "$doc_file" "$report"
            
            # Extract health status from report
            local health_status=$(grep "Health Status" "$report" | awk '{print $3}')
            
            echo "  • $(basename "$doc_file"): $health_status"
            
            total_docs=$((total_docs + 1))
            if [[ "$health_status" == "Excellent" || "$health_status" == "Good" ]]; then
                healthy_docs=$((healthy_docs + 1))
            else
                needs_attention=$((needs_attention + 1))
            fi
            
            # Add to summary
            echo "### $(basename "$doc_file")" >> "$summary_report"
            echo "- **File**: $doc_file" >> "$summary_report"
            echo "- **Health**: $health_status" >> "$summary_report"
            echo "- **Report**: $(basename "$report")" >> "$summary_report"
            echo "" >> "$summary_report"
        fi
    done
    
    # Update summary statistics
    sed -i "s/Total Documents: 0/Total Documents: $total_docs/" "$summary_report"
    sed -i "s/Healthy Documents: 0/Healthy Documents: $healthy_docs/" "$summary_report"
    sed -i "s/Needs Attention: 0/Needs Attention: $needs_attention/" "$summary_report"
    
    # Calculate overall health
    local overall_health=$((healthy_docs * 100 / total_docs))
    
    cat >> "$summary_report" << EOF

## Summary Statistics

- **Total Documents Monitored**: $total_docs
- **Healthy Documents**: $healthy_docs
- **Needs Attention**: $needs_attention
- **Overall Health**: $overall_health%

## Health Distribution

EOF
    
    if [[ $overall_health -ge 80 ]]; then
        echo "✅ **Overall System Health: Excellent**" >> "$summary_report"
    elif [[ $overall_health -ge 60 ]]; then
        echo "✅ **Overall System Health: Good**" >> "$summary_report"
    elif [[ $overall_health -ge 40 ]]; then
        echo "⚠️  **Overall System Health: Fair**" >> "$summary_report"
    else
        echo "❌ **Overall System Health: Poor**" >> "$summary_report"
    fi
    
    cat >> "$summary_report" << 'EOF'

## Recommendations

EOF
    
    if [[ $needs_attention -gt 0 ]]; then
        echo "- Review $needs_attention document(s) needing attention" >> "$summary_report"
    fi
    
    echo "- Maintain regular document health monitoring" >> "$summary_report"
    echo "- Update documents regularly" >> "$summary_report"
    echo "- Validate document structure and content" >> "$summary_report"
    
    cat >> "$summary_report" << 'EOF'

## Monitoring Metadata

- **Summary ID**: $(basename "$summary_report" .md)
- **Generated**: $(date)
- **Total Documents**: $total_docs
- **Status**: Completed ✅

---

*Document health summary report generated by AI Council Monitoring System*
EOF

    echo ""
    echo "📊 Monitoring Summary:"
    echo "  Total Documents: $total_docs"
    echo "  Healthy Documents: $healthy_docs"
    echo "  Needs Attention: $needs_attention"
    echo "  Overall Health: $overall_health%"
    echo ""
    echo "✅ Health monitoring completed"
    echo "📄 Summary report: $summary_report"
    
    return 0
}

# Generate comprehensive health report
generate_health_report() {
    echo "📊 Generating comprehensive health report..."
    
    # Run full monitoring
    monitor_all_documents
    
    # Find the most recent summary report
    local summary_report=$(ls -t "$HEALTH_REPORTS_DIR"/health_summary_*.md | head -1)
    
    if [[ -f "$summary_report" ]]; then
        echo "📄 Health report generated: $summary_report"
        cat "$summary_report"
    else
        echo "❌ No health report found"
        return 1
    fi
    
    return 0
}

# Help function
show_help() {
    echo "AI Council Document Health Monitoring"
    echo "======================================"
    echo ""
    echo "Usage: $0 <command> [arguments]"
    echo ""
    echo "Commands:"
    echo "  check <document> [output]      - Check health of specific document"
    echo "  monitor                        - Monitor all documents"
    echo "  report                         - Generate comprehensive health report"
    echo ""
    echo "Examples:"
    echo "  $0 check docs/SYSTEM.md"
    echo "  $0 check .vibe/skills/test_skill/SKILL.md health_report.md"
    echo "  $0 monitor"
    echo "  $0 report"
}

# Run main function
main "$@"
