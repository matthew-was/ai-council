# Research Questions

**Role:** Head of Development
**Phase:** Research (pre-decision facilitation)
**Date produced:** 2026-04-15
**Status:** Complete

---

## Purpose

This document records open research questions that must be investigated before the Head of Development can facilitate architectural decisions for the AI Council project. The questions are derived from:

1. The Architectural Flags surfaced in `documentation/requirements/user-requirements.md`.
2. The cross-cutting concerns implied by the system behaviours described in `documentation/project/overview.md` and `documentation/requirements/phase-1-user-stories.md`.
3. Specific investigation areas requested by the developer for this session.

**Scope rules:**

- This document only lists questions. It does not answer them.
- It does not recommend, rank, or pre-filter options.
- Answers produced by the research phase will feed into decision facilitation, where the developer makes the final choice on each question and each choice is recorded as an ADR.
- Questions are grouped thematically. Within each group, each question has a unique ID (`RQ-NNN`) so findings can be cross-referenced.

**Hard constraint to respect in every research answer:** The Infrastructure as Configuration principle (`documentation/process/development-principles.md`). Every external service — including the AI model — must be accessed through an abstraction interface whose concrete implementation is selected by configuration at runtime. No candidate framework, library, or pattern is acceptable if it forces hardcoded provider selection, hardcoded model endpoints, or environment-name branching in application code.

---

## Group A: Agentic Framework Evaluation (Developer-Requested Focus)

This group covers the developer's specific research request: whether LangChain and/or LangGraph are appropriate foundations for the agentic behaviour in AI Council, and whether alternatives exist that fit better. The AI Council system has several distinct agentic behaviours — multi-Persona conversations in three modes, a background Orchestrator, a three-layer Mentor memory system, and a Review Agent — and the chosen framework (or deliberate absence of one) must support all of them without violating the Infrastructure as Configuration principle.

### RQ-A1 — LangChain suitability (general)

**Status:** Complete

Is LangChain a credible choice for powering the AI Council system's agentic behaviours as currently specified? What does LangChain provide out of the box that maps cleanly onto AI Council's requirements (Persona conversations with per-Persona System Prompts, snapshotting, Context Panel injection into every call, memory layers, background analysis jobs, tool-free Persona responses)? What parts of LangChain would have to be deliberately avoided or routed around?

**Research findings:**

LangChain (Python, v0.3.x as of April 2026) is a mature framework centred on a modular "glue layer" architecture: prompt templates, a unified chat model interface, LCEL (LangChain Expression Language) for pipeline composition, and integrations with 100+ providers. Its core design maps onto several AI Council needs:

*What maps cleanly:*

- **Per-Persona System Prompts.** `ChatPromptTemplate` with a system message slot directly supports per-Persona System Prompt injection. A different template instance per Persona is idiomatic.
- **Context Panel injection.** The Context Panel can be added as a fixed element in a `ChatPromptTemplate` before the message history placeholder. LCEL pipelines pass structured context to every `invoke()` call, so injecting the Context Panel as a high-priority message before truncated history is a natural pattern.
- **Provider-agnostic model calls.** The `BaseChatModel` interface (`invoke`, `stream`, `batch`) is uniform across all providers. `init_chat_model()` with `configurable_fields=("model", "model_provider")` allows provider and model name to be read from config at runtime with no code change — directly satisfying Infrastructure as Configuration (see RQ-A4 for detail).
- **Prompt templating for analysis jobs.** Review Agent and Orchestrator suggestion prompts are exactly the single-turn or multi-turn structured prompts LangChain was built for.
- **Tool-free Persona responses.** LangChain does not force tool-calling; plain `invoke()` against a `ChatPromptTemplate | chat_model` chain is fully supported and is the default for non-agent chains.

*What must be avoided or routed around:*

- **Legacy memory classes.** `ConversationBufferMemory`, `ConversationSummaryMemory`, and related classes were deprecated in LangChain v0.3.1 and are scheduled for removal at v1.0.0. They cannot persist across process restarts and conflict with tool-calling agents. The recommended replacement is LangGraph's checkpointer (for within-session state) and `BaseStore` (for cross-session long-term memory). This means the three-layer Mentor memory system (Working, Episodic, Semantic) cannot be built on LangChain memory primitives — it must be built on LangGraph persistence or a bespoke layer (see RQ-A9).
- **Agents module.** LangChain's `AgentExecutor` and ReAct-style agents are tool-using patterns that are not relevant to AI Council's Persona responses, which are direct prompt→response chains. Adopting them would introduce unnecessary complexity. The recommended pattern for multi-agent coordination is LangGraph, not LangChain's own agents module.
- **Snapshot coupling risk.** LangChain has no built-in concept of a "Persona snapshot" (capturing Name, System Prompt, Temperature at conversation-start and freezing them). This must be implemented in application code — LangChain provides no protection against accidentally using an updated System Prompt in a running conversation. This is not a blocker but requires deliberate design.

*Overall assessment:* LangChain's core (LCEL + ChatPromptTemplate + BaseChatModel) is a credible foundation for the prompt construction and model invocation layer. The parts that are irrelevant (AgentExecutor, legacy memory) can be ignored. The parts AI Council needs but LangChain does not provide (multi-agent turn orchestration, persistent multi-layer memory) are supplied by LangGraph and bespoke application logic respectively. LangChain alone is insufficient for AI Council; it would be one component of a wider stack.

### RQ-A2 — LangGraph suitability (general)

**Status:** Complete

Is LangGraph a credible choice for the multi-agent coordination required by AI Council — specifically Round-Robin and Peer-to-Peer Conversation modes, the Orchestrator's supervisory behaviour, and the Review Agent's batch analysis? What does LangGraph's state-graph model offer that a hand-rolled turn-taking loop does not, and what does it impose in return?

**Research findings:**

LangGraph (Python, v0.2.x / v0.3.x as of April 2026; TypeScript `@langchain/langgraph` at production parity since mid-2025) is a graph-based agent orchestration framework where nodes are Python/TypeScript functions and edges define control flow. State is a typed dictionary passed between nodes; reducers control how node outputs accumulate into shared state.

*What LangGraph provides over a hand-rolled loop:*

- **Persistent checkpointing.** Every node transition is checkpointed to a configurable backend (in-memory, SQLite, PostgreSQL). This means a paused conversation can be resumed across process restarts, a key requirement for AI Council (conversations remain open indefinitely, FR sessions survive application restarts).
- **Human-in-the-loop interrupts.** The `interrupt()` function pauses graph execution at any node, saves the checkpoint, and waits indefinitely for an external resume signal via `Command(resume=value)`. This is natively suited to: user confirmation of Orchestrator suggestions (FR-8.2), pausing an autonomous P2P exchange on `@Orchestrator` mention (FR-8.7), and "End Conversation" triggers mid-cycle (FR-6.1).
- **Conditional routing.** Edge functions inspect state and return the name of the next node. This maps onto next-speaker selection in P2P mode and mode-based routing between Round-Robin and P2P execution paths.
- **Supervisor pattern.** `langgraph-supervisor` (a published sub-package on PyPI) implements a coordinator agent that delegates to worker sub-graphs. The supervisor can be configured to route, retry, or terminate.
- **Subgraph composition.** Complex workflows can be broken into reusable subgraphs, enabling a single graph topology to accommodate multiple conversation modes.
- **Streaming.** LangGraph supports token-by-token streaming from nodes, which is needed for real-time Persona response rendering (RQ-C4).

*What LangGraph imposes:*

- **State schema must be declared upfront.** The `TypedDict` state schema defines what data flows through the graph. AI Council's conversation state (message history, active personas, mode, turn count, context panel) must be modelled as graph state, which is reasonable but not trivial.
- **Node restarts on resume.** When resuming after an `interrupt()`, the entire node re-executes from the beginning (not from the interrupt call site). Any side effects before the interrupt point run again. This requires idempotent node design.
- **Checkpointer required for persistence.** The graph is stateless without a checkpointer. Configuring and maintaining the checkpointer (SQLite for local, PostgreSQL for cloud) is an infrastructure concern.
- **Abstraction overhead for simple workflows.** Round-Robin mode is a sequential loop; wrapping it in a state graph adds graph definition boilerplate compared to a plain `for persona in personas: response = model.invoke(...)` loop (see RQ-A7 for this specific analysis).

*Fit for AI Council's agentic behaviours:*

- Round-Robin: Expressible as a graph but may be over-engineered (see RQ-A7).
- P2P: Well-suited; conditional routing, turn-cap enforcement via state counters, and interrupt-based pause/resume are native capabilities.
- Orchestrator (monitor + suggester): Partially suitable; the supervisor pattern maps onto routing but the "soft suggester" requirement requires careful design to avoid making the Orchestrator a hard router (see RQ-A8).
- Review Agent (batch analysis): Expressible but likely overkill; the batch nature does not benefit from graph state management (see RQ-A10).

*Infrastructure as Configuration:* LangGraph does not bind nodes to specific model instances at graph definition time. Models are passed into nodes as parameters or accessed via application-layer dependency injection. No constraint violation detected, provided the application code follows the pattern correctly.

### RQ-A3 — LangChain + LangGraph together

**Status:** Complete

Is the combination of LangChain (for model abstraction, prompt templating, memory primitives) and LangGraph (for multi-agent turn orchestration) a coherent stack, or does using both introduce duplication, conflicting abstractions, or unnecessary coupling? What is the realistic minimum surface area of each library that the project would need to adopt?

**Research findings:**

LangGraph is built on top of LangChain's core package (`langchain-core`). This is by design: LangGraph nodes can use any LangChain Runnable — including chains built with LCEL, `ChatPromptTemplate`, and `BaseChatModel` instances — as their callable. The two libraries share the same message types (`HumanMessage`, `AIMessage`, `SystemMessage`), the same streaming interface, and the same `configurable` runtime configuration mechanism.

*Coherence:* The combination is coherent rather than conflicting. The intended architecture documented by LangChain Inc. is: LangChain for model calls and prompt construction inside nodes; LangGraph for the graph that sequences those nodes, manages state, and handles interrupts. LangGraph's own documentation describes LangChain as the "model invocation layer" within a LangGraph node.

*Duplication risk:* The main area of potential duplication is memory. LangChain's deprecated `ConversationBufferMemory` and LangGraph's checkpointer + `BaseStore` both manage conversation history, but since the LangChain memory classes are deprecated and the recommendation is to migrate to LangGraph persistence, this is not a live conflict. A project starting fresh in 2026 would use LangGraph persistence exclusively and never touch LangChain's memory module.

*Minimum surface area for AI Council:*

From LangChain (`langchain-core` + `langchain`):
- `ChatPromptTemplate` / `SystemMessage` / `HumanMessage` / `AIMessage` — for prompt construction per Persona
- `BaseChatModel.invoke()` / `.stream()` — for model calls
- `init_chat_model()` with `configurable_fields` — for provider-agnostic model selection

From LangGraph:
- `StateGraph` + `TypedDict` state schema — for conversation graph definition
- `interrupt()` + `Command` — for human-in-loop pause/resume (Orchestrator suggestions, P2P pausing)
- A checkpointer (e.g. `SqliteSaver` or `PostgresSaver`) — for persistent conversation state
- `langgraph-supervisor` — optional sub-package, if the supervisor pattern is adopted for Orchestrator; can be avoided if bespoke routing is preferred

What is *not* needed from either library:
- `AgentExecutor` or ReAct agents (LangChain)
- Tool-calling abstractions (LangChain)
- Legacy memory classes (LangChain)
- LangGraph's pre-built `create_react_agent` (not needed for non-tool Persona responses)

*Coupling risk:* Both libraries are maintained by LangChain Inc. and are co-versioned. A breaking change in `langchain-core` would affect both. This is a single-vendor dependency (see RQ-A13 for lock-in analysis). The minimum-surface-area approach limits coupling: if AI Council only uses prompt templates and model calls from `langchain-core`, and graph/state management from `langgraph`, an exit from either is narrowly scoped.

### RQ-A4 — LangChain/LangGraph and the Infrastructure as Configuration principle

**Status:** Complete

Can LangChain's model integration be wrapped so that swapping a local LLM for a cloud API is purely a configuration change with zero application-code change (FR-21.2, NFR-3)? Does LangChain's chat model abstraction already satisfy this, or would an additional internal interface be required on top? Does LangGraph constrain this in any way — for example, by binding nodes to specific model instances at graph definition time?

**Research findings:**

*LangChain's built-in mechanism:*

`init_chat_model(configurable_fields=("model", "model_provider"))` (available since LangChain 0.2.x, stable in 0.3.x) creates a `ConfigurableModel` instance. At `invoke()` time, the caller passes `config={"configurable": {"model": "llama3", "model_provider": "ollama"}}`. No application code refers to a provider-specific class. This is the closest native mechanism to Infrastructure as Configuration that LangChain offers.

Confirmed working with: OpenAI, Anthropic, Google, Ollama, Hugging Face, Azure OpenAI, and any provider that has a `langchain-<provider>` package installed. The model name is passed directly to the provider SDK — no LangChain update is required when a new model name is released (confirmed in documentation).

*Does this fully satisfy Infrastructure as Configuration?*

Partially. The `init_chat_model` pattern satisfies the "no application-code change" requirement for provider and model name. However:

1. **Provider packages must be installed.** If the config specifies `model_provider: "anthropic"`, the `langchain-anthropic` package must be present in the environment. Switching from Ollama to Anthropic requires installing a different package, not just changing config. In a Docker-based or bundled deployment this is solved by pre-installing all provider packages; in a lightweight local install it requires documentation clarity. This is an operational constraint, not an application-code constraint.
2. **API key environment variables vary by provider.** OpenAI reads `OPENAI_API_KEY`; Anthropic reads `ANTHROPIC_API_KEY`; Ollama reads nothing. The config file or environment must supply the correct key for the selected provider. This is standard practice but must be documented in the configuration schema (see RQ-C2).
3. **Structured output / tool-calling behaviour differs.** Cloud APIs support `.with_structured_output()` natively; some local models do not. LangChain's interface exposes this uniformly but the underlying model capability varies. If structured output is needed (RQ-C3), the abstraction does not fully hide provider differences.

*Would an additional internal interface be needed?*

With `init_chat_model`, an explicit project-internal interface (e.g. `ModelGateway`) would not be strictly required — `BaseChatModel` is already a protocol. However, an internal facade could add value for: (a) centralising the `configurable` plumbing so all call sites use a consistent pattern, (b) adding retry/error handling uniformly (see RQ-C5), and (c) providing a seam for testing (inject a fake `BaseChatModel` in unit tests). Whether this internal facade is necessary is a decision, not a finding.

*Does LangGraph constrain this?*

No. LangGraph nodes receive models as parameters or via dependency injection — the graph definition does not bind to a specific model instance. A node function `def persona_node(state, model: BaseChatModel)` decoupled from graph wiring is the idiomatic pattern. The `configurable` config dict flows through the graph's `invoke()` call into every node, so a single config can propagate the provider/model choice to all model calls in a graph execution without per-node modification. No constraint violation detected.

### RQ-A5 — Language and ecosystem fit

**Status:** Complete

LangChain and LangGraph are most mature in Python, with a TypeScript port of narrower scope. Which language/runtime choice is implied by adopting LangChain/LangGraph, and what does that imply for the backend technology decision that has not yet been taken? If the backend is not Python, is the TypeScript port sufficient for AI Council's specific needs, or would adoption effectively force a Python backend?

**Research findings:**

*Python vs TypeScript status as of April 2026:*

LangChain and LangGraph were Python-first. As of mid-2025, `@langchain/langgraph` (TypeScript/JavaScript) reached production stability with feature parity on core capabilities: `StateGraph`, conditional edges, checkpointing, streaming, and human-in-the-loop `interrupt()`. The TypeScript package sees 42,000+ weekly npm downloads as of April 2026 (reported). The LangChain TypeScript package (`langchain` on npm) also offers `initChatModel()` with equivalent provider-agnostic behaviour.

*Where parity was and remains uncertain:*

- **Checkpointer backends.** Python LangGraph ships `SqliteSaver` and `PostgresSaver` as stable packages. The TypeScript equivalent (`@langchain/langgraph-checkpoint-sqlite`, `@langchain/langgraph-checkpoint-postgres`) were added but are newer. Their production robustness compared to the Python versions is unconfirmed from official documentation.
- **`langgraph-supervisor` package.** The supervisor sub-package exists in Python (`langgraph-supervisor` on PyPI). A first-party TypeScript equivalent is available in `@langgraphjs/toolkit` (bundled as of April 2026), but documentation is thinner.
- **ML-centric utilities.** Tokenizers, embedding models, and local-model specific utilities (e.g. detailed Ollama integration) remain better covered in Python. For AI Council's use of LangChain (prompt templates + model calls only), this is not a blocker — the TypeScript integrations for Ollama, Anthropic, and OpenAI are documented and functional.

*What adopting LangChain/LangGraph implies for the backend:*

If Python is chosen: full access to the most mature tooling, the widest provider integration coverage, and the `langgraph-supervisor` package if needed.

If TypeScript/Node.js is chosen: the core capabilities needed by AI Council (LCEL-style chains, `initChatModel`, `StateGraph`, `interrupt`, SQLite/Postgres checkpointer) are available and production-stable. The TypeScript ecosystem implies Fastify, NestJS, or similar Node.js backend frameworks, which have mature background job and WebSocket/SSE capabilities independently of the agentic framework.

*Does adopting LangChain/LangGraph force Python?*

No, based on April 2026 state. The TypeScript port is sufficient for AI Council's specific needs as identified in RQ-A1 and RQ-A2. However, Python carries lower risk for LangGraph-specific features because it remains the primary development target. If the project adopts a TypeScript backend, the TypeScript LangGraph stack is viable but carries a small residual risk that edge-case features (e.g. advanced supervisor configuration, specific checkpointer behaviour) may lag the Python version by weeks to months.

*Cross-reference:* The backend framework choice (RQ-G5) interacts with this. A Python backend (FastAPI, Litestar) would make Python LangGraph the natural fit. A Node.js backend would require the TypeScript stack. If no agentic framework is adopted (RQ-A12), the language choice becomes unconstrained by the agentic layer.

### RQ-A6 — Peer-to-Peer turn-taking with LangGraph

**Status:** Complete

The P2P requirement (FR-5.3 Mode 3, FR-8.7, US-O3, Section 5.2 Mode 3 of the overview) requires that multiple Personas respond to the user or to each other without the user prompting each turn, with throttling to prevent runaway Persona-to-Persona loops, and with the ability to interrupt the exchange via an `@Orchestrator` mention or an "End Conversation" action. Can LangGraph's supervisor / multi-agent patterns express this behaviour directly? Specifically:

- How would "next speaker" selection be modelled as graph state or as an edge function?
- How would a hard turn cap (maximum consecutive Persona-to-Persona turns without user involvement) be enforced?
- How would a soft throttle (e.g. progress detection, topic drift, diminishing novelty) be expressed — as a graph node, as a custom edge condition, or outside the graph?
- How would mid-run interruption from a user message or `@Orchestrator` mention propagate into a running graph execution?
- Is pausing and resuming an autonomous exchange (US-O3) a native LangGraph capability, or something that must be implemented around it?

**Research findings:**

*Next-speaker selection as graph state / edge function:*

LangGraph's canonical approach is a **conditional edge function** that reads the current graph state (e.g. last speaker, message content, addressability) and returns the name of the next node. For AI Council, next-speaker logic would live in a function like `decide_next_speaker(state) -> str` evaluated as a conditional edge. The state would carry `last_speaker`, `p2p_turn_count`, `addressee` (if a Persona was named in the last message), and `messages`. This is a confirmed LangGraph pattern, implemented in published examples (multi-agent debate / conversation patterns on LangChain's blog and GitHub).

*Hard turn cap enforcement:*

A `p2p_turn_count` integer in the graph state, incremented by a reducer each time a Persona node runs, compared in the edge function: `if state["p2p_turn_count"] >= MAX_TURNS: return "await_user"`. This is a first-class LangGraph pattern — counter-based termination via conditional edges is documented in official multi-agent examples. The `MAX_TURNS` value would come from application config, satisfying Infrastructure as Configuration.

*Soft throttle (progress detection, topic drift):*

This is **not a native LangGraph feature**. Detecting diminishing novelty or topic drift requires an LLM-mediated evaluation step or an embedding-similarity computation on recent messages. Implementation options:

- **Evaluation node:** A `throttle_check` graph node after each Persona response that invokes the model to assess "has meaningful progress occurred in the last N turns?". If not, it routes to `await_user`. This adds latency per turn.
- **Custom edge condition:** The edge function runs a lightweight heuristic (repetition detection on message text) without an LLM call. Faster but less accurate.
- **Outside the graph:** A background evaluator checks state between turns and writes a `should_pause` flag to graph state via `Command`. This requires the graph to have a checkpoint the evaluator can write to.

None of these are provided out of the box. The project must implement whichever soft throttle strategy is chosen. Cross-reference: RQ-F1 covers throttle trigger semantics in more depth.

*Mid-run interruption from user message or `@Orchestrator` mention:*

LangGraph's `interrupt()` function is the intended mechanism. An `interrupt()` call inside the Persona node or the next-speaker edge function pauses graph execution, saves the checkpoint, and surfaces a value to the caller (e.g. the current in-flight response). The caller (the backend HTTP handler) can then accept the user message and resume with `Command(resume=user_message)`. Two important constraints apply:

1. The node **restarts from the beginning** upon resume, not from the interrupt call site. Any LLM call that happened before the interrupt in that node re-executes. Designing nodes to be idempotent or placing the interrupt before the LLM call (after the previous response was committed to state) is the correct pattern.
2. The interrupt propagates between node executions, not mid-token-stream. If a Persona is currently generating tokens, the interrupt takes effect at the next turn-selection decision point, not immediately mid-stream. This matches FR-8.7's requirement: "after the current in-flight Persona response completes."

*Pausing and resuming an autonomous exchange:*

This is a **native LangGraph capability** via checkpointing + `interrupt()`. Pausing produces a checkpoint. Resuming re-invokes the graph with the same `thread_id` and a `Command(resume=...)` value. The resumed graph picks up from the interrupted node. The pause state survives process restarts if a persistent checkpointer (SqliteSaver, PostgresSaver) is configured. This directly satisfies US-O3.

*Caveats:*

- Dynamic P2P (any-to-any Persona addressing) requires careful state modelling: tracking which Persona was addressed, whether the user interjected, and how the autonomous loop restarts after a user injection. These are application-layer decisions, not LangGraph decisions.
- LangGraph's `interrupt()` imposes a checkpointer requirement; without a checkpointer, pause/resume is not available.

### RQ-A7 — Round-Robin turn-taking with LangGraph

**Status:** Complete

Round-Robin mode (FR-5.15) requires a fixed, sequential turn order after each user message, with the full cycle completing before the user can send the next message, and with `@Orchestrator` interrupts after the current in-flight response completes (FR-8.8). Is Round-Robin worth modelling as a LangGraph graph at all, or is it simple enough that a plain sequential loop is more appropriate? If both modes use LangGraph, can they share a single graph definition with a routing policy, or do they require separate graphs?

**Research findings:**

*Is Round-Robin worth modelling as a LangGraph graph?*

Round-Robin mode is algorithmically simple: iterate through personas in a fixed list and call the model for each in sequence. A plain sequential loop (`for persona in ordered_personas: response = model.invoke(...)`) achieves this without any graph infrastructure. LangGraph's own documentation acknowledges it is most beneficial for complex workflows with branching, looping, and conditional logic; simple sequential workflows are noted as a case where simpler alternatives may be more appropriate.

Arguments for using LangGraph for Round-Robin anyway:
- **Consistency.** If P2P mode uses LangGraph (for checkpointing, interrupt support, and conditional routing), using LangGraph for Round-Robin too means a single graph framework manages all conversation state. The same conversation thread, checkpoint store, and interrupt mechanism applies to both modes.
- **`@Orchestrator` interrupt.** FR-8.8 requires that an `@Orchestrator` mention interrupt the current Round-Robin cycle after the in-flight response completes. LangGraph's `interrupt()` placed at the cycle boundary (after each Persona node) handles this without additional custom state management.
- **Mode switching.** If the user switches mode mid-conversation (Round-Robin → P2P), having both modes expressed as LangGraph graph states in the same checkpoint makes the switch a graph-routing decision rather than a state migration.

Arguments against using LangGraph for Round-Robin:
- **Overhead for a for-loop.** A Round-Robin cycle is a deterministic, ordered sequence with no branching. The graph definition, state schema, and checkpointing overhead are all non-trivially more complex than a `for` loop.
- **Debugging simplicity.** A plain loop is easier to reason about and test than a graph with sequentially wired nodes.

*Can both modes share a single graph definition?*

Yes, and this is the architecturally cleanest option if LangGraph is adopted at all. A shared `ConversationGraph` with a `mode` field in state and a routing function that selects either the Round-Robin node sequence or the P2P conditional edge can express both modes under one graph. Mode switches become state updates, not graph replacements. The existing checkpoint and thread continue uninterrupted.

*Recommendation posture (neutral):* If LangGraph is adopted for P2P (which is the stronger case), sharing the graph for Round-Robin trades some complexity for consistency and avoids maintaining two separate execution paths. If no framework is adopted, Round-Robin is straightforwardly implementable as a plain loop, and is the weaker argument for adopting LangGraph.

### RQ-A8 — Orchestrator as a LangGraph supervisor

**Status:** Complete

The Orchestrator (Section 5.4, FR-8.1 through FR-8.9) monitors Conversations, suggests Personas, responds to `@Orchestrator` mentions for targeted summaries (FR-8.6, FR-11.1), and in P2P mode pauses autonomous exchanges (FR-8.7). Does LangGraph's supervisor pattern map cleanly onto this role, or does it force the Orchestrator to be something it is not (a hard router rather than a soft suggester)? Is there a clean way to express "never auto-adds — always surfaces a suggestion for user confirmation" (FR-8.2) inside a LangGraph flow?

**Research findings:**

*LangGraph's supervisor pattern — what it does natively:*

The `langgraph-supervisor` package implements a coordinator agent that receives a task, delegates to specialist worker agents, collects their outputs, and decides when work is complete. It is designed for **hard routing**: the supervisor makes a binding decision about which agent runs next, and that agent runs immediately. The supervisor is the authoritative controller of the workflow.

*Mismatch with AI Council's Orchestrator:*

AI Council's Orchestrator is a **soft suggester**, not a hard router. The key divergences:

1. **Never auto-adds.** The supervisor pattern auto-routes to workers — this is its core function. Making a supervisor that surfaces a suggestion for user confirmation rather than routing automatically is possible but inverted from the pattern's intent. It would require replacing the router's output with an `interrupt()` that surfaces the suggestion and waits for user confirmation before the Persona is added. This is achievable but fights the pattern.
2. **Monitoring role.** The supervisor pattern is triggered by a task arriving. AI Council's Orchestrator runs as a post-message observer — it does not receive a "task" to complete; it analyses the conversation and may or may not surface a suggestion. This is an event-driven evaluation pattern, not a routing pattern.
3. **Dismissal suppression.** When the user dismisses a suggestion, the Orchestrator suppresses it (prompt-driven). A supervisor pattern has no built-in concept of suppression; this would have to live in the state (`dismissed_suggestions: list[str]`) and be read by the suggestion-generation prompt. This is implementable but must be bespoke.

*A workable LangGraph approach that avoids the supervisor anti-pattern:*

Model the Orchestrator as a **post-message hook node** in the conversation graph:

- After each user message or Persona response, the graph routes to an `orchestrator_check` node.
- This node invokes the model with the current conversation topic and the list of available (non-active) Personas.
- If the model determines a Persona is relevant, it writes a `pending_suggestion` to state and calls `interrupt()` to surface the suggestion to the frontend.
- The user confirms or dismisses via `Command(resume={"action": "confirm"|"dismiss", "persona_id": ...})`.
- The graph then routes to either the Persona-add node (confirm) or the suppression-update node (dismiss) before continuing.

This uses LangGraph correctly (checkpointing, interrupt) without forcing the supervisor pattern.

*`@Orchestrator` mention handling:*

An `@Orchestrator` mention in a user message can be detected by the edge function before the turn-selection node and routed to an `orchestrator_respond` node. This node runs the targeted summary or pause logic. This is a standard conditional-routing pattern and maps cleanly.

*P2P pause:*

The `@Orchestrator` mention in P2P mode that pauses the autonomous exchange is handled by the same detection-and-interrupt mechanism described in RQ-A6 — the interrupt occurs at the next turn boundary, not mid-stream.

*Overall:* The LangGraph supervisor sub-package is not the right fit for the Orchestrator role. A bespoke post-message hook node with interrupt-based user confirmation is a more honest expression of the Orchestrator's "never auto-adds, soft suggester" behaviour. This is implementable in LangGraph but requires designing the graph topology rather than adopting a pre-built pattern.

### RQ-A9 — Three-layer Mentor memory with LangChain memory primitives

**Status:** Complete

The Mentor's three-layer memory system (FR-18.1 through FR-18.5, US-MM1, US-MM2, Section 8.5) is a specific architecture: Working Memory (verbatim recent dialogue), Episodic Memory (rolling summaries of the last N sessions, with promotion of facts to Semantic Memory before oldest-entry retirement), and Semantic Memory (permanent structured Markdown knowledge documents). Does LangChain's memory abstraction support any of this directly, partially, or not at all? Which of the three layers, if any, map onto existing LangChain memory classes, and which require bespoke implementation?

**Research findings:**

*LangChain memory classes (legacy):*

All of LangChain's memory classes (`ConversationBufferMemory`, `ConversationSummaryMemory`, `ConversationKGMemory`, etc.) were deprecated in LangChain v0.3.1 and are scheduled for removal at v1.0.0. They should not be used in a new project. This finding closes the LangChain memory primitive path entirely.

*LangGraph's replacement primitives:*

LangGraph provides two persistence primitives:

1. **Checkpointer** (`SqliteSaver`, `PostgresSaver`): Stores the full graph state per `thread_id`. Used for within-session state — the running conversation. This maps to Working Memory.
2. **BaseStore** (`InMemoryStore`, `PostgresStore`): A key-value store with optional semantic search, scoped by namespace. Persists across sessions and thread boundaries. This maps to cross-session long-term memory.

*Mapping AI Council's three layers:*

**Working Memory (verbatim recent dialogue):**
Maps cleanly to the LangGraph checkpointer. The `messages` list in graph state, maintained by the checkpointer, is exactly the verbatim recent dialogue. Compression triggers (capacity threshold, new chapter, session end — FR-18.1) would fire application-side logic that reads the checkpointed messages, calls the model to summarise, writes the summary to BaseStore (Episodic), and truncates the messages list in state.

**Episodic Memory (rolling N session summaries with promotion logic):**
Partially maps to LangGraph's BaseStore. A namespace like `("workspace_id", "mentor", "episodic")` with keys `"session_0"`, `"session_1"` etc. can store summaries. However:
- BaseStore does not natively support "rolling N" semantics — the project must implement the window management (delete oldest when N exceeded).
- The **promotion check** (before retiring the oldest episodic entry, check if facts should be promoted to Semantic Memory — FR-18.3) is an LLM-mediated step that has no LangGraph equivalent. This is bespoke application logic invoking the model and writing results to Semantic Memory.
- Note: LangMem SDK (by LangChain Inc., a layer on top of BaseStore) provides episodic and semantic memory types with semantic search, but its `p95 search latency of 59.82 seconds` (per benchmark data found in research) makes it unsuitable for interactive use. LangMem is under active development and this limitation may improve.

**Semantic Memory (permanent structured Markdown knowledge documents):**
Partially maps to BaseStore. Key-value storage of Markdown strings per namespace is supported. However:
- BaseStore semantics are key-value (get by key or semantic search by embedding). AI Council's Semantic Memory is described as "structured Markdown knowledge documents" — structured prose, not discrete facts. Storing and retrieving a single document per Workspace is trivial; structured updates (appending to an existing document when new facts are extracted) require bespoke merge logic.
- The Memory Inspector (FR-19) requires reading Semantic Memory for display — BaseStore's `get()` supports this directly.

*Overall assessment:*

None of the three layers maps cleanly and completely onto a single LangGraph primitive. Working Memory is the closest fit (the checkpointer's message list). Episodic and Semantic Memory require BaseStore plus bespoke application logic for window management, promotion checks, and document merging. The LangChain memory classes are not an option. LangMem is an emerging SDK that may reduce the bespoke work but is not yet suitable for production interactive use.

Cross-reference: RQ-I7 covers the promotion-to-Semantic logic in more depth. RQ-C3 is relevant for structured output from the promotion/compression prompts.

### RQ-A10 — Review Agent as a LangGraph batch workflow

**Status:** Complete

The Review Agent (FR-14.1 through FR-14.11, FR-15.1 through FR-15.7, FR-16.1 through FR-16.5) is a nightly background job that evaluates each participating Persona against snapshots, produces persona-specific findings with embedded evidence, and supports an interactive consultation mode with a different context boundary (no Conversation histories). Is LangGraph appropriate for expressing this batch workflow, or is it overkill for a job that is fundamentally "for each Persona, run an evaluator prompt"? Would a plain task queue be a simpler and more honest fit?

**Research findings:**

*What the Review Agent actually does at execution time:*

1. Gather all concluded conversations since last run (database query).
2. For each Conversation, for each Persona in that Conversation: invoke the evaluator prompt with the conversation snapshot and full history.
3. Write findings (or update existing findings) to the findings store per Persona.
4. Optionally: for the Mentor, evaluate the recent Mentor Conversation activity.

This is a **fan-out batch job**: for each item in a set, run a model call and write a result. There is no dynamic routing, no conditional multi-step agent reasoning, no mid-run user interaction (the nightly batch is unattended). The interactive consultation mode (FR-16.2) is a separate concern — it is a synchronous request-response pattern, not a batch job.

*Is LangGraph appropriate for this?*

LangGraph's value propositions — graph-based state management, checkpointing, interrupt/resume, conditional routing — are not needed by the nightly Review Agent:

- **No mid-run pausing:** The nightly batch runs to completion unattended. LangGraph's interrupt mechanism is not relevant.
- **No dynamic routing:** The "for each Persona" loop is deterministic; there is no conditional logic driving which agent runs next.
- **No persistent multi-turn state:** Each Persona evaluation is an independent prompt call with no state carried between evaluations.
- **Checkpointing:** Useful if mid-run shutdown recovery is needed (FR-14.10 says partial results are discarded on shutdown), but that requirement *explicitly* rules out recovery — starting fresh is correct, making checkpointing counterproductive.

LangGraph's Send API (`map`/fan-out) could express the "for each Persona" pattern and provide some parallelism, but this is using a large framework for one pattern it supports among many. The LangGraph documentation itself, and independent comparisons (LangGraph vs Prefect/Airflow), note that production batch evaluation jobs may be better served by dedicated task orchestrators (Prefect, Celery, APScheduler, or a plain async task queue).

*A simpler and more honest fit:*

A plain `async for persona in personas: await evaluate(persona)` loop (with concurrency control via `asyncio.Semaphore` to avoid saturating the model API) is sufficient for the nightly batch. Alternatively, a lightweight task queue (Celery, ARQ, or a simple in-process scheduler — see RQ-D1) can run the evaluator function per Persona without LangGraph.

The interactive consultation mode (FR-16.2) is a synchronous chat pattern — a `ChatPromptTemplate | model` LCEL chain with a restricted context (no conversation histories). This is LangChain's core use case and does not require LangGraph.

*Verdict:* LangGraph is overkill for the Review Agent. The nightly batch is better expressed as a plain async loop or lightweight task queue. The interactive consultation mode is an LCEL chain. Neither requires graph state management.

Cross-reference: RQ-D1 (scheduling), RQ-D2 (single-run enforcement), RQ-I4 (dual access rules — batch vs interactive).

### RQ-A11 — Alternatives to LangChain/LangGraph

**Status:** Complete

What are the credible alternatives currently available for each role LangChain/LangGraph would otherwise play? The research should cover at least:

- **Direct use of a model provider SDK** (e.g. the OpenAI Python/TypeScript SDK, or a local-LLM server's HTTP API such as Ollama) with a thin internal abstraction layer.
- **Alternative agent frameworks** — including but not limited to AutoGen / AG2, CrewAI, LlamaIndex Agents, Haystack Agents, Semantic Kernel, PydanticAI, Mastra, and any other actively-maintained framework the research surfaces.
- **A bespoke thin layer** — a project-specific abstraction written from scratch over a model provider SDK, with turn-taking, memory, and Review Agent logic implemented directly in application code.

For each candidate, state: what it would cover, what it would leave to the project, its language/ecosystem fit, its fit with the Infrastructure as Configuration principle, and its maturity as of April 2026.

**Research findings:**

**1. Direct use of a model provider SDK + thin internal abstraction**

- **Covers:** Model calls (invoke, stream). Nothing else.
- **Leaves to the project:** Prompt construction, conversation state, memory management, turn-taking, scheduling, all agentic logic.
- **Language fit:** Provider SDKs exist for Python (OpenAI, Anthropic, HuggingFace) and TypeScript (openai, @anthropic-ai/sdk). Ollama exposes an OpenAI-compatible HTTP API, so the OpenAI SDK works with Ollama by setting `base_url`.
- **Infrastructure as Configuration fit:** Excellent, if the project wraps SDKs behind its own interface and selects the concrete SDK implementation from config. The project controls the abstraction boundary completely.
- **Maturity:** Stable. OpenAI and Anthropic SDKs are production-grade and updated synchronously with provider APIs.
- **Assessment:** Maximum control, maximum implementation cost for everything above the model call.

**2. PydanticAI (Python)**

- **Covers:** Type-safe agent definition, provider-agnostic model interface (OpenAI, Anthropic, Gemini, Ollama, many others via native support or LiteLLM bridge), structured output via Pydantic schemas, dependency injection for tools, Logfire observability, Temporal integration for durable execution. Released v1.0 September 2025.
- **Leaves to the project:** Multi-agent turn orchestration (no built-in graph model), memory layers, conversation state persistence, scheduler/background job logic. Multi-agent support exists via agent-calling-agent patterns, but P2P autonomous exchange requires bespoke state management.
- **Language fit:** Python only.
- **Infrastructure as Configuration fit:** Excellent. Model selection is a parameter on `Agent(model=...)`, and the model object can be constructed from config at startup. No code change required to swap providers — confirmed as a design goal ("a single PydanticAI agent is portable to different LLM vendors without any other code changes just by swapping out the Model").
- **Maturity:** v1.0 as of September 2025. 7,000+ GitHub stars. Growing adoption. Thinner ecosystem than LangChain; fewer pre-built integrations for memory and long-term persistence.
- **Assessment:** Strong for model-call layer and structured output; significantly weaker for multi-agent orchestration and persistent memory. Closer to "thin abstraction plus structured output" than a full agentic framework.

**3. Mastra (TypeScript/JavaScript)**

- **Covers:** TypeScript-native agent framework with conversation memory (working memory, semantic recall, observational memory via embedding-based search), workflow orchestration (graph-based, similar to LangGraph), tool calling, OpenTelemetry observability, Vercel/Next.js/Hono/Express integration. Launched January 2025, YC W25.
- **Leaves to the project:** Custom turn-taking logic for P2P and Round-Robin modes (Mastra's agent model is single-agent + tools, not multi-agent conversation); the Mentor's three-layer memory would need to be mapped to Mastra's memory primitives; Review Agent batch scheduling.
- **Language fit:** TypeScript/JavaScript only. Not available in Python.
- **Infrastructure as Configuration fit:** Good. The model provider is a parameter on agent creation; switching providers is a config change. Supports OpenAI, Anthropic, Google, and others.
- **Maturity:** Early but growing rapidly. `@mastra/core` on npm. Memory system (observational memory) launched February 2026. Developer experience rated 9/10 in independent benchmarks. Production readiness is less proven than LangChain/LangGraph.
- **Assessment:** Most compelling TypeScript alternative to the LangGraph stack. Gaps exist in multi-agent orchestration for AI Council's specific P2P and Round-Robin modes.

**4. AG2 / AutoGen (Python)**

- **Covers:** Multi-agent conversational patterns, group chat orchestration, human-in-the-loop, structured tool calling, built-in round-robin and selector-based speaker selection. AG2 is the community fork (100K PyPI installs/month); Microsoft's AutoGen 0.4 is a full rewrite integrating with Semantic Kernel.
- **Leaves to the project:** Infrastructure as Configuration model abstraction (see below), Mentor memory layers, persistent state, scheduling.
- **Language fit:** Python primarily. TypeScript support exists but lags.
- **Infrastructure as Configuration fit:** Moderate concern. AG2's `GroupChat` and speaker selection are coupled to model configuration at construction time, and model swapping requires care to ensure it does not bleed into application logic. Not designed with "swap-via-config-alone" as a first principle. Requires explicit wrapping to fully satisfy the constraint.
- **Maturity:** Established (AutoGen lineage, 48K GitHub stars). AG2 is stable; Microsoft's AutoGen 0.4 is still maturing.

**5. CrewAI (Python)**

- **Covers:** Role-based multi-agent coordination with crew, task, and agent primitives. 1.3M monthly PyPI installs. Opinionated workflow model designed for automated pipelines.
- **Leaves to the project:** The conversational, user-in-the-loop pattern AI Council requires (CrewAI is optimised for automated pipelines, not interactive user-facing conversations). Memory, persistence, scheduling.
- **Infrastructure as Configuration fit:** Moderate. CrewAI wraps LangChain's model interface and benefits from `init_chat_model` flexibility, but its design philosophy is not primarily around provider agnosticism.
- **Assessment:** Not well-suited to AI Council's interactive, user-in-the-loop conversational mode.

**6. Semantic Kernel (Python and C#/.NET)**

- **Covers:** Enterprise-grade agent framework from Microsoft. Model abstraction as connectors (OpenAI, Anthropic, Hugging Face, Ollama). Memory via semantic stores. Plugin model for tool calling. v1.0 stable.
- **Language fit:** Primary targets are Python and C#/.NET. Not TypeScript-first.
- **Infrastructure as Configuration fit:** Good; connectors are swappable by config. Designed for enterprise multi-model deployments.
- **Assessment:** Credible but heavyweight. Less community momentum in the Python agent space compared to LangGraph and PydanticAI. No significant advantage for AI Council specifically.

**7. LlamaIndex Agents / Haystack Agents**

- LlamaIndex Agents: RAG-first framework; agent and workflow capabilities exist but are secondary to retrieval pipelines. Not designed for multi-agent conversational turns.
- Haystack: Best suited for search/QA and evaluation-heavy teams. Not a natural fit for conversational multi-agent orchestration.
- Neither is a strong candidate for AI Council's primary agentic needs.

**Cross-reference:** RQ-A12 covers the no-framework option in depth.

### RQ-A12 — "No framework" option

**Status:** Complete

Is there a strong case for not adopting any agentic framework at all, on the grounds that AI Council's agentic behaviours (Persona dispatch, turn-taking, memory, Review Agent) are narrow and well-defined enough that a bespoke implementation would be simpler, more controllable, and more portable than any framework? What are the honest costs of that approach — specifically, what LangChain/LangGraph primitives would have to be re-implemented by hand, and is that re-implementation non-trivial for any of AI Council's specific needs?

**Research findings:**

*The case for no framework:*

AI Council's agentic behaviours are narrow and well-specified:
- Persona dispatch: call a model with a system prompt and message history. This is a single SDK call.
- Round-Robin: a for-loop over ordered personas.
- P2P: a while-loop with a next-speaker function, a turn counter, and an interrupt check.
- Review Agent (nightly): a for-loop over concluded conversations and personas.
- Mentor memory: three specific data structures with defined transition logic.
- Orchestrator: a post-message model call with a suggestion output.

None of these individually requires a framework. The core value proposition of a framework is that it handles the cross-cutting concerns the project does not want to implement: state persistence, streaming, retry logic, observability, and (for LangGraph specifically) pause/resume.

*What would have to be re-implemented by hand:*

**1. State persistence / pause-resume (non-trivial).** LangGraph's checkpointer provides conversation state persistence across process restarts and pause/resume for P2P exchanges. Without it, the project must implement: serialise conversation state to the database, restore it on process start, detect an interrupt signal and write state, accept a resume signal and restore state. This is around 200-500 lines of well-understood CRUD code — not impossible, but not trivial. The correctness requirements are high (no state corruption, idempotent recovery).

**2. Streaming (moderate).** Streaming a model response token-by-token to the frontend requires reading an async generator from the SDK and forwarding it over SSE or WebSocket. LangChain/LangGraph provides a uniform streaming interface across providers. Without it, each provider SDK has slightly different streaming APIs (OpenAI uses `stream=True`, Anthropic uses `with client.messages.stream()`, Ollama uses its own). A thin wrapper around each provider's streaming API is around 50-100 lines per provider, but must be maintained as provider SDKs evolve.

**3. Retry / error handling (moderate).** Provider SDKs raise different exception types for rate limits (429), timeouts, and server errors. A unified retry policy must be implemented. LangChain provides this for free. The cost is small but real.

**4. Observability (moderate).** Without a framework, the project must instrument its own model calls (log prompt, response, token count, latency) per the requirements for Review Agent evidence and debugging (RQ-A15). Custom middleware or callbacks on each model call site. An OpenTelemetry instrumentation library (OpenLLMetry) can instrument provider SDK calls without a framework, reducing this cost.

**5. Soft throttle (non-trivial, but same cost with or without a framework).** Detecting "diminishing novelty" or topic drift in P2P requires the same LLM call or heuristic whether a framework is used or not. This is not a re-implementation cost specific to the no-framework choice.

*What is NOT non-trivial to re-implement:*

- Prompt construction: Python f-strings or a `string.Template` class is sufficient. No framework needed.
- Message history management: a list of dicts following the standard `{"role": ..., "content": ...}` schema, written to a database. Not non-trivial.
- Turn-taking loops: idiomatic Python or TypeScript async code. Not non-trivial.
- Review Agent batch job: a plain async loop. Not non-trivial.
- Mentor memory layer management: database reads/writes per defined transition rules. Non-trivial in terms of business logic, but not framework logic.

*Honest assessment:*

The no-framework option is viable. The hardest missing piece is conversation state persistence and pause/resume for P2P, which is implementable in application code (around 300-500 lines of purposeful CRUD and async state management). The rest — streaming, retry, prompt construction — are moderate costs. The advantages are: no LangChain Inc. dependency, no framework API churn, smaller dependency tree, simpler debugging, and complete control over the abstraction boundary (Infrastructure as Configuration is trivially satisfied by the project's own design).

The disadvantages are: the development team must implement and maintain the persistence, streaming, and retry infrastructure that frameworks provide. If the team is small or the timeline is tight, this is a real cost.

*Community evidence:* Experienced engineers who have moved away from LangChain report that building a "thin layer over native SDKs" adds one additional day of initial setup but saves weeks of debugging abstraction layers in production. Direct API calls showed 40% performance improvements over framework abstractions in one reported benchmark (community finding, not formally benchmarked).

### RQ-A13 — Lock-in and migration risk

**Status:** Complete

If LangChain and/or LangGraph are adopted, how tightly does the project become coupled to them? If a future version of LangChain changes API shape, or if the project decides to migrate off the framework entirely, what does the exit path look like? Does the Infrastructure as Configuration principle give us enough insulation, or would agent-layer abstractions also be needed?

**Research findings:**

*Historical coupling pattern:*

LangChain has had significant API churn in its history. The deprecation of `ConversationBufferMemory`, `AgentExecutor`, `LLMChain`, and `ConversationChain` (all deprecated or removed as of v0.3.x) required substantial migration work for projects that used them. Community feedback (as of 2025) consistently identifies "LangChain updates break everything constantly" and "migration docs are garbage" as recurring pain points. The `langchain-core` package was separated to provide a more stable base, and the v1.0 release in October 2025 included a stability commitment (no breaking changes until v2.0). This commitment was recent at the time of research.

*What creates coupling:*

The more AI Council's code directly imports and calls LangChain/LangGraph types and functions in application logic, the higher the migration cost. Coupling surfaces are:

- **LangChain message types** (`HumanMessage`, `AIMessage`, `SystemMessage`): Used everywhere model calls are made. These are `langchain-core` types. Replacing them requires changing every call site.
- **LangGraph `StateGraph` and node definitions**: If conversation graphs are defined in application code using LangGraph's API, migrating off LangGraph means rewriting the graph as imperative application code — the business logic is preserved but the framework wiring must be replaced.
- **LangGraph checkpointer**: If conversation persistence is provided by the checkpointer, migrating off LangGraph requires replacing the checkpointer with bespoke database persistence. This is the highest migration cost item.
- **LangChain `ChatPromptTemplate`**: Replacing with f-strings or another templating library is low-cost.

*Does Infrastructure as Configuration provide enough insulation?*

Partially. Infrastructure as Configuration insulates against **model provider lock-in** — switching from OpenAI to Anthropic to Ollama requires only config changes, and this holds with or without LangChain. However, it does **not** insulate against **framework lock-in**. The Infrastructure as Configuration principle governs model selection, not the orchestration layer.

To insulate against LangGraph lock-in, **agent-layer abstractions** would also be needed: internal interfaces (e.g. `ConversationOrchestrator`, `StateRepository`) that the application code calls, with LangGraph as one implementation of those interfaces. This adds an additional abstraction layer but makes the LangGraph dependency replaceable.

*The exit path:*

If LangGraph is adopted without internal abstraction layers:
- Exiting LangGraph means replacing every graph definition, every `interrupt()` call, and the checkpointer with bespoke application code. Estimated scope: medium (weeks, not months), because the business logic in graph nodes is preserved.
- Exiting LangChain's `langchain-core` message types means a mechanical search-and-replace across all model call sites. Low cost if message types are only used at the model call boundary.

If LangGraph is adopted with an internal `ConversationOrchestrator` abstraction layer:
- The exit path is replacing the LangGraph implementation of the interface with a bespoke implementation. Application business logic is entirely unaffected.
- The cost of the abstraction layer itself is around 200-400 lines of interface and adapter code.

*Versioning risk:*

LangGraph v1.0 was released in October 2025 with a no-breaking-changes-until-v2.0 commitment. LangChain 1.0 carries the same commitment. This reduces (but does not eliminate) the churn risk for new projects starting in 2026. Both packages are maintained by a single commercial entity (LangChain Inc.) funded by VC; the risk of commercial discontinuity or direction change exists at the ecosystem level.

*Assessment:* Infrastructure as Configuration is necessary but not sufficient for framework migration safety. Internal agent-layer abstractions would meaningfully reduce LangGraph lock-in, at a modest design cost. Whether that cost is worth paying is a decision for the developer.

### RQ-A14 — Local LLM compatibility

**Status:** Complete

AI Council must be able to run against a locally-hosted LLM from day one (FR-21.2, NFR-7, Section 1 of the overview). Do LangChain and LangGraph, in their current state, work reliably with common local-LLM runtimes (Ollama, llama.cpp server, vLLM, LM Studio, LocalAI)? Are there structured-output or tool-calling features that LangChain/LangGraph rely on that some local models do not support, and if so, how would that affect AI Council's agentic behaviours?

**Research findings:**

*LangChain integration status per local runtime (confirmed as of April 2026):*

- **Ollama:** First-class LangChain integration via `ChatOllama` (Python) / `ChatOllama` from `@langchain/ollama` (TypeScript). Ollama also exposes an OpenAI-compatible API, so `ChatOpenAI` with `base_url="http://localhost:11434/v1"` works as an alternative. `init_chat_model(model_provider="ollama")` is supported.
- **llama.cpp server:** LangChain has a `LlamaCpp` class in `langchain_community`, but as of early 2026 llama.cpp server also exposes an OpenAI-compatible API endpoint. Using LangChain's `ChatOpenAI` pointed at `http://localhost:8080/v1` is the recommended pattern — the dedicated `LlamaCpp` class requires in-process model loading (not server mode) and has been less actively maintained.
- **vLLM:** OpenAI-compatible API. Works with `ChatOpenAI` pointing at the vLLM endpoint. Also has a dedicated `ChatVLLM` in `langchain_community`.
- **LM Studio:** OpenAI-compatible API. Works with `ChatOpenAI` at the LM Studio local endpoint.
- **LocalAI:** OpenAI-compatible API. Works with `ChatOpenAI` at the LocalAI endpoint.

*Pattern:* All major local runtimes expose an OpenAI-compatible HTTP API. The practical approach is to use `ChatOpenAI` (or `init_chat_model(model_provider="openai")`) with a `base_url` set to the local server address. This works with LangChain and LangGraph without any framework changes — only the config changes. This directly satisfies Infrastructure as Configuration.

*Structured output compatibility:*

LangChain's `.with_structured_output()` uses two mechanisms depending on the model:
1. **Native function/tool calling** (OpenAI-style JSON schema in the API request). Supported by Ollama for models trained with function-calling (Llama 3.1, Mistral, Qwen2.5, others). **Not supported** by all local models — models without function-calling training will ignore the schema or hallucinate structure.
2. **JSON mode** (instruct the model in the prompt to return JSON; parse the output). Less reliable but works with any model.
3. **Constrained generation** (grammar-based token-level constraint): llama.cpp's GBNF grammar support (March 2026: autoparser merged, new models get structured output automatically). Not exposed through LangChain's standard interface — requires direct llama.cpp server API calls.

*Implication for AI Council:* AI Council needs structured output for the Automatic Summary, Review Agent findings, Episodic Memory compression, and Orchestrator suggestions (see RQ-C3). If the configured local model does not support function calling, the project must fall back to prompt-based JSON output with parsing — which is less reliable and requires a parsing fallback strategy. This is a capability gap that the model abstraction layer must handle: the structured output request should degrade gracefully when the model does not support tool calling, not throw an unhandled error.

*Tool calling compatibility:*

AI Council's Persona responses do not use tool calling (Personas are pure chat). The Orchestrator, Review Agent, and Mentor memory compression do not require tool calling — they require structured output, which is a related but distinct concern addressed above. If the project avoids using LangGraph's tool-calling infrastructure for these functions (using prompt-based structured output instead), local LLM compatibility is maximised.

*Streaming compatibility:*

Ollama, llama.cpp server, vLLM, and LM Studio all support streaming over their OpenAI-compatible API. Streaming works with LangChain's `.stream()` via `ChatOpenAI` at a local endpoint. No known incompatibilities.

*Summary of risk:* The primary compatibility gap is **structured output via function calling** on models that do not support it. A fallback parsing strategy is required and must be part of the model abstraction interface design (RQ-C1, RQ-C3). All other LangChain/LangGraph features (chat calls, streaming, basic context injection) work reliably with local runtimes via the OpenAI-compatible API.

### RQ-A15 — Observability, debuggability, and testability

**Status:** Complete

AI Council needs to be able to reason about what happened in a Conversation — for Review Agent evidence, for Context Panel injection correctness, and for debugging turn-taking behaviour. How well do LangChain and LangGraph support local, first-party, privacy-respecting observability (trace of prompts sent, decisions made, tokens used) without mandating a cloud service such as LangSmith? How testable is a LangGraph multi-agent flow in unit tests — can graph execution be deterministically driven with a fake model for Persona response generation?

**Research findings:**

*Observability without LangSmith (cloud):*

LangSmith is LangChain Inc.'s hosted observability product. It is **not required** — it is opt-in via environment variables (`LANGCHAIN_TRACING_V2=true`, `LANGCHAIN_API_KEY`). Without these vars, no data leaves the process.

Local-first observability options:

1. **LangChain callbacks.** LangChain's callback system (`BaseCallbackHandler`) fires events for each chain start/end, LLM start/end, and tool call. A custom callback can log prompts, responses, token counts, and decision points to local files or a local database without any external dependency. This is the lightest-weight option and is fully privacy-respecting.

2. **Arize Phoenix (open-source, local-first).** An open-source observability tool that runs locally (in-process or as a local server), instruments LangChain and LangGraph via OpenTelemetry, and provides a UI for trace inspection. No data leaves the machine. Confirmed as production-viable for local deployments as of 2025.

3. **OpenLLMetry.** Open-source OpenTelemetry instrumentation for LLM calls. Instruments LangChain/LangGraph and sends spans to any OTel backend (local Jaeger, Zipkin, etc.) without cloud dependency.

4. **LangSmith self-hosted.** LangSmith offers a self-hosted deployment (bring-your-own-cloud / on-premises). More complex to operate but provides the full LangSmith UI without data leaving the organisation.

*LangGraph-specific observability:*

LangGraph's graph execution produces a stream of events (one per node transition). Consuming this stream (`graph.stream(inputs, config)`) yields node outputs in order. This provides a built-in execution trace at the application layer — no external observability tool required to understand what happened in a graph run. For AI Council's Review Agent evidence capture, the node output stream (which includes the exact prompt sent and the response received) can be logged per Persona evaluation without any framework instrumentation.

*Debugging complexity:*

A noted criticism of LangChain/LangGraph in production is that "abstraction layers make troubleshooting extremely difficult — tracing actual API calls becomes nearly impossible." This applies particularly to complex chains with many nested calls. AI Council's use of LangChain is limited (LCEL chains inside LangGraph nodes), which reduces this risk compared to heavily nested chain architectures. The LangGraph execution model (nodes as plain functions) is more debuggable than opaque chain pipelines.

*Testability of LangGraph multi-agent flows:*

LangGraph's design — nodes as plain functions, state as a `TypedDict` — is inherently unit-testable:

- **Fake model injection.** LangChain provides `FakeListLLM` / `FakeListChatModel` that return predefined responses in sequence. A LangGraph node that takes a `BaseChatModel` as input can be tested by injecting a `FakeListChatModel` with scripted responses. This drives graph execution deterministically without any model API calls.
- **Node-level unit tests.** Individual node functions can be tested in isolation by passing constructed state dicts and asserting on output state. No graph execution infrastructure needed.
- **Graph-level integration tests.** A compiled graph with an `InMemoryCheckpointer` and a `FakeListChatModel` runs entirely in-process, deterministically, and without network calls. Tools like `fasteval` (community) provide trajectory evaluation harnesses for asserting on node execution order and state transitions.
- **Mock LLM server.** `llmock` (by CopilotKit, open-source) is a real HTTP server on a local port that returns scripted responses for any provider SDK call. Used in production test suites for LangGraph-based systems.

*Limitations:*

- Fake models return scripted responses; they do not simulate model reasoning. Tests verify graph routing and state management, not model quality.
- Complex multi-agent flows with conditional routing require carefully scripted fake responses to exercise all branches — the test author must reason about execution order in advance.
- LangGraph lacks a first-party test runner or assertion library; the community patterns are sufficient but require custom setup.

*Summary:* Observability without cloud dependency is fully supported via LangChain callbacks, Arize Phoenix, or OpenLLMetry. LangGraph is unit-testable with fake model injection and `InMemoryCheckpointer`. Neither LangSmith nor any cloud product is required for either capability.

---

## Group B: Context Window Management (FR-20.2 Flag)

### RQ-B1 — Context window management strategies

**Status:** Complete

FR-20.1 and FR-20.2 require that Conversation history be automatically summarised or truncated when it grows beyond the deployed model's context window, while preserving the Context Panel and the most recent exchanges (FR-7.2). What are the standard approaches for this problem (sliding-window truncation, recursive summarisation, hierarchical summarisation, hybrid approaches), and what are the tradeoffs of each in terms of information retention, latency, cost, and determinism?

**Research findings:**

Five canonical approaches exist, with hybrids being the dominant production pattern:

**1. Sliding-window truncation (naive)**

Keep only the last N tokens or last N messages; discard everything older. The `TruncationStrategy` pattern (named in the agent-framework literature) performs coarse-grained removal of the oldest message groups until a target count is reached.

- *Information retention:* Poor. Any detail not in the retained window is permanently gone. Critical facts mentioned early in a conversation — user corrections, persona configuration rationale — are silently lost.
- *Latency:* Near-zero overhead; purely algorithmic.
- *Cost:* Lowest possible — no additional model calls.
- *Determinism:* High. Output is fully predictable given input length.
- *Failure mode:* In a multi-Persona conversation, the window may cut mid-exchange, breaking conversational coherence.

**2. Rolling single-pass summarisation**

When the history approaches a threshold (commonly 70-80% of context capacity), invoke the model to summarise the oldest portion of history. Keep the summary plus the verbatim recent exchanges. On the next trigger, summarise the oldest remaining verbatim segment and prepend to the previous summary, or replace the previous summary.

- *Information retention:* Moderate. Summary fidelity depends on the model; fine-grained details and exact phrasing are lost. If the summary omits something, it is effectively forgotten.
- *Latency:* Adds one model call per compression event. Call happens at trigger time, potentially adding perceptible delay before the next user response.
- *Cost:* Moderate — one additional model call at each compression trigger. For a local LLM, this is an internal cost; for a cloud API, it is billable.
- *Determinism:* Low-to-moderate. Summary content varies with model temperature; setting temperature to zero improves consistency but does not eliminate variation across model versions.
- *Failure mode:* Compounding summarisation error — if early summaries are inaccurate, later summaries compound the error. Also: the summary is the sole record of what was compressed; there is no way to re-derive what was lost.

**3. Recursive (incremental) summarisation**

A specific variant of rolling summarisation where each new compression step takes the *previous summary* plus the next unsummarised segment as input, producing an updated summary. Published research (arxiv 2308.15022, published in Neurocomputing 2025) demonstrates this maintains stronger long-term conversational coherence than single-pass summarisation.

- *Information retention:* Better than single-pass; the rolling update anchors each compression step on accumulated prior context, reducing drift.
- *Latency:* Same as rolling summarisation — one model call per compression event.
- *Cost:* Same as rolling summarisation.
- *Determinism:* Lower than single-pass. Each compression builds on the previous, so early randomness propagates. Temperature=0 is strongly recommended. Setting temperature to zero for compression prompts is confirmed as a production pattern.
- *Failure mode:* Cumulative error propagation — a misleading early summary contaminates all later summaries. There is no clean rollback point.

**4. Hierarchical summarisation**

Maintain multiple levels: verbatim recent turns (Level 0), compressed summaries of older recent-segment blocks (Level 1), and coarser summaries of Level 1 summaries (Level 2). Older content is always compressed before reaching the raw discard boundary.

- *Information retention:* Better than single-pass; granularity is preserved at the level appropriate to recency. Most production multi-agent memory systems (including LangGraph's documented memory patterns) use a two-level hierarchy (verbatim + summary), which is the minimal viable hierarchical design.
- *Latency:* Higher than single-pass; multiple compression levels may need to fire at once.
- *Cost:* Higher — potentially multiple model calls per compression event.
- *Determinism:* Lower — each level compounds model stochasticity. Errors propagate across levels.
- *Best fit:* Structured, document-like conversations where section-level summarisation is meaningful. Less obviously beneficial for free-form chat.

**5. Importance-scored selective retention**

Score each message by recency, semantic relevance to the current topic, entity mentions (names, facts), and interaction metadata (e.g., user corrections). Retain the top-scoring messages within the token budget; discard the rest. Does not require a model call for the selection step (heuristic scoring), but may use a model call for relevance scoring.

- *Information retention:* High, for content that scores well. Relevance-scoring can preserve early facts that a sliding window would lose.
- *Latency:* Depends on scoring method. Heuristic scoring is fast; model-based relevance scoring adds latency comparable to a model call.
- *Cost:* Low-to-moderate depending on scoring method.
- *Determinism:* High for heuristic scoring; lower for model-based scoring.
- *Failure mode:* Scoring logic errors silently drop important messages. Requires tuning for each use case.

**6. Routing to a larger-context model**

When the context window is exceeded, switch to a model with a larger context window (e.g., a 128K model instead of a 32K model).

- *Information retention:* Complete — no information is lost.
- *Latency:* Variable — depends on the larger model's throughput.
- *Cost:* Significantly higher for cloud models; may not be available at all for local deployments where only one model is configured.
- *Determinism:* High.
- *Infrastructure as Configuration relevance:* This approach requires the model abstraction layer to support switching models mid-conversation based on context length. This is a non-trivial extension of the model abstraction interface (see RQ-C1). It also violates a subtle Infrastructure as Configuration constraint: the fallback model must also be operator-configurable, not hardcoded. Only viable if the operator has configured a fallback model.

**Dominant production pattern (hybrid):**

Most production systems use a combination: keep the last N verbatim messages unconditionally, apply rolling or recursive summarisation to everything older, and optionally score messages for importance before compression to avoid compressing high-value content prematurely. The `TokenBudgetComposedStrategy` pattern chains multiple strategies (importance scoring → summarisation → truncation fallback) so that deterministic truncation is a last resort rather than the primary mechanism.

**AI Council-specific notes:**

- The Mentor's three-layer memory (FR-18) is essentially a bespoke hierarchical system: verbatim Working Memory, rolling Episodic summaries, and permanent Semantic facts. The general RQ-B1 strategies apply directly to the Working→Episodic compression step.
- Recursive summarisation at temperature=0 is the closest to deterministic behaviour; it is the pattern most consistent with producing stable Episodic Memory entries.
- The Context Panel must survive any compression strategy — see RQ-B2.
- Research (Paulsen 2025, cited by Atlan) found accuracy degradation in many models well below their advertised context window limits. This suggests conservative triggering thresholds (at 70-80% capacity rather than 100%) are warranted regardless of which strategy is chosen.

### RQ-B2 — Guaranteed Context Panel inclusion

**Status:** Complete

FR-7.2 states the Context Panel must be the last element evicted under context pressure. How is this typically implemented — as a priority-ordered context assembly step before every model call, as a reserved portion of the token budget, or both? Does any existing framework provide this guarantee out of the box, or must it be enforced in a bespoke context-assembly layer?

**Research findings:**

*Does any existing framework provide this guarantee out of the box?*

No. Neither LangChain, LangGraph, nor any other major framework provides a built-in mechanism for guaranteeing that an arbitrary piece of user-authored content (like the Context Panel) is always included. What frameworks provide is narrower:

- **LangChain `trim_messages`** (Python and TypeScript): The `include_system=True` parameter with `strategy="last"` preserves the `SystemMessage` at index 0 of the message list when trimming to a token budget. This is the closest native mechanism. However, it only protects the role-typed `SystemMessage` at position 0 — it cannot selectively protect other message types or arbitrary content within the history. It provides no protection for a user-authored Context Panel that is injected into the middle of the message history.
- **Anthropic's context awareness** (Claude Sonnet 4.6+): Newer Claude models inform themselves of the remaining token budget via `<system_warning>` injections. This helps the model manage its own output length but does not guarantee what the application includes in the input.
- **Priority-assembly pattern (community/bespoke)**: The standard production pattern found in the community involves a `PriorityAssembler` class with REQUIRED > HIGH > MEDIUM > LOW priority levels. REQUIRED items are assembled first and consume their token quota unconditionally; lower-priority items fill the remainder. System prompts and any other "always include" content are marked REQUIRED. This is a bespoke pattern, not a framework feature.

*Standard implementation approaches:*

**Approach 1 — Reserved token budget (additive):**

Calculate the token cost of fixed elements (System Prompt, Context Panel, current user message) first. Treat their total as a fixed reservation subtracted from the model's total context window. The remainder is the "history budget" for conversation messages. The history budget is filled by trimming from the oldest messages inward until it fits. This is the most common production pattern for guaranteed inclusion.

*Guarantees:* If the fixed elements individually fit within the context window, they are always included. If their combined token cost exceeds the window (possible if the Context Panel has grown very large), the system must either refuse to proceed or truncate the Context Panel — this is an edge case requiring explicit policy.

*Implementation:* Requires a context-assembly layer that computes token costs for each element before constructing the API request. Must run before every model call.

**Approach 2 — Priority-ordered assembly (additive):**

Assign each element a priority tier. Build the context array from highest to lowest priority, computing a running token count, and stop when the budget is exhausted. Elements that don't fit are dropped. Context Panel is REQUIRED tier; message history is MEDIUM or LOW tier.

*Guarantees:* Same as Approach 1. The Context Panel is the last thing trimmed. If the system prompt + context panel exceed the window, a policy decision is needed.

*Implementation:* Slightly more general than the reserved-budget approach; the priority system extends more naturally to future elements without recalculating fixed reservation sizes.

**Approach 3 — Structural placement at assembly time (simplest):**

Always construct the message array in this order: (1) System Prompt message, (2) Context Panel as a system or user message immediately after the system prompt, (3) trimmed/summarised conversation history. Because trim happens to the history segment only and the first two segments are pre-assembled, the Context Panel survives any history trimming by construction.

*Guarantees:* Context Panel is never in the set of messages passed to the trimmer; it is pre-placed outside the trimmed segment. This is structurally correct and requires no token arithmetic for the guarantee itself.

*Implementation:* The simplest approach. The application code must ensure the assembler always uses this ordering and never passes the Context Panel into the trimmed message list.

*Which approach fits AI Council?*

AI Council requires the Context Panel to always be present and to survive context pressure (FR-7.2). Approach 3 (structural placement) is the simplest path to correctness: if the Context Panel is never placed in the trimmable segment of the message array, it cannot be trimmed. The reserved-budget approach (Approach 1) is a more complete solution because it also accounts for edge cases where the Context Panel itself is very large, but requires explicit token arithmetic.

Both approaches must be enforced in a bespoke context-assembly layer — no framework provides this automatically.

*Infrastructure as Configuration note:* The context-assembly layer must not hard-code the model's context window size. The window size must come from the configuration (set per model endpoint — see RQ-C2, RQ-B3). This means the assembly layer computes: `available_for_history = configured_window_size - reserved_token_estimate`, where the reserved estimate covers system prompt + context panel + safety margin.

*Interaction with RQ-B1 strategies:* Whichever compression strategy is chosen (RQ-B1), the compression trigger and the assembly-time guarantee are separate concerns. Compression manages the history buffer; the assembly-time guarantee ensures the Context Panel is prepended outside the history buffer. They can coexist independently.

### RQ-B3 — Token counting and budget enforcement

**Status:** Complete

To manage context window limits reliably, the system must be able to count tokens per model. How is this done when the configured model is unknown at build time (local vs cloud, different tokenisers)? Is there a common library or pattern that provides a model-agnostic token count with acceptable accuracy, and how does this interact with the Infrastructure as Configuration principle?

**Research findings:**

*The tokeniser problem:*

Token counts vary between models because they use different tokenisers. A 1,000-token message on GPT-4o (o200k_base BPE) might be 1,200 tokens on Claude (SentencePiece variant) and 900 tokens on Gemini. There is no universal token count. This creates a tension with Infrastructure as Configuration: if the model is selected from config at runtime, the tokeniser needed to count tokens accurately is also selected at runtime.

*Provider-specific approaches:*

- **OpenAI models:** `tiktoken` (Python, MIT licence) is the official tokeniser library. Supports `cl100k_base` (GPT-3.5, GPT-4) and `o200k_base` (GPT-4o, GPT-4o-mini). Accurate and fast (C extension). Also available as `js-tiktoken` for TypeScript.
- **Anthropic (Claude):** The official `anthropic` SDK exposes `messages.countTokens()` (Python) / `messages.countTokens()` (TypeScript) as an API call — an actual request to Anthropic's API that returns exact token counts. This is billing-accurate but requires a network call. Claude models use a SentencePiece-derived tokeniser. `tiktoken` is not accurate for Claude.
- **Ollama:** As of August 2025, a PR was merged adding `/api/tokenize` and `/api/detokenize` endpoints (PR #12030). These expose model-aligned tokenisation without running inference. Confirmed status: merged and available in Ollama as of late 2025. Ollama also returns token counts in completion responses (`prompt_eval_count`, `eval_count`). Pre-flight token counting via `/api/tokenize` is available for installed models.
- **llama.cpp server, vLLM, LM Studio, LocalAI:** All expose OpenAI-compatible APIs; token counts are returned in completion responses. Pre-flight tokenisation endpoints vary by runtime; llama.cpp server has a `/tokenize` endpoint. These are not standardised across all local runtimes.
- **HuggingFace models (direct):** Use the model-specific tokeniser from the `transformers` library (`AutoTokenizer.from_pretrained(model_name)`). Accurate for any HF model but requires downloading the tokeniser files. Not relevant for server-mode local LLM deployments.

*Model-agnostic libraries and fallback approaches:*

- **LiteLLM's `token_counter` function:** Provides a `token_counter(model, messages)` utility that selects the tokeniser based on the model name (Anthropic, Cohere, Llama2, Llama3, OpenAI are natively supported) and falls back to `tiktoken` for unrecognised models. This is the most complete single-library option for model-agnostic counting. The tiktoken fallback introduces inaccuracy for non-OpenAI models — for a 1,000-token Llama3 message, tiktoken may return 900-1,100 tokens depending on content.
- **LangChain `trim_messages`:** The `token_counter` parameter accepts: (1) a `BaseChatModel` instance (uses its `get_num_tokens_from_messages` method), (2) a custom callable `(messages) -> int`, or (3) the literal `'approximate'` (uses `count_tokens_approximately`, a character-based heuristic added to `langchain_core`). The `'approximate'` option avoids all network calls and library dependencies at the cost of accuracy (~4 characters per token is the heuristic). The `ChatAnthropic` model's `get_num_tokens_from_messages` calls Anthropic's API — it is accurate but adds latency and requires network access.
- **`count_tokens_approximately` (LangChain core):** A new function (added to `langchain_core` after the v0.3 series) that uses a character-count heuristic. Useful for rough triggering heuristics but not for precise budget enforcement.

*Interaction with Infrastructure as Configuration:*

Infrastructure as Configuration requires the model to be selectable from config at runtime. Token counting must follow the same pattern: the token counter implementation must be selected at runtime based on the configured model, not at build time. This means:

1. The application's context-assembly layer must receive the model type from config and select the appropriate token counter (tiktoken for OpenAI, Anthropic API for Claude, Ollama's `/api/tokenize` for Ollama, fallback heuristic for unknown).
2. This is not provided automatically by any single library; it requires a dispatch mechanism in the application layer.
3. LiteLLM's `token_counter` is the closest to a ready-made dispatch solution, but its fallback to tiktoken for non-supported models introduces inaccuracy.

*Practical accuracy requirements:*

For compression triggering (fire compression at 75% of window) ± 10% accuracy is acceptable — a heuristic or tiktoken fallback is sufficient. For hard budget enforcement (never send more than N tokens) exact counts are needed — provider-specific counting methods or post-send usage feedback are required.

A common production pattern: use a heuristic or approximate count for compression triggering; use the actual token counts returned in the completion response (`usage.prompt_tokens`) to calibrate and correct the assembly layer over time. This avoids pre-flight counting latency for every call while catching systematic over/under-counting.

*Known gap — Infrastructure as Configuration concern:*

If the application hard-codes `model_provider = "openai"` in the token-counter dispatch to select tiktoken as default, this is a soft Infrastructure as Configuration violation — not in model selection, but in the ancillary token-counting path. The dispatch must read from the same configuration source as the model selection.

*Cross-reference:* RQ-C2 (configuration schema for model selection) must include the context window size as a configurable field, since neither tiktoken nor any fallback library can reliably derive the window size from a local model name.

### RQ-B4 — Multi-Persona context sharing

**Status:** Complete

FR-5.16 requires that each Persona in a multi-Persona Conversation receives the full message history (including messages from all other Personas) but must never receive any other Persona's System Prompt. How is this typically implemented in agent frameworks, and does LangChain/LangGraph enforce this boundary natively or does it need to be enforced at the context-assembly layer?

**Research findings:**

*Does any framework enforce this boundary natively?*

No. Neither LangChain, LangGraph, PydanticAI, Mastra, AG2, nor any other surveyed framework enforces system-prompt isolation between agents in a shared-history multi-agent conversation. This boundary is universally the application layer's responsibility.

This is a confirmed active gap: a PydanticAI GitHub issue (#967, February 2026) specifically requests framework-level support for "cleanly adding or removing system prompts when managing multi-agent workflows." The issue documents that developers currently manipulate protected member variables directly to achieve this, and notes that framework-level enforcement is lacking. The same thread notes an additional complication: some framework optimisations (token caching) are built on the assumption that the system prompt is stable across a session — if each Persona call uses a different system prompt, cache misses increase.

LangGraph's shared-history pattern (documented by LangChain): by default, all node outputs — including the messages from each agent node — are appended to a shared `messages` list in the graph state. The system prompts for each agent are not stored in the shared state; they are constructed locally within each node function. However, LangGraph provides no enforcement or validation that one agent cannot read another's system prompt — that boundary exists only by convention in how node functions are written.

*Standard implementation pattern:*

The universally documented approach is context-assembly-time injection:

1. **Single shared message store.** All conversation messages (from all Personas, the user, and system events) are stored in a single ordered message list (or database table) keyed by conversation. Every message is attributed to its source (user, Persona name, system).
2. **Per-Persona context assembly.** When it is Persona A's turn to respond, the context-assembly layer constructs the API request as:
   - `[SystemMessage(content=persona_a.system_prompt)]`
   - `[...shared_message_history_with_persona_attributions...]`
   - `[optional: Context Panel as a system or high-priority user message]`
   Persona A's system prompt is the first element; no other Persona's system prompt appears anywhere in this array.
3. **Attribution in shared history.** When Persona B's message appears in the shared history (which Persona A can see), it appears as an `AssistantMessage` or `HumanMessage` attributed by name (e.g., content begins with "Persona B: ..."), not as a system message. System prompt content is structurally impossible to confuse with message content in this model because system prompts are never placed into the message history.

This pattern makes system-prompt leakage structurally impossible rather than merely convention-dependent: the system prompt is never stored in the shared message history, only in the Persona record. The assembly layer reads it from the Persona record at call time and places it only at position 0 of the API request.

*How this interacts with LangGraph:*

In a LangGraph implementation, each Persona node function would:
1. Look up the Persona's System Prompt from the application's Persona store (keyed by Persona ID).
2. Construct a `ChatPromptTemplate` with `SystemMessage(content=persona.system_prompt)` followed by the shared `messages` list from graph state.
3. Invoke the model with this prompt.

The shared `messages` in graph state contain only the conversation history (attributed utterances), not any system prompts. LangGraph state is the shared message store; each node constructs its own local prompt from it, adding its private system prompt fresh on each call.

*Risks to flag:*

1. **Persona attribution format in shared history.** The format used to attribute messages in the shared history matters. If Persona B's message is stored verbatim with no attribution prefix, Persona A receives it without knowing who said it — which is the desired behaviour for a natural-feeling conversation. If attribution is needed for Review Agent evidence (FR-15.2), it can be stored as metadata on the message record and stripped from the content in the context assembly. The attribution strategy is an application design decision.
2. **System prompt leakage via model outputs.** A model responding as Persona A may inadvertently summarise or reference its own system prompt in its output (a well-known failure mode called "system prompt leakage"). This is a model behaviour issue, not an architectural one — it cannot be guaranteed away by context assembly alone. System prompt wording that discourages self-referential disclosure reduces (but does not eliminate) this risk.
3. **Snapshot vs live system prompt.** FR-6.1 requires that each Conversation use the Persona's System Prompt as snapshotted at the time the Persona joined, not the live current System Prompt. The context-assembly layer must read from the Conversation's Persona snapshot, not from the live Persona record, for in-progress Conversations. This is a data-layer concern (see RQ-E4) but has assembly-layer implications.

*Cross-reference:*
- RQ-E4 (Conversation snapshot storage) — the system prompt in the shared history must come from the snapshot, not the live Persona.
- RQ-B2 — the Context Panel must survive context pressure and appears in the assembled context alongside the system prompt; its position must be after the system prompt.
- RQ-A4 — the model abstraction layer (RQ-C1) is the point at which per-Persona context assembly occurs; the interface must accept a fully-assembled message array, not raw Persona metadata, to keep assembly concerns in the application layer.

---

## Group C: AI Model Abstraction Layer (FR-21.2, NFR-3 Flags)

### RQ-C1 — Model abstraction interface shape

**Status:** Complete

What is the minimum viable shape of an internal AI model interface that satisfies FR-21.2 (swap local for cloud via config alone) and covers the operations AI Council actually needs: Persona response generation, Automatic Summary generation, targeted summary generation, Orchestrator suggestion prompts, Review Agent evaluation prompts, Mentor memory compression prompts, and Report generation? Should this be a single `generate(prompt, config) -> response` call, a richer chat-style interface, a streaming interface, or some combination?

**Research findings:**

*Industry convergence on a message-array interface:*

Every major LLM provider — OpenAI, Anthropic, Google, Mistral, Ollama, llama.cpp server — accepts the same OpenAI-compatible chat completion format: a `messages` array of role-tagged objects (`system`, `user`, `assistant`) plus per-call parameters (`temperature`, `max_tokens`, `stop`). This has become a de facto cross-provider standard. LiteLLM, LangChain's `BaseChatModel`, and Vercel's AI SDK all converge on this shape. A single-string `generate(prompt, config)` call is a step backward — it loses the system/user role distinction that is fundamental to per-Persona System Prompt injection and forces the caller to flatten structured conversation history into a string, losing type safety and role semantics. The correct minimum shape is `complete(messages: list[Message], params: ModelParams) -> CompletionResponse`.

*Operations AI Council actually needs and whether one interface covers them:*

All seven named operations (Persona response, Automatic Summary, targeted summary, Orchestrator suggestion, Review Agent evaluation, Mentor compression, Report generation) reduce to the same call shape: assemble a `messages` array, invoke the model, parse the response. The difference is in who assembles the messages and what they expect back:

- Persona response: multi-turn history array + System Prompt in `system` role → free-text `assistant` reply, possibly streamed.
- Summary / memory compression / Orchestrator suggestion / Review Agent evaluation / Report generation: one or two messages, structured output expected (see RQ-C3), no streaming needed.

This means the interface does **not** need two separate method signatures for streaming vs non-streaming. It needs one method plus a `stream: bool` flag (or an `astream()` variant), consistent with LiteLLM's `completion(stream=True)` and LangChain's optional `_stream` implementation. Callers that don't need streaming simply call the non-streaming variant; the Persona response path can call the streaming variant.

*Token count metadata:*

LangChain's `AIMessage` carries a `usage_metadata` field (`input_tokens`, `output_tokens`, `total_tokens`) populated from provider responses. LiteLLM's `ModelResponse` carries a `usage` object with `prompt_tokens`, `completion_tokens`, `total_tokens`. Both patterns confirm that token usage can be returned from the same call that returns content — no separate probe call is needed. The internal interface should surface this as a field on the response object (e.g. `response.usage`). This satisfies the RQ-B3 → RQ-C1 cross-reference: the abstraction must expose token count metadata from completion responses so that context-window management (Group B) can make informed truncation decisions.

*Minimum interface shape (confirmed pattern):*

```python
complete(messages, params) -> CompletionResponse
  # CompletionResponse: { content: str, usage: Usage, finish_reason: str }
  # Usage: { input_tokens: int, output_tokens: int }

stream(messages, params) -> AsyncIterator[str]
  # yields content deltas; usage available in a final chunk or via a separate call
```

The interface accepts a fully-assembled message array, keeping context-assembly in the application layer — satisfying the RQ-B4 → RQ-C1 cross-reference. The concrete provider implementations (`OllamaAdapter`, `OpenAIAdapter`, `AnthropicAdapter`) each translate from this internal shape to their provider's native protocol.

*LangChain's `BaseChatModel` as the interface:*

If LangChain is adopted (Group A decision), `BaseChatModel` is already this interface: `invoke(messages) -> AIMessage` (with `usage_metadata`), `stream(messages) -> Iterator[AIMessage]` (delta chunks). Custom models require only `_generate()` and `_llm_type` to be implemented — a clean extension point. An internal bespoke interface could mirror this shape without taking a LangChain dependency, which would satisfy the RQ-A13 → RQ-C1 cross-reference: an internal abstraction layer (`ConversationOrchestrator` / `StateRepository`) should insulate the application from the framework dependency so that the framework can be replaced without touching application code.

*Constraint check:* No violation of Infrastructure as Configuration detected — the interface shape does not reference any specific provider. The concrete adapter selected at runtime is a configuration concern (RQ-C2).

### RQ-C2 — Configuration schema for model selection

**Status:** Complete

What configuration fields are needed to describe a model endpoint such that the same interface works for "local LLM via Ollama", "local LLM via llama.cpp server", "OpenAI API", "Anthropic API", and similar? What is the minimum, and what is the shape (flat keys vs per-provider sub-sections)?

**Research findings:**

*De facto minimum field set:*

Both Ollama and llama.cpp expose OpenAI-compatible `/v1/chat/completions` endpoints. All major providers and their adapter libraries (LiteLLM, LangChain `init_chat_model`, Vercel AI SDK) converge on the same minimum config fields:

| Field | Required | Purpose |
| --- | --- | --- |
| `provider` | Yes | Selects the concrete adapter (`ollama`, `openai`, `anthropic`, `llama_cpp`) |
| `model` | Yes | Model name or tag (e.g. `llama3:8b`, `gpt-4o`, `claude-opus-4-5`) |
| `api_base` | Conditional | Base URL; required for local servers (default differs per provider) |
| `api_key` | Conditional | Bearer token; required for cloud APIs; Ollama accepts any string |
| `context_window` | Recommended | Maximum context in tokens; needed by Group B token-budget logic (RQ-B2 → RQ-C2) |

*Shape — flat vs per-provider sub-sections:*

Two credible shapes exist:

**Option A — flat top-level block (LangChain `init_chat_model` style):**

```yaml
model:
  provider: ollama
  model: llama3:8b
  api_base: http://localhost:11434/v1
  api_key: ollama
  context_window: 8192
```

Simple, validated with a single schema. Works when the application uses exactly one model. Becomes awkward if AI Council ever needs different models for different operations (e.g. a fast model for summarisation, a large model for Mentor).

**Option B — named model registry + active-model pointer (LiteLLM proxy style):**

```yaml
models:
  local_chat:
    provider: ollama
    model: llama3:8b
    api_base: http://localhost:11434/v1
    context_window: 8192
  cloud_summary:
    provider: openai
    model: gpt-4o-mini
    api_key: "env:OPENAI_API_KEY"
    context_window: 128000

default_model: local_chat
```

More powerful; enables per-operation model routing via config alone (satisfying FR-21.2 without code change). Adds schema complexity. V1 may only populate one entry, but the schema is future-proof.

*Context window as a config field:*

Neither Ollama nor llama.cpp server surfaces context window size in their API responses. The application cannot discover it dynamically — it must be declared in config. This confirms the RQ-B2 → RQ-C2 cross-reference: `context_window` must be an explicit field in the config schema so that token-budget management (Group B) can read it without making a probe call.

*Token-counter dispatch:*

The RQ-B3 → RQ-C2 cross-reference requires that the token-counter strategy align with the configured model. This means the config schema should either carry `tokenizer` as an optional field (to specify a HuggingFace tokenizer for a local model) or fall back to `tiktoken` cl100k as the default for cloud-API models. LiteLLM's `model_info.custom_tokenizer` field confirms this is a known pattern.

*Secrets handling:*

`api_key` should support environment variable indirection (`env:VAR_NAME`) to avoid hardcoding credentials in the config file. This is the pattern used by LiteLLM (`os.environ/KEY_NAME`) and is consistent with the NFR-7 local storage requirement.

*Constraint check:* The flat or registry shape is purely declarative. No code branching on environment name is required — the `provider` field selects the adapter class at bootstrap, satisfying Infrastructure as Configuration.

### RQ-C3 — Structured output requirements

**Status:** Complete

Several AI Council features need structured output from the model — the Automatic Summary (FR-10.1, with named fields), Review Agent findings (FR-15.2, with evidence and suggestion), Episodic Memory compression, Semantic Memory promotion, and potentially Orchestrator suggestions. How should structured output be obtained in a way that works with both local LLMs (which may not support function-calling) and cloud APIs (which do)? Is JSON-mode, tool-calling, constrained generation, or prompt-with-parse the most portable approach?

**Research findings:**

*Four approaches and their portability:*

**Tool calling (function calling):** Cloud APIs (OpenAI, Anthropic, Google) support tool calling natively and it is the most reliable method for those providers — the model selects a function and fills its parameters. However, tool calling is only available on models specifically fine-tuned for it. As confirmed in the RQ-A14 → RQ-C3 cross-reference, structured output via tool calling is unavailable on models not trained for it, so it cannot be the sole strategy.

**JSON schema / format mode:** Ollama supports a `format` parameter that accepts a full JSON schema, using constrained decoding (grammar-guided token sampling) to guarantee the output matches the schema structure. This is not the same as tool calling — it is schema-enforced generation. Most capable local models (Llama 3.x, Qwen 2.5, Gemma 3, Mistral) support this via Ollama's `format` field or equivalently via llama.cpp's `--grammar` or `response_format`. This is the most portable native mechanism for local models.

**Constrained generation libraries (Outlines, XGrammar):** Libraries like Outlines and XGrammar sit at the inference engine level and enforce grammar-constrained decoding with near-zero overhead. These are most relevant when the application controls the inference engine directly (self-hosted vLLM or llama.cpp). When using Ollama as a server, the constraint happens inside Ollama — the calling application does not interact with these libraries directly.

**Prompt-with-parse (fallback):** Prompt engineering instructs the model to respond in JSON, then the application parses and validates. Works with any model. Fragile: models can deviate from format, hallucinate field names, or produce trailing text. This must be the ultimate fallback for models that support neither tool calling nor schema-constrained output.

*Recommended pattern for AI Council — layered strategy:*

1. **Primary for cloud APIs:** Use the provider's native structured output / tool calling interface via LangChain's `with_structured_output(schema, method="tool_calling")` or the Instructor library's `client.chat.completions.create(response_model=MyPydanticModel)`. The Instructor library adds automatic retry-with-validation-error-feedback when the model returns an invalid schema, which is a useful safety net on top of either method.

2. **Primary for local models via Ollama:** Use Ollama's `format` parameter with a JSON schema object. Accessible via the OpenAI-compatible `response_format` field, so the same client code works for both cloud and local paths.

3. **Fallback for neither:** Prompt-with-parse using a `PydanticOutputParser` or equivalent, with explicit retry logic on validation failure.

The model abstraction interface should expose a `complete_structured(messages, schema, params)` method that internally selects the appropriate mechanism based on the configured provider's declared capabilities. This keeps the selection logic out of application code — satisfying Infrastructure as Configuration.

*LangChain's `with_structured_output`:*

`BaseChatModel.with_structured_output(schema)` accepts a Pydantic model or JSON Schema and dispatches to tool calling or JSON mode based on the model's declared capabilities. For models that declare neither, it falls back to prompt-with-parse via `PydanticOutputParser`. This is a confirmed, production-used layering pattern as of LangChain v0.3.x.

*Constraint flag (RQ-A14 → RQ-C3):*

This cross-reference is confirmed. The abstraction must not assume tool calling is available. Any model served via Ollama or llama.cpp that has not been fine-tuned for function calling will silently ignore tool definitions — the call may succeed but return free text. The safe universal fallback is JSON schema mode (via Ollama `format`) or prompt-with-parse. The application layer should never branch on provider name to select the strategy — instead, each adapter declares its capabilities and the `complete_structured` dispatch uses the declared capability set.

### RQ-C4 — Streaming vs. non-streaming

**Status:** Complete

Does AI Council need streaming responses for any feature (real-time Persona response rendering in Conversation view), or is non-streaming acceptable for V1? How does the choice affect the shape of the model abstraction interface and the frontend/backend transport contract?

**Research findings:**

*Is streaming required for V1?*

Streaming is not strictly required by any functional requirement, but non-streaming Persona responses in the Conversation view create a significant UX problem. Local LLMs in particular are slow: a 500-token response from a 7B model running on consumer hardware takes 6–15 seconds to complete. Without streaming the user sees nothing for that duration — a blank state that is indistinguishable from a hang. Research confirms that users perceive streaming interfaces as ~40% faster even when total generation time is identical, because Time to First Token (the moment text starts appearing) dominates perceived responsiveness. Modern LLM chat experiences (ChatGPT, Claude.ai) have set a streaming baseline that users expect. For Persona responses, non-streaming is technically acceptable but creates a product quality problem severe enough to be treated as a blocking concern rather than a nice-to-have.

Background operations (Automatic Summary, Review Agent evaluation, memory compression, Report generation) do not require streaming. These are fire-and-complete calls where the result is written to the database and reflected in the UI after completion. Non-streaming is the correct choice for all background and structured-output operations.

*Streaming is needed for: Persona responses in all three conversation modes (Direct, Round-Robin, P2P).*
*Non-streaming is correct for: summaries, memory compression, Orchestrator suggestion prompts, Review Agent evaluations, Report generation.*

*Impact on the model abstraction interface:*

The interface needs both variants. As noted in RQ-C1 findings, the correct design is:

- `complete(messages, params) -> CompletionResponse` — used for all non-streaming operations.
- `stream(messages, params) -> AsyncIterator[str]` — yields content delta strings; used for Persona responses.

These are distinct methods, not a flag on a single method, because the caller's code path is fundamentally different: a streaming caller must iterate and pipe chunks to the transport layer immediately, while a non-streaming caller awaits the full result.

Token usage metadata is not available mid-stream in most provider implementations. It is delivered in a final chunk or must be tracked separately. The interface design must account for this: `stream()` may return an async iterator of content deltas plus a final usage event, or usage may be recovered post-completion via an accumulated token count.

*Transport contract implications:*

For streaming Persona responses the backend must push token deltas to the frontend as they are generated. The credible options are:

**Server-Sent Events (SSE):** Runs over standard HTTP; no protocol upgrade handshake; built-in browser `EventSource` API; one-directional (server → client); fits the LLM streaming use case exactly. Supported in FastAPI via `sse-starlette`. The consensus recommendation for LLM token streaming as of 2025–2026.

**WebSockets:** Full-duplex; adds connection lifecycle management complexity; harder to scale; most of that complexity is wasted for unidirectional token delivery. Better suited when the client also needs to send messages mid-stream (e.g., pause, cancel). AI Council's pause/resume (FR-8.7 `@Orchestrator` interrupt) could motivate WebSockets if the interrupt must arrive on the same channel as the stream, but this can also be handled via a separate HTTP request with SSE for output.

**Recommendation (confirmed by multiple sources):** SSE is the correct default for Persona response streaming. If the P2P pause/cancel interaction model requires the client to interrupt a stream mid-flight, a WebSocket channel can be added later without changing the model abstraction layer.

*Round-Robin concurrent streaming:*

In Round-Robin mode, Personas respond sequentially — Persona A streams, completes, then Persona B streams. This does not require concurrent streaming. P2P autonomous mode may have more complex interleaving, but the sequential-per-turn model means one active stream at a time per conversation.

*New cross-reference generated:* RQ-C4 → RQ-G2: The streaming transport choice (SSE vs WebSocket) must be resolved in Group G (Frontend/Backend split, RQ-G2 real-time update transport). The two questions must be answered consistently.

### RQ-C5 — Handling model errors, rate limits, and timeouts

**Status:** Complete

NFR-2 requires that user-authored content not be lost due to transient errors. What is the expected behaviour when a model call fails mid-Conversation — retry, surface error, queue — and what does this imply for the model abstraction interface and the overall request lifecycle? Is there a standard pattern for this that fits both local and cloud models?

**Research findings:**

*NFR-2 scope clarification:*

NFR-2 protects user-authored content (messages typed by the user, Context Panel edits, Persona System Prompts). It does not require that AI-generated responses be retried indefinitely. Losing a mid-generation response because the model call failed is acceptable — the user's input that triggered it is already persisted. The practical implication is: the user's message must be written to the database before the model call is initiated. A model failure then surfaces as an error in the response slot, not a loss of user content.

*Error taxonomy: local vs cloud models have fundamentally different failure modes:*

**Local Ollama / llama.cpp errors:**
- Connection refused: the server is not running.
- Timeout: model is still loading (cold start can take 13–46 seconds for large models) or inference is very slow on the available hardware.
- No rate limiting applies — Ollama has no per-user quotas.
- **Critical finding:** Treating a local model timeout as a rate-limit trigger (and putting the provider into "cooldown") is incorrect and has been confirmed as a known bug in several tools (GitHub issues filed against multiple frameworks). The model abstraction must distinguish timeout from rate-limit and apply different handling: timeouts on local models should retry with a longer wait, not enter exponential backoff designed for cloud quota recovery.

**Cloud API errors:**
- 429 Too Many Requests: rate limit hit (RPM, TPM, RPD, TPD).
- 500 / 503: provider-side transient failure.
- Network timeout: connection issue.
- Rate limits are real and differ by provider tier; exponential backoff with jitter is the standard response.

*Standard retry pattern:*

The consensus pattern (confirmed across LangChain `with_retry`, Tenacity library, and general LLM production guidance) is:

1. Catch retryable exceptions: `ConnectionError`, `TimeoutError`, HTTP 429, HTTP 5xx.
2. Apply exponential backoff with jitter: e.g. `wait = min(2^attempt + random(0, 1), max_wait)`.
3. Hard stop after N attempts (typically 3–5 for interactive calls).
4. Raise a non-retryable exception after exhaustion so the caller can surface an error to the user.

Non-retryable conditions: HTTP 400 (bad request — a prompt construction bug, not a transient error), HTTP 401/403 (auth failure — retrying will not help), HTTP 404 (model not found).

LangChain provides `RunnableRetry` (wrapping any `Runnable` with configurable retry policy and exponential backoff) and `with_fallbacks()` (chain to an alternative model if the primary fails all retries). Tenacity is the lower-level Python library used by both LangChain internally and directly in application code.

*Implications for the model abstraction interface:*

The interface should **not** embed retry logic inside `complete()` / `stream()`. Retry policy is a caller concern: the number of retries, wait schedule, and whether to fall back to an alternative model are decisions that belong above the abstraction layer. The interface should surface typed exceptions that the calling layer can inspect (`RateLimitError`, `TimeoutError`, `ConnectionError`, `ModelError`). The caller (e.g. the ConversationOrchestrator) wraps the call with `with_retry()` or equivalent.

This keeps the adapter implementations thin and testable, and allows per-operation retry policies: interactive Persona responses may retry 2× with a short wait before surfacing an error (to keep UX responsive), while background Review Agent calls may retry 5× with longer waits.

*Mid-streaming failure:*

If a model call fails mid-stream (the SSE connection drops or the model stops generating), the partial response has already been sent to the client. The application must decide whether to:
- Truncate and mark the message as incomplete (simplest; show an error indicator).
- Discard the partial response and retry the full generation (safest for content integrity; doubles latency on retry).
- Buffer the full response server-side before streaming to the client (defeats the streaming UX benefit).

The standard practice (confirmed by multiple production sources) is to truncate and surface an error state on the message, allowing the user to manually re-trigger the response. This avoids the latency cost of full-response buffering and the complexity of resumable streams.

*No queue required:*

A queuing mechanism (e.g. message queue with dead-letter) is not warranted for V1. AI Council is a single-user local application; queuing adds infrastructure complexity that conflicts with NFR-5 (minimal setup). Retry-with-backoff at the call site is sufficient. If the background Review Agent fails a model call, it should log the failure and continue to the next Conversation rather than queuing a retry.

*Constraint check:* No Infrastructure as Configuration violation. The retry policy is a configuration concern (max retries, wait schedule) and can be placed in the app config. Provider-specific error codes are handled inside each adapter, which normalises them to the typed exceptions above before raising to the application layer.

---

## Group D: Background Job Scheduling (FR-14.4 Review Agent Schedule)

### RQ-D1 — Nightly scheduling mechanism

**Status:** Complete

FR-14.4 requires a nightly Review Agent run that skips (no catch-up) if the system is not running at the scheduled time. What are the credible scheduling mechanisms for a local-first application: an in-process scheduler thread, a system cron integration, an OS-level scheduled task, a lightweight job queue, or an embedded scheduler library? What are the tradeoffs in terms of reliability, packaging simplicity (NFR-5), and cloud portability (FR-22.2)?

**Research findings:**

*The "skip if not running" requirement is a key filter:*

FR-14.4 explicitly states the nightly run is skipped with no catch-up if the system is not running at the scheduled time. This eliminates OS-level cron and Windows Task Scheduler from serious consideration: those mechanisms would attempt to launch the application process or trigger an out-of-context script at the scheduled time, which does not fit the local-first model where the Review Agent runs within the application process and has access to the application's database connection and model abstraction layer. OS-level schedulers also create significant packaging complexity (NFR-5) because they require registration during install and cleanup during uninstall, platform-specific setup scripts per OS (macOS launchd, Linux cron, Windows Task Scheduler), and elevated permissions in some cases.

*Candidate 1 — System cron / OS task scheduler:*

Mechanism: OS-managed. On macOS, a launchd plist; on Linux, a crontab entry; on Windows, Task Scheduler via `schtasks`. These launch a separate process or script at the scheduled time, independent of whether the main application is running.

Tradeoffs:
- Reliability: high — fires even if the app is not running, which is actually undesirable here. "Skip if not running" requires additional logic to detect that the app is down and abort.
- Packaging (NFR-5): poor — requires per-OS registration scripts and teardown; increases installer complexity substantially.
- Cloud portability (FR-22.2): incompatible — cloud deployments do not use host OS cron; they use Kubernetes CronJobs or equivalent, which is a different mechanism entirely.
- Verdict: does not fit the requirement. Skip-if-not-running is its weakness, not a strength.

*Candidate 2 — In-process scheduler thread (APScheduler):*

APScheduler (Advanced Python Scheduler, v3.x stable / v4.x async) is an embedded scheduler library with no external dependencies (no Redis, no RabbitMQ, no broker process). It runs inside the application process, started at application startup and shut down with the application.

Key configuration properties directly relevant to FR-14.4:
- `CronTrigger`: specifies a schedule in cron syntax (e.g., `hour=2, minute=0` for 2 AM nightly).
- `max_instances=1`: only one concurrent run of the job is permitted. If a second trigger fires while the first is still running, it is logged as a misfire and skipped. This is the default behaviour.
- `coalesce=True`: if multiple trigger events accumulate (e.g., the scheduler was paused), only one execution is run rather than catching up on all missed ones.
- `misfire_grace_time`: if the scheduler is not running at the scheduled time, the job is simply skipped — there is no catch-up. Setting `misfire_grace_time=None` means it always runs if found within the window; setting it to a small value (e.g., 60 seconds) means jobs missed by more than that are silently dropped, which exactly implements FR-14.4's no-catch-up requirement.

The `AsyncIOScheduler` variant integrates with async frameworks (FastAPI, Litestar) via the application lifespan context manager: `scheduler.start()` on startup, `scheduler.shutdown()` on shutdown. No separate process management required.

Tradeoffs:
- Reliability: good for the local use case — the nightly run fires if and only if the application is running. "Skip if not running" is inherent to in-process scheduling.
- Packaging (NFR-5): excellent — APScheduler is a pure Python dependency added to `requirements.txt`; no OS-level setup required.
- Cloud portability (FR-22.2): acceptable for V1. In a cloud deployment, the in-process scheduler would still work if running as a single-instance service. However, if the cloud deployment scales to multiple backend instances, in-process scheduling creates a multi-trigger problem (each instance fires the job independently). Mitigation: use APScheduler with a shared data store (SQLAlchemy jobstore backed by the shared database) so only one instance claims the job. This is explicitly supported and documented. Alternatively, in cloud the scheduler can be extracted to a dedicated worker pod or replaced with a Kubernetes CronJob — the application-level job function does not change, only the trigger mechanism.
- Version note: APScheduler v3.x is stable and widely used. v4.x (async-first, AnyIO-based) is under active development and is the recommended future path for async frameworks, but is marked as not yet stable for production as of early 2026.

*Candidate 3 — Lightweight `schedule` library:*

The `schedule` library (dbader/schedule) is a minimal in-process scheduler with no dependencies and a simple fluent API (`schedule.every().day.at("02:00").do(job)`). It is single-threaded and requires a polling loop in a background thread.

Tradeoffs:
- No built-in coalesce, max_instances, or misfire_grace_time — these must be implemented manually.
- No persistence.
- Much simpler than APScheduler; appropriate only if APScheduler's feature set is considered overkill.
- Given that RQ-D2 (single-run enforcement) and FR-14.4 (skip if not running) require explicit concurrency controls, the `schedule` library would need manual wrappers for all these concerns. APScheduler provides them out of the box.

*Candidate 4 — Full job queue (Celery, RQ, Arq):*

Celery Beat, RQ Scheduler, and Arq all support periodic tasks, but all require an external message broker (Redis or RabbitMQ) as a separate process dependency.

Tradeoffs:
- Packaging (NFR-5): violates the minimal-setup requirement. Running Redis as a sidecar process solely to fire a nightly job is disproportionate infrastructure for a local-first application.
- Cloud portability (FR-22.2): excellent — these tools are native to cloud-scale deployments.
- Verdict: the infrastructure cost in V1 is not justified for a single nightly job. This could become the right choice if the application adds many more background jobs with complex dependency chains, but that is not a V1 concern.

*Summary of viable candidates:*

| Mechanism | Skip-if-not-running | Packaging (NFR-5) | Cloud portability | External dependencies |
| --- | --- | --- | --- | --- |
| OS cron / Task Scheduler | Must bolt on | Poor (per-OS setup) | Incompatible | OS-managed |
| APScheduler (in-process) | Inherent | Excellent | Good (extendable) | None |
| `schedule` library | Manual wrappers needed | Excellent | Good | None |
| Celery / RQ / Arq | Supported | Poor (broker required) | Excellent | Redis/RabbitMQ |

*Cross-reference (RQ-C5 → RQ-D1):* RQ-C5 concluded that the Review Agent should log and continue (not retry) on model failure during a nightly run. This aligns with APScheduler's model: the scheduler fires the job function; if the function catches model errors internally and continues to the next Conversation, the scheduler sees a successful job completion. Retry-at-the-scheduler-level (re-queuing the entire nightly run) is not the right pattern for model call failures.

*Infrastructure as Configuration check:* No violation. The scheduling mechanism is the only infrastructure concern here. APScheduler is a library dependency, not infrastructure. If a cloud deployment needs to replace it with a Kubernetes CronJob, the trigger mechanism is replaceable by configuration (swap the scheduler startup for a CronJob spec that calls the same job function endpoint), and the job function itself does not change.

### RQ-D2 — Single-run enforcement

**Status:** Complete

FR-14.6 requires that only one Review Agent run can be in progress at a time, blocking any second trigger. How is this best enforced — a database advisory lock, an application-level in-memory lock, a file lock, a message queue with a concurrency limit of 1? Which is robust in both local (single-process) and future cloud (potentially multi-instance) deployments?

**Research findings:**

**APScheduler's built-in mechanism (confirmed)**

APScheduler 3.x exposes `max_instances=1` per job and `coalesce=True`. With `max_instances=1`, if the nightly job is already executing when its next trigger fires, the new trigger is silently skipped and an `events.EVENT_JOB_MAX_INSTANCES` event is emitted. This is the native first line of defence for a single-process deployment and requires zero additional code. `coalesce=True` is a complementary parameter: if the scheduler was down during multiple missed fire times, it collapses them into one firing rather than queuing backfill runs. APScheduler 4.x (the new architecture) exposes `max_running_jobs` on `TaskDefaults` with the same semantics. Both are documented behaviour, not undocumented behaviour.

**Why `max_instances=1` alone is sufficient for V1 (single-process)**

AI Council V1 is a single-process application. The APScheduler `AsyncIOScheduler` runs in the same event loop as the application. In this configuration `max_instances=1` is a process-local flag — it is held entirely in memory by the scheduler and cannot be corrupted by a second process. There is no race condition because there is only one process. For V1, this is the correct and complete solution.

**The V1 → cloud gap: why `max_instances=1` does not survive multi-instance deployment**

If a future cloud deployment runs two or more application instances (each with its own scheduler), `max_instances=1` provides no cross-process enforcement: both instances could fire their own nightly job simultaneously. This is the problem that distributed locking solves.

**Candidate distributed locking mechanisms (for future cloud use, not V1)**

Four mechanisms are viable, in order of fit:

1. **Database-row lock (a `review_agent_runs` status table with a `started_at` / `status` column, updated inside a `SELECT … FOR UPDATE` or unique-index insertion).** This works with PostgreSQL and SQLite (SQLite does not have advisory locks but a unique INSERT on a status row achieves the same serialisation). It requires no additional infrastructure and the lock is implicitly released if the row is deleted or the transaction rolls back. The pattern is well-established in Python Django and SQLAlchemy applications. The table also doubles as the run audit log (cross-reference RQ-D3).

2. **PostgreSQL advisory locks** (session-level `pg_try_advisory_lock`). Zero infrastructure overhead if PostgreSQL is the database (see RQ-E1). The lock auto-releases when the session disconnects, so crashes release the lock automatically — a desirable property. Not available in SQLite. Libraries such as `sqlalchemy-dlock` and `pals` wrap this. The downside is it does not give an audit trail.

3. **Redis `SET NX PX` (SETNX with expiry).** Standard distributed lock pattern (Redlock). Only relevant if Redis is already in the stack; RQ-D1 concluded that the full job-queue stack (Celery/RQ/Arq) was eliminated, so Redis would be new infrastructure. Violates Infrastructure as Configuration in a local-first context — flagged.

4. **File lock (`fcntl.flock` / `filelock` library).** Works for multi-process on one machine, does not work across network file systems or cloud-native deployments. Not recommended as the migration path is a dead end.

**Recommended architecture (two-layer)**

Layer 1 (V1, always active): `max_instances=1` in APScheduler. Zero cost, zero additional code, correct for single-process.

Layer 2 (cloud readiness): A `review_agent_runs` status table with columns `(id, status, started_at, finished_at, workspace_id)`. At job start the runner `INSERT`s a row with `status='running'`; at job end it updates to `status='complete'` or `status='failed'`. The INSERT uses a unique partial index on `(status='running')` so a second insertion while a run is active raises an integrity error and the new trigger returns without running. This row also serves RQ-D3 (mid-run shutdown detection) and RQ-D4 (manual-vs-nightly collision). Moving to multi-instance cloud deployment requires only that this table live in a shared database — no code change, satisfying Infrastructure as Configuration.

**Infrastructure as Configuration check:** No violation for the two-layer approach. The `review_agent_runs` table is application state stored in the application database, not a separate infrastructure component. Replacing SQLite with PostgreSQL (the likely cloud migration) does not change the locking code — it only changes the database URL in configuration. Redis was noted as a violation and eliminated.

*Cross-reference:* RQ-D3 (the `review_agent_runs` table also solves mid-run cleanup); RQ-D4 (the same table is the correct mechanism for manual vs nightly collision); RQ-I8 (Report generation per-Conversation lock is a finer-grained concern and is a separate in-process lock, not this table); RQ-E1 (database choice affects whether PostgreSQL advisory locks become available).

### RQ-D3 — Mid-run shutdown handling

**Status:** Complete

FR-14.10 requires that partial Review Agent results be discarded if the system shuts down mid-run, with the next scheduled trigger starting fresh. What is the cleanest way to model this — a transactional write of results only on successful completion, a run-id staging area that is reaped on startup, or something else?

**Research findings:**

**SQLite transaction atomicity on crash (confirmed)**

SQLite guarantees that an uncommitted transaction is automatically rolled back if the process crashes (SIGKILL or otherwise), regardless of WAL or rollback-journal mode. In WAL mode, committed transactions are durable across application crashes but not necessarily across OS crashes or power loss without `PRAGMA synchronous=FULL`. The key implication: if the Review Agent holds a single open database transaction across its entire run and commits only at the very end, a crash at any point automatically discards all partial writes. This is database-level atomicity, not application code.

**Two viable models**

*Model A — Single-transaction commit (preferred for V1)*

The nightly Review Agent job opens one database transaction at the start of the run. As it processes each Conversation in sequence it accumulates new or updated findings in memory. At the very end, if the run completed without error, it commits the transaction in a single call; if an exception is raised or the process is killed, the transaction is rolled back by SQLite automatically. No additional application code for partial-result cleanup is needed. The trade-off is that a long-running nightly job holds an open write transaction for its full duration (potentially minutes), which blocks concurrent writes in SQLite's default serialised write mode. For V1 (single user, nightly job running while the user is likely not active) this is acceptable. For PostgreSQL this is less of a concern because read queries are not blocked by open write transactions.

*Model B — Run-id staging table with startup reaper*

The Review Agent writes findings to a `review_agent_run_findings` staging table, keyed by a `run_id` UUID generated at job start, alongside a `review_agent_runs` row with `status='running'`. On successful completion, a final transaction promotes the staged findings into the live `findings` table and marks the run `status='complete'`. On the next application startup, a boot-time reaper queries for any runs still in `status='running'` and deletes their staged rows. This avoids a long-held write transaction because each Conversation's findings can be staged in its own short transaction. The cost is two tables, a reaper step, and a promotion step. This is the standard pattern used in job systems like Airflow and Quartz.

**Graceful SIGTERM vs ungraceful SIGKILL**

A SIGTERM (graceful restart, Ctrl+C) can be caught by an `asyncio` signal handler. APScheduler's `scheduler.shutdown(wait=True)` lets the currently running job function complete before the scheduler exits. For FR-14.10 the requirement is that partial results are discarded; a graceful shutdown does not need to cancel the in-flight run unless it is mid-way through. The simpler handling is to let the signal handler cancel the running asyncio task (`task.cancel()` raises `asyncio.CancelledError` inside the job function), catch that inside the job, and roll back or leave the transaction uncommitted. For SIGKILL there is no signal handler; SQLite's automatic rollback handles it.

**Recommendation**

Model A (single-transaction commit) is the cleaner starting point for V1 with SQLite. It achieves the FR-14.10 requirement with zero additional code beyond the normal transaction boundary. The `review_agent_runs` status table introduced in RQ-D2 provides the run audit log regardless of which model is used. If V1 testing reveals that the held write lock is disruptive (e.g. users actively writing during a nightly run), Model B can be adopted incrementally — the `review_agent_runs` table is already present and only the staging table and promotion step need to be added.

**Infrastructure as Configuration check:** No violation. Both models use only the application database. No external queue, no file system staging area, no external lock store.

*Cross-reference:* RQ-D2 (the `review_agent_runs` table introduced there is the same table that tracks run status here); RQ-D4 (the `status='running'` row is also the collision guard for manual-vs-nightly); RQ-E1 (SQLite write serialisation matters for the Model A trade-off; PostgreSQL removes it).

### RQ-D4 — Manual "Run now" vs nightly collision

**Status:** Complete

FR-14.5 and FR-14.6 require that a manual run and a nightly run never collide (second triggered run is blocked and skipped). Is this the same mechanism as RQ-D2 or a separate concern?

**Research findings:**

**Is this the same mechanism as RQ-D2? — Partially yes, with an additional surface**

RQ-D2 established a two-layer guard: (1) `max_instances=1` in APScheduler, and (2) the `review_agent_runs` status table as the cloud-ready distributed lock. The manual "Run now" trigger introduces a second code path that bypasses the APScheduler scheduler entirely — the user clicks a button, the API endpoint receives a POST, and application code must decide whether to start a new run. This is a separate dispatch surface but the same underlying lock.

**How a "Run now" API endpoint interacts with `max_instances=1`**

APScheduler's `max_instances=1` is enforced at the scheduler level: it prevents the scheduler from starting a second execution of the same job. If the "Run now" feature is implemented by adding a one-time `DateTrigger` job (via `scheduler.add_job(review_agent_job, 'date', run_date=now, id='review_agent_manual')`) rather than calling the job function directly, the scheduler would enforce `max_instances=1` across both the cron-triggered and the manually-triggered instances — because `max_instances` is scoped per `job_id`. However, the cron job and the manual job have different `job_id` values by default, so `max_instances=1` on the cron job does not automatically block the manual job. This is a gap.

**The correct implementation: shared job function, shared lock check at dispatch**

The clean pattern is:

1. The "Run now" API endpoint does not go through the APScheduler scheduler. It calls the job function (or an async task wrapping it) directly after checking the `review_agent_runs` status table for an active run.
2. The check is: `SELECT 1 FROM review_agent_runs WHERE status = 'running' LIMIT 1`. If a row exists, the API returns a `409 Conflict` response with a message indicating a run is already in progress. The user sees the conflict and the run is not started.
3. If no active run exists, the function is dispatched (either as an asyncio task or via the scheduler's `add_job` with a date trigger), and a new `review_agent_runs` row is inserted with `status='running'`.

This is the same `review_agent_runs` table from RQ-D2. The manual trigger shares the lock with the nightly trigger — they are the same concern.

**Why not use `max_instances=1` alone for both paths?**

If "Run now" is dispatched as a separate APScheduler job with a distinct `job_id`, the scheduler's `max_instances` check does not cross `job_id` boundaries. The status table check is the single cross-path lock. Implementing the manual trigger to use the same `job_id` as the cron trigger would reuse the scheduler's `max_instances` check but creates a scheduling complexity (two trigger types on one job object). The status table approach is simpler and works regardless of how the trigger path is structured.

**The "skip and notify" semantics of FR-14.6**

FR-14.6 says the second trigger is "blocked and skipped" — not queued. Both the nightly and manual paths produce the same outcome on collision: the second attempt is rejected immediately with no pending re-try. The status table check achieves this directly: if a run is active, return early. No queue entry is created.

**Summary: same mechanism as RQ-D2, with one additional enforcement point**

The `review_agent_runs` status table (introduced in RQ-D2) is the authoritative lock for both the nightly cron trigger (enforced at the scheduler level via `max_instances=1` and at the table level) and the manual "Run now" trigger (enforced at the API endpoint level via the table check). The manual path adds one enforcement point — the API guard — but relies on the same shared lock. No new infrastructure is needed.

**Infrastructure as Configuration check:** No violation. The status table is already in the application database. The API endpoint is application code, not infrastructure.

*Cross-reference:* RQ-D2 (the `review_agent_runs` status table is the shared lock for both paths); RQ-D3 (the same table tracks run lifecycle for crash recovery); RQ-I8 (per-Conversation Report generation lock is a finer-grained and separate concern).

---

## Group E: Data Model and Persistence (FR-22.3, FR-23.1 Flags)

### RQ-E1 — Database choice for local-first with cloud path

**Status:** Complete

AI Council must run locally from day one (FR-22.1) with no fundamental rework needed for future cloud deployment (FR-22.2). What are the credible database choices given this constraint — SQLite, PostgreSQL, a file-based document store, or something else? What are the tradeoffs in packaging simplicity (NFR-5), concurrency for background jobs (NFR-4), JSON-heavy storage (memory documents, summaries, snapshots), and cloud migration path?

**Research findings:**

**Candidate 1 — SQLite (standard library, WAL mode)**

SQLite ships as a single file, requires no server process, and is included in Python's standard library (`sqlite3`). For local deployment it satisfies NFR-5 entirely: zero additional installation steps. Key characteristics:

- **Concurrency (WAL mode):** With `PRAGMA journal_mode=WAL`, concurrent readers and a single writer do not block each other. Multiple readers can run simultaneously against the main database file while a writer appends to the WAL file. The critical limitation: only one writer can hold the write lock at a time; WAL does not unlock concurrent writes. For AI Council's background jobs (Review Agent, Orchestrator), all writes are sequential or low-frequency, so this is not a material constraint in V1.
- **JSON storage:** SQLite has had first-class JSON functions (`json1` extension, built in since 3.38.0 by default) and as of SQLite 3.45.0 (January 2024) supports a native JSONB binary format for reduced parse overhead. SQLAlchemy's `JSON` column type works transparently over SQLite. The main difference from PostgreSQL's JSONB is the absence of server-side JSON indexing and GIN indexes — not required for AI Council's memory document access patterns.
- **Cloud migration path:** The migration path to PostgreSQL is a single configuration change: replacing the `DATABASE_URL` from `sqlite:///…` to `postgresql://…`. SQLAlchemy and Alembic abstract the dialect differences. Minor incompatibilities (identifier quoting, date formats) exist and are handled by `pgloader` or manual review. Confirmed pattern: most SQLAlchemy-based applications running on SQLite can be migrated to PostgreSQL by changing only the connection string, provided SQLite-specific pragmas and dialect-specific SQL are avoided.
- **Advisory locks:** Not available in SQLite. The `review_agent_runs` status table pattern (RQ-D2) is the substitute for single-run enforcement and provides equivalent guarantees.
- **WAL file on network filesystem:** WAL mode requires all processes to share a small amount of memory (via a shared-memory file) and does not work over NFS. This is not a concern for a local-first deployment but is a cloud constraint — it means a SQLite file cannot be placed on a shared network volume. If the cloud deployment separates the application process from the storage tier, this rules out SQLite as the cloud database. It does not prevent using SQLite for V1 local deployment and migrating the data to PostgreSQL for cloud.

**Candidate 2 — PostgreSQL (standard server)**

PostgreSQL is a full server-process database with the richest feature set. Key characteristics:

- **Concurrency:** MVCC allows unlimited concurrent readers and multiple concurrent writers. No write serialisation bottleneck. Background jobs can write in parallel. Relevant for AI Council primarily if the Review Agent and user activity frequently overlap.
- **JSON storage:** PostgreSQL's `JSONB` column type stores JSON in binary form with GIN indexing for containment queries. This is more capable than SQLite's JSONB but the extra capability (indexed JSON queries) is unlikely to be needed by AI Council in V1.
- **Advisory locks:** Session-level `pg_try_advisory_lock` is available. This is an alternative to the `review_agent_runs` status table row-lock for the single-run enforcement (RQ-D2, Layer 2). It auto-releases on session disconnect (crash-safe).
- **Packaging complexity:** PostgreSQL is a server process that must be installed separately. On macOS (`brew install postgresql` or Postgres.app) and Ubuntu (`apt install postgresql`) this is straightforward for developers. For a non-developer end user (NFR-5), it introduces a prerequisite that cannot be satisfied with a single command without wrapping everything in Docker Compose. This is the principal disadvantage for the local-first packaging requirement.
- **Cloud migration path:** No migration needed — PostgreSQL can be pointed at a managed cloud service (Neon, Supabase, AWS RDS) by changing the connection string. The database is already network-addressable by design.

**Candidate 3 — LibSQL / Turso (SQLite fork)**

LibSQL is an open-source fork of SQLite maintained by Tursodatabase. It extends SQLite with embedded replication and remote database support:

- **Local mode:** identical to SQLite — single file, no server, full backward-compatibility.
- **Sync mode:** an embedded replica syncs writes to a remote Turso Cloud database via WAL-based frame sync. This gives a local-first read path (low latency) with cloud persistence.
- **Python support:** libSQL has an official Python SDK (`libsql-client`, `libsql-experimental`), though it is less mature than SQLAlchemy's SQLite dialect. SQLAlchemy integration exists but is experimental as of early 2026.
- **Cloud migration path:** native — the remote endpoint is configuration. However, it ties the cloud deployment to Turso's infrastructure unless a self-hosted libSQL server (`sqld`) is operated. This introduces external service dependency and potential Infrastructure as Configuration violation if the cloud endpoint is hardcoded.
- **Assessment:** Interesting for a future cloud path but the Python ecosystem maturity is lower than standard SQLite + PostgreSQL, and the Turso dependency adds lock-in risk.

**Candidate 4 — File-based document store (JSON files, SQLite as document store)**

Using plain JSON files (one per Conversation, one per Persona) or a document-oriented store (TinyDB, JSON-on-disk):

- Has no relational integrity, no query language, no atomic cross-entity operations.
- Does not support the `user_id`, `workspace_id`, and FK constraints required by the data model (FR-22.3, RQ-E5).
- The cloud migration path is undefined.
- Not a credible candidate.

**Summary of tradeoffs**

| Dimension | SQLite + WAL | PostgreSQL |
| --- | --- | --- |
| Packaging (NFR-5) | Zero-install (stdlib) | Requires server install |
| Write concurrency | Single writer | Multi-writer (MVCC) |
| JSON support | JSON1 + JSONB (3.45+) | JSONB + GIN indexes |
| Advisory locks | Not available | Available |
| Cloud migration | Config string change + data migration | Config string change only |
| Docker Compose | Optional | Near-required for local |

**Infrastructure as Configuration check:** Both SQLite and PostgreSQL satisfy Infrastructure as Configuration provided the connection URL is configuration-driven (`DATABASE_URL` env var or config file) and no SQLite-specific SQL or pragmas appear outside a dialect-aware layer. Hardcoded `sqlite:///` strings in application code would be a violation.

*Cross-reference:* RQ-D2/D3 (the `review_agent_runs` status table is the substitute for advisory locks in SQLite; PostgreSQL advisory locks become available if PostgreSQL is chosen); RQ-H1 (docker-compose bundle vs native installer depends directly on this choice); RQ-H2 (cloud migration path concretely described here).

### RQ-E2 — `user_id` from day one without multi-user UI

**Status:** Complete

FR-22.3 and US-DM1 require `user_id` to be present on all entities from day one, with a fixed local default in V1. What is the cleanest way to represent this — a column on every table with a default value, a separate single-row users table the default references, or something else? What patterns prevent forgetting to include `user_id` in queries and scoping rules?

**Research findings:**

**Option A — `user_id` column on every entity table, with a hardcoded UUID default**

Each entity table has a `user_id UUID NOT NULL` column with a default value equal to a fixed sentinel UUID (e.g. `00000000-0000-0000-0000-000000000001`) that is baked into the application's bootstrap constants. There is no `users` table in V1. The default is applied by the ORM mixin (described below) so every `INSERT` automatically carries it.

- Pros: simplest V1 schema — zero new tables. The default value is invisible to the application in V1 because all queries implicitly produce the same result with or without the `WHERE user_id = …` clause.
- Cons: no referential integrity; the `user_id` value references nothing. When a real `users` table is added later, a migration must add the table and backfill FKs. There is a risk of accidentally shipping queries without the `user_id` filter in future, when multiple users exist, because the filter was never enforced.

**Option B — Single-row `users` table with a seeded default row**

A `users` table with a fixed-ID row (`id = 00000000-0000-…-0001`, `email = 'local@localhost'`) is seeded at application bootstrap. Every entity table has `user_id UUID NOT NULL REFERENCES users(id)`. In V1 all INSERTs carry the seeded default; the FK constraint ensures referential integrity from day one.

- Pros: correct relational structure immediately; the FK constraint prevents orphaned `user_id` values; adding real users in V2 is a seed-management concern, not a schema migration. The `users` table is already there.
- Cons: one extra table and a bootstrap seed script. Not materially complex.
- The seeded row pattern is standard in Django (the `auth_user` model seeds no rows by default but fixtures can seed one), in Rails (seeds.rb), and in SQLAlchemy projects using Alembic's `bulk_insert` in the initial migration.

**Option C — Schema-per-user (separate SQLite file or PostgreSQL schema per user)**

Each user gets a wholly separate database file (SQLite) or schema (PostgreSQL). `user_id` is implicit in the connection/schema, not a column.

- Pros: complete isolation trivially enforced; no cross-user leakage possible at the query level.
- Cons: background jobs (Review Agent) must open or connect to the correct schema dynamically. Cross-user queries (future admin views) require federation. Cloud migration introduces per-tenant connection management. For AI Council, where Workspace isolation (RQ-E5) is already a separate concern and V1 has one user, this is overengineering. Not recommended.

**Preventing forgotten `user_id` scoping in queries**

Three mechanisms exist, from weakest to strongest:

1. **ORM mixin (structural enforcement).** Define a `UserScopedMixin` in SQLAlchemy:

   ```python
   class UserScopedMixin:
       user_id: Mapped[uuid.UUID] = mapped_column(
           UUID, nullable=False, default=DEFAULT_USER_ID
       )
   ```

   Every mapped class that inherits this mixin automatically gets the column. If a developer creates a new entity class without the mixin they get a missing column — caught at schema creation time, not runtime.

2. **ORM session event `do_orm_execute` (query-time enforcement).** SQLAlchemy 2.x supports `SessionEvents.do_orm_execute()`, which fires before every ORM SELECT. An event listener can inject a `with_loader_criteria()` filter that appends `WHERE user_id = <current_user>` to all queries against `UserScopedMixin` subclasses. In V1, with only one user, this is a no-op filter. In V2, it becomes a transparent per-request scope gate without touching individual query call sites. This is the same mechanism used for role-based row filtering in multi-tenant FastAPI applications.

3. **PostgreSQL Row-Level Security (RLS) (database-enforced).** PostgreSQL can enforce `user_id` scoping at the database level via `CREATE POLICY`. A query without a matching `user_id` returns empty rather than raising an error. Not available in SQLite and adds operational complexity (policies must be managed alongside migrations). Useful as a belt-and-suspenders layer in cloud deployment but not required in V1.

**Recommended structure for V1**

Option B (single-row `users` table) combined with the `UserScopedMixin` and `do_orm_execute` event listener is the most forward-compatible approach. The schema is correct from day one, the ORM mixin makes the column structural rather than optional, and the session event creates the hook for per-user scoping without any query changes when real users are added.

**Infrastructure as Configuration check:** No violation. The `DEFAULT_USER_ID` sentinel is an application constant, not an external service dependency. The `users` table is application state, not infrastructure.

*Cross-reference:* RQ-E5 (Workspace isolation is a parallel concern — `workspace_id` follows the same mixin pattern); RQ-H2 (adding real users in cloud deployment is a seed and auth concern, not a schema migration, if Option B is used).

### RQ-E3 — Persona version history readiness

**Status:** Complete

FR-23.1 and US-DM2 require that the Persona data model support storing multiple timestamped versions of a System Prompt, even though V1 shows only the latest. What are the standard approaches — history table, append-only version table with a "current version" pointer, row-versioning with an `is_current` flag, event-sourced design? Which fits AI Council best given that Conversations already snapshot Persona state independently (FR-6.1)?

**Research findings:**

**Context: What AI Council actually needs from versioning**

Conversations already snapshot the Persona's System Prompt, Name, and Temperature at join-time (FR-6.1, RQ-E4). The Persona version history (FR-23.1) is a separate, user-facing concern: it allows the user to see previous System Prompts and potentially restore them. The two subsystems share one invariant: a Conversation snapshot must never be coupled to the live Persona version — they are independent records. Any versioning scheme must not create a FK that could cascade into Conversation snapshots.

**Option A — Dedicated `persona_system_prompt_versions` table (append-only)**

A separate table: `(id, persona_id FK, system_prompt TEXT, created_at TIMESTAMP)`. The live Persona row holds only the current system prompt (or a FK to `persona_system_prompt_versions`). On every System Prompt edit, a new row is inserted and the Persona row is updated. History is the full row sequence ordered by `created_at`.

- Pros: simple; history rows are immutable once written; straightforward to query "all versions for Persona X" or "version as of time T"; no `is_current` flag to keep consistent.
- Cons: two writes per System Prompt update (version insert + persona row update) — in a transaction this is atomic and not a problem. The Persona row holds the live prompt either denormalised (copy of the text) or as a FK to the latest version row. The FK variant means reading the current prompt requires a join; the denormalised variant means the current prompt lives in two places.
- For AI Council, the version history is a background/audit concern, not a hot read path. The denormalised approach (live prompt stays on the Persona row; history table is write-only except for the version inspector UI) is the simpler read path.
- SQLAlchemy's built-in history examples (`examples/versioned_history`) implement this pattern. `sqlalchemy-history` (corridor/sqlalchemy-history) and `sqlalchemy-continuum` (kvesteri/sqlalchemy-continuum) automate it via mapper events.

**Option B — `is_current` flag on a single versions table**

All version rows live in one table with an `is_current BOOLEAN` column. The "current" version has `is_current = TRUE`; all others have `is_current = FALSE`. On edit: set old `is_current = FALSE`, insert new row with `is_current = TRUE`.

- Pros: one table; no FK to maintain on the parent Persona row.
- Cons: `is_current` must be kept consistent in the same transaction; partial failure (crash after the new insert but before clearing the old flag) leaves two current rows. A `UNIQUE PARTIAL INDEX ON (persona_id) WHERE is_current = TRUE` enforces single-current at the database level, but this syntax is supported in PostgreSQL and SQLite (SQLite supports partial indexes as of 3.8.9). The two-step update within a transaction is standard and safe with proper transaction handling.
- More complex to query the current prompt: `WHERE is_current = TRUE` is a filter condition, not a column lookup.

**Option C — Event-sourced design (append-only log of Persona mutation events)**

All changes are stored as immutable events (`PersonaSystemPromptChanged`, `PersonaNameChanged`, etc.) in an event log. Current state is reconstructed by replaying events (or via a read-model projection).

- Pros: complete audit trail; no mutation of existing rows.
- Cons: significant complexity overhead for AI Council's scope — event replay, projection consistency, snapshot management. The only event type for System Prompt history is "prompt changed", making full event sourcing disproportionate to the benefit. Not recommended for V1.

**Option D — Version counter on the Persona row (SQLAlchemy's native `version_id_col`)**

SQLAlchemy's `Mapper` supports a `version_id_col` that increments on every UPDATE. This is an optimistic concurrency control mechanism, not a history store — it does not retain previous values. Not suitable for version history retrieval. Excluded.

**Interaction with Conversation snapshots (RQ-E4)**

The critical constraint is that Conversation snapshots (FR-6.1) must not reference the versioned Persona history by FK — they must be self-contained. This means:

- If Option A is used: the Conversation snapshot stores the System Prompt text directly (denormalised), not a FK to `persona_system_prompt_versions`. This decouples the two subsystems entirely.
- If Option B is used: same — the snapshot stores the text, not the version row's ID.

Neither Option A nor B creates a cascade risk provided the snapshot table has no FK into the version history. This is a schema design discipline point, not a technical limitation.

**V1 deferral strategy**

FR-23.1 requires "readiness" — the model must support versioning even if the V1 UI only shows the latest. The minimal V1 implementation is Option A with automatic version row insertion wired to the System Prompt update endpoint. The version inspector UI can be added in V2 without any schema migration. Option B requires the same number of tables and slightly more query complexity for no benefit in V1.

**Infrastructure as Configuration check:** No violation. All versioning options use the application database only.

*Cross-reference:* RQ-E4 (Conversation snapshots are deliberately decoupled from Persona versioning — the snapshot stores text directly, not a version FK); RQ-B4 (System prompts must be read from Conversation Persona snapshots during active Conversations, which reinforces that the live Persona version table is not the source for in-flight Conversations).

### RQ-E4 — Conversation snapshot storage

**Status:** Complete

FR-6.1 through FR-6.5 require that each Conversation capture an immutable snapshot of each participating Persona (Name, System Prompt, Temperature) at the moment they join, and that this snapshot survive deletion of the source Persona (FR-6.3). How is this best stored — as denormalised JSON in the Conversation record, as a separate snapshot table keyed by (conversation_id, persona_id, joined_at), or as a reference to a Persona version (see RQ-E3)? The chosen shape should not leak across to the live Persona through foreign key cascades.

**Research findings:**

**Key requirement: survive Persona deletion**

FR-6.3 is the binding constraint: the snapshot must survive deletion of the source Persona. Any storage shape with a `NOT NULL` FK to the live Persona record will block Persona deletion or cascade-delete the snapshot. The two clean solutions are: (a) store the snapshot data denormalised (no FK to Persona), or (b) use a nullable FK and accept `NULL` after deletion — but a NULL FK means reading the snapshot name/prompt at runtime requires handling the NULL case, which is messier than pure denormalisation.

**Option A — Denormalised columns on a `conversation_personas` join table**

A `conversation_personas` table with columns:
`(id, conversation_id FK, persona_id NULLABLE FK, joined_at, snapshot_name TEXT, snapshot_system_prompt TEXT, snapshot_temperature NUMERIC)`

The `persona_id` column is nullable. When the Persona is deleted, `persona_id` is set to NULL (via `ON DELETE SET NULL`); the snapshot columns remain intact because they are independent text columns, not derived from the Persona row. The context-assembly layer reads `snapshot_system_prompt` and `snapshot_name` from this table, never from the live Persona record. This directly satisfies the cross-reference from RQ-B4.

- Pros: snapshot data is fully self-contained; Persona deletion is clean; no join needed to read the snapshot during active Conversations; the nullable `persona_id` preserves a soft link to the originating Persona while it exists.
- Cons: System Prompt text is duplicated (once in Persona/version history, once per Conversation participant snapshot). For AI Council's data volumes this is not a storage concern.
- SQLAlchemy note: by default SQLAlchemy sets nullable FKs to NULL when the parent is deleted (ORM-level cascade). To defer to the database's `ON DELETE SET NULL`, set `passive_deletes=True` on the relationship and declare `ON DELETE SET NULL` in the FK constraint. Either works; the database-level cascade is more reliable for bulk deletes.

**Option B — JSON blob on the Conversation record**

A `participants_snapshot JSONB/TEXT` column on the `conversations` table stores an array of participant objects: `[{"name": "…", "system_prompt": "…", "temperature": 0.7, "persona_id": "…"}]`.

- Pros: one column; no join; self-contained.
- Cons: querying across Conversations for "which Conversations included Persona X" requires a JSON containment query — workable in PostgreSQL (GIN index), awkward in SQLite (full-text scan). Adding/removing participants mid-Conversation (FR-5.5 persona-leave, FR-5.6 persona-add) requires deserialising and re-serialising the JSON array; the `conversation_personas` join table handles these events as row inserts/deletes. The relational model is generally cleaner for multi-participant Conversations.

**Option C — FK to a Persona version row (from RQ-E3)**

The Conversation snapshot stores a FK to a `persona_system_prompt_versions` row rather than copying the text.

- Eliminated: if the Persona and all its version history are deleted, the FK becomes a dangling reference unless the version row is excluded from cascades. This creates a dependency between two unrelated subsystems (Conversation management and Persona version history). The decoupling benefit of keeping snapshots independent outweighs any normalisation gain. The cross-reference to RQ-E3 confirms: snapshots must store text directly, not version FKs.

**Recommended shape: Option A (separate `conversation_personas` join table)**

The `conversation_personas` table is the standard relational pattern for a many-to-many relationship with per-association data. It handles the participant lifecycle (Personas joining and leaving mid-Conversation, FR-5.5 and FR-5.6) naturally as row inserts and soft-deletes (a `left_at TIMESTAMP` column marks departure). Snapshot data lives on the same row, captured at join time and never updated. The nullable `persona_id` FK with `ON DELETE SET NULL` keeps a soft link while the Persona exists without breaking the invariant on deletion.

**Context-assembly interaction**

The context-assembly layer (RQ-B4 cross-reference) reads the `snapshot_system_prompt` and `snapshot_temperature` from `conversation_personas` for every active participant when constructing the prompt. It never reads from the live `personas` table during an active Conversation. This is a schema-enforced discipline: the context-assembly code path has no reason to touch the `personas` table.

**Infrastructure as Configuration check:** No violation. All storage is in the application database.

*Cross-reference:* RQ-B4 (context assembly reads from snapshots, not live Persona records — the `conversation_personas` table is the source); RQ-E3 (snapshots store text directly, not Persona version FKs, to keep the two subsystems decoupled); RQ-I5 (applying a Review Agent finding updates the live Persona but not any Conversation snapshot — enforced because snapshots are on `conversation_personas`, not on the `personas` row).

### RQ-E5 — Workspace total isolation enforcement

**Status:** Complete

FR-1.6 requires that all Workspace content be completely inaccessible from any other Workspace. What patterns enforce this at the data layer so that a programmer cannot accidentally join across Workspaces — schema-per-workspace, a `workspace_id` on every entity with a query-time guard, row-level security, or an ORM-level scope?

**Research findings:**

AI Council's Workspaces are structurally analogous to tenants in a multi-tenant application. The isolation requirement (FR-1.6) means every query that returns Workspace-scoped data must include a `workspace_id` predicate. The risk is a developer writing a query that omits it — returning data across all Workspaces.

**Option A — `workspace_id` column on every entity, enforced by ORM mixin + `do_orm_execute` session event**

Every entity table that is Workspace-scoped inherits a `WorkspaceScopedMixin` (parallel to `UserScopedMixin` from RQ-E2) providing a `workspace_id UUID NOT NULL FK` column. The `do_orm_execute` session event fires before every ORM SELECT and injects a `with_loader_criteria()` filter scoped to the active workspace.

Implementation pattern (SQLAlchemy 2.x):
1. The current `workspace_id` is stored in a `ContextVar` set at request entry (API middleware or dependency).
2. The `do_orm_execute` listener reads the `ContextVar` and appends `workspace_id = <current>` to all SELECTs against `WorkspaceScopedMixin` subclasses.
3. The mixin's `NOT NULL` constraint blocks INSERTs that omit `workspace_id` at the database level.

- Pros: single database; no schema migrations when a new Workspace is created; works with both SQLite and PostgreSQL; the `ContextVar` pattern is idiomatic in FastAPI async applications; query injection is transparent to individual query call sites.
- Cons: the session event approach only covers ORM-level queries — raw SQL executed via `session.execute(text(…))` bypasses it. Discipline required for raw SQL. Also: background jobs (Review Agent) that are not in a request context must set the `ContextVar` explicitly before executing queries.
- MultiAlchemy (mwhite/MultiAlchemy) implements this pattern as a library extension; it is experimental but demonstrates feasibility.

**Option B — Schema-per-Workspace (PostgreSQL `search_path`)**

Each Workspace gets its own PostgreSQL schema. All entity tables are created under the schema. `search_path` is set per connection to the correct schema, making queries schema-unaware in application code.

- Pros: complete structural isolation; a query literally cannot see another Workspace's tables without changing `search_path`.
- Cons: requires PostgreSQL (not available in SQLite); schema creation and migration must run per Workspace (Alembic migrations need to run once per schema); connection pool management requires `search_path` to be set on each connection. At AI Council's V1 scale (few Workspaces) this is operationally feasible, but the cloud migration complexity scales poorly. `fastapi-tenancy` supports this pattern natively for FastAPI + SQLAlchemy but adds a third-party dependency.

**Option C — PostgreSQL Row-Level Security (RLS)**

PostgreSQL RLS policies enforce `workspace_id` scoping at the database engine level — even if application code forgets the WHERE clause, the database returns zero rows for other Workspaces. Implementation: `CREATE POLICY workspace_isolation ON personas USING (workspace_id = current_setting('app.workspace_id')::uuid)`, with the session variable set per request via `SET LOCAL`.

- Pros: strongest enforcement — bugs in application code cannot leak cross-Workspace data. Independent of ORM.
- Cons: PostgreSQL-only (not available in SQLite); adds database-side policy management to migrations; connection pooling requires care (`SET LOCAL` is transaction-scoped, which is correct, but connection pool reset behaviour must be verified); RLS policies increase schema complexity. `fastapi-rowsecurity` and `fastapi-tenancy` provide SQLAlchemy integration for this pattern.
- This is a belt-and-suspenders layer, appropriate for cloud deployments where data isolation is a compliance concern.

**Option D — Separate SQLite file per Workspace**

Each Workspace gets its own SQLite database file. Isolation is structural: the application opens a connection to a different file per Workspace.

- Pros: complete isolation; no accidental cross-Workspace queries possible.
- Cons: background jobs must manage multiple database connections; cross-Workspace operations (e.g. future admin dashboard) require federated queries; Alembic migrations must run against each file; cloud migration replaces per-file isolation with schema or RLS anyway. Not recommended.

**Layering recommendation**

A two-layer approach is the most practical:

- **Layer 1 (V1, always):** `WorkspaceScopedMixin` + `do_orm_execute` session event. All ORM queries are automatically scoped. The `ContextVar` is set by API middleware; background jobs set it at task start. Covers SQLite and PostgreSQL equally.
- **Layer 2 (cloud, PostgreSQL-only):** PostgreSQL RLS as a safety net. When the deployment migrates to PostgreSQL, RLS policies can be added as an additional enforcement layer. No application code changes required — the ORM-level scoping already does the right thing; RLS merely catches anything that slips through raw SQL paths.

**Infrastructure as Configuration check:** No violation. Option A works with both SQLite and PostgreSQL — the mechanism is ORM-level code, not database-specific infrastructure. Option C (RLS) is PostgreSQL-specific and would be an additive layer only activated in cloud deployment via database configuration, not application code.

*Cross-reference:* RQ-E2 (the `UserScopedMixin` pattern is exactly analogous; the same `do_orm_execute` event can enforce both `user_id` and `workspace_id` scoping in one listener); RQ-I9 (Workspace deletion during in-flight work — the isolation pattern determines whether deletion cascades or requires explicit task cancellation).

### RQ-E6 — Mentor memory persistence shape

**Status:** Complete

The three-layer Mentor memory (FR-18) needs persistent storage for Episodic Memory (rolling N summaries, with promotion logic) and Semantic Memory (structured Markdown knowledge documents). Working Memory is the live Conversation and does not need separate storage. What is the right storage shape for each layer — structured tables, JSON blobs, Markdown files on disk, or a mix? How does this interact with Workspace isolation (RQ-E5) and with the read-only Memory Inspector (FR-19)?

**Research findings:**

**Layer mapping**

- **Working Memory** = the live Mentor Conversation thread. Already stored as messages in the `conversations`/`messages` tables. No additional storage needed.
- **Episodic Memory** = a rolling window of N session summaries, with a `sequence_number` or `created_at` to identify the oldest. Promotion-to-Semantic runs before the oldest is retired (FR-18.3, RQ-I7).
- **Semantic Memory** = structured Markdown knowledge documents ("What I know about this user's preferences", "Domain facts"). Rendered in the Memory Inspector (FR-19) as human-readable text.

**Episodic Memory — storage shape options**

*Option E-A: Dedicated `mentor_episodic_memories` table*

Columns: `(id, workspace_id FK, mentor_persona_id FK, sequence_number INT, summary_text TEXT, created_at TIMESTAMP, promoted_at TIMESTAMP NULLABLE)`.

Each row is one episodic entry (one session's summary). The rolling window is maintained by `ORDER BY sequence_number` and a configurable limit N (from the config file, satisfying NFR-3). The oldest entry's `sequence_number` is the retirement candidate.

- Pros: standard SQL; queryable for the Memory Inspector (FR-19) as an ordered list without deserialisation; sequence_number makes "oldest entry" deterministic; `promoted_at` records when a promotion check was performed; FK ensures Workspace isolation chains through the `WorkspaceScopedMixin` pattern (RQ-E5).
- Cons: no additional cons for AI Council's scale and access pattern.

*Option E-B: JSON array column on the Mentor Persona row*

A `episodic_memory_entries JSONB` column on the `personas` table (or a `mentor_config` table) stores the N entries as a JSON array.

- Pros: one column; no join.
- Cons: updating a single entry requires deserialising and re-serialising the entire array; partial failure during promotion leaves the array inconsistent; the Memory Inspector must parse JSON to display the ordered list; no FK to chain Workspace isolation through. For a rolling window with mutation semantics (retirement and promotion), a relational table is cleaner.

*Option E-C: LangGraph BaseStore / InMemoryStore*

LangGraph provides a `BaseStore` abstraction for long-term cross-thread memory. In V1, `InMemoryStore` is available; `PostgresStore` is the production persistent implementation. `SqliteSaver` and `AsyncSqliteSaver` handle checkpointing (short-term thread state), but `BaseStore` for long-term cross-thread memory does not have a first-class SQLite backend in the official LangGraph library (a community library `langmem-sqlite-vec` provides one). For AI Council's custom three-layer structure — specifically the rolling N entries and promotion logic — the `BaseStore` key-value interface is less natural than a relational table with an ordered sequence.

- This is relevant only if LangGraph is chosen as the agentic framework (see Group A). If LangGraph is used, its checkpointer (SQLite or PostgreSQL) handles Working Memory within the graph; Episodic and Semantic Memory should still be stored in the application database for consistent Workspace isolation enforcement, not in a separate LangGraph store.

**Semantic Memory — storage shape options**

*Option S-A: Dedicated `mentor_semantic_memories` table with `content_markdown TEXT`*

Columns: `(id, workspace_id FK, mentor_persona_id FK, title TEXT, content_markdown TEXT, created_at TIMESTAMP, updated_at TIMESTAMP)`.

Each row is one knowledge document. The Memory Inspector (FR-19) reads and displays all rows for the current Workspace's Mentor. Promotion from Episodic appends a new row or updates an existing row if the promoted fact pertains to an existing document (matched by title or LLM-identified topic).

- Pros: queryable; inspectable; Workspace isolation via `workspace_id`; human-readable Markdown stored as plain text; straightforward to display in the Memory Inspector.
- Cons: matching "existing documents" during promotion requires either an explicit title match or a secondary LLM call to find the right document — this is an application-level concern, not a schema concern.

*Option S-B: Markdown files on disk, one per knowledge document*

Files stored under `data/workspaces/{workspace_id}/mentor/semantic/{title}.md`. Read at query time by loading from disk.

- Pros: human-readable in file manager.
- Cons: file system is not a transactional store; Workspace isolation must be enforced through directory naming (error-prone); queries across documents require directory listing + file reads; the Memory Inspector cannot query them via the same database layer; cloud migration requires abstracting file storage (S3, etc.) — a separate Infrastructure as Configuration concern. Not recommended for data that must survive Workspace deletion cleanly (FR-1.8 requires all Workspace data be deleted on Workspace deletion — a CASCADE from the database is clean; file cleanup is not).

**Interaction with Workspace isolation (RQ-E5)**

Both `mentor_episodic_memories` and `mentor_semantic_memories` tables inherit `WorkspaceScopedMixin`. The `do_orm_execute` session event automatically scopes all reads to the active Workspace. Deletion of a Workspace cascades to these tables via FK.

**Interaction with the Memory Inspector (FR-19)**

FR-19 specifies a read-only inspector. Both table options (E-A and S-A) support this directly: the API endpoint reads from the two tables and serialises to JSON. The Markdown content in S-A is returned as-is and rendered client-side. No additional storage layer needed for the inspector.

**Recommended shape**

- **Episodic:** `mentor_episodic_memories` table (Option E-A). Ordered by `sequence_number`; configurable N from config file.
- **Semantic:** `mentor_semantic_memories` table (Option S-A). `content_markdown TEXT` column; one row per knowledge document.
- **No file-system storage** for either layer. All memory data in the application database, Workspace-scoped.

**Infrastructure as Configuration check:** No violation. Both recommended shapes use the application database. LangGraph's `BaseStore` (Option E-C) would introduce a second storage abstraction with a separate connection; this would only be adopted if LangGraph is chosen and its store implementation is kept configuration-driven.

*Cross-reference:* RQ-E5 (WorkspaceScopedMixin applies to both memory tables); RQ-I7 (promotion logic — the promotion-to-semantic step is an LLM call that writes to `mentor_semantic_memories`; the schema shape described here defines where that write lands); RQ-I6 (session end detection triggers Working Memory compression into Episodic — the episodic table is the write target).

### RQ-E7 — Review Agent finding storage and lifecycle

**Status:** Complete

FR-15 requires that findings be persona-specific, persist as cards until explicitly applied or dismissed, embed evidence inline (no link to source Conversation), survive deletion of the source Conversation (FR-3.8), evolve across runs (expand with new evidence, drop when no longer apparent, FR-15.6), and have no visible "resolved" state. What storage shape supports this lifecycle cleanly — a simple findings table keyed by persona, an event log of finding-state changes, or something else?

**Research findings:**

**Lifecycle analysis**

A finding has the following state transitions:
1. **Created** by a Review Agent run — identified as a pattern in Conversations.
2. **Persists** across nightly runs — survives even if the source Conversations are deleted.
3. **Evolves** across runs — evidence text can expand (new Conversations reinforce the pattern) or the finding can be dropped (pattern no longer apparent, FR-15.6).
4. **Closed** in one of two ways: **Applied** (user applies the suggested change to the Persona's System Prompt, FR-15.4) or **Dismissed** (user dismisses the card, FR-15.3). No "resolved" state is shown in the UI.
5. Once closed, the finding is removed from the visible card list — but whether it is physically deleted or soft-deleted is a schema choice.

**Option A — Simple `review_agent_findings` table with mutable evidence columns**

Columns: `(id UUID PK, workspace_id FK, persona_id FK, category TEXT, suggestion_text TEXT, evidence_text TEXT, first_seen_at TIMESTAMP, last_updated_at TIMESTAMP, status ENUM('active', 'applied', 'dismissed'), closed_at TIMESTAMP NULLABLE)`.

The nightly run reads all `status='active'` findings for a Persona. For each pattern it identifies:
- If a matching finding exists (by `category` or `suggestion_text` similarity — application-level match logic): UPDATE the `evidence_text` to include the new evidence, UPDATE `last_updated_at`. The finding card reflects expanded evidence.
- If a pattern it previously found is no longer apparent: UPDATE `status='dismissed'` (or DELETE the row — see below) so the card disappears.
- If a new pattern is found: INSERT a new row.

When the user applies or dismisses a card: UPDATE `status='applied'` or `status='dismissed'`, SET `closed_at = NOW()`.

- Pros: simple; one table; the card UI reads `WHERE status='active' AND persona_id = ?`; the card lifecycle is expressed as column values, not row count; evidence is a mutable text column updated in place. The "no visible resolved state" requirement maps cleanly — the UI never exposes `status='applied'` or `status='dismissed'` rows.
- Cons: updating `evidence_text` in place loses the history of how evidence evolved. If a future requirement needed an audit trail of evidence expansion, this would require a history table. FR-15 as stated does not require evidence history, so this is not a present constraint.
- The `persona_id` FK must be set to `ON DELETE SET NULL` (not CASCADE DELETE) so that findings survive deletion of the source Persona if the Persona is deleted. However FR-15 says findings are Persona-specific and displayed on the Persona page — if the Persona is deleted, there is no page to display them on. A CASCADE DELETE on Persona deletion is likely the correct behaviour; this is a product decision. For source Conversation deletion (FR-3.8): the `evidence_text` embeds conversation excerpts inline — there is no FK to `conversations`. Conversation deletion cannot orphan evidence because there is no FK to break.

**Option B — Event log of finding-state changes**

An append-only `review_agent_finding_events` table logs every state change: `FindingIdentified`, `EvidenceAdded`, `FindingDropped`, `FindingApplied`, `FindingDismissed`. Current state is the projection of the event log.

- Pros: complete audit trail; evidence expansion history preserved.
- Cons: current-state queries require either an event replay or a materialised view. For AI Council's finding volume (a few findings per Persona, updated nightly), this is significantly over-engineered. Event sourcing introduces projection maintenance, schema evolution challenges, and query complexity not justified by FR-15's requirements. Not recommended.

**Option C — Hard delete on apply/dismiss vs soft delete**

When a finding is applied or dismissed, the row can be either:
- **Hard deleted:** row is removed from the database. Simplest approach; cards disappear cleanly; no `status` column needed.
- **Soft deleted:** `status='applied'` or `status='dismissed'` with `closed_at`. Enables future audit trail or undo capability.

FR-15 has no undo requirement and no resolved-state display. Hard deletion on apply/dismiss is the simplest implementation and avoids soft-delete complexity (ORM filter requirements, accidental exposure of closed findings in queries). The trade-off is that once applied or dismissed, the finding is gone — there is no basis for future analysis of "how many findings were applied this month". Whether that analytics capability is needed is a product question outside this research scope.

If hard deletion is chosen, the `evidence_text` must be self-contained (no FK to source Conversations — already required by FR-3.8) so the DELETE is clean with no orphan concerns.

**Finding "matching" across nightly runs**

The key practical challenge in Option A is determining whether a newly observed pattern matches an existing finding. Two approaches:

1. **Deterministic key** (e.g. `category + persona_id` as a unique composite key). If the Review Agent always assigns the same category label to the same type of pattern, the nightly run can UPSERT on `(persona_id, category)`. Simple, fast, requires consistent category taxonomy.
2. **LLM-mediated match** (the nightly run passes existing findings to the LLM and asks it to identify which existing finding each new pattern corresponds to, or whether it is new). More robust to category drift but adds an extra LLM call per run. This is an application design choice, not a schema choice.

**Recommended shape: Option A with hard deletion**

A `review_agent_findings` table with: `(id UUID PK, workspace_id FK, persona_id FK, category TEXT, suggestion_text TEXT, evidence_text TEXT, first_seen_at TIMESTAMP, last_updated_at TIMESTAMP)`. No `status` column; apply and dismiss are hard deletes. Evidence is updated in place on each nightly run pass. `persona_id` FK with `ON DELETE CASCADE` (findings belong to a Persona and have no meaning without one).

The nightly run logic:
1. SELECT all active findings for each Persona.
2. For each identified pattern: UPSERT (insert new or update evidence of existing).
3. DELETE findings whose patterns are no longer apparent.

The user apply/dismiss actions: DELETE the finding row.

**Infrastructure as Configuration check:** No violation. Single application database table; no external service.

*Cross-reference:* RQ-D2/D3/D4 (the `review_agent_runs` table governs single-run enforcement and lifecycle — it is a separate table from the `review_agent_findings` table but both are written in the same nightly run transaction, per the Model A pattern in RQ-D3); RQ-E5 (WorkspaceScopedMixin applies; `workspace_id` on the findings table chains through the ORM scope); RQ-I4 (interactive consultation reads existing findings from this table — the same `review_agent_findings` table is the read source for both the nightly run and interactive consultation, but the interactive mode must not read Conversation histories — that is an application layer constraint, not a schema constraint).

---

## Group F: Peer-to-Peer Throttling Semantics (FR-5.3 Mode 3 Flag)

This group overlaps with Group A but is specifically about the *semantics* of P2P throttling, independent of whatever framework is chosen. These questions must be answerable whether or not LangGraph is adopted.

### RQ-F1 — Throttle trigger definition

**Status:** Complete

The overview states the Orchestrator "throttles the exchange to prevent runaway Persona-to-Persona loops where two Personas respond to each other indefinitely without meaningful progress" (Section 5.2 Mode 3). What concrete signals can be used to detect "runaway" or "without meaningful progress"? Candidates include: fixed maximum turn count since last user message, topic drift detection, diminishing semantic novelty of successive responses, repetition detection, and time-based cutoffs. What are the tradeoffs of each, and is any combination of them considered standard practice?

**Research findings:**

*Cross-reference note:* RQ-A6 established that no framework — including LangGraph — provides a soft throttle out of the box. The P2P throttle mechanism must be designed at the application layer and composed with the turn-taking graph. This question concerns what that mechanism should evaluate.

**Signal 1 — Hard turn cap (max autonomous turns since last user message)**

A counter (`p2p_turn_count`) in graph state, incremented after each Persona-to-Persona response, compared to a configured `MAX_P2P_TURNS` ceiling. When the ceiling is reached, the turn-selection edge routes to `await_user`. Implementation is trivial: a conditional edge function reading integer state. The cap value is operator-configurable (satisfies Infrastructure as Configuration when read from config, not hardcoded).

- Pros: zero latency cost per turn (pure integer comparison), completely deterministic, no false negatives (will always fire), crash-safe (counter is in checkpoint state), widely recommended as the "hard fail-safe" in multi-agent frameworks (AutoGen's `max_consecutive_auto_reply`, LangGraph's `recursion_limit`, all use this pattern).
- Cons: fires regardless of whether conversation is productive; a high-quality 20-turn exchange gets cut as readily as a 20-turn loop. Gives no signal about *why* it fired.
- Verdict: Necessary as a hard safety backstop. Should always be present. Not sufficient as the only mechanism.

**Signal 2 — Repetition detection (exact or near-exact text hash)**

Hash each Persona response (exact text) or a normalised/whitespace-stripped variant and compare against the last N hashes in a rolling buffer in graph state. If a hash repeats within the window, route to `await_user`. This directly catches verbatim or near-verbatim loops ("I agree with that" / "I also agree" cycling).

- Pros: O(1) per turn — no model call required, no embedding computation. Deterministic and interpretable. Confirmed effective: embedding-based loop detection (a superset of hash matching) "identified and prevented 100% of infinite or runaway loops in models that exhibit degenerative repetition." Hash detection catches the hardest cases (exact repeats) at zero cost.
- Cons: Does not catch semantic repetition expressed in varied words. Two Personas can circle the same idea with different phrasing indefinitely and this signal will not fire.
- Verdict: Low-cost high-reliability first line of defence. Should be included in all cases.

**Signal 3 — Embedding similarity / diminishing semantic novelty**

Embed each Persona response using the configured embedding model (or a lightweight local embedding if available) and compute cosine similarity against the rolling window of recent responses. When similarity exceeds a threshold (e.g. 0.90) across the last K responses, route to `await_user`. A related variant: track a rolling "novelty score" (1 − max_similarity_to_recent) and fire when novelty drops below a threshold for N consecutive turns.

- Pros: Catches semantic repetition that hash detection misses ("I concur" vs "I agree" vs "I think you're right"). Production drift-detection implementations cite cosine-similarity thresholds of ~0.82 as catching degradation 11 days before user-facing tickets in deployed systems, which suggests the signal is reliable at appropriate thresholds.
- Cons: (a) Requires an embedding call per turn — adds latency and token cost. If the configured model does not expose an embedding endpoint, a separate embedding model must be provisioned; this is a potential Infrastructure as Configuration concern if a hardcoded embedding provider is used instead of the abstracted model interface. (b) Threshold calibration is domain-sensitive: a philosophical debate legitimately revisits themes; cosine similarity alone cannot distinguish "productive revisiting" from "unproductive looping." (c) Cosine similarity in high-dimensional embedding spaces has well-documented pathologies (cosine similarity between unrelated texts can be arbitrarily high in some embedding models). The reliability depends on embedding model quality.
- Infrastructure as Configuration flag: if embedding similarity is used, the embedding model endpoint must be accessed via the same abstraction interface as the generative model. A hardcoded `text-embedding-ada-002` call would be a violation.
- Verdict: Higher fidelity than hash detection but has operational cost and calibration requirements. Best used as a secondary signal layered above the hard cap.

**Signal 4 — LLM-mediated progress evaluation**

A lightweight "throttle check" call to the configured model after every N turns: "Given the last N messages, has meaningful progress been made on the original topic? Answer YES or NO." Route to `await_user` on NO. This is the approach described in RQ-A6 as a `throttle_check` graph node.

- Pros: The richest signal — the model can interpret context, distinguish productive theme revisiting from unproductive loops, and understand nuance that embedding similarity and hashing cannot.
- Cons: (a) Adds a full model round-trip of latency after every N Persona turns. In a fast autonomous exchange this is noticeable to the user. (b) Introduces a second model call to the infrastructure cost per turn cycle. (c) The model's judgement is non-deterministic — the same conversation may evaluate differently on different runs. (d) The prompt for this call must be authored and maintained; it can itself become a source of bugs.
- Verdict: Highest fidelity, highest cost. Suitable as an optional layer for power users or as the evaluation triggered only *after* the embedding similarity signal flags a concern, not as a per-turn default.

**Signal 5 — Time-based cutoff (wall-clock timeout)**

A timestamp recorded when the autonomous exchange begins, compared after each turn. If elapsed time exceeds a configured threshold (e.g. 5 minutes), route to `await_user`.

- Pros: Independent of message content — catches stalls where one Persona is slow to respond (e.g. due to model latency) or where the exchange is producing content but has been running too long for the user's session context. AutoGen's `TimeoutTermination` implements exactly this.
- Cons: Poor signal quality for the "no meaningful progress" case — a slow-but-substantive exchange gets cut at the same time as a fast-but-circular one. Primarily a user-experience guard, not a quality signal.
- Verdict: Useful as a user-experience backstop (especially for slow model endpoints), not as a primary quality signal.

**Standard practice: layered combination**

AutoGen's published termination documentation demonstrates combining conditions with AND/OR operators (e.g. `MaxMessageTermination(10) | TextMentionTermination("DONE")`). Multi-agent loop prevention guides universally recommend a layered approach: hard turn cap as the unconditional ceiling, with lighter heuristics (repetition, time) acting as early exits before the ceiling is reached. The MAST framework taxonomy (2025) identifies "missing termination conditions" as one of the top specification-level failure modes, accounting for a large fraction of multi-agent system failures, which confirms that *some* termination signal is mandatory.

The recommended layered stack for AI Council, in increasing cost order:

1. **Hard cap** (always on): `p2p_turn_count >= MAX_P2P_TURNS` — unconditional ceiling, operator-configured.
2. **Repetition hash** (always on): exact/near-exact match against rolling window — zero latency cost, catches degenerate loops immediately.
3. **Embedding similarity** (optional, operator-configured): fires when cosine similarity of recent responses exceeds threshold — catches semantic loops at modest latency cost. Infrastructure as Configuration constraint: must use the abstracted model/embedding interface.
4. **LLM progress check** (optional, high-cost): invoked only when Layer 3 flags a concern, or on a slower cadence (every N turns) — highest fidelity but adds per-cycle latency.
5. **Time cutoff** (always on): wall-clock timeout as a user-experience backstop — operator-configured.

Layers 1, 2, and 5 are lightweight enough to always be active. Layers 3 and 4 are opt-in quality signals governed by operator configuration. All threshold values must be config-driven (satisfies Infrastructure as Configuration).

*Cross-reference:* RQ-A6 (implementation options as graph node vs edge condition vs external flag); RQ-F4 (whether the Orchestrator owns this evaluation or a separate turn-router does).

### RQ-F2 — Next-speaker selection in P2P

**Status:** Complete

How should the system decide which Persona speaks next in P2P? Candidates include: explicit addressability (a Persona addresses another by name), round-robin within autonomous turns, a supervisor/router prompt that picks next speaker, stochastic selection weighted by topic relevance. Which of these best matches the "feels more natural than Round-Robin" intent of the overview? Does the choice have to be made architecturally, or can it be a configuration knob?

**Research findings:**

*Context from RQ-A6:* LangGraph expresses next-speaker selection as a conditional edge function: `decide_next_speaker(state) -> str`, reading graph state fields (`last_speaker`, `addressee`, `messages`, `p2p_turn_count`). This is the confirmed architectural position; RQ-F2 concerns the *logic* that function should contain.

**Candidate A — Explicit addressability (Persona names another Persona by name in its response)**

The Persona response is parsed for references to another Persona's name (e.g. "@Socrates", "Socrates, what do you think?"). If found, the named Persona is next. If no Persona is named, a fallback rule applies.

- How it maps to "feels more natural": This is the closest model to a genuine peer conversation — one participant addresses another by name, and that participant responds. Humans naturally direct questions and challenges to specific individuals, and this pattern replicates that.
- Confirmed pattern: AutoGen's SelectorGroupChat uses participant name/description attributes as inputs to its model-based selection. The LangGraph handoff pattern uses explicit tool calls (`Command(goto="persona_name")`) — a structured analogue of addressability.
- Implementation: After each Persona LLM call, the response text is inspected for Persona name tokens. If a match is found, `addressee` is written to graph state. The conditional edge reads `addressee` first; if populated, it routes directly. Name extraction can be a regex (fast, deterministic) or a lightweight model classification call (slower, handles paraphrase).
- Limitation: Personas must be prompted to address each other by name; if the System Prompt does not encourage this, Personas may produce responses without addressee signals, causing repeated fallback-rule firing.

**Candidate B — Round-Robin within autonomous turns**

Within the P2P autonomous segment, Personas take turns in a fixed cycle (A → B → A → B…). No speaker-selection logic is needed.

- How it maps to "feels more natural": Explicitly worse than addressability on this dimension. The overview singles out Round-Robin as the *less natural* Mode 2, and P2P is intended to feel different. Round-Robin within P2P turns is Mode 2 behaviour with a different label — it would not satisfy the intent.
- Use case: Only appropriate as a final fallback when no Persona names an addressee and no supervisor has been configured. Should not be the primary mechanism.

**Candidate C — Supervisor/router prompt (LLM picks next speaker)**

A dedicated supervisor LLM call reads the conversation history and the list of participating Personas (with their descriptions) and returns the name of the next speaker. This is AutoGen's SelectorGroupChat model and LangGraph's `langgraph-supervisor` pattern.

- How it maps to "feels more natural": High quality — the selector LLM can account for conversation flow, topic expertise implied by Persona descriptions, balance of participation, and unanswered questions. SelectorGroupChat prevents consecutive turns by the same speaker by default, which avoids the A-B-A-B ping-pong of Round-Robin while still being structured.
- Confirmed pattern: SelectorGroupChat is a production-stable AutoGen feature. LangGraph's `langgraph-supervisor` package implements an equivalent pattern where the supervisor is itself a graph node with conditional routing output. Both are in active use as of 2025.
- Implementation: A `select_next_speaker` node invokes the model with a prompt containing Persona names, descriptions, and recent messages. The response (Persona name) is used as the next edge target. The selector prompt is author-configurable (satisfies Infrastructure as Configuration for the prompt content; the model call itself uses the abstracted model interface).
- Limitation: Adds one model round-trip of latency per turn. The selector model must be the same provider-agnostic interface; hardcoding a specific model for the selector call would be an Infrastructure as Configuration violation.

**Candidate D — Stochastic selection weighted by topic relevance**

Each Persona's most recent response or System Prompt is embedded; similarity to the current conversation topic is computed; Personas are selected with probability proportional to their relevance score.

- How it maps to "feels more natural": Produces unpredictable speaker patterns, which may feel organic. However, the selection would not be explainable to the user, and a Persona could be repeatedly selected (or never selected) by chance. It introduces the same embedding infrastructure requirement as RQ-F1 Signal 3.
- Assessment: No established framework uses this as a primary selection mechanism. It is a novel design with unproven UX characteristics. Infrastructure as Configuration concern: embedding calls must use the abstracted interface.
- Verdict: Not a credible primary mechanism. Could theoretically be an option in a future experimentation mode.

**Does the choice have to be made architecturally, or can it be a configuration knob?**

The conditional edge function in LangGraph already reads from graph state, which is populated from application configuration. The *logic* of the edge function can be branched at runtime based on a `speaker_selection_mode` config value: `"addressability"`, `"supervisor"`, or `"round_robin"`. This means:

- The architectural choice is to use a conditional edge function (fixed).
- The *strategy* within that function is a configuration knob: `SPEAKER_SELECTION_MODE = addressability | supervisor | round_robin`.
- Addressability and supervisor can be layered: try explicit addressability first; if no addressee is detected, fall back to supervisor selection. This combination best satisfies the "more natural" intent while providing a reliable fallback.

**Recommendation-neutral summary:**

The combination of addressability-first with supervisor fallback most directly satisfies the "feels more natural than Round-Robin" intent: Personas direct each other by name when they naturally do so, and the supervisor fills the gap when they do not. Pure Round-Robin within P2P turns contradicts the stated intent. Stochastic selection has no established precedent and no clear Infrastructure as Configuration path. The choice can and should be a configuration knob backed by a multi-strategy conditional edge.

*Cross-reference:* RQ-A6 (conditional edge function is the confirmed architectural hook); RQ-F4 (if the Orchestrator is the turn router, the supervisor role in Candidate C may be the Orchestrator itself, collapsing two roles into one).

### RQ-F3 — User interruption semantics

**Status:** Complete

FR-8.7 requires that an `@Orchestrator` mention pauses the autonomous exchange and that resumption is always explicit. US-O3 reinforces this. In a live autonomous exchange, where does the pause actually take effect — after the current in-flight Persona response completes, immediately, or at the next turn-selection decision point? What is the implementation model for "pause", and how does the UI represent the paused state to the user?

**Research findings:**

*Cross-reference note:* RQ-A6 established that `interrupt()` / `Command(resume=...)` is the confirmed pause/resume mechanism and that the interrupt propagates between node executions — not mid-token-stream. Nodes restart from the beginning upon resume, requiring idempotent node design. RQ-F3 expands on the exact timing, the implementation model, and the UI representation.

**Where does the pause take effect?**

Three positions are theoretically possible:

1. **Immediately, mid-token-stream** — the current in-flight Persona response is truncated and discarded the moment an `@Orchestrator` mention arrives.
2. **After the current node completes** — the in-flight Persona response finishes generating; then, at the next turn-selection point, the interrupt takes effect.
3. **At the next turn-selection decision point** — effectively the same as (2) if the Persona node completes before the next speaker is chosen.

LangGraph's `interrupt()` function pauses execution at the exact point where it is called within a node, not mid-stream. When token streaming is occurring in a Persona node (calling the model with `stream=True`), the interrupt cannot fire mid-generation — it must be placed before or after the streaming call. The confirmed design pattern from RQ-A6 is to place `interrupt()` *after* the Persona response has been generated and committed to state, and *before* the next-speaker selection edge runs. This means:

**The pause takes effect after the current in-flight Persona response completes, at the next turn-selection decision point.** This is the only architecturally consistent position given LangGraph's streaming model, and it precisely matches FR-8.7's stated requirement.

This also means: if a user sends `@Orchestrator` mid-stream, the backend can acknowledge receipt of the message immediately (storing it as a pending interrupt signal), complete the current stream, commit the response to state, and then fire the interrupt at the turn-boundary. The user sees the Persona finish its response and then the exchange pauses — no partial message is shown.

**Implementation model for "pause"**

The sequence of operations when a user sends a message containing `@Orchestrator` during an autonomous P2P exchange:

1. The backend HTTP handler receives the user message and writes a `pending_interrupt = True` flag to the graph state (via `Command` on the checkpoint) or stores it in application memory associated with the `thread_id`.
2. The currently running Persona node completes its LLM call and streams the response to the frontend.
3. At the end of the Persona node, the node reads `pending_interrupt` from state. If True, it calls `interrupt(value={"reason": "user_mention", "message": user_message})`.
4. LangGraph saves the checkpoint, surfaces the interrupt to the caller, and halts the graph run.
5. The backend signals the frontend (via SSE or WebSocket event) that the exchange is now paused.
6. To resume, the user sends an explicit "resume" action (e.g. a button click or a follow-up message), which causes the backend to invoke `Command(resume={"user_response": ...})` against the same `thread_id`.
7. The Persona node restarts from the beginning (LangGraph re-execution behavior). If the LLM call is before the interrupt check, it re-runs. The solution is to place `interrupt()` as the *first action* in the node (before any LLM call), using the checkpoint state to supply the previous response rather than re-generating it.

*Node idempotency requirement (from RQ-A2):* Because the interrupted node restarts from the beginning on resume, any LLM call placed before the interrupt check will re-execute. The correct pattern is: commit the Persona's response to state before calling `interrupt()`, so that on resume the node finds the response already in state and skips the LLM call (idempotent guard: `if state["current_response"] is not None: skip_llm_call()`).

**What "pause" means without LangGraph**

If LangGraph is not used, the pause mechanism must be implemented at the application layer: an external flag in the database or an in-process event (a `threading.Event` or asyncio `Event`) watched by the turn-loop, which breaks out of the loop after the current Persona coroutine completes. The mechanics are equivalent; the implementation is bespoke.

**UI representation of the paused state**

Research into AG-UI (Agent-User Interaction Protocol, April 2025) and multi-agent chat UI patterns identifies the following established conventions for representing paused/awaiting states:

- **Status indicator** — a persistent badge or banner in the conversation thread: "Exchange paused — awaiting your input." Distinct visual state from "Typing…" (active) and idle (no activity). AG-UI defines a lifecycle event category that includes run-start and run-finish events, which the frontend can use to maintain a state machine (`running` → `paused` → `idle`).
- **Input field state** — the user message input is enabled (the user can type) but the "send" button changes label/icon to "Resume" or shows an explicit call-to-action. The current conversation thread is scrolled to show the last completed Persona response and the system notification that the exchange is paused.
- **In-thread system message** — a system message is inserted into the conversation thread at the point of pause: "[Exchange paused after @Orchestrator mention. Type to respond or press Resume to continue.]" This is consistent with FR-5.7's precedent for system messages as first-class thread entries.
- **No auto-resume** — US-O3 explicitly requires resumption to always be explicit. The UI must not auto-resume on a timer or on any user action other than an explicit resume command. Accidental key presses must not resume the exchange.

**AG-UI events relevant to this state:**

AG-UI's "Special events" category includes a pause-for-approval event type, which is the protocol-level expression of the `interrupt()` state. Frontends supporting AG-UI receive this event and render the paused state accordingly. For AI Council's custom frontend, the equivalent is a backend-pushed SSE event with a `type: "exchange_paused"` payload, which the frontend state machine handles by transitioning from `streaming` to `paused`.

*Cross-reference:* RQ-A6 (interrupt() / Command(resume=...) confirmed as the mechanism; node idempotency requirement); RQ-A2 (confirms idempotent node design requirement on resume); RQ-G2 (transport choice — SSE or WebSocket — determines how the `exchange_paused` event reaches the frontend); RQ-G3 (the paused state is a sub-state of the "system not idle" category that gates UI controls).

### RQ-F4 — Orchestrator's P2P role (open question from overview)

**Status:** Complete

The overview (Section 5.4 Peer-to-Peer Role) explicitly defers whether the Orchestrator plays a role in P2P turn routing and throttling. This is a substantive architectural question, not just a research one: if the Orchestrator is the turn router, then the Orchestrator is an active controller; if the Orchestrator is purely a monitor, then turn routing and throttling live elsewhere. Research should enumerate the two positions, their implementation implications, and any hybrid positions. The final choice will be a decision for the developer.

**Research findings:**

*Baseline from the overview:* Section 5.4 defines the Orchestrator as a "background process that monitors the interaction" whose "primary user-facing responsibility is to suggest additional Personas." It explicitly does not add Personas or route turns without user confirmation. The Peer-to-Peer Role note states: "Whether the Orchestrator plays a role in managing P2P turn routing and throttling is an open question, dependent on how the technical solution handles the use case."

The overview therefore already establishes the Orchestrator as a *monitor/suggester* for non-P2P concerns. RQ-F4 is about whether its mandate should be extended to include turn routing and throttling in P2P.

**Position A — Orchestrator as pure monitor; turn routing and throttling live elsewhere**

In this position, P2P turn routing and throttling are handled by a separate application-layer component — the turn-router — which is not the Orchestrator. The Orchestrator continues to function solely as a background suggestion engine. The turn-router is an infrastructure component (e.g. the LangGraph conditional edge function and throttle-check node) with no LLM personality, no user-facing persona, and no suggestion authority.

*Responsibilities of the turn-router:*
- Evaluates next-speaker selection (RQ-F2 logic)
- Applies throttle signals (RQ-F1 hard cap, repetition hash, optional embedding similarity)
- Detects `@Orchestrator` mention and routes the message to the Orchestrator
- Routes `@Orchestrator` responses back into the conversation thread
- Handles the interrupt/resume lifecycle (RQ-F3)

*Responsibilities of the Orchestrator (unchanged from overview):*
- Monitors conversation content
- Surfaces Persona addition suggestions
- Responds to `@Orchestrator` direct mentions

*Implementation:* The turn-router is a LangGraph conditional edge function and a set of graph nodes (throttle-check, interrupt-handler). It has no model call of its own for routing decisions unless the supervisor-LLM speaker-selection strategy (RQ-F2 Candidate C) is used — in which case, a *separate* lightweight LLM call for speaker selection is made, distinct from the Orchestrator's monitoring call.

*Tradeoffs:*
- Clear separation of concerns: the Orchestrator's suggestion logic is not entangled with turn-routing logic. Changes to throttle strategy do not require changes to the Orchestrator prompt and vice versa.
- Two independent background processes run during P2P: the turn-router (always active, per-turn) and the Orchestrator monitor (active but triggered less frequently). Their lifecycle and scheduling are independent.
- If the supervisor-LLM speaker-selection strategy is used, there is a *second* model call per turn cycle (one for speaker selection, one for Orchestrator monitoring). This has a non-trivial latency and cost implication.
- The Orchestrator's `@Orchestrator` mention handler must be wired into the turn-router so that it intercepts the mention at the turn boundary — not a conceptual violation of this position but requires coordination between the two components.

**Position B — Orchestrator as active P2P controller; turn routing and throttling are Orchestrator responsibilities**

In this position, the Orchestrator is promoted from a background monitor to the active turn router for P2P mode. It evaluates next-speaker selection, applies throttle signals, and manages the autonomous exchange loop. The same LLM call that evaluates topic and suggestions also decides who speaks next.

*Merged responsibilities:*
- Topic monitoring and Persona suggestion (existing)
- Next-speaker selection (new)
- Throttle evaluation — either as a combined "progress + routing" prompt or as a separate evaluation hook (new)
- Interrupt handling for `@Orchestrator` mentions (existing for suggestion response, extended for routing)

*Implementation:* The Orchestrator becomes a `supervisor` graph node in LangGraph, making a model call after each Persona response to decide: (a) which Persona speaks next, and (b) whether to continue, throttle, or surface a suggestion. This aligns with LangGraph's `langgraph-supervisor` pattern. The supervisor node is an LLM-powered coordinator.

*Tradeoffs:*
- Fewer conceptually distinct components — one background process handles both monitoring and routing.
- The Orchestrator LLM call already occurs (for monitoring); extending its prompt to include routing decisions may not add a full extra round-trip if the call is already happening per-turn.
- However: the overview explicitly restricts the Orchestrator from directly controlling the conversation flow. Promoting it to active turn router would expand its authority beyond what the product spec currently allows. The overview says the Orchestrator "suggests" and "never automatically adds a Persona." If the Orchestrator also decides turn order and applies throttle, it crosses from suggestion into control. This is a product spec tension, not just a technical preference.
- The Orchestrator's monitoring call frequency (currently unspecified — possibly per-message, possibly periodic) would need to match the turn-routing frequency (per-turn in P2P). If these frequencies differ, the combined approach forces the monitoring rate to equal the routing rate, which may be more frequent than the Orchestrator was intended to operate.
- Mixing routing logic with suggestion logic in a single LLM call increases prompt complexity and makes each concern harder to test, tune, and debug independently.

**Hybrid Position — Orchestrator as trigger-only throttle decision-maker; deterministic router handles turn selection**

In this position, the turn order selection is handled deterministically (addressability-first with round-robin fallback) by the conditional edge function — no LLM call required for next-speaker. Throttle evaluation for hard cap and repetition detection is also deterministic (graph state inspection). The Orchestrator is invoked *only* when the deterministic throttle signals are ambiguous (i.e., neither the hard cap nor the repetition detector has fired, but the exchange has been running for N turns without a clear signal) — at that point, the Orchestrator makes an LLM-mediated "meaningful progress" judgement call. The Orchestrator does not decide *who* speaks next; it only decides *whether* to continue.

*Implementation:* The throttle-check node (RQ-F1 Layer 4) is implemented as an Orchestrator call. The Orchestrator monitor and the throttle check share the same model call, reducing the number of distinct LLM invocations. The turn-router calls the Orchestrator node only when escalation is warranted.

*Tradeoffs:*
- The Orchestrator's monitoring and throttle-escalation roles are related: both require understanding conversation content and progress. Merging these into one LLM call is architecturally coherent.
- The Orchestrator does *not* control turn order — it remains a non-controlling background process, consistent with the product spec.
- The escalation trigger (after N turns without deterministic signal) is a configuration value (Infrastructure as Configuration compatible).
- The Orchestrator's throttle-escalation prompt and its suggestion prompt can be combined or separate, depending on whether they are evaluated at the same frequency. If they differ, the hybrid position requires scheduling both.

**Research note: there is no established name for this three-way distinction in the literature**

Industry literature (LangGraph supervisor, AutoGen SelectorGroupChat, AWS multi-agent reference architecture) uniformly describes orchestrators as *active controllers* — they route, they select speakers, they manage the loop. The AI Council overview's definition of the Orchestrator as a *non-controlling background observer* is a deliberate product-level constraint that differentiates it from the standard orchestrator pattern. The research findings above are therefore constructed from first principles applied to the specific constraints, not from a directly precedented pattern.

**Summary of positions for the developer's decision:**

| Dimension | Position A (separate router) | Position B (Orchestrator controls) | Hybrid |
| --- | --- | --- | --- |
| Conforms to overview's Orchestrator-as-monitor mandate | Yes | Partially — requires spec extension | Yes |
| Model calls per P2P turn | 1 (Persona) + optional supervisor LLM | 1 (Persona) + 1 (Orchestrator/router) | 1 (Persona) + 1 (Orchestrator, escalation only) |
| Separation of concerns | High | Low | Medium |
| Implementation complexity | Two components to test/maintain | One component, higher prompt complexity | One escalation path added to existing components |
| Risk of Orchestrator overreach | None | High — needs spec guard rails | Low — routing stays deterministic |

*Cross-reference:* RQ-F1 (throttle signals — Layer 4 LLM evaluation is the Orchestrator touch-point in the hybrid position); RQ-F2 (next-speaker selection — deterministic in Positions A and Hybrid; LLM-mediated in Position B); RQ-A6 (conditional edge function is the confirmed graph-layer hook for both routing and throttle check).

---

## Group G: Frontend and Backend Split (NFR-8 Flag)

### RQ-G1 — Frontend and backend as separate deployable units

**Status:** Complete

NFR-8 requires that the frontend and backend be separate deployable units to allow independent scaling in a future cloud deployment, even if V1 deploys them together. What are the credible patterns for this — a single-page application served alongside an API backend, a server-rendered frontend with a separate backend-for-frontend, a fully split SPA + API contract, or an Electron-style desktop wrapper? What are the tradeoffs in packaging simplicity (NFR-5), responsiveness (NFR-1), and cloud deployability (FR-22.2)?

**Research findings:**

*Candidate 1 — SPA (static build) + API backend (fully split):*

The frontend is a compiled set of static files (HTML, JS, CSS) served from anywhere — a CDN, a static file server, or a dedicated path on the backend. The backend exposes a REST/SSE API only. The two units are independently deployable because the frontend has no runtime dependency on the backend process — it fetches data at runtime. In V1 local deployment, the backend process can serve the static files from a `/static` route with zero additional infrastructure. In cloud deployment, the frontend can move to a CDN without any backend change.

Tradeoffs:
- Packaging (NFR-5): excellent. The frontend build step (`npm run build`) produces a `/dist` folder. The backend serves it or a separate static server does. No per-OS configuration required.
- Responsiveness (NFR-1): the initial page load fetches the full JS bundle on first visit; subsequent navigation is purely client-side (fast). For a local-first app where the "CDN" is localhost, the initial bundle load is effectively instant.
- Cloud deployability (FR-22.2): excellent. The static frontend can move to a CDN independently of the backend. Backend can scale horizontally without touching the frontend. This is the canonical split that NFR-8 describes.
- API contract: the frontend communicates with the backend only via the agreed HTTP/SSE API. This enforces the boundary structurally.
- Constraint: the frontend and backend must run on a known pair of host:port in V1. A local config file or environment variable provides the backend URL to the frontend at build time or via a runtime config endpoint — satisfying Infrastructure as Configuration.

*Candidate 2 — Server-rendered frontend (SSR) with a separate backend:*

The frontend is a server-side rendering process (e.g., SvelteKit Node adapter, Next.js) that communicates with the backend API. The SSR server renders HTML pages and serves them to the browser. The backend is a separate process serving only data.

Tradeoffs:
- Packaging (NFR-5): poor for local-first V1. Two backend-ish processes (the SSR server and the API server) must be started and managed together. For a single-user local app this is significant overhead with no benefit — there is no SEO requirement (FR not present) and no page-load performance requirement beyond what a SPA delivers from localhost.
- Cloud deployability (FR-22.2): better for multi-user cloud scenarios (pages are rendered server-side, no JS requirement for first paint), but this is not a V1 concern.
- Verdict: SSR introduces packaging complexity that conflicts with NFR-5 without offering any V1 benefit. It would be revisited only if a public-facing cloud product required SEO or initial render performance.

*Candidate 3 — Backend-for-Frontend (BFF) pattern:*

A BFF is an intermediate server layer that aggregates multiple backend services for a specific frontend's needs. It is not a credible V1 pattern for AI Council: there is only one backend, so a BFF adds a redundant proxy layer with no aggregation benefit. Excluded.

*Candidate 4 — Electron / Tauri desktop wrapper:*

Desktop wrappers (Electron, Tauri) bundle the frontend into a native app binary. The frontend runs in an embedded WebView; the backend runs as a sidecar process or as Rust code (Tauri) within the same binary.

- Electron: bundles Chromium + Node.js. Binary size 100–150 MB minimum for "Hello World". Enables Node.js-based backend-frontend IPC. The backend (Python or Node) must still be started separately or as a subprocess.
- Tauri: uses the OS WebView (WebKit/WebView2), dramatically smaller binaries (~5–20 MB). Rust handles the native layer. Python or Node.js backend runs as a sidecar process. The sidecar pattern is documented by Tauri but requires bundling the Python runtime or Node binary, which reintroduces packaging complexity.

Tradeoffs:
- Packaging (NFR-5): a single installable binary is attractive in theory. In practice, bundling a Python runtime (for the backend) alongside Tauri adds significant complexity and produces binaries of 50–200 MB depending on included packages. Ollama for local LLMs must be separately installed regardless.
- Cloud deployability (FR-22.2): desktop wrappers do not deploy to cloud environments. A cloud version would need to be rebuilt as a web app — a significant rework, contrary to NFR-8's goal.
- Verdict: desktop wrappers are incompatible with NFR-8's cloud-portability requirement. The pattern locks the product into a desktop distribution model.

*Summary:*

| Pattern | Packaging (NFR-5) | Cloud portability (FR-22.2) | Complexity |
| --- | --- | --- | --- |
| SPA + API (split) | Excellent | Excellent | Low |
| SSR frontend + API | Poor (two servers) | Good | Medium |
| BFF | N/A (unnecessary layer) | N/A | High |
| Electron/Tauri wrapper | Medium (binary size) | Poor (rework required) | High |

The SPA + API pattern is the only candidate that satisfies both NFR-5 and NFR-8 simultaneously. In V1, the backend serves the static frontend build as a convenience; in cloud deployment, the static files move to a CDN without code change.

*Infrastructure as Configuration check:* The backend URL used by the frontend must be configurable without a code change (e.g., via a build-time environment variable `VITE_API_BASE_URL` or equivalent). This is standard practice for any SPA build pipeline and does not constitute a violation.

*Cross-references:* RQ-G4 (frontend framework choice) determines the SPA build toolchain. RQ-G5 (backend framework) determines which server serves the static files in V1. RQ-G2 (real-time transport) determines the SSE/WebSocket endpoint the SPA connects to.

### RQ-G2 — Real-time update transport

**Status:** Complete

FR-8.6, FR-8.7, FR-5.15, US-O3 and other requirements imply the frontend needs to receive streaming or near-real-time updates during Conversation activity — new Persona responses in Round-Robin cycles, autonomous P2P exchanges, Orchestrator suggestions surfacing mid-Conversation, and the system idle/non-idle state that gates many UI controls. What is the appropriate transport mechanism — Server-Sent Events, WebSockets, long polling, or HTTP with client-side polling? How does this choice interact with streaming model responses (see RQ-C4)?

**Research findings:**

*RQ-C4 cross-reference (confirmed):*

RQ-C4 concluded that SSE is the correct default for Persona response streaming and that the client-to-server interrupt (pause/cancel FR-8.7) can be handled via a separate HTTP POST rather than requiring WebSocket bidirectionality. This finding must be consistent with the transport decision here. The two questions converge: the transport decided in RQ-G2 also handles Persona token streaming.

*Candidate 1 — Server-Sent Events (SSE):*

SSE is a unidirectional server-to-client push protocol running over standard HTTP. The browser opens a persistent HTTP connection via the `EventSource` API; the server sends newline-delimited `data:` events. The connection auto-reconnects on drop. Named event types allow multiplexing multiple logical streams (e.g., `event: token`, `event: orchestrator_suggestion`, `event: idle_state`).

Relevant properties for AI Council:
- Token streaming: confirmed fit. LangGraph's `graph.stream()` yields node outputs that can be formatted as SSE events and flushed immediately. FastAPI supports this via `sse-starlette`'s `EventSourceResponse` or via `StreamingResponse` with `text/event-stream` content type.
- Orchestrator suggestions (FR-8.6): suggestions are server-initiated events; SSE delivers them without client polling.
- P2P pause state (`exchange_paused`, RQ-F3): the backend emits an `exchange_paused` SSE event when the P2P loop is interrupted; the frontend receives it and updates UI. No bidirectional channel needed for the notification.
- Idle/non-idle state (RQ-G3): SSE can carry `idle_state` events as a named event type on the same connection, keeping the frontend in sync without polling.
- HTTP/2 multiplexing: under HTTP/2, multiple SSE streams from the same origin do not each consume a separate TCP connection; they are multiplexed on one connection, removing the browser's historical 6-connection-per-domain limit on SSE. For a local-first app (always HTTP/2-capable via localhost), this is not a constraint.
- Proxy compatibility: SSE uses standard HTTP, so it is not blocked by corporate proxies or firewalls that strip WebSocket upgrades. For a local-first app this is less relevant, but the constraint matters for future cloud deployment.
- Auto-reconnect: the browser `EventSource` API reconnects automatically on connection loss with the `Last-Event-ID` header, allowing the backend to resume from a known position. This is available without application-layer retry logic.

Limitations:
- Unidirectional. Client-to-server signals (pause, cancel, resume) must go over a separate HTTP POST endpoint. This is the architectural pattern confirmed by RQ-C4. It is not a complication — these signals are already modelled as REST calls (e.g., `POST /conversations/{id}/pause`).
- Native `EventSource` does not support `POST` with a request body. If the initial stream-open request must carry a payload (e.g., conversation ID and parameters), either a `GET` with query parameters is used (acceptable) or the `@microsoft/fetch-event-source` library is used on the client (supports `POST` with headers/body). The LangGraph + FastAPI integration article confirms this pattern.

*Candidate 2 — WebSockets:*

WebSockets provide full-duplex persistent connections. Used when both client and server need to send messages on the same channel without the request-response overhead.

Relevant properties:
- Full-duplex is not needed for AI Council's primary push use case (token streaming, suggestions, idle state). It would be needed only if the client must send messages on the same connection as the stream arrives.
- FR-8.7 pause/cancel: could be sent over the same WebSocket that receives token deltas. However, RQ-C4 confirmed that the interrupt takes effect between Persona responses (not mid-token), so the latency difference between sending a WS message and a HTTP POST is negligible.
- Complexity: WebSockets require connection lifecycle management (open, ping/pong keepalive, error detection, manual reconnect logic) that SSE provides automatically. Most real WebSocket implementations require a library (Socket.IO or similar) to handle reconnection robustly. This is additional complexity with no functional benefit over SSE for AI Council's use case.
- Python framework support: both FastAPI and Litestar support WebSockets natively. Not a differentiator.

*Candidate 3 — Long polling:*

Long polling is now a legacy technique. It creates high connection overhead (repeated HTTP handshakes), has no standard reconnection protocol, and imposes server-side complexity for managing held requests. Every source reviewed categorises it as a fallback for environments where SSE and WebSockets are unavailable. It is not a credible choice for a new application in 2026.

*Candidate 4 — Short polling (periodic HTTP GET):*

Simple but fundamentally unsuitable for token streaming, which requires low-latency incremental delivery. Also creates unnecessary backend load even during idle periods. Excluded.

*Recommended pattern:*

SSE is the correct transport for AI Council. Specific design:

- One SSE endpoint per active Conversation: `GET /conversations/{id}/stream`. The frontend opens this connection when the user enters a Conversation and closes it on leave.
- Named event types multiplexed on the single connection:
  - `token` — content delta for the currently streaming Persona response.
  - `response_complete` — signals end of a Persona response in Round-Robin or P2P mode.
  - `orchestrator_suggestion` — surfaces a suggestion from the Orchestrator (FR-8.6).
  - `exchange_paused` — signals P2P mode has paused (RQ-F3).
  - `idle` / `busy` — system idle state transitions (RQ-G3).
- Client-to-server signals remain as HTTP POST endpoints: `pause`, `resume`, `cancel`, `send_message`.
- The `@microsoft/fetch-event-source` library on the client allows `POST` for the initial connection if the conversation requires authentication context in the request body; otherwise, native `EventSource` with query parameters is sufficient.

*Infrastructure as Configuration check:* The SSE endpoint URL is configuration (it follows from the backend base URL, which is already identified as a config value in RQ-G1). No violation.

*Cross-references:*
- RQ-C4 → RQ-G2: SSE confirmed as consistent with Group C streaming findings.
- RQ-F3 → RQ-G2: `exchange_paused` event delivered via the `exchange_paused` SSE event type on the Conversation stream.
- RQ-G3 → RQ-G2: idle state propagated via `idle`/`busy` SSE events on the same stream.
- RQ-G5 → RQ-G2: backend framework must support `EventSourceResponse` or `StreamingResponse` with `text/event-stream`. Both FastAPI (`sse-starlette`) and Litestar (native SSE support) satisfy this.

### RQ-G3 — System idle state propagation

**Status:** Complete

Many requirements gate UI controls on "system is idle" (FR-5.8, FR-3.10, FR-6.4, FR-9.3, FR-9.4, US-R3, and others). Where should "idle" be determined — in the backend as the authority, in the frontend from local state, or both with the backend as source of truth? How is this state kept in sync across the transport chosen in RQ-G2?

**Research findings:**

*What "idle" means across requirements:*

- FR-5.8: no action queuing — if the system is not idle, the user cannot send another message; the send button must be disabled.
- FR-3.10: export is gated on idle (no in-flight Conversation activity).
- FR-6.4, FR-9.3, FR-9.4: Persona management and Workspace-level actions gated on idle.
- US-R3: Round-Robin cycle must complete before the user can send the next message.
- RQ-F3 context: "exchange_paused" is a sub-state of non-idle — the system is not idle when the P2P exchange is paused, because re-starting would affect in-flight graph state. The UI must treat `paused` as a non-idle variant that enables a Resume button rather than a Send button.

This means "idle" is not a simple boolean — it has at least three variants: `idle`, `busy` (actively generating), and `paused` (P2P loop interrupted, awaiting user resume decision). The UI needs all three states to render correctly.

*Option A — Backend as sole authority, frontend polls:*

The frontend periodically polls `GET /conversations/{id}/status` to fetch idle state. Simple but creates unnecessary load and introduces latency (the status update arrives at most every poll interval after the actual state change). Not appropriate for token-streaming UX where the "idle" transition is a precise moment (last token received, stream closed).

*Option B — Frontend derives idle state from local signals:*

The frontend tracks whether a streaming response is in progress based on SSE stream open/close events. When the `response_complete` SSE event arrives and no new streaming begins, the frontend transitions itself to idle and re-enables controls.

Problems:
- The frontend cannot observe all causes of non-idle state. Background jobs (the nightly Review Agent, memory compression) are not visible to the frontend unless explicitly signalled. A background memory compression run that locks the Conversation from editing would not be reflected in locally derived idle state.
- If the SSE connection drops and reconnects, the frontend must re-query the backend for current state — it cannot reconstruct it from the stream alone.
- Network partitions between the frontend and backend (brief in a local-first app, but possible) create a window where the frontend incorrectly believes the system is idle.

*Option C — Backend as authoritative source of truth, pushed via SSE:*

The backend maintains the definitive idle state per Conversation (or per Workspace for global operations). State transitions are emitted as SSE events (`event: idle`, `event: busy`, `event: paused`). The frontend reflects whatever state the backend last pushed, with no independent derivation.

Advantages:
- Single source of truth. The backend already knows when a LangGraph graph is running (the checkpointer tracks execution state), when a background job has locked a resource, and when an `exchange_paused` interrupt has been set.
- The frontend cannot be out of sync except during an SSE connection gap. On reconnection, the frontend requests the current state via a REST endpoint before re-attaching the stream — this is a standard SSE reconnection pattern (`Last-Event-ID` or an initial status fetch).
- The `paused` sub-state (RQ-F3) is a first-class backend concept (the LangGraph graph is at an `interrupt()` checkpoint). Only the backend can know this; the frontend cannot derive it.

Limitations:
- The backend must explicitly track and emit idle state changes, including for background operations (Review Agent). This is additional backend state management, but it is the correct location for this authority.
- If the SSE connection is down, the frontend does not know the current state. Mitigation: on reconnect or initial page load, fetch `GET /conversations/{id}/status` to get the current `{state: "idle" | "busy" | "paused"}` before attaching the stream.

*Option D — Frontend local optimistic state + backend authority:*

A hybrid where the frontend immediately disables the send button when the user submits (optimistic "busy"), and then the backend sends the authoritative state transition events. This prevents the brief window between user action and first backend SSE event where the user could double-submit. This is an additive pattern on top of Option C, not a replacement — the backend remains the authority; the frontend just applies a local optimistic lock on user action.

*Recommended pattern:*

Backend is the sole authority for idle state. The state machine per Conversation has three values: `idle`, `busy`, `paused`. Transitions are emitted as SSE events on the Conversation stream. The frontend reflects the last-received state. On initial connection or reconnection, the frontend fetches the current state via a synchronous REST call before subscribing to the stream. The frontend additionally applies an optimistic lock (disabling the send button immediately on user submission) to handle the latency gap before the first `busy` event arrives.

*Idle state for Workspace-level gates (FR-9.3, FR-9.4, FR-6.4):*

These gates apply to the Workspace, not to individual Conversations. A separate `workspace_status` endpoint and corresponding SSE event type (if a global Workspace stream is opened) would handle this. Alternatively, gated actions that span the Workspace can simply call the backend and receive a 409 Conflict if the system is not in a safe state to perform the action — the frontend then surfaces the error. This avoids the need for a per-Workspace SSE stream for a relatively rare UI event.

*Cross-references:*
- RQ-G2 → RQ-G3: idle state pushed via SSE using named event types (`idle`, `busy`, `paused`) on the Conversation stream decided in RQ-G2.
- RQ-F3 → RQ-G3: `paused` is a first-class idle sub-state originating from the P2P exchange interrupt (FR-8.7). The backend emits `paused` when LangGraph hits an `interrupt()` checkpoint; the frontend enables the Resume control instead of the Send control.
- RQ-I11 → RQ-G3: RQ-I11 asks about the race condition risk and per-aggregate lock granularity for idle enforcement. The pattern here (backend authority, SSE push, HTTP 409 on conflict) is consistent with a per-Conversation idle flag held in the backend.

### RQ-G4 — Frontend framework choice

**Status:** Complete

No framework has been chosen for the frontend. What are the credible candidates (React, Vue, Svelte, SolidJS, Astro, vanilla with web components, HTMX + server templates) given the real-time update needs in RQ-G2, the single-page editorial nature of the Personas configuration (FR-4.9 test panel), the sidebar navigation of Discussions (FR-2.1 to FR-2.5), and the requirement that the frontend be independently deployable (NFR-8)?

**Research findings:**

*Framing: what the UI requires:*

AI Council's frontend is primarily a single-page application with a persistent sidebar (Workspace/Conversation list, FR-2.1–FR-2.5), a real-time message thread (streaming SSE tokens), a Persona configuration panel (FR-4.9 test panel), and several modal flows. It is interactive and stateful. There is no public-facing marketing surface and no SEO requirement. The interaction model is closer to a chat/IDE application than a content site.

*Candidate 1 — React (with Vite):*

React 19 (2025) holds approximately 39% market share. The ecosystem is the largest of any frontend framework — UI component libraries, SSE handling (`EventSource`, `fetch-event-source`), state management (Zustand, TanStack Query), routing (React Router, TanStack Router) all have mature, well-documented solutions.

Tradeoffs:
- Bundle size: React runtime is ~40 KB (gzip); a complete app with router and state library is typically 100–200 KB. Acceptable for a local SPA where load is from localhost.
- SSE integration: React has no built-in SSE abstraction; custom hooks over `EventSource` or `fetch-event-source` are idiomatic and well-documented. TanStack Query can manage SSE-derived data with cache invalidation.
- Real-time streaming rendering: React re-renders on state change; streaming token accumulation requires accumulating tokens in local state and triggering a re-render per event. With React 19's concurrent features, this is efficient enough for typical LLM streaming rates (10–30 tokens/second).
- Developer experience: largest hiring pool, most StackOverflow answers, most tutorials. Lowest risk for a team unfamiliar with newer frameworks.
- Independently deployable: a Vite build produces a `/dist` folder of static assets. No server process required for the frontend unit.

*Candidate 2 — Svelte 5 (with SvelteKit in SPA mode):*

Svelte compiles to vanilla JavaScript at build time, shipping ~1.6 KB of framework runtime. Svelte 5 introduced "runes" — a new, more explicit reactivity primitive that replaces the previous implicit `$:` syntax. In SPA mode (using the `@sveltejs/adapter-static` adapter), SvelteKit produces a static build equivalent to a React + Vite SPA — independently deployable, no server process.

Tradeoffs:
- Bundle size: 60–70% smaller than equivalent React applications. In a local-first app this is a secondary concern but contributes to faster initial load and simpler caching.
- SSE integration: Svelte stores + `EventSource` in a `onMount` lifecycle is a clean, minimal pattern. Fine-grained reactivity means the message thread updates only the specific DOM node containing the streaming token, without re-rendering surrounding UI.
- Real-time streaming rendering: Svelte's fine-grained DOM updates (no virtual DOM diffing) make it particularly efficient for high-frequency token streaming — each token update patches only the target text node.
- Developer experience: rated highest in satisfaction surveys (2025 State of JS). Steeper initial adjustment for teams coming from React but generally considered easier to learn from scratch. Smaller ecosystem than React; some enterprise component libraries are React-only.
- Independently deployable: `adapter-static` produces a `/dist` folder; same pattern as React + Vite.

*Candidate 3 — SolidJS:*

SolidJS uses a React-like JSX syntax but compiles to fine-grained DOM updates (signals), not a virtual DOM. Benchmarks consistently place SolidJS at the top of JavaScript framework performance charts.

Tradeoffs:
- SSE and streaming: SolidJS's reactive primitives (`createSignal`, `createResource`) handle SSE-derived state naturally. Fine-grained reactivity is ideal for token streaming — only the updated text node re-renders.
- Ecosystem: much smaller than React or Svelte. UI component libraries, routing solutions, and community resources are fewer. In 2025, SolidJS powers approximately 1–2% of new SPAs vs Svelte's growing share.
- Developer experience: steeper learning curve despite React-like syntax — the mental model (signals run once, not on every render) is different from React. Hiring and onboarding risk is higher.
- Independently deployable: SolidJS builds to static assets via Vite. No server process.
- Verdict: a credible performance-optimised choice. The ecosystem gap vs Svelte is the primary risk.

*Candidate 4 — Vue 3:*

Vue 3 with Vite is the mainstream alternative to React, with a gentler learning curve. The Composition API aligns well with React hooks in mental model.

Tradeoffs:
- Bundle size: ~20 KB runtime, smaller than React, larger than Svelte.
- SSE integration: equivalent to React — custom composables over `EventSource`. Ecosystem is mature.
- Independently deployable: Vite build, static assets. Same pattern.
- Verdict: a credible candidate. Vue's primary differentiator (over React) is slightly smaller bundles and arguably smoother DX. It does not outperform Svelte or SolidJS for streaming-heavy UIs.

*Candidate 5 — HTMX + server templates:*

HTMX adds HTML-attribute-driven AJAX behaviour to server-rendered pages. It is appropriate for CRUD-heavy, low-interactivity applications where the team has no frontend specialists.

AI Council's requirements make HTMX a poor fit:
- A streaming token thread requires appending DOM nodes in real time as SSE events arrive. HTMX's `hx-sse` extension can do this, but it offloads the rendering to the server (the server renders partial HTML fragments) rather than the client. This means every token delta goes through a round-trip to the template engine before appearing on screen — unnecessary latency and coupling.
- The Persona test panel (FR-4.9) is a complex interactive form with real-time preview; HTMX's pattern of full or partial page replacement is architecturally awkward for this.
- NFR-8 requires an independently deployable frontend. An HTMX frontend is tightly coupled to the server template engine — it is not independently deployable unless the server renders nothing beyond the HTMX-attributed HTML, in which case it effectively becomes a SPA in disguise.
- Verdict: excluded for AI Council's use case.

*Candidate 6 — Astro:*

Astro is a static site framework with an "islands architecture" for selective hydration. Its primary use case is content sites (blogs, marketing). For a highly interactive SPA with a persistent real-time thread, Astro adds complexity without benefit — the whole application is effectively one interactive island. Excluded.

*Candidate 7 — Vanilla JS / Web Components:*

No framework at all, using only the browser's native `EventSource`, `fetch`, `<template>` elements, and `customElements.define`. Maximum control, minimum dependencies, minimum bundle size.

Tradeoffs:
- No virtual DOM / reactivity primitive means managing the streaming token thread, the sidebar state, and modal flows manually. The boilerplate cost is high.
- Web Components are now well-supported (Chrome, Firefox, Safari) but the authoring DX is significantly more verbose than any framework alternative.
- Excluded as the primary choice. Could be revisited for a performance-critical embeddable widget, but not the application shell.

*Summary of credible candidates:*

| Framework | Bundle size | SSE/streaming fit | Ecosystem maturity | Independent deploy |
| --- | --- | --- | --- | --- |
| React 19 + Vite | ~150 KB app | Good (hook pattern) | Excellent | Yes (static /dist) |
| Svelte 5 + SvelteKit | ~30–60 KB app | Excellent (fine-grained) | Good (growing) | Yes (adapter-static) |
| SolidJS + Vite | ~40–80 KB app | Excellent (signals) | Limited | Yes (static build) |
| Vue 3 + Vite | ~80–120 KB app | Good | Good | Yes (static /dist) |

*Cross-references:*
- RQ-G2 → RQ-G4: SSE is the transport. All four credible framework candidates support SSE natively via `EventSource` or `fetch-event-source`. No framework constraint is created by the SSE choice.
- RQ-G1 → RQ-G4: independently deployable requirement is satisfied by all four candidates (all produce static build artefacts).
- RQ-G5 → RQ-G4: if the backend is Python (FastAPI/Litestar), the frontend framework choice is unconstrained — any JavaScript framework can consume a REST + SSE API. If the backend is Node.js, there is also no constraint (the API contract is the boundary).

### RQ-G5 — Backend framework choice

**Status:** Complete

No framework has been chosen for the backend. What are the credible candidates given (a) the language implied by the agentic framework choice in Group A, (b) the background job needs in Group D, (c) the transport needs in RQ-G2, and (d) the packaging simplicity requirement (NFR-5)? Python candidates include FastAPI, Litestar, Django, and Flask. Node candidates include Fastify, NestJS, and Hono. Other language candidates (Go, Rust, Elixir) should be surfaced only if they have a credible agentic ecosystem story.

**Research findings:**

*Language constraint from Group A:*

Group A findings (RQ-A3) confirmed that LangGraph Python is the primary development target and carries lower risk for edge-case features than the TypeScript port. RQ-A3 also noted that a Python backend (FastAPI, Litestar) makes Python LangGraph the natural fit, while a Node.js backend would require the TypeScript LangGraph stack with a small residual risk of feature lag. The agentic layer does not mandate Python, but it strongly biases toward it for reduced integration risk.

*Constraint axis 1 — Async-first for SSE/streaming (RQ-G2):*

SSE streaming requires the server to hold an HTTP connection open and flush incremental bytes. This is efficient only with an async I/O model — a synchronous WSGI framework (Flask, Django pre-4.x) would block a thread per open SSE stream, making it unsuitable for concurrent streaming Conversations. The framework must be ASGI-based (Python) or event-loop-based (Node.js).

*Constraint axis 2 — Background scheduler integration (RQ-D1):*

APScheduler's `AsyncIOScheduler` integrates with async frameworks via a lifespan context manager. This is native to FastAPI and Litestar. Django's background task framework (added in 6.0, December 2025) is an alternative but is newer and less proven for async scheduling.

*Constraint axis 3 — Packaging simplicity (NFR-5):*

The backend must start with a single command (e.g., `uvicorn app.main:app`). No external broker process, no separate scheduler process. All four Python async candidates and Node.js candidates satisfy this constraint.

*Python Candidate 1 — FastAPI:*

FastAPI (Starlette-based, Pydantic v2) is the current dominant choice for Python async API development. Adoption grew from 29% to 38% of Python developers in 2025 (JetBrains survey), and the framework has over 80,000 GitHub stars.

Relevant properties:
- SSE: supported via `sse-starlette` (`EventSourceResponse`) or `StreamingResponse` with `text/event-stream`. The LangGraph + FastAPI + SSE pattern is documented and in production use.
- Background jobs: FastAPI's built-in `BackgroundTasks` handles lightweight fire-and-forget tasks (e.g., triggering a post-response database write). For APScheduler nightly jobs (RQ-D1), `AsyncIOScheduler` is started in the FastAPI lifespan context manager — a documented, widely used pattern.
- LangGraph integration: LangGraph's own tutorials use FastAPI as the backend. The `graph.stream()` iterator integrates directly with FastAPI's async generator streaming pattern.
- Ecosystem: largest Python async ecosystem. Authentication, database access (SQLAlchemy, asyncpg), migrations (Alembic), testing (pytest + httpx) are all well-documented.
- Dependency injection: function-based `Depends()` injection; simpler to learn than Litestar's system, slightly less powerful for complex override scenarios.
- Community risk: FastAPI's creator has reduced his direct involvement; the framework is maintained by a broader contributor group, but the governance model is less formal than Django's. This is a noted risk in some analyses but has not resulted in slower development as of early 2026.

*Python Candidate 2 — Litestar:*

Litestar (formerly Starlette) is a high-performance async framework positioning itself as an enterprise-grade alternative to FastAPI with stricter typing, a more powerful dependency injection system, and native SQLAlchemy integration.

Relevant properties:
- SSE: Litestar has native SSE support via `ServerSentEvent` route handlers. No external library required.
- Background jobs: APScheduler `AsyncIOScheduler` integrates via Litestar's `on_startup`/`on_shutdown` lifespan hooks.
- Performance: benchmarks show Litestar consistently outperforms FastAPI on raw throughput due to msgspec serialization (claimed ~12x faster than Pydantic v2, ~85x vs Pydantic v1). In practice, for AI Council's use case the bottleneck is LLM inference time (seconds), not serialization (microseconds), so this advantage is marginal.
- LangGraph integration: no published official examples use Litestar. Integration follows the same async generator pattern as FastAPI, but developers must adapt FastAPI-centric LangGraph documentation manually.
- Ecosystem: approximately 5,900 GitHub stars vs FastAPI's 80,000+. Third-party plugins, authentication libraries, and tutorial content are materially smaller. This is the primary risk: novel integration questions are harder to answer from community resources.
- Dependency injection: pytest-inspired system with support for dependency override at any application level. More powerful than FastAPI's `Depends()` for complex testing and architectural layering.

*Python Candidate 3 — Django (v5.x / 6.0):*

Django is a full-stack framework with a built-in ORM, admin interface, authentication, and migrations. Django 5.x supports ASGI; Django 6.0 (December 2025) added a background tasks framework.

Tradeoffs for AI Council:
- Django's strengths (admin panel, built-in auth, ORM) are either irrelevant (admin), duplicated by better alternatives (SQLAlchemy + Alembic), or unnecessary (AI Council manages its own auth boundary as a local-first app in V1).
- Django REST Framework (DRF) is the standard API layer, adding another dependency.
- Django Channels is required for WebSocket or SSE support — another non-trivial dependency.
- The full-stack monolith model conflicts with NFR-8's separation requirement — Django's template engine is tightly coupled to the Python process, making it harder to cleanly separate the frontend build artefact.
- Django 6.0's background task framework is new and has no track record against APScheduler's decade of production use.
- Verdict: Django brings significant overhead for a project that needs only the API/streaming/scheduling slice. Excluded as the primary candidate; only appropriate if the team has existing deep Django expertise.

*Python Candidate 4 — Flask:*

Flask is WSGI-based (synchronous). While Flask 3.x supports async route handlers as an opt-in, it is not async-first. SSE streaming with Flask requires holding a thread per connection, limiting concurrency. Excluded on the async-first constraint.

*Node.js Candidate 1 — Fastify:*

Fastify is the fastest Node.js HTTP framework by benchmark and TypeScript-friendly. SSE is supported via the response object with manual event formatting; no official SSE plugin is in the core ecosystem but several community plugins exist. APScheduler's equivalent in Node.js is `node-cron` or `@nestjs/schedule`.

Tradeoffs:
- LangGraph TypeScript integration: viable (as confirmed by RQ-A3) but carries residual feature-lag risk vs the Python version.
- Background job scheduling: `node-cron` is the standard lightweight option. Equivalent feature set to APScheduler for the nightly Review Agent use case.
- AI SDK integration: Vercel AI SDK supports Fastify as an API server for streaming AI responses, with documented SSE patterns. This is an additional abstraction layer, but it can simplify streaming integration.
- Packaging (NFR-5): a Node.js backend adds a Node.js runtime requirement alongside (or instead of) a Python runtime. If the agentic layer is also TypeScript LangGraph, the entire stack is Node.js — one runtime, cleaner packaging. If Python LangGraph is used with a Node.js backend, a cross-language boundary must be bridged (e.g., the Node.js backend calls a Python subprocess or a local Python service), which is a significant architectural complication.
- Verdict: credible if the project adopts the TypeScript LangGraph stack throughout. Not credible as a mix with Python LangGraph (the cross-language bridging cost is too high for a V1).

*Node.js Candidate 2 — NestJS:*

NestJS provides an opinionated, module/decorator-based architecture on top of Fastify or Express. It is well-suited for large teams with strict code structure requirements.

Tradeoffs:
- The decorator-heavy DI system is complex and has been noted as making AI-assisted code generation less consistent.
- SSE and streaming are supported via `@Sse()` decorators and `Observable` streams.
- The overhead of NestJS's module system adds startup cost and boilerplate that is disproportionate to AI Council's V1 scope.
- Verdict: excluded for V1 scope. Would be credible for a large multi-team project.

*Node.js Candidate 3 — Hono:*

Hono is an ultra-lightweight (~14 KB) framework targeting edge computing environments (Cloudflare Workers, Deno). For a local-first app deployed on a standard server process, Hono's differentiator (edge compatibility) is irrelevant. It supports SSE and streaming but has a smaller ecosystem than Fastify or NestJS. Excluded as a primary candidate for AI Council's use case.

*Non-JavaScript/Python candidates (Go, Rust, Elixir):*

These are explicitly gated on a "credible agentic ecosystem story":
- Go: no LangGraph port exists. Agentic frameworks (e.g., Golang LLM frameworks like `langchaingo`) are immature compared to LangGraph Python/TypeScript. Excluded.
- Rust: no production-ready agentic framework comparable to LangGraph. Excluded.
- Elixir: no LangGraph port. Elixir's strength is concurrent real-time systems (Phoenix Channels, Phoenix LiveView), which is compelling for SSE/streaming, but the agentic ecosystem gap is disqualifying. Excluded.

*Summary of credible candidates:*

| Framework | Language | SSE support | APScheduler / equiv. | LangGraph integration | Ecosystem risk |
| --- | --- | --- | --- | --- | --- |
| FastAPI | Python | Via `sse-starlette` | `AsyncIOScheduler` (documented) | Official examples exist | Low |
| Litestar | Python | Native | `AsyncIOScheduler` (lifespan hooks) | No official examples | Medium (small community) |
| Fastify | Node.js | Manual / plugins | `node-cron` | TS LangGraph (feature-lag risk) | Low, but requires TS-only stack |

*Infrastructure as Configuration check:*

The backend framework is an application-layer choice, not infrastructure. The framework exposes the API; the database connection string, model endpoint, and scheduler timing are all configuration values read at startup. No violation.

*Cross-references:*
- RQ-A3 → RQ-G5: Python LangGraph biases toward a Python backend. A Node.js backend requires the TypeScript LangGraph stack and accepts the residual feature-lag risk.
- RQ-D1 → RQ-G5: APScheduler `AsyncIOScheduler` is explicitly designed for FastAPI and Litestar lifespan integration. Node.js equivalent is `node-cron`.
- RQ-G2 → RQ-G5: SSE transport is satisfied by all three credible candidates. FastAPI requires `sse-starlette`; Litestar has native SSE; Fastify uses response streaming with manual formatting or a community plugin.
- RQ-C4 → RQ-G5: The LangGraph + FastAPI + SSE pattern (graph.stream() → EventSourceResponse) is the most documented and lowest-risk integration path for streaming Persona responses.

---

## Group H: Deployment Architecture (FR-22.2 Flag)

### RQ-H1 — Local packaging for a non-administrator

**Status:** Complete

NFR-5 requires the system to be deployable with minimal setup steps — ideally a single command. What are the credible options — a docker-compose bundle, a native installer per OS, a Python/Node CLI launcher, or a single binary? What are the tradeoffs given a local database (RQ-E1), a local LLM as a possible configured model (FR-21.2), a frontend + backend split (NFR-8), and a background scheduler (RQ-D1)?

**Research findings:**

*Constraint framing:*

Three axes constrain the packaging choice:

1. **Database (RQ-E1):** If SQLite is chosen, the database file is created on first run — no server process, no network socket, no `pg_ctl` equivalent. This enables the simplest possible packaging. If PostgreSQL is chosen, a running PostgreSQL process is required before the application can start — this effectively mandates Docker Compose or a separate installer step, as there is no single-command PostgreSQL launcher for non-administrators.
2. **Background scheduler (RQ-D1):** APScheduler `AsyncIOScheduler` runs in-process inside the FastAPI/uvicorn event loop. No separate daemon process is required. This is the same process model as the backend itself, so the scheduler adds no new packaging complexity.
3. **Local LLM (FR-21.2):** If a local LLM such as Ollama is configured, Ollama is a separately-installed native process that binds to `localhost:11434`. Ollama has its own native installer (a `.pkg` on macOS, `.exe` on Windows, `curl | sh` on Linux) and does not require Docker. The application connects to Ollama's OpenAI-compatible REST endpoint — so Ollama is a dependency, not something AI Council needs to bundle. The packaging note is: the application's startup must detect whether Ollama is reachable and fail gracefully with a clear message if it is not.

*Option 1 — Docker Compose bundle:*

A `docker-compose.yml` file declares the backend service (including the Python runtime, dependencies, and static frontend build artefacts) and, if PostgreSQL is chosen, a `postgres` service. The user runs `docker compose up`.

Properties:
- Complete environment isolation — Python version, dependency versions, and database are all pinned inside containers.
- Reproducible across macOS, Windows, and Linux.
- PostgreSQL gating: if PostgreSQL is chosen, Docker Compose is the practical single-command path and there is no simpler alternative for non-administrator local deployment. Docker Compose becomes near-required in this case (consistent with RQ-E1's finding).
- Administrator requirement: Docker Desktop requires an initial installation that may need administrator access on Windows (user must be added to the `docker-users` group) and macOS (a `--user` installer flag bypasses the privilege helper, but must be set at install time). This is a one-time cost, not a per-run cost.
- SQLite on Docker: SQLite with Docker Compose requires a named volume or a bind-mount to persist the `.db` file across container restarts. A missing or misconfigured volume mount means data loss on `docker compose down`. This is a non-obvious footgun for non-technical users.
- Local LLM: if Ollama runs outside Docker, the backend container must call `host.docker.internal:11434` (macOS/Windows Docker Desktop) or the host bridge IP (Linux) — a portability complication. Running Ollama inside a Docker Compose service is possible but adds significant image size and complicates GPU passthrough.

*Option 2 — uv + Python virtual environment (CLI launcher):*

`uv` (Astral, written in Rust) is a single-binary installer for Python that also manages virtual environments and runs projects. With a `pyproject.toml` checked into the repository, the user installs `uv` once and then runs `uv run fastapi run app/main.py`. `uv run` automatically creates the virtual environment, installs all locked dependencies, and starts the server. Python itself is installed by `uv` if not already present — no separate Python installer step.

Properties:
- `uv` is a ~10 MB standalone binary installable via `curl -LsSf https://astral.sh/uv/install.sh | sh` (macOS/Linux) or a Windows `.exe` installer. No administrator privileges required.
- After `uv` is installed, `uv run` is a true single-command launch of the complete application.
- No Docker required. No container image build step.
- SQLite: the `.db` file sits on the host filesystem. Visible, accessible, and backed up with normal file tools. No volume mount complication.
- Background scheduler: APScheduler runs in the same Python process. No additional launcher needed.
- Static frontend: the FastAPI backend serves the compiled frontend via `StaticFiles` mount. The frontend build artefact is committed or produced by a pre-run build step. In V1 there is no separate frontend process.
- Local LLM: the application calls `localhost:11434` directly. No container networking complications.
- Upgrade path: `uv sync` re-installs any changed dependencies; `uv run` always verifies the environment is in sync before launching. This is a clean update mechanism.
- Limitation: `uv` itself must be installed first. For non-technical users, this is still a two-step install (install `uv`, then run the app) unless a wrapper script or a platform-specific installer bundles `uv` installation.

*Option 3 — Native OS installer (PyInstaller / Nuitka single binary):*

Tools like PyInstaller (bundles the Python interpreter, all dependencies, and the app into a single executable) or Nuitka (transpiles Python to C and compiles a native binary) can produce a single clickable file per platform.

Properties:
- No Python, no Docker, no `uv` required on the target machine. Pure end-user experience.
- PyInstaller bundles the Python interpreter and all site packages; the resulting binary is typically 50–200 MB. It does not cross-compile: a macOS binary must be built on macOS, a Windows binary on Windows.
- Nuitka compiles Python to C — requires a C toolchain (MSVC on Windows, Clang/GCC on macOS/Linux) during the build process. Produces smaller and faster binaries than PyInstaller but significantly longer build times.
- SQLAlchemy + aiosqlite + APScheduler + LangGraph create a large and complex dependency tree. PyInstaller's import analysis frequently misses dynamic imports in these libraries, requiring manual `--hidden-import` flags and extensive testing. Maintenance overhead per Python dependency upgrade is high.
- No path to serving a live frontend: the binary embeds static files, but the frontend build artefact must be baked in at build time — there is no hot-reload or post-install frontend update path.
- A separate binary is required per supported OS version, creating a multi-platform build/release pipeline.
- Verdict: appropriate for commercial end-user applications with a dedicated release engineering process. Disproportionate overhead for a developer-oriented or technical-user tool in V1.

*Option 4 — Tauri / Electron desktop wrapper:*

Tauri (Rust-based, uses the OS WebView) or Electron (bundles Chromium) can wrap the SPA frontend and launch a Python FastAPI "sidecar" as a subprocess managed by the desktop app lifecycle.

Properties:
- Provides a true desktop app experience: no browser tab, no exposed port, system tray, native notifications.
- The sidecar model uses PyInstaller to compile the Python backend into a binary that Tauri or Electron starts on launch and kills on close.
- Inherits all PyInstaller complexity described in Option 3.
- Adds a separate Rust (Tauri) or Node.js (Electron) toolchain requirement to the build pipeline.
- Electron: ~200 MB overhead for bundled Chromium. Tauri: ~5–10 MB overhead using native WebView, but WebView rendering differs across Windows (WebView2/Edge), macOS (WKWebView/Safari), and Linux (WebKitGTK).
- Cross-platform WebView inconsistencies in Tauri require CSS/JS testing on each platform.
- Not consistent with V1 scope. A browser-based SPA + local server is architecturally equivalent from the user's perspective, without the Rust/Electron build pipeline cost.
- Verdict: out of scope for V1. Credible if a standalone desktop app experience becomes a requirement in a later phase.

*Summary of credible options for V1:*

| Option | Admin required | Docker required | SQLite works cleanly | PostgreSQL works | Local LLM works | Complexity |
| --- | --- | --- | --- | --- | --- | --- |
| Docker Compose | One-time install | Yes | Volume mount needed | Native | `host.docker.internal` | Low for ops, high for SQLite data portability |
| uv + CLI launcher | No | No | Native (host FS) | Requires separate PostgreSQL | Native (localhost) | Low |
| PyInstaller single binary | No | No | Bundled (complex) | Requires separate PostgreSQL | Native (localhost) | High (build pipeline) |
| Tauri/Electron wrapper | No | No | Same as PyInstaller | Same as PyInstaller | Native | Very high |

*Infrastructure as Configuration check:*

None of the packaging options themselves violate Infrastructure as Configuration — the choice is about how the runtime environment is assembled, not how the application is configured. The violation risk is in the SQLite/PostgreSQL gate: if the application hardcodes `sqlite:///` anywhere outside a configuration-driven dialect layer, moving to Docker Compose with PostgreSQL requires code changes. This is an RQ-E1 constraint already noted there.

*Cross-references:*
- RQ-E1 → RQ-H1: SQLite permits uv + CLI launcher (no container required). PostgreSQL near-requires Docker Compose or a separate OS-level PostgreSQL install.
- RQ-D1 → RQ-H1: APScheduler in-process eliminates the scheduler as a separate packaging concern.
- RQ-G5 → RQ-H1: FastAPI + uvicorn is the single-command launch target (`uv run fastapi run` or `uvicorn app.main:app`).
- RQ-G1 → RQ-H1: Backend serves static files in V1 via `StaticFiles` mount — no separate frontend server process required, simplifying all packaging options.

### RQ-H2 — Cloud deployment path

**Status:** Complete

FR-22.2 requires that the system be architected so that future cloud deployment is possible without fundamental rework. What does "without fundamental rework" concretely mean for decisions that must be made now — the database (must it already be network-addressable?), the file system usage (must it already be abstracted?), session management (must it already be stateless?), model endpoint configuration (already required by FR-21.2)? What additional Infrastructure-as-Configuration abstractions are required to keep that path open?

**Research findings:**

*Defining "fundamental rework":*

For the purposes of this question, "fundamental rework" means changes to application logic, data models, or API contracts — as distinct from changes to deployment configuration, environment variables, or connection strings. The Twelve-Factor App methodology (Factor III: Config) is the standard framework for this distinction: everything that varies between environments (credentials, endpoint URLs, timeouts, feature flags) must live in environment variables or mounted config files, not in code.

*Axis 1 — Database:*

AI Council's architecture must answer a concrete question: does the database need to be network-addressable in V1?

SQLAlchemy uses a `DATABASE_URL` (or `SQLALCHEMY_DATABASE_URI`) string as the sole point of database identity. The format changes between drivers, but the application code is identical:

- SQLite (local): `sqlite+aiosqlite:///./data/council.db`
- PostgreSQL (cloud): `postgresql+asyncpg://user:pass@db-host:5432/council`

The migration from SQLite to PostgreSQL is therefore a configuration-string change, provided:

1. No SQLite-specific pragmas (e.g., `PRAGMA journal_mode`, `PRAGMA foreign_keys`) appear outside a dialect-aware initialisation module.
2. No raw SQL uses SQLite-specific syntax (e.g., `INSERT OR REPLACE`, `AUTOINCREMENT` vs `SERIAL`).
3. Alembic migrations do not embed dialect-specific DDL.

If these constraints are met in V1, the database transition to cloud deployment is: change `DATABASE_URL` → run `alembic upgrade head` → done. No code changes.

However: if the V1 data lives in a SQLite file, moving to cloud means a one-time data migration (export SQLite, import to PostgreSQL). This is an operational task, not a code task. It does not constitute "fundamental rework."

*Axis 2 — Filesystem usage:*

AI Council's current feature set does not include user-uploaded files or binary media storage. The primary filesystem-adjacent concerns are:

- The SQLite database file itself (handled by `DATABASE_URL`)
- Log files (handled by the logging configuration — cloud logging agents consume stdout/stderr)
- Potential future: user document uploads, Persona avatar images

If no user-uploaded binary content exists in V1, there is no filesystem abstraction required in V1. The constraint that must be honoured is: application code must not write to or read from the local filesystem for any artifact that would need to survive across process restarts in a cloud deployment. This means:

- Database writes go through SQLAlchemy exclusively.
- Any future binary upload feature must use a storage abstraction from day one. Python libraries that provide a local-disk-to-S3 abstraction with a configuration-driven backend include `pyfilesystem2` (filesystem abstraction layer), `fsspec` (includes local and S3/GCS/Azure backends), and `obstore` (Rust-backed, highest throughput for concurrent S3 operations). Using any of these, the backend constructor takes a URI (`file:///data` vs `s3://bucket/prefix`) — a config change, not a code change.
- The application must not generate reports, exports, or summaries as files on disk. In-memory generation with a streaming response (FastAPI `StreamingResponse`) is the cloud-compatible pattern.

V1 risk: if reports or markdown exports are written to a local temp directory and served as file downloads, this pattern will not work in a horizontally-scaled cloud environment where the requesting process may not be the process that created the file. Using a database-backed or in-memory approach for all transient output eliminates this risk.

*Axis 3 — Session management:*

AI Council V1 is a local single-user application. There is no authentication layer in V1. When multi-user support is added (the `user_id` constraint from RQ-E2 is already satisfied structurally), the standard cloud-compatible session pattern is:

- Stateless JWT tokens: the server issues a signed JWT; no server-side session store is required. Any instance in a horizontally-scaled deployment can validate any token using the shared signing key (which is itself configuration).
- If server-side session storage is used (e.g., `itsdangerous`-signed cookies backed by a session table), the session table must use the same database as the rest of the application — which is already network-addressable in cloud deployment. This avoids in-process session state but adds a database round-trip per request.

The architectural constraint that must be honoured in V1 (even though there is no auth): no in-process global state that represents per-user data. The `DEFAULT_USER_ID` sentinel from RQ-E2 satisfies this — it is a query parameter, not an in-process cache.

*Axis 4 — Model endpoint configuration (FR-21.2):*

This is already required by FR-21.2 and confirmed resolved in RQ-C2. The model provider, endpoint base URL, API key, and model ID are configuration values — no code change is needed to switch from a local Ollama endpoint to an OpenAI API endpoint or a cloud-hosted private model. The constraint is: these fields must be in the configuration schema (RQ-H4) and never hardcoded.

*Axis 5 — Background scheduler:*

APScheduler `AsyncIOScheduler` runs in-process. In a cloud deployment with multiple horizontal replicas, each replica would run its own scheduler, causing duplicate nightly Review Agent runs. The cloud-compatible remediation is one of:

1. Use a distributed job queue (Celery + Redis/SQS, or pg-based task queue from RQ-D1's findings) with a scheduler that writes tasks into the queue and workers that claim them — exactly one worker processes each task even with N replicas.
2. Use a leader-election mechanism (a database lock) so only one replica runs the scheduler at a time — this is the pattern described in RQ-D2 with advisory locks (PostgreSQL) or the status-table substitute (SQLite).

V1 does not require horizontal scaling and therefore does not have this problem. The architectural constraint that must be honoured in V1 to keep cloud migration cheap: do not embed logic into the APScheduler callback that relies on shared in-process state. The callback should be a function that issues a database read/write — compatible with the distributed model without rewriting.

*Summary — Infrastructure-as-Configuration abstractions required now:*

| Concern | V1 requirement | Cloud migration cost if respected | Cloud migration cost if violated |
| --- | --- | --- | --- |
| Database connection | `DATABASE_URL` in config | Config string change | Code audit + dialect-specific SQL fixes |
| Filesystem writes | None in V1 (no binary uploads) | Add storage abstraction at the feature's creation | Rewrite all file I/O to use abstraction layer |
| Session state | No in-process per-user state | Add stateless JWT with config-driven signing key | Rewrite session layer |
| Model endpoint | Config-driven (RQ-C2) | Already satisfied | N/A |
| Scheduler concurrency | Single replica in V1 | Replace APScheduler with queue consumer | Duplicate jobs until scheduler is replaced |
| Log output | Write to stdout/stderr (not log files) | Cloud log agents consume stdout | Rewrite logging sinks |

*Infrastructure as Configuration check:*

No violation if all axes above are respected. The violations to watch for:
- Hardcoded `sqlite:///` anywhere outside the configuration module (database URL must be configuration-sourced).
- Writing log files or output files to a fixed local path (must use `stdout`/`stderr` or a configuration-addressable path).
- Hardcoded model endpoint URL or API key (already flagged in RQ-C2).

*Cross-references:*
- RQ-E1 → RQ-H2: SQLite is acceptable in V1. The migration to PostgreSQL for cloud is a `DATABASE_URL` change provided dialect-specific SQL is isolated.
- RQ-E2 → RQ-H2: `user_id` structural presence from day one means adding real multi-user auth is a new layer over an existing schema column — not a schema migration.
- RQ-C2 → RQ-H2: Model abstraction fields (`provider`, `model`, `api_base`, `api_key`, `context_window`) are already configuration — this axis is satisfied if RQ-C2 findings are implemented.
- RQ-D1 → RQ-H2: APScheduler in-process is acceptable in V1; the cloud path requires a distributed queue consumer replacing it, but no application business logic changes are needed if the scheduler callback is a pure database-interacting function.
- RQ-G1 → RQ-H2: Backend serving static files in V1 via `StaticFiles` is fine; in cloud the frontend moves to a CDN with zero application code change (FastAPI `StaticFiles` mount is simply removed and replaced by a CDN base URL in the frontend build configuration).

### RQ-H3 — Secrets management and configuration loading strategy

**Status:** Complete

NFR-7 requires local data storage in V1 and NFR-3 requires all configuration to be settable in a config file. Where should secrets (cloud model API keys, future cloud database credentials) live in V1, and what is the migration path to a secrets manager in cloud deployment without changing application code?

In addition to evaluating plain environment variables, this question must evaluate the layered configuration file pattern — exemplified by `nconf` in Node.js ecosystems — where a hierarchy of JSON (or TOML/YAML) config files is merged at load time, with lower-priority files (checked into version control) providing defaults and higher-priority files or environment variables providing overrides for secrets and deployment-specific values. A file containing secrets can be gitignored and maintained separately per environment. What are the credible libraries implementing this pattern for the backend language in use (e.g. `dynaconf`, `pydantic-settings`, or `python-decouple` for Python; `nconf`, `convict`, or `dotenv`-layered approaches for Node.js)? How does each handle the migration from local file-based secrets to a cloud secrets manager (e.g. AWS Secrets Manager, HashiCorp Vault) without application code changes? Does the layered approach satisfy the Infrastructure as Configuration principle better or worse than a pure env-var approach?

**Research findings:**

*The layered configuration file pattern (nconf-style):*

The nconf pattern (Node.js) and its Python equivalents work as follows: a stack of configuration sources is declared at application bootstrap, ordered by priority. Each source in the stack is checked in turn — the first source that contains a value wins. Sources typically include (highest to lowest priority):

1. Environment variables (set by the shell, CI/CD, or a container orchestrator)
2. An environment-specific override file (e.g., `settings.local.toml` or `.secrets.toml`, gitignored)
3. An environment-named section file (e.g., `settings.production.toml`, checked in without secrets)
4. A base defaults file (`settings.toml`, checked into version control, no secrets)

The gitignored secrets file contains only the values that differ per developer or deployment (API keys, database passwords). The checked-in defaults file contains safe non-secret defaults. When the application is bootstrapped in a new environment, only the secrets file needs to be created — everything else is in version control.

This pattern satisfies Infrastructure as Configuration: the application reads a uniform API regardless of which source provided a given value. Switching from a local secrets file to a cloud secrets manager means adding a new source to the top of the stack — no change to how the application reads values.

*Python Candidate 1 — pydantic-settings:*

`pydantic-settings` is the FastAPI-native settings library, built on Pydantic v2. FastAPI's own documentation recommends it as the standard settings pattern. Settings are declared as a `BaseSettings` subclass with typed fields.

Default source priority (highest to lowest):
1. CLI arguments (if enabled)
2. Environment variables
3. `.env` file(s) (supports multiple via `env_file=["base.env", "local.env"]`)
4. `secrets_dir` — a directory where each file is named after a setting key and contains that setting's value (one file per secret)
5. Field default values

The `secrets_dir` feature is directly designed for Docker and Kubernetes secrets, which mount secrets as individual files in a directory. No application code change is needed when moving from a `.env` secrets file to mounted Kubernetes secrets — change `secrets_dir` from `None` to `/run/secrets` in the configuration.

Cloud secrets manager integration is via custom `SettingsSource` classes:
- `pydantic-settings-aws` adds `AWSSecretsManagerSettingsSource` as a source in `settings_customise_sources()`. The source is plugged in at a defined priority position — replacing the local secrets file source when deploying to AWS.
- `pydantic2-settings-vault` and `pydantic-vault` provide equivalent `SettingsSource` implementations for HashiCorp Vault.

Migration path — local file to cloud secrets manager:
1. V1: `settings_customise_sources` returns `(env_settings, dotenv_settings, secrets_dir_settings, init_settings)` — reads from `.env` or a secrets directory.
2. Cloud deployment: add `AWSSecretsManagerSettingsSource` at position 1 (before `env_settings`) — or replace `secrets_dir_settings`. Application code is unchanged; only the `Settings` class's `settings_customise_sources` method changes, which is configuration-layer code, not business logic.

Limitation: pydantic-settings does not support TOML config files natively as a first-class source. The Pydantic team has added TOML provider support in recent versions via `pydantic-settings-toml`, but this is a third-party extension. For a project wanting a checked-in TOML defaults file alongside an env/secrets-file override, pydantic-settings alone requires a workaround (pre-load the TOML file and pass values as defaults, or use a hybrid with Dynaconf for the TOML layer).

*Python Candidate 2 — Dynaconf:*

`dynaconf` is a layered configuration library with native multi-format file support (TOML, YAML, JSON, INI, Python), a dedicated `.secrets.toml` file convention, environment sections (`[default]`, `[development]`, `[production]`), and first-party integration with HashiCorp Vault and Redis.

Loading hierarchy (highest to lowest priority, confirmed):
1. Environment variables prefixed with `DYNACONF_` (or a custom prefix)
2. `.secrets.local.toml` / `.secrets.{env}.toml` (gitignored, per-environment)
3. `.secrets.toml` (gitignored)
4. `settings.local.toml` (gitignored, developer-local overrides)
5. `settings.{ENV}.toml` (checked in, environment-specific non-secret config)
6. `settings.toml` (checked in, base defaults)

Dynaconf automatically appends `.secrets.*` to `.gitignore` when the `dynaconf init` command is run.

Cloud secrets manager integration:
- **HashiCorp Vault**: set `VAULT_ENABLED_FOR_DYNACONF=true`, `VAULT_URL_FOR_DYNACONF=https://vault.example.com`, and the appropriate auth method env vars. Dynaconf reads from Vault at startup as an additional loader — no application code change, only environment variable configuration.
- **AWS Secrets Manager**: not a built-in loader in the current stable release; requires a custom `dynaconf` loader plugin. This is a gap relative to pydantic-settings-aws.
- **Redis**: first-party loader for distributed settings synchronisation across multiple processes.

Dynaconf can be combined with pydantic: Dynaconf handles the layered file loading and environment switching; Pydantic validates and types the values. This hybrid pattern ("Dynaconf for loading, Pydantic for typing") is documented and in active use in FastAPI projects.

*Python Candidate 3 — python-decouple:*

`python-decouple` is a minimal library that reads settings from `.env` files and `settings.ini` files, falling back to environment variables. Priority: `.env` > `settings.ini` > environment variables > defaults (note: environment variables override files in pydantic-settings but not by default in python-decouple — `.env` takes highest priority, which is counterintuitive for production).

Properties:
- Very simple and small (no external dependencies).
- No multi-environment sections, no secrets file convention, no cloud secrets manager integration.
- The priority order (`.env` over environment variables) means accidentally deploying with a developer's `.env` file in a container will silently override production environment variables — an Infrastructure as Configuration violation risk.
- No native TOML support.
- Verdict: appropriate for simple scripts or prototypes. Does not satisfy the layered hierarchy required for the nconf-style pattern. Not recommended for AI Council.

*Node.js candidates (for reference, relevant if TypeScript LangGraph stack is chosen):*

`nconf`: hierarchical config with providers for command-line arguments, environment variables, JSON/YAML files, and in-memory stores. Providers are added in priority order: `nconf.argv().env().file({ file: '.secrets.json' }).file({ file: 'config.json' })`. The first provider that has a key wins. The gitignored `.secrets.json` file is the standard local secrets pattern. No native cloud secrets manager integration — requires a custom provider.

`convict`: extends nconf with a schema definition layer for validation and type-checking, making it the closest Node.js equivalent to pydantic-settings. Supports JSON and YAML config files, environment variable mapping, and a validation step at startup that fails loudly on invalid or missing required config.

`dotenv`-layered approaches: chaining multiple `dotenv.config({ path: '.env.local', override: true })` calls implements the nconf pattern manually without a dedicated library.

*Comparison matrix:*

| Library | Language | TOML config | Secrets file convention | Env var priority | Vault integration | AWS Secrets Mgr | Schema validation |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pydantic-settings | Python | Via plugin | `secrets_dir` | Higher than `.env` | Via pydantic-vault | Via pydantic-settings-aws | Native (Pydantic types) |
| dynaconf | Python | Native | `.secrets.toml` auto-gitignored | Higher than files | First-party | Custom loader | Via Pydantic hybrid |
| python-decouple | Python | No | `.env` only | Lower than `.env` (risk) | No | No | Manual |
| nconf | Node.js | Via plugin | Custom JSON file | Provider-ordered | Custom | Custom | No |
| convict | Node.js | Via plugin | Schema-declared | Configurable | Custom | Custom | Native |

*Does the layered approach satisfy Infrastructure as Configuration better than pure env-var?*

Yes, for the following reason: a pure env-var approach (Twelve-Factor strict interpretation) requires all configuration to be set in the environment before process start. For a local developer, this means either manually `export`-ing dozens of variables, or using a `.env` file loaded by `dotenv`-style tooling — which is effectively the lowest tier of the layered file approach anyway.

The layered file approach extends this by making defaults visible and version-controlled. A developer checking out the repository sees `settings.toml` with all required configuration keys and their documentation-friendly defaults. They create only the minimal `.secrets.toml` with real secret values. This is strictly more auditable than environment variables, which are invisible to reviewers and easily overlooked.

The cloud migration path is superior with the layered approach: adding a cloud secrets manager source to the top of the stack replaces file-based secrets without modifying business logic. With a pure env-var approach, the switch from `.env` file to a secrets manager requires changing the process launcher (e.g., a Docker `entrypoint.sh` that runs `aws secretsmanager get-secret-value` and injects values) — which is deployment-layer code but still a change to environment setup scripts.

*Infrastructure as Configuration check:*

The layered approach satisfies Infrastructure as Configuration provided:
- No secret values appear in checked-in configuration files.
- The secrets file is gitignored by convention (dynaconf enforces this automatically; pydantic-settings requires manual `.gitignore` discipline for the `.env` file).
- The application reads configuration uniformly through the settings object — no direct `os.environ[]` calls scattered through business logic.

A violation would be: loading `dotenv` in application business-logic modules rather than exclusively at the settings bootstrap layer. This creates hidden dependency on the environment at arbitrary points in the code.

*Cross-references:*
- RQ-C2 → RQ-H3: The model provider configuration fields (`provider`, `model`, `api_base`, `api_key`, `context_window`) are the primary secrets-bearing fields in V1. `api_key` belongs in the gitignored secrets file or `secrets_dir`; the other fields are non-secret and can live in the base `settings.toml`.
- RQ-H4 → RQ-H3: The typed schema and bootstrap loading strategy (RQ-H4) must consume whatever loading layer is chosen here. pydantic-settings and the Dynaconf+Pydantic hybrid both satisfy this naturally.
- RQ-H2 → RQ-H3: The cloud migration path (env vars → secrets manager) requires a configuration loading strategy that supports custom sources at defined priority positions — pydantic-settings and dynaconf both satisfy this; python-decouple does not.

### RQ-H4 — Configuration schema and loading

**Status:** Complete

NFR-3 requires that all operator-configurable values (Context Panel character limit, Episodic Memory window size N, model endpoint, Review Agent schedule, and others implied in Open Questions OQ-01 through OQ-07 of the requirements) be settable in a configuration file without code changes. What is the standard pattern for a typed, validated configuration schema that loads once at application bootstrap, and how does it interact with per-provider sections for the model abstraction (RQ-C2)?

**Research findings:**

*The standard bootstrap pattern:*

The FastAPI-documented and ecosystem-standard pattern for typed, validated configuration that loads once is the `pydantic-settings` `BaseSettings` class combined with an `@functools.lru_cache`-decorated getter function injected as a FastAPI dependency:

```python
# config.py
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field
from functools import lru_cache

class Settings(BaseSettings):
    app_name: str = "AI Council"
    context_panel_char_limit: int = Field(default=2000, ge=100, le=10000)
    episodic_memory_window: int = Field(default=10, ge=1, le=100)
    review_agent_cron: str = "0 2 * * *"  # 2am nightly
    # ... other fields
    model_config = SettingsConfigDict(
        env_file=".env",
        env_nested_delimiter="__",
        extra="forbid",  # fail loudly on unknown config keys
    )

@lru_cache
def get_settings() -> Settings:
    return Settings()
```

```python
# main.py
from fastapi import Depends, FastAPI
from .config import Settings, get_settings
from typing import Annotated

app = FastAPI()

@app.get("/")
async def root(settings: Annotated[Settings, Depends(get_settings)]):
    ...
```

Key properties of this pattern:
- `@lru_cache` ensures `Settings()` is instantiated exactly once across all requests — no repeated `.env` file reads.
- `extra="forbid"` causes the application to fail at startup if an unrecognised configuration key is present, catching typos in the config file immediately.
- All fields are type-annotated and validated by Pydantic at instantiation. A misconfigured value (e.g., a string where an int is expected, or a value outside a `ge`/`le` range) raises a `ValidationError` at bootstrap — the application fails to start rather than failing at runtime.
- The `get_settings` function can be overridden in tests via `app.dependency_overrides[get_settings] = lambda: Settings(...)` without touching the singleton.

*Fail-fast validation at bootstrap:*

The Pydantic validation layer catches configuration errors at process start, not at the first request that exercises a feature. This is the correct behaviour for NFR-3: an operator who misconfigures the application learns immediately, not after deploying for a week and triggering a nightly job that fails silently.

For fields without defaults (required fields), omitting them in the environment or config file causes a `ValidationError` that identifies the missing field by name. This is directly superior to reading `os.environ.get("KEY")` and handling `None` in business logic.

*Per-provider configuration section (RQ-C2 integration):*

The model abstraction (RQ-C2) requires fields: `provider`, `model`, `api_base`, `api_key`, and `context_window`. These map naturally to a nested `BaseModel` inside the `Settings` class:

```python
from pydantic import BaseModel, SecretStr

class ModelConfig(BaseModel):
    provider: str = "ollama"  # "ollama" | "openai" | "anthropic" | "custom"
    model: str = "llama3.2"
    api_base: str = "http://localhost:11434/v1"
    api_key: SecretStr = SecretStr("")  # empty = no key (Ollama local)
    context_window: int = 8192

class Settings(BaseSettings):
    # ... other fields
    llm: ModelConfig = ModelConfig()
    model_config = SettingsConfigDict(
        env_nested_delimiter="__"
    )
```

With `env_nested_delimiter="__"`, the following environment variable names control the nested model:
- `LLM__PROVIDER=openai`
- `LLM__MODEL=gpt-4o`
- `LLM__API_BASE=https://api.openai.com/v1`
- `LLM__API_KEY=sk-...`
- `LLM__CONTEXT_WINDOW=128000`

In a TOML config file (via `TomlConfigSettingsSource` or a Dynaconf layer), the same structure is expressed as:

```toml
[llm]
provider = "openai"
model = "gpt-4o"
api_base = "https://api.openai.com/v1"
api_key = ""  # secrets file or env var
context_window = 128000
```

The `SecretStr` type for `api_key` prevents the key from appearing in logs, debug output, or serialised settings dumps (it renders as `**********`).

*Review Agent schedule — cron string validation:*

`review_agent_cron` is stored as a string (`"0 2 * * *"`) and validated at APScheduler startup when the `CronTrigger.from_crontab()` call is made. There is no Pydantic-native cron string validator in the standard library.

Two approaches:
1. **Defer validation to APScheduler**: accept `str` in the settings schema; APScheduler raises a `ValueError` with a clear message if the string is not a valid cron expression. This is fail-fast at bootstrap provided the scheduler is started in the FastAPI lifespan context manager (which runs before the server accepts requests).
2. **Custom Pydantic validator**: add a `@field_validator("review_agent_cron")` that calls `CronTrigger.from_crontab(v)` inside a try/except and re-raises as a `ValueError`. This moves the validation error into the Pydantic layer and produces a `ValidationError` at settings instantiation — slightly earlier and more consistent with all other fields.

Option 2 is superior for operator experience but adds an APScheduler import to the config module. Since APScheduler is already a required dependency, this is not a meaningful additional coupling.

*Configurable values inventory (from NFR-3, OQ-01 through OQ-07, and product overview):*

| Setting | Type | Default source | Secret? |
| --- | --- | --- | --- |
| `llm.provider` | `str` | Base defaults file | No |
| `llm.model` | `str` | Base defaults file | No |
| `llm.api_base` | `str` | Base defaults file | No |
| `llm.api_key` | `SecretStr` | Secrets file / env var | Yes |
| `llm.context_window` | `int` | Base defaults file | No |
| `context_panel_char_limit` | `int` | Base defaults file | No |
| `episodic_memory_window` | `int` (N) | Base defaults file | No |
| `working_memory_token_budget` | `int` | Base defaults file | No |
| `review_agent_cron` | `str` | Base defaults file | No |
| `database_url` | `str` | Env var / secrets file | Yes (if PostgreSQL) |
| `app_host` | `str` | Base defaults file | No |
| `app_port` | `int` | Base defaults file | No |

*TOML config file as the base defaults file:*

pydantic-settings added `TomlConfigSettingsSource` support in recent versions. The source can be added to `settings_customise_sources` at the lowest priority tier (below env vars and the secrets file), providing a checked-in `settings.toml` with human-readable annotated defaults. This satisfies NFR-3's "settable in a config file" requirement: a user reads `settings.toml`, sees all configurable keys with defaults, edits the values they want to change, and the application picks them up at next start.

The full source priority stack with TOML:
1. Environment variables (highest)
2. Secrets directory (Docker/Kubernetes secret mounts)
3. `.env` file (developer/operator local secrets)
4. `settings.local.toml` (developer-local non-secret overrides, gitignored)
5. `settings.toml` (base defaults, checked in) (lowest)

*Infrastructure as Configuration check:*

No violation, provided:
- All configurable values are declared in the `Settings` class — no `os.environ[]` calls in business logic.
- `extra="forbid"` is set, preventing undeclared configuration from silently accumulating.
- The `SecretStr` type is used for all credential fields to prevent accidental logging.

A violation would be: a background scheduler job that reads `os.environ.get("REVIEW_AGENT_CRON")` directly rather than consuming the validated settings object through the application's configuration layer.

*Cross-references:*
- RQ-C2 → RQ-H4: The `ModelConfig` nested model is the direct implementation of the model abstraction fields required in RQ-C2. Provider, model, api_base, api_key, and context_window are all first-class typed fields.
- RQ-H3 → RQ-H4: The loading strategy (pydantic-settings sources stack, dynaconf layering, or a hybrid) determines how the `Settings` class receives its values. The schema defined here (RQ-H4) is the consumer; RQ-H3 is the supplier. The two must be decided together.
- RQ-D1 → RQ-H4: The Review Agent cron schedule is a configurable field. The `review_agent_cron` string must be validated at bootstrap, either via a Pydantic `field_validator` or by APScheduler startup in the lifespan context.
- RQ-H2 → RQ-H4: The `database_url` field in the schema is the implementation of the Infrastructure-as-Configuration requirement for the database connection (RQ-H2, Axis 1). Its presence as a typed field in the settings schema makes it impossible to accidentally hardcode.

---

## Group I: Cross-Cutting Questions Identified During Reading

### RQ-I1 — Orchestrator monitoring loop

**Status:** Complete

The Orchestrator (FR-8.1) "continuously monitors" the topic and direction of active Conversations and surfaces suggestions without being a participant. Is this a true continuous background loop, or is it an event-driven evaluator that runs after each user or Persona message? Both models are defensible; the choice affects the implementation model (a subscriber, a post-message hook, or a periodic sweep). Research should enumerate both options and their implementation costs.

**Research findings:**

*What "continuously monitors" means in practice:*

FR-8.1 uses the word "continuously" but the product requirement is actually about liveness — the Orchestrator should notice topical changes and surface suggestions in time for them to be useful. This does not require sampling at every clock tick; it requires sampling frequently enough that a suggestion arrives before the conversation has moved on. These are distinct requirements with very different implementation costs.

**Option A — True continuous background loop (periodic polling)**

A background asyncio task wakes at a fixed interval (e.g. every N seconds) and, if a Conversation is active (state is `busy` or `idle` with recent messages), fetches the last K messages from state and calls the configured LLM with the Orchestrator monitor prompt. If the result contains a suggestion, it is surfaced to the frontend via an SSE event.

- Pros: easy to implement; the monitoring rate is a single configurable number; no coupling to the message-dispatch path.
- Cons: polls even when nothing has changed (wasteful); creates a steady-state model call load even for low-activity conversations; the interval is a blunt instrument — too short and the cost is high, too long and the suggestion arrives after the relevant window has passed. With LangGraph, this loop would run outside the graph, requiring the monitor to read graph checkpoint state directly rather than participating in the state graph.
- Infrastructure as Configuration: No violation if the poll interval is read from config. A violation would occur if the Orchestrator is hardwired to a specific provider or if the interval is hardcoded.

**Option B — Post-message hook (event-driven, triggered after each complete Persona or user message)**

The Orchestrator evaluator runs as a post-commit hook after each message is written to the conversation. In a LangGraph context, this is a node that is always inserted after the Persona response node in the graph's execution path; it inspects the updated state and decides whether to surface a suggestion or stay silent. In a non-LangGraph context, it is a function called from the message-dispatch layer after the response is committed.

- Pros: directly coupled to message rate (fires once per message, not on a timer); no idle polling; the Orchestrator always sees the most recent state; easy to test (deterministic — one message = one evaluation); the LangGraph node model makes this natural — the Orchestrator node is simply always in the graph, after each Persona turn, and returns early if no suggestion is warranted.
- Cons: adds latency to every turn cycle — the Orchestrator LLM call must complete before the graph can transition to the next state. This can be mitigated by running the Orchestrator node concurrently with the Persona node (LangGraph supports concurrent node execution via parallel branches) or by making it an async fire-and-forget task that does not block the next turn. If fire-and-forget, the suggestion arrives asynchronously and may arrive after the next Persona turn has already started — acceptable for suggestions, not acceptable for routing decisions.
- Infrastructure as Configuration: No violation.

**Option C — Periodic post-message with skip (event-driven with frequency gate)**

A hybrid: the Orchestrator evaluator runs after each message, but a state counter gates how often the LLM call actually fires. For example, the Orchestrator prompt is invoked only every M messages (configurable) or only when the message count crosses a threshold since the last evaluation. This reduces cost while preserving the event-driven trigger.

- Pros: cost-controlled; still message-driven (not timer-driven); the gate value M is a configurable tuning parameter.
- Cons: slightly more complex than pure post-message; the first evaluation does not occur until M messages have been exchanged.

**Recommended pattern for AI Council:**

Option B (post-message hook / LangGraph node) is the natural fit. It aligns with LangGraph's node execution model, requires no timer infrastructure, and ensures the Orchestrator always evaluates the latest state. The LLM call for the monitor prompt should run as a parallel branch concurrent with the Persona response node, so it does not add latency to the turn cycle. If LangGraph is not used, a post-message callback in the application's message-dispatch layer achieves the same effect. Option C's frequency gate can be applied on top of either as a cost-reduction measure, controlled by a configurable integer in the settings schema (RQ-H4).

The "continuously monitors" language in FR-8.1 is consistent with Option B — the Orchestrator evaluates continuously in the sense that it evaluates after every message event without needing explicit user action, not in the sense of a polling loop.

*Infrastructure as Configuration check:* No violation for Options B and C. Option A has no structural violation but introduces polling infrastructure complexity without benefit. The Orchestrator's model call uses the same `BaseChatModel` interface as all other model calls in the system (RQ-A1, RQ-A4), satisfying the LLM abstraction requirement.

*Cross-references:*
- RQ-A6/F4: The Orchestrator node runs in the same LangGraph graph as the Persona turn nodes. Whether it is a separate node or merged with turn routing is the Position A/B/Hybrid question from RQ-F4.
- RQ-G3: The `busy` → `idle` SSE events on the Conversation stream give the Orchestrator evaluator a signal about when a turn has completed — useful if a non-LangGraph implementation is used.
- RQ-I11: Per-Conversation idle state and the Orchestrator's firing gate are related — the Orchestrator should not fire during an `idle` state where no new content has arrived since the last evaluation.

### RQ-I2 — Conversation auto-naming trigger

**Status:** Complete

FR-3.5 auto-names a Conversation on first summarisation — whichever comes first: automatic context compression (Group B) or the first user-requested targeted summary. This couples naming logic to the context-window management layer. Is there a cleaner factoring where auto-naming is an observer of a named event rather than a branch inside the compression path?

**Research findings:**

*What the requirement actually says:*

FR-3.5 states a Conversation is auto-named on "first summarisation." The two summarisation paths that can be first are: (a) automatic context compression triggered by the rolling summary mechanism (Group B), and (b) a user-initiated targeted summary (FR-3.3/FR-3.4). In both cases a summary text already exists after the operation completes — the auto-naming step simply derives a short title from that summary.

**Problem with the coupled approach:**

If the naming logic lives as a branch inside each summarisation path (`if not conversation.name: generate_name(summary_text)`), then:
1. Two separate code locations must be kept in sync — if a third summarisation path is added later, the auto-naming branch must be added there too.
2. The naming logic is tangled with the summarisation logic, making both harder to test in isolation.
3. The condition `if not conversation.name` must be checked in application code at both call sites, which is an implicit invariant that can be violated if either call site is refactored.

**Option A — Inline branch at each summarisation call site**

The simplest implementation: after each summarisation function completes, check whether `conversation.name` is null and, if so, call a `generate_title(summary_text)` LLM helper and write the result. The check lives in the application service layer.

- Pros: minimal abstraction overhead; straightforward to read.
- Cons: naming logic is duplicated across two call sites; adding a new summarisation path requires remembering to add the naming branch; the invariant is correctness-by-care.

**Option B — Named domain event + observer**

The summarisation service emits a `SummaryCreated` domain event (or calls a named hook) whenever a new summary is produced. An `AutoNamingObserver` subscribes to this event and performs the name-generation step if the conversation has no name yet. The observer checks the invariant once, in one place; any new summarisation path only needs to emit the same event.

In a Python/FastAPI stack without a full event bus (as established in RQ-D1, which eliminated external job queues), this can be implemented as a simple synchronous hook pattern:
- The summarisation function returns a `SummarisationResult` dataclass.
- After calling the summarisation function, the caller passes the result to a `ConversationNameService.on_summarisation_complete(conversation_id, result)` method.
- That method is the single location that decides whether to trigger naming.

This is not a full event bus but still decouples the two concerns. Any new summarisation path calls the same `on_summarisation_complete` hook.

- Pros: single location for the invariant; testable in isolation; naming logic is not tangled with compression or summary logic; easy to extend.
- Cons: requires a small design step (defining the hook interface); slightly more indirection.

**Option C — Database trigger or ORM hook**

A SQLAlchemy `@event.listens_for(Conversation, 'after_update')` hook fires whenever a `Conversation` row is updated. If the update set `last_summary_text` and `name` is still null, the hook triggers naming.

- Pros: zero changes needed in the summarisation service.
- Cons: ORM hooks run synchronously inside the database session, making LLM calls inside them awkward (they would need to be deferred to an asyncio task, which introduces ordering complexity). Hooks on generic ORM events are hard to test and can fire unexpectedly during migrations or bulk operations. Not recommended for LLM-dependent side effects.

**Option D — Naming on the Summary model, not on the Conversation**

A different factoring: `Summary` is a first-class model (if summaries are persisted — a choice established in Group B). Whenever the first `Summary` row for a Conversation is created, a post-insert hook names the Conversation. This makes the invariant "the Conversation name is derived from its first Summary," which is stated explicitly.

- Relevance: Only applicable if summaries are persisted as rows. If summaries are ephemeral (stored only in the Conversation's context window state), this option is not available.

**Recommended pattern:**

Option B (named hook / `on_summarisation_complete` method). It provides the factoring cleanly without requiring an event bus, remains testable, and ensures any new summarisation path is handled by adding one function call rather than remembering to add a conditional branch. The hook also serves as the single place to gate the LLM call for title generation behind the `name is None` check, making the invariant explicit in code structure rather than implicit in two separate `if` branches.

The title-generation LLM call can reuse the same `BaseChatModel` instance used for summarisation, satisfying Infrastructure as Configuration without adding a new model connection.

*Infrastructure as Configuration check:* No violation. The naming logic uses the same configured model instance as summarisation.

*Cross-references:*
- RQ-B3/B4: Group B established the rolling summary mechanism. The `on_summarisation_complete` hook fires after that mechanism produces a summary, as well as after a user-requested targeted summary.
- RQ-I10: Auto-naming is not directly related to system message storage, but the `SummaryCreated` event (if used as a formal domain event) could also trigger other observers such as a system-message insertion into the Conversation thread announcing the naming — a choice for the developer.

### RQ-I3 — Single-writer invariants for Context Panel

**Status:** Complete

FR-7.3 requires that the Context Panel never be written by the system — only by the user. FR-7.6 creates a one-click add-from-summary offer that still requires user confirmation. What is the right way to enforce "user-authored only" at the data layer and at the API layer to prevent accidental background writes during future feature work?

**Research findings:**

*What needs protecting:*

The Context Panel is a user-owned text field on a Conversation. It is included verbatim in every LLM context for that Conversation (FR-7.1/7.2). The requirement is that no background process, no agent, and no automated step can write to it without explicit user action. This is a correctness requirement: if the system could write to the Context Panel, the user's carefully maintained context notes could be overwritten by automated logic, which is a significant trust violation.

**Layer 1 — Data model: no system ownership field**

The data model for the `conversations` table stores `context_panel_text TEXT`. There is no separate `context_panel_updated_by` column or ownership marker needed if enforcement happens at the API layer. The data model itself is neutral — it stores whatever is PUT there. Enforcement must happen before the write, not after.

**Layer 2 — API layer: dedicated endpoint with no system path**

The correct enforcement point is the API. The Context Panel should have exactly one write endpoint: `PUT /conversations/{id}/context-panel` (or equivalent). This endpoint is:
- **Only accessible via user-authenticated requests.** It is not called by any background service, scheduled job, or agent in the codebase. The Review Agent, the Orchestrator, the compression service, and the naming service have no import of this endpoint's handler.
- **Not part of the general conversation update endpoint.** If the Context Panel field is part of a general `PATCH /conversations/{id}` body, any code that constructs a `ConversationUpdate` object could accidentally include a `context_panel_text` field. A dedicated endpoint makes the write surface explicit and narrow.

The "add from summary" flow (FR-7.6) runs as follows: the system sends a read-only suggestion to the frontend (via SSE or as a response to a user action). The user sees the suggestion and explicitly clicks to accept it. The frontend then calls `PUT /conversations/{id}/context-panel` with the user-confirmed text. **The system never calls this endpoint directly** — it only supplies the candidate text for user review.

**Layer 3 — Application layer: no `context_panel_text` in non-user service calls**

A service-level guard can be added: the `ConversationService` class (or equivalent) exposes `update_context_panel(conversation_id, text, actor: Literal["user"])` where `actor` is required to be `"user"`. This is a code-level contract, not a database-level constraint, but it makes the intent explicit. Any future developer who attempts to write `update_context_panel(..., actor="system")` will see an immediate type error or assertion failure. This is a lightweight defence-in-depth measure.

**Layer 4 — Code review convention documented in principles**

The `development-principles.md` file can state explicitly: "The Context Panel is user-authored. No code path other than the `PUT /conversations/{id}/context-panel` handler may write `context_panel_text`." This is a documentation-level constraint, but when combined with the dedicated endpoint and the service-layer `actor` parameter, it forms a complete layered defence.

**What NOT to do:**

- A database CHECK constraint cannot enforce who performs the write — the database only sees the SQL, not the caller identity.
- A database trigger could theoretically block writes from non-user sessions, but this would require session-level metadata in the database that the application layer manages, which is over-engineered for this requirement.
- Making `context_panel_text` a separate table with a different ORM model (to prevent accidental access from the `Conversation` ORM object) is a valid structural option but adds complexity. The dedicated API endpoint + service-layer actor parameter is sufficient.

**Summary:**

Enforcement happens at two layers: (1) a dedicated, narrow API endpoint that is the only write path for the Context Panel, with no invocation path from background services, and (2) a service-layer `actor` parameter that documents and enforces the user-only write constraint in application code. The FR-7.6 "add from summary" flow routes through these same two layers, with the system providing a suggestion text to the frontend and the user explicitly confirming the write through the dedicated endpoint.

*Infrastructure as Configuration check:* No violation. This is pure application-layer access control.

*Cross-references:*
- RQ-E4: The `conversation_personas` snapshot table pattern (system prompts read from snapshot, not live record) is a similar "deliberate separation of concerns" pattern. The Context Panel's dedicated-endpoint approach is analogous — one narrow write surface, no accidental path.
- RQ-I10: System messages inserted into the Conversation thread (FR-5.7) are distinct from the Context Panel — they enter through a different path (the message store) and do not touch `context_panel_text`.

### RQ-I4 — Interactive Review Agent consultation context boundary

**Status:** Complete

FR-16.2 creates a second, narrower access boundary for the Review Agent: during interactive consultation it must have only the Persona's current System Prompt and existing findings — explicitly not Conversation histories. The automated nightly run (Section 7.2) has the opposite access — full concluded Conversation histories. These are two distinct access rules for the same component. How should this be expressed architecturally — two separately-scoped interfaces, one interface with a context mode parameter, or two separate services that share model plumbing? The chosen pattern must make it structurally impossible for the interactive mode to read Conversation histories by accident.

**Research findings:**

*The two access rules side-by-side:*

| Mode | Inputs | Access to Conversation histories |
| --- | --- | --- |
| Nightly automated run | Concluded Conversations for a Persona, existing findings | Yes — this is the primary data source |
| Interactive consultation (FR-16.2) | Persona System Prompt + existing findings only | Explicitly no — must not read Conversation histories |

The key safety property is that the interactive mode must not accidentally gain access to Conversation histories even if the implementing developer calls the wrong service method or passes the wrong context object.

**Option A — Single service class with a `mode` parameter**

`ReviewAgentService.consult(persona_id, mode: Literal["nightly", "interactive"])`. Inside the method, a branch either loads Conversation histories (nightly) or does not (interactive). The safety property relies on the caller passing the correct mode.

- Problem: the safety is correctness-by-care. Any call site can pass `mode="nightly"` in an interactive context and gain access to Conversation histories. The parameter is a flag that changes behaviour but not data access rights. This is the weakest option.

**Option B — Two separate service classes sharing model plumbing**

`NightlyReviewAgentService` and `InteractiveReviewAgentService` are two distinct classes. Both use the same underlying `BaseChatModel` instance (injected via dependency injection). `NightlyReviewAgentService` has a dependency on the `ConversationRepository`; `InteractiveReviewAgentService` does not — it has no import of `ConversationRepository` at all.

- Safety property: `InteractiveReviewAgentService` structurally cannot query Conversation histories because it has no reference to the repository. A developer cannot accidentally call a Conversation-loading method that does not exist on the class. This is correctness-by-construction for the access boundary.
- Shared model plumbing: both services receive the same `BaseChatModel` instance (or the same factory function) via dependency injection. When the configured model changes in the settings schema (RQ-H4), both services pick up the change through the same injection path.
- Cons: two classes to maintain; the shared prompt construction logic (which likely overlaps between the nightly and interactive runs) may be duplicated unless extracted to a shared helper module.

**Option C — Two separately-scoped interfaces on one implementation**

A single `ReviewAgentEngine` class contains the model invocation logic and prompt construction. Two façade classes, `NightlyReviewFacade` and `InteractiveReviewFacade`, each delegate to `ReviewAgentEngine` but have different injected repositories. `InteractiveReviewFacade` is constructed without the `ConversationRepository` parameter.

- Safety property: the same as Option B — the interactive façade has no access to the Conversation repository. The shared engine handles prompt construction and LLM calls.
- This is a refinement of Option B that reduces duplication. It is the pattern recommended when two access modes share significant logic but differ in their data access rights.

**Recommended pattern: Option C (two façades, one engine)**

1. `ReviewAgentEngine` — handles prompt construction, the configured `BaseChatModel` call, and structured output parsing. It is data-source-agnostic; it receives its inputs as parameters (system prompt text, findings list, optionally a list of conversation excerpts).
2. `NightlyReviewFacade` — loads concluded Conversations and existing findings, calls `ReviewAgentEngine` with all inputs. Has `ConversationRepository` injected.
3. `InteractiveReviewFacade` — loads only the Persona's current System Prompt and existing findings, calls `ReviewAgentEngine` without Conversation excerpts. Does not have `ConversationRepository` injected. Structurally cannot pass Conversation histories to the engine.

The engine's function signature is something like: `ReviewAgentEngine.evaluate(system_prompt: str, findings: list[Finding], conversation_excerpts: list[str] = [])`. The nightly façade passes a populated `conversation_excerpts` list; the interactive façade always passes an empty list (or calls an overload that does not accept the parameter at all — strongest option).

*Cross-reference to RQ-E7:* Both façades read from the same `review_agent_findings` table established in RQ-E7. The nightly façade writes to it; the interactive façade reads from it but does not write (the interactive consultation produces suggestions that the user applies — application of findings writes to the `personas` table, not to `review_agent_findings`).

*Infrastructure as Configuration check:* No violation. Both façades share the same `BaseChatModel` instance, which is configured via the settings schema (RQ-H4). No provider is hardcoded in either façade or the engine.

*Cross-references:*
- RQ-E7: `review_agent_findings` table — both read targets for interactive façade.
- RQ-B4: System Prompt isolation is analogous — application-layer constraints prevent system prompts from leaking into the shared message store. The same design principle applies here.
- RQ-I13: The interactive consultation session's ephemerality (RQ-I13) is a separate concern from the access boundary established here; both must be addressed.

### RQ-I5 — Snapshot vs live Persona during mid-Conversation apply

**Status:** Complete

FR-15.4 requires that applying a Review Agent finding for a Persona that is active in an open Conversation updates the live Persona's System Prompt but leaves the running Conversation's snapshot unaffected. This is a subtle invariant: the same request modifies one record and deliberately does not modify another. Is there a pattern that makes this correctness-by-construction rather than correctness-by-care?

**Research findings:**

*The invariant in detail:*

When the user applies a Review Agent finding, two records exist:
1. **The `personas` table row** — the live Persona record. This is what the user edits on the Persona detail page. Applying a finding writes to `personas.system_prompt`.
2. **The `conversation_personas` snapshot row** (established in RQ-E4) — a copy of the Persona's `system_prompt`, `name`, and `temperature` taken at the moment the Conversation started. This snapshot is what the LLM context uses during the running Conversation. It must not change mid-Conversation.

FR-15.4 says: "a Conversation that is already in progress with that Persona continues to use the snapshot taken at conversation start." Applying the finding updates record (1) but must never touch record (2).

**Why this is a subtle correctness problem:**

The "apply" API handler calls something like `PersonaService.update_system_prompt(persona_id, new_text)`. If that service method also updates the snapshot row — or if the developer misidentifies the snapshot row as the canonical record — the running Conversation silently picks up the new System Prompt mid-run, violating FR-15.4. This is a correctness-by-care failure: the developer must remember not to update the snapshot.

**Making it correctness-by-construction:**

Three mechanisms combine to make the invariant structurally hard to violate:

*Mechanism 1 — Schema separation*

The `personas` table and the `conversation_personas` table are distinct tables with distinct ORM model classes. `PersonaService.update_system_prompt()` operates on the `Persona` ORM model (maps to `personas`). It has no import of or reference to the `ConversationPersona` ORM model. A developer implementing the "apply" handler who only touches `PersonaService` cannot accidentally write to `conversation_personas` — the model does not appear in scope.

This is the same structural isolation argument made in RQ-I4 for the Review Agent façades: the access boundary is enforced by what is in scope, not by what is documented.

*Mechanism 2 — No cascade update on `persona.system_prompt`*

The `conversation_personas` table must not have an ORM relationship that cascades updates from `Persona.system_prompt` to `ConversationPersona.system_prompt`. The snapshot was deliberately taken at Conversation start and must be an independent copy. The FK from `conversation_personas` to `personas` is for referential integrity (so Persona deletion can be managed) but carries no `cascade="all,delete-orphan"` for the `system_prompt` field. The ORM configuration explicitly does not define `back_populates` or any relationship that would propagate `system_prompt` changes from the parent to the snapshot row.

*Mechanism 3 — The "apply finding" API endpoint targets `personas`, not `conversation_personas`*

The API endpoint for applying a finding is something like `POST /personas/{persona_id}/apply-finding/{finding_id}`. Its handler retrieves the `Persona` record, updates `system_prompt`, and saves. The handler has no reason to enumerate open Conversations or touch `ConversationPersona` rows — there is no code path from the finding-apply handler to the snapshot table.

**What about Conversations that start after the finding is applied?**

New Conversations started after the finding is applied will take a fresh snapshot from the updated `personas.system_prompt`. This is correct — FR-15.4 only protects already-running Conversations.

**Residual correctness-by-care element:**

The only remaining care requirement is that any future developer who writes a "bulk update system prompt across all snapshots" feature (not in FR-15, but imaginable) must explicitly understand that this is a separate operation from a Persona update. The principles file should document: "The `conversation_personas` table is a write-once snapshot taken at Conversation start. It is never updated after creation."

**Summary:**

The invariant is made correctness-by-construction by: (a) schema separation so the `PersonaService` does not have the `ConversationPersona` model in scope, (b) no cascade update ORM relationship between `personas.system_prompt` and `conversation_personas.system_prompt`, and (c) the apply-finding API handler targeting only the `Persona` record. The combination of these three means a developer cannot accidentally update the snapshot without explicitly importing the `ConversationPersona` model and writing a new database call — which would be visibly intentional.

*Infrastructure as Configuration check:* No violation. This is a pure data model and application-layer design.

*Cross-references:*
- RQ-E4: The `conversation_personas` snapshot table is the concrete implementation; this question is about the invariant that protects it from being modified mid-Conversation.
- RQ-I3: The Context Panel's single-writer invariant uses a similar "dedicated endpoint + no system path" pattern to prevent accidental writes.

### RQ-I6 — Mentor session boundary detection

**Status:** Complete

FR-17.6 defines a "session" for the Mentor as bounded by chapter markers (with a day-change prompt on return), and FR-18.2 lists session end as one of the Working Memory compression triggers. How is "session end" detected in practice — when the user explicitly starts a new chapter, when they close the Mentor Conversation tab, when they close the application, or on a timer? The overview is explicit that Working Memory compression happens on any of capacity / new chapter / end of session; research should enumerate how each of those three triggers actually fires.

**Research findings:**

*The three compression triggers from FR-18.2:*

1. **Capacity** — Working Memory (the live Mentor Conversation) reaches a configurable token/message threshold.
2. **New chapter** — the user explicitly starts a new chapter (via the chapter marker feature, FR-17.6).
3. **End of session** — the session ends.

Trigger 1 and Trigger 2 are well-defined; this question is primarily about Trigger 3 — how "end of session" is detected.

**What "session" means for the Mentor:**

FR-17.6 says the Mentor presents a "day-change prompt" when the user returns after a gap, implying session boundaries are related to inactivity or day changes. There is no product requirement for the user to explicitly "end" a Mentor session — it ends naturally when they stop using it.

**How each trigger fires in practice:**

**Trigger 1 — Capacity:**

Fires during message processing. After each message is added to the Mentor Conversation, the application checks the current Working Memory size (message count or estimated token count). If it exceeds the configured threshold, compression is triggered immediately as part of the message-handling flow. This is synchronous and deterministic. The threshold value is a configurable integer in the settings schema (RQ-H4, `mentor_working_memory_capacity`). Write target: `mentor_episodic_memories` table (RQ-E6).

**Trigger 2 — New chapter:**

Fires when the user explicitly triggers a chapter marker (a UI action). The chapter marker feature in FR-17.6 implies a button or command that the user intentionally activates. When this action is received by the backend, it: (a) inserts a chapter-marker system message into the Mentor Conversation thread (FR-5.7 pattern), and (b) triggers Working Memory compression for the content since the previous chapter marker. This is an explicit user action — no ambiguity in detection.

**Trigger 3 — End of session (the hard case):**

Browser/client-side signals available for session end detection include:
- `pagehide` event (fired when tab is closed, navigated away from, or put into bfcache)
- `visibilitychange` event (fired when the page loses focus or is hidden)
- `navigator.sendBeacon()` — a best-effort POST that fires on page unload and is not cancelled by the browser

None of these are guaranteed to reach the server. The browser may kill the page process before the network call completes (especially on mobile). `sendBeacon()` is the most reliable of the client-side signals but is still best-effort.

Server-side signals available:
- **SSE connection drop:** If the frontend maintains a persistent SSE connection to the backend (established in RQ-G2), the SSE connection closing is a server-detectable event. When the SSE connection drops, the backend knows the client has disconnected. This is not instantaneous (the server may take 30–60 seconds to detect a half-open TCP connection without keepalives), but with proper SSE keepalive intervals (a periodic `:ping` comment every 15–30 seconds), the server can detect disconnection within one keepalive interval.
- **Inactivity timer:** A backend timer per Mentor session (keyed by `workspace_id`) that fires after a configurable inactivity period (e.g. 30 minutes with no messages). This is independent of client-side signals and is the most reliable fallback.

**Recommended pattern for Trigger 3 (best-effort + timer fallback):**

1. The frontend sends a `navigator.sendBeacon('/mentor/session-end', {workspace_id})` on `pagehide`. The backend receives this and, if there is un-compressed Working Memory, triggers compression immediately.
2. If the beacon does not arrive (network failure, process kill, mobile browser kill), the server-side inactivity timer fires after a configurable idle period. The timer detects that no messages have been received for N minutes and triggers compression.
3. On the next Mentor session start (when the user returns), the backend checks whether a pending compression exists (if compression was missed) and runs it before presenting the new session. The "day-change prompt" in FR-17.6 can be triggered by the same re-entry check.

This is the same pattern used by chat platforms (e.g. Streamlit's session detection research confirms: "No guaranteed client-side event that unequivocally means 'user closed browser/tab' — rely on server-side timeouts and multiple signals").

**Edge case — application close during mid-compression:**

If the compression LLM call is in progress when the application shuts down, it must not write partial results. The compression is a single LLM call followed by a database insert — if the call is cancelled (SIGTERM + `asyncio.CancelledError`), the insert does not happen and the episodic entry is not created. On the next startup, the uncompressed Working Memory is still present in the Conversation thread and the capacity check will re-trigger compression at the appropriate point. This is safe because Working Memory compression is idempotent from the Working Memory's perspective: compressing the same content twice produces at worst a duplicate episodic entry, which the rolling window handles by having two entries for the period rather than one.

**Summary of trigger mechanisms:**

| Trigger | Detection mechanism | Reliability |
| --- | --- | --- |
| Capacity | Synchronous check after each message | Deterministic |
| New chapter | Explicit user action (UI button) | Deterministic |
| Session end (beacon) | `navigator.sendBeacon()` on `pagehide` | Best-effort, not guaranteed |
| Session end (inactivity) | Server-side timer, configurable interval | Reliable, delayed by interval |
| Session end (reconnect check) | Check on next Mentor session start | Guaranteed (deferred) |

*Infrastructure as Configuration check:* No violation. The inactivity timer interval is a configurable value in the settings schema. No external timer service is required — an in-process asyncio timer or APScheduler task is sufficient.

*Cross-references:*
- RQ-E6: `mentor_episodic_memories` table is the write target for session-end compression.
- RQ-G2: The SSE connection drop as a session-end signal depends on SSE being the chosen transport (confirmed in RQ-G2).
- RQ-I7: Promotion-to-Semantic logic runs as part of the capacity trigger when the oldest episodic entry is about to be retired — session-end compression produces an episodic entry that will eventually reach this promotion step.

### RQ-I7 — Promotion-to-Semantic logic

**Status:** Complete

FR-18.3 and US-MM2 require that before the oldest Episodic entry is retired, the system "checks whether any facts in the oldest episodic entry should be promoted to Semantic Memory before retiring it." This is an LLM-mediated judgement (what counts as "fact worth keeping"). How is this best expressed — a dedicated prompt to the configured model, a rules-based filter, or a hybrid? How is the output structured so that it can be written into Semantic Memory reliably (RQ-C3)?

**Research findings:**

**The three approaches and their tradeoffs:**

**Option A — Pure rules-based filter**

A rules-based filter extracts facts without an LLM call: look for sentences with named entities (proper nouns, numbers, dates), extract key-value pairs using heuristics (e.g. "My name is X", "I work at Y", "I prefer Z"), and write those directly to `mentor_semantic_memories`.

*Advantages:* Deterministic, zero latency, zero token cost, no LLM dependency in this path.

*Disadvantages:* Fails on implicit facts ("I tend to think slowly before responding" does not parse as a named entity but is a promotable fact). Cannot distinguish facts stated speculatively from facts stated as true. Cannot identify when an existing semantic fact should be updated vs left alone. High false-negative rate for the nuanced, contextual facts that are most valuable in Semantic Memory.

Community consensus (confirmed in LangChain memory system discussions and OpenAI cookbook examples): pure rule-based extraction is appropriate only for highly structured domains. Conversational fact extraction reliably requires LLM judgement.

**Option B — Pure LLM extraction**

A dedicated prompt asks the configured model to read the episodic entry text and return a structured list of facts worth preserving in long-term memory.

This is the approach used by MemGPT, mem0, and the LangChain `ConversationEntityMemory` / `ConversationSummaryMemory` patterns. The key pattern (confirmed in MemGPT architecture and mem0 source) is:

- Input: the full text of the episodic entry (the session summary produced by session-end compression).
- Output: a JSON array of fact objects, each with `fact_key`, `fact_value`, and optionally a `confidence` field.
- The prompt instructs the model to: (1) extract only facts the Mentor's user has stated about themselves or their preferences, (2) express each fact as a short key-value pair, (3) return an empty array if no promotable facts are found, (4) flag any fact that contradicts an existing semantic fact so the system can resolve the conflict.

*Advantages:* High recall on implicit facts. Can handle temporal updates ("previously X, now Y"). Produces the exact schema needed for `mentor_semantic_memories` (RQ-C3: `fact_key`, `fact_value`, `confidence`, `last_updated_at`).

*Disadvantages:* One LLM call per episodic retirement. Adds latency to the retirement step. LLM output must be parsed and validated before writing to DB — structured output (JSON mode or tool-call output) is essential.

**Option C — Hybrid (rules-based pre-filter + LLM confirmation)**

Run a cheap rules-based pass first. If the episodic text contains zero candidate sentences (no proper nouns, no preference-pattern strings, no numeric facts), skip the LLM call and retire the episodic entry with zero promotions. If candidate sentences exist, send only those sentences to the LLM for structured extraction.

*Advantages:* Reduces LLM token cost for episodic entries that are genuinely fact-free (e.g. a session that was entirely abstract discussion). Keeps the deterministic fast path for obvious non-candidates.

*Disadvantages:* Still requires the LLM call for most real conversations. The pre-filter false-negative rate (missing a promotable fact at the filter stage) becomes a product quality risk.

**Recommended approach: Option B with structured output enforcement**

Pure LLM extraction is the most defensible for a conversational memory system, and the episodic retirement step is already a background operation (part of the capacity trigger), so added latency is acceptable. The critical implementation detail is using the model's structured output or tool-call capability to enforce the JSON schema at the API level, rather than relying on post-hoc parsing of free-text output.

**Output schema for reliable DB writes (mapping to RQ-C3):**

The LLM should return a JSON object with a single `facts` array:

```json
{
  "facts": [
    {
      "fact_key": "user_occupation",
      "fact_value": "software engineer at a fintech startup",
      "confidence": 0.9,
      "update_mode": "overwrite"
    }
  ]
}
```

Fields:
- `fact_key` — short snake_case identifier, stable across updates (e.g. `user_name`, `communication_preference`, `timezone`). The prompt must instruct the model to re-use an existing key when updating a known fact.
- `fact_value` — free-text string, concise.
- `confidence` — float 0–1 representing how explicitly the fact was stated (1.0 = directly stated by user; 0.5 = inferred from behaviour; 0.2 = speculative).
- `update_mode` — `overwrite` (replaces an existing row with the same `fact_key`) or `append` (creates a new row even if a key with the same name exists, for list-like facts such as "topics the user is interested in").

The `fact_key` + `workspace_id` combination is the upsert key for `mentor_semantic_memories`. The `last_updated_at` column is set by the application to `now()` on each upsert — the LLM does not produce this field.

**Handling zero promotable facts:**

The LLM returns `{"facts": []}`. This is a valid, expected response. The application treats it as: retire the episodic entry (delete the row from `mentor_episodic_memories`) with no writes to `mentor_semantic_memories`. No error is raised. This is the common case for episodic entries that are primarily task discussion with no personal facts.

**Handling LLM call failure:**

The LLM call for promotion can fail due to a transient API error, a timeout, or a model unavailability event. Two options:

- **Block retirement on LLM failure:** Do not delete the episodic entry. Retry the promotion call at the next capacity trigger or on a scheduled retry. Advantage: no data is lost. Disadvantage: if the LLM is persistently unavailable, the episodic window cannot grow (capacity trigger keeps firing but never completing retirement), potentially blocking new compressions.
- **Best-effort retirement:** Log the LLM failure, retire the episodic entry anyway (on the grounds that episodic retention is already time-bounded by design), and accept that the promotion step was skipped for this entry.

The correct choice is **block retirement with bounded retry**: attempt the LLM call up to N times (configurable, default 3) with exponential backoff. If all retries fail, retire the episodic entry and log a `promotion_skipped` warning with the entry ID. The system should surface this as a health indicator. This mirrors the pattern used in MemGPT's `archival_memory_insert` fallback: the operation is attempted, and failure is logged but does not permanently block the memory system.

**Transaction boundary:**

The promotion step and the episodic retirement are a single logical operation and must be a single database transaction:

1. BEGIN TRANSACTION
2. Call LLM (outside the transaction — LLM calls cannot be transactional)
3. If LLM succeeds: upsert facts into `mentor_semantic_memories`; delete the episodic row from `mentor_episodic_memories`; COMMIT.
4. If LLM fails after N retries: delete the episodic row from `mentor_episodic_memories` (best-effort fallback); log warning; COMMIT.

The LLM call itself is outside the transaction. The transaction wraps only the database writes, ensuring the fact upserts and the episodic deletion are atomic. If the process crashes between steps 2 and 3, the episodic entry is still present on the next startup, and the promotion will be re-attempted when the capacity trigger fires again.

**Conflict resolution for existing semantic facts:**

When the LLM returns a fact with a `fact_key` that already exists in `mentor_semantic_memories`, the upsert replaces the existing row's `fact_value` and `confidence` and updates `last_updated_at`. The old value is not preserved (no versioning of semantic facts in V1). If the promotion prompt instructs the LLM to flag contradictions (e.g. "user now lives in Berlin, previously stated London"), the `content_text` can include the old value for reference, but the write still overwrites.

**Prompt pattern for reliable structured extraction (confirmed pattern from MemGPT and mem0 research):**

The system prompt for the promotion call should:
1. Describe the task: "You are extracting long-term facts from a Mentor conversation summary."
2. Provide the existing semantic facts (or a summary of current `fact_key` values) so the model can re-use stable keys.
3. Instruct the model to output ONLY the JSON structure — no prose.
4. Enumerate the categories of promotable facts: personal facts (name, location, occupation), stated preferences, recurring patterns, stated goals.
5. Explicitly state that speculative or uncertain facts should receive low confidence, and that facts that are not about the user should not be included.

*Infrastructure as Configuration check:* No violation. The promotion LLM call goes through the same model abstraction interface used for all other LLM calls (RQ-A). The fact that structured output (JSON mode or tool use) is required is a prompt/API-level concern, not a model-provider constraint — all supported providers (OpenAI, Anthropic, local Ollama with grammar sampling) support this mode.

*Cross-references:*
- RQ-C3: `mentor_semantic_memories` schema (`fact_key`, `fact_value`, `confidence`, `last_updated_at`) is the write target. The `update_mode` field in the LLM output determines whether the write is an upsert or an insert.
- RQ-E6: The `mentor_episodic_memories` row being retired is the input to this step; its `content_text` is the LLM prompt input.
- RQ-I6: Session-end compression produces the episodic entry that eventually reaches this step when the capacity limit is hit.
- RQ-D1: The promotion step runs as part of the capacity trigger, which fires inline during message processing — not as a separate APScheduler job.

### RQ-I8 — Report generation concurrency

**Status:** Complete

FR-12.4 blocks concurrent Report generation for the same Conversation. What is the right lock granularity — per (conversation_id) — and where does it live (the job queue from RQ-D1, the database, or an in-process lock)? Does this mechanism generalise to "only one Review Agent run at a time" (RQ-D2) or is it a separate concern?

**Research findings:**

**Lock granularity: per `conversation_id`**

The lock is naturally per `conversation_id`. Only one Report generation job can be running for a given Conversation at any time (FR-12.4). This is a finer-grained concern than the global Review Agent run lock (RQ-D2), which prevents two nightly Review Agent runs from overlapping across all Conversations. Both are needed and are independent.

**Where the lock lives: three options**

**Option A — APScheduler `max_instances` per job**

APScheduler supports `max_instances=1` per job definition. If the job is defined as a per-Conversation job (e.g. job_id = `f"report_generation_{conversation_id}"`), setting `max_instances=1` means APScheduler will not allow a second instance of that job ID to run if one is already running. A second request to generate a Report for the same Conversation would be rejected at the scheduler level.

*Advantages:* The constraint is enforced at the scheduler level, which already manages job state (via the SQLAlchemy jobstore from RQ-D1). No additional database table or in-process data structure is needed.

*Disadvantages:* Report generation is a user-triggered action, not a scheduled recurring job. Using APScheduler to gate one-off user-triggered work is non-standard and introduces coupling between the request handler and the scheduler. The job would need to be submitted to APScheduler's queue and checked for duplication at submission time — this is more complex than it appears because APScheduler's deduplication is based on `coalesce`/`max_instances` for recurring jobs, not arbitrarily named one-off jobs.

**Option B — Database-backed status flag on the Report row**

The `reports` table (or a `report_generation_status` table) includes a `status` column with values `pending`, `in_progress`, `complete`, `failed`. Before starting Report generation, the application:
1. Inserts a new row with `status = 'in_progress'` for the `(conversation_id)` being generated, or checks for an existing `in_progress` row.
2. Uses a database-level unique partial index: `CREATE UNIQUE INDEX reports_conversation_in_progress ON reports (conversation_id) WHERE status = 'in_progress'` — this makes the insert fail with a unique constraint violation if another `in_progress` row already exists for the same `conversation_id`.
3. If the insert fails, the handler returns 409 Conflict to the caller.

This pattern is called a "database advisory lock via unique constraint" and is well-established for distributed systems. It works correctly under concurrent requests and survives process restarts (a crashed `in_progress` row can be detected on startup and reset to `failed`).

*Advantages:* Survives process restart (the `in_progress` flag persists in the DB). Works correctly in both SQLite (single-process) and PostgreSQL (multi-process) without any application-level coordination. Audit trail: the Report row records when generation started.

*Disadvantages:* Requires a write to the DB at the start of every Report generation attempt, even if the check fails immediately. Adds a row per Report to track lifecycle state.

SQLite note: SQLite serialises all writes (WAL mode allows one writer at a time), so the unique constraint violation approach works reliably even under concurrent requests.

**Option C — In-process asyncio lock keyed by `conversation_id`**

An in-process dictionary maps `conversation_id` to an `asyncio.Lock()`. Before starting Report generation, the handler acquires `lock_map[conversation_id]`. If the lock is already held, the handler can either: (a) raise immediately (returning 409), or (b) `await lock.acquire()` and queue behind the first request.

*Advantages:* Zero database writes for the locking mechanism. Extremely low latency check.

*Disadvantages:* The lock is lost on process restart (a crash during Report generation leaves no `in_progress` marker, so the system cannot detect stale generation on startup). Does not work if the application runs across multiple processes (not a concern in V1 but a scaling constraint). In an async context, holding a lock across an LLM API call (which may take 30+ seconds) is correct but requires careful error handling to ensure the lock is released on `asyncio.CancelledError` or exception.

**Comparison table:**

| Mechanism | Survives restart | Multi-process safe | V1 complexity | Recommended for |
| --- | --- | --- | --- | --- |
| APScheduler `max_instances` | Yes (jobstore) | Yes (shared jobstore) | Medium | Recurring scheduled jobs |
| DB unique partial index | Yes | Yes | Low-medium | One-off user-triggered work |
| In-process asyncio lock | No | No | Low | Prototype / single-process |

**Recommended approach: DB-backed `in_progress` flag (Option B)**

For a user-triggered operation with potentially long duration (LLM call), the database-backed status flag is the most robust. The partial unique index enforces the constraint at the DB level, making it safe under any concurrency model. The lock is effectively the Report row itself — no separate lock table is needed.

**Behaviour on second request (reject vs queue):**

FR-12.4 says to block concurrent generation — it does not say to queue. The correct behaviour is: return 409 Conflict immediately when a second Report generation is requested for a Conversation that already has an `in_progress` Report. The UI can show "Report generation already in progress" as a message. No queue is maintained (consistent with the no-action-queue principle from FR-5.8, which applies more broadly to the idle-state gating pattern — see also RQ-I11).

**Does this generalise to RQ-D2 (single Review Agent run)?**

No — they are separate concerns at different granularities:
- RQ-D2 uses the `review_agent_runs` table with a `running` status flag to enforce a global "only one Review Agent run at a time" constraint. This is a workspace-agnostic global lock.
- RQ-I8 uses a per-`conversation_id` `in_progress` flag on the Report row. This is a per-Conversation finer-grained lock.

The two mechanisms coexist: a Review Agent run (which generates Reports for all concluded Conversations in a Workspace) first checks the RQ-D2 global lock, then acquires per-Conversation `in_progress` flags as it processes each Conversation sequentially. A user manually triggering Report generation also checks the per-Conversation flag. The global lock (RQ-D2) does not prevent a user from manually generating a Report for a Conversation that is not currently being processed by the nightly run.

*Infrastructure as Configuration check:* No violation. The DB unique partial index is a standard SQL feature supported by both SQLite and PostgreSQL. No external lock service is required.

*Cross-references:*
- RQ-D1: APScheduler is the scheduler for the nightly Review Agent run; Report generation locking is separate from APScheduler's job deduplication.
- RQ-D2: The global Review Agent run lock (`review_agent_runs` table) is a coarser-grained sibling of this per-Conversation lock — they are complementary, not alternatives.
- RQ-I11: The broader idle-state gating pattern (per-Conversation idle flag) is related but distinct — idle-state gating covers all user actions during a live Conversation, not just Report generation.

### RQ-I9 — Workspace deletion during in-flight work

**Status:** Complete

FR-1.8 and US-W3 require that deleting a Workspace mid-Review-Agent-run stops the run immediately and discards partial results. FR-9.7 and US-W4 require that mid-Conversation in-flight AI responses complete in the background after a Workspace switch. Deleting a Workspace while one of its Conversations has an in-flight response is a combination case. What cancellation model supports both behaviours — cancellation tokens, run IDs that are invalidated, or something else? Any model must also ensure no data from a deleted Workspace survives in any queue, cache, or on-disk staging area.

**Research findings:**

**The two behaviours in tension:**

1. **Review Agent mid-run delete (FR-1.8, US-W3):** Cancel immediately, discard partial results. The Review Agent is a background job with no user-visible partial output — aborting it and cleaning up is the correct behaviour.
2. **In-flight Conversation response after Workspace switch (FR-9.7, US-W4):** The LLM call should complete in the background, and the result should be saved even though the user has switched away. The user can return to the Conversation and see the completed response.

The conflict: Workspace deletion while case 2 is active. The AI response is in-flight (should complete by the FR-9.7 rule) but the Workspace is deleted (should be cancelled and discarded by the FR-1.8 rule). Deletion supersedes the "complete in background" rule — deletion is an intentional, destructive action.

**asyncio task tracking model:**

The application maintains a per-Workspace set of `asyncio.Task` references, keyed by `workspace_id`. This is an in-process registry:

```python
# In-process task registry
workspace_tasks: dict[uuid.UUID, set[asyncio.Task]] = defaultdict(set)
```

When any background async operation is started for a Workspace (LLM streaming call, Review Agent run, Report generation), its `asyncio.Task` is registered in `workspace_tasks[workspace_id]`. When the task completes (success or error), it removes itself from the registry via a done callback:

```python
task.add_done_callback(lambda t: workspace_tasks[workspace_id].discard(t))
```

On Workspace deletion, the deletion handler:
1. Iterates `workspace_tasks[workspace_id]`
2. Calls `task.cancel()` on each task
3. Awaits `asyncio.gather(*tasks, return_exceptions=True)` to confirm all tasks have received `CancelledError` and have completed their `finally` blocks
4. Proceeds to DB deletion

**`asyncio.Task.cancel()` behaviour (confirmed from Python docs):**

`task.cancel()` schedules a `CancelledError` to be raised at the next `await` point inside the task. The task can catch it in a `try/finally` or `except asyncio.CancelledError` block to perform cleanup before re-raising. This is the standard asyncio cancellation pattern.

Key behaviours:
- `cancel()` is a request, not an immediate kill. The task continues until its next `await` point.
- LLM streaming calls (which are long-running `await` calls) will raise `CancelledError` at the `await` on the next streamed chunk. The HTTP connection to the LLM provider is closed by the underlying HTTP client's cancellation path (httpx cancels the request when the coroutine is cancelled).
- Tasks should always re-raise `CancelledError` after cleanup — catching it and not re-raising breaks the cooperative cancellation contract.

**Run ID invalidation as a supplementary guard:**

An alternative (or complement) to task cancellation is run ID invalidation. Each in-flight task is assigned a `run_id` (UUID) at creation. The run ID is stored in the task registry and also in the database (e.g. in the `review_agent_runs` table for Review Agent runs, or in a `conversation_run_id` column for in-flight Conversation responses).

On Workspace deletion, the delete handler marks all run IDs for the Workspace as `cancelled` in the database before calling `task.cancel()`. Inside the task, at each significant checkpoint (before writing a DB row, before starting the next step), the task checks: "is my `run_id` still valid?" If not, it raises `CancelledError` itself and exits.

This provides defence in depth: even if `task.cancel()` fails to propagate immediately (e.g. the task is in a non-interruptible C extension call), the DB check will catch it at the next checkpoint.

**Cleanup order for Workspace deletion:**

1. **Mark `workspace.deleted_at = now()`** (soft-delete flag) — from this point, no new tasks can be created for this Workspace (checked at task creation time).
2. **Collect all in-flight tasks** from `workspace_tasks[workspace_id]`.
3. **Invalidate run IDs** in the DB for all in-flight jobs (set `status = 'cancelled'` in `review_agent_runs`, clear `conversation_run_id` for in-flight Conversations).
4. **Cancel all tasks** (`task.cancel()` on each).
5. **Await all task completions** (`asyncio.gather` with `return_exceptions=True`) — waits for all tasks to reach their finally blocks and exit.
6. **Hard delete DB rows** — cascade delete all data for the Workspace (Personas, Conversations, Messages, Reports, Memory tables, etc). SQLAlchemy cascade delete on the `workspace_id` FK is the mechanism.
7. **Clear workspace_tasks entry** — remove the now-empty registry entry.
8. **Return success to the client**.

**Soft-delete vs hard-delete tradeoff:**

- **Hard delete:** All Workspace data is immediately and irreversibly removed. The `cascade delete` on the `workspace_id` FK in SQLAlchemy handles this in a single DB operation. Simpler, no orphan risk. Chosen here as the correct model for V1 (FR-1.8 says "deleted" not "archived").
- **Soft delete:** Workspace row has a `deleted_at` column; queries filter it out but the data persists. Advantage: supports undo, audit trail. Disadvantage: every query must include `WHERE deleted_at IS NULL`, and the "no data survives" requirement from FR-1.8 becomes harder to guarantee (data is still on disk). For V1, hard delete is simpler and satisfies the requirement.

**Ensuring no data survives in queue, cache, or staging:**

- **APScheduler queue:** Any pending (not yet started) Review Agent jobs for the Workspace must be removed from the APScheduler jobstore. APScheduler supports `scheduler.remove_job(job_id)` — the deletion handler iterates pending jobs and removes any matching `workspace_id`. This must happen before the hard delete, as the job store may hold a reference to the Workspace's `review_agent_runs` row.
- **In-process cache:** If the application maintains any in-process cache (e.g. LRU cache of Persona records or Conversation metadata), the Workspace deletion must invalidate all cache entries for `workspace_id`. This can be done by tagging cache entries with `workspace_id` and evicting all matching entries on delete.
- **On-disk staging:** If streaming LLM responses are written to a temporary file before being committed to the DB (not expected in V1 but worth noting), the temp file must be deleted as part of step 4/5 above. The task's `finally` block is responsible for deleting any on-disk staging artefacts it created.

**The FR-9.7 + deletion combination case:**

When a Workspace is deleted while an in-flight Conversation response is completing in the background (the FR-9.7 case):

- The task receives `task.cancel()`.
- The task's `finally` block discards any partial LLM output already buffered.
- The task does not write any message row to the database (the write happens only on successful completion).
- The soft-delete flag set in step 1 causes any attempt by the task to write to the DB to be rejected by the `WorkspaceScopedMixin` (RQ-E5) — the Workspace row no longer appears as active, so the foreign key write will fail (or the scoped query will find nothing to update).

This is a safe failure mode: the in-flight response is silently discarded, consistent with FR-1.8.

*Infrastructure as Configuration check:* No violation. `asyncio.Task`, `task.cancel()`, and `asyncio.gather` are Python stdlib. No external cancellation service is required.

*Cross-references:*
- RQ-D1: APScheduler is used for the Review Agent nightly run; pending APScheduler jobs for the Workspace must be explicitly removed during deletion.
- RQ-D2: The `review_agent_runs` table row is marked `cancelled` as part of step 3 — this is consistent with the global run lock mechanism.
- RQ-E5: `WorkspaceScopedMixin` scoping provides a DB-level guard against post-deletion writes landing in an orphaned Workspace.
- RQ-G3: In-flight tasks are associated with the Workspace's idle/busy state; cancellation resets the state to `idle` (though the Workspace is being deleted so the SSE channel for that Workspace is also being torn down).
- RQ-I8: Per-Conversation Report generation tasks are also registered in `workspace_tasks` and cancelled as part of Workspace deletion.

### RQ-I10 — System message insertion consistency

**Status:** Complete

FR-5.7 (Persona join/leave system messages) and raw Conversation exports (FR-3.10) both treat system messages as first-class parts of the Conversation thread. Are system messages stored as message rows with a distinct type, or as a separate event stream that is merged at read time? How does this affect the Automatic Summary, the Review Agent's evidence capture, and the raw Markdown export?

**Research findings:**

**The two architectural options:**

**Option A — System messages as message rows with a distinct `role` type**

All messages (user, AI, and system/event) are stored in the same `messages` table with a `role` column: `user`, `assistant`, `system_event`. System messages (Persona join/leave, chapter markers, auto-naming events) are inserted as rows with `role = 'system_event'` and a `content_type` indicating the specific event kind.

Schema addition to the existing `messages` table:
- `role`: enum `('user', 'assistant', 'system_event')`
- `event_type`: nullable string (e.g. `'persona_joined'`, `'persona_left'`, `'chapter_marker'`, `'conversation_named'`) — only populated when `role = 'system_event'`
- `event_metadata`: nullable JSON (e.g. `{"persona_id": "...", "persona_name": "..."}`) — structured data for UI rendering

*Advantages:*
- Queries for the full Conversation thread (for display, export, Review Agent input) are a single `SELECT ... ORDER BY created_at` — no merging needed.
- Ordering guarantees: system events appear at the exact moment in the thread when they happened (between message N and message N+1 based on `created_at`).
- The raw Markdown export (FR-3.10) is a single ordered result set — no merge join required.
- The Review Agent can skip `role = 'system_event'` rows when assembling the LLM context for analysis, using a simple `WHERE role != 'system_event'` filter on its input query.
- LangChain's message history loaders (`SQLChatMessageHistory`) support custom role values — `system_event` rows can be loaded as `ChatMessage(role='system_event', content=...)` objects and filtered before sending to the LLM.

*Disadvantages:*
- The `messages` table schema becomes slightly polymorphic (the `event_type` and `event_metadata` columns are only meaningful for `system_event` rows). This is manageable with a table check constraint.
- Querying only user/assistant messages (for LLM context assembly) requires a `WHERE role IN ('user', 'assistant')` filter — one extra clause, not a significant cost.

**Option B — Separate `conversation_events` table, merged at read time**

A second table `conversation_events` stores system/event messages, with a `(conversation_id, occurred_at)` index. Read queries merge the two tables using a UNION or a LEFT JOIN with ordering by `occurred_at`.

*Advantages:*
- Clean separation: the `messages` table contains only LLM-relevant messages. The events table is clearly a different concern.

*Disadvantages:*
- Every read of the full Conversation thread (display, export, Review Agent) requires a UNION query or application-layer merge. This is more complex and harder to paginate correctly (UNION ordering with LIMIT/OFFSET is notoriously tricky in SQLite).
- The ordering guarantee is weaker: if a system event and a user message have identical `created_at` timestamps (possible under async concurrency), the merge order is undefined without an explicit tiebreaker.
- Raw Markdown export (FR-3.10) must implement the merge — either in SQL or in the application layer.
- More complex to test: two code paths for "full thread" vs "LLM messages only".

**Standard practice in chat applications:**

Confirmed behaviour from Discord, Slack, and Rocket.Chat architectures: system/event messages are stored as first-class message rows with a distinct `type` or `role` field. This is also the pattern used in LangChain's `ConversationBufferMemory` and OpenAI's chat completion API, which defines `role: system` as a distinct value in the messages array. The separate-event-table approach is less common and appears primarily in event-sourcing architectures where the event log is the source of truth, not the message store.

**Recommended approach: Option A — `system_event` role in the `messages` table**

This is the simpler, more queryable approach and matches standard chat application patterns. The polymorphic columns (`event_type`, `event_metadata`) are a minor schema concern easily managed by a database check constraint.

**How system messages interact with downstream features:**

**Automatic Summary (FR-3.4):**

The Automatic Summary is generated by an LLM call over the Conversation's message content. The prompt for the summary should filter out `system_event` rows — they are metadata events, not conversation content. The query for the summary LLM context uses `WHERE role IN ('user', 'assistant')`. The rendered summary in the UI may optionally include inline references to events (e.g. "at this point, Persona X joined") but this is a UI rendering concern, not a stored field.

**Review Agent evidence capture (RQ-E7):**

The Review Agent's `evidence_message_ids` (from RQ-E7) references the `id` values of `messages` rows used as evidence for a finding. System event rows should not appear in `evidence_message_ids` — the Review Agent processes only `role IN ('user', 'assistant')` messages for its analysis. However, a system event row (e.g. `persona_joined`) could be contextually relevant: if the Review Agent notes that a Persona's tone changed, it may be relevant that a second Persona joined mid-conversation. This is a prompt design concern — the Review Agent prompt can optionally include `system_event` rows as context but should not generate findings that cite them as evidence.

**Raw Markdown export (FR-3.10):**

A single ordered query: `SELECT role, content, event_type, created_at FROM messages WHERE conversation_id = ? ORDER BY created_at`. In the Markdown output, `system_event` rows are rendered as a distinct visual element (e.g. `> **[System]** Persona "Alice" joined the conversation`) rather than as a user or assistant message block. The export format is determined by the exporter, not the storage model.

**LangChain interaction:**

LangChain's `BaseChatMessageHistory` interface and `SQLChatMessageHistory` implementation store messages with a `type` field corresponding to message class names (`HumanMessage`, `AIMessage`, `SystemMessage`, `ChatMessage`). The `system_event` rows in the AI Council schema are closest to `ChatMessage(role='system_event', content=...)`. When loading history for LLM context assembly, the application filters to `HumanMessage` and `AIMessage` equivalents, which maps to the `WHERE role IN ('user', 'assistant')` clause.

Note: LangChain's `SystemMessage` is semantically different from a `system_event` in this context. LangChain's `SystemMessage` is the system prompt (the Persona's instructions), which is prepended to every LLM call and is not stored as a `messages` row in AI Council's schema. FR-5.7 "system messages" are UI-layer event markers, not LLM system prompts.

**Example system event types and their storage:**

| Event | `event_type` value | `event_metadata` example |
| --- | --- | --- |
| Persona joined Conversation | `persona_joined` | `{"persona_id": "...", "persona_name": "Alice"}` |
| Persona left Conversation | `persona_left` | `{"persona_id": "...", "persona_name": "Alice"}` |
| Mentor chapter marker | `chapter_marker` | `{"chapter_title": "Week 3 Retrospective"}` |
| Conversation auto-named | `conversation_named` | `{"new_name": "Planning discussion"}` |
| Conversation auto-summarised | `conversation_summarised` | `{"summary_id": "..."}` |

*Infrastructure as Configuration check:* No violation. The `messages` table schema change is a standard SQL migration. No external event stream service is required.

*Cross-references:*
- RQ-E7: `evidence_message_ids` in `review_agent_findings` should reference only `role IN ('user', 'assistant')` message IDs — `system_event` rows are context, not evidence.
- RQ-I2: Conversation auto-naming (RQ-I2) can insert a `conversation_named` system event row as part of the naming flow, if the UI is designed to show this in the thread.
- RQ-I3: System event rows enter the `messages` table through a dedicated backend path (not through the user message submission path), consistent with the single-writer principle from RQ-I3.
- RQ-I6: Mentor chapter markers (Trigger 2 from RQ-I6) are stored as `system_event` rows with `event_type = 'chapter_marker'`.

### RQ-I11 — Idle-state gating and race conditions

**Status:** Complete

Many actions are gated on "system is idle" (see RQ-G3) and explicitly no action queue is supported (FR-5.8). What is the right pattern for expressing and enforcing this — a single authoritative idle flag in the backend, per-Conversation idle flags, a more general per-aggregate lock? How does this interact with background jobs that are not user-triggered (the Review Agent nightly run)?

**Research findings:**

**Lock granularity: per-Conversation, not global**

The system has multiple active Conversations simultaneously within a Workspace. A user can be in Conversation A while the Review Agent is analysing Conversation B. The idle state must therefore be per-Conversation (or more precisely, per-Conversation-session), not a single global flag.

The three-state model from RQ-G3 (`idle`, `busy`, `paused`) applies at the Conversation level. Each Conversation has an authoritative state held in the backend, and the backend is the single source of truth.

**What each state means at the per-Conversation level:**

- `idle`: No LLM call in progress for this Conversation. User actions (send message, add Persona, etc.) are accepted.
- `busy`: An LLM call or background operation (streaming response, Report generation) is in progress for this Conversation. User actions that require `idle` are rejected with 409.
- `paused`: The Conversation is paused mid-stream (if the product supports pause — FR-5.8 says no action queue, implying pause is also a user-visible state distinct from busy during streaming). This is the state where streaming output is happening but the user can interrupt.

For simplicity in V1, `busy` and `paused` may collapse into a single non-`idle` state. The product requirements do not explicitly define `paused` for Conversations (it appears in the Orchestrator context from RQ-G3). The core distinction is `idle` vs not-`idle`.

**Where the state lives:**

Two candidates:

**Option A — In-process asyncio state per `conversation_id`:**

```python
conversation_states: dict[uuid.UUID, Literal["idle", "busy"]] = {}
conversation_locks: dict[uuid.UUID, asyncio.Lock] = {}
```

When a user action arrives, the handler checks `conversation_states[conversation_id]`. If `busy`, return 409. If `idle`, set to `busy`, run the operation, set back to `idle`.

*Advantages:* Zero DB overhead for state checks. Asyncio `Lock` prevents the TOCTOU race (see below).

*Disadvantages:* State is not visible to other processes (not a V1 concern for single-process deployments). State is lost on restart — if the process crashes mid-LLM-call, the Conversation may be left in `busy` state in-process, but since the process restarted, the in-process dict is reset and the state is implicitly `idle`. This is actually the correct behaviour for restart: the LLM call was cancelled, the response was not saved, and the Conversation is back to `idle`.

**Option B — DB column `conversation_state` on the `conversations` table:**

The `conversations` table gets a `state` column: `idle` or `busy`. Reads and writes are DB operations. A `SELECT FOR UPDATE` is used to acquire the state atomically (for PostgreSQL) or a unique partial index trick (for SQLite).

*Advantages:* State survives process restart. Correct in a multi-process deployment.

*Disadvantages:* Every user action requires a DB read-write-update for state management. For a streaming response, the state transitions (`idle → busy` at start, `busy → idle` at end) add two DB writes to every LLM call, adding latency.

**Recommended approach: In-process asyncio lock (Option A) for V1**

For V1 (single process, SQLite), the in-process asyncio lock is sufficient, correct, and low-overhead. The state survives all normal operating conditions (process restart is an exceptional case that correctly resets state). A DB column can be added later when multi-process support is needed.

**The TOCTOU race condition and how to prevent it:**

The "check state → start action" gap is the classic time-of-check-to-time-of-use (TOCTOU) race. In a single-threaded asyncio event loop, two concurrent requests could both check `conversation_states[id] == 'idle'` before either sets it to `busy`:

```text
Request 1: check → idle (not yet busy)
Request 2: check → idle (not yet busy)   ← race
Request 1: set state to busy, start LLM call
Request 2: set state to busy, start LLM call  ← both running
```

In asyncio, this race only occurs if there is an `await` between the check and the state update. The fix is to use an `asyncio.Lock` as a non-awaited critical section:

```python
async with conversation_locks[conversation_id]:
    if conversation_states[conversation_id] != "idle":
        raise HTTP409ConflictError()
    conversation_states[conversation_id] = "busy"
# Lock released; LLM call runs without holding the lock
try:
    result = await llm_call(...)
    await save_result(result)
finally:
    conversation_states[conversation_id] = "idle"
```

The lock is held only for the check-and-set operation (microseconds), not for the LLM call itself. This eliminates the race without blocking the event loop. `asyncio.Lock` is non-reentrant by default and is fair (FIFO ordering for waiters), so a second request will wait behind the lock, see `busy`, and return 409 immediately. No queue forms because the lock is held for microseconds.

**`select_for_update()` in SQLAlchemy:**

SQLAlchemy's `select_for_update()` is a row-level advisory lock mechanism for PostgreSQL (and MariaDB). For SQLite, `SELECT FOR UPDATE` is not supported — SQLite serialises all writes at the connection level, so the asyncio lock approach achieves the same effect without needing `select_for_update()`.

For PostgreSQL: `select_for_update()` on the `conversations` row would work as an alternative to the in-process lock, but it requires a DB round-trip and holds a row lock for the duration of the check-and-set, not the LLM call. This is the right pattern for the DB-column approach (Option B), where the state is authoritative in the DB.

**How background jobs (Review Agent) interact:**

The Review Agent nightly run (RQ-D1, RQ-D2) is not subject to the per-Conversation idle state in the same way. The Review Agent reads concluded Conversations — Conversations that have already ended. A concluded Conversation does not receive new user messages, so there is no idle/busy race to manage.

However, the Report generation step (RQ-I8) within the Review Agent run does interact: as the Review Agent generates a Report for a Conversation, it sets the Report row to `in_progress` (the DB-backed flag from RQ-I8). If the user simultaneously requests manual Report generation for the same Conversation (a concluded Conversation), the per-Conversation Report generation lock (RQ-I8) prevents duplication.

The per-Conversation idle state (for live, in-progress Conversations) and the per-Conversation Report generation lock (for concluded Conversations) are two separate mechanisms protecting different operations on different Conversation lifecycle stages. They do not interfere with each other.

**SSE state broadcast (from RQ-G3):**

When the backend transitions a Conversation's state (`idle → busy`, `busy → idle`), it broadcasts the new state to all connected SSE clients for that Workspace. The SSE event is:

```text
event: conversation_state_change
data: {"conversation_id": "...", "state": "busy"}
```

The frontend uses this event to disable UI controls that require `idle`. This is the authoritative state — the frontend does not maintain its own idle state; it only reflects what the backend broadcasts.

**Edge case — state stuck in `busy` after crash:**

If the process crashes while an LLM call is in-flight, the in-process state is lost. On restart, the conversation_states dict is empty (all Conversations start as `idle`). This is the correct behaviour: the LLM call was interrupted, the response was not saved (the DB write only happens in the `finally` block after the LLM call completes), and the Conversation is back to `idle`. The user can resend their message.

The orphaned task leaves no trace in the DB because the message row is not written until the LLM call completes and the result is saved atomically.

*Infrastructure as Configuration check:* No violation. `asyncio.Lock` is Python stdlib. The SSE state broadcast uses the same SSE transport confirmed in RQ-G2. No external coordination service is required.

*Cross-references:*
- RQ-G3: The three-state model (idle/busy/paused) from RQ-G3 is the authoritative definition; this finding applies it at per-Conversation granularity.
- RQ-G2: SSE is the transport for state broadcast — every `conversation_state_change` event goes through the SSE channel.
- RQ-I8: The per-Conversation Report generation lock (DB-backed) is a sibling mechanism for the Report generation operation specifically, distinct from the in-process asyncio lock for live Conversation state.
- RQ-I9: Workspace deletion cancels all in-flight tasks; after cancellation, the per-Conversation state is no longer relevant (the Workspace is gone), but the in-process asyncio lock ensures that cancelled tasks release the lock in their `finally` blocks.

### RQ-I12 — Report generation after Conversation deletion

**Status:** Complete

FR-3.9 allows Reports to survive Conversation deletion, at which point the link back to the source Conversation "will no longer resolve." What does the data model look like to make this graceful rather than a null-pointer exception — a nullable foreign key, a soft-deleted Conversation stub, a denormalised source-title field on the Report?

**Research findings:**

**What the Report needs from the Conversation at read time:**

To display a Report, the UI needs to know:
1. Which Conversation the Report was generated from (for navigation — "view source conversation").
2. The name of the source Conversation (for display in the Report header and in the Reports list).
3. The Persona the Report analysed (already stored on the Report row via `persona_id` — survives Conversation deletion as long as the Persona is not also deleted).

Item 1 becomes a dead link if the Conversation is deleted. Item 2 is only available via the Conversation row unless it is denormalised. Item 3 is already safe.

**The four relational patterns for orphaned references:**

**Option A — Nullable FK with `SET NULL ON DELETE`**

The `reports` table has a `conversation_id` column with a nullable FK: `FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE SET NULL`. When the Conversation is deleted, the DB automatically sets `reports.conversation_id = NULL`. The Report survives with `conversation_id = NULL`.

Read-time behaviour: the query `JOIN conversations ON reports.conversation_id = conversations.id` returns no row when `conversation_id IS NULL` (or the join is `LEFT JOIN`). The UI checks `conversation_id IS NULL` and renders "Source conversation deleted" instead of a link.

*Advantages:* Standard SQL pattern. No application code needed to handle the transition from linked to unlinked. The DB enforces referential integrity at all times.

*Disadvantages:* Once `conversation_id` is NULL, the Report has no record of which Conversation it came from. If the Conversation name was never stored on the Report, it is permanently lost. The UI can only show "Source conversation deleted" with no name.

**Option B — Soft-deleted Conversation stub**

The `conversations` table has a `deleted_at` column. Deleting a Conversation sets `deleted_at = now()` rather than removing the row. The FK on `reports.conversation_id` remains valid (it points to the still-present row). Queries that load Conversations for the user filter `WHERE deleted_at IS NULL`, so the deleted Conversation is invisible in normal operation. The Report query does a plain `JOIN` and still retrieves the Conversation name from the soft-deleted row.

*Advantages:* The Report's link is permanently valid. The Conversation name and any other metadata the Report needs is always available. No denormalisation required.

*Disadvantages:* Deleted Conversations remain in the DB indefinitely unless a hard purge is run. This conflicts with the spirit of FR-1.8 (which says Workspace deletion removes all data — the same principle should apply to Conversation deletion). Data the user believes is deleted is still on disk. Requires `WHERE deleted_at IS NULL` in every Conversation list query to avoid showing deleted Conversations. GDPR / privacy implications: soft-deleted data is not deleted data.

Soft-delete is the correct pattern for Workspaces (where the soft-delete flag gates task cancellation, per RQ-I9), but it is a misleading pattern for Conversations if the product implies the data is gone.

**Option C — Denormalised `source_conversation_title` on the Report row**

The `reports` table stores a copy of the Conversation name at the time the Report was generated: `source_conversation_title TEXT NOT NULL`. The FK `conversation_id` is still present but nullable (as in Option A). When the Conversation is deleted: the FK is set to NULL (via `ON DELETE SET NULL`), but the `source_conversation_title` column retains the name. The Report can display "From: Planning discussion (deleted)" permanently.

*Advantages:* The Report always has the Conversation name, even after deletion. No soft-delete required. No data the user deleted persists in the Conversations table. The UI can show a meaningful label ("From: [name] — conversation deleted") rather than a generic "deleted" message.

*Disadvantages:* Denormalised — if the Conversation is renamed after Report generation but before deletion, the Report shows the name at generation time, not the final name. This is actually the correct behaviour (the Report reflects the state at the time it was generated).

**Option D — Denormalised snapshot with no FK**

The `reports` table stores all needed Conversation metadata (`source_conversation_title`, `source_persona_name`, etc.) at generation time and has no FK back to the Conversation at all. No `conversation_id` column.

*Advantages:* Completely decoupled from Conversation lifecycle. No orphaned reference problem.

*Disadvantages:* Cannot support "navigate to source Conversation" while the Conversation still exists. This is a product regression — the UI should link to the source Conversation if it still exists (useful for users who want to continue the conversation or see the full context).

**Recommended approach: Option C — nullable FK + denormalised title**

This is the standard pattern for "orphaned reference with graceful degradation" in relational systems, used in e-commerce orders (store product name at time of purchase), document history (store author name at time of edit), and similar audit-trail patterns. It gives:
- A live link to the Conversation while it exists (`conversation_id IS NOT NULL` → render link).
- A preserved name after deletion (`conversation_id IS NULL` → render `source_conversation_title` with "deleted" indicator).
- No soft-deleted data on disk.

**Schema change for the `reports` table:**

```sql
ALTER TABLE reports
    ADD COLUMN source_conversation_title TEXT NOT NULL DEFAULT '',
    ALTER COLUMN conversation_id DROP NOT NULL;  -- make nullable

-- Or in SQLAlchemy model terms:
conversation_id = Column(UUID, ForeignKey("conversations.id", ondelete="SET NULL"), nullable=True)
source_conversation_title = Column(Text, nullable=False)
```

The `source_conversation_title` is populated when the Report is created (copied from `conversations.name` at that moment).

**UI behaviour when source Conversation is gone:**

| `conversation_id` | Rendered UI |
| --- | --- |
| Not NULL | "From: [link to Conversation name]" |
| NULL | "From: [source_conversation_title] (conversation deleted)" |

**What the Report needs at read time — full picture:**

The Report display requires:
- `reports.id`, `reports.content_text`, `reports.created_at` — always on the Report row.
- `reports.persona_id` → join to `personas` for Persona name and avatar — Persona may or may not still exist (same orphaned-reference risk, same nullable-FK + denormalised-name pattern should apply to `source_persona_name`).
- `reports.conversation_id` → optional join to `conversations` for link — gracefully NULL when deleted.
- `reports.source_conversation_title` — always present, used when the link is NULL.

**Interaction with Workspace deletion (RQ-I9):**

When a Workspace is deleted, all its Reports are hard-deleted via cascade (along with all other Workspace data). The soft-delete vs hard-delete question for Reports does not arise — deletion of the Workspace removes everything. The nullable FK + denormalised title pattern only matters for individual Conversation deletions within a still-active Workspace.

*Infrastructure as Configuration check:* No violation. Nullable FK and denormalised columns are standard SQL/SQLAlchemy features.

*Cross-references:*
- RQ-E7: `review_agent_findings` table stores `conversation_id` and `persona_id` as FKs; the same nullable-FK + denormalised-name pattern should be applied there if findings are expected to survive Conversation or Persona deletion.
- RQ-I9: Workspace deletion hard-deletes all Reports via cascade — this pattern only applies to individual Conversation deletion within a live Workspace.
- RQ-I8: The `in_progress` status flag on the Report row (from RQ-I8) means a Report that is being generated when its source Conversation is deleted must handle the case where the Conversation FK is set to NULL mid-generation. The Report generation task should capture `source_conversation_title` at the start of the generation job, before any deletion can occur.

### RQ-I13 — Interactive consultation session ephemerality

**Status:** Complete

FR-16.3 and US-RA4 require that the interactive Review Agent consultation session be discarded when the user navigates away from the Persona page. Where should this ephemeral session live — in the browser only, in server memory keyed by a navigation scope, in a short-lived backend session that is explicitly garbage-collected on navigation? What is the cleanest pattern that prevents accidental persistence?

**Research findings:**

**What the consultation session is:**

The interactive consultation session is a back-and-forth dialogue between the user and the Review Agent concerning a specific finding or Report — for example, "explain why you flagged this pattern" or "suggest an alternative wording for this System Prompt improvement." It is not a Persona Conversation in the product sense: it has no Persona, it does not appear in the Conversations list, and it must not be persisted across navigation events. It is a transient, single-page-lifecycle artefact.

The session has a natural scope: it is created when the user opens the Persona review page (or clicks into a specific finding), and it ends when the user navigates away. The product explicitly does not want it to persist (FR-16.3).

**The three storage options:**

**Option A — Browser-only (frontend state, no backend session)**

The consultation session exists entirely in the browser. The frontend maintains the message history in component state (e.g. React `useState` or a Zustand store scoped to the page component). Each user message is sent to a stateless backend endpoint that:
1. Receives the full message history from the frontend on each request.
2. Calls the configured LLM with the full context.
3. Returns the response.

The frontend accumulates the history. On navigation away, the component unmounts and the state is discarded. No backend session is ever created.

*Advantages:* The ephemerality is guaranteed by the component lifecycle — there is nothing to explicitly garbage-collect on the backend. No backend session table, no TTL logic, no cleanup job. The "discarded on navigation" requirement is enforced architecturally rather than by policy.

*Disadvantages:* The full message history must be sent on every request. For a multi-turn consultation (5–10 exchanges), this is a modest token overhead but is not a practical problem. If the user's browser tab crashes or is closed, the session is irrecoverably gone — but this is the desired behaviour (FR-16.3). The backend endpoint cannot distinguish a "new consultation" from a "continuation" — it always reconstructs context from the payload.

This is the pattern used by chat playground UIs (OpenAI Playground, Anthropic Console) where sessions are browser-local and stateless on the backend.

**Option B — Server-side in-process session keyed by session token**

The frontend receives a `consultation_session_id` (UUID) when the Persona review page opens. The backend stores the message history for that `consultation_session_id` in a server-side in-process dict (not persisted to the DB). On each user message, the frontend sends only the new message; the backend appends to its in-process history and calls the LLM. On navigation away, the frontend calls a `DELETE /consultation-sessions/{id}` endpoint to clean up the backend state. A background TTL sweeper discards any sessions not explicitly cleaned up (handles browser crashes).

*Advantages:* Minimal per-request payload (only the new message, not the full history). The backend manages context window construction.

*Disadvantages:* Requires explicit cleanup coordination between frontend and backend. Browser navigation events (`beforeunload`, `pagehide`) are unreliable — the DELETE call may not fire if the tab is killed. A TTL sweeper is needed as a safety net, adding operational complexity. The in-process dict is lost on server restart, leaving no ability to recover a session (again the desired behaviour, but the frontend must handle the 404 case gracefully). In a multi-process deployment, the session is tied to one backend process — this is not a V1 concern but is a future scaling constraint.

**Option C — Short-lived DB-backed session with TTL**

The consultation session is stored in the database in a `consultation_sessions` table with a `expires_at` column. Session rows older than TTL (e.g. 15 minutes of inactivity) are hard-deleted by a background job. The frontend sends a `consultation_session_id` with each request; the backend loads the history from DB, appends the new message, calls the LLM, and writes the updated history back.

*Advantages:* Survives server restarts. Works in multi-process deployments.

*Disadvantages:* Adds a DB table for data that is explicitly intended to be ephemeral. The TTL sweeper adds operational complexity. Every message turn triggers a DB read and write. The DB writes create a risk of the data being retained longer than intended (e.g. if the TTL sweeper has a bug). This is the heaviest option for what is deliberately the lightest interaction in the product.

**Comparison:**

| Approach | Persistence risk | Complexity | Restart safety | Multi-process safe |
| --- | --- | --- | --- | --- |
| Browser-only (A) | None — component lifecycle | Minimal | N/A | N/A |
| In-process session (B) | Low — TTL sweeper mitigates | Medium | Lost on restart (correct) | No (V1 acceptable) |
| DB-backed TTL session (C) | Low-medium — sweeper required | High | Survives restart | Yes |

**Recommended approach: Option A — browser-only session, stateless backend endpoint**

The browser-only approach is the cleanest expression of the requirement. The ephemerality is a structural property, not a policy enforced by cleanup code. The payload overhead (sending the full history on each turn) is acceptable for the expected volume of turns in a consultation session (the per-message context is small compared to a Persona Conversation with many messages and an attached System Prompt).

The backend exposes a single endpoint:

```text
POST /workspaces/{workspace_id}/review-agent/consult
```

Request body:

```json
{
  "finding_id": "uuid",
  "persona_id": "uuid",
  "history": [
    {"role": "user", "content": "..."},
    {"role": "assistant", "content": "..."}
  ],
  "new_message": "..."
}
```

The backend:
1. Loads the `review_agent_findings` row for `finding_id` (for context: the finding text, evidence message IDs, Persona system prompt).
2. Constructs the LLM prompt: system context (the finding, the Persona's current system prompt) + `history` + `new_message`.
3. Calls the configured LLM (via the model abstraction layer).
4. Returns the assistant response.

The endpoint is idempotent (stateless on the backend). The frontend appends the returned response to its local history and sends the updated history on the next turn.

**Frontend lifecycle binding:**

The frontend component that renders the consultation session initialises an empty `history` array when it mounts. When it unmounts (navigation away, route change), React's cleanup runs and the state is discarded. No explicit API call is needed. The frontend framework's component lifecycle is the "session manager."

For frameworks without component unmount semantics (e.g. a server-rendered MPA), the equivalent is: the session history lives in a scoped JS variable tied to the page's lifetime. On `pagehide` or route change, the variable goes out of scope.

**Preventing accidental persistence:**

Three properties prevent accidental persistence:

1. The backend endpoint is stateless — it writes nothing to the DB for this session. There is no backend state to accidentally persist.
2. The `history` field in the request is client-provided and is never echoed back to the DB. The backend only reads `finding_id` / `persona_id` from the DB (as context), never writes the consultation turn to it.
3. The `review_agent_findings` table (RQ-E7) records the outcome of the Review Agent's analysis, not the interactive consultation. If the user accepts a suggestion from the consultation, the acceptance action writes to the DB explicitly (updating the finding's `status` to `applied` and updating the Persona's system prompt) — this is a deliberate action, not an ambient persistence of the conversation.

**Handling mid-consultation LLM streaming:**

If the consultation response is streamed (via SSE, per RQ-G2), the stream is tied to the HTTP response for that single POST request. The frontend accumulates the streamed tokens and appends the completed response to its local history. If the user navigates away during streaming, the component unmounts, the frontend stops listening to the SSE stream, and the in-flight HTTP request is abandoned (the browser closes the connection). The backend's LLM call receives `ConnectionResetError` or `CancelledError` (if the ASGI server cancels the request coroutine) and discards the partial response. Nothing is written to the DB.

**What about long consultation sessions (many turns)?**

If a user conducts a very long consultation (e.g. 20+ turns), the `history` payload grows. This is acceptable within reason — 20 turns of short messages is well within typical LLM context windows. If context window limits become a concern, the frontend can implement a sliding window (trim the oldest turns from the payload before sending). This is a frontend UX concern, not a backend architectural decision. The backend does not enforce a maximum history length — it passes the history to the LLM and lets the model's context limit be the constraint.

*Infrastructure as Configuration check:* No violation. The stateless endpoint uses the same model abstraction interface as all other LLM calls. No new backend state or infrastructure component is introduced.

*Cross-references:*
- RQ-E7: `review_agent_findings` is the source of context for the consultation — the endpoint loads the finding row to populate the LLM system context, but does not write to it during the consultation (only on acceptance).
- RQ-G2: SSE is the transport for streaming consultation responses, consistent with all other streaming LLM responses in the system.
- RQ-G3: The consultation endpoint does not gate on Conversation idle state — it is a separate interaction not tied to a Conversation's lifecycle. No idle flag check is needed.
- RQ-I11: Idle-state gating applies to live Conversations; the consultation session is not a Conversation and does not interact with the per-Conversation lock.

---

## Out-of-Scope for This Research Phase

The following are explicitly out of scope for the research agent and must not be answered here — they are decisions for the developer during decision facilitation:

- Choice of specific framework, library, database, or language. Research should surface candidates with tradeoffs, not pick one.
- Values for Open Questions OQ-01 through OQ-07 in the user requirements. Those are product-side defaults, not architectural research.
- UI layout or visual design choices.
- Implementation task ordering or delivery plans.

---

## Handoff

This document is the output of the research phase of the Head of Development cycle. It is to be handed to a research agent. The research agent should return findings grouped by the same RQ IDs used above, presenting candidates and tradeoffs without recommending a single answer. Once research findings are received, the Head of Development will return to decision facilitation, presenting options to the developer for each Architectural Flag and recording each resolved decision as an ADR in `documentation/decisions/architecture-decisions.md`.
