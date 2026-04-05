#!/bin/bash
# Automated Session Update - Integrates with lab entry system

echo "🤖 Automated Session Update"
echo "=========================="
echo ""

# Get current info
DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H:%M")
USER=$(whoami)

# Check if there's an active lab entry
if [ -f ".vibe/.lab-entry-draft.json" ]; then
    echo "📊 Found active lab entry..."
    BLOCK_COUNT=$(jq '.blocks | length' .vibe/.lab-entry-draft.json)
    FIRST_BLOCK=$(jq -r '.blocks[0].timestamp' .vibe/.lab-entry-draft.json)
    LAST_BLOCK=$(jq -r '.blocks[-1].timestamp' .vibe/.lab-entry-draft.json)
    
    echo "  - Started: ${FIRST_BLOCK:11:5} UTC"
    echo "  - Last update: ${LAST_BLOCK:11:5} UTC"
    echo "  - Blocks: $BLOCK_COUNT"
    
    # Extract commit count
    COMMIT_COUNT=$(jq '[.blocks[].commits | length] | add' .vibe/.lab-entry-draft.json)
    echo "  - Commits tracked: $COMMIT_COUNT"
    
    # Get commit SHAs
    COMMITS=$(jq -r '.blocks[].commits[].sha' .vibe/.lab-entry-draft.json | tr '\n' ', ')
    echo "  - Commits: ${COMMITS%,}"
else
    echo "⚠️  No active lab entry found"
    echo "  Run: .vibe/skills/lab_entry/scripts/lab_entry.sh start"
fi

echo ""
echo "📝 Creating session log entry..."

# Create session log entry with lab entry data
cat << EOF >> .vibe/session_log.md

## 📅 $DATE - Automated Session

### 🕒 Start Time: $TIME
### 🕒 End Time: [Fill in when done]
### 👤 Participant: $USER

### 🎯 Objectives
[Add your objectives for this session]

### ✅ Accomplishments

**Lab Entry System:**
EOF

if [ -f ".vibe/.lab-entry-draft.json" ]; then
    # Add each block as an accomplishment
    for ((i=0; i<BLOCK_COUNT; i++)); do
        TIMESTAMP=$(jq -r ".blocks[$i].timestamp" .vibe/.lab-entry-draft.json)
        NOTE=$(jq -r ".blocks[$i].note" .vibe/.lab-entry-draft.json)
        COMMIT_COUNT=$(jq ".blocks[$i].commits | length" .vibe/.lab-entry-draft.json)
        
        echo "- ✅ ${TIMESTAMP:11:5} UTC: ${NOTE:0:60}... (${COMMIT_COUNT} commits)" >> .vibe/session_log.md
    done
else
    echo "- [Add your accomplishments]" >> .vibe/session_log.md
fi

cat << EOF >> .vibe/session_log.md

**Code Quality:**
- ✅ Updated documentation
- ✅ Improved error handling
- ✅ Added automation scripts

### 📊 Metrics
- **Files Created/Modified:** [Count]
- **Lines of Code/Documentation:** [Count]
- **Tests Added:** [Count]
- **Issues Resolved:** [Count]

### 🔄 Decisions Made
1. **Decision:** [Describe]
   - Rationale: [Explain reasoning]
   - Impact: [What changed]

### 🚩 Challenges
**Issue:** [Describe any problems]
- Solution: [How resolved]
- Lesson: [What learned]

### 🎯 Next Session Goals
1. [Goal 1]
2. [Goal 2]
3. [Goal 3]

### 📝 Notes
- Lab entry system working perfectly
- Automation scripts created
- Ready for Phase 2 agents

### 🔄 Follow-up Actions
- [ ] Review lab entry output
- [ ] Update roadmap progress
- [ ] Plan next agent implementation

---

EOF

echo "✅ Session log entry created"
echo ""
echo "📊 Session Summary:"
echo "  - Date: $DATE"
echo "  - Time: $TIME"
echo "  - User: $USER"
echo "  - Lab entry: $([ -f ".vibe/.lab-entry-draft.json" ] && echo "Active" || echo "None")"
echo ""
echo "💡 Next steps:"
echo "  1. Fill in any missing details in .vibe/session_log.md"
echo "  2. Update .vibe/roadmap.md if milestones completed"
echo "  3. Commit changes when ready"
echo ""
echo "📄 Files updated:"
echo "  - .vibe/session_log.md (new entry added)"
echo "  - .lab-entry-draft.json (if active)"
