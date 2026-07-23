<!-- ENGINE-FILLED (Phase 2 r2+, convergence round, PENNER side — goes first; the
     second mover follows after this lands). Placeholders: N, COLLAB_DIR,
     REVIEW_FILES, OUT_FILE. Penner derivation: r2=CB anchor, alternating parity. -->
Review round {{N}} (convergence) — you are this round's **penner**: you write the fusion draft. Your role is **quality inspector, not debater**. This round converges existing disputes first; genuinely new findings are welcome in any round (a new discovery is yield, not noise) — but do not hunt for problems to fill a quota: discoveries should be by-products of honest scrutiny.

Materials (always read the files on disk — no relayed summaries):
- Both original proposals: {{COLLAB_DIR}}/10_claude_proposal.md, {{COLLAB_DIR}}/11_codex_proposal.md
- All reviews to date (incl. supplement ledgers): {{REVIEW_FILES}}
- Dispute ledger: {{COLLAB_DIR}}/25_disputes.md (cite disputes by id; a resolved dispute may not be reopened without new facts; **dispute identity**: the substance under one id must not be swapped — if your dissatisfaction has moved to a different thing, raise a new dispute instead of extending the old id's life)

## Fusion draft (your duty; write it as the FIRST section of your review file, headed "## Fusion draft")
From both original proposals and all reviews to date (incl. supplement ledgers), produce the version that beats both inputs — take each side's strengths, fill each side's gaps; this is not splitting the difference. Real conflicts stay as OBJECT; mushy compromise that papers over a genuine conflict is forbidden. Tag every element with its **source** (from-CA / from-CB / supplement-new) so "true fusion vs copying one side" stays auditable. Marking a dispute "handled per X" makes it *addressed, pending confirmation* — resolution belongs to its proposer (declare `dN=addressed` in your DISPUTES line).

**Write the draft in the target skeleton of `30_PLAN.md`** — at convergence this draft **IS the PLAN body**; the finalize penner only integrates later-round confirmed additions and de-processifies, and O never rewrites or adds substance. Skeleton: `## Background & goal` / `## Design` (decisions with source tags) / `## Acceptance criteria (DoD)` (complete fields, behavior boundaries, forbidden cases — written in full here; nothing downstream will expand them) / `## Risks` (carry residual risks verbatim, one per line, never merged) / `## Task table (draft)` (rows in 31_TASKS format: `| id | task | owner (pending user approval) | files | acceptance | test command |`). Write to final-deliverable quality: the later you leave a constraint, the likelier it is lost.

## Review contract (same as r1)
Respond point-by-point to open disputes and the latest counterpart review; supplement-ledger table `| # | peer's gap/defect | severity | what I add |` (same-altitude-or-finer precision, no fake filenames, every row convertible to a TASKS line); key claims about current code behavior carry file:line anchors and you spot-check the counterpart's; points decidable by read-only experiment — run it, attach command + output. Style preferences and tolerable concerns do not occupy OBJECT (put them in the body or your AGREE residual-risk slot).

Machine-readable dispute declarations, one line starting exactly with `DISPUTES: ` (directly above your CONSENSUS line): items separated by `; `, or `none`. Forms: `dN=open` (still unresolved from your side) / `dN=addressed` (you processed it; only valid if you are NOT its proposer) / `dN=confirm-closed` (you are the proposer and are satisfied) / `dN=withdrawn` (you are the proposer and retract — record why in your dropped-objection slot) / `new="one-line summary"` (engine assigns the id; no `|` or `;` inside). Authority is enforced mechanically; declarations must match what your review body actually argues.

End with a single line (a bare AGREE is malformed):
`CONSENSUS: OBJECT — <one sentence: the substantive disagreement (adopting it would actually change the plan or the task split)>`
or
`CONSENSUS: AGREE — residual-risk: <the one thing you still fear most even if this plan is adopted; if truly none, say why>; dropped-objection: <the strongest objection you considered but chose not to press>`

Delivery & write scope: the deliverable lands at {{OUT_FILE}} — your ONLY legitimate write target this round; the rest of the repo is read-only to you this round. If you are CA, write that file yourself and give O a one-line summary in your reply. If you are CB, you write no files (your sandbox enforces this): your final reply body IS the deliverable — it will be saved as that file; no appended questions or pleasantries.
