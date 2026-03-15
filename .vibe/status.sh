#!/bin/bash

echo "📊 AI Council Project Status"
echo "============================"
echo ""

# Project info
echo "📁 Project Structure:"
echo "--------------------"
find . -maxdepth 2 -type d ! -name ".git" ! -name ".vibe" | sort | while read dir; do
    count=$(find "$dir" -type f 2>/dev/null | wc -l)
    echo "  $dir: $count files"
done
echo ""

# Documentation status
echo "📚 Documentation:"
echo "----------------"
if [ -d "docs" ]; then
    total_lines=0
    for file in docs/*.md; do
        if [ -f "$file" ]; then
            lines=$(wc -l < "$file")
            total_lines=$((total_lines + lines))
            echo "  $(basename $file): $lines lines"
        fi
    done
    echo "  Total: $total_lines lines"
else
    echo "  No docs directory found"
fi
echo ""

# Git status
echo "🔄 Git Status:"
echo "-------------"
git status --short 2>/dev/null | head -10 || echo "  No git changes or not a git repo"
echo ""

# Markdown linting
echo "✅ Quality Checks:"
echo "-----------------"
if command -v markdownlint &> /dev/null; then
    markdownlint . 2>/dev/null && echo "  Markdown: ✅ All files pass" || echo "  Markdown: ⚠️ Issues found"
else
    echo "  Markdown: ⚠️ markdownlint not installed"
fi
echo ""

# Roadmap progress
echo "🗺️ Roadmap Progress:"
echo "--------------------"
if [ -f ".vibe/roadmap.md" ]; then
    # Count completed tasks
    completed=$(grep -c "- \[x\]" .vibe/roadmap.md)
    total=$(grep -c "- \[\(x\| \]\)" .vibe/roadmap.md)
    if [ $total -gt 0 ]; then
        percent=$((completed * 100 / total))
        echo "  Progress: $completed/$total tasks ($percent%)"
    else
        echo "  Progress: No tasks tracked yet"
    fi
else
    echo "  No roadmap found"
fi
echo ""

# Session log
echo "📝 Recent Sessions:"
echo "------------------"
if [ -f ".vibe/session_log.md" ]; then
    grep "^## 📅" .vibe/session_log.md | tail -3
else
    echo "  No session log found"
fi
echo ""

echo "🎯 Next Steps:"
echo "-------------"
if [ -f ".vibe/roadmap.md" ]; then
    grep -A 5 "Next Update" .vibe/roadmap.md | tail -5 | sed 's/^/  /'
else
    echo "  Check .vibe/roadmap.md for priorities"
fi
echo ""

echo "💡 Tips:"
echo "--------"
echo "  • Run .vibe/start_session.sh to begin work"
echo "  • Update .vibe/session_log.md after each session"
echo "  • Follow workflow in .vibe/rules.md"
echo "  • Keep documentation updated"
echo ""

echo "Status generated at: $(date)"