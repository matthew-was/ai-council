# AI Council CI/CD Workflows

## 🎯 Overview

This directory contains GitHub Actions workflows that automate the AI Council development process. The workflows integrate with the skills registry and workflow automation system to provide end-to-end automation for document management, testing, and deployment.

## 📁 Directory Structure

```
.github/workflows/
├── document-automation.yml      # Main document automation workflow
├── testing-validation.yml       # Testing and validation workflow
├── change-propagation.yml       # Change propagation workflow
└── monitoring-notifications.yml  # Monitoring and notifications workflow
```

## 🚀 Quick Start

The workflows are automatically triggered by GitHub events. No manual setup is required beyond the initial configuration.

### Workflow Triggers

| Workflow | Trigger | Description |
|----------|---------|-------------|
| `document-automation` | Push/PR to main | Automates document changes |
| `testing-validation` | Push/PR to main | Runs comprehensive tests |
| `change-propagation` | Push to main | Propagates approved changes |
| `monitoring-notifications` | Schedule/Manual | System monitoring |

## 📖 Workflow Documentation

### document-automation.yml

**Purpose**: Main workflow that automates document changes through the complete lifecycle.

**Jobs**:
1. **Document Validation** - Validates Markdown, YAML, and JSON structures
2. **Impact Assessment** - Assesses change impact and generates reports
3. **Approval Workflow** - Creates approval requests for pull requests
4. **Change Propagation** - Propagates changes on main branch merges
5. **Monitoring** - Generates monitoring reports

**Artifacts**:
- `impact-reports` - Impact assessment reports
- `monitoring-report` - Monitoring reports

### testing-validation.yml

**Purpose**: Comprehensive testing and validation of all system components.

**Jobs**:
1. **Unit Testing** - Runs skill and workflow tests
2. **Integration Testing** - Tests workflow integration
3. **Validation** - Validates registry structure and documents
4. **Test Coverage** - Calculates and reports test coverage

**Artifacts**:
- `validation-report` - Validation reports
- `coverage-report` - Test coverage reports

### change-propagation.yml

**Purpose**: Automates the propagation of approved document changes.

**Jobs**:
1. **Detect Changes** - Identifies changed files
2. **Propagate Changes** - Executes propagation for changed files
3. **Update Versions** - Bumps version numbers
4. **Commit Changes** - Automatically commits and pushes changes
5. **Notification** - Generates propagation notifications

**Artifacts**:
- `propagation-report` - Propagation reports
- `propagation-notification` - Notification reports

### monitoring-notifications.yml

**Purpose**: System monitoring and alert generation.

**Jobs**:
1. **System Monitoring** - Checks system health and generates reports
2. **Workflow Notifications** - Creates workflow status notifications
3. **Workflow Summary** - Generates executive summary reports
4. **Notification Dispatch** - Dispatches final notifications

**Artifacts**:
- `system-monitoring-report` - System monitoring reports
- `workflow-notification` - Workflow notifications
- `workflow-summary` - Summary reports
- `dispatch-notification` - Dispatch notifications

## 🔧 Setup and Configuration

### Requirements

- GitHub repository with Actions enabled
- Workflow permissions for repository access
- Runner environment with bash, jq, and other tools

### Environment Setup

The workflows automatically set up the required environment:

```yaml
- name: Set up environment
  run: |
    sudo apt-get update
    sudo apt-get install -y jq
    npm install -g markdownlint-cli
```

### Secrets

No secrets are required for basic operation. For notifications (Slack, Email, etc.), you would need to configure appropriate secrets.

## 📊 Workflow Integration

The CI/CD workflows integrate with:

1. **Skills Registry** - `.vibe/skills/skills.json`
2. **Workflow Automation** - `.vibe/workflows/*`
3. **Monitoring System** - `.vibe/monitoring/*`
4. **Documentation** - `docs/*`

## 💡 Best Practices

### Workflow Optimization

1. **Use caching** for dependencies to speed up workflows
2. **Parallelize jobs** where possible for faster execution
3. **Limit workflow triggers** to relevant paths to avoid unnecessary runs
4. **Use artifacts** to preserve intermediate outputs
5. **Monitor workflow execution** times and optimize as needed

### Security

1. **Follow least privilege** principles for workflow permissions
2. **Review workflows** before merging to main branch
3. **Use secrets** for sensitive information
4. **Audit workflow logs** regularly
5. **Rotate secrets** periodically

### Maintenance

1. **Update workflows** when requirements change
2. **Review workflows** regularly for improvements
3. **Clean up old workflows** that are no longer needed
4. **Document workflows** thoroughly
5. **Monitor workflow execution** for performance issues

## 🔍 Troubleshooting

### Common Issues

**Issue**: Workflow not triggering
**Solution**: Check GitHub Actions permissions and path filters

**Issue**: Workflow failing on dependencies
**Solution**: Ensure runner environment has required tools installed

**Issue**: Artifacts not uploading
**Solution**: Check workflow permissions and storage quotas

**Issue**: Workflow timing out
**Solution**: Optimize workflow steps or increase timeout settings

### Debugging

View workflow logs in GitHub Actions tab for detailed debugging information.

## 📚 Related Documentation

- [Workflow Automation](../.vibe/workflows/README.md)
- [Skills Registry](../.vibe/skills/README.md)
- [Monitoring System](../.vibe/monitoring/README.md)

## 🎯 Support

For issues with CI/CD workflows:
1. Check GitHub Actions documentation
2. Review workflow logs
3. Consult GitHub community forums
4. Open an issue in the project repository

## 🎉 Key Features

- ✅ **Automated document processing** through complete lifecycle
- ✅ **Comprehensive testing** with coverage reporting
- ✅ **Change propagation** with automatic version updates
- ✅ **System monitoring** with alert generation
- ✅ **Full integration** with skills registry and workflow automation

The CI/CD workflows provide end-to-end automation for the AI Council system, enabling efficient and reliable document management and development processes.
