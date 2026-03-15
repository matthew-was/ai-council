# Vibe Command Reference for AI Council

<!-- markdownlint-disable MD031 -->

## Common Commands

### Documentation

```bash
# Run markdown linting
markdownlint .

# Check specific document
markdownlint docs/requirements.md

# Create new markdown document
.vibe/create_doc.sh "architecture" "System Architecture Design"

```

### Project Management
```bash
# Start a new session
.vibe/start_session.sh

# Update session log
.vibe/update_log.sh "Completed requirements document"

# Check project status
.vibe/status.sh

```

### Git Operations
```bash
# Commit with conventional message
.vibe/git_commit.sh "feat: add requirements documentation"

# Create feature branch
.vibe/git_branch.sh "feat/agent-framework"

# Sync with remote
git push origin $(git branch --show-current)

```

### Development
```bash
# Run tests (to be created)
.vibe/run_tests.sh

# Build documentation
.vibe/build_docs.sh

# Start development environment
.vibe/dev_up.sh

```

## Command Patterns

### Documentation First
```bash
# Always create/update docs before coding
.vibe/create_doc.sh "component_name" "Component Description"

```

### Consistent Formatting
```bash
# Format all markdown
.vibe/format_markdown.sh

# Format Python code (when available)
.vibe/format_python.sh

```

### Session Workflow
```bash
# Typical session flow
.vibe/start_session.sh
# ... work ...
.vibe/update_log.sh "Progress made"
.vibe/end_session.sh

```

## Custom Commands

Add project-specific commands to `.vibe/custom_commands.sh`
