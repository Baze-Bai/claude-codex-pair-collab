#!/usr/bin/env bash
# pair-collab: ca-round.sh — unified wrapper for every HEADLESS CA (Claude CLI) call;
# the route-B mirror of cb-round.sh. Makes CA a script-drivable CLI worker so the
# engine can drive both sides without O relaying anything.
#
# Differences from cb-round.sh (read these before assuming symmetry):
#   - Session ids are MINTED HERE and pinned via `--session-id` (no banner parsing);
#     resume uses `--resume <uuid>`. Sessions persist in ~/.claude per-cwd project
#     buckets — always run from the repo root (this script cd's there) so create and
#     resume land in the same bucket.
#   - <out-file> is the PRECHECK TARGET, not a capture flag: headless CA Writes its
#     deliverable file itself (same contract as subagent CA); claude's stdout is only
#     the one-line summary and goes to the .log.
#   - No OS sandbox exists for CA. Its write scope is enforced by: the per-round
#     scope contract (behavior) + the engine's write sentinel (detection) + the
#     baseline-restore procedure (repair). The tool surface IS pinned below:
#     --permission-mode default + an --allowedTools whitelist + a --disallowedTools
#     deny list — the deny list (not the whitelist) is what blocks the dangerous
#     categories (git mutations, installs, rm/mv), and it holds even on machines
#     whose user settings allow all Bash (ground-truth measured). No path-surface
#     wall though — NEVER "fix" a denial by switching to bypassPermissions.
#   - Model/effort: assume NOT persistent across resume (same trap as codex) — if the
#     topic pins a CA model, export CA_MODEL and it is passed on EVERY call.
#
# Auth prerequisite (one-time, user-performed): the STANDALONE Claude CLI must be
# authenticated — desktop-app-hosted auth does not reach nested `claude -p` (symptom:
# instant "Not logged in · Please run /login", exit 8 here). Fix: the user runs
# `claude setup-token` once and stores the token as the CLAUDE_CODE_OAUTH_TOKEN
# User-scope environment variable (setup-token's standard mechanism; it does NOT
# write ~/.claude/.credentials.json). Long-lived processes started before the var
# was set don't inherit it, so this script auto-loads it from the User registry
# scope when absent from the process env (measured 2026-07-22: works; the token is
# never printed and never reaches the .log).
#
# Usage (from anywhere inside the repo; collab dir and out-file are repo-root-relative):
#   bash ca-round.sh new    <collab-dir> <label> <out-file> <purpose> [--require-consensus]
#   bash ca-round.sh resume <collab-dir> <label> <UUID> <out-file> [--require-consensus]
#
#   <label>    prompt/log name: reads <collab-dir>/prompts/<label>.md, logs to <label>.log
#   <purpose>  'new' only; recorded in claude_sessions.txt (canonical: discussion /
#              implementation; degraded rebuilds may use discussion-2 etc.)
#   --require-consensus  review/readback/audit rounds: out-file must contain a line
#              starting with `CONSENSUS: AGREE|OBJECT`
#
# Env overrides:
#   CA_MODEL             model for this call (default: user's CLI default; pin per-topic)
#   CA_ALLOWED_TOOLS     --allowedTools value (default: the whitelist below)
#   CA_DISALLOWED_TOOLS  --disallowedTools value (default: the deny list below;
#                        deny beats every allow rule — efficacy ground-truth measured)
#
# Exit codes: 0 ok; 2 claude exited non-zero; 3 out-file empty (CA failed to Write
#             its deliverable); 4 CONSENSUS line missing (formal defect — O's return
#             right); 5 UUID lock conflict (single-writer); 6 usage/precondition
#             error; 8 standalone CLI not logged in (user must run `claude setup-token`)
set -u -o pipefail

usage_die() { echo "ca-round: $*" >&2; exit 6; }

MODE="${1:-}"
case "$MODE" in
  new|resume) ;;
  *) usage_die "unknown mode '${MODE}' (use new|resume; see file header)" ;;
esac

COLLAB="${2:-}"; LABEL="${3:-}"
[ -n "$COLLAB" ] && [ -n "$LABEL" ] || usage_die "missing arguments (see file header)"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || usage_die "must run inside the repo"
cd "$REPO_ROOT" || usage_die "cannot cd to repo root: $REPO_ROOT"
[ -d "$COLLAB" ] || usage_die "collab dir not found: $COLLAB"

PROMPT="$COLLAB/prompts/$LABEL.md"
LOG="$COLLAB/prompts/$LABEL.log"
[ -s "$PROMPT" ] || usage_die "prompt missing or empty: $PROMPT (generate it first — engine advance, or Write by hand)"

REQUIRE_CONSENSUS=0
UUID=""; OUTFILE=""; PURPOSE=""
if [ "$MODE" = new ]; then
  OUTFILE="${4:-}"; PURPOSE="${5:-}"
  [ -n "$OUTFILE" ] && [ -n "$PURPOSE" ] || usage_die "'new' requires <out-file> <purpose>"
  [ "${6:-}" = "--require-consensus" ] && REQUIRE_CONSENSUS=1
else
  UUID="${4:-}"; OUTFILE="${5:-}"
  [ -n "$UUID" ] && [ -n "$OUTFILE" ] || usage_die "'resume' requires <UUID> <out-file>"
  echo "$UUID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' \
    || usage_die "resume takes a UUID, got '${UUID}'"
  [ "${6:-}" = "--require-consensus" ] && REQUIRE_CONSENSUS=1
fi

# Auto-load the standalone-CLI auth token from the Windows User env scope when the
# process env lacks it (parent sessions started before `claude setup-token` ran
# don't inherit it). Value is exported for the child only — never printed or logged.
if [ -z "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
  _tok="$(powershell -NoProfile -Command "[Environment]::GetEnvironmentVariable('CLAUDE_CODE_OAUTH_TOKEN','User')" 2>/dev/null | tr -d '\r')"
  [ -n "$_tok" ] && export CLAUDE_CODE_OAUTH_TOKEN="$_tok"
  unset _tok
fi

mint_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then uuidgen | tr 'A-Z' 'a-z'; return; fi
  if command -v python >/dev/null 2>&1; then python -c "import uuid;print(uuid.uuid4())"; return; fi
  powershell -NoProfile -Command "[guid]::NewGuid().ToString()" | tr -d '\r'
}

# Permission posture (measured 2026-07-22 on this machine): the nested CLI inherits
# user-scope settings — here defaultMode:bypassPermissions plus a bare `Bash` allow
# rule, under which --allowedTools alone is a no-op (echo probe executed). Counter:
# pin --permission-mode default (CLI flag beats settings defaultMode) and carry an
# explicit deny list (deny beats any allow rule). Net effect: allow list guarantees
# deliverable writing + read-only probes even on a bare machine; deny list blocks
# the identity-layer ban categories even on a machine whose settings allow all Bash.
# Never widen to bypassPermissions.
ALLOWED="${CA_ALLOWED_TOOLS:-Write Edit Bash(git diff*) Bash(git log*) Bash(git show*) Bash(git status*) Bash(rg*) Bash(pytest*) Bash(python -m pytest*) Bash(ls*)}"
DENIED="${CA_DISALLOWED_TOOLS:-Bash(git add*) Bash(git commit*) Bash(git push*) Bash(git checkout*) Bash(git restore*) Bash(git reset*) Bash(git stash*) Bash(git rebase*) Bash(git merge*) Bash(npm install*) Bash(pnpm install*) Bash(pip install*) Bash(uv add*) Bash(uv pip*) Bash(rm*) Bash(rmdir*) Bash(mv*)}"

CLAUDE_ARGS=(-p --permission-mode default --allowedTools "$ALLOWED" --disallowedTools "$DENIED")
[ -n "${CA_MODEL:-}" ] && CLAUDE_ARGS+=(--model "$CA_MODEL")

if [ "$MODE" = new ]; then
  UUID="$(mint_uuid)"
  [ -n "$UUID" ] || usage_die "could not mint a UUID (no uuidgen/python/powershell)"
  CLAUDE_ARGS+=(--session-id "$UUID")
else
  # per-UUID single-writer lock (resume only; 'new' mints a fresh id, no conflict)
  mkdir -p "$COLLAB/.locks"
  LOCKDIR="$COLLAB/.locks/$UUID"
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "ca-round: lock conflict — $LOCKDIR exists (holder pid: $(cat "$LOCKDIR/pid" 2>/dev/null || echo '?'))" >&2
    echo "ca-round: single-writer rule: first confirm the previous task on this UUID has exited, then remove the lock dir by hand and retry" >&2
    exit 5
  fi
  echo $$ > "$LOCKDIR/pid"
  trap 'rm -rf "$LOCKDIR"' EXIT
  CLAUDE_ARGS+=(--resume "$UUID")
fi

RC=0
claude "${CLAUDE_ARGS[@]}" < "$PROMPT" 2>&1 | tee "$LOG" || RC=$?

if grep -q "Not logged in" "$LOG"; then
  echo "ca-round: standalone Claude CLI is not authenticated (desktop-app auth does not reach nested claude -p)." >&2
  echo "ca-round: one-time fix, performed by the user: run 'claude setup-token' (or /login inside interactive claude), then retry." >&2
  exit 8
fi
if [ "$RC" -ne 0 ]; then
  echo "ca-round: claude exited $RC — read $LOG to diagnose" >&2
  exit 2
fi

[ -s "$OUTFILE" ] || { echo "ca-round: deliverable missing/empty: $OUTFILE (CA must Write it; read $LOG for its reply)" >&2; exit 3; }

if [ "$REQUIRE_CONSENSUS" -eq 1 ] && ! grep -qE '^CONSENSUS: (AGREE|OBJECT)' "$OUTFILE"; then
  echo "ca-round: output lacks a CONSENSUS line (formal defect): $OUTFILE — O handles via the return right" >&2
  exit 4
fi

if [ "$MODE" = new ]; then
  SESSIONS="$COLLAB/claude_sessions.txt"
  if [ ! -f "$SESSIONS" ] || ! grep -q '^# claude ' "$SESSIONS"; then
    echo "# claude $(claude --version 2>/dev/null | head -n1)" >> "$SESSIONS"
  fi
  echo "$PURPOSE=$UUID" >> "$SESSIONS"
  echo "ca-round: session_id=$UUID (recorded in $SESSIONS)"
fi

echo "ca-round: OK -> $OUTFILE"
