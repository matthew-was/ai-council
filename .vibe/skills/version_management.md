# AI Council Version Management System

## Semantic Versioning Specification

This system implements Semantic Versioning 2.0.0 for all AI Council skills.

### SemVer Format

```json
MAJOR.MINOR.PATCH
```json

- **MAJOR**: Breaking changes, increment when backward compatibility is broken
- **MINOR**: Backward-compatible features, increment when functionality is added
- **PATCH**: Backward-compatible bug fixes, increment when bugs are fixed

### Version Constraints

#### Caret Constraints (`^`)
- `^1.2.3` := `>=1.2.3 <2.0.0`
- Allows minor and patch updates within same major version

#### Tilde Constraints (`~`)
- `~1.2.3` := `>=1.2.3 <1.3.0`
- Allows patch updates within same minor version

#### Comparison Operators
- `>=1.2.3`: Greater than or equal to 1.2.3
- `>1.2.3`: Greater than 1.2.3
- `<=1.2.3`: Less than or equal to 1.2.3
- `<1.2.3`: Less than 1.2.3
- `=1.2.3`: Equal to 1.2.3

## Version Management Workflow

### Version Bump Process
1. **Identify Change Type**:
   - Bug fix → `patch` bump
   - New feature (backward compatible) → `minor` bump
   - Breaking change → `major` bump

2. **Update Version**:

   ```bash
   .vibe/skills/version_manager.sh bump 1.2.3 patch  # → 1.2.4
   .vibe/skills/version_manager.sh bump 1.2.3 minor  # → 1.3.0
   .vibe/skills/version_manager.sh bump 1.2.3 major  # → 2.0.0
   ```

1. **Update Registry**:
   - Update `skills.json` with new version
   - Update `SKILLS.md` version table
   - Add change log entry

2. **Validate**:

   ```bash
   .vibe/skills/version_manager.sh validate-registry
   ```

### Constraint Management
1. **Define Constraints**:

   ```json
   "constraints": {
     "doc_skill": "^1.0.0",
     "code_skill": ">=1.2.0 <2.0.0"
   }
   ```

2. **Check Compatibility**:

   ```bash
   .vibe/skills/version_manager.sh compatibility doc_skill 1.2.3 code_skill 1.1.0 "^1.0.0"
   ```

## Implementation Details

### Version Validation
- Regex pattern: `^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-((?:0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$`
- Validates MAJOR.MINOR.PATCH format
- Supports pre-release and build metadata

### Version Comparison Algorithm
1. Split versions into components
2. Compare major versions numerically
3. If equal, compare minor versions
4. If equal, compare patch versions
5. Return -1, 0, or 1

### Constraint Resolution
1. Parse constraint type (^, ~, >=, etc.)
2. Extract base version
3. Calculate version range
4. Check if target version falls within range

## Usage Examples

### Basic Validation

```bash
.vibe/skills/version_manager.sh validate 1.2.3
# ✅ Valid version: 1.2.3

.vibe/skills/version_manager.sh validate 1.2
# ❌ Invalid version: 1.2
```json

### Version Comparison

```bash
.vibe/skills/version_manager.sh compare 1.2.3 1.2.4
# -1 (1.2.3 < 1.2.4)

.vibe/skills/version_manager.sh compare 1.2.3 1.2.3
# 0 (equal)

.vibe/skills/version_manager.sh compare 1.2.4 1.2.3
# 1 (1.2.4 > 1.2.3)
```json

### Constraint Checking

```bash
.vibe/skills/version_manager.sh constraint 1.2.5 ^1.2.3
# ✅ true (1.2.5 satisfies ^1.2.3)

.vibe/skills/version_manager.sh constraint 2.0.0 ^1.2.3
# ❌ false (2.0.0 does not satisfy ^1.2.3)
```json

### Registry Validation

```bash
.vibe/skills/version_manager.sh validate-registry
# ✅ Valid version: 1.0.0
# ✅ Valid version: 1.0.0
# ... (all skills validated)
```json

## Integration with Existing Systems

### Skills Registry
- All versions in `skills.json` validated against SemVer
- Version constraints documented in compatibility section
- Automatic validation during registry updates

### Change Management
- Version bumps trigger appropriate change workflows
- Major version changes require architectural review
- Minor/patch changes follow standard approval

### Dependency Management
- Version constraints enforced during skill activation
- Compatibility warnings for conflicting versions
- Automatic resolution suggestions

## Testing and Validation

### Test Cases

```bash
# Test version validation
.vibe/skills/version_manager.sh validate 1.0.0
.vibe/skills/version_manager.sh validate 0.0.1
.vibe/skills/version_manager.sh validate 2.3.4-alpha.1

# Test comparisons
.vibe/skills/version_manager.sh compare 1.0.0 1.0.1
.vibe/skills/version_manager.sh compare 1.1.0 1.0.1
.vibe/skills/version_manager.sh compare 2.0.0 1.9.9

# Test constraints
.vibe/skills/version_manager.sh constraint 1.2.3 ^1.0.0
.vibe/skills/version_manager.sh constraint 1.2.3 ~1.2.0
.vibe/skills/version_manager.sh constraint 1.2.3 ">=1.2.0"
```json

### Validation Commands

```bash
# Validate all skill versions
.vibe/skills/version_manager.sh validate-registry

# Check specific compatibility
.vibe/skills/version_manager.sh compatibility skill1 1.2.3 skill2 1.1.0 "^1.0.0"

# Test version bumping
.vibe/skills/version_manager.sh bump 1.2.3 patch
.vibe/skills/version_manager.sh bump 1.2.3 minor
.vibe/skills/version_manager.sh bump 1.2.3 major
```json

## Best Practices

### Version Management
- Always use semantic versioning
- Document version changes in change log
- Test compatibility before deployment
- Validate versions during CI/CD

### Constraint Usage
- Use `^` for most dependencies (allows minor/patch updates)
- Use `~` for strict minor version compatibility
- Use exact versions (`=`) only when necessary
- Avoid overly restrictive constraints

### Registry Maintenance
- Keep versions up to date
- Validate regularly
- Document all version changes
- Test after version updates
