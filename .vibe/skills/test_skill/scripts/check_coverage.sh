#!/bin/bash
# Coverage Checker
# Verifies test coverage meets minimum thresholds

echo "📊 Checking test coverage..."

# Run tests with coverage
pytest tests/ --cov=backend/src --cov=frontend/src --cov-report=term-missing

COVERAGE_EXIT_CODE=$?

if [ $COVERAGE_EXIT_CODE -eq 0 ]; then
    echo "✅ Coverage check passed"
    exit 0
else
    echo "❌ Coverage check failed or no tests found"
    exit 1
fi