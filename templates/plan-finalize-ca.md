<!-- ENGINE-FILLED (Phase 3 finalize, penner = CA). Placeholders: COLLAB_DIR,
     FINAL_DRAFT_FILE, REVIEW_FILES, DRIFT_FILES. The penner — not O — writes the
     definitive PLAN/TASKS; O never holds the pen on consensus substance. -->
Consensus is reached. You are the **finalize penner**: produce the definitive {{COLLAB_DIR}}/30_PLAN.md and {{COLLAB_DIR}}/31_TASKS.md. O will not rewrite, summarize, or add substance — what you write is what the user approves and the implementer executes.

Inputs:
- Your final fusion draft (the base — you wrote it in the PLAN skeleton): the "## Fusion draft" section of {{FINAL_DRAFT_FILE}}
- All reviews (for later-round confirmed additions and AGREE credentials): {{REVIEW_FILES}}
- Dispute ledger — **the sole authority on dispute outcomes**: {{COLLAB_DIR}}/25_disputes.md
- Drift-fix input: {{DRIFT_FILES}} — if files are listed here, this is a repair pass: they contain readback objections (drift claims: omission / compression / addition). Repair by restoring omitted or compressed content from the sources and deleting un-consensused additions — not by rewriting healthy sections.

Rules:
1. **Carry, don't re-generate**: your fusion draft is the body; preserve its wording. Integrate later-round confirmed additions as clearly attributed appended items (e.g. "from CB r3 supplement #2"). Copying is fidelity; re-phrasing is the drift channel.
2. **De-processify**: remove worker-facing process markers ("addressed per X, awaiting confirmation"); ledger says closed-confirmed / closed-withdrawn / closed-ruled → write it as a settled decision. If the ledger still shows any open or pending-confirm dispute, STOP and report to O instead of finalizing.
3. **No compression of agreed acceptance criteria / DoD** — PLAN/TASKS are the implementation basis; the implementer will not re-read the review files to recover dropped constraints.
4. **No un-consensused additions** — your counterpart runs the readback with adversarial motivation and will catch smuggled content; especially: implementation mode and task owners are **undecided execution decisions pending user approval** — never write a default owner.
5. **Risks**: carry every residual-risk and dropped-objection from all AGREE credential slots into PLAN "## Risks" verbatim, one per line, never merged (two risks pointing at different failure modes merge into falsehood).
6. **Minimal background**: the one net-new text you may write is a short "## Background & goal" top-up so the user can read the PLAN standalone (the draft assumed readers who had read everything). Addition of context, not compression of substance.
7. **31_TASKS.md**: table `| id | task | owner (pending user approval) | files | acceptance | test command |`. Every accepted supplement-ledger row becomes a task row, carried without compression.

Delivery & write scope: write {{COLLAB_DIR}}/30_PLAN.md and {{COLLAB_DIR}}/31_TASKS.md directly — your ONLY legitimate write targets this round; the rest of the repo is read-only to you. Then give O a one-line summary in your reply. No CONSENSUS line needed (this is a deliverable, not a review).
