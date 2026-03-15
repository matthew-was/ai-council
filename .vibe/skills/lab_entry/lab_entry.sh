#!/bin/bash
# Simple Lab Entry Agent - Follows user's exact JSON schema
# Schema: {"date": "YYYY-MM-DD", "blocks": [{"timestamp": "ISO", "note": "text or null", "commits": []}]}

# FUNDAMENTAL RULES:
# 1. Never finalize early - let user decide when day is complete
# 2. Support multiple blocks throughout the day
# 3. Only finish when explicitly requested at end of day
# 4. Never assume work is done or suggest finishing

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LAB_DRAFT_FILE="$PROJECT_ROOT/.lab-entry-draft.json"

# Initialize with just date and empty blocks
function start_entry() {
    local current_date=$(date -u +"%Y-%m-%d")
    
    # Check for existing draft
    if [ -f "$LAB_DRAFT_FILE" ]; then
        local existing_date=$(jq -r .date < "$LAB_DRAFT_FILE")
        echo "📊 Existing draft found from $existing_date"
        read -p "Discard and start new entry? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            return 1
        fi
    fi
    
    # Create minimal structure per user's schema
    echo "{
  \"date\": \"$current_date\",
  \"blocks\": []
}" > "$LAB_DRAFT_FILE"
    
    echo "✅ Lab entry started: $current_date"
    echo "📝 Schema: date + empty blocks array"
}

# Add a note block (timestamp + note text, null commits)
function add_note() {
    local note="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry. Start one first."
        return 1
    fi
    
    if [ -z "$note" ]; then
        echo "⚠️  Note cannot be empty"
        return 1
    fi
    
    # Add block with note and null commits per schema
    # Use jq to append to existing blocks array
    jq --arg timestamp "$timestamp" --arg note "$note" '
      .blocks += [{
        "timestamp": $timestamp,
        "note": $note,
        "commits": null
      }]' "$LAB_DRAFT_FILE" > "$LAB_DRAFT_FILE.tmp" && mv "$LAB_DRAFT_FILE.tmp" "$LAB_DRAFT_FILE"
    
    echo "✅ Added note block at $timestamp"
}

# Add a commits block (timestamp + commits array, null note)
function add_commits() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    shift
    local commits=("$@")
    
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry. Start one first."
        return 1
    fi
    
    if [ ${#commits[@]} -eq 0 ]; then
        echo "⚠️  No commits provided"
        return 1
    fi
    
    # Process commits
    local commit_data=()
    for sha in "${commits[@]}"; do
        local full_hash=$(git rev-parse "$sha^{commit}" 2>/dev/null)
        if [ -z "$full_hash" ]; then
            echo "⚠️  Invalid commit: $sha"
            continue
        fi
        
        local short_hash=$(git rev-parse --short "$sha")
        local message=$(git show -s --format=%s "$sha")
        local url=""
        
        # Get GitHub URL if available
        local remote_url=$(git remote get-url origin 2>/dev/null)
        if [[ $remote_url == *"github.com"* ]]; then
            local repo_path=$(echo "$remote_url" | sed 's/.*github.com[:/]//' | sed 's/.git$//')
            url="https://github.com/$repo_path/commit/$full_hash"
        fi
        
        commit_data+=("$(jq -n --arg sha "$short_hash" --arg message "$message" --arg url "$url" \
            '{sha: $sha, message: $message, url: $url}')")
    done
    
    if [ ${#commit_data[@]} -eq 0 ]; then
        echo "❌ No valid commits found"
        return 1
    fi
    
    # Add block with commits and null note per schema
    local commits_json=$(printf '%s\n' "${commit_data[@]}" | jq -s)
    jq --arg timestamp "$timestamp" --argjson commits "$commits_json" '
      .blocks += [{
        "timestamp": $timestamp,
        "note": null,
        "commits": $commits
      }]' "$LAB_DRAFT_FILE" > "$LAB_DRAFT_FILE.tmp" && mv "$LAB_DRAFT_FILE.tmp" "$LAB_DRAFT_FILE"
    
    echo "✅ Added commits block at $timestamp"
}

# Add combined block (timestamp + note + commits)
function add_combined() {
    local note="$1"
    shift
    local commits=("$@")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry. Start one first."
        return 1
    fi
    
    if [ -z "$note" ] && [ ${#commits[@]} -eq 0 ]; then
        echo "⚠️  Provide note, commits, or both"
        return 1
    fi
    
    # Process commits if provided
    local commit_data=()
    for sha in "${commits[@]}"; do
        local full_hash=$(git rev-parse "$sha^{commit}" 2>/dev/null)
        if [ -z "$full_hash" ]; then
            echo "⚠️  Invalid commit: $sha"
            continue
        fi
        
        local short_hash=$(git rev-parse --short "$sha")
        local message=$(git show -s --format=%s "$sha")
        local url=""
        
        local remote_url=$(git remote get-url origin 2>/dev/null)
        if [[ $remote_url == *"github.com"* ]]; then
            local repo_path=$(echo "$remote_url" | sed 's/.*github.com[:/]//' | sed 's/.git$//')
            url="https://github.com/$repo_path/commit/$full_hash"
        fi
        
        commit_data+=("$(jq -n --arg sha "$short_hash" --arg message "$message" --arg url "$url" \
            '{sha: $sha, message: $message, url: $url}')")
    done
    
    local commits_json="null"
    if [ ${#commit_data[@]} -gt 0 ]; then
        commits_json=$(printf '%s\n' "${commit_data[@]}" | jq -s)
    fi
    
    # Add combined block per schema
    if [ -n "$note" ]; then
        jq --arg timestamp "$timestamp" --arg note "$note" --argjson commits "$commits_json" '
          .blocks += [{
            "timestamp": $timestamp,
            "note": $note,
            "commits": $commits
          }]' "$LAB_DRAFT_FILE" > "$LAB_DRAFT_FILE.tmp" && mv "$LAB_DRAFT_FILE.tmp" "$LAB_DRAFT_FILE"
    else
        jq --arg timestamp "$timestamp" --argjson commits "$commits_json" '
          .blocks += [{
            "timestamp": $timestamp,
            "note": null,
            "commits": $commits
          }]' "$LAB_DRAFT_FILE" > "$LAB_DRAFT_FILE.tmp" && mv "$LAB_DRAFT_FILE.tmp" "$LAB_DRAFT_FILE"
    fi
    
    echo "✅ Added combined block at $timestamp"
}

# Show current draft status
function show_status() {
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "📊 No active lab entry"
        return 1
    fi
    
    local date=$(jq -r .date < "$LAB_DRAFT_FILE")
    local block_count=$(jq '.blocks | length' "$LAB_DRAFT_FILE")
    
    echo "📋 Lab Entry: $date"
    echo "📝 Blocks: $block_count"
    echo ""
    
    for ((i=0; i<block_count; i++)); do
        local timestamp=$(jq -r ".blocks[$i].timestamp" "$LAB_DRAFT_FILE")
        local note=$(jq -r ".blocks[$i].note" "$LAB_DRAFT_FILE")
        local commits=$(jq -r ".blocks[$i].commits" "$LAB_DRAFT_FILE")
        
        echo "Block $((i+1)) - $timestamp:"
        if [ "$note" != "null" ]; then
            echo "  📝 Note: $note"
        fi
        if [ "$commits" != "null" ]; then
            local commit_count=$(echo "$commits" | jq 'length')
            echo "  🔗 Commits: $commit_count"
        fi
        echo ""
    done
}

# Finish and output JSON + Notion markdown
function finish_entry() {
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry"
        return 1
    fi
    
    # Output JSON file
    local json_file="lab_entry_$(date +%Y%m%d).json"
    cp "$LAB_DRAFT_FILE" "$json_file"
    
    # Generate Notion markdown with proper GitHub links
    local md_file="lab_entry_$(date +%Y%m%d).md"
    local date=$(jq -r .date < "$LAB_DRAFT_FILE")
    
    echo "# Lab Entry: $date" > "$md_file"
    echo "" >> "$md_file"
    echo "## What was done" >> "$md_file"
    echo "" >> "$md_file"
    
    # Process each block
    local block_count=$(jq '.blocks | length' "$LAB_DRAFT_FILE")
    for ((i=0; i<block_count; i++)); do
        local timestamp=$(jq -r ".blocks[$i].timestamp" "$LAB_DRAFT_FILE")
        local note=$(jq -r ".blocks[$i].note" "$LAB_DRAFT_FILE")
        local commits=$(jq -r ".blocks[$i].commits" "$LAB_DRAFT_FILE")
        local time_only=$(echo "$timestamp" | cut -c 12-16)
        
        echo "### ${time_only} UTC" >> "$md_file"
        
        if [ "$note" != "null" ]; then
            echo "$note" >> "$md_file"
        fi
        
        if [ "$commits" != "null" ]; then
            local commit_count=$(echo "$commits" | jq 'length')
            for ((j=0; j<commit_count; j++)); do
                local sha=$(echo "$commits" | jq -r ".[$j].sha")
                local message=$(echo "$commits" | jq -r ".[$j].message")
                local url=$(echo "$commits" | jq -r ".[$j].url")
                
                if [ "$url" != "null" ] && [ -n "$url" ]; then
                    echo "- [$sha]($url) — $message" >> "$md_file"
                else
                    echo "- $sha — $message" >> "$md_file"
                fi
            done
        fi
        
        echo "" >> "$md_file"
    done
    
    echo "## Next steps" >> "$md_file"
    echo "- Review and refine the implementation" >> "$md_file"
    echo "- Test with sample data" >> "$md_file"
    echo "- Document the workflow" >> "$md_file"
    
    # Clean up
    rm "$LAB_DRAFT_FILE"
    
    echo "🎉 Lab entry completed!"
    echo "📄 JSON file: $json_file"
    echo "📝 Notion markdown: $md_file"
    echo ""
    echo "📋 Markdown preview (with GitHub links):"
    cat "$md_file"
}

# Discard current draft
function discard_draft() {
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "📊 No active lab entry"
        return 1
    fi
    
    local date=$(jq -r .date < "$LAB_DRAFT_FILE")
    read -p "🗑️  Discard entry from $date? (y/n): " confirm
    
    if [ "$confirm" = "y" ]; then
        rm "$LAB_DRAFT_FILE"
        echo "🗑️  Entry discarded"
    fi
}

# Main command handling
case "$1" in
    "start")
        start_entry
        ;;
    "note")
        shift
        add_note "$*"
        ;;
    "commits")
        shift
        add_commits "$@"
        ;;
    "combined")
        shift
        # Extract note (everything until first hash-like argument)
        note=""
        commits=()
        found_hash=false
        
        for arg in "$@"; do
            if [[ $arg =~ ^[a-f0-9]{7,40}$ ]] && ! $found_hash; then
                found_hash=true
            fi
            
            if $found_hash; then
                commits+=("$arg")
            else
                if [ -n "$note" ]; then
                    note="$note "
                fi
                note="$note$arg"
            fi
        done
        
        add_combined "$note" "${commits[@]}"
        ;;
    "status")
        show_status
        ;;
    "finish")
        finish_entry
        ;;
    "discard")
        discard_draft
        ;;
    *)
        echo "📝 Simple Lab Entry Agent - Follows exact user schema"
        echo ""
        echo "Schema: {\"date\": \"YYYY-MM-DD\", \"blocks\": [{\"timestamp\": \"ISO\", \"note\": \"text or null\", \"commits\": []}]}"
        echo ""
        echo "WORKFLOW:"
        echo "  1. Start once at beginning of day"
        echo "  2. Add blocks multiple times as work is completed"
        echo "  3. Finish once at end of day (explicit request only)"
        echo ""
        echo "COMMANDS:"
        echo "  start              - Initialize with date + empty blocks"
        echo "  note [text]        - Add note block (null commits)"
        echo "  commits [hashes...] - Add commits block (null note)"
        echo "  combined [note] [hashes...] - Add block with both"
        echo "  status             - Show current draft (safe to check anytime)"
        echo "  finish             - Output JSON file (ONLY at end of day)"
        echo "  discard            - Discard current draft"
        echo ""
        echo "IMPORTANT: Agent will NEVER suggest finishing early - you decide when day is complete"
        echo ""
        echo "Example:"
        echo "  simple_lab_entry.sh start"
        echo "  simple_lab_entry.sh note \"Implemented feature X\""
        echo "  simple_lab_entry.sh commits abc123 def456"
        echo "  simple_lab_entry.sh combined \"Fixed bugs\" gh1234 jk5678"
        echo "  simple_lab_entry.sh finish"
        ;;
esac