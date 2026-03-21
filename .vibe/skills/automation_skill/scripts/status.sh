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
    completed=$(grep "\-[ ]*\[x\]" .vibe/roadmap.md | wc -l)
    total=$(grep "\-[ ]*\[x\]" .vibe/roadmap.md | wc -l)
    incomplete=$(grep "\-[ ]*\[ \]" .vibe/roadmap.md | wc -l)
    total=$((total + incomplete))
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
echo "📋 Lab Entry Log:"
echo "----------------"
# Check for active draft
if [ -f ".vibe/.lab-entry-draft.json" ]; then
    # Extract date and block count
    entry_date=$(jq -r .date .vibe/.lab-entry-draft.json)
    block_count=$(jq '.blocks | length' .vibe/.lab-entry-draft.json)

    # Format date nicely
    pretty_date=$(date -j -f "%Y-%m-%d" "$entry_date" "+%A, %B %d, %Y" 2>/dev/null || echo "$entry_date")

    echo "  ✅ Lab entry started: $pretty_date"

    if [ $block_count -gt 0 ]; then
        echo "  📄 $block_count work block(s) recorded"
        # Show one-line summary of each block with timestamp
        for i in $(seq 0 $((block_count-1))); do
            timestamp=$(jq -r ".blocks[$i].timestamp" .vibe/.lab-entry-draft.json)
            pretty_time=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$timestamp" "+%H:%M" 2>/dev/null || echo "$timestamp")
            note=$(jq -r ".blocks[$i].note" .vibe/.lab-entry-draft.json)
            commit_count=$(jq ".blocks[$i].commits | length" .vibe/.lab-entry-draft.json)
            if [ -n "$note" ]; then
                echo "    - [$pretty_time] $note"
            else
                echo "    - [$pretty_time] $commit_count commit(s)"
            fi
        done
    else
        echo "  📄 No work blocks yet (add some!)"
    fi
else
    echo "  📄 No active lab entry draft"
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
