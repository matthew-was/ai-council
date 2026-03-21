#!/bin/bash

# Impact Assessment Automation
# Detailed impact analysis for document changes

set -e

echo "🔍 Impact Assessment Automation"
echo "================================"
echo ""

# Configuration
WORKFLOWS_DIR=".vibe/workflows"
DOCS_DIR="docs"
SKILLS_DIR=".vibe/skills"

# Impact assessment function
assess_impact() {
    local document="$1"
    local change_description="$2"
    local output_file="$3"
    
    if [[ -z "$document" || -z "$change_description" ]]; then
        echo "Error: Document and change description required"
        echo "Usage: $0 <document> <change_description> [output_file]"
        return 1
    fi
    
    # Set default output file
    if [[ -z "$output_file" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        output_file="$WORKFLOWS_DIR/impact_assessments/assessment_${timestamp}.md"
        mkdir -p "$WORKFLOWS_DIR/impact_assessments"
    fi
    
    echo "Assessing impact for: $document"
    echo "Change: $change_description"
    echo "Output: $output_file"
    echo ""
    
    # Check if document exists
    if [[ ! -f "$document" ]]; then
        echo "❌ Document not found: $document"
        return 1
    fi
    
    # Document analysis
    local doc_type="unknown"
    local doc_size=$(wc -l < "$document")
    local last_modified=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$document")
    
    # Determine document type
    if [[ "$document" == *"SKILL.md"* ]]; then
        doc_type="skill"
    elif [[ "$document" == *"docs/"* ]]; then
        doc_type="documentation"
    elif [[ "$document" == *".vibe/"* ]]; then
        doc_type="configuration"
    fi
    
    # Dependency analysis
    echo "📋 Analyzing dependencies..."
    local dependencies=$(grep -r "$document" .vibe/ docs/ 2>/dev/null | grep -v ".git" | grep -v "Binary" | wc -l)
    local dependent_files=$(grep -r "$document" .vibe/ docs/ 2>/dev/null | grep -v ".git" | grep -v "Binary" | cut -d':' -f1 | sort | uniq | tr '\n' ' ')
    
    # Risk assessment
    local risk_score=0
    
    # Calculate risk based on dependencies
    if [[ $dependencies -gt 10 ]]; then
        risk_score=$((risk_score + 3))
    elif [[ $dependencies -gt 5 ]]; then
        risk_score=$((risk_score + 2))
    elif [[ $dependencies -gt 2 ]]; then
        risk_score=$((risk_score + 1))
    fi
    
    # Calculate risk based on document type
    if [[ "$doc_type" == "skill" ]]; then
        risk_score=$((risk_score + 2))
    elif [[ "$doc_type" == "configuration" ]]; then
        risk_score=$((risk_score + 1))
    fi
    
    # Determine risk level
    local risk_level="Low"
    if [[ $risk_score -ge 4 ]]; then
        risk_level="High"
    elif [[ $risk_score -ge 2 ]]; then
        risk_level="Medium"
    fi
    
    # Create impact assessment report
    cat > "$output_file" << EOF
# Impact Assessment Report

## Document Information

- **Document**: $document
- **Type**: $doc_type
- **Size**: $doc_size lines
- **Last Modified**: $last_modified
- **Change Description**: $change_description

## Dependency Analysis

- **Total Dependencies**: $dependencies files
- **Dependent Files**:
$(echo "$dependent_files" | fold -s -w 80)

## Risk Assessment

- **Risk Score**: $risk_score/5
- **Risk Level**: $risk_level
- **Factors Considered**:
  - Dependency count ($dependencies)
  - Document type ($doc_type)
  - Change scope

## Impact Analysis

### Potential Impacts

1. **Direct Impacts**:
   - Document content updates
   - Version number changes
   - Metadata modifications

2. **Indirect Impacts**:
   - Dependent document references
   - Skill registry updates
   - Configuration changes

3. **System Impacts**:
   - Workflow automation
   - Approval processes
   - Change propagation

## Recommendations

EOF

    # Add recommendations based on risk level
    if [[ "$risk_level" == "High" ]]; then
        cat >> "$output_file" << EOF
⚠️ **HIGH RISK** - Manual review required before approval

### Required Actions:
1. Manual code review by senior developer
2. Comprehensive testing in staging environment
3. Approval from architecture team
4. Change propagation testing
5. Rollback plan preparation

### Testing Requirements:
- Unit tests for affected components
- Integration testing for dependent systems
- End-to-end workflow testing
- Performance impact assessment
- Security review

EOF
    elif [[ "$risk_level" == "Medium" ]]; then
        cat >> "$output_file" << EOF
⚠️ **MEDIUM RISK** - Automated approval with oversight

### Required Actions:
1. Automated test suite execution
2. Code review by team member
3. Approval from document owner
4. Limited change propagation testing

### Testing Requirements:
- Unit tests for affected components
- Integration testing for key dependencies
- Workflow validation

EOF
    else
        cat >> "$output_file" << EOF
✅ **LOW RISK** - Automated approval possible

### Required Actions:
1. Automated test suite execution
2. Documentation update verification
3. Standard approval workflow

### Testing Requirements:
- Unit tests for affected components
- Basic integration testing

EOF
    fi

    cat >> "$output_file" << EOF
## Approval Workflow

### Suggested Approval Path:

1. **Impact Assessment Review**
   - Review this impact assessment
   - Verify dependency analysis
   - Confirm risk level assessment

2. **Testing Execution**
   - Run required test suites
   - Verify test coverage
   - Document test results

3. **Approval Process**
   - Route to appropriate approver
   - Set approval deadline
   - Monitor approval status

4. **Change Propagation**
   - Execute approved changes
   - Update dependent documents
   - Verify propagation success

5. **Post-Change Verification**
   - Confirm all changes applied
   - Verify system functionality
   - Update documentation

## Assessment Metadata

- **Assessment Date**: $(date)
- **Assessment Tool**: AI Council Impact Assessment v1.0
- **Assessor**: Automated System
- **Report ID**: $(basename "$output_file" .md)

---

*This impact assessment was generated automatically by the AI Council workflow automation system.*
EOF

    echo "✅ Impact assessment completed"
    echo "📄 Report saved to: $output_file"
    echo ""
    echo "📊 Summary:"
    echo "  Document: $document"
    echo "  Risk Level: $risk_level ($risk_score/5)"
    echo "  Dependencies: $dependencies files"
    echo "  Type: $doc_type"
    
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    assess_impact "$@"
fi
