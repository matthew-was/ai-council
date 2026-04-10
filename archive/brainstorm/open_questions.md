# AI Council: Open Questions for Resolution

## Status: Draft - Awaiting User Input
**Created**: 2026-03-23
**Purpose**: Consolidate all unresolved questions that need answers before detailed requirements can be created
**Next Step**: Review and answer each question systematically

---

## 1. Authentication & User Management

### 1.1 User Roles ✅ DECIDED
**Decision**: Design system with role-based architecture but implement only single "User" role initially
**Rationale**: Future-proof for RBAC while keeping initial implementation simple for single-user local use
**Implementation**:
- Create roles infrastructure with extension points
- Start with single "User" role having full permissions
- Document path for adding Admin/Editor/Viewer roles later

### 1.2 Authentication Mechanism ✅ DECIDED
**Decision**: Dual-mode system with local mode primary and OAuth2/OIDC future-ready
**Rationale**: Matches current local use while enabling future cloud deployment
**Implementation**:
- **Local mode**: No authentication, single implicit user (`user_id = "local_user"`)
- **OAuth mode**: Use `sub` claim from OIDC token as `user_id`
- Consistent data model using string `user_id` for both modes
- Design for easy mode switching

### 1.3 User Onboarding ✅ DECIDED
**Decision**: No onboarding process initially
**Rationale**: Reduces complexity, matches technical user profile, can be added retrospectively
**Implementation**:
- Direct access to main interface on first launch
- Empty state with clear "Create your first team" call-to-action
- Contextual help available but non-intrusive
- Store "first launch" flag for potential future onboarding

---

## 2. Agent Customization

### 2.1 Custom Agent Creation ✅ DECIDED
**Decision**: Simplified single-level configuration with temperature in basic parameters
**Rationale**: Matches discussion format needs, removes unnecessary complexity
**Implementation**:
- **Basic Parameters** (all visible):
  - Agent name (required)
  - System prompt (required, with validation)
  - Agent description (optional)
  - Temperature (slider 0.1-0.9, labeled Technical/Balanced/Creative)
  - Team assignment (required)
- No response templates (not needed for discussion format)
- No separate advanced mode (all parameters in single view)
- Versioning: Each save creates new version with timestamp
- Validation: Name, prompt length, temperature range, team assignment

### 2.2 Agent Sharing ✅ DECIDED
**Decision**: Server-based direct copying via agent IDs with URL sharing
**Rationale**: Simpler than document exchange, enables direct preview and import
**Implementation**:
- Each agent gets unique ID (agent_<random_8_chars>)
- Sharing via URL: `/share?agent=agent_abc123xy`
- Import creates new agent with same config, new ID, version 1
- No version history transfer, clean separation from original
- Preview UI shows name, temperature, description before import
- Conflict resolution: auto-rename or manual rename

### 2.3 Agent Templates ✅ DECIDED
**Decision**: No templates initially, but design for easy future addition
**Rationale**: Keep initial system simple while enabling future expansion
**Implementation**:
- Current: Users create all agents from scratch
- Future design hooks:
  - AgentCreator service with template parameter
  - Database schema ready for templates table
  - UI hooks for template browser
  - Public templates = shared agents with template flag
- Future implementation path:
  1. Add templates table
  2. Implement template service
  3. Add template browser UI
  4. Enable public/private flagging

---

## 3. System Integration

### 3.1 API Access ✅ DECIDED
**Decision**: No API for version 1
**Rationale**: Focus on core UI experience, avoid unnecessary complexity for local tool
**Implementation**:
- No API endpoints implemented
- Internal services remain UI-only
- Design system to allow API layer addition later
- Keep business logic separate from UI
- Document potential future API endpoints

### 3.2 Export/Import Capabilities ✅ DECIDED
**Decision**: No export/import capabilities for version 1
**Rationale**: Focus on core functionality, avoid file handling complexity for local tool
**Implementation**:
- No export/import functionality implemented
- Data remains within local system
- Design data models to allow export later if needed
- Document potential JSON export format for future:

  ```json
  {
    "format": "ai-council-export-v1",
    "type": "team/conversation",
    "data": { /* structured content */ }
  }
  ```

### 3.3 Webhook Notifications ✅ DECIDED
**Decision**: No webhook notifications for version 1
**Rationale**: Overkill for local single-user tool, adds unnecessary complexity
**Implementation**:
- No webhook system implemented
- Design event system to allow webhooks later
- Document potential webhook events for future:
  - conversation.created
  - agent.created
  - team.created
  - message.received

---

## 4. Conversation Management

### 4.1 Conversation Organization ✅ DECIDED
**Decision**: Single-level folders within "Conversations" page, team-scoped
**Rationale**: Matches overview document structure while adding team context
**Implementation**:
- **Page Name**: "Conversations" (simple, user-friendly)
- **UI Structure**:

  ```text
  [Top Navigation]
  User Menu ▼  |  Current Team ▼

  [Left Sidebar]
  Folder Name 1 (3)
  ├── Conversation 1
  ├── Conversation 2
  └── Conversation 3

  Folder Name 2 (2)
  ├── Conversation i
  └── Conversation ii

  Uncategorized (2)
  ├── Conversation A
  └── Conversation B
  ```

- **Team Context**: Shown in top navigation, changes via dropdown
- **Folder Operations**: Create, rename, delete folders within current team
- **Conversation Operations**: Move between folders, create in folder or uncategorized
- **No Search**: Keep simple for v1 (can add later if needed)
- **No Tagging**: Keep simple for v1 (can add later if needed)

### 4.2 Conversation History ✅ DECIDED
**Decision**: Configurable time-based retention with user overrides
**Rationale**: Balances storage management with user control
**Implementation**:
- **Default Retention**:
  - Archive after: 1 year (365 days)
  - Delete after: 2 years (730 days)
  - Check frequency: Daily
- **User Controls**:
  - Pin conversations (never auto-archive)
  - Manual archive/delete
  - Per-conversation custom retention
  - Per-team retention overrides
- **Warning System**:
  - Notify 30 days before auto-archive
  - Configurable warning settings
- **Configuration**:
  - Global config: `config/retention.json`
  - Team overrides: `teams/{team_id}/retention.json`
  - UI settings for non-technical users
- **Implementation**:
  - Daily retention job
  - Three-state system: active → archived → deleted
  - Archived conversations: read-only access

---

## 5. Report Generation

### 5.1 Report Templates ✅ DECIDED
**Decision**: No report templates for version 1
**Rationale**: Reports vary by conversation type, templates would limit flexibility
**Implementation**:
- Single auto-generated report format (Markdown)
- Structure based on conversation content

  ```markdown
  # [Title] - Report
  ## Overview
  ## Participants
  ## Key Discussion Points
  ## Perspectives
  ## Outcomes
  ## Metadata
  ```

- User can edit before saving
- Future-proof design for templates:
  - Report generator accepts template parameter
  - Structured data storage enables re-templating

### 5.2 Report Export ✅ DECIDED
**Decision**: Markdown-only export for version 1
**Rationale**: Simple implementation, versatile format, matches developer workflow
**Implementation**:
- Export format: `.md` files
- Structure: Clean Markdown with front matter metadata
- File naming: `reports/{team_id}/{conversation_id}/report.md`
- Versioning: Timestamp suffix for multiple versions
- Future expansion: Design to allow PDF/HTML/Word export later

**Proposed from Overview**: Overview specifies "Reports: Markdown Files" - suggests Markdown format only for v1.

---

## 6. Mentor Functionality

### 6.1 Mentor Personalization ✅ DECIDED
**Decision**: Team-specific mentor with viewable, document-based memory
**Rationale**: Enables effective guidance while maintaining transparency
**Implementation**:
- **Team-Specific**: Each team has separate mentor instance
- **Memory Architecture**:
  - **Conversation Memory**: Last 10 conversations (auto-managed)
    - Topics, challenges, key decisions
    - Auto-pruned to maintain performance
  - **Knowledge Documents**: Persistent structured memory
    - **Types**: insights, lessons, preferences, context
    - **Sources**: user additions, review agent suggestions
    - **Storage**: Database table with team/user scoping
- **Prompt Structure**:

  ```text
  Base: "You are a mentor for [name] in [team]..."
  + Persistent knowledge from documents
  + Recent context from conversations
  ```

- **User Visibility**:
  - Memory viewer UI showing:
    - Recent conversation summaries
    - Knowledge document previews
    - Source attribution
  - Memory editor for manual adjustments
- **Review Agent Integration**:
  - Suggests knowledge document additions
  - Flags outdated/inaccurate memories
  - Helps structure persistent knowledge

**Proposed from Overview**: Overview states "Mentor Agent replies with **personalized suggestions**" and "includes user background and past interactions for personalized guidance."

### 6.2 Mentor Sessions ✅ DECIDED
**Decision**: Single long-running session with inactivity handling
**Rationale**: Matches "personal mentor" concept with seamless continuity
**Implementation**:
- **Session Model**: Single ongoing session per team
- **Context Management**:
  - Automatic summarization when context exceeds ~3000 tokens
  - Keep last 5 messages verbatim, summarize older context
  - Periodic knowledge extraction (every 20 messages)
- **Inactivity Handling**:
  - Timeout: 1 hour of inactivity
  - UI prompt on return:

    ```text
    [Continue where we left off] [Start fresh session]

    Continue: "Where were we with [last topic]?"
    Fresh: "What's on your mind today?"
    ```
  
  - Choice affects Review Agent analysis and memory structuring
- **Memory Structuring**:
  - Review Agent tracks session boundaries
  - Topics organized by natural breaks and user choices
  - Structured memory format:

    ```json
    {
      "topic": "API Design",
      "duration": "2024-03-25 to 2024-03-27",
      "key_points": [...],
      "outcomes": [...]
    }
    ```

- **Resource Monitoring**:
  - Token usage tracking (warn at 3500/4096)
  - Memory usage monitoring
  - Auto-save every 5 minutes

**Proposed from Overview**: Overview specifies "Mentor Conversations: Special UI—no other agents allowed" but doesn't mention time limits or recording.

---

## 7. Review Agent Functionality

### 7.1 Review Analysis ✅ DECIDED
**Decision**: Agent-specific overnight reviews with actionable suggestions
**Rationale**: Continuous improvement through data-driven feedback
**Implementation**:
- **Review Timing**: Nightly batch processing
- **Scope**: All agent activity since last review
- **Metrics Tracked**:
  - Agent Performance: relevance, role adherence, missed opportunities, engagement
  - Conversation Quality: topic coverage, perspective diversity, decision clarity
  - System Health: context usage, token efficiency
- **Review Process**:
  - Analyze conversations since last review
  - Generate findings with evidence
  - Group with existing review or create new
  - Prioritize findings (high/medium/low)
- **Finding Structure**:

  ```json
  {
    "metric": "role_adherence",
    "score": 0.75,
    "issue": "Frequently discussed business topics",
    "evidence": ["Conversation #456", "Conversation #458"],
    "suggestion": "Add to prompt: 'Strictly focus on technical aspects...'",
    "rationale": "Technical Mentor's role is architectural guidance...",
    "priority": "high"
  }
  ```

- **User Interface**:
  - Review suggestions in agent screen
  - Show evidence examples
  - One-click accept/reject
  - Rationale explanation
  - Grouped findings for same agent
- **Workflow**:
  - Review appears after overnight run
  - User accepts/rejects suggestions
  - Accepted changes auto-applied to agent
  - Review remains until dismissed
  - New findings added to existing review
- **Database**: Separate tables for reviews and findings with status tracking

**Proposed from Overview**: Overview describes Review Agent evaluating "agent’s defined purpose" and suggesting "instruction updates" - suggests tracking purpose alignment and missed opportunities.

### 7.2 Agent Performance ✅ DECIDED
**Decision**: Socratic performance analysis with prompt improvement suggestions
**Rationale**: Context-specific improvement through reflective questioning
**Implementation**:
- **Performance Metrics**:
  - Relevance: How on-topic responses are (0-10)
  - Role Adherence: Stayed within defined role (0-10)
  - Missed Opportunities: Instances where agent could have contributed more
  - Engagement: User reply rate to agent (0-10)
  - Value Added: Quality of contributions (0-10)
- **Analysis Approach**:
  - No fixed benchmarks - context-specific evaluation
  - Socratic questioning: "Why did X happen?"
  - Evidence-based findings with specific examples
  - Concrete prompt modification suggestions
- **Finding Structure**:

  ```json
  {
    "question": "Why did agent discuss off-topic subjects X% of the time?",
    "evidence": [
      {"conversation": "#123", "example": "message text", "issue": "description"}
    ],
    "impact": "How this affected conversation quality",
    "suggestion": "Human-readable improvement suggestion",
    "prompt_modification": "Specific text to add to system prompt"
  }
  ```

- **Review Integration**:
  - Metrics displayed in agent review screen
  - Findings presented as actionable items
  - One-click accept for prompt modifications
  - Evidence examples expandable
- **Example Output**:

  ```text
  Technical Mentor Performance
  Metrics: Relevance 8.5 | Adherence 7.2 | Opportunities 3

  Finding 1: Role Discipline
  Question: Why discuss business topics 28% of the time?
  Evidence: 2 instances in conversations #456, #458
  Impact: Reduces technical focus
  Suggestion: Add role boundary reminder
  Prompt: "When business topics arise, defer to Business Strategist"
  ```

**Proposed from Overview**: Overview shows Review Agent assessing if agents "overstepped boundaries" or "missed opportunities" - suggests performance measured against defined purpose.

---

## 8. User Interface

### 8.1 Interface Customization ✅ DECIDED
**Decision**: No interface customization for version 1
**Rationale**: Focus on core functionality and consistent experience
**Implementation**:
- Single consistent UI for all users
- No customization settings or options
- Design system to allow customization later:
  - Theme system ready for light/dark modes
  - Layout components prepared for resizing
  - CSS variables for easy theming
- Future customization options documented:
  - Theme selection (light/dark/color accents)
  - Layout preferences (sidebar position, densities)
  - Agent display options

### 8.2 Accessibility ✅ DECIDED
**Decision**: Full WCAG 2.1 AAA compliance with automated testing
**Rationale**: Inclusive design with robust testing infrastructure
**Implementation**:
- **Compliance Target**: WCAG 2.1 AAA
- **Framework**: Next.js with TypeScript
- **Testing Stack**:
  - react-testing-library for component testing
  - jest-axe for accessibility testing
  - Automated CI/CD integration
- **Key Features**:
  - Semantic HTML structure
  - Sufficient color contrast (minimum 7:1 for normal text)
  - Keyboard navigation (no shortcuts, focus management only)
  - Reduced motion support
  - ARIA attributes and labels
  - Screen reader friendly markup
- **Testing Approach**:
  - Automated axe tests on all components
  - Custom jest matchers for accessibility
  - CI/CD pipeline integration
  - No manual screen reader testing (as requested)
- **Example Implementation**:

  ```tsx
  // Accessible conversation component
  const ConversationList = ({ conversations }) => (
    <ul aria-label="List of conversations">
      {conversations.map(conv => (
        <li key={conv.id} tabIndex={0}>
          <h3>
            <a href={`/conv/${conv.id}`}>{conv.title}</a>
          </h3>
          <p aria-label={`Preview of ${conv.title}`}>{conv.preview}</p>
        </li>
      ))}
    </ul>
  );

  // Test with jest-axe
  test('meets WCAG AAA', async () => {
    const { container } = render(<ConversationList />);
    expect(await axe(container)).toHaveNoViolations();
  });
  ```

- **CSS Considerations**:
  - Color system with guaranteed contrast ratios
  - Focus indicators (3px outline)
  - Reduced motion media queries
  - Responsive design with proper spacing

---

## 9. Data Management

### 9.1 Data Storage ✅ DECIDED
**Decision**: PostgreSQL (Docker) + Filesystem for reports
**Rationale**: Robust local storage with clear cloud migration path
**Implementation**:
- **Local Database**:
  - PostgreSQL 15 in Docker container
  - Data volume mapped to `./postgres-data`
  - Exposed for manual backup
  - Connection: `postgresql://aicouncil:securepassword@postgres:5432/aicouncil`
- **Report Storage**:
  - Local: `~/.ai-council/reports/{team_id}/{conversation_id}/report.md`
  - AWS alternative: S3 bucket with same structure
- **Docker Setup**:

  ```yaml
  services:
    postgres:
      image: postgres:15
      volumes:
        - ./postgres-data:/var/lib/postgresql/data
      ports:
        - "5432:5432"
  ```

- **Migration Path**:
  - Database: Local PostgreSQL → AWS RDS
  - Reports: Local filesystem → S3
  - Environment variables control storage location
- **Backup Strategy**:
  - Local: Manual copy of `postgres-data` and `reports` directories
  - AWS: Automatic RDS backups + S3 versioning
- **No In-App Export**: Data accessible via filesystem for manual operations
- **No Encryption**: Handled by AWS if migrated, not needed for local

### 9.2 Data Privacy ✅ DECIDED
**Decision**: Basic privacy with data deletion capabilities
**Rationale**: Appropriate for single-user local system with transparency
**Implementation**:
- **Storage Approach**:
  - User-specific directory: `~/.ai-council/{user_id}/`
  - Restrictive permissions (0700 for directories, 0600 for files)
  - No cross-user access possible
- **Privacy Features**:
  - Complete data isolation
  - Local filesystem permissions only
  - No remote access or cloud sync
  - Transparent data location disclosure
- **Data Deletion**:
  - Full account deletion endpoint
  - Specific resource deletion (conversations, agents, teams)
  - Permanent removal (no trash/recycle bin)
  - Confirmation dialogs with clear warnings
- **User Interface**:
  - Privacy settings page showing:
    - Data location path
    - Storage usage breakdown
    - Deletion options
  - Confirmation dialogs for destructive actions
- **API Endpoints**:
  - `POST /privacy/delete-account` - Delete all user data
  - `POST /privacy/delete-resource` - Delete specific resource
  - `GET /privacy/data-info` - Get storage information
- **No Backups**: User responsible for manual backups
- **No Size Warnings**: User can monitor via UI

---

## 10. System Performance

### 10.1 Performance Requirements ✅ DECIDED
**Decision**: Good performance targets for responsive local experience
**Rationale**: Balance between responsiveness and implementation complexity
**Implementation**:
- **Response Time Targets**:
  - Agent responses: < 3 seconds (local LLM)
  - UI navigation: < 500ms
  - Data loading: < 1 second
- **Resource Usage Targets**:
  - Memory: < 2GB typical usage
  - CPU: < 50% typical usage
  - Disk: < 100MB initial, scales with usage (~10MB per 100 conversations)
- **Scalability Targets**:
  - Conversations: 100+ without performance degradation
  - Agents: 20+ per team
  - Teams: 10+ per user
- **Optimization Strategies**:
  - Database indexing on frequent queries
  - Query optimization for conversation loading
  - Caching of agent configurations
  - Lazy loading of conversation history
  - WebSocket for real-time updates
- **Monitoring**:
  - Track response times per agent
  - Monitor resource usage
  - Alert on slow responses (>5 seconds)
  - Generate performance recommendations

### 10.2 Scalability ✅ DECIDED
**Decision**: Good scalability targets with performance monitoring
**Rationale**: Phase 1 focus with room for optimization as needed
**Implementation**:
- **Phase 1 Targets**:
  - Data volume: 1,000+ conversations, 100+ agents, 20+ teams
  - Performance: Maintain < 3s response times at scale
  - Resource usage: Linear growth with data volume
- **Monitoring**:
  - Track response times, query performance, memory usage
  - Establish baseline metrics on first run
  - Monitor degradation over time
- **Optimization Recommendations**:
  - Generated when performance degrades beyond thresholds
  - Visible in admin debug panel and CLI
  - Specific, actionable suggestions:
    - SQL indexes to add
    - Query optimizations
    - Caching strategies
    - Memory management
  - Example: "Add index on conversations.team_id (35% improvement)"
- **Display Locations**:
  - Admin debug panel (development only)
  - CLI debug command
  - Log file entries
- **No Alerts**: Recommendations visible but no notifications
- **Phase 2**: Implement automatic optimizations based on recommendations

---

## 11. Clarification Questions from Design Decisions

### 11.1 Hybrid Agent Involvement ✅ DECIDED
**Decision**: Never auto-add agents, but allow context-aware re-suggestion
**Rationale**: Balance user control with opportunity identification
**Implementation**:
- **Agent Addition**: Always requires explicit user confirmation
- **Suggestion System**:
  - Analyzes conversation topics for agent relevance
  - Suggests agents that could add value
  - Shows confidence percentage and rationale
- **Dismissal Handling**:
  - Records dismissed suggestions with context
  - Prevents immediate re-suggestion
  - Allows re-suggestion if conversation shifts significantly (>30% topic change)
- **Opportunity Monitoring**:
  - Review Agent analyzes completed conversations
  - Identifies missed opportunities where agents could have contributed
  - Provides specific feedback: "Agent X could have addressed Y topic"
- **UI Presentation**:
  - Non-intrusive suggestion panel
  - Clear rationale for each suggestion
  - Context about previous dismissals
  - One-click add/dismiss actions
- **Example Flow**:

  ```text
  1. Conversation about API design
  2. System suggests Technical Mentor (92% match)
  3. User dismisses suggestion
  4. Conversation shifts to database scaling
  5. System re-suggests Technical Mentor for new topic
  6. Review shows missed opportunity for pricing discussion
  ```

**Proposed from Overview**: Overview states "Hybrid: Agents suggest hand-offs, but users must confirm" - suggests no fully automatic agent addition.

### 11.2 Mentor-Only Conversations ✅ DECIDED
**Decision**: Single long-lived conversation in dedicated UI section
**Rationale**: Special treatment for personalized guidance while maintaining continuity
**Implementation**:
- **Conversation Model**: Single ongoing mentor session per user
- **UI Placement**:
  - Dedicated section at bottom of conversations sidebar
  - Separate from folders and regular conversations
  - Always visible and accessible
- **Visual Distinction**:
  - Blue accent color (#4a90e2)
  - Mentor icon (🎓) prefix
  - Subtle background tint
  - Special border treatment
- **Selected State**:
  - Unique header with gradient background
  - "Ongoing since [date]" subtitle
  - No agent sidebar or selection options
  - Special message styling
- **Context Management**:
  - Continuous context maintained
  - Automatic summarization when needed
  - Periodic knowledge extraction
  - No manual context clearing required
- **UI Structure**:

  ```text
  Conversations Sidebar
  ├── Folders/
  ├── Uncategorized
  └── 🎓 Mentor Session  [at bottom]
      └── Ongoing conversation
  ```

**Proposed from Overview**: Overview specifies "Mentor Conversations: Special UI—no other agents allowed" - suggests visual distinction and special UI elements.

### 11.3 Markdown-Based Reports ✅ DECIDED
**Decision**: Standard structure via specialized report agent with timestamp versioning
**Rationale**: Consistent output with automatic versioning
**Implementation**:
- **Report Generation**:
  - Dedicated Report Agent with fixed template
  - No user customization in phase 1
  - Generated automatically from conversation data
- **Structure**:
  - YAML front matter with comprehensive metadata
  - Standardized sections: Overview, Key Points, Perspectives, Outcomes
  - Structured markdown format
  - Conversation metadata appendix
- **Versioning**:
  - Timestamp in filename: `[title]-[YYYYMMDD-HHMM].md`
  - Version field in front matter
  - Template version tracking
- **Example Front Matter**:

  ```yaml
  ---
  title: "API Design Review - 20240326-1430"
  date: "2024-03-26"
  agents: ["Technical Mentor", "Devil's Advocate"]
  team: "Product Development"
  conversation_id: "conv_abc123"
  version: "1.0"
  template: "standard-v1"
  ---
  ```

- **Storage**:
  - Local: `~/.ai-council/reports/{team_id}/{conversation_id}/{title}-{timestamp}.md`
  - AWS: S3 with same path structure
- **Processing**:
  - Front matter enables easy parsing
  - Standard structure allows consistent processing
  - Metadata supports search and filtering

**Proposed from Overview**: Overview mentions "Reports: Markdown Files" but doesn't specify structure or versioning - suggests standard Markdown format without customization.

---

## Next Steps

1. Review this document question by question
2. Provide answers or request clarification for each item
3. Update the system document based on resolved questions
4. Create detailed requirements and user stories documents
5. Finalize system document for architecture handoff
