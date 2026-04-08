# AI Council: Open Questions for Resolution v2.0

## Status: Draft - Awaiting Resolution
**Created**: 2026-03-26
**Based on**: System Document v0.2 Internal Review
**Purpose**: Consolidate all unresolved questions and consistency issues identified during document review
**Next Step**: Systematic review and resolution of each question

---

## 1. Terminology and Structural Questions

### 1.1 Team vs Folder Organization

**Question**: Should teams be the primary containers with folders inside, or should folders be the primary containers with team scoping?

**Current State**:
- Section 2.3: "Teams act as primary containers" with folders inside
- Section 7.3: "Single-level folders within 'Conversations' page, team-scoped"
- Overview document: Mentions "teams" as organizational units but doesn't specify hierarchy

**Options**:

**Option A: Teams as Primary Containers (Current Section 2.3)**

```mermaid
Teams (Primary)
└── Folders
    └── Conversations

```text

**Benefits**:
- Matches enterprise workflows where teams own projects
- Aligns with agent sharing being "team-scoped"
- Clear ownership model
**Drawbacks**:
- May be overkill for single-user local use
- Requires team management UI

**Option B: Folders as Primary Containers (Current Section 7.3)**

```mermaid
Folders (Primary, team-scoped)
└── Conversations
```text

**Benefits**:
- Simpler for single-user scenarios
- Less management overhead
- Matches traditional file organization
**Drawbacks**:
- Less clear team ownership
- May not scale well for multi-user scenarios

**Option C: Workspace/Team Model (User Decision)**

```

User Account
├── Team/Workspace Switcher (Top Navigation)
│   ├── Team 1 (Workspace 1)
│   │   ├── Agents (Team-specific, not shared)
│   │   └── Conversations View
│   │       ├── Folders (Primary containers)
│   │       │   └── Conversations
│   │       └── Ungrouped Conversations
│   │
│   ├── Team 2 (Workspace 2)
│   │   ├── Agents (Different set, team-specific)
│   │   └── Conversations View
│   │       ├── Folders
│   │       │   └── Conversations
│   │       └── Ungrouped Conversations
│   │
│   └── Team 3 (Workspace 3)
│       ├── Agents (Different set, team-specific)
│       └── Conversations View
│           ├── Folders
│           │   └── Conversations
│           └── Ungrouped Conversations
│
└── Account Settings
    └── Team/Workspace Management
        ├── Create New Team
        ├── Rename Team
        ├── Delete Team
        └── Switch Team

```text

**Benefits**:
- Matches user's described workflow of multiple workspaces
- Supports agent isolation between workspaces
- Aligns with existing UI description (team switching in top navigation)
- Provides clear workspace switching
- Simpler for single-user local use
- Scales well for multi-context scenarios
- Each workspace has its own agent set and conversation space

**Drawbacks**:
- Requires updating terminology from "teams" to "workspaces/teams"
- Need to clarify workspace management in account settings

**Reference**:
- open_questions.md Section 4.1: "Single-level folders within 'Conversations' page, team-scoped"
- system_document.md Section 2.3: Teams as primary containers
- system_document.md Section 3.2: Team switching in top navigation

**Decision**: **Option C (Workspace/Team Model)**
- **Structure**: Workspaces/Teams (switchable via top navigation) → Folders → Conversations
- **Key Characteristics**:
  1. Teams = Workspaces: Single user can create multiple workspaces for different projects/contexts
  2. Team-Specific Agents: Each workspace has its own agent set (not shared between workspaces)
  3. Team Switching: Via top navigation dropdown
  4. Folder Organization: Primary organization within each workspace
  5. Conversation Structure: Folders → Conversations hierarchy
- **Rationale**: Matches user's vision of workspace-based organization with isolated agent sets, aligns with existing UI patterns, and provides the flexibility needed for different project contexts
- **Date**: 2026-03-26
- **Decided By**: User

**Implementation Requirements**:
- Update Section 2.3 to describe workspaces/teams as switchable contexts
- Clarify that "team-scoped agents" means workspace-specific agents
- Keep folder/conversation hierarchy as described
- Add workspace management to account settings
- Update terminology consistently throughout document (teams = workspaces)

---

### 1.2 Mentor Scope and Organization

**Question**: Should mentors be user-wide (one mentor for all teams) or team-specific (separate mentor per team)?

**Current State**:
- Section 2.2: "The Mentor operates as a single ongoing conversation" (suggests user-wide)
- Section 7.4: "Single ongoing session per team" (suggests team-specific)
- Overview document: "Mentor Agent replies with personalized suggestions"

**Options**:

**Option A: User-Wide Mentor (Single Instance)**

```

User
└── Mentor (shared across all teams)

```text

**Benefits**:
- Simpler implementation
- Consistent advice across all contexts
- Matches "personal advisor" concept
**Drawbacks**:
- May mix contexts between different projects
- Less specialized per team

**Option B: Team-Specific Mentors (Multiple Instances)**

```

User
├── Team 1
│   └── Mentor (team-specific, in Conversations page)
├── Team 2
│   └── Mentor (team-specific, in Conversations page)
└── Team 3
    └── Mentor (team-specific, in Conversations page)

```text

**Benefits**:
- Context remains project-specific
- Can specialize per team
- Better knowledge isolation
- Mentor has correct context for advice
- Integrated with team's conversation space
**Drawbacks**:
- More complex implementation
- User needs to switch mentors when switching teams
- Requires mentor state management per team

**Option C: Hybrid Approach (User Decision)**

```

User
├── Global Mentor (shared across teams)
│   └── High-level personal advice
│
├── Team 1
│   └── Team Mentor (team-specific context)
├── Team 2
│   └── Team Mentor (team-specific context)
└── Team 3
    └── Team Mentor (team-specific context)

```text

**Benefits**:
- Both personal and contextual advice
- Global mentor maintains personal history
- Team mentors provide project-specific guidance
**Drawbacks**:
- Most complex implementation
- User needs to choose which mentor to use

**Reference**:
- open_questions.md Section 6.1: "Team-Specific mentor with viewable, document-based memory"
- system_document.md Section 7.4: "Each team has separate mentor instance"

**Decision**: **Option B (Team-Specific Mentors with Conversations Integration)**
- **Structure**: Each team has its own mentor instance within the Conversations page
- **Key Characteristics**:
  1. **Team-Specific**: Each workspace/team has its own mentor
  2. **Context-Specific**: Mentor operates within the team's context for optimal advice
  3. **Conversations Integration**: Mentor lives in the Conversations page alongside other conversations
  4. **Automatic Switching**: When user switches teams, they automatically get that team's mentor
  5. **Isolated Knowledge**: Each mentor maintains team-specific knowledge and conversation history
- **Rationale**: Ensures mentor has the right context for giving the best advice, aligns with the workspace isolation model decided in 1.1, provides project-specific guidance while maintaining the mentor's personalized approach within each context
- **UI Integration**: Mentor appears as a special conversation type in the Conversations view, visually distinct but part of the same hierarchy
- **Date**: 2026-03-26
- **Decided By**: User

**Implementation Requirements**:
- Update Section 2.2 to describe team-specific mentors
- Modify Section 3.2 UI description to show mentor in Conversations page
- Ensure mentor state is properly scoped to teams
- Design visual distinction for mentor conversations
- Implement automatic mentor switching when changing teams
- Update Section 7.4 with conversations integration details

---

## 2. Functional and Timing Questions

### 2.1 Review Agent Processing Timing

**Question**: Should review agent analysis happen immediately after conversations or as nightly batch processing?

**Current State**:
- Section 4.2: "After each conversation ends, the Review Agent:" (immediate)
- Section 7.5: "Nightly batch processing" (batched)
- Overview document: Doesn't specify timing

**Options**:

**Option A: Immediate Processing (After Each Conversation)**
**Benefits**:
- Instant feedback for users
- More responsive system
- Better for active learning
**Drawbacks**:
- Higher resource usage
- May slow down conversation completion
- More complex implementation

**Option B: Nightly Batch Processing**
**Benefits**:
- Lower resource impact
- Can process multiple conversations together
- Simpler implementation
- Focused on long-term improvement
- Asynchronous operation doesn't impact user experience
**Drawbacks**:
- Delayed feedback (up to 24h)
- Less responsive for users
- May miss time-sensitive insights

**Option C: Hybrid Approach**
- Immediate lightweight analysis
- Nightly deep analysis
**Benefits**:
- Balances responsiveness and resource usage
- Provides both quick insights and comprehensive analysis
**Drawbacks**:
- Most complex implementation
- Need to define what constitutes "lightweight" vs "deep"

**Reference**:
- open_questions.md Section 7.1: "Nightly batch processing"
- system_document.md Section 4.2: "After each conversation ends"

**Decision**: **Option B (Nightly Batch Processing - Team Scoped)**
- **Timing**: Nightly asynchronous batch processing
- **Scope**: Team/workspace-scoped, aware of all agents within a team
- **Focus**: Long-term agent improvement rather than immediate feedback
- **Key Characteristics**:
  1. **Asynchronous Operation**: Runs as background task, doesn't impact user experience
  2. **Team-Scoped Analysis**: Processes all conversations within a team/workspace together
  3. **Comprehensive Review**: Analyzes patterns across multiple conversations for deeper insights
  4. **Agent-Specific Findings**: Generates improvement suggestions for each agent in the team
  5. **Batch Efficiency**: Processes all team conversations since last run in single operation
- **Rationale**: Aligns with focus on long-term improvement, avoids adding complexity of immediate processing, respects team/workspace boundaries, asynchronous nature prevents performance impact on main system, simpler implementation allows focusing on quality of analysis rather than real-time constraints
- **Integration Points**:
  - Results visible in team context (Conversations page)
  - Agent-specific suggestions appear when viewing agents
  - Team-level insights available in team settings
  - Notification system for important findings
- **Date**: 2026-03-26
- **Decided By**: User

**Implementation Requirements**:
- Update Section 4.2 to reflect nightly team-scoped processing
- Modify Section 7.5 to emphasize team awareness and long-term focus
- Design notification system for review findings
- Create team-level insights dashboard
- Ensure proper team scoping of review data
- Implement efficient batch processing of team conversations
- Add visual indicators for agents with pending improvements

---

## 3. Implementation and Clarity Questions

### 3.1 Agent Sharing Workflow

**Question**: How should agent sharing work in practice, especially across teams?

**Current State**:
- Section 7.2 describes technical implementation
- No user journey or UI description
- open_questions.md Section 2.2 describes URL-based sharing
- Agents are team-specific (from decision 1.2)
- Workspaces are isolated (from decision 1.1)

**Options Considered**:

**Option A: Intra-User Workspace Sharing**

```

Workflow:
1. User creates agent in Workspace A
2. User clicks "Share Agent" in agent menu
3. System shows sharing dialog with workspace selector
4. User selects target workspace (Workspace B)
5. System creates agent copy in Workspace B with:
   - Same configuration (name, prompt, temperature)
   - New unique ID (agent_<new_8_chars>)
   - Version 1 (clean history)
   - Metadata: "Copied from Workspace A"

```text

**Benefits**: Aligns with workspace model, enables reuse, future-proof
**Drawbacks**: Adds complexity, requires workspace selector UI

**Option B: No Sharing in v1 (Simplest)**
- Disable sharing functionality initially
- Focus on core workspace and agent functionality
- Document as future enhancement

**Option C: File-Based Export/Import**
- Export agents as JSON files
- Import files into other workspaces
- More manual but flexible

**Decision**: **Option B (No Sharing in v1)**
- **Approach**: Disable agent sharing functionality for version 1
- **Rationale**:
  1. **Focus on Core**: Prioritize workspace isolation and team-specific agents
  2. **Simplicity**: Avoid adding complexity to initial implementation
  3. **Future-Proof**: Document Option A as planned enhancement for future versions
  4. **Alignment**: Matches single-user, local-focused v1 scope
- **Future Consideration**: Option A (Intra-User Workspace Sharing) identified as valuable future refinement
- **Implementation**:
  - Remove sharing UI elements from agent menus
  - Disable sharing endpoints in API
  - Document absence in limitations section
  - Add future enhancement note in roadmap
- **Date**: 2026-03-26
- **Decided By**: User

**Future Enhancement Plan**:

```

v2.0 Feature: Intra-User Workspace Sharing
- Implement Option A workflow
- Add workspace selector to sharing dialog
- Create agent copying mechanism
- Add visual indicators for copied agents
- Maintain agent isolation while enabling reuse

```text

**Reference**:
- open_questions.md Section 2.2: Agent sharing implementation details
- system_document.md Section 7.2: Technical sharing description
- Decision 1.1: Workspace/Team Model
- Decision 1.2: Team-Specific Mentors

---

### 3.2 Performance Metrics Definition

**Question**: Should we define specific performance targets or keep them as "good" general guidelines?

**Current State**:
- Section 6.3 lists targets but calls them "good" rather than specific
- Section 10.2 identifies this as a gap
- open_questions.md Section 10.1 suggests these are targets, not hard requirements
- System is first-pass, single-user, personal tool

**Options**:

**Option A: Define Specific Metrics**

```

Response Times:
- Agent responses: ≤ 2.5s (90th percentile)
- UI navigation: ≤ 300ms (95th percentile)
- Data loading: ≤ 800ms (95th percentile)

Resource Usage:
- Memory: ≤ 1.8GB average, ≤ 2.5GB peak
- CPU: ≤ 40% average, ≤ 75% peak
- Disk: ≤ 50MB initial, ≤ 8MB per 100 conversations

```text

**Benefits**:
- Clear success criteria
- Measurable quality standards
- Better for performance testing
**Drawbacks**:
- May be too optimistic for local LLMs
- Could limit implementation flexibility
- Overhead for personal project

**Option B: Keep as General Guidelines**

```

Response Times:
- Agent responses: < 3 seconds (target)
- UI navigation: < 500ms (target)
- Data loading: < 1 second (target)

```text

**Benefits**:
- More implementation flexibility
- Recognizes local LLM variability
- Easier to achieve
- Appropriate for personal tool
**Drawbacks**:
- Harder to measure success
- Less concrete for developers

**Option C: No Explicit Metrics (User Decision)**
- Remove specific performance targets entirely
- Focus on qualitative user experience
- Optimize based on personal testing and perception
- Document as "responsive single-user experience"

**Benefits**:
- Maximum flexibility for personal project
- No artificial constraints
- Aligns with first-pass, single-user nature
- Avoids premature optimization
**Drawbacks**:
- No clear targets for optimization
- Hard to measure objectively

**Reference**:
- open_questions.md Section 10.1: "Good performance targets for responsive local experience"
- system_document.md Section 6.3: Current performance requirements
- User context: First-pass system for personal use only

**Decision**: **Option C (No Explicit Metrics for v1)**
- **Approach**: Remove specific performance targets for version 1
- **Rationale**:
  1. **Personal Project**: System is first-pass and will only be used by developer
  2. **Flexibility**: Avoid artificial constraints during initial implementation
  3. **Practicality**: Performance optimization can be added later if needed
  4. **Focus**: Prioritize functionality and user experience over metrics
  5. **Future-Proof**: Can add metrics in later version if scaling becomes issue
- **Implementation**:
  - Replace specific metrics in Section 6.3 with qualitative descriptions
  - Focus on "responsive single-user experience" as goal
  - Document performance considerations without hard targets
  - Add note about future metric addition if needed
  - Optimize based on personal testing and perception
- **Future Consideration**: Option A or B can be added in future versions if:
  - System usage expands beyond single user
  - Performance issues are identified
  - Metrics become useful for optimization
- **Date**: 2026-03-26
- **Decided By**: User

**Updated Performance Section Content**:

```markdown
### 6.3 Performance Guidelines

**PR-001: Responsive User Experience**
- System should feel responsive and smooth during normal usage
- UI interactions should be immediate (< 1s perceived)
- Agent responses should be reasonable for local LLM (< 5s typical)
- No noticeable lag during navigation and data loading

**PR-002: Efficient Resource Usage**
- System should run efficiently on modern hardware
- Memory usage should be reasonable for single-user application
- CPU usage should not cripple the system during normal operation
- Resource usage should scale linearly with workload

**PR-003: Practical Scalability**
- Support typical single-user workloads without degradation
- Handle multiple workspaces and agents efficiently
- Maintain performance with reasonable conversation history
- Scale appropriately for personal knowledge management use case

**Note**: As a first-pass personal system, specific metrics are not defined. Performance will be optimized based on actual usage patterns and personal testing. Metrics may be added in future versions if the system expands beyond single-user scope.

```text

---

## 4. Technical Clarification Questions

### 4.1 Mentor Memory Architecture

**Question**: How exactly should the mentor's memory architecture work, especially the relationship between conversation memory and knowledge documents?

**Current State**:
- Section 7.4: "Memory architecture with conversation memory (last 10 conversations) and knowledge documents"
- No diagram or detailed explanation
- Unclear how these components interact
- Needs to align with team-specific mentor decision (1.2)

**Options Considered**:

**Option A: Basic Dual-Layer System**
- Simple conversation history + knowledge documents
- Minimal implementation complexity
- Less intelligent memory management

**Option B: Enhanced Dual-Layer Memory System (Recommended)**

```

Mentor Memory Architecture (Team-Specific):
├── Working Memory (Volatile - Current Session)
│   ├── Last 5 messages (verbatim, ~3000 token limit)
│   ├── Active conversation state
│   └── Current reasoning scratchpad
│
├── Episodic Memory (Short-term - Recent History)
│   ├── Summaries of last 10 conversations
│   ├── Key decisions and outcomes extracted
│   ├── Timestamped and team-scoped
│   └── Automatic decay after 30 days
│
└── Semantic Memory (Long-term - Knowledge Documents)
    ├── Team Context (Structured)
    │   ├── Team goals and objectives
    │   ├── Current projects and challenges
    │   └── Domain-specific knowledge
    │
    ├── User Profile (Team-Specific)
    │   ├── Role in this team
    │   ├── Expertise relevant to team
    │   └── Preferences for this context
    │
    └── Learned Knowledge (Evolving)
        ├── Successful strategies in this team
        ├── Common pitfalls to avoid
        └── Agent-specific improvements

```text

**Memory Flow with Context Management**:

```

1. User interacts with mentor in team context
2. Add to Working Memory (verbatim)
3. When approaching token limit (~3000 tokens):
   - Summarize oldest messages → Episodic Memory
   - Extract key insights → Semantic Memory
   - Keep last 5 messages verbatim in Working Memory
4. Nightly Review Agent (team-scoped):
   - Analyzes conversation patterns across team
   - Updates Semantic Memory with new insights
   - Flags outdated or incorrect information
   - Prunes stale Episodic Memory (>30 days)
   - Suggests knowledge document improvements

```text

**Context Window Optimization**:
- **Retrieval**: Only inject relevant memories (not all available)
- **Compression**: Summarize old conversations (don't truncate)
- **Filtering**: Score memories by recency + relevance + importance
- **Reserve Space**: Keep 20% of context window for reasoning
- **Hybrid Retrieval**: Combine semantic similarity with metadata filtering

**Storage Implementation**:
- **Working Memory**: In-memory key-value store (Redis-like)
- **Episodic Memory**: Vector database with TTL (automatic expiration)
- **Semantic Memory**: Hybrid vector + relational storage

**Benefits**:
- Aligns with memory systems best practices
- Respects team-specific mentor decision
- Implements proper memory type separation
- Includes context window management
- Future-proof architecture
- Balances sophistication with implementability

**Drawbacks**:
- More complex than basic conversation history
- Requires careful context window management
- Needs memory decay implementation

**Reference**:
- open_questions.md Section 6.1: Mentor memory details
- system_document.md Section 7.4: Current memory description
- Decision 1.2: Team-Specific Mentors with Conversations Integration
- [7 Steps to Mastering Memory in Agentic AI Systems - MachineLearningMastery.com](https://machinelearningmastery.com/7-steps-to-mastering-memory-in-agentic-ai-systems/) (Comprehensive memory systems design guide)

**Decision**: **Option B (Enhanced Dual-Layer Memory System)**
- **Approach**: Implement three-tier memory architecture (Working, Episodic, Semantic) with context-aware management
- **Rationale**:
  1. **Best Practices**: Follows established memory systems design patterns
  2. **Team Alignment**: Respects team-specific mentor decision and workspace model
  3. **Context Management**: Properly handles scarce context window resource
  4. **Future-Proof**: Can evolve with system needs
  5. **Practical**: Balances sophistication with v1 implementability
- **Implementation Requirements**:
  - Update Section 7.4 with detailed architecture diagram
  - Implement three memory layers with proper scoping
  - Design context window management system
  - Create memory decay and pruning mechanisms
  - Add memory viewer UI for transparency
  - Implement Review Agent memory analysis
  - Document memory types and their purposes
- **Future Enhancements**:
  - Add procedural memory layer for learned behaviors
  - Implement memory importance scoring
  - Add user-editable memory corrections
  - Create memory health dashboard
- **Date**: 2026-03-26
- **Decided By**: User

**Diagram for Section 7.4**:

```mermaid
graph TD
    A[User Interaction] --> B[Working Memory]
    B -->|exceeds limit| C[Summarize to Episodic]
    B -->|key insights| D[Extract to Semantic]
    C --> E[Episodic Memory: Last 10 Conversations]
    D --> F[Semantic Memory: Team Knowledge]
    E -->|>30 days| G[Automatic Pruning]
    F -->|nightly| H[Review Agent Analysis]
    H -->|updates| F
    H -->|flags stale| E
    B -->|current| I[Context Window]
    E -->|relevant| I
    F -->|filtered| I

```text

**Updated Section 7.4 Content**:

```markdown
### 7.4 Mentor Functionality - Enhanced Memory Architecture

**Three-Layer Memory System**:

1. **Working Memory (Volatile)**
   - Current session context (last 5 messages verbatim)
   - Active reasoning scratchpad
   - Team-scoped and conversation-specific
   - Automatic management when approaching token limits

2. **Episodic Memory (Short-term)**
   - Summaries of last 10 team conversations
   - Key decisions and outcomes extracted
   - Timestamped with automatic 30-day decay
   - Vector storage for semantic retrieval

3. **Semantic Memory (Long-term)**
   - Team context and domain knowledge
   - User profile specific to this team
   - Learned strategies and best practices
   - Hybrid vector + relational storage

**Context Window Management**:
- Dynamic memory injection based on relevance
- Context-aware compression of older conversations
- Reserved reasoning space (20% of window)
- Continuous memory quality monitoring

**Memory Lifecycle**:
- Working → Episodic (when context full)
- Working → Semantic (key insights extraction)
- Episodic → Pruned (after 30 days)
- Semantic → Updated (nightly by Review Agent)

```text

---

### 4.2 Review Agent Findings Presentation

**Question**: How should review agent findings be presented to users in the UI?

**Current State**:
- Section 7.5 shows technical JSON structure
- No UI description or mockups
- Unclear how users interact with findings
- Agents are team-scoped with per-team pages
- Review agent runs nightly batch processing

**Options Considered**:

**Option A: Inline Notifications (Generic)**
- Pop-up notifications after conversations
- Limited context and persistence
- Not team-specific

**Option B: Dedicated Review Center (Complex)**
- Separate tab for all review findings
- Historical trend analysis
- Overkill for v1

**Option C: Agent-Specific Recommendations Tab (User Decision)**

```markdown
**Presentation**: Integrated into per-team Agents page
**Location**: Each agent has its own "Recommendations" tab
**Behavior**: Findings persist and evolve nightly until actioned

```text

**UI Workflow**:

```

1. User navigates to Team → Agents page
2. User selects specific agent (e.g., "Technical Mentor")
3. User clicks "Recommendations" tab
4. System shows accumulated findings:

[Agent Page: Technical Mentor]
[Profile] [Configuration] [Recommendations] [Usage]

[Recommendations Tab - 3 Pending]
┌─────────────────────────────────────────────┐
│ 📊 Performance Analysis (Last 7 Days)        │
├─────────────────────────────────────────────┤
│                                             │
│ 📈 Strengths:                                │
│ • Relevance: 8.5/10 ✓                       │
│ • Engagement: 7.8/10 ✓                       │
│                                             │
│ ⚠️  Improvement Opportunities:               │
│                                             │
│ 1. Role Adherence (March 24-26)             │
│    "Frequently discussed business topics"   │
│    [View 3 Examples +]                      │
│    [Apply Suggested Fix]                     │
│    Suggested prompt addition:                │
│    "When business topics arise, defer to"   │
│    "Business Strategist agent."              │
│                                             │
│ 2. Missed Opportunities (March 25)          │
│    "Could have addressed performance"       │
│    "concerns earlier in API discussion"     │
│    [View Conversation Context]               │
│    [Add to Knowledge Documents]             │
│                                             │
│ 3. Context Utilization (March 26)            │
│    "Underutilized in performance"          │
│    "discussions - suggest higher"           │
│    "involvement priority"                   │
│    [Adjust Involvement Rules]               │
│                                             │
└─────────────────────────────────────────────┘

[Action Buttons]
[Apply All Suggestions] [Dismiss All]
[Mark as Reviewed] [Download Report]

[Finding History]
├── March 25: 2 findings (1 applied, 1 dismissed)
├── March 24: 1 finding (applied)
└── March 23: No findings

```text

**Finding Evolution**:

```

Nightly Processing Logic:
1. Analyze today's conversations for this agent
2. For existing findings:
   - Expand with new examples if pattern continues
   - Modify suggestion if new data changes recommendation
   - Mark as "Updated" with new evidence
3. For resolved findings:
   - Keep in history but dimmed
   - Show "Applied on [date]" or "Dismissed on [date]"
4. For new findings:
   - Add to top of list
   - Mark as "New"

```text

**Key Characteristics**:
1. **Agent-Specific**: Each agent has its own recommendations
2. **Persistent**: Findings remain until explicitly actioned
3. **Evolving**: Nightly updates expand/modify existing findings
4. **Actionable**: Clear suggestions with preview capability
5. **Transparent**: Full evidence and examples available
6. **Team-Scoped**: Only shows findings relevant to current team
7. **Historical**: Shows what was applied/dismissed

**Benefits**:
✅ Perfect alignment with team/agent structure
✅ Persistent but non-intrusive
✅ Encourages regular review without forcing it
✅ Matches nightly processing model
✅ Provides complete context for decisions
✅ Respects user's workflow

**Drawbacks**:
❌ Requires agent-page integration
❌ More UI complexity than pop-ups

**Reference**:
- open_questions.md Section 7.2: Review agent findings structure
- system_document.md Section 4.2: Review agent description
- Decision 1.1: Workspace/Team Model
- Decision 2.1: Nightly Batch Processing
- User's agent-page concept

**Decision**: **Option C (Agent-Specific Recommendations Tab)**
- **Approach**: Implement as expandable section in agent profile for v1.0, with migration path to dedicated tab in future versions
- **Rationale**:
  1. **Perfect Alignment**: Matches user's described agent-page structure exactly
  2. **Team Consistency**: Respects team-scoped agent organization
  3. **User Control**: Findings persist until explicitly addressed
  4. **Nightly Evolution**: Findings grow and adapt with new data
  5. **Action-Oriented**: Clear, previewable suggestions
  6. **Non-Intrusive**: Doesn't interrupt workflow but visible when needed
  7. **Pragmatic**: Balances completeness with implementation practicality
- **Implementation Requirements**:
  - Add "Recommendations" expandable section to agent detail page
  - Design finding cards with expandable evidence sections
  - Implement nightly finding evolution logic
  - Create action preview system
  - Add finding history tracking
  - Design visual indicators for new/updated findings
  - Integrate with agent configuration system
- **Migration Path**:
  - v1.0: Expandable section in agent profile
  - v1.1: Extract to dedicated tab when usage patterns demand
  - Reuse same backend logic for both approaches
- **Date**: 2026-03-27
- **Decided By**: User

---

## 5. Resolution Priority Matrix

| Question | Priority | Section | Resolution Status |
|----------|----------|---------|-------------------|
| 1.1 Team vs Folder Organization | HIGH | 2.3, 7.3 | ✅ DECIDED: Workspace/Team Model |
| 1.2 Mentor Scope | HIGH | 2.2, 7.4 | ✅ DECIDED: Team-Specific Mentors |
| 2.1 Review Agent Timing | HIGH | 4.2, 7.5 | ✅ DECIDED: Nightly Team-Scoped |
| 3.1 Agent Sharing Workflow | MEDIUM | 7.2 | ✅ DECIDED: No Sharing in v1 |
| 3.2 Performance Metrics | MEDIUM | 6.3 | ✅ DECIDED: No Explicit Metrics |
| 4.1 Mentor Memory Architecture | LOW | 7.4 | ✅ DECIDED: Enhanced Dual-Layer |
| 4.2 Review Findings UI | LOW | 7.5 | ✅ DECIDED: Expandable Section |

---

## Next Steps

1. **Review High-Priority Questions (1.1, 1.2, 2.1)**
   - Make decisions on structural organization
   - Resolve fundamental scope questions

2. **Update System Document**
   - Apply chosen options consistently throughout
   - Resolve terminology conflicts
   - Standardize descriptions

3. **Address Medium-Priority Questions (3.1, 3.2)**
   - Add missing user journey examples
   - Define performance metrics

4. **Document Low-Priority Questions (4.1, 4.2)**
   - Add technical diagrams
   - Design UI presentations

5. **Final Review**
   - Verify all inconsistencies resolved
   - Ensure document is architecture-ready

---

## Resolution Tracking

```

[✅] 1.1 Team vs Folder Organization - DECIDED: Workspace/Team Model
[✅] 1.2 Mentor Scope - DECIDED: Team-Specific Mentors with Conversations Integration
[✅] 2.1 Review Agent Timing - DECIDED: Nightly Batch Processing - Team Scoped
[✅] 3.1 Agent Sharing Workflow - DECIDED: No Sharing in v1
[✅] 3.2 Performance Metrics - DECIDED: No Explicit Metrics for v1
[✅] 4.1 Mentor Memory Architecture - DECIDED: Enhanced Dual-Layer Memory System
[✅] 4.2 Review Findings UI - DECIDED: Expandable Section with Tab Migration Path

```text
✅ **All questions resolved** - Document ready for architecture creation.
