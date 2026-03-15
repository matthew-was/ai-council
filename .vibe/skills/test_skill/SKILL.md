---
name: test-skill
description: Runs Python tests with coverage analysis. Executes pytest with coverage on the tests/ directory and measures code coverage. Use when you need to validate functionality, check test coverage, or before pushing code changes to ensure all tests pass.
license: MIT
metadata:
  author: ai-council
  version: "1.0"
---

# Test Skill

## Purpose
This skill runs Python tests and measures code coverage to ensure functionality and test completeness.

## When to Use
- Before pushing code changes
- During CI/CD pipeline execution
- When requested to validate functionality
- As part of pre-push hooks
- To ensure test coverage meets project standards

## How It Works
1. Runs pytest on the tests/ directory
2. Measures code coverage using pytest-cov
3. Reports test results and coverage statistics
4. Returns success (0) if all tests pass, failure (1) if any tests fail

## Requirements
- pytest installed
- pytest-cov installed
- Python test files in tests/ directory

## Usage

```bash
.vibe/skills/test_skill/scripts/run_tests.sh
```

## Output
- Success: "✅ All tests passed" followed by coverage report
- Failure: "❌ Some tests failed" followed by test failure details
- Coverage report shows percentage of code covered by tests

## Common Issues
- Missing test files
- Import errors in test files
- Assertion failures
- Low test coverage
- Missing test dependencies

## Configuration
The skill uses pytest configuration. Common configuration options include:
- Test discovery patterns
- Coverage thresholds
- Test markers and fixtures
- Plugin configurations
