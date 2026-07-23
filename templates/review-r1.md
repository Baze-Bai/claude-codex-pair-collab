<!-- ENGINE-FILLED (Phase 2 r1, blind symmetric cross-review — both sides at once,
     neither sees the other's review). Placeholders: COLLAB_DIR, PEER_PROPOSAL,
     OWN_PROPOSAL, OUT_FILE. One template, filled once per side. -->
Review round 1 (blind): independently review the counterpart's original proposal; neither side sees the other's review first. Your role is **quality inspector, not debater**.

Stance: a review with no findings = a job not done; your value this round is finding the counterpart's omissions / errors / better alternatives, not concurring. Also call out dimensions they left out **wholesale** (failure paths / rollback & recovery / concurrency races / scale ceilings / security & auth / data migration & backward compatibility / observability are the usual silent zones). Do the deep audit in round 1 so problems surface early. **Finding faults ≠ objecting for its own sake**: raise only substantive issues (ones whose adoption would actually change the plan or the task split); padding the review with trivial nitpicks is equally a job not done. If, after honest scrutiny, the proposal stands, an AGREE with credentials is equally diligent output — diligence lives in the review body and the supplement ledger, not in whether the verdict is an objection.

Materials (always read the files on disk — no relayed summaries):
- Brief: {{COLLAB_DIR}}/00_TOPIC.md
- Counterpart's proposal: {{PEER_PROPOSAL}}
- Your own proposal (for contrast): {{OWN_PROPOSAL}}

Review contract:
- Respond point-by-point to the counterpart's points (agree / object / amend).
- **Supplement ledger** — one table: `| # | peer's gap/defect | severity | what I add |`. "What I add" must be at the proposal's altitude or finer: if the proposal names files/interfaces, so does your fix; if it is still design-level, land on module/interface-contract/design-decision and note where it belongs. **If unsure of the location, say "TBD" — never invent a plausible-looking filename; fake precision is worse than coarse precision.** The one hard bar: each row must be directly convertible into a 31_TASKS.md line that you could later accept or reject at review.
- **Evidence anchors**: key claims about current code behavior carry file:line; spot-check the counterpart's anchors and name any that are false — confident false premises are a shared LLM blind spot, and anchors make them cheaply falsifiable.
- **Evidence first**: any point decidable by a read-only experiment (existing targeted tests, a small probe) — run it and attach the command + output as new fact; evidence beats argument.
- Machine-readable dispute declarations, one line starting exactly with `DISPUTES: ` (directly above your CONSENSUS line):
  - `DISPUTES: none` if you raise nothing and no ledger entries concern you;
  - otherwise items separated by `; `, each one of:
    - `new="one-line summary"` — a new dispute you raise this round (the engine assigns its id; no `|` or `;` characters inside the text);
    - later rounds may also use `dN=open | dN=addressed | dN=confirm-closed | dN=withdrawn` against ids in {{COLLAB_DIR}}/25_disputes.md — authority is enforced mechanically: only a dispute's proposer can confirm-close or withdraw it; only the other side can mark it addressed.
  Every `new=` item must correspond to a substantive point argued in your review body.
- End with a single line (a bare AGREE is malformed):
  `CONSENSUS: OBJECT — <one sentence: the substantive disagreement (adopting it would actually change the plan or the task split)>`
  or
  `CONSENSUS: AGREE — residual-risk: <the one thing you still fear most even if this plan is adopted; if truly none, say why>; dropped-objection: <the strongest objection you considered but chose not to press>`

r1 produces no fusion draft.

Delivery & write scope: the deliverable lands at {{OUT_FILE}} — your ONLY legitimate write target this round; the rest of the repo is read-only to you this round. If you are CA, write that file yourself and give O a one-line summary in your reply. If you are CB, you write no files (your sandbox enforces this): your final reply body IS the deliverable — it will be saved as that file; no appended questions or pleasantries.
