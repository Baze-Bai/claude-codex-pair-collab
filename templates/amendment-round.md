<!-- O-FILLED (Phase 4 PLAN amendment deliberation — manual phase, not engine-driven in
     step 1; delete this comment block before sending). Send to the NON-owner side
     (CA via SendMessage relay of a prompt file / CB via cb-round.sh resume on the
     discussion session, with --require-consensus).
     Per amendment: ≤2 deliberation rounds (1 round = the amendment or its revision +
     the counterpart's one-line CONSENSUS); still OBJECT after 2 → O escalates to the user.
     If the amendment touches scope/acceptance criteria: at most 1 technical round, then
     straight to the user gate (note that here). -->
The owner has raised PLAN amendment {{AMENDMENT_ID}} during implementation (deliberation round {{K}} of max 2). Please deliberate.

Amendment text (with evidence; ledger entry {{AMENDMENT_ID}} in {{COLLAB_DIR}}/25_disputes.md):
{{AMENDMENT_TEXT}}

Deliberation points:
- Check the evidence: do the anchors / command outputs actually support "this PLAN assumption is overturned by reality"?
- Check the proposal: is it the minimal change; does it stay inside the frozen scope and acceptance criteria — if you judge that it actually moves scope/acceptance, say so explicitly (it then re-routes through the user gate).
- Substantive issues only; points decidable by read-only experiment — run it and attach the output.
- If you OBJECT, your "what change would make me agree" criterion is bound by three edges: ① **same scope** as this amendment (independent demands go to a new dispute line, not this amendment's rounds); ② **verifiable at deliberation time** (decidable at the text/interface-contract level, or provable by a read-only experiment; "implement it first and let me look" is not allowed); ③ **meeting the stated criterion closes it** — no appending conditions to the same amendment (new substance → new dispute; if you cannot state a verifiable criterion → O escalates to the user).

End with a single line:
`CONSENSUS: AGREE — residual-risk: <...>; dropped-objection: <...>`
or
`CONSENSUS: OBJECT — <substantive reason>; what change would make me agree: <verifiable criterion>` (required from the FIRST OBJECT)
