# Usage Guide

**[中文 →](USAGE.zh-CN.md)**

This guide takes the **user's point of view**: how to install, how to start a topic, at which checkpoints you are needed, where the artifacts live, and how to recover from failures. The normative source for the protocol mechanics is [SKILL.md](SKILL.md).

## 1. Prerequisites

| Component | Requirement |
|---|---|
| Claude Code | installed and working (this is a skill for it) |
| Codex CLI | `npm install -g @openai/codex`, logged in. The CLI shares `~/.codex` with the Codex desktop app — if the app is logged in, the CLI reuses that login |
| Bash | Claude Code must be able to run Bash (on Windows: Git Bash, bundled with Git for Windows) — all worker calls are driven via stdin through the wrapper scripts; backgrounding them from PowerShell hangs forever on an unclosed stdin |
| Standalone Claude CLI auth *(for the default headless-CA carrier)* | run `claude setup-token` once — desktop-app-hosted auth does not reach a nested `claude -p` (the wrapper reports exit 8 if missing). Optional: without it the skill falls back to the subagent carrier automatically |
| Git repo | use it inside a git repository (baselines, the write sentinel, and diff review all depend on git) |

## 2. Install

From your project root:

```bash
git clone https://github.com/Baze-Bai/claude-codex-pair-collab.git .claude/skills/pair-collab
```

Recommended: locally exclude the per-topic workspace so it never pollutes `git status` (the engine's write sentinel also assumes this):

```bash
echo "collab/" >> .git/info/exclude
```

## 3. Start a topic

In a Claude Code session:

```
/pair-collab Add resumable export to the export service, keeping the existing REST contract
```

The more specific the topic (motivation, constraints, acceptance expectations), the better. If information is missing, the orchestrator asks you first, then starts.

The orchestrator will: create the `collab/<date>-<slug>/` workspace and tell you its path, then drive Phases 1–3 through the **round engine** (`collab-engine.sh status / advance / collect`) — the engine fills the prompts, sequences the rounds, and prechecks the outputs; the orchestrator launches the printed worker commands and makes the judgment calls the engine can't. Both engineers run **in parallel and in isolation** wherever the flow allows it.

**Scale note**: trivial single-function changes are not worth this protocol (two proposals + multi-round review has fixed overhead) — the orchestrator will say so and let you decide. For small tasks the artifacts shrink automatically (one-page proposals, merged PLAN/TASKS), but four things never shrink: the user approval gate, independent anti-anchoring proposals, CONSENSUS credentials, and the reviewer posture.

## 4. Where you are needed

The regular flow has exactly **two mandatory checkpoints**; the rest runs autonomously, and you can open the collab directory at any time to watch progress (each round also produces a one-screen receipt).

### Checkpoint 1: plan approval (Phase 3, always)

After the reviews converge, the **finalize penner** (the worker who wrote the last fusion draft — never the orchestrator) writes the definitive plan, and both sides read it back in full for drift. You then receive an approval package:

- `30_PLAN.md` (consensus plan, worker-authored, carrying both sides' readback sign-off) + `31_TASKS.md` (task table);
- a list of **"assumptions both sides share but never adversarially tested"** — mechanically extracted from every AGREE's credential slots. These are the places two AIs are most likely to fall into together. **Review this list first**, not just whether the plan reads well;
- you are invited to **add or adjust acceptance items** (the final integration verification runs against them) — your chance to inject an outside perspective;
- the implementation split (who implements, who audits) is also decided by you here — the orchestrator only recommends, never decides;
- the orchestrator's only authored text is a 3–5 line reading guide on top.

You can approve, reject, or attach change requests (they re-enter as *user adjudication* for a targeted convergence round, then come back for approval). **No code is touched before your approval.**

### Checkpoint 2: genuine-dispute adjudication (only if it happens)

If a real disagreement survives (10-round review cap, early escalation on a stalled dispute ledger, an amendment failing 2 rounds, an audit finding failing 3 fix/verify rounds), the orchestrator condenses it into 2–4 options for you to decide. This is not a process failure — it means there is genuine design tension worth a human call.

### Other touchpoints (non-regular)

- If a mid-implementation amendment **touches scope or acceptance criteria**, it comes straight to you (engineer consensus cannot substitute for your authorization);
- at the end, **whether to commit is your decision** — nobody commits during the process; the working tree is left for your acceptance.

## 5. Artifacts: the collab directory map

Everything lands in `collab/<date>-<slug>/` as plain Markdown, readable at any time:

| File | Content |
|---|---|
| `00_TOPIC.md` | topic, constraints, code entry points, acceptance criteria |
| `10_/11_*_proposal.md` | the two independent proposals |
| `20_/21_*_review_rN.md` | cross-review rounds (from r2, the penner's file opens with the fusion draft) |
| `25_disputes.md` | dispute ledger — engine-maintained under authority rules |
| `30_PLAN.md` / `31_TASKS.md` | consensus plan + task table, **written by the finalize penner** (readback sign-off, your approval, and amendments appended) |
| `32_finalize_combined.md` | CB-penner only: combined finalize output before the engine splits it |
| `35_/36_*_readback.md` | the two readback verdicts |
| `40_/41_*_worklog.md` | implementation logs |
| `50_/51_*_reviews_*.md` | code audits (including verify/reject rounds) |
| `90_SUMMARY.md` | summary + collaboration-yield audit |
| `receipts/` | engine receipts per round: verbatim CONSENSUS/DISPUTES excerpts, precheck flags, ledger diff |
| `readback_archive/` | objected readbacks + drifted PLAN/TASKS per fix attempt |
| `prompts/` | every dispatched prompt and log |
| `baseline.txt` | Phase 4 work-start baseline: stash SHA + opening porcelain inventory (written by O) |
| `opening_snapshot.txt` | worktree snapshot backing the engine's write sentinel |
| `.locks/` | wrapper per-UUID single-writer lock dirs (empty in normal state) |
| `codex_sessions.txt` / `claude_sessions.txt` / `agents.txt` | worker session registries (the presence of `claude_sessions.txt` selects the headless CA carrier) |

**The on-disk files are the single source of truth for process state** — the engine itself keeps no state and re-derives everything from disk on each call. This is what makes the whole collaboration survivable across session interruptions.

## 6. Advanced

- **Continue from existing sessions**: if both sides already have sessions that read the project and formed positions, independent proposals can be skipped, entering cross-review directly. Identify the Codex session by **UUID** (thread names are neither unique nor stable); taking one over appends to that app conversation, so the orchestrator asks your consent first — don't use that conversation in the app during the collaboration.
- **CA carriers**: the default is a **headless `claude -p` CLI session** (fully script-driven, survives orchestrator-session death, and carries the strictest tool-level permission pinning). Fallbacks: a background **subagent** (works with zero extra setup) or an **independent top-level session** you can open yourself (semi-automatic; each dispatch needs your confirmation).
- **Parallel implementation (dual-track)**: only worth it when the work splits with low coupling, interfaces can be frozen up front, and both halves are large and wall-clock-bound; the hard rule is disjoint file sets. The default is single-owner implementation with the other side doing a full audit — the collaboration dividend is in planning and reviewing, not parallel typing.
- **Model pinning**: CB runs pinned to `gpt-5.6-sol` @ `xhigh` reasoning effort on every call (override per topic via the `CB_EFFORT` / `CB_MODEL` env vars) — changing your Codex app/config defaults mid-topic cannot silently swap the model under a live topic. Headless CA follows your Claude CLI default unless you pin `CA_MODEL`.

## 7. Failures and recovery

- **Orchestrator session interrupted / context compacted**: just run `/pair-collab <same topic>` in a new session — finding an existing collab directory triggers recovery mode, and `collab-engine.sh status` re-derives the exact state from disk. Codex and headless-CA sessions persist in their stores and resume by recorded UUID; a subagent CA dies with the session and is re-spawned automatically.
- **Codex call failures**: automatic degradation chain = one retry → new session re-seeded from the collab files → **mailbox mode** (the orchestrator hands you the prompt to paste into the Codex app and stores the reply back into the right file); everything else stays the same.
- **Headless-CA call failures**: same ladder, one rung shorter — retry → re-seeded fresh session → **fall back to the subagent carrier** (same model, in-process). Exit 8 means the standalone CLI isn't authenticated: run `claude setup-token` once.
- **Engine failure**: any misbehavior → the orchestrator stops using it and runs the manual flow (templates filled by hand, wrapper scripts driven directly, ledger kept by hand); the collab files stay authoritative either way, so the two modes interleave safely.
- **Wrapper exit codes** (`cb-round.sh` / `ca-round.sh`): `2` worker CLI exited non-zero (read the matching `.log`) / `3` deliverable empty / `4` missing CONSENSUS line (formal defect) / `5` per-UUID single-writer lock conflict (confirm the previous task really exited, then delete `collab/<slug>/.locks/<UUID>` and retry) / `6` usage error / `7` (cb only) output valid but session id not captured — register it by hand / `8` (ca only) standalone CLI not logged in.
- **An engineer touched files it shouldn't have**: two separate mechanisms. During the discussion phases (1–3), the engine's write sentinel compares the worktree against `opening_snapshot.txt` and flags any change in its receipt — detection only; the orchestrator verifies first, since the change may equally be your own editing. From implementation (Phase 4) onward, off-track files are restored to the work-start baseline (the stash SHA in `baseline.txt`); an explicit red line forbids restoring files you had modified before the collaboration via `git checkout` to HEAD, which is what protects your own uncommitted work.

## 8. Caveats and cost

- **Two quota pools burn**: Engineer B runs on your ChatGPT/Codex subscription, independent of the Claude usage pool — one reason self-contained tasks are good candidates for Codex to implement.
- **Don't upgrade the Codex CLI mid-topic** (resume version drift), and don't touch the collaborating Codex conversation in the app.
- **Discussion phases run CB in a read-only sandbox**; write access only during implementation/fix phases; `--dangerously-bypass-approvals-and-sandbox` and `bypassPermissions` are never used, under any circumstances.
- **Honest expectation setting**: both engineers and the orchestrator are LLMs. Cross-review covers the *non-overlapping* blind spots of the two models and grants no immunity for shared ones. The engine adds determinism to the procedure, not intelligence to the judgment. Your plan approval and the integration tests are the only two non-LLM checkpoints — "two AIs reviewed it" does not mean "adequately vetted", and the shared-assumptions list in the approval package deserves your genuine attention.
