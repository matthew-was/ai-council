#!/bin/bash
# Python Code Formatter
# Runs black and isort on Python source files

echo "🎨 Formatting Python code..."

# Find Python files in backend/src/ and frontend/src/
PYTHON_FILES=$(find backend/src/ frontend/src/ -name "*.py" -type f 2>/dev/null)

if [ -z "$PYTHON_FILES" ]; then
    echo "⚠️  No Python files found in backend/src/ or frontend/src/"
    exit 0
fi

# Run black formatter
echo "Running black..."
black $PYTHON_FILES

if [ $? -ne 0 ]; then
    echo "❌ Black formatting failed"
    exit 1
fi

# Run isort for import sorting
echo "Running isort..."
isort $PYTHON_FILES

if [ $? -ne 0 ]; then
    echo "❌ isort formatting failed"
    exit 1
fi

echo "✅ Code formatting completed"
exit 0