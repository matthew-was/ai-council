#!/bin/bash

echo "📝 Updating Session Log"
echo "======================"
echo ""

# Get current date
DATE=$(date +"%Y-%m-%d")
TIME=$(date +"%H:%M")

# Create new session entry
cat << EOF >> .vibe/session_log.md

## 📅 $DATE - Session

### 🕒 Start Time: $TIME
### 🕒 End Time: 
### 👤 Participant: $(whoami)

### 🎯 Objectives
-
-
-

### ✅ Accomplishments
**Category:**
- ✅ 
- ✅ 

### 📊 Metrics
- **Files Created/Modified:** 
- **Lines of Code/Documentation:** 
- **Tests Added:** 
- **Issues Resolved:** 

### 🔄 Decisions Made
1. **Decision:**
   - Rationale:
   - Impact:

### 🚩 Challenges
**Issue:**
- Solution:
- Lesson:

### 🎯 Next Session Goals
1. 
2. 
3.

### 📝 Notes
-
-
-

### 🔄 Follow-up Actions
- [ ] 
- [ ] 
- [ ]

---

EOF

echo "✅ New session log entry created for $DATE"
echo "Edit .vibe/session_log.md to fill in details"
echo ""

# Open the log file for editing
if command -v code &> /dev/null; then
    code .vibe/session_log.md
elif command -v open &> /dev/null; then
    open -a TextEdit .vibe/session_log.md
else
    echo "Session log ready for editing: .vibe/session_log.md"
fi