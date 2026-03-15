# Persona Template

## 📋 Persona Definition

### Basic Information
- **Name:** [Persona Name]
- **Role:** [Primary Responsibility]
- **Status:** [planned/implemented/testing]
- **Version:** 1.0

## 🎯 Purpose

[Clear, concise description of what this persona does and why it exists. Explain the value it provides to users.]

## 📝 Responsibilities

### Primary Responsibilities
- [Primary responsibility 1]
- [Primary responsibility 2]
- [Primary responsibility 3]

### Secondary Responsibilities
- [Secondary responsibility 1]
- [Secondary responsibility 2]

### Out of Scope
- [Things this persona should NOT do]
- [Boundaries and limitations]

## 🤖 System Prompt

```text
You are an AI persona named [Persona Name], part of the AI Council system.

### Your Role
[Detailed description of the persona's role and responsibilities]

### Guidelines
1. [Guideline 1]
2. [Guideline 2]
3. [Guideline 3]

### Constraints
- Never [prohibited action 1]
- Always [required action 1]
- When unsure, [fallback behavior]

### Response Format
- Use [format requirements]
- Include [required elements]
- Avoid [prohibited elements]

### Example Interactions
User: [Example input]
Persona: [Example response]
```

## 🔧 Configuration

```json
{
  "model": "mistral-7b",
  "temperature": 0.7,
  "max_tokens": 2048,
  "context_window": 4096,
  "stop_sequences": ["\n\n", "User:", "Persona:"],
  "presence_penalty": 0.1,
  "frequency_penalty": 0.1
}
```

## 📊 Performance Metrics

### Success Criteria
- [Metric 1]: [Target value]
- [Metric 2]: [Target value]
- [Metric 3]: [Target value]

### Monitoring
- Response time: <2s
- Context accuracy: >90%
- User satisfaction: >4/5

## 🧪 Testing

### Test Cases
1. **Input:** [Test case 1]
   **Expected:** [Expected response]
   **Actual:** [Actual response]
   **Status:** [pass/fail]

2. **Input:** [Test case 2]
   **Expected:** [Expected response]
   **Actual:** [Actual response]
   **Status:** [pass/fail]

### Edge Cases
- **Empty context:** [Handling strategy]
- **Token limit:** [Handling strategy]
- **Ambiguous input:** [Handling strategy]

## 🔄 Integration

### Dependencies
- [Dependency 1]
- [Dependency 2]

### Interfaces
- **Input:** [Expected input format]
- **Output:** [Expected output format]
- **API:** [API endpoints if applicable]

### Hand-off Protocol
- **To Persona:** [Persona Name]
  - Conditions: [When to hand off]
  - Context: [What to include]
- **From Persona:** [Persona Name]
  - Conditions: [When to receive]
  - Context: [What to expect]

## 📚 Knowledge Base

### Resources
- [Resource 1](url)
- [Resource 2](url)

### Examples
- [Example 1](url)
- [Example 2](url)

## 📝 Development Notes

### Implementation Status
- [ ] Design complete
- [ ] System prompt finalized
- [ ] Basic implementation done
- [ ] Testing complete
- [ ] Integration complete
- [ ] Documentation complete

### Open Questions
1. [Question 1]
2. [Question 2]

### Decisions Made
- Decision 1: [Rationale]
- Decision 2: [Rationale]

## 🔄 Version History

### Version 1.0 (YYYY-MM-DD)
- Initial template created
- Basic structure defined
- Placeholder content added

### Version 1.1 (YYYY-MM-DD)
- [Change 1]
- [Change 2]

## 💡 Usage Examples

### Example 1: Basic Interaction

**User Input:**

```text
[Example user query]
```

**Persona Response:**

```text
[Example persona response]
```

### Example 2: Complex Scenario

**User Input:**

```text
[Complex user query with context]
```

**Persona Response:**

```text
[Detailed persona response with reasoning]
```

## 📋 Checklist

- [ ] Persona design documented
- [ ] System prompt finalized
- [ ] Test cases defined
- [ ] Integration points identified
- [ ] Performance metrics established
- [ ] Documentation complete

---

**Template Version:** 1.0
**Last Updated:** 2026-03-14
**Maintainer:** [Your Name]
