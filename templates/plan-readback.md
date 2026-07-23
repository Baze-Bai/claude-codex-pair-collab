<!-- ENGINE-FILLED (Phase 3 readback — both sides in parallel, each fills once).
     Placeholders: COLLAB_DIR, OUT_FILE. The finalize was authored by the PENNER
     (a worker, not O); the readback audits the penner's carry fidelity. On PASS the
     engine appends both CONSENSUS lines verbatim to 30_PLAN.md as the sign-off. -->
The consensus has been finalized into {{COLLAB_DIR}}/30_PLAN.md and {{COLLAB_DIR}}/31_TASKS.md by the **finalize penner** (the engineer who wrote the last fusion draft) under a carry-don't-regenerate contract: fusion draft as body, later confirmed additions appended with attribution, process markers settled per the dispute ledger, risks carried verbatim. O added nothing beyond mechanics.

**Read both documents IN FULL** (not just your own slice) and check four questions:

1. **Omission** — is anything that was agreed (in the fusion draft, in accepted supplements, in later confirmed additions) missing from PLAN/TASKS?
2. **Compression** — were agreed **acceptance criteria / DoD constraints** summarized into a one-liner that drops substance? (PLAN/TASKS are the implementation basis; the implementer will not re-read review files to recover them.)
3. **Addition** — does anything appear that was **never consensused**? (Especially: a task owner or implementation mode written as settled — those are undecided execution decisions pending user approval; and any penner preference smuggled in as a settled decision.)
4. **New blocking risks** — and are the residual risks from AGREE credentials carried verbatim, one per line, **unmerged** (two risks pointing at different failure modes merge into falsehood)?

Perspectives differ by role and both matter: if you are the **second mover** (not the penner), your accepted supplements and positions are the likeliest omission victims, and you are the natural adversarial checker for additions — check both hard (battle lesson: the non-author side historically rubber-stamps; do not). If you are the **penner**, verify the mechanical carry of your own constraints (nothing lost in integration or splitting) and re-check your DoD completeness with fresh eyes.

Name **specific items** when objecting; a clean pass also needs credentials. No DISPUTES line in this task (drift routes through OBJECT → the fix loop, not the ledger). End with a single line:
`CONSENSUS: OBJECT — <which specific spot was omitted / compressed / added / which new blocking risk>`
or
`CONSENSUS: AGREE — residual-risk: <...>; dropped-objection: <...>`

Delivery & write scope: the deliverable lands at {{OUT_FILE}} — your ONLY legitimate write target this round; the rest of the repo is read-only to you this round. If you are CA, write that file yourself and give O a one-line summary in your reply. If you are CB, you write no files (your sandbox enforces this): your final reply body IS the deliverable — it will be saved as that file; no appended questions or pleasantries.
