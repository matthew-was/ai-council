#!/bin/bash
# Lab Entry Management Skill
# Manages multi-session lab notebook entries for Notion

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LAB_DRAFT_FILE="$PROJECT_ROOT/.lab-entry-draft.json"

# Initialize a new lab entry
function start_entry() {
    local title="$1"
    local current_date=$(date -u +"%Y-%m-%d")
    local current_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Check for existing draft
    if [ -f "$LAB_DRAFT_FILE" ]; then
        echo "⚠️  Existing draft found from $(jq -r .started_at < $LAB_DRAFT_FILE)"
        read -p "Discard and start new? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            return 1
        fi
    fi
    
    # Create new draft
    echo "{
  \"session_id\": \"$(uuidgen)\",
  \"started_at\": \"$current_time\",
  \"date\": \"$current_date\",
  \"title\": \"$title\",
  \"blocks\": []
}" > "$LAB_DRAFT_FILE"
    
    echo "✅ Lab entry started: $title"
}

# Append a note to the current entry
function append_note() {
    local note="$1"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry. Start one first."
        return 1
    fi
    
    # Append note block
    jq --arg timestamp "$timestamp" --arg note "$note" '
      .blocks += [{
        "timestamp": $timestamp,
        "note": $note,
        "commits": []
      }]' "$LAB_DRAFT_FILE" > "$LAB_DRAFT_FILE.tmp" && mv "$LAB_DRAFT_FILE.tmp" "$LAB_DRAFT_FILE"
    
    echo "✅ Appended note"
}

# Append Git commits to the current entry
function append_commits() {
    # Get commit SHAs from arguments
    local commits=("$@")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry. Start one first."
        return 1
    fi
    
    # Process each commit
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
        
        # Try to get GitHub URL
        local remote_url=$(git remote get-url origin 2>/dev/null)
        if [[ $remote_url == *"github.com"* ]]; then
            url="https://github.com/$(echo $remote_url | sed 's/.*github.com:\\(.*\\)\.git/\1/')/commit/$full_hash"
        fi
        
        commit_data+=("$(jq -n --arg sha "$short_hash" --arg message "$message" --arg url "$url" \
            '{sha: $sha, message: $message, url: $url}')")
    done
    
    # Add commit block
    local commits_json=$(printf '%s\n' "${commit_data[@]}" | jq -s)
    jq --arg timestamp "$timestamp" --argjson commits "$commits_json" '
      .blocks += [{
        "timestamp": $timestamp,
        "note": null,
        "commits": $commits
      }]' "$LAB_DRAFT_FILE" > "$LAB_DRAFT_FILE.tmp" && mv "$LAB_DRAFT_FILE.tmp" "$LAB_DRAFT_FILE"
    
    echo "✅ Appended ${#commits[@]} commit(s)"
}

# Finish entry and generate Notion markdown
function finish_entry() {
    if [ ! -f "$LAB_DRAFT_FILE" ]; then
        echo "❌ No active lab entry"
        return 1
    fi
    
    # Generate markdown
    local title=$(jq -r .title < "$LAB_DRAFT_FILE")
    local output_file="lab_entry_$(date +%Y%m%d).md"
    
    echo "# Lab Entry: $title" > "$output_file"
    echo "" >> "$output_file"
    echo "## What was done" >> "$output_file"
    echo "" >> "$output_file"
    
    # Process each block
    jq -r '.blocks[] | "### \(.timestamp[11:16]) UTC\n\(.note // empty)" + 
      (if .commits then 
        (.commits[] | "- \(.sha) — \(.message)")
      else
        empty
      end)' "$LAB_DRAFT_FILE" >> "$output_file"
    
    echo "" >> "$output_file"
    echo "## Next steps" >> "$output_file"
    echo "- Review and refine the implementation" >> "$output_file"
    echo "- Test with sample data" >> "$output_file"
    echo "- Document the workflow" >> "$output_file"
    
    # Clean up
    rm "$LAB_DRAFT_FILE"
    
    echo "✅ Lab entry completed. Markdown ready in $output_file"
    echo "Paste this into Notion:"
    cat "$output_file"
}

# Main command handling
case "$1" in
    "start")
        start_entry "$2"
        ;;
    "note")
        shift
        append_note "$*"
        ;;
    "commits")
        shift
        append_commits "$@"
        ;;
    "finish")
        finish_entry
        ;;
    *)
        echo "Usage: $0 [start|note|commits|finish] [args]"
        ;;
esac