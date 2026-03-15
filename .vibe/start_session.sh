#!/bin/bash

echo "🚀 Starting AI Council Development Session"
echo "=========================================="
echo ""

echo "📖 Reading Project Rules..."
echo "-----------------------------------"
# Show key reminders from the rules
grep -A 5 "Session Checklist" .vibe/rules.md | head -10
echo ""

echo "📁 Project Status:"
echo "-----------------------------------"
# Show git status
git status --short 2>/dev/null || echo "Not a git repository or no changes"
echo ""

echo "📄 Documentation Status:"
echo "-----------------------------------"
# Check if docs exist and show counts
if [ -d "docs" ]; then
    echo "$(find docs -name "*.md" | wc -l) markdown documents found"
    for file in docs/*.md; do
        if [ -f "$file" ]; then
            lines=$(wc -l < "$file")
            echo "  - $(basename $file): $lines lines"
        fi
    done
else
    echo "No docs directory found"
fi
echo ""

echo "✅ Markdown Linting:"
echo "-----------------------------------"
# Run markdownlint if available
if command -v markdownlint &> /dev/null; then
    markdownlint . 2>/dev/null && echo "✅ All markdown files pass linting" || echo "⚠️  Some linting issues found"
else
    echo "markdownlint not installed - install with: npm install -g markdownlint-cli"
fi
echo ""

echo "🎯 Next Steps:"
echo "-----------------------------------"
echo "1. Review open issues/tasks"
echo "2. Update documentation as needed"
echo "3. Implement next component from roadmap"
echo "4. Run tests before committing"
echo ""

echo "💡 Remember: Documentation → Architecture → Implementation"
echo "=========================================="
echo "Session started at: $(date)"
echo ""

# Add to git if rules file changed
git add .vibe/rules.md 2>/dev/null