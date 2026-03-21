#!/bin/bash

# Integration Test for Skill Discovery and Registration
# Tests the complete workflow from scanning to registration

echo "🧪 Integration Test: Skill Discovery & Registration"
echo "=================================================="

# Test variables
TEST_SKILL_DIR=".vibe/skills/test_integration_skill"
TEST_SKILL_NAME="test_integration_skill"
REGISTRY_FILE=".vibe/skills/skills.json"

# Clean up any existing test skill
cleanup_test_skill() {
    if [[ -d "$TEST_SKILL_DIR" ]]; then
        rm -rf "$TEST_SKILL_DIR"
    fi
    
    # Remove from registry if exists
    if jq -e ".skills[\"$TEST_SKILL_NAME\"]" "$REGISTRY_FILE" >/dev/null 2>&1; then
        jq "del(.skills.$TEST_SKILL_NAME)" "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && \
        mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"
    fi
}

# Set up test skill
setup_test_skill() {
    mkdir -p "$TEST_SKILL_DIR"
    cat > "$TEST_SKILL_DIR/SKILL.md" << 'EOF'
---
name: test_integration_skill
description: Integration test skill
metadata:
  version: "2.0"
  author: ai-council
  license: MIT
---

# Integration Test Skill
This skill is used for integration testing.
EOF
}

echo ""
echo "Test 1: Skill Scanner - Directory Discovery"
echo "-------------------------------------------"
setup_test_skill

# Test scanning
found_skills=$(.vibe/skills/skill_scanner.sh scan)
if [[ "$found_skills" == *"$TEST_SKILL_NAME"* ]]; then
    echo "✅ PASS: Scanner found test skill"
else
    echo "❌ FAIL: Scanner did not find test skill"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 2: Skill Scanner - Discovery of Unregistered Skills"
echo "-------------------------------------------------------"
# Test discovery (should find our test skill)
discovered_skills=$(.vibe/skills/skill_scanner.sh discover)
if [[ "$discovered_skills" == *"$TEST_SKILL_NAME"* ]]; then
    echo "✅ PASS: Discovery found unregistered test skill"
else
    echo "❌ FAIL: Discovery did not find unregistered test skill"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 3: Skill Parser - Metadata Extraction"
echo "------------------------------------------"
# Test parsing
parsed_name=$(.vibe/skills/skill_parser.sh extract "$TEST_SKILL_DIR" "name")
parsed_version=$(.vibe/skills/skill_parser.sh extract "$TEST_SKILL_DIR" "version")

if [[ "$parsed_name" == "$TEST_SKILL_NAME" && "$parsed_version" == "2.0" ]]; then
    echo "✅ PASS: Parser extracted correct metadata"
else
    echo "❌ FAIL: Parser failed to extract correct metadata"
    echo "  Expected: name=$TEST_SKILL_NAME, version=2.0"
    echo "  Got: name=$parsed_name, version=$parsed_version"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 4: Skill Validator - Structure Validation"
echo "----------------------------------------------"
# Test validation
if .vibe/skills/skill_validator.sh validate "$TEST_SKILL_DIR" >/dev/null 2>&1; then
    echo "✅ PASS: Validator confirmed skill structure is valid"
else
    echo "❌ FAIL: Validator rejected valid skill structure"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 5: Skill Registrar - Single Skill Registration"
echo "---------------------------------------------------"
# Test registration
if .vibe/skills/skill_registrar.sh register "$TEST_SKILL_DIR" >/dev/null 2>&1; then
    # Verify registration
    if jq -e ".skills[\"$TEST_SKILL_NAME\"]" "$REGISTRY_FILE" >/dev/null 2>&1; then
        echo "✅ PASS: Registrar successfully registered skill"
    else
        echo "❌ FAIL: Skill not found in registry after registration"
        cleanup_test_skill
        exit 1
    fi
else
    echo "❌ FAIL: Registration command failed"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 6: Registry Verification - Metadata Integrity"
echo "--------------------------------------------------"
# Verify metadata integrity
registered_version=$(jq -r ".skills.$TEST_SKILL_NAME.metadata.version" "$REGISTRY_FILE")
registered_name=$(jq -r ".skills.$TEST_SKILL_NAME.metadata.name" "$REGISTRY_FILE")

if [[ "$registered_version" == "2.0" && "$registered_name" == "$TEST_SKILL_NAME" ]]; then
    echo "✅ PASS: Registry contains correct metadata"
else
    echo "❌ FAIL: Registry metadata incorrect"
    echo "  Expected: name=$TEST_SKILL_NAME, version=2.0"
    echo "  Got: name=$registered_name, version=$registered_version"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 7: Version Matrix Update"
echo "---------------------------"
# Check version matrix (should use major.minor version)
version_matrix_entry=$(jq -r ".version_matrix[\"2\"]" "$REGISTRY_FILE")
if [[ "$version_matrix_entry" == *"$TEST_SKILL_NAME"* ]]; then
    echo "✅ PASS: Version matrix updated correctly"
else
    echo "❌ FAIL: Version matrix not updated correctly"
    echo "  Entry: $version_matrix_entry"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 8: Dependency Graph Update"
echo "------------------------------"
# Check dependency graph
dep_graph_entry=$(jq -r ".dependency_graph[\"$TEST_SKILL_NAME\"]" "$REGISTRY_FILE")
if [[ "$dep_graph_entry" != "null" ]]; then
    echo "✅ PASS: Dependency graph updated correctly"
else
    echo "❌ FAIL: Dependency graph not updated"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 9: Duplicate Registration Prevention"
echo "----------------------------------------"
# Try to register again (should fail gracefully)
registration_result=$(.vibe/skills/skill_registrar.sh register "$TEST_SKILL_DIR" 2>&1)
if [[ "$registration_result" == *"already registered"* ]]; then
    echo "✅ PASS: Duplicate registration prevented"
else
    echo "❌ FAIL: Duplicate registration not prevented"
    echo "  Result: $registration_result"
    cleanup_test_skill
    exit 1
fi

echo ""
echo "Test 10: Register-All Functionality"
echo "----------------------------------"
# Create another test skill for bulk registration
TEST_SKILL_DIR2=".vibe/skills/test_integration_skill2"
mkdir -p "$TEST_SKILL_DIR2"
cat > "$TEST_SKILL_DIR2/SKILL.md" << 'EOF'
---
name: test_integration_skill2
description: Second integration test skill
metadata:
  version: "1.5"
  author: ai-council
  license: MIT
---

# Second Integration Test Skill
Another skill for integration testing.
EOF

# Test register-all
register_all_output=$(.vibe/skills/skill_registrar.sh register-all 2>&1)
if [[ "$register_all_output" == *"Registered: test_integration_skill2"* ]]; then
    echo "✅ PASS: Register-all successfully registered new skill"
else
    echo "❌ FAIL: Register-all did not work correctly"
    echo "  Output: $register_all_output"
    cleanup_test_skill
    rm -rf "$TEST_SKILL_DIR2"
    exit 1
fi

# Clean up second test skill
rm -rf "$TEST_SKILL_DIR2"
jq "del(.skills.test_integration_skill2)" "$REGISTRY_FILE" > "$REGISTRY_FILE.tmp" && \
mv "$REGISTRY_FILE.tmp" "$REGISTRY_FILE"

# Final cleanup
cleanup_test_skill

echo ""
echo "📊 Integration Test Summary"
echo "=========================="
echo "✅ All 10 integration tests PASSED!"
echo ""
echo "Integration Test Coverage:"
echo "  ✓ Directory scanning and discovery"
echo "  ✓ SKILL.md parsing and metadata extraction"
echo "  ✓ Skill structure validation"
echo "  ✓ Single skill registration"
echo "  ✓ Bulk skill registration"
echo "  ✓ Registry metadata integrity"
echo "  ✓ Version matrix updates"
echo "  ✓ Dependency graph updates"
echo "  ✓ Duplicate prevention"
echo "  ✓ End-to-end workflow"

echo ""
echo "🎉 Integration testing complete!"
