# 🔐 Vibe Tool Permissions & Access Control

This document explains how to control and manage permissions for Vibe tools and skills.

## 📋 Permission Levels

### 1. **System-Level Permissions**

Controlled via `.vibe/config.json` - affects all users and tools.

**Current Configuration:**

```json
{
  "vibe_settings": {
    "markdown_lint_strict": false,
    "use_project_lint_config": true,
    "max_session_duration": 3600,
    "preferred_editor": "vscode"
  },
  "development_tools": {
    "python_version": "3.13.12",
    "docker_enabled": true,
    "test_framework": "pytest"
  }
}
```

### 2. **Skill-Specific Permissions**

Each skill can have its own permission settings in its `SKILL.md` file.

**Example (from automation_skill/SKILL.md):**

```yaml
---
name: automation_skill
description: Provides session management and workflow automation
metadata:
  author: ai-council
  version: "1.0"
  license: MIT
  permissions:
    default: "read"
    execute: ["start_session.sh", "status.sh"]
    restricted: ["auto_update.sh"]
---
```

### 3. **User-Level Permissions**

User-specific permissions can be managed in `.vibe/users/<username>.json`

## 🔧 Permission Configuration

### Global Permission Settings

Add to `.vibe/config.json`:

```json
{
  "permission_settings": {
    "default_skill_access": "read",
    "restricted_skills": ["system_management_skill"],
    "admin_users": ["matthew"],
    "skill_execution_rules": {
      "automation_skill": {
        "allowed_scripts": ["start_session.sh", "status.sh", "update_log.sh"],
        "restricted_scripts": ["auto_update.sh"]
      }
    }
  }
}
```

### Skill Permission Levels

| Level | Description | Example Use Cases |
| --- | --- | --- |
| **admin** | Full access, including registration/modification | System administrators |
| **write** | Can execute and modify skill configurations | Developers |
| **read** | Can execute but not modify | Reviewers, testers |
| **none** | No access | Restricted users |

## 🛡️ Access Control Implementation

### Method 1: Configuration File Control

**File:** `.vibe/access_control.json`

```json
{
  "users": {
    "matthew": {
      "role": "admin",
      "skills": {
        "*": "admin",
        "system_management_skill": "admin"
      }
    },
    "guest": {
      "role": "read",
      "skills": {
        "automation_skill": "read",
        "doc_skill": "read"
      }
    }
  },
  "roles": {
    "admin": {
      "description": "Full system access",
      "permissions": ["*"]
    },
    "developer": {
      "description": "Development access",
      "permissions": ["automation_skill", "doc_skill", "code_skill", "test_skill"]
    },
    "reviewer": {
      "description": "Read-only access",
      "permissions": ["automation_skill:read", "doc_skill:read"]
    }
  }
}
```

### Method 2: Environment-Based Control

**File:** `.vibe/environment_permissions.json`

```json
{
  "environments": {
    "development": {
      "default_access": "write",
      "restricted_skills": []
    },
    "production": {
      "default_access": "read",
      "restricted_skills": ["system_management_skill", "workflow_skill"],
      "admin_only": ["skill_registrar.sh", "skill_validator.sh"]
    },
    "testing": {
      "default_access": "read",
      "allowed_skills": ["automation_skill", "test_skill", "doc_skill"]
    }
  }
}
```

## 🔐 Skill-Specific Permission Examples

### Automation Skill Permissions

```yaml
# In automation_skill/SKILL.md
---
name: automation_skill
metadata:
  permissions:
    default: "write"
    scripts:
      start_session.sh: "public"
      status.sh: "public"
      update_log.sh: "write"
      auto_update.sh: "admin"
---
```

### System Management Skill Permissions

```yaml
# In system_management_skill/SKILL.md
---
name: system_management_skill
metadata:
  permissions:
    default: "admin"
    scripts:
      skill_registrar.sh: "admin"
      skill_validator.sh: "admin"
      skill_parser.sh: "write"
      skill_scanner.sh: "read"
---
```

## 🎯 Permission Management Commands

### Check Current Permissions

```bash
# Check skill permissions
.vibe/skills/system_management_skill/scripts/skill_parser.sh extract .vibe/skills/automation_skill all

# List all registered skills
jq '.skills | keys' .vibe/skills/skills.json
```

### Modify Permissions

```bash
# Update config.json permissions
jq '.permission_settings.admin_users += ["new_admin"]' .vibe/config.json > tmp.json && mv tmp.json .vibe/config.json

# Restrict a skill
jq '.permission_settings.skill_execution_rules.automation_skill.restricted_scripts += ["update_log.sh"]' .vibe/config.json > tmp.json && mv tmp.json .vibe/config.json
```

## 📊 Permission Matrix

| Skill | Default Access | Admin Required | Read-Only Users | Notes |
| --- | --- | --- | --- | --- |
| **automation_skill** | write | auto_update.sh | All scripts | Session management |
| **system_management_skill** | admin | All scripts | None | System control |
| **doc_skill** | write | None | lint_docs.sh | Documentation |
| **workflow_skill** | write | version_updates.sh | status scripts | Workflow control |
| **test_skill** | write | None | run_tests.sh | Testing |
| **monitoring_skill** | read | None | All scripts | Monitoring |

## 🔧 Implementation Guide

### Step 1: Create Access Control File

```bash
cat > .vibe/access_control.json << 'EOF'
{
  "users": {
    "matthew": {
      "role": "admin",
      "skills": {
        "*": "admin"
      }
    }
  },
  "roles": {
    "admin": {
      "description": "Full system access",
      "permissions": ["*"]
    },
    "developer": {
      "description": "Development access",
      "permissions": ["automation_skill", "doc_skill", "code_skill", "test_skill"]
    }
  }
}
EOF
```

### Step 2: Update Skill Permissions

Add permissions section to each SKILL.md:

```bash
# For automation_skill/SKILL.md
yq -i '.metadata.permissions = {
  "default": "write",
  "scripts": {
    "start_session.sh": "public",
    "status.sh": "public",
    "update_log.sh": "write",
    "auto_update.sh": "admin"
  }
}' .vibe/skills/automation_skill/SKILL.md
```

### Step 3: Create Permission Check Script

```bash
cat > .vibe/check_permissions.sh << 'EOF'
#!/bin/bash

# Check if user has permission to use a skill/script
check_permission() {
    local user="$1"
    local skill="$2"
    local script="$3"
    
    # Default to admin if no access control file
    if [[ ! -f ".vibe/access_control.json" ]]; then
        return 0
    fi
    
    # Check user role
    local role=$(jq -r ".users[\"$user\"].role" .vibe/access_control.json 2>/dev/null || echo "guest")
    
    # Admins can do anything
    if [[ "$role" == "admin" ]]; then
        return 0
    fi
    
    # Check skill-specific permissions
    local skill_perm=$(jq -r ".users[\"$user\"].skills[\"$skill\"]" .vibe/access_control.json 2>/dev/null || echo "")
    
    if [[ -n "$skill_perm" && "$skill_perm" != "none" ]]; then
        return 0
    fi
    
    # Check role permissions
    local role_perms=$(jq -r ".roles[\"$role\"].permissions[]" .vibe/access_control.json 2>/dev/null)
    
    if echo "$role_perms" | grep -q "$skill"; then
        return 0
    fi
    
    echo "❌ Permission denied: $user cannot access $skill/$script"
    return 1
}

# Example usage:
# if check_permission "matthew" "automation_skill" "start_session.sh"; then
#     .vibe/skills/automation_skill/scripts/start_session.sh
# else
#     echo "Access denied"
# fi
EOF

chmod +x .vibe/check_permissions.sh
```

## 💡 Best Practices

### Permission Management Recommendations

1. **Start Restrictive**: Begin with minimal permissions and expand as needed
2. **Role-Based Access**: Use roles (admin, developer, reviewer) rather than individual permissions
3. **Audit Regularly**: Review permissions periodically
4. **Document Changes**: Keep a log of permission changes in `session_log.md`
5. **Test Permissions**: Verify access controls work as expected

### Common Permission Scenarios

| Scenario | Recommended Setup |
| --- | --- |
| **Solo Developer** | All skills: admin access |
| **Small Team** | Core skills: write, system skills: admin-only |
| **Large Team** | Role-based access with clear boundaries |
| **Production** | Restricted access, admin-only for critical operations |

## 📝 Permission Change Log

Track permission changes in `.vibe/session_log.md`:

```markdown
## 📅 2026-03-20 - Permission Setup

### 🔐 Security Changes
- ✅ Created access_control.json
- ✅ Set up admin role for matthew
- ✅ Configured skill-specific permissions
- ✅ Added permission check script

### 📊 Permission Summary
- **Admin Users**: matthew
- **Default Access**: write for core skills, admin for system skills
- **Restricted Scripts**: auto_update.sh, skill_registrar.sh
```

## 🚨 Troubleshooting

### Common Issues

**Problem:** "Permission denied" when running a script
**Solution:** Check `.vibe/access_control.json` and your user role

**Problem:** Script not found in allowed list
**Solution:** Update the skill permissions in SKILL.md or access_control.json

**Problem:** Admin commands failing
**Solution:** Verify admin status in access_control.json

### Debugging Commands

```bash
# Check your permissions
jq ".users[matthew]" .vibe/access_control.json

# List all admin users
jq ".users[] | select(.role == \"admin\") | .name" .vibe/access_control.json

# Check skill permissions
jq ".skills.automation_skill.metadata.permissions" .vibe/skills/automation_skill/SKILL.md
```

## 🔒 Security Recommendations

1. **Backup Config Files**: Regularly backup `.vibe/config.json` and `.vibe/access_control.json`
2. **Limit Admin Access**: Only essential users should have admin privileges
3. **Review Periodically**: Audit permissions monthly
4. **Use Git**: Track permission changes in version control
5. **Document**: Keep permission rationale documented

## 📚 Related Documents

- `.vibe/config.json` - Main configuration file
- `.vibe/access_control.json` - User permission settings
- `.vibe/SKILLS_OVERVIEW.md` - Skill capabilities reference
- Individual `SKILL.md` files - Skill-specific permissions

---

**Note:** The current system has minimal permission controls. Implement the recommendations above to establish proper access management as your team grows.
