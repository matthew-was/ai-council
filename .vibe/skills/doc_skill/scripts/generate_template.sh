#!/bin/bash
# Documentation Template Generator
# Creates new documentation files from templates

echo "📝 Generating documentation template..."

TEMPLATE_DIR=".vibe/templates"
DOCS_DIR="docs"

# Create docs directory if it doesn't exist
mkdir -p "$DOCS_DIR"

# Check if template exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "⚠️  Template directory not found: $TEMPLATE_DIR"
    exit 1
fi

# List available templates
echo "Available templates:"
ls -la "$TEMPLATE_DIR/" | grep -v "^d" | grep -v "^total" | awk '{print $NF}'

# Ask user which template to use
read -p "Enter template name: " template_name

if [ ! -f "$TEMPLATE_DIR/$template_name" ]; then
    echo "❌ Template not found: $template_name"
    exit 1
fi

# Ask for output filename
read -p "Enter output filename (in docs/): " output_file

# Copy template to docs directory
cp "$TEMPLATE_DIR/$template_name" "$DOCS_DIR/$output_file"

echo "✅ Documentation template created: $DOCS_DIR/$output_file"
exit 0