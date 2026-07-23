# pair-collab

**[中文说明 →](README.zh-CN.md)**

A [Claude Code](https://claude.com/claude-code) skill that orchestrates a **Claude × Codex two-agent pair-collaboration protocol, driven by a deterministic round engine**: two symmetric AI engineers independently propose, adversarially cross-review each other under engine-managed rounds, converge on a consensus plan written by one of the workers — and, after explicit user approval, one implements while the other audits the full diff. The session that invokes the skill acts as a strictly **neutral orchestrator** that never writes code, never takes a technical side, and never holds the pen on consensus substance.

## Why

Two LLMs politely agreeing with each other is worthless. This protocol is engineered against that failure mode:

- **Anti-anchoring**: both engineers write proposals independently and in parallel — neither sees the other's draft first. Round 1 of review is also blind and symmetric.
- **AGREE has a cost**: a bare "AGREE" is rejected mechanically. Every AGREE must carry *residual risks* and *the strongest objection I considered but dropped*. An empty-handed unanimous round 1 is treated as a red flag, not a success.
- **Disputes belong to whoever raised them — and the machine enforces it**: reviews end with a machine-readable `DISPUTES:` line; the engine applies declarations to a ledger **under authority rules** (only the proposer can confirm-close or withdraw; closed disputes never regress via worker declarations). Nobody — including the orchestrator — can close a dispute on the proposer's behalf.
- **Nothing is paraphrased in between**: workers read each other's originals from disk; the engine's receipts quote verbatim excerpts; the consensus PLAN is written by the worker who penned the final fusion draft under a *carry-don't-regenerate* contract, then read back by both sides for drift (omission / compression / addition). The orchestrator's only authored text in the approval package is a 3–5 line reading guide.
- **Evidence over rhetoric**: factual claims about current code behavior require `file:line` anchors, which the counterpart spot-checks; any dispute decidable by a read-only experiment should be decided by running it.
- **The user is the only non-LLM checkpoint**: plan approval and integration testing are explicitly framed as the last line of defense against blind spots *shared* by both models. The skill tells the orchestrator to say this out loud rather than let "two AIs reviewed it" masquerade as assurance.

## Architecture

| Party | Carrier | Role |
|---|---|---|
| Orchestrator (O) | the Claude Code session invoking the skill | neutral facilitator: runs engine commands, executes the launch actions it prints, makes the semantic verdicts the engine can't, handles exceptions, runs integration tests — **no code, no technical stance, no pen on consensus** |
| Round engine | `scripts/collab-engine.sh` (deterministic state machine) | infers state from files, fills prompts from templates, sequences rounds, prechecks outputs formally, keeps the dispute ledger under authority rules, emits verbatim receipts — **never calls an LLM, never judges merit** |
| Engineer A (CA) | headless `claude -p` CLI session (default) or a Claude subagent (fallback) | proposes, reviews, implements or audits |
| Engineer B (CB) | Codex CLI (`codex exec`, headless) | proposes, reviews, implements or audits |
| User | you | sets the topic; approves the plan; adjudicates genuine disputes |

Workflow: `Phase 0` topic → `1` independent proposals (parallel, isolated) → `2` cross-review convergence (≤10 rounds; engine sequences, O judges) → `3` consensus PLAN/TASKS **written by the finalize penner**, verified by a two-sided readback, then the **user approval gate** → `4` implementation (single owner by default; PLAN amendments via a formal procedure) → `5` full-diff audit by the non-owner (3-strike fix/verify loop with verifiable closure criteria) → `6` integration verification run by O → `7` summary with a collaboration-yield audit. The engine covers the Phases 1–3 happy path; Phases 4–7 and every exception path stay with O.

All artifacts land in `collab/<date>-<slug>/` as plain Markdown files — the on-disk files are the single source of truth (the engine itself keeps no state), so the whole process survives session interruption and context compaction.

## Prerequisites

- **Claude Code** (this is a skill for it).
- **Codex CLI**: `npm install -g @openai/codex`, logged in (shares `~/.codex` with the Codex desktop app).
- A **Bash** available to Claude Code (on Windows: Git Bash) — all worker calls are driven via stdin through the wrapper scripts.
- For the default headless-CA carrier: the **standalone Claude CLI authenticated** — run `claude setup-token` once (desktop-app-hosted auth does not reach nested `claude -p`). Without it, the skill falls back to the subagent carrier automatically.

## Install

From your project root:

```bash
git clone https://github.com/Baze-Bai/claude-codex-pair-collab.git .claude/skills/pair-collab
```

Recommended: add `collab/` (the per-topic workspace) to `.git/info/exclude` — the engine's write sentinel assumes it.

## Usage

```
/pair-collab <topic description>
```

The orchestrator will set up the topic workspace, drive both engineers in parallel through the engine, and come back to you at exactly two regular checkpoints: plan approval and (if any) genuine-dispute adjudication.

See the **[Usage Guide](USAGE.md)** for the full walkthrough: prerequisites, the checkpoints where you are needed, the artifact map, failure recovery, and cost caveats.

## Repository layout

```
SKILL.md      # the protocol itself (normative source for all contract wording)
templates/    # 11 prompt templates (8 engine-filled: proposals / reviews / finalize / readback;
              #  3 O-filled for the manual phases: amendment / implementation / audit)
scripts/
  collab-engine.sh  # the round engine: status / advance / collect (Phases 1–3 happy path)
  ca-round.sh       # headless-CA call wrapper: session pinning, single-writer lock,
                    #  permission pinning + deny list, output preflight
  cb-round.sh       # Codex call wrapper: stdin feeding, logging, session-id capture,
                    #  single-writer lock, model/effort pin (defaults gpt-5.6-sol / xhigh,
                    #  override via CB_MODEL / CB_EFFORT), output preflight
```

## Language

Protocol text and templates are written in **English**. The orchestrator communicates with you in your language, and collab documents follow your working language (code and commands stay in English).

## Honest limitations

CA, CB, and O are all LLMs (O is also Claude — it is not an independent third perspective). Cross-review only covers the *non-overlapping* blind spots of the two models; it grants no immunity against blind spots they share (recent API changes, implicit repo constraints, threat modeling, concurrency failure modes, and the trained tendency of both to be agreeable). The engine adds determinism to the *procedure*, not intelligence to the *judgment* — it eliminates paraphrase drift and bookkeeping errors, nothing more. Costly AGREEs, the orchestrator's rejection power, and mechanized authority rules *reduce* polite convergence; they do not eliminate it. The two non-LLM checkpoints — your plan approval and the integration tests — are the real backstop. The skill instructs the orchestrator to tell you this explicitly.

## License

MIT
