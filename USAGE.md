# Usage Guide

**[中文 →](USAGE.zh-CN.md)**

This guide takes the **user's point of view**: how to install, how to start a topic, at which checkpoints you are needed, where the artifacts live, and how to recover from failures. The normative source for the protocol mechanics is [SKILL.md](SKILL.md) (in Chinese).

## 1. Prerequisites

| Component | Requirement |
|---|---|
| Claude Code | installed and working (this is a skill for it) |
| Codex CLI | `npm install -g @openai/codex`, logged in. The CLI shares `~/.codex` with the Codex desktop app — if the app is logged in, the CLI reuses that login |
| Bash | Claude Code must be able to run Bash (on Windows: Git Bash, bundled with Git for Windows) — Codex calls are driven via stdin through Bash; backgrounding them from PowerShell hangs forever on an unclosed stdin |
| Git repo | use it inside a git repository (baselines and diff review depend on git) |

## 2. Install

From your project root:

```bash
git clone https://github.com/Baze-Bai/claude-codex-pair-collab.git .claude/skills/pair-collab
```

Recommended: locally exclude the per-topic workspace so it never pollutes `git status`:

```bash
echo "collab/" >> .git/info/exclude
```

## 3. Start a topic

In a Claude Code session:

```
/pair-collab Add resumable export to the export service, keeping the existing REST contract
```

The more specific the topic (motivation, constraints, acceptance expectations), the better. If information is missing, the orchestrator asks you first, then starts.

The orchestrator will: create the `collab/<date>-<slug>/` workspace and tell you its path, spawn the Claude subagent (Engineer A), create the Codex session (Engineer B), and have both write proposals **in parallel and in isolation**.

**Scale note**: trivial single-function changes are not worth this protocol (two proposals + multi-round review has fixed overhead) — the orchestrator will say so and let you decide. For small tasks the artifacts shrink automatically (one-page proposals, merged PLAN/TASKS), but four things never shrink: the user approval gate, independent anti-anchoring proposals, CONSENSUS evidence, and the reviewer posture.

## 4. Where you are needed

The regular flow has exactly **two mandatory checkpoints**; the rest runs autonomously, and you can open the collab directory at any time to watch progress.

### Checkpoint 1: plan approval (Phase 3, always)

After the reviews converge you receive an approval package:

- `30_PLAN.md` (consensus plan) + `31_TASKS.md` (task table);
- a list of **"assumptions both sides share but never adversarially tested"** — the places where two AIs are most likely to fall into the same hole. **Review this list first**, not just whether the plan reads well;
- you are invited to **add or adjust acceptance items** (the final integration verification runs against them) — your chance to inject an outside perspective;
- the implementation split (who implements, who reviews) is also decided by you here — the orchestrator only recommends, never decides.

You can approve, reject, or attach change requests (they re-enter as *user adjudication* for a targeted convergence round, then come back for approval). **No code is touched before your approval.**

### Checkpoint 2: genuine-dispute adjudication (only if it happens)

If a real disagreement survives (10-round review cap, early escalation on stalemate, an amendment failing 2 rounds, a review finding failing 3 fix/verify rounds), the orchestrator condenses it into 2–4 options for you to decide. This is not a process failure — it means there is genuine design tension worth a human call.

### Other touchpoints (non-regular)

- If a mid-implementation amendment **touches scope or acceptance criteria**, it comes straight to you (engineer consensus cannot substitute for your authorization);
- at the end, **whether to commit is your decision** — nobody commits during the process; the working tree is left for your acceptance.

## 5. Artifacts: the collab directory map

Everything lands in `collab/<date>-<slug>/` as plain Markdown, readable at any time:

| File | Content |
|---|---|
| `00_TOPIC.md` | topic, constraints, code entry points, acceptance criteria |
| `10_/11_*_proposal.md` | the two independent proposals |
| `20_/21_*_review_rN.md` | cross-review rounds (from r2, the drafter's file opens with the merged draft) |
| `25_disputes.md` | dispute + amendment ledger (one line each, with a state machine) |
| `30_PLAN.md` | consensus plan (readback records, your approval, and all amendments appended) |
| `31_TASKS.md` | task table (id / task / owner / files / acceptance / test command) |
| `40_/41_*_worklog.md` | implementation logs |
| `50_/51_*_reviews_*.md` | code reviews (including verify/reject rounds) |
| `90_SUMMARY.md` | summary + collaboration-yield audit |
| `prompts/` | archive of every dispatch prompt and log |

**The on-disk files are the single source of truth for process state** — this is what makes the whole collaboration survivable across session interruptions.

## 6. Advanced

- **Continue from existing sessions**: if both sides already have sessions that read the project and formed positions, independent proposals can be skipped, entering cross-review directly. Identify the Codex session by **UUID** (thread names are neither unique nor stable); taking one over appends to that app conversation, so the orchestrator asks your consent first — don't use that conversation in the app during the collaboration.
- **Engineer A as a standalone session**: by default CA is a background subagent; if you want a top-level Claude session you can open yourself, say so — the cost is semi-automation (each dispatch needs your confirmation).
- **Parallel implementation (dual-owner)**: only worth it when the work splits with low coupling, interfaces can be frozen up front, and both halves are large and wall-clock-bound; the hard rule is disjoint file sets. The default is single-owner implementation with the other side doing a full review — the collaboration dividend is in planning and reviewing, not parallel typing.

## 7. Failures and recovery

- **Orchestrator session interrupted / context compacted**: just run `/pair-collab <same topic>` in a new session — finding an existing collab directory triggers recovery mode, rebuilding progress from the on-disk files (phase inferred from the highest-numbered artifact; in-flight tasks checked via `prompts/`). Codex sessions persist in the library and resume directly; the Claude subagent dies with the session and is re-spawned automatically.
- **Codex call failures**: automatic degradation chain = one retry → new session re-seeded from the collab files → **mailbox mode** (the orchestrator hands you the prompt to paste into the Codex app and stores the reply back into the right file); everything else stays the same.
- **`cb-round.sh` exit codes**: `2` codex exited non-zero (read the matching `.log`) / `3` empty output / `4` missing CONSENSUS line (formal failure) / `5` per-UUID single-writer lock conflict (confirm the previous task really exited, then delete `collab/<slug>/.locks/<UUID>` and retry) / `7` output valid but session id not captured (record it manually).
- **An engineer touched files it shouldn't have**: out-of-bounds files are restored to the work-start baseline (the stash SHA in `baseline.txt`) — your own uncommitted changes are never touched.

## 8. Caveats and cost

- **Two quota pools burn**: Engineer B runs on your ChatGPT/Codex subscription, independent of the Claude usage pool — one reason self-contained tasks are good candidates for Codex to implement.
- **Don't upgrade the Codex CLI mid-topic** (resume version drift), and don't touch the collaborating Codex conversation in the app.
- **Discussion phases run in a read-only sandbox**; write access only during implementation/fix phases; `--dangerously-bypass-approvals-and-sandbox` is never used, under any circumstances.
- **Honest expectation setting**: both engineers and the orchestrator are LLMs. Cross-review covers the *non-overlapping* blind spots of the two models and grants no immunity for shared ones. Your plan approval and the integration tests are the only two non-LLM checkpoints — "two AIs reviewed it" does not mean "adequately vetted", and the shared-assumptions list in the approval package deserves your genuine attention.
