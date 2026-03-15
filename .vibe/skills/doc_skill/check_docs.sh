#!/bin/bash
# Documentation Structure Checker
# Validates documentation completeness

echo "📚 Checking documentation structure..."

# Required documentation files
REQUIRED_DOCS=(
    "docs/workflow_implementation_plan.md"
)

# Optional documentation files (will be needed later)
OPTIONAL_DOCS=(
    "docs/architecture.md"
    "docs/technical_spec.md"
    "docs/api_specification.md"
    "docs/architecture_workflow_diagram.md"
)

MISSING_DOCS=()

for doc in "${REQUIRED_DOCS[@]}"; do
    if [ ! -f "$doc" ]; then
        MISSING_DOCS+=("$doc")
        echo "❌ Missing: $doc"
    else
        echo "✅ Found: $doc"
    fi
done

# Check optional docs (informational only)
for doc in "${OPTIONAL_DOCS[@]}"; do
    if [ ! -f "$doc" ]; then
        echo "ℹ️  Optional doc missing: $doc (will be needed later)"
    else
        echo "✅ Found optional: $doc"
    fi
done

if [ ${#MISSING_DOCS[@]} -eq 0 ]; then
    echo "✅ All required documentation present"
    exit 0
else
    echo "❌ Missing ${#MISSING_DOCS[@]} required documentation files"
    exit 1
fi