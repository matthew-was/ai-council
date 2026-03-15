#!/bin/bash
# Test Runner
# Executes pytest with coverage

echo "🧪 Running tests..."

# Run pytest with coverage
pytest tests/ --cov=src --cov-report=term-missing

TEST_EXIT_CODE=$?

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo "✅ All tests passed"
    exit 0
else
    echo "❌ Some tests failed"
    exit 1
fi