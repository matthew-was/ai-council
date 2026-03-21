# AI Council Skills Version Matrix

## Current Version Compatibility

This document provides a comprehensive overview of skill versions and their compatibility across the AI Council system.

## Version Matrix

### Registry Version: 2.0
**Last Updated**: 2026-03-17
**Status**: 🟢 Current

### Skill Versions

| Skill Name | Current Version | Semantic Version | Status | Compatibility |
| ---------- | -------------- | --------------- | ------ | ------------- |
| arch_skill | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| code_skill | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| doc_skill | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| lab_entry | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| monitoring_skill | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| system_management_skill | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| workflow_skill | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| doc_change_manager | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| test_skill | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| lab_entry | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |
| doc_change_manager | v1.0 | 1.0.0 | 🟢 Active | ✅ All systems |

## Compatibility Rules

### Semantic Versioning
All skills follow semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking changes, increment when backward compatibility is broken
- **MINOR**: Backward-compatible features, increment when functionality is added
- **PATCH**: Backward-compatible bug fixes, increment when bugs are fixed

### Version Compatibility Matrix

| System Version | Skill Versions Supported | Status |
| -------------- | ----------------------- | ------ |
| v1.0 | 1.0.0 - 1.x.x | 🟢 Current |
| v0.9 | 0.9.0 - 0.9.x | ⚪ Archived |

### Dependency Compatibility

| Skill | Depends On | Required By | Compatibility |
| ----- | ---------- | ----------- | ------------- |
| doc_skill | - | doc_change_manager | ✅ Independent |
| code_skill | - | - | ✅ Independent |
| test_skill | - | - | ✅ Independent |
| arch_skill | - | - | ✅ Independent |
| lab_entry | jq | - | ✅ Tool dependency |
| doc_change_manager | doc_skill | - | ✅ Skill dependency |

## Version History

### Version 1.0 (Current)
**Release Date**: 2026-03-15
**Status**: 🟢 Stable

**Skills Included**:
- doc_skill v1.0.0
- code_skill v1.0.0
- test_skill v1.0.0
- arch_skill v1.0.0
- lab_entry v1.0.0
- doc_change_manager v1.0.0

**Features**:
- Complete skill registry with version tracking
- Status indicators for all skills
- Capabilities documentation
- Dependency mapping
- Enhanced validation system

### Version 0.9 (Archived)
**Release Date**: 2026-03-10
**Status**: ⚪ Archived

**Skills Included**:
- Basic skill definitions
- Minimal metadata
- No version tracking
- No dependency management

## Upgrade Paths

### From v0.9 to v1.0
1. **Backup**: Create backup of existing skills.json
2. **Transform**: Convert to enhanced registry format
3. **Validate**: Run schema validation
4. **Test**: Verify all skills operational
5. **Document**: Update SKILLS.md and version_matrix.md
6. **Deploy**: Replace old registry with new one

### Version Compatibility Checklist

- [x] All skills have semantic versions
- [x] Version matrix documented
- [x] Dependency graph created
- [x] Compatibility rules defined
- [x] Upgrade paths documented
- [x] Validation system implemented

## Version Management Protocol

### Version Update Process
1. **Identify Change Type**:
   - Bug fix → PATCH increment
   - New feature (backward compatible) → MINOR increment
   - Breaking change → MAJOR increment

2. **Update Registry**:
   - Update version in skills.json
   - Update version_matrix.md
   - Update SKILLS.md
   - Add change log entry

3. **Validation**:
   - Run registry validation
   - Test skill functionality
   - Verify dependencies
   - Check compatibility

4. **Documentation**:
   - Update SKILL.md files
   - Update version_matrix.md
   - Add release notes
   - Update change log

5. **Deployment**:
   - Create backup
   - Deploy updated registry
   - Notify dependent systems
   - Monitor for issues

## Compatibility Testing

### Test Scenarios
1. **Forward Compatibility**: Newer skills work with older system
2. **Backward Compatibility**: Older skills work with newer system
3. **Cross-Version**: Different skill versions work together
4. **Dependency Resolution**: All dependencies available and compatible

### Validation Commands

```bash
# Validate registry structure
.vibe/skills/registry_utils.sh validate

# Check version compatibility
.vibe/skills/registry_utils.sh compatibility

# Validate all skills
.vibe/skills/registry_utils.sh validate-all

# Show version matrix
.vibe/skills/registry_utils.sh version-matrix
```

## Future Version Planning

### Version 1.1 (Planned)
**Target Date**: 2026-04-01
**Features**:
- Enhanced dependency resolution
- Automatic version checking
- Skill update notifications
- Compatibility warnings

### Version 2.0 (Roadmap)
**Target Date**: 2026-Q3
**Features**:
- Major architecture improvements
- New skill types
- Enhanced validation
- Advanced dependency management

## Troubleshooting

### Common Version Issues

**Issue**: Version mismatch warnings
- **Cause**: Skills have different versions than expected
- **Solution**: Update skills to compatible versions or adjust version_matrix.md

**Issue**: Dependency resolution failures
- **Cause**: Missing or incompatible dependencies
- **Solution**: Install required dependencies or update dependency_graph

**Issue**: Validation failures
- **Cause**: Registry structure doesn't match schema
- **Solution**: Fix registry structure or update schema

### Version Conflict Resolution
1. **Identify**: Determine which versions are in conflict
2. **Analyze**: Check compatibility matrix for supported combinations
3. **Resolve**: Update to compatible versions or adjust requirements
4. **Test**: Verify the resolution works
5. **Document**: Update version_matrix.md with the resolution

## Best Practices

### Version Management
- Always use semantic versioning
- Document all version changes
- Test compatibility before deployment
- Maintain backward compatibility when possible
- Deprecate old versions gracefully

### Dependency Management
- Explicitly document all dependencies
- Specify version requirements
- Test dependency resolution
- Handle missing dependencies gracefully
- Provide clear error messages

### Registry Maintenance
- Keep registry up to date
- Validate regularly
- Backup before major changes
- Document all modifications
- Test after updates
