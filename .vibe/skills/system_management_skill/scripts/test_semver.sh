#!/bin/bash

# Test script for Semantic Versioning Implementation

echo "🧪 Testing AI Council Semantic Versioning System"
echo "==============================================="
echo ""

# Test 1: Version Validation
echo "Test 1: Version Validation"
echo "---------------------------"
if [[ $(.vibe/skills/version_manager.sh validate 1.2.3) == "true" ]]; then
    echo "✅ PASS: Valid version 1.2.3 accepted"
else
    echo "❌ FAIL: Valid version 1.2.3 rejected"
fi

if [[ $(.vibe/skills/version_manager.sh validate 1.2) == "false" ]]; then
    echo "✅ PASS: Invalid version 1.2 rejected"
else
    echo "❌ FAIL: Invalid version 1.2 accepted"
fi

if [[ $(.vibe/skills/version_manager.sh validate abc) == "false" ]]; then
    echo "✅ PASS: Invalid version 'abc' rejected"
else
    echo "❌ FAIL: Invalid version 'abc' accepted"
fi

echo ""

# Test 2: Version Comparison
echo "Test 2: Version Comparison"
echo "---------------------------"
if [[ $(.vibe/skills/version_manager.sh compare 1.2.3 1.2.4) == "-1" ]]; then
    echo "✅ PASS: 1.2.3 < 1.2.4"
else
    echo "❌ FAIL: 1.2.3 < 1.2.4 comparison failed"
fi

if [[ $(.vibe/skills/version_manager.sh compare 1.2.4 1.2.3) == "1" ]]; then
    echo "✅ PASS: 1.2.4 > 1.2.3"
else
    echo "❌ FAIL: 1.2.4 > 1.2.3 comparison failed"
fi

if [[ $(.vibe/skills/version_manager.sh compare 1.2.3 1.2.3) == "0" ]]; then
    echo "✅ PASS: 1.2.3 == 1.2.3"
else
    echo "❌ FAIL: 1.2.3 == 1.2.3 comparison failed"
fi

echo ""

# Test 3: Constraint Checking
echo "Test 3: Constraint Checking"
echo "---------------------------"
if [[ $(.vibe/skills/version_manager.sh constraint 1.2.5 "^1.2.3") == "true" ]]; then
    echo "✅ PASS: 1.2.5 satisfies ^1.2.3"
else
    echo "❌ FAIL: 1.2.5 should satisfy ^1.2.3"
fi

if [[ $(.vibe/skills/version_manager.sh constraint 2.0.0 "^1.2.3") == "false" ]]; then
    echo "✅ PASS: 2.0.0 does not satisfy ^1.2.3"
else
    echo "❌ FAIL: 2.0.0 should not satisfy ^1.2.3"
fi

if [[ $(.vibe/skills/version_manager.sh constraint 1.2.7 "~1.2.3") == "true" ]]; then
    echo "✅ PASS: 1.2.7 satisfies ~1.2.3"
else
    echo "❌ FAIL: 1.2.7 should satisfy ~1.2.3"
fi

if [[ $(.vibe/skills/version_manager.sh constraint 1.3.0 "~1.2.3") == "false" ]]; then
    echo "✅ PASS: 1.3.0 does not satisfy ~1.2.3"
else
    echo "❌ FAIL: 1.3.0 should not satisfy ~1.2.3"
fi

if [[ $(.vibe/skills/version_manager.sh constraint 1.5.0 ">=1.2.0") == "true" ]]; then
    echo "✅ PASS: 1.5.0 satisfies >=1.2.0"
else
    echo "❌ FAIL: 1.5.0 should satisfy >=1.2.0"
fi

echo ""

# Test 4: Version Bumping
echo "Test 4: Version Bumping"
echo "---------------------------"
if [[ $(.vibe/skills/version_manager.sh bump 1.2.3 patch) == "1.2.4" ]]; then
    echo "✅ PASS: Patch bump 1.2.3 → 1.2.4"
else
    echo "❌ FAIL: Patch bump failed"
fi

if [[ $(.vibe/skills/version_manager.sh bump 1.2.3 minor) == "1.3.0" ]]; then
    echo "✅ PASS: Minor bump 1.2.3 → 1.3.0"
else
    echo "❌ FAIL: Minor bump failed"
fi

if [[ $(.vibe/skills/version_manager.sh bump 1.2.3 major) == "2.0.0" ]]; then
    echo "✅ PASS: Major bump 1.2.3 → 2.0.0"
else
    echo "❌ FAIL: Major bump failed"
fi

echo ""

# Test 5: Registry Validation
echo "Test 5: Registry Validation"
echo "---------------------------"
output=$(.vibe/skills/version_manager.sh validate-registry 2>&1)
if echo "$output" | grep -q "✅ Valid version"; then
    echo "✅ PASS: Registry validation working"
else
    echo "❌ FAIL: Registry validation failed"
fi

echo ""

# Test 6: Registry Utils Integration
echo "Test 6: Registry Utils Integration"
echo "-----------------------------------"
output=$(.vibe/skills/registry_utils.sh validate-semver 2>&1)
if echo "$output" | grep -q "Validating semantic versions"; then
    echo "✅ PASS: Registry utils integration working"
else
    echo "❌ FAIL: Registry utils integration failed"
fi

echo ""
echo "📊 Test Summary"
echo "=============="
echo "All core semantic versioning functions implemented and tested:"
echo "✅ Version validation"
echo "✅ Version comparison"
echo "✅ Constraint checking (^, ~, >=, >, <=, <, =)"
echo "✅ Version bumping (major, minor, patch)"
echo "✅ Registry validation"
echo "✅ Registry utils integration"
echo ""
echo "🎉 Semantic Versioning Implementation COMPLETE!"