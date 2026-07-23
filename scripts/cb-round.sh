#!/usr/bin/env bash
# pair-collab: cb-round.sh — unified wrapper for every CB (Codex) call; the default
# entry point named in SKILL.md ("Driving Engineer B"). The raw commands in that
# section are the underlying facts and the fallback path when this script breaks.
# Handles uniformly: feeding the prompt via stdin (prevents the PowerShell
# stdin-EOF hang), tee'ing the log, capturing and registering the session id,
# a per-UUID single-writer lock (turns the single-writer rule from discipline
# into mechanism), and a formal precheck of the output (non-empty / CONSENSUS line).
#
# Usage (from anywhere inside the repo; collab dir and output file are repo-root-relative):
#   bash cb-round.sh new    <collab-dir> <label> <read-only|workspace-write> <out-file> <purpose> [--require-consensus]
#   bash cb-round.sh resume <collab-dir> <label> <UUID> <out-file> [--require-consensus]
#
#   <label>    prompt/log name: reads <collab-dir>/prompts/<label>.md, writes the log
#              next to it as <label>.log (naming convention: codex-pNrM)
#   <purpose>  'new' only; recorded in codex_sessions.txt (canonical values:
#              discussion / implementation; degraded rebuilds may use discussion-2 etc.)
#   --require-consensus  add on review / readback / audit / amendment rounds:
#              the output must contain a line starting with `CONSENSUS: AGREE|OBJECT`
#   CB_MODEL / CB_EFFORT  env vars: model and reasoning-effort tier, defaults
#              gpt-5.6-sol / xhigh; both passed explicitly on every call (resume
#              included), pinning CB against ~/.codex/config.toml drift mid-topic
#
# Exit codes: 0 ok; 2 codex exited non-zero; 3 output file empty; 4 CONSENSUS line
#             missing (formal defect — O handles via the return right); 5 UUID lock
#             conflict (single-writer); 6 usage/precondition error; 7 codex succeeded
#             but no session id captured (output still valid; register it by hand)
set -u -o pipefail

CB_MODEL="${CB_MODEL:-gpt-5.6-sol}"
CB_EFFORT="${CB_EFFORT:-xhigh}"

usage_die() { echo "cb-round: $*" >&2; exit 6; }

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
[ -s "$PROMPT" ] || usage_die "prompt missing or empty: $PROMPT (Write it first, then call)"

REQUIRE_CONSENSUS=0
SANDBOX=""; UUID=""; OUTFILE=""; PURPOSE=""
if [ "$MODE" = new ]; then
  SANDBOX="${4:-}"; OUTFILE="${5:-}"; PURPOSE="${6:-}"
  case "$SANDBOX" in
    read-only|workspace-write) ;;
    *) usage_die "sandbox must be read-only|workspace-write, got '${SANDBOX}'" ;;
  esac
  [ -n "$OUTFILE" ] && [ -n "$PURPOSE" ] || usage_die "'new' requires <out-file> <purpose>"
  [ "${7:-}" = "--require-consensus" ] && REQUIRE_CONSENSUS=1
else
  UUID="${4:-}"; OUTFILE="${5:-}"
  [ -n "$UUID" ] && [ -n "$OUTFILE" ] || usage_die "'resume' requires <UUID> <out-file>"
  echo "$UUID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' \
    || usage_die "resume takes a UUID only (thread names are neither unique nor stable), got '${UUID}'"
  [ "${6:-}" = "--require-consensus" ] && REQUIRE_CONSENSUS=1
fi

# per-UUID single-writer lock (resume only; two 'new' calls are distinct sessions, no conflict)
if [ "$MODE" = resume ]; then
  mkdir -p "$COLLAB/.locks"
  LOCKDIR="$COLLAB/.locks/$UUID"
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "cb-round: lock conflict — $LOCKDIR exists (holder pid: $(cat "$LOCKDIR/pid" 2>/dev/null || echo '?'))" >&2
    echo "cb-round: single-writer rule: first confirm the previous task on this UUID has exited, then remove the lock dir by hand and retry" >&2
    exit 5
  fi
  echo $$ > "$LOCKDIR/pid"
  trap 'rm -rf "$LOCKDIR"' EXIT
fi

RC=0
if [ "$MODE" = new ]; then
  codex exec -C "$REPO_ROOT" -s "$SANDBOX" -m "$CB_MODEL" -c model_reasoning_effort="$CB_EFFORT" -o "$OUTFILE" - < "$PROMPT" 2>&1 | tee "$LOG" || RC=$?
else
  codex exec resume "$UUID" -m "$CB_MODEL" -c model_reasoning_effort="$CB_EFFORT" -o "$OUTFILE" - < "$PROMPT" 2>&1 | tee "$LOG" || RC=$?
fi
if [ "$RC" -ne 0 ]; then
  echo "cb-round: codex exited $RC — read $LOG to diagnose (re-run with --json if needed)" >&2
  exit 2
fi

[ -s "$OUTFILE" ] || { echo "cb-round: output empty: $OUTFILE (read $LOG)" >&2; exit 3; }

if [ "$REQUIRE_CONSENSUS" -eq 1 ] && ! grep -qE '^CONSENSUS: (AGREE|OBJECT)' "$OUTFILE"; then
  echo "cb-round: output lacks a CONSENSUS line (formal defect): $OUTFILE — O handles via the return right" >&2
  exit 4
fi

if [ "$MODE" = new ]; then
  SESSIONS="$COLLAB/codex_sessions.txt"
  SID="$(grep -m1 -oE 'session id: [0-9a-f-]+' "$LOG" | sed 's/^session id: //')"
  if [ -z "$SID" ]; then
    echo "cb-round: output valid but no session id captured from $LOG (banner format drift?) — register it in $SESSIONS by hand" >&2
    exit 7
  fi
  if [ ! -f "$SESSIONS" ] || ! grep -q '^# codex ' "$SESSIONS"; then
    echo "# codex $(codex --version 2>/dev/null | head -n1)" >> "$SESSIONS"
  fi
  echo "$PURPOSE=$SID" >> "$SESSIONS"
  echo "cb-round: session_id=$SID (recorded in $SESSIONS)"
fi

echo "cb-round: OK -> $OUTFILE"
