#!/bin/bash
# Lab Entry Agent - Intelligent lab notebook entry management
# Understands user intent, groups commits logically, and generates proper Notion entries

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LAB_DRAFT_FILE="$PROJECT_ROOT/.lab-entry-draft.json"
AGENT_PROMPT="$PROJECT_ROOT/.vibe/prompts/lab_entry_agent.md"

# Initialize a new lab entry with intent understanding
function start_entry() {
    local title="$1"
    local current_date=$(date -u +"%Y-%m-%d")
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Check for existing draft with understanding
    if [ -f "$LAB_DRAFT_FILE" ]; then
        local existing_title=$(jq -r .title < "$LAB_DRAFT_FILE")
        echo "🤔 Existing draft found: '$existing_title' from $(jq -r .started_at < $LAB_DRAFT_FILE)"
        read -p "Discard and start new entry '$title'? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            echo "🔄 Keeping existing draft. Use 'finish' or 'discard' to manage it."
            return 1
        fi
    fi
    
    # Create new draft with proper structure
    echo "{
  \"session_id\": \"$(uuidgen)\",
  \"started_at\": \"$current_time\",
  \"date\": \"$current_date\",
  \"title\": \"$title\",
  \"work_items\": [],
  \"commit_groups\": []
}" > "$LAB_DRAFT_FILE"
    
    echo "✅ Lab entry started: $title"
    echo "💡 Tip: Use 'note' to add work summaries, 'group' to organize commits"
}

# Add a work note with proper summarization
function add_note() {
    local note="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry. Start one first with: lab_entry_agent start "[title]""
        return 1
    fi
    
    # Validate note content
    if [ -z "$note" ] || [ "$note" = " " ]; then
        echo "⚠️  Note cannot be empty. Provide a meaningful work summary."
        return 1
    fi
    
    # Add note with proper structure
    jq --arg timestamp "$timestamp" --arg note "$note" '
      .work_items += [{
        "timestamp": $timestamp,
        "type": "note",
        "content": $note
      }]' "$LAB_DRAFT_FILE" > "$LAB_DRAFT_FILE.tmp" && mv "$LAB_DRAFT_FILE.tmp" "$LAB_DRAFT_FILE"
    
    echo "✅ Added work note: $note"
}

# Intelligently group commits with a summary
function group_commits() {
    local summary="$1"
    shift
    local commits=("$@")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry. Start one first."
        return 1
    fi
    
    # Validate summary
    if [ -z "$summary" ] || [ "$summary" = " " ]; then
        echo "⚠️  Group summary cannot be empty. Describe what these commits accomplish."
        return 1
    fi
    
    # Validate we have commits
    if [ ${#commits[@]} -eq 0 ]; then
        echo "⚠️  No commits provided. Specify commit hashes to group."
        return 1
    fi
    
    # Process each commit with validation
    local commit_data=()
    local valid_commits=0
    
    for sha in "${commits[@]}"; do
        local full_hash=$(git rev-parse "$sha^{commit}" 2>/dev/null)
        if [ -z "$full_hash" ]; then
            echo "⚠️  Invalid commit: $sha (not found in git history)"
            continue
        fi
        
        local short_hash=$(git rev-parse --short "$sha")
        local message=$(git show -s --format=%s "$sha")
        local url=""
        
        # Try to get GitHub URL
        local remote_url=$(git remote get-url origin 2>/dev/null)
        if [[ $remote_url == *"github.com"* ]]; then
            local repo_path=$(echo "$remote_url" | sed 's/.*github.com[:/]//' | sed 's/.git$//')
            if [ -n "$repo_path" ]; then
                url="https://github.com/$repo_path/commit/$full_hash"
            fi
        fi
        
        commit_data+=("$(jq -n --arg sha "$short_hash" --arg message "$message" --arg url "$url" \
            '{sha: $sha, message: $message, url: $url}')")
        valid_commits=$((valid_commits + 1))
    done
    
    if [ $valid_commits -eq 0 ]; then
        echo "❌ No valid commits found. Check your commit hashes."
        return 1
    fi
    
    # Add commit group with proper structure
    local commits_json=$(printf '%s\n' "${commit_data[@]}" | jq -s)
    jq --arg timestamp "$timestamp" --arg summary "$summary" --argjson commits "$commits_json" '
      .commit_groups += [{
        "timestamp": $timestamp,
        "summary": $summary,
        "commits": $commits
      }]' "$LAB_DRAFT_FILE" > "$LAB_DRAFT_FILE.tmp" && mv "$LAB_DRAFT_FILE.tmp" "$LAB_DRAFT_FILE"
    
    echo "✅ Grouped $valid_commits commit(s): $summary"
}

# Finish entry and generate Notion-compatible markdown
function finish_entry() {
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry"
        return 1
    fi
    
    # Generate markdown with proper Notion formatting
    local title=$(jq -r .title < "$LAB_DRAFT_FILE")
    local output_file="lab_entry_$(date +%Y%m%d).md"
    
    echo "# Lab Entry: $title" > "$output_file"
    echo "" >> "$output_file"
    echo "## What was done" >> "$output_file"
    echo "" >> "$output_file"
    
    # Process work items
    local item_count=$(jq '.work_items | length' "$LAB_DRAFT_FILE")
    for ((i=0; i<item_count; i++)); do
        local timestamp=$(jq -r ".work_items[$i].timestamp" "$LAB_DRAFT_FILE")
        local content=$(jq -r ".work_items[$i].content" "$LAB_DRAFT_FILE")
        local time_only=$(echo "$timestamp" | cut -c 12-16)
        
        echo "### ${time_only} UTC" >> "$output_file"
        echo "$content" >> "$output_file"
        echo "" >> "$output_file"
    done
    
    # Process commit groups
    local group_count=$(jq '.commit_groups | length' "$LAB_DRAFT_FILE")
    for ((i=0; i<group_count; i++)); do
        local timestamp=$(jq -r ".commit_groups[$i].timestamp" "$LAB_DRAFT_FILE")
        local summary=$(jq -r ".commit_groups[$i].summary" "$LAB_DRAFT_FILE")
        local time_only=$(echo "$timestamp" | cut -c 12-16)
        
        echo "### ${time_only} UTC" >> "$output_file"
        echo "$summary" >> "$output_file"
        
        local commit_count=$(jq ".commit_groups[$i].commits | length" "$LAB_DRAFT_FILE")
        for ((j=0; j<commit_count; j++)); do
            local sha=$(jq -r ".commit_groups[$i].commits[$j].sha" "$LAB_DRAFT_FILE")
            local message=$(jq -r ".commit_groups[$i].commits[$j].message" "$LAB_DRAFT_FILE")
            echo "- $sha — $message" >> "$output_file"
        done
        echo "" >> "$output_file"
    done
    
    echo "## Next steps" >> "$output_file"
    echo "- Review and refine the implementation" >> "$output_file"
    echo "- Test with sample data" >> "$output_file"
    echo "- Document the workflow" >> "$output_file"
    
    # Clean up
    rm "$LAB_DRAFT_FILE"
    
    echo "🎉 Lab entry completed!"
    echo "📄 Markdown file: $output_file"
    echo ""
    echo "📋 Entry content:"
    cat "$output_file"
    echo ""
    echo "💡 Ready to paste into Notion!"
}

# Show current draft status
function show_status() {
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "📊 No active lab entry"
        return 1
    fi
    
    local title=$(jq -r .title < "$LAB_DRAFT_FILE")
    local work_count=$(jq '.work_items | length' "$LAB_DRAFT_FILE")
    local group_count=$(jq '.commit_groups | length' "$LAB_DRAFT_FILE")
    
    echo "📋 Active Lab Entry: $title"
    echo "📝 Work notes: $work_count"
    echo "🔗 Commit groups: $group_count"
    echo ""
    
    if [ $work_count -gt 0 ]; then
        echo "Recent work notes:"
        jq -r '.work_items[-1].content' "$LAB_DRAFT_FILE" | sed 's/^/  - /'
    fi
    
    if [ $group_count -gt 0 ]; then
        echo "Recent commit groups:"
        jq -r '.commit_groups[-1].summary' "$LAB_DRAFT_FILE" | sed 's/^/  - /'
    fi
}

# Discard current draft
function discard_draft() {
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "📊 No active lab entry to discard"
        return 1
    fi
    
    local title=$(jq -r .title < "$LAB_DRAFT_FILE")
    read -p "🗑️  Discard entry '$title'? (y/n): " confirm
    
    if [ "$confirm" = "y" ]; then
        rm "$LAB_DRAFT_FILE"
        echo "🗑️  Entry discarded"
    else
        echo "🔄 Entry kept"
    fi
}

# Main command handling with intent understanding
case "$1" in
    "start")
        start_entry "$2"
        ;;
    "note")
        shift
        add_note "$*"
        ;;
    "group")
        shift
        # Extract summary (everything until first hash-like argument)
        summary=""
        commits=()
        found_hash=false
        
        for arg in "$@"; do
            if [[ $arg =~ ^[a-f0-9]{7,40}$ ]] && ! $found_hash; then
                found_hash=true
            fi
            
            if $found_hash; then
                commits+=("$arg")
            else
                if [ -n "$summary" ]; then
                    summary="$summary "
                fi
                summary="$summary$arg"
            fi
        done
        
        group_commits "$summary" "${commits[@]}"
        ;;
    "finish")
        finish_entry
        ;;
    "status")
        show_status
        ;;
    "discard")
        discard_draft
        ;;
    *)
        echo "🤖 Lab Entry Agent - Intelligent lab notebook management"
        echo ""
        echo "Usage: lab_entry_agent [command] [arguments]"
        echo ""
        echo "Commands:"
        echo "  start [title]          - Start a new lab entry"
        echo "  note [summary]         - Add a work summary note"
        echo "  group [summary] [commits...] - Group commits with a summary"
        echo "  finish                 - Generate Notion markdown"
        echo "  status                 - Show current draft status"
        echo "  discard                - Discard current draft"
        echo ""
        echo "Example:"
        echo "  lab_entry_agent start \"AI Setup\""
        echo "  lab_entry_agent note \"Configured infrastructure\""
        echo "  lab_entry_agent group \"Created lab skill\" f20c132 2f3a47b"
        echo "  lab_entry_agent finish"
        ;;
esac