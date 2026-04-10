# AI Council: System Design Document

## System Document v0.3 - Hybrid Format

**Based on**: Overview Document v1.0
**Created**: 2026-03-27
**Status**: Final - Ready for Review
**Next Step**: Owner approval
**Owner**: system_doc_creator v0.3
**Approval**: Pending owner review

---

## 1. System Overview: How AI Council Works

### 1.1 The Core Concept

AI Council is a **self-hosted system** that simulates conversations with specialized personas to validate ideas, test assumptions, and refine strategies before real-world meetings. The system enables users to:

- **Pitch ideas** to diverse virtual personas and get instant feedback
- **Rehearse conversations** with a mentor who understands their context
- **Stress-test strategies** with challenging perspectives
- **Generate comprehensive reports** documenting all viewpoints

By simulating conversations first, users can identify weak points, anticipate objections, and refine their approach before engaging with real stakeholders.

### 1.2 The Simulation Process

A typical AI Council workflow follows these steps:

**1. Set the Stage**
- Create or select a workspace for your initiative
- Start a new conversation and choose relevant personas
- Example persona selection:
  - *Early Adopter Alex* (innovation focus)
  - *Budget-Conscious Priya* (cost/ROI analysis)
  - *Technical Mentor* (feasibility assessment)
  - *Devil's Advocate* (risk identification)

**2. Have the Conversation**
- Present your idea as you would in a real meeting
- Each persona responds with their unique perspective
- Engage in iterative discussion and refinement

**3. Get the Summary**
- System automatically generates key takeaways
- Highlights agreements, disagreements, and action items
- Identifies risks and opportunities

**4. Generate the Report**
- One-click comprehensive Markdown report
- Documents all perspectives, decisions, and rationale
- Includes conversation metadata and context

**5. Continuously Improve**
- Review Agent analyzes conversation quality
- Suggests agent performance improvements
- Recommends prompt refinements for better results

---

## 2. Key System Components Explained

### 2.1 Personas: Your Virtual Advisory Panel

AI Council provides specialized persona panels with distinct expertise:

#### User Research Panel - "Will real users love this?"

- **Early Adopter Alex**: Pushes for innovation and novelty
- **Budget-Conscious Priya**: Focuses on cost, ROI, and value
- **Power User Maya**: Stress-tests technical capabilities
- **Non-Technical Jamie**: Identifies usability issues
- **Privacy-Focused Sam**: Ensures compliance and ethical considerations

#### Senior Management Panel - "Does this align with our strategy?"

- **Vision Keeper**: Ensures mission and values alignment
- **Technical Mentor**: Evaluates architecture and scalability
- **Business Strategist**: Analyzes market positioning
- **Devil's Advocate**: Identifies risks and challenges
- **Process Optimizer**: Suggests workflow improvements

### 2.2 Workspaces and Teams

**Workspace Model**: AI Council uses a workspace/team structure for organization:

- **Workspaces**: Switchable contexts for different projects/initatives
- **Isolation**: Each workspace has its own agents and conversations
- **Switching**: Top navigation dropdown for changing workspaces
- **Structure**: Workspace → Folders → Conversations

**Key Characteristics**:
- Complete context separation between workspaces
- Team-specific agents and conversations
- Flexible organization for different initiatives
- Easy switching via navigation dropdown

### 2.3 The Mentor: Your Personal Guide

The Mentor provides **team-specific, context-aware guidance**:

- **Team-Specific**: Each workspace has its own mentor instance
- **Conversations Integration**: Mentor appears in Conversations page
- **Context-Aware**: Maintains knowledge within workspace boundaries
- **Long-Lived Sessions**: Single ongoing conversation with context management

**Memory Architecture**:
- **Working Memory**: Current session (last 5 messages verbatim)
- **Episodic Memory**: Last 10 conversation summaries
- **Semantic Memory**: Team context and knowledge documents

### 2.4 Context Management

Intelligent handling of LLM context limitations:

- **Automatic Summarization**: When conversations exceed token limits
- **Targeted Summaries**: User-requested topic-specific summaries
- **Context Preservation**: Critical information carried forward
- **Mentor Optimization**: Special context management for mentor sessions

---

## 3. How Users Work with AI Council

### 3.1 Typical User Journey: Validating a New Feature

**Sarah's Story**: Product manager validating a document collaboration feature

**Day 1 - Initial Validation**
- Creates "DocCollab" workspace
- Starts conversation with Alex, Maya, and Technical Mentor
- Gets feedback on innovation, technical depth, and feasibility
- System summarizes: "Team excited but needs performance work"

**Day 2 - Business Analysis**
- New conversation with Priya, Business Strategist, Devil's Advocate
- Refines concept based on cost and market feedback
- Generates "DocCollab Business Analysis" report

**Day 3 - Mentor Session**
- Gets personalized advice from workspace-specific mentor
- Mentor suggests focusing on collaboration over AI features
- Recommends prototyping approach for performance concerns

**Day 4 - Review and Presentation**
- Reviews Review Agent's analysis of agent performance
- Adjusts agent prompts based on suggestions
- Exports comprehensive report for stakeholder meeting

### 3.2 The User Interface

**Navigation Structure**

```text
Top Navigation: [Workspace Switcher] [Current Team] [User Menu]
├── Workspace A
│   ├── Folders
│   │   ├── Folder 1
│   │   │   ├── Conversation 1
│   │   │   ├── Conversation 2
│   │   │   └── Conversation 3
│   │   └── Folder 2
│   │       ├── Conversation A
│   │       └── Conversation B
│   ├── Documents
│   └── Agents
│       ├── Agent 1 [Profile] [Config] [Recommendations] [Usage]
│       ├── Agent 2 [Profile] [Config] [Recommendations] [Usage]
│       └── Mentor [Profile] [Config] [Recommendations] [Usage]
└── Workspace B
    ├── Folders
    ├── Documents
    └── Agents
```

**Main Panels**:
- **Left Sidebar**: Workspace navigation, folders, conversations
- **Main Panel**: Conversation view with Markdown rendering
- **Right Sidebar**: Active agents and management controls

### 3.3 Real-World Usage Patterns

**Quick Validation** (5-10 minutes)
- Rapid feedback with 2-3 key personas
- Summary copied as Markdown for documentation

**Deep Dive** (Multiple sessions)
- Different persona combinations for different aspects
- Comprehensive report generation
- Review Agent analysis for optimization

**Mentor Guidance** (Ongoing)
- Context-aware advice based on workspace history
- Knowledge extraction and reuse
- Continuity across sessions

**Post-Mortem Analysis**
- Review completed conversations
- Analyze agent performance
- Optimize prompts and involvement rules

---

## 4. Behind the Scenes

### 4.1 Workspace Management

**Orchestrator**: Intelligent workspace and agent coordination:
- Suggests relevant agents based on conversation topics
- Manages context across workspace boundaries
- Handles agent hand-offs between conversations
- Flags gaps when important viewpoints are missing

### 4.2 Review Agent: Continuous Improvement

**Team-Scoped Nightly Processing**:
- Analyzes all conversations since last run
- Processes agent performance within workspace context
- Generates agent-specific improvement suggestions
- Maintains complete conversation history for analysis

**Finding Presentation**:
- Expandable recommendations section in each agent's profile
- Persistent findings that evolve nightly
- Full evidence and examples available
- Actionable suggestions with preview capability

### 4.3 Data Management

**Storage Architecture**:
- **PostgreSQL**: Structured data (workspaces, conversations, agents)
- **Filesystem**: Reports and documents (`/reports/{workspace_id}/{conversation_id}/`)
- **Memory**: Three-layer mentor memory system per workspace

**Privacy Measures**:
- Complete workspace isolation
- User-specific data segregation
- Restrictive permissions on storage locations

---

## 5. Key Benefits

### 5.1 For Product Managers
- Validate ideas quickly before development
- Identify risks through diverse perspectives
- Create comprehensive documentation automatically
- Prepare thoroughly for stakeholder meetings

### 5.2 For Developers
- Get early feedback on technical approaches
- Identify edge cases through stress-testing
- Document technical decisions automatically
- Improve architecture with expert guidance

### 5.3 For Business Leaders
- Assess strategic alignment
- Evaluate business viability
- Prepare for tough questions
- Generate executive-ready reports

### 5.4 For UX Designers
- Test usability with different user types
- Identify pain points systematically
- Validate designs with diverse personas
- Document user feedback comprehensively

---

## 6. System Requirements

### 6.1 Core Functional Requirements

**FR-001: Workspace Management**
- Support multiple switchable workspaces per user
- Isolate agents and conversations by workspace
- Enable workspace creation, renaming, and deletion
- Provide workspace switching via navigation

**FR-002: Team-Specific Agents**
- Each workspace maintains its own agent set
- Agents cannot be shared between workspaces (v1)
- Mentor instances are workspace-specific
- Agent configuration scoped to workspace

**FR-003: Context-Aware Mentoring**
- Three-layer memory system per workspace
- Working memory for current session
- Episodic memory for recent conversations
- Semantic memory for workspace knowledge

**FR-004: Review Agent Processing**
- Nightly batch processing of workspace conversations
- Team-scoped analysis and suggestions
- Persistent findings with nightly updates
- Agent-specific improvement recommendations

### 6.2 User Experience Requirements

**UX-001: Workspace Navigation**
- Clear workspace switching in top navigation
- Visual indication of current workspace
- Easy access to all workspace components
- Consistent UI across all workspaces

**UX-002: Agent Management**
- Per-workspace agent configuration
- Expandable recommendations section
- Clear agent performance indicators
- Easy apply/dismiss of suggestions

**UX-003: Mentor Integration**
- Mentor in Conversations page
- Visual distinction from regular conversations
- Context-aware advice display
- Continuous session management

### 6.3 Performance Guidelines

**PR-001: Responsive Experience**
- UI interactions should feel immediate (< 1s perceived)
- Agent responses should be reasonable for local LLM (< 5s typical)
- No noticeable lag during navigation and data loading
- Smooth workspace switching and context loading

**PR-002: Efficient Resource Usage**
- Memory usage appropriate for single-user application
- CPU usage shouldn't cripple the system during operation
- Resource usage scales linearly with workload
- Efficient context window management

**PR-003: Practical Scalability**
- Support typical single-user workloads without degradation
- Handle multiple workspaces and agents efficiently
- Maintain performance with reasonable conversation history
- Scale appropriately for personal knowledge management use

### 6.4 User Stories

**US-001: Validate Product Idea**
"As a product manager, I want to simulate conversations with diverse personas about my feature idea within a dedicated workspace so I can identify potential issues before presenting to stakeholders."

**US-002: Get Workspace-Specific Advice**
"As a developer, I want to discuss my architectural approach with the Technical Mentor in my current workspace so I can get context-aware guidance tailored to this project."

**US-003: Review Agent Suggestions**
"As a user, I want to see Review Agent findings in each agent's recommendations section so I can continuously improve my workspace's agent performance."

**US-004: Switch Workspaces Easily**
"As a user working on multiple projects, I want to switch between workspaces quickly so I can maintain separate contexts for different initiatives."

---

## 7. Implementation Details

### 7.1 Workspace System

**Structure**:

```text
User Account
├── Workspace 1 (e.g., "API Redesign")
│   ├── Agents (workspace-specific)
│   ├── Folders
│   │   └── Conversations
│   └── Documents
│
├── Workspace 2 (e.g., "Pricing Model")
│   ├── Agents (different set)
│   ├── Folders
│   │   └── Conversations
│   └── Documents
│
└── Workspace 3 (e.g., "UX Research")
    ├── Agents (different set)
    ├── Folders
    │   └── Conversations
    └── Documents
```

**Switching Mechanism**:
- Top navigation dropdown shows all workspaces
- Current workspace highlighted
- Switching changes entire context (agents, conversations, documents)
- Automatic mentor switching when changing workspaces

### 7.2 Mentor Memory Architecture

**Three-Layer System**:

1. **Working Memory (Volatile)**
   - Current session context (last 5 messages verbatim)
   - Active reasoning scratchpad
   - ~3000 token limit with automatic management

2. **Episodic Memory (Short-term)**
   - Summaries of last 10 workspace conversations
   - Key decisions and outcomes extracted
   - 30-day automatic decay

3. **Semantic Memory (Long-term)**
   - Workspace context and goals
   - User profile specific to this workspace
   - Learned strategies and best practices

**Context Window Optimization**:
- Dynamic memory injection based on relevance
- Context-aware compression of older conversations
- 20% reserved for reasoning
- Continuous quality monitoring

### 7.3 Review Agent Functionality

**Nightly Processing**:

```text
1. Analyze all conversations in workspace since last run
2. Evaluate each agent's performance
3. Generate findings with evidence
4. Update existing findings or create new ones
5. Store in agent-specific recommendations
```

**Finding Evolution**:
- New findings marked as "New"
- Updated findings marked as "Updated" with new evidence
- Resolved findings moved to history
- Complete audit trail maintained

### 7.4 Agent Recommendations UI

**Expandable Section Design**:

```text
Agent Profile Page
└── Recommendations Tab
    ├── Performance Summary
    ├── Active Findings (persistent)
    │   ├── Finding #1 (New/Updated)
    │   │   ├── Status and evidence
    │   │   ├── Suggestion with preview
    │   │   └── Actions (Apply/Dismiss)
    │   └── Finding #2
    │       ├── Evidence examples
    │       ├── Impact analysis
    │       └── Action buttons
    └── Findings History
        ├── Applied findings
        └── Dismissed findings
```

**Migration Path**:
- v1.0: Expandable section in agent profile
- v1.1: Extract to dedicated tab if needed
- Same backend logic for both approaches

---

## 8. Document Validation

### 8.1 Completion Checklist

**Structural Completeness**:
- [x] Workspace/team model fully defined
- [x] Mentor functionality with memory architecture
- [x] Review agent with team scoping
- [x] Agent recommendations UI approach
- [x] Performance guidelines established
- [x] All user stories updated

**Consistency Verification**:
- [x] Terminology standardized throughout
- [x] Structural relationships clarified
- [x] No conflicting descriptions
- [x] All references validated

**Quality Gates**:
- [x] Self-review completed
- [x] All ambiguities resolved
- [x] Ready for architecture creation
- [x] Final validation passed

### 8.2 Document Status

**Current Status**: 🟡 Final - Ready for Owner Approval
**Version**: v0.3
**Date**: 2026-03-27
**Next Step**: Owner review and approval

**Validation Summary**:
✅ All decisions from open_questions_v2.md incorporated
✅ All structural inconsistencies resolved
✅ All terminology standardized
✅ Complete and self-consistent
✅ Ready for implementation (pending approval)

---

## 9. Change Log

| Version | Date | Changes | Author |
| --------- | ------ | --------- | -------- |
| v0.1 | 2026-03-23 | Initial hybrid document | system_doc_creator |
| v0.2 | 2026-03-26 | Incorporated initial decisions | system_doc_creator |
| v0.3 | 2026-03-27 | Complete v0.3: Workspace model, enhanced mentor memory, team-scoped reviews, pragmatic implementation approach | system_doc_creator |

---

## 10. Questions for Further Review

*No questions remaining - all issues resolved during comprehensive review process*

**Document Status**: ✅ **FINAL - No ambiguities, ready for implementation (pending owner approval)**
