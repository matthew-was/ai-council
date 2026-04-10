**AI Council: Design Brainstorm Summary**

Prepared for the Product Owner

April 2026

# **Purpose of This Document**

This document summarises a product brainstorming session exploring alternative use cases and architectural extensions for the AI Council system. It is intended as a design input for the Product Owner to consider alongside the existing System Overview, identifying new directions worth exploring and flagging architectural decisions that should be made now in order not to foreclose future possibilities.

# **1\. Reframing the Core Value Proposition**

The brainstorming session began by questioning what makes AI Council distinctive. The conclusion reached was that its core value is not simply simulating advisory characters, but enabling a participant-centred practice environment. Until AI, this kind of practice was difficult to achieve: you could observe simulations (war games, case studies) but you could not easily be inside them with realistic interlocutors.

This reframing surfaces the system’s real differentiator: you are not watching the council deliberate — you are in the room with them, subject to the same pressures and dynamics you would face in reality.

## **The Observer–Participant Axis**

A useful framework emerged from the discussion. Rather than thinking of use cases as a simple spectrum from “war gaming” to “RPG”, it is more precise to map them across two independent axes:

* Observer vs. Participant: Is the user watching the simulation play out, or are they inside it as an active agent?

* Rational vs. Emotional: Are the Personas operating as logical actors with defined objectives, or as characters with personalities, histories, and emotional states?

AI Council as currently designed sits at Participant \+ Rational — the user is inside the council, and the Personas behave as logical advisory voices. This is a distinct quadrant from war gaming (Observer \+ Rational) and RPG (Participant \+ Emotional).

The other quadrants are reachable with the same underlying architecture, but serve different use cases and would require different Persona design patterns and memory schemas.

# **2\. Use Case Exploration**

## **2.1 Strategic War Gaming (Command Practice)**

A war gaming mode was explored, but reframed away from the observer model typical in existing war game tools. In AI Council, a war gaming use case would be participant-centred: the user practises how to command different Personas, or how to respond when a Persona is commanding them.

This is fundamentally about practising influence and authority dynamics — how you direct people with different priorities, how you respond to challenge, how you navigate a room where not everyone is aligned with your objective.

The Persona design for this mode would emphasise defined objectives and information asymmetries. Personas are rational actors with positions to defend, not just advisory voices offering perspective.

## **2.2 RPG and Game Master Practice**

The system architecture maps naturally onto an RPG context: the Mentor becomes the Game Master holding world state and narrative arc, while Personas become NPCs or player characters. A user who cannot find a Game Master, or a Game Master who wants to rehearse scenarios with simulated players, could use the system in this mode.

The critical design difference in RPG mode is that the Orchestrator must be invisible — breaking the fiction destroys the experience. In advisory or war gaming modes, the Orchestrator can surface its logic transparently; in RPG mode it must operate entirely behind the scenes.

Persona relationships in RPG mode are also qualitatively different: they are personal and evolving, not just defined by interest and incentive. An NPC Persona might like your character while opposing them, and that tension needs to be tracked and expressed over time.

## **2.3 The Common Thread: Practice Through Participation**

All three use cases — advisory council, command practice, RPG — share the same underlying mechanic: the user practises how they interact with other Personas in a given context in order to achieve a goal. The system is a participation engine, not a simulation viewer. This framing should inform how the system is described and positioned.

# **3\. The Game World Concept and Shared Persona Memory**

## **3.1 The Architectural Gap**

Exploring the RPG and war gaming use cases exposed a gap in the current design: the system has no concept of shared state between Personas. Each Persona currently knows only what is in the conversation history. For more complex use cases — and arguably even for the core advisory use case — there is value in Personas having persistent memory of past interactions, established positions, and decisions that have been made.

In an RPG context, this is called a “game world” document: a persistent shared context that all Personas can reference. In the advisory context, it is better described as shared institutional knowledge: what has been decided, what positions each Persona has taken, what the user has committed to.

## **3.2 Canonical vs. Non-Canonical Memory**

A critical insight from the session is that persistent memory must be intentional, not automatic. The primary use case for AI Council is practice: the user wants to try an idea, see how it lands, and try a different approach. If Personas automatically remembered every conversation, a failed rehearsal would pollute their context and affect future sessions.

The proposed mechanic is canonical vs. non-canonical memory:

* During a conversation, Personas engage fully, drawing on their current memory and the conversation history as it builds.

* At the end of a conversation, when the summary is produced, the user is offered a single choice: “Save the memory of this conversation for the participants.”

* If the user confirms, the conversation becomes canonical and its key outcomes are added to the Personas’ persistent memory. If not, the conversation is a rehearsal and nothing persists beyond it.

This is consistent with the existing design philosophy of the Context Panel, where nothing persists without a deliberate user act.

## **3.3 Conversation Snapshots**

A related question is what version of a Persona is active during a conversation. The recommended approach is to snapshot the Persona at conversation start: the Persona the user begins a conversation with is the Persona they finish with, regardless of any edits made elsewhere during that time.

This has several benefits: conversations are stable and self-contained; concluded conversations are reproducible; and there is no need to lock Personas across all active conversations just because one is running.

If the live Persona is updated during a conversation by another route (e.g. the Review Agent applies a recommendation), a merge is required at canonisation time. Because Persona prompts are natural language rather than code, this merge is LLM-tractable: the LLM can resolve semantic equivalences and produce a coherent merged prompt without the precision conflicts that make code merges difficult.

# **4\. Persona Memory Architecture**

## **4.1 Two-Layer Memory for Personas**

The Mentor already uses a three-layer memory system (Working, Episodic, Semantic). For standard Personas, a simpler two-layer system is proposed:

* Episodic Store: An append-only, timestamped record of canonised conversation summaries. Each entry captures what was established in that conversation for this Persona. The store is shallow — a small number of recent entries, not a full history.

* Semantic Document: A structured Markdown document synthesised from the episodic store. This is what actually gets included in context when the Persona responds. It is regenerated each time a new episode is added.

The episodic store is the source of truth. The semantic document is the working representation, optimised for context window efficiency.

## **4.2 Forgetting as a Feature**

The episodic store is time-stamped and has a fixed window size. Older entries age out as new ones accumulate. This is intentional: Personas that remember everything equally are unrealistic, and persistent stale memory degrades rather than improves their usefulness.

Controlled forgetting also makes the memory self-correcting. If the user tells the system that a Persona is acting on an incorrect assumption, a correction episode is added to the store. Because it is newer, it is weighted more heavily in the semantic synthesis. Eventually the incorrect episode ages out of the window entirely. No special “delete memory” interface is needed.

## **4.3 Correction Mechanism**

When a user notices a Persona behaving incorrectly — acting as though X is true when in fact Y — they raise this through the Review Agent interface, exactly as they would for a prompt improvement. The Review Agent writes a correction episode to the episodic store, the semantic document is regenerated with the corrected information taking precedence, and the old incorrect memory ages out naturally over time.

This keeps the UX consistent: the Review Agent is the single surface through which all Persona changes — prompt improvements, memory additions, and memory corrections — are proposed and approved.

## **4.4 Mentor vs. Persona Memory Depth**

The Mentor requires deeper, broader memory than standard Personas. Its value is accumulated understanding of the user over time, which requires a longer episodic window and a richer semantic layer. Standard Personas are more context-specific and benefit from shallower, faster-forgetting memory: enough to feel coherent and consistent across recent sessions, but not so deep that they accumulate stale history that conflicts with the user’s current context.

## **4.5 Memory Visibility**

Persona memory should not be directly visible or editable by the user. Exposing raw memory invites over-engineering and creates a maintenance burden. Instead, the Review Agent surfaces the effects of memory through its proposed changes, and users correct problems by interacting with the Review Agent rather than editing memory directly. The memory inspector pattern used by the Mentor (read-only transparency) could be considered for Personas in a future version if trust becomes an issue.

# **5\. Implications for the Review Agent**

The introduction of Persona memory extends the Review Agent’s responsibilities beyond prompt refinement. It now has three distinct jobs:

* Prompt improvement (existing): Analysing concluded conversations and surfacing suggestions for how a Persona’s System Prompt could be refined to improve future performance.

* Memory canonisation (new): At the end of a conversation the user chooses to canonise, the Review Agent processes the conversation summary and proposes what should be added to each participating Persona’s episodic store. This is an on-demand process triggered by canonisation, not part of the nightly batch.

* Memory correction (new): When the user reports a Persona acting on incorrect information, the Review Agent writes a correction episode to the store.

In all three cases the user experience is the same: the Review Agent proposes a change, and the user approves or dismisses it. The consistency of this pattern is important — users learn one mental model for how Persona changes happen.

# **6\. V1 Scoping and Architectural Constraints**

## **6.1 Persona Memory is a V2 Requirement**

Persistent Persona memory is not required for V1. The core advisory use case works without it: Personas draw on their System Prompts and the current conversation history, which is sufficient for single-session practice. Memory becomes important when the user wants continuity across sessions — when Personas should “remember” what was decided last time.

However, the V1 architecture must not close the door on adding memory in V2. The following constraints should be observed during V1 development:

## **6.2 Data Model Constraints for Forward Compatibility**

The Persona data model should treat the System Prompt as one of potentially several context documents, not as the single definition of the Persona. Concretely:

* The Persona record should have a relationship to one or more typed context documents, where “system\_prompt” is one type. Adding “semantic\_memory” as another type in V2 should be additive, not structural.

* The conversation snapshot mechanism should be designed to snapshot all context documents associated with a Persona, not just the System Prompt. Even in V1 when only the System Prompt exists, the snapshot mechanism should handle multiple document types so V2 does not require a rewrite.

* The Review Agent’s proposed change format should reference “a context document belonging to a Persona” rather than specifically “the System Prompt.” V1 only has one document type, but the pipeline is ready for more.

* Persona records should include a user\_id concept internally from day one, consistent with the multi-user forward compatibility requirement already noted in the System Overview.

## **6.3 Canonisation UI Placeholder**

The end-of-conversation summary screen should be designed to accommodate the canonisation option even if it is not functional in V1. This avoids a disruptive UI change when the feature is introduced in V2 and signals the intended future behaviour to early users.

# **7\. Open Questions for the Product Owner**

The following questions were not fully resolved during the brainstorming session and are flagged for consideration:

* Use case priority: Should the V2 roadmap prioritise deepening the advisory council use case (Persona memory, richer Orchestrator behaviour), or should it invest in enabling adjacent use cases (command practice, RPG mode)? These have different architectural implications.

* Episodic window size: How many canonised episodes should a standard Persona retain before older ones age out? This is a configurable parameter but the default matters for user experience. Too few and Personas feel amnesiac; too many and stale context accumulates.

* Canonisation granularity: Should canonisation apply to all Personas in a conversation at once, or should the user be able to select which Personas’ memories are updated? The latter offers more control but adds friction.

* Semantic synthesis timing: Should the semantic document be regenerated immediately on canonisation, or as part of the next nightly Review Agent run? Immediate regeneration means the Persona is updated before the next conversation; deferred means a lag but better batching.

* Observer mode: Is there value in an explicit observer mode — where the user sets up a scenario and watches Personas interact without participating — as a distinct feature? This was not explored in depth but is implied by the framework.

*This document was produced from a product brainstorming session in April 2026\. It is a design input, not a specification. All proposals are subject to review and refinement by the Product Owner and Head of Development.*