# Overview Review

Fourth review pass — conducted against the live text of `documentation/project/overview.md` dated 2026-04-10.

---

## Contradictions

- **Persona deletion vs. active Conversation definition (Sections 4.2 and 5.2).** Section 4.2 states a Persona "cannot be deleted while it is active in an open Conversation" and defines active as "added as a participant and that Conversation has not yet been ended." Section 5.2 states the minimum number of active Personas in a Conversation is one and that a user can remove Personas mid-Conversation. If a Persona has been removed mid-Conversation but that Conversation is still open, can it be deleted? The document does not address this edge case — the Persona is no longer a participant but the Conversation is not yet ended. The two sections appear to use "active in a Conversation" differently.

- **Snapshot refresh in Round-Robin: cycle vs. message (Section 5.6).** The general rule for snapshot refresh is "the refresh applies from the next message onwards." The Round-Robin-specific rule is "the refreshed snapshot takes effect from the start of the next cycle." These are inconsistent with each other. It is not clear whether the Round-Robin rule is an override of the general rule or a clarification — but in the scenario where the refresh is applied mid-cycle, the general rule says it applies to the next message (possibly still within the current cycle) while the Round-Robin rule says it waits until the next cycle. The document should state which rule takes precedence, or make clear that the Round-Robin rule always governs in Round-Robin mode.

- **Review Agent run timing and skip logic (Section 7.2).** The document states "it processes all Conversations that concluded since its last run." It also states "if no Conversations have concluded since the last run, the Review Agent skips." However, it separately notes the Mentor Conversation is reviewed "on an ongoing basis — analysing the most recent activity since its last review" and is skipped only "if the Mentor Conversation has had no new activity since the last run." These two skip conditions are evaluated independently, yet the document presents them as part of the same run. If standard Conversations have nothing new but the Mentor does have new activity, does the run proceed (for the Mentor only) or is it skipped? The skip logic is ambiguous when applied to the combined batch.

---

## Missing information

- **`@Orchestrator` syntax in Peer-to-Peer mode (Sections 5.3, 5.4, 6.3).** The `@Orchestrator` mention is described as the mechanism for targeted summaries and direct interaction. In Peer-to-Peer mode the Orchestrator is also managing turn routing. The document does not clarify whether an `@Orchestrator` message during a P2P session pauses the autonomous Persona exchange, or how the system distinguishes a user `@Orchestrator` message from the natural flow of Persona-to-Persona turns.

- **Workspace switching while a P2P session is in progress (Section 5.5).** Section 5.5 addresses Workspace switching for standard Conversations (the in-progress response completes in the background). Peer-to-Peer mode may have multiple in-flight Persona turns simultaneously, or a sustained autonomous exchange. The document does not address what happens to a P2P session when the user switches Workspace — does the autonomous exchange continue in the background, pause, or stop?

- **Report linking after source Conversation deletion (Section 6.4).** Section 6.4 states each Report is "linked back to its source Conversation." Section 3.2 states that deleting a Conversation does not delete Review Agent findings. However, the document does not explicitly state what happens to Reports (or their links) when the source Conversation is deleted. Section 6.6 discusses deleting Reports but not deleting Conversations. Does the Report remain in the Documents area with a broken or absent link? Does the link simply show the Conversation title without navigation?

- **Chapter boundary behaviour when user is mid-message (Section 8.4).** The document describes the chapter prompt as appearing "if the user returns to the Mentor Conversation on a different calendar day." It does not specify when during the session-start flow this prompt appears — before the user can type, or only when the user sends their first message. This affects the UI flow.

- **Folder ordering within the Discussions sidebar (Section 3.1).** Section 3.1 states "Within the Folders section, items are ordered by most recent activity (most recent first)" but it is not clear whether "items" refers to the Folders themselves (ordered by the most recent activity of any Conversation within each Folder) or the Conversations within an expanded Folder. The sentence is ambiguous and could be read both ways.

- **Persona removal during an in-flight response (Sections 5.2 and 5.5).** Section 5.2 states changes take effect "at the next natural break" and the current turn or cycle completes first. Section 5.5 addresses in-flight responses specifically for the End Conversation action. The document does not separately clarify whether removing a Persona mid-cycle while a response from that exact Persona is in flight follows the same "complete then remove" rule, or whether some immediate interruption is possible.

- **Manual Review Agent run scope when Mentor is unconfigured (Section 7.2).** The document states a manual run covers "all Personas in the Workspace, equivalent to the nightly batch." If the Mentor has not yet been created, the document does not say whether the Review Agent silently skips the Mentor slot or whether its absence is surfaced in any way.

- **Conversation naming on first summarisation — targeted summary triggered by user mid-conversation (Sections 3.2 and 6.3).** Section 3.2 states auto-naming triggers on "first summarisation — whichever comes first: automatic context compression or the first user-requested targeted summary." If a targeted summary is requested very early in a Conversation (e.g., after just two messages), the auto-generated name may be based on very little content. The document does not state whether there is a minimum message count or content threshold before auto-naming triggers, or whether the trigger is truly unconditional.

---

## Undocumented edge cases

- **Ending a Conversation in P2P mode while Personas are in an autonomous exchange.** Section 6.1 states the in-flight response completes before the end-of-conversation flow begins. In P2P mode there may be a chain of queued or autonomous Persona responses, not just a single in-flight response. It is unclear whether all queued P2P turns complete before ending, only the current in-flight one, or whether the autonomous exchange is interrupted after the current response.

- **Applying a Review Agent finding that conflicts with the Persona's existing System Prompt.** Section 7.3 describes 1-click Apply as immediately updating the live System Prompt. If the suggested change is logically contradictory with an existing instruction in the System Prompt (e.g., the current prompt says "always be brief" and the finding suggests "provide detailed analysis"), the document does not indicate whether the system warns the user of potential conflicts or applies the change blindly.

- **Multiple Reports in progress simultaneously (Section 6.4).** The document states multiple Reports can be generated from the same Conversation. It does not address whether a second Report generation can be triggered while the first is still being generated — whether concurrent Report generation is permitted or blocked.

- **Context Panel content that references Conversation content dropped from context window (Section 5.3).** The Context Panel is user-managed and the document explicitly states it is "the last element to be evicted." However, if the user copies text from an old Conversation message into the Context Panel and that original message has been dropped from context, the Context Panel text still references context the Personas cannot see directly. This is not a system error but it is an undocumented user experience gap — there is no guidance or warning for this scenario.

- **Chapters in the Mentor and the Review Agent's session definition (Sections 7.2 and 8.4).** The Review Agent is described as analysing "the most recent activity since its last review" for the Mentor. If the user creates multiple chapters within a single calendar day (by manually triggering chapter boundaries), does each chapter constitute a separate session for Review Agent purposes, or is the unit of analysis time-based regardless of chapter boundaries?

- **Exporting an active Conversation that is mid-response (Section 6.5).** The document states a user can export any Conversation "at any time." It does not address whether an export triggered while a Persona response is being generated includes the partial in-flight message or only completed messages.

---

## Ambiguities

- **"Most recent activity" ordering — what qualifies as activity (Sections 3.1 and 3.2).** The sidebar orders Conversations by "most recent activity (most recent first)." The document does not define what constitutes activity — is it the timestamp of the last message sent or received, the last time the Conversation was opened by the user, a snapshot refresh, or a Persona join/leave event? This distinction matters for ordering correctness.

- **The Orchestrator's role in P2P mode — single component or dual function (Sections 5.2 and 5.4).** Section 5.4 describes the Orchestrator as a background process whose "primary user-facing responsibility is to suggest additional Personas." Section 5.2 (P2P) states the Orchestrator "throttles the exchange to prevent runaway loops" and Section 5.4 notes it "may also take on a behind-the-scenes role in managing the routing and pacing." The document hedges this with a research note. This creates ambiguity about whether P2P turn management is part of the Orchestrator or a separate mechanism — the requirements and stories cannot be written with full precision until this is resolved. The P2P note in Section 5.2 is already flagged as "subject to ongoing technical research," but the Orchestrator's dual role in P2P (suggestion + turn management) is a product scope question distinct from the technical implementation question.

- **Semantics of "dismissed" Review Agent findings across runs (Section 7.3).** Section 7.3 states the Review Agent "treats [a dismissal] as a deliberate user preference and will not immediately resurface the same type of suggestion" but "if the same issue continues to appear strongly across subsequent Conversations, the Review Agent may raise it again." The word "immediately" and the phrase "continues to appear strongly" are undefined. From the user's perspective it is unclear what the suppression period is, how many subsequent Conversations constitute "strongly," or what user-visible feedback (if any) indicates a previously dismissed finding is being re-evaluated. This ambiguity will produce imprecise acceptance criteria.

- **Pinned Conversation inside a Folder — ordering within the Folder's list (Sections 3.1 and 3.2).** Section 3.1 states Standalone Pinned Conversations are "ordered by pin date — oldest pin first." Section 3.2 states a pinned Conversation inside a Folder is "pinned to the top of the Folder's Conversation list." If multiple Conversations within the same Folder are pinned, the document does not state what order they appear in at the top of the Folder's list — is it also oldest-pin-first, or most-recently-pinned first, or some other order?

- **Persona addition prompt on 1:1 → Round-Robin switch via Orchestrator (Section 5.2).** The document states that accepting an Orchestrator suggestion in a 1:1 Conversation "triggers" a switch to Round-Robin and "Round-Robin mode is assumed." It is not stated whether this is automatic (the mode switches immediately upon confirming the Persona addition) or whether the user is shown a separate mode-change confirmation step after confirming the Persona addition. This is a distinct UX question from whether to add the Persona.

- **Episodic Memory window eviction — what happens to facts that exist only in the oldest entry (Sections 8.5 and 8.6).** The document states "when a new session is summarised and the window is full, the oldest episodic entry is retired." It does not state whether the retirement process checks whether facts from the oldest entry have been promoted to Semantic Memory before evicting. If a significant decision is only present in the oldest episodic entry and has not been extracted to Semantic Memory, it silently disappears. The document does not clarify whether the compression step that creates Episodic Memory also extracts Semantic facts, or whether those are separate operations — which affects whether silent fact loss is possible.
