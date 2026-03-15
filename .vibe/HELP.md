# .vibe Directory Help Guide

## 🎯 Purpose

This `.vibe` directory contains tools and configuration to help you manage your Vibe usage and maintain consistency across development sessions for the AI Council project.

## 📁 Files Overview

### Core Files

| File | Purpose | Usage |
| --- | --- | --- |
| **`rules.md`** | Project rules and guidelines | Read at session start |
| **`start_session.sh`** | Session initialization script | `.vibe/start_session.sh` |
| **`HELP.md`** | This help guide | Reference as needed |

### Workflow Tools

| File | Purpose | Usage |
| --- | --- | --- |
| **`update_log.sh`** | Create new session log entry | `.vibe/update_log.sh` |
| **`status.sh`** | Show project status | `.vibe/status.sh` |
| **`vibe_commands.md`** | Common Vibe commands | Reference |

### Tracking & Planning

| File | Purpose | Usage |
| --- | --- | --- |
| **`roadmap.md`** | Project roadmap and milestones | Update regularly |
| **`session_log.md`** | Development session history | Log after each session |

### Configuration

| File | Purpose | Usage |
| --- | --- | --- |
| **`config.json`** | Vibe configuration | Customize as needed |
| **`README.md`** | .vibe directory overview | Reference |

## 🚀 Quick Start

### Beginning a Session

```bash
cd /path/to/ai-council
.vibe/start_session.sh
```

### Ending a Session

```bash
.vibe/update_log.sh
.vibe/status.sh
```

### Checking Progress

```bash
.vibe/status.sh
```

## 📖 Common Workflows

### Documentation Workflow

```bash
# Start session
.vibe/start_session.sh

# Create/update documentation
# ... edit files ...

# Check formatting
markdownlint .

# Update session log
.vibe/update_log.sh

# Commit changes
git add .
git commit -m "docs: update requirements"
```

### Development Workflow

```bash
# Start session
.vibe/start_session.sh

# Check roadmap
.vibe/roadmap.md

# Implement feature
# ... code ...

# Update session log
.vibe/update_log.sh

# Commit changes
git add .
git commit -m "feat: implement agent framework"
```

## 🔧 Customization

### Adding New Tools
1. Create script in `.vibe/` directory
2. Make executable: `chmod +x script.sh`
3. Document in `vibe_commands.md`
4. Add to workflow in `rules.md`

### Modifying Configuration
Edit `config.json` to customize:
- Preferred tools
- Command aliases
- Workflow preferences
- Quality settings

## 💡 Tips

### Consistency
- Always start with `.vibe/start_session.sh`
- Follow the checklist in `rules.md`
- Update `session_log.md` after each session

### Documentation
- Documentation first, code second
- Run `markdownlint` before committing
- Keep `roadmap.md` updated

### Collaboration
- Use conventional commit messages
- Reference issues in commits
- Update roadmap with progress

## 📊 Current Status

Run `.vibe/status.sh` to see:
- Project structure overview
- Documentation statistics
- Git status
- Quality checks
- Roadmap progress
- Recent sessions

## 🔄 Maintenance

### Weekly
- Review and update `roadmap.md`
- Clean up `session_log.md`
- Check `config.json` for updates

### Monthly
- Review `rules.md` for improvements
- Update `vibe_commands.md` with new patterns
- Archive old session logs if needed

## 🆘 Troubleshooting

### Markdown Linting Issues

```bash
# Check specific file
markdownlint docs/requirements.md

# Fix automatically (if possible)
markdownlint --fix .
```

### Script Permissions

```bash
# Make all scripts executable
chmod +x .vibe/*.sh
```

### Missing Tools

```bash
# Install markdownlint
npm install -g markdownlint-cli
```

## 📚 Resources

- **[Markdown Guide](https://www.markdownguide.org/)**
- **[Conventional Commits](https://www.conventionalcommits.org/)**
- **[Git Best Practices](https://git-scm.com/doc)**
- **[FastAPI Docs](https://fastapi.tiangolo.com/)**

## 🎓 Best Practices

1. **Documentation First**: Always update docs before coding
2. **Consistent Formatting**: Use markdownlint for all docs
3. **Session Logging**: Track progress in session_log.md
4. **Roadmap Updates**: Keep priorities current
5. **Quality Checks**: Run linting before committing

## 📞 Support

For Vibe-specific questions:
- Check `.vibe/rules.md` first
- Review `vibe_commands.md` for examples
- Update `config.json` for customization

For project questions:
- Check `docs/requirements.md`
- Review `overview.md`
- Update `roadmap.md` with questions
