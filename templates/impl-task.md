<!-- O-FILLED (Phase 4 implementation dispatch — manual phase, not engine-driven in
     step 1; delete this comment block before sending).
     owner=CA: SendMessage relay; worklog=41_claude_worklog.md.
     owner=CB: first smoke the implementation session via
       cb-round.sh new <collab-dir> codex-p4-smoke workspace-write ... implementation
     (first prompt only asks CB to write one title line into 40_codex_worklog.md to
     verify file landing), then resume the implementation session with this template;
     worklog=40_codex_worklog.md. -->
The plan has user approval. You are this topic's implementation owner. Implement the tasks assigned to you per {{COLLAB_DIR}}/30_PLAN.md (**including every passed amendment under "## Amendments" at its end**) and {{COLLAB_DIR}}/31_TASKS.md: {{TASK_IDS}}.

Write scope for this phase: ONLY your assigned file set {{FILE_SET}} plus your worklog {{WORKLOG_FILE}}; everything else in the repo is read-only to you.

Hard constraints:
- No git add/commit/push; no installing or upgrading dependencies; do not commit — the worktree belongs to the integration phase.
- Run only your tasks' targeted tests (commands in the TASKS table); full-suite verification belongs to O's integration phase.
- Land the implementation log in {{WORKLOG_FILE}} (what was done / key decisions / targeted-test results) and give O a one-line summary in your reply.

**PLAN amendment procedure** (the only legitimate deviation channel; silent deviation is forbidden): if implementation reveals that a PLAN assumption is overturned by reality (a frozen interface was wrong, a dependency behaves differently than assumed, etc.) → pause the affected task and submit an amendment to O: the overturned PLAN item + evidence (file:line / targeted-test or probe output) + the minimal proposal. O relays it to the other side for deliberation (≤2 rounds per amendment); do not build on your proposal before it passes.
