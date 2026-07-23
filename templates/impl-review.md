<!-- O-FILLED (Phase 5 full-diff audit dispatch — manual phase, not engine-driven in
     step 1; delete this comment block before sending). Single-owner default; in
     dual-track mode change the materials to the counterpart's file set.
     Auditor = the non-owner. CA: SendMessage relay; writes 50_claude_reviews_codex.md.
     CB: cb-round.sh resume <discussion-UUID> (read-only can run git diff), -o to
     51_codex_reviews_claude.md, with --require-consensus.
     Early-calibration audit reuses this template: narrow the scope to the first
     completed task's slice, focused on "is the PLAN being misread". -->
Implementation is complete. As the auditor, review **the entire diff**.

Scope and commands:
- Baseline SHA: {{BASELINE_SHA}} (see {{COLLAB_DIR}}/baseline.txt)
- `git diff {{BASELINE_SHA}} -- {{FILE_SET}}`
- Files the owner newly created (not in the diff; audit them too): {{NEW_FILES}}

Semantic baseline = {{COLLAB_DIR}}/30_PLAN.md + every passed amendment at its end. **Special check: self-consistent misreading** — the single-owner risk is that one mind wrote both sides of an interface, so a PLAN misreading stays consistent end-to-end and no test fails; recommended (not mandatory): first blind-read the PLAN and write down your expected interfaces/semantics, then open the diff and compare — reading the PLAN after seeing the implementation anchors you to the implementation.

Write scope this round: your ONLY legitimate write target is {{REVIEW_FILE}}; the rest of the repo is read-only to you — you point, you do not patch.

Requirements:
- Grade findings by severity (blocking / non-blocking), each with a stable number (#1...); substantive issues only, no performative fault-finding.
- Key claims carry file:line anchors; points decidable by read-only experiment — run it and attach the output.
- Fixes are executed by the owner; you point, you do not patch. Findings you raised are accepted/closed by you (from the second rejection on, you must state a verifiable closure criterion: same scope as the finding, self-provable within the owner's targeted tests, met = closed).
- Land/deliver {{REVIEW_FILE}}, ending with a single line (AGREE = no blocking issues, credentials still required):
  `CONSENSUS: OBJECT — <one sentence: which blocking issue remains unresolved>`
  or
  `CONSENSUS: AGREE — residual-risk: <...>; dropped-objection: <...>`
