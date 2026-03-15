# Vibe Automation Guide

## 🤖 Automated Tracking System

Vibe provides multiple levels of automation to reduce manual tracking overhead while maintaining accuracy.

## 📊 Automation Levels

### Level 1: Basic (Manual)

```bash
# Start session
.vibe/start_session.sh

# Manually add to session log
nano .vibe/session_log.md

# Manually update roadmap
nano .vibe/roadmap.md
```

### Level 2: Semi-Automated (Recommended)

```bash
# Start with template
.vibe/update_log.sh

# Fill in details manually
nano .vibe/session_log.md

# Use lab entry for commits
.vibe/skills/lab_entry/lab_entry.sh combined "Work" commit1 commit2
```

### Level 3: Fully Automated

```bash
# Run comprehensive automation
.vibe/auto_update.sh

# Automatically:
# - Detects active lab entries
# - Extracts commit information
# - Creates session log entry
# - Suggests metrics and goals
```

## 🎯 Recommended Workflow

### Morning Start

```bash
# 1. Start session
.vibe/start_session.sh

# 2. Begin lab entry
.vibe/skills/lab_entry/lab_entry.sh start

# 3. Set objective for the day
nano .vibe/session_log.md  # Add objectives
```

### During Work

```bash
# Add work as you complete it
.vibe/skills/lab_entry/lab_entry.sh combined "Feature X" commit1 commit2

# Multiple times per day - no need to remember everything!
```

### End of Day

```bash
# 1. Run automation
.vibe/auto_update.sh

# 2. Review generated log
nano .vibe/session_log.md  # Fill in any gaps

# 3. Update roadmap if milestones completed
nano .vibe/roadmap.md

# 4. Finish lab entry
.vibe/skills/lab_entry/lab_entry.sh finish

# 5. Commit changes
git add .vibe/session_log.md .vibe/roadmap.md
git commit -m "Update logs: [summary]"
git push
```

## 📝 What Gets Automated

### ✅ Automatically Captured
- **Commit SHAs** - From lab entry blocks
- **Commit messages** - From git history
- **Timestamps** - When work was done
- **Block count** - How many work units completed
- **Commit count** - Total commits tracked
- **Session duration** - Start/end times

### 📝 Manual Additions (Recommended)
- **Objectives** - What you planned to accomplish
- **Challenges** - Problems encountered and solutions
- **Decisions** - Architectural choices made
- **Metrics** - Lines of code, tests added, etc.
- **Next goals** - What comes next

## 🔄 Integration Points

### Lab Entry → Session Log

```bash
# Lab entry blocks automatically become
# session log accomplishments with:
# - Timestamp
# - Short description
# - Commit count
```

### Git → Documentation

```bash
# Commit messages can feed into:
# - Session logs
# - Roadmap progress
# - Change logs
# - Release notes
```

### Session Log → Roadmap

```bash
# When milestones are completed:
# 1. Mark in session log
# 2. Update roadmap percentages
# 3. Adjust timelines if needed
```

## 💡 Pro Tips

### 1. **Small, Frequent Updates**

```bash
# Add lab entry blocks as you work
# Don't wait until end of day
.vibe/skills/lab_entry/lab_entry.sh combined "Fixed bug" abc123
```

### 2. **Use Commit Messages Wisely**

```bash
# Write descriptive commit messages
# They become part of your documentation
git commit -m "Add user auth: implement JWT validation"
```

### 3. **Automate the Boring Stuff**

```bash
# Let scripts handle:
# - Timestamps
# - Commit counting
# - File listings
# - Basic metrics
```

### 4. **Focus on Insights**

```bash
# Spend manual time on:
# - Why decisions were made
# - Lessons learned
# - Future plans
# - Challenges overcome
```

## 📊 Automation Coverage

| Aspect | Automation Level | Manual Effort |
| ------ | ---------------- | ------------- |
| Commit tracking | 100% | 0% |
| Timestamp recording | 100% | 0% |
| Block counting | 100% | 0% |
| Session log structure | 90% | 10% |
| Objective setting | 0% | 100% |
| Challenge documentation | 0% | 100% |
| Decision rationale | 0% | 100% |
| Metrics collection | 70% | 30% |
| Roadmap updates | 30% | 70% |

**Result: ~75% automation, 25% manual insight**

## 🎯 Best Practices

1. **Start every session** with `.vibe/start_session.sh`
2. **Add lab entry blocks** as you complete work
3. **Run auto_update.sh** at end of day
4. **Fill in the gaps** with your insights
5. **Update roadmap** when milestones change
6. **Commit logs** with your code changes

## 🚀 Advanced Automation

### Create Custom Scripts

```bash
# Example: Auto-generate metrics
# Count files changed today
git diff --name-only $(git log --since="00:00" --until="23:59" --format="%H" | tail -1) | wc -l

# Count lines added/removed
git diff --numstat $(git log --since="00:00" --until="23:59" --format="%H" | tail -1) | awk '{add+=$1; sub+=$2} END {print "+",add,"-",sub}'
```

### Integrate with CI/CD

```bash
# Add to your CI pipeline:
# 1. Update logs on successful build
# 2. Track deployment frequency
# 3. Monitor test coverage trends
```

## 📚 Resources

- **Lab Entry Skill**: `.vibe/skills/lab_entry/lab_entry.sh`
- **Session Log**: `.vibe/session_log.md`
- **Roadmap**: `.vibe/roadmap.md`
- **Auto Update**: `.vibe/auto_update.sh`
- **Start Session**: `.vibe/start_session.sh`

## 🎓 Training

Start with **Level 2 (Semi-Automated)**:
1. Use `update_log.sh` for structure
2. Add lab entry blocks as you work
3. Fill in session log details at end of day

Graduate to **Level 3 (Fully Automated)** when comfortable:
1. Run `auto_update.sh` daily
2. Review and tweak generated content
3. Focus on insights and decisions

**Goal**: Spend <5 minutes/day on tracking, get comprehensive records!
