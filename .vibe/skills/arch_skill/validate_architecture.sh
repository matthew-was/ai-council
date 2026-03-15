#!/bin/bash
# Architecture Validation
# Checks project structure and dependencies

echo "🔍 Validating architecture..."

# Check required directories
REQUIRED_DIRS=("backend" "frontend" "docs" ".vibe")
MISSING_DIRS=()

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        MISSING_DIRS+=("$dir")
        echo "❌ Missing directory: $dir"
    else
        echo "✅ Directory exists: $dir"
    fi
done

# Check required files
REQUIRED_FILES=("docker-compose.yml" "README.md" ".gitignore")
MISSING_FILES=()

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
        echo "❌ Missing file: $file"
    else
        echo "✅ File exists: $file"
    fi
done

# Check backend structure
if [ -d "backend" ]; then
    if [ -f "backend/requirements.txt" ]; then
        echo "✅ Backend requirements.txt found"
    else
        echo "❌ Backend requirements.txt missing"
    fi
    
    if [ -f "backend/Dockerfile" ]; then
        echo "✅ Backend Dockerfile found"
    else
        echo "❌ Backend Dockerfile missing"
    fi
fi

# Check frontend structure
if [ -d "frontend" ]; then
    if [ -f "frontend/requirements.txt" ]; then
        echo "✅ Frontend requirements.txt found"
    else
        echo "❌ Frontend requirements.txt missing"
    fi
    
    if [ -f "frontend/Dockerfile" ]; then
        echo "✅ Frontend Dockerfile found"
    else
        echo "❌ Frontend Dockerfile missing"
    fi
fi

# Summary
if [ ${#MISSING_DIRS[@]} -eq 0 ] && [ ${#MISSING_FILES[@]} -eq 0 ]; then
    echo "✅ Architecture validation passed"
    exit 0
else
    echo "❌ Architecture validation failed"
    if [ ${#MISSING_DIRS[@]} -gt 0 ]; then
        echo "Missing directories: ${MISSING_DIRS[*]}"
    fi
    if [ ${#MISSING_FILES[@]} -gt 0 ]; then
        echo "Missing files: ${MISSING_FILES[*]}"
    fi
    exit 1
fi