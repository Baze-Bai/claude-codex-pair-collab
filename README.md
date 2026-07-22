# pair-collab

**[中文说明 →](README.zh-CN.md)**(the skill itself is written in Chinese)

A [Claude Code](https://claude.com/claude-code) skill that orchestrates a **Claude × Codex two-agent pair-collaboration protocol**: two symmetric AI engineers independently propose, adversarially cross-review each other, converge on a consensus plan, and — after explicit user approval — one implements while the other reviews the full diff. The session that invokes the skill acts as a strictly **neutral orchestrator** that never writes code and never takes a technical side.

## Why

Two LLMs politely agreeing with each other is worthless. This protocol is engineered against that failure mode:

- **Anti-anchoring**: both engineers write proposals independently and in parallel — neither sees the other's draft first. Round 1 of review is also blind and symmetric.
- **AGREE has a cost**: a bare "AGREE" is rejected. Every AGREE must carry *residual risks* and *the strongest objection I considered but dropped*. An empty-handed unanimous round 1 is treated as a red flag, not a success.
- **Disputes belong to whoever raised them**: only the proposer can close their own dispute (confirm, withdraw, or user adjudication). The orchestrator keeps a ledger and never declares a dispute resolved on anyone's behalf.
- **Evidence over rhetoric**: factual claims about current code behavior require `file:line` anchors, which the counterpart spot-checks; any dispute decidable by a read-only experiment should be decided by running it.
- **The user is the only non-LLM checkpoint**: plan approval and integration testing are explicitly framed as the last line of defense against blind spots *shared* by both models. The skill tells the orchestrator to say this out loud rather than let "two AIs reviewed it" masquerade as assurance.

## Architecture

| Party | Carrier | Role |
|---|---|---|
| Orchestrator (O) | the Claude Code session invoking the skill | neutral facilitator: dispatch, relay, consensus bookkeeping, integration tests, summary — **no code, no technical stance** |
| Engineer A (CA) | a Claude subagent spawned by O (background) | proposes, reviews, implements or audits |
| Engineer B (CB) | Codex CLI (`codex exec`, headless) | proposes, reviews, implements or audits |
| User | you | sets the topic; approves the plan; adjudicates genuine disputes |

Workflow: `Phase 0` topic → `1` independent proposals (parallel, isolated) → `2` cross-review convergence (≤10 rounds, dispute ledger) → `3` consensus PLAN/TASKS + **user approval gate** → `4` implementation (single owner by default; PLAN amendments via a formal procedure) → `5` full-diff review by the non-owner (3-strike fix/verify loop with verifiable closure criteria) → `6` integration verification run by O → `7` summary with a collaboration-yield audit.

All artifacts land in `collab/<date>-<slug>/` as plain Markdown files — the on-disk files are the single source of truth, so the whole process survives session interruption and context compaction.

## Prerequisites

- **Claude Code** (this is a skill for it).
- **Codex CLI**: `npm install -g @openai/codex`, logged in (shares `~/.codex` with the Codex desktop app).
- A **Bash** available to Claude Code (on Windows: Git Bash) — Codex calls are driven via stdin through `scripts/cb-round.sh`.

## Install

From your project root:

```bash
git clone https://github.com/Baze-Bai/claude-codex-pair-collab.git .claude/skills/pair-collab
```

Optionally add `collab/` (the per-topic workspace) to `.git/info/exclude`.

## Usage

```
/pair-collab <topic description>
```

The orchestrator will set up the topic workspace, run both engineers in parallel, and come back to you at exactly two regular checkpoints: plan approval and (if any) genuine-dispute adjudication.

See the **[Usage Guide](USAGE.md)** for the full walkthrough: prerequisites, the checkpoints where you are needed, the artifact map, failure recovery, and cost caveats.

## Repository layout

```
SKILL.md      # the protocol itself (normative source; in Chinese)
templates/    # 8 dispatch-prompt templates (proposal / review / readback / amendment / impl / audit)
scripts/
  cb-round.sh # unified Codex invocation wrapper: stdin feeding, logging, session-id capture,
              # per-UUID single-writer lock, output preflight (non-empty / CONSENSUS line)
```

## Language

The protocol text and templates are written in **Chinese** (code and commands in English) — it was built for a Chinese-speaking workflow. Everything about the mechanism is language-independent; fork and translate freely.

## Honest limitations

CA, CB, and O are all LLMs (O is also Claude — it is not an independent third perspective). Cross-review only covers the *non-overlapping* blind spots of the two models; it grants no immunity against blind spots they share (recent API changes, implicit repo constraints, threat modeling, concurrency failure modes, and the trained tendency of both to be agreeable). Costly AGREEs and the orchestrator's rejection power *reduce* polite convergence; they do not eliminate it. The two non-LLM checkpoints — your plan approval and the integration tests — are the real backstop. The skill instructs the orchestrator to tell you this explicitly.

## License

MIT
