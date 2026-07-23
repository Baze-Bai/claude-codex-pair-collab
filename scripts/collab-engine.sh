#!/usr/bin/env bash
# pair-collab: collab-engine.sh — deterministic round engine for Phases 1–3.
#
# Replaces O's per-round orchestration (template filling, sequencing, precheck,
# ledger bookkeeping) with a mechanical state machine. O keeps only: semantic
# verdicts (hollow-AGREE / substantive-OBJECT judgment), exception handling,
# and the user gates. The engine NEVER calls an LLM and NEVER launches CB
# itself — it prepares prompts and prints the exact dumb actions for O to
# execute (relay a pointer to CA; launch cb-round.sh in background Bash), so
# the harness keeps task tracking and completion notifications.
#
# Usage (from anywhere inside the repo; collab dir is repo-root-relative):
#   bash collab-engine.sh status  <collab-dir>
#   bash collab-engine.sh advance <collab-dir> [--penner ca|cb] [--accept-hollow]
#   bash collab-engine.sh collect <collab-dir>
#
#   status   Infer and print the current state, ledger summary, and next step.
#   advance  Prepare the next step: fill prompt files from templates and print
#            the CA action + CB launch command. Idempotent — re-running
#            re-prints instructions; existing prompt files are not overwritten
#            (delete a prompt file to force regeneration).
#            CA carrier: headless (route B — prints ca-round.sh commands; both
#            sides fully script-driven) when claude_sessions.txt exists or
#            --ca headless is passed on the first advance; subagent (prints
#            spawn/relay instructions for O) otherwise.
#   collect  After the awaited outputs have landed: precheck (formal layer),
#            parse CONSENSUS + DISPUTES, apply the dispute ledger under
#            authority rules, and emit a structured receipt (stdout + receipts/).
#
#   --penner ca|cb   Required only for an r1 convergence (no fusion draft
#                    exists, so the finalize penner cannot be derived).
#   --accept-hollow  Proceed past a hollow-AGREE RETURN-CANDIDATE flag. Use
#                    after O has exercised (or waived) the one-time formal
#                    return right.
#   --ca headless|subagent   CA carrier override. Needed only until the first
#                    ca-round 'new' records claude_sessions.txt (thereafter the
#                    file's presence selects headless); explicit flag wins.
#
# State is inferred from files only; the engine keeps no state of its own.
# All semantic judgment stays with O: the engine checks form (a grep can do
# it), never merit. Degraded mode: if this script misbehaves, fall back to the
# manual flow in SKILL.md (templates by hand + cb-round.sh / raw codex exec).
#
# Exit codes: 0 ok; 6 usage/precondition error.
set -u -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TPL_DIR="$SCRIPT_DIR/../templates"

die() { echo "collab-engine: $*" >&2; exit 6; }

CMD="${1:-}"; COLLAB_ARG="${2:-}"
case "$CMD" in
  status|advance|collect) ;;
  *) die "unknown command '${CMD}' (use status|advance|collect; see file header)" ;;
esac
[ -n "$COLLAB_ARG" ] || die "missing <collab-dir> (repo-root-relative)"
shift 2

PENNER_OVERRIDE=""; ACCEPT_HOLLOW=0; CA_MODE_FLAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --penner) PENNER_OVERRIDE="${2:-}"; shift 2
              case "$PENNER_OVERRIDE" in ca|cb) ;; *) die "--penner takes ca|cb" ;; esac ;;
    --accept-hollow) ACCEPT_HOLLOW=1; shift ;;
    --ca) CA_MODE_FLAG="${2:-}"; shift 2
          case "$CA_MODE_FLAG" in headless|subagent) ;; *) die "--ca takes headless|subagent" ;; esac ;;
    *) die "unknown option '$1'" ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "must run inside the repo"
cd "$REPO_ROOT" || die "cannot cd to repo root: $REPO_ROOT"
ROOT_PWD="$(pwd)"
SCRIPTS_REL="${SCRIPT_DIR#"$ROOT_PWD"/}"   # repo-relative path of scripts/ (falls back to absolute)
CB_ROUND="$SCRIPTS_REL/cb-round.sh"
CA_ROUND="$SCRIPTS_REL/ca-round.sh"

COLLAB="${COLLAB_ARG%/}"
[ -d "$COLLAB" ] || die "collab dir not found: $COLLAB"
mkdir -p "$COLLAB/prompts" "$COLLAB/receipts"

# ---------- file map ----------
TOPIC="$COLLAB/00_TOPIC.md"
PROP_CA="$COLLAB/10_claude_proposal.md"
PROP_CB="$COLLAB/11_codex_proposal.md"
LEDGER="$COLLAB/25_disputes.md"
PLAN="$COLLAB/30_PLAN.md"
TASKS="$COLLAB/31_TASKS.md"
COMBINED="$COLLAB/32_finalize_combined.md"
RB_CA="$COLLAB/35_claude_readback.md"
RB_CB="$COLLAB/36_codex_readback.md"
RB_ARCHIVE="$COLLAB/readback_archive"
SESSIONS="$COLLAB/codex_sessions.txt"
CA_SESSIONS="$COLLAB/claude_sessions.txt"
SNAPSHOT="$COLLAB/opening_snapshot.txt"

ca_review()  { echo "$COLLAB/20_claude_review_r$1.md"; }
cb_review()  { echo "$COLLAB/21_codex_review_r$1.md"; }
side_review(){ if [ "$1" = ca ]; then ca_review "$2"; else cb_review "$2"; fi; }
side_name()  { if [ "$1" = ca ]; then echo CA; else echo CB; fi; }
other_side() { if [ "$1" = ca ]; then echo cb; else echo ca; fi; }

# ---------- small helpers ----------
nonempty() { [ -s "$1" ]; }

trim() { sed 's/^[[:space:]]*//; s/[[:space:]]*$//' <<<"${1-}"; }

consensus_line() { grep -E '^CONSENSUS: (AGREE|OBJECT)' "$1" 2>/dev/null | tail -1; }
disputes_line()  { grep -E '^DISPUTES:' "$1" 2>/dev/null | tail -1; }

verdict_of() { # file -> AGREE | OBJECT | MISSING
  local line; line="$(consensus_line "$1")"
  case "$line" in
    "CONSENSUS: AGREE"*)  echo AGREE ;;
    "CONSENSUS: OBJECT"*) echo OBJECT ;;
    *) echo MISSING ;;
  esac
}

agree_credentials_ok() { # file -> exit 0 if AGREE line carries non-empty credential slots
  local line; line="$(consensus_line "$1")"
  grep -qE 'residual-risk:[[:space:]]*[^;[:space:]].{2,}' <<<"$line" \
    && grep -qE 'dropped-objection:[[:space:]]*[^[:space:]].{2,}' <<<"$line"
}

object_substance_ok() { # file -> exit 0 if OBJECT line has content after the dash
  local line; line="$(consensus_line "$1")"
  grep -qE '^CONSENSUS: OBJECT[[:space:]]*[—–-]+[[:space:]]*.{5,}' <<<"$line"
}

anchor_count() {
  local c; c="$(grep -oE '[A-Za-z0-9_][A-Za-z0-9_./-]*:[0-9]+' "$1" 2>/dev/null | wc -l | tr -d '[:space:]')"
  echo "${c:-0}"
}

has_supplement_table() { grep -qF '| # |' "$1" 2>/dev/null; }

max_round() {
  local n=0 f m
  for f in "$COLLAB"/20_claude_review_r*.md "$COLLAB"/21_codex_review_r*.md; do
    [ -e "$f" ] || continue
    m="${f##*_r}"; m="${m%.md}"
    [[ "$m" =~ ^[0-9]+$ ]] && [ "$m" -gt "$n" ] && n="$m"
  done
  echo "$n"
}

penner_of() { # round (>=2) -> ca|cb  (r2=CB anchor, alternating by parity)
  if [ $(( $1 % 2 )) -eq 0 ]; then echo cb; else echo ca; fi
}

review_files_upto() { # round -> comma-separated repo-relative list of all review files r1..N
  local n=$1 i out=""
  for i in $(seq 1 "$n"); do
    for f in "$(ca_review "$i")" "$(cb_review "$i")"; do
      [ -s "$f" ] && out="${out:+$out, }$f"
    done
  done
  echo "$out"
}

discussion_uuid() {
  [ -f "$SESSIONS" ] || { echo ""; return; }
  grep -E '^discussion[^=]*=' "$SESSIONS" | tail -1 | cut -d= -f2 | tr -d '[:space:]'
}

rb_attempt() { # current readback attempt number (1-based; archive grows only at FIX time)
  local c; c="$(ls "$RB_ARCHIVE" 2>/dev/null | grep -c readback)"
  echo $(( ${c:-0} / 2 + 1 ))
}

ca_mode() { # -> headless|subagent (explicit flag wins; else claude_sessions.txt selects headless)
  if [ -n "$CA_MODE_FLAG" ]; then echo "$CA_MODE_FLAG"; return; fi
  if [ -f "$CA_SESSIONS" ]; then echo headless; else echo subagent; fi
}

ca_uuid() {
  [ -f "$CA_SESSIONS" ] || { echo ""; return; }
  grep -E '^discussion[^=]*=' "$CA_SESSIONS" | tail -1 | cut -d= -f2 | tr -d '[:space:]'
}

# ---------- write sentinel ----------
# Discussion phases (1–3) must leave the repo worktree untouched: collab/ is
# git-excluded, so legitimate deliverables never show up in porcelain output.
# Detection, not prevention — the flag may also be the user's own editing.
ensure_snapshot() {
  [ -f "$SNAPSHOT" ] && return
  git status --porcelain > "$SNAPSHOT"
  echo "(opening worktree snapshot recorded: $SNAPSHOT)"
}

worktree_guard() { # appends sentinel findings to the current receipt
  [ -f "$SNAPSHOT" ] || return 0
  local added
  added="$(comm -13 <(sort "$SNAPSHOT") <(git status --porcelain | sort))"
  if [ -n "$added" ]; then
    rlog "--- write sentinel ---"
    rlog "  SENTINEL FLAG: repo worktree changed since the opening snapshot (discussion phases write only collab/ files):"
    while IFS= read -r _l; do rlog "    $_l"; done <<<"$added"
    rlog "  (could be the user's own edits — O verifies; worker off-track => baseline-restore procedure)"
  fi
}

# ---------- template filling ----------
fill_template() { # template-name out-file KEY=VALUE...
  local tpl="$TPL_DIR/$1" out="$2"; shift 2
  [ -f "$tpl" ] || die "template not found: $tpl"
  if [ -s "$out" ]; then
    echo "  (prompt exists, not overwritten: $out)"
    return 0
  fi
  local content kv k v
  content="$(cat "$tpl")"
  if [[ "$content" == '<!--'* ]]; then          # strip leading usage-comment block
    content="${content#*-->}"
    content="${content#"${content%%[![:space:]]*}"}"
  fi
  for kv in "$@"; do
    k="${kv%%=*}"; v="${kv#*=}"
    content="${content//\{\{$k\}\}/$v}"
  done
  if [[ "$content" == *'{{'* ]]; then
    echo "collab-engine: WARNING — unfilled placeholders in $out:" >&2
    grep -oE '\{\{[A-Z0-9_]+\}\}' <<<"$content" | sort -u >&2
  fi
  printf '%s\n' "$content" > "$out"
  echo "  prompt generated: $out"
}

# ---------- dispute ledger ----------
ensure_ledger() {
  [ -f "$LEDGER" ] && return
  cat > "$LEDGER" <<'EOF'
# Dispute ledger (engine-maintained)
#
# Statuses: open | pending-confirm | closed-confirmed | closed-withdrawn | closed-ruled
# Engine writes rows from worker DISPUTES declarations under authority rules:
#   confirm-closed / withdrawn — accepted only from the dispute's proposer;
#   addressed (-> pending-confirm) — accepted only from the non-proposer;
#   closed-ruled — written only by O, recording a user ruling. Never by the engine.
# Summaries must not contain pipe or semicolon characters.

| id | proposer | summary | status | last-change |
|----|----------|---------|--------|-------------|
EOF
}

ledger_col() { # id field-index(3=proposer 4=summary 5=status) -> value
  awk -F'|' -v id="$1" -v col="$2" '
    { t=$2; gsub(/^[ ]+|[ ]+$/,"",t)
      if (t==id) { v=$col; gsub(/^[ ]+|[ ]+$/,"",v); print v; exit } }' "$LEDGER"
}

ledger_set() { # id status round
  local tmp="$LEDGER.tmp"
  awk -F'|' -v OFS='|' -v id="$1" -v st=" $2 " -v rd=" r$3 " '
    { t=$2; gsub(/^[ ]+|[ ]+$/,"",t)
      if (t==id) { $5=st; $6=rd }
      print }' "$LEDGER" > "$tmp" && mv "$tmp" "$LEDGER"
}

ledger_next_id() {
  local n
  n="$(grep -oE '^\| *d[0-9]+' "$LEDGER" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)"
  echo "d$(( ${n:-0} + 1 ))"
}

ledger_count() { # status-regex -> count
  local c; c="$(grep -cE "^\| *d[0-9]+ *\|[^|]*\|[^|]*\| *($1) *\|" "$LEDGER" 2>/dev/null)"
  echo "${c:-0}"
}

apply_disputes() { # SIDE(CA|CB) review-file round ; appends log lines to $RECEIPT
  local side="$1" file="$2" rn="$3"
  local line body it id st prop old new summ
  line="$(disputes_line "$file")"
  if [ -z "$line" ]; then
    rlog "  FLAG: $side review has no DISPUTES line (contract requires an explicit 'DISPUTES: none')"
    return
  fi
  body="$(trim "${line#DISPUTES:}")"
  if [ "$body" = "none" ]; then
    rlog "  $side disputes: none declared"
    return
  fi
  local IFS=';'
  for it in $body; do
    it="$(trim "$it")"
    [ -z "$it" ] && continue
    case "$it" in
      new=*)
        summ="${it#new=}"; summ="${summ%\"}"; summ="${summ#\"}"
        summ="${summ//|//}"
        if grep -qF "| $side | $summ |" "$LEDGER"; then
          rlog "  $side: new dispute already recorded (dedupe): \"$summ\""
        else
          id="$(ledger_next_id)"
          printf '| %s | %s | %s | open | r%s |\n' "$id" "$side" "$summ" "$rn" >> "$LEDGER"
          rlog "  $id: NEW open ($side, r$rn) \"$summ\""
        fi
        ;;
      d[0-9]*=*)
        id="${it%%=*}"; st="${it#*=}"
        prop="$(ledger_col "$id" 3)"
        if [ -z "$prop" ]; then
          rlog "  FLAG: $side references unknown dispute id '$id' — not applied"
          continue
        fi
        new=""
        case "$st" in
          open)           new="open" ;;
          addressed)      if [ "$side" = "$prop" ]; then
                            rlog "  FLAG: $side declared '$id=addressed' but is the proposer (proposer confirms or withdraws; cannot self-address) — not applied"
                            continue
                          fi; new="pending-confirm" ;;
          confirm-closed) if [ "$side" != "$prop" ]; then
                            rlog "  FLAG: $side declared '$id=confirm-closed' but proposer is $prop (resolution belongs to the proposer) — not applied"
                            continue
                          fi; new="closed-confirmed" ;;
          withdrawn)      if [ "$side" != "$prop" ]; then
                            rlog "  FLAG: $side declared '$id=withdrawn' but proposer is $prop — not applied"
                            continue
                          fi; new="closed-withdrawn" ;;
          *) rlog "  FLAG: $side declared unknown status '$id=$st' — not applied"; continue ;;
        esac
        old="$(ledger_col "$id" 5)"
        if [ "$old" = "$new" ]; then
          rlog "  $id: $new (unchanged, $side r$rn)"
        elif [[ "$old" == closed-* ]]; then
          # terminal states never regress via worker declarations (reopening requires
          # new facts = a NEW dispute per identity rules; only O may edit closed rows)
          rlog "  $id: stays $old ($side declared '$st' on a closed dispute — not applied)"
        else
          ledger_set "$id" "$new" "$rn"
          rlog "  $id: $old -> $new ($side, r$rn)"
        fi
        ;;
      *) rlog "  FLAG: $side unparseable DISPUTES item: '$it'" ;;
    esac
  done
}

# ---------- receipt ----------
RECEIPT=""
rlog() { echo "$1"; [ -n "$RECEIPT" ] && echo "$1" >> "$RECEIPT"; }
receipt_start() { RECEIPT="$1"; : > "$RECEIPT"; }

quote_consensus() { # SIDE file
  local line; line="$(consensus_line "$2")"
  rlog "$1 ($2):"
  rlog "  ${line:-<no CONSENSUS line found>}"
  local d; d="$(disputes_line "$2")"
  [ -n "$d" ] && rlog "  $d"
}

formal_flags() { # SIDE file kind(review|readback) ; returns 0 if formally OK
  local side="$1" file="$2" kind="$3" ok=0 v
  v="$(verdict_of "$file")"
  case "$v" in
    MISSING) rlog "  HARD FLAG: $side is missing a well-formed CONSENSUS line"; ok=1 ;;
    AGREE)   if ! agree_credentials_ok "$file"; then
               rlog "  HARD FLAG: $side AGREE has empty credential slots (residual-risk / dropped-objection) — RETURN-CANDIDATE"
               ok=1
             fi ;;
    OBJECT)  if ! object_substance_ok "$file"; then
               rlog "  HARD FLAG: $side OBJECT carries no substance after the dash — RETURN-CANDIDATE"
               ok=1
             fi ;;
  esac
  if [ "$kind" = review ]; then
    if ! has_supplement_table "$file"; then
      rlog "  FLAG: $side review has no supplement-ledger table ('| # |' header not found)"
    fi
    local ac; ac="$(anchor_count "$file")"
    if [ "${ac:-0}" -eq 0 ]; then
      rlog "  FLAG: $side review contains zero file:line anchors"
    else
      rlog "  info: $side anchor-bearing lines: $ac"
    fi
  fi
  return $ok
}

# ---------- state inference ----------
STATE=""; ROUND=0; PEN=""; NOTE=""

finalize_penner() { # -> ca|cb|"" (derives from existing finalize prompt, else parity, else override)
  if   [ -s "$COLLAB/prompts/ca-p3-finalize.md" ]; then echo ca
  elif [ -s "$COLLAB/prompts/codex-p3-finalize.md" ]; then echo cb
  elif [ -n "$PENNER_OVERRIDE" ]; then echo "$PENNER_OVERRIDE"
  else
    local n; n="$(max_round)"
    if [ "$n" -ge 2 ]; then penner_of "$n"; else echo ""; fi
  fi
}

infer_state() {
  if ! nonempty "$TOPIC"; then STATE=P0_TOPIC; return; fi

  if ! nonempty "$PROP_CA" || ! nonempty "$PROP_CB"; then
    if [ -s "$COLLAB/prompts/ca-p1.md" ] && [ -s "$COLLAB/prompts/codex-p1.md" ]; then
      STATE=P1_INFLIGHT
    else
      STATE=P1_PREP
    fi
    return
  fi

  local n; n="$(max_round)"
  if [ "$n" -eq 0 ]; then
    if [ -s "$COLLAB/prompts/ca-p2r1.md" ] && [ -s "$COLLAB/prompts/codex-p2r1.md" ]; then
      STATE=R1_INFLIGHT; ROUND=1
    else
      STATE=R1_PREP; ROUND=1
    fi
    return
  fi

  ROUND="$n"
  local caf cbf; caf="$(ca_review "$n")"; cbf="$(cb_review "$n")"

  if nonempty "$caf" && nonempty "$cbf"; then
    if [ ! -s "$COLLAB/receipts/r$n.md" ]; then STATE=RN_COLLECT; return; fi
    local va vb; va="$(verdict_of "$caf")"; vb="$(verdict_of "$cbf")"
    if [ "$va" = MISSING ] || [ "$vb" = MISSING ]; then STATE=O_ACTION; NOTE="round r$n has a missing CONSENSUS line — formal return (redo) or fix by hand, then re-run collect"; return; fi
    if [ "$va" = AGREE ] && [ "$vb" = AGREE ]; then
      if [ "$ACCEPT_HOLLOW" -eq 0 ] && { ! agree_credentials_ok "$caf" || ! agree_credentials_ok "$cbf"; }; then
        STATE=O_ACTION; NOTE="r$n double-AGREE with hollow credentials — exercise the one-time formal return, or advance --accept-hollow"; return
      fi
      # converged -> phase 3
      if ! nonempty "$PLAN"; then
        if nonempty "$COMBINED"; then STATE=FINALIZE_COLLECT; PEN="$(finalize_penner)"; return; fi
        PEN="$(finalize_penner)"
        if [ -z "$PEN" ]; then STATE=O_ACTION; NOTE="r1 convergence: no fusion draft exists, so O must pick the finalize base and penner — re-run advance with --penner ca|cb"; return; fi
        if [ -s "$COLLAB/prompts/${PEN/cb/codex}-p3-finalize.md" ] || { [ "$PEN" = ca ] && [ -s "$COLLAB/prompts/ca-p3-finalize.md" ]; }; then
          STATE=FINALIZE_INFLIGHT
        else
          STATE=FINALIZE_PREP
        fi
        return
      fi
      # PLAN exists -> readback loop
      if nonempty "$RB_CA" && nonempty "$RB_CB"; then
        local ra rb; ra="$(verdict_of "$RB_CA")"; rb="$(verdict_of "$RB_CB")"
        if [ ! -s "$COLLAB/receipts/readback-attempt$(rb_attempt).md" ]; then STATE=READBACK_COLLECT; return; fi
        if [ "$ra" = OBJECT ] || [ "$rb" = OBJECT ]; then STATE=READBACK_FIX; PEN="$(finalize_penner)"; return; fi
        if grep -qF '## Readback sign-off' "$PLAN" 2>/dev/null; then STATE=USER_GATE; else STATE=READBACK_COLLECT; fi
        return
      fi
      if [ -s "$COLLAB/prompts/ca-p3-readback.md" ] && [ -s "$COLLAB/prompts/codex-p3-readback.md" ] \
         && { nonempty "$RB_CA" || nonempty "$RB_CB" || true; }; then
        if nonempty "$RB_CA" || nonempty "$RB_CB"; then STATE=READBACK_INFLIGHT; else STATE=READBACK_INFLIGHT; fi
        return
      fi
      STATE=READBACK_PREP; return
    fi
    # at least one OBJECT -> next round
    local m=$((n + 1)); ROUND="$m"; PEN="$(penner_of "$m")"
    local pprompt sprompt pfile sfile pside sside
    pside="$PEN"; sside="$(other_side "$PEN")"
    pfile="$(side_review "$pside" "$m")"; sfile="$(side_review "$sside" "$m")"
    pprompt="$COLLAB/prompts/$([ "$pside" = ca ] && echo ca || echo codex)-p2r$m.md"
    sprompt="$COLLAB/prompts/$([ "$sside" = ca ] && echo ca || echo codex)-p2r$m.md"
    if [ ! -s "$pprompt" ]; then STATE=PENNER_PREP; return; fi
    if ! nonempty "$pfile"; then STATE=PENNER_INFLIGHT; return; fi
    if [ ! -s "$sprompt" ]; then STATE=SECOND_PREP; return; fi
    if ! nonempty "$sfile"; then STATE=SECOND_INFLIGHT; return; fi
    return
  fi

  # exactly one of the round-N reviews is in
  if [ "$n" -eq 1 ]; then STATE=R1_INFLIGHT; return; fi
  PEN="$(penner_of "$n")"
  local pfile sfile; pfile="$(side_review "$PEN" "$n")"; sfile="$(side_review "$(other_side "$PEN")" "$n")"
  if nonempty "$pfile"; then
    local sprompt; sprompt="$COLLAB/prompts/$([ "$(other_side "$PEN")" = ca ] && echo ca || echo codex)-p2r$n.md"
    if [ -s "$sprompt" ]; then STATE=SECOND_INFLIGHT; else STATE=SECOND_PREP; fi
  else
    STATE=PENNER_INFLIGHT
    nonempty "$sfile" && NOTE="sequence anomaly: second-mover review landed before the penner draft (r$n)"
  fi
}

# ---------- instruction printers ----------
print_ca_spawn() { # promptfile
  cat <<EOF
CA ACTION (O executes — spawn):
  Spawn CA via the Agent tool (subagent_type: general-purpose, run_in_background: true).
  First message = the FULL CONTENTS of: $1
  (first message must be self-contained — paste the content, not a pointer)
  Record the returned agentId in $COLLAB/agents.txt
EOF
}

print_ca_relay() { # promptfile
  cat <<EOF
CA ACTION (O executes — dumb relay, zero authorship):
  SendMessage to CA (agentId in $COLLAB/agents.txt) with exactly:
    "Next task: from the repo root, read and execute $1. All paths inside are repo-root-relative."
EOF
}

print_ca_first() { # promptfile label outfile — Phase 1 CA action, carrier-aware
  if [ "$(ca_mode)" = headless ]; then
    cat <<EOF
CA ACTION (O executes — launch in background Bash; headless carrier, route B):
  bash $CA_ROUND new $COLLAB $2 $3 discussion
EOF
  else
    print_ca_spawn "$1"
  fi
}

print_ca_task() { # promptfile label outfile [--require-consensus] — later rounds, carrier-aware
  if [ "$(ca_mode)" = headless ]; then
    local uuid; uuid="$(ca_uuid)"
    if [ -z "$uuid" ]; then
      cat <<EOF
CA ACTION: headless mode but no discussion UUID in $CA_SESSIONS.
  Run the phase-1 'new' first, or record 'discussion=<uuid>' by hand, then re-run advance.
EOF
      return
    fi
    cat <<EOF
CA ACTION (O executes — launch in background Bash; headless carrier, route B):
  bash $CA_ROUND resume $COLLAB $2 $uuid $3 ${4:-}
EOF
  else
    print_ca_relay "$1"
  fi
}

print_cb_new() { # label outfile purpose
  cat <<EOF
CB ACTION (O executes — launch in background Bash):
  bash $CB_ROUND new $COLLAB $1 read-only $2 $3
EOF
}

print_cb_resume() { # label outfile [--require-consensus]
  local uuid; uuid="$(discussion_uuid)"
  if [ -z "$uuid" ]; then
    cat <<EOF
CB ACTION: no discussion UUID found in $SESSIONS.
  If the discussion session was never created, run the phase-1 'new' first;
  otherwise record 'discussion=<uuid>' in $SESSIONS by hand, then re-run advance.
EOF
    return
  fi
  cat <<EOF
CB ACTION (O executes — launch in background Bash):
  bash $CB_ROUND resume $COLLAB $1 $uuid $2 ${3:-}
EOF
}

# ---------- advance ----------
do_advance() {
  ensure_snapshot
  infer_state
  echo "STATE: $STATE${ROUND:+ (round r$ROUND)}${PEN:+ penner=$PEN}"
  [ -n "$NOTE" ] && echo "NOTE: $NOTE"
  case "$STATE" in
    P0_TOPIC)
      echo "Phase 0 is O's own writing task (not engine work): write $TOPIC (topic, constraints, code entry points, acceptance criteria, out-of-scope), then re-run advance." ;;
    P1_PREP)
      echo "Preparing Phase 1 (independent proposals, anti-anchoring — parallel, isolated):"
      fill_template ca-first.md "$COLLAB/prompts/ca-p1.md" \
        "COLLAB_DIR=$COLLAB"
      fill_template cb-first.md "$COLLAB/prompts/codex-p1.md" \
        "COLLAB_DIR=$COLLAB"
      echo
      print_ca_first "$COLLAB/prompts/ca-p1.md" ca-p1 "$PROP_CA"
      echo
      print_cb_new codex-p1 "$PROP_CB" discussion
      echo
      echo "Run both actions in the SAME message (true parallelism). When both outputs land, run: collect" ;;
    P1_INFLIGHT)
      echo "Waiting for proposals:"
      nonempty "$PROP_CA" && echo "  CA proposal: LANDED" || echo "  CA proposal: pending ($PROP_CA)"
      nonempty "$PROP_CB" && echo "  CB proposal: LANDED" || echo "  CB proposal: pending ($PROP_CB)"
      echo "Re-run instructions if a launch was lost:"
      print_ca_first "$COLLAB/prompts/ca-p1.md" ca-p1 "$PROP_CA"
      print_cb_new codex-p1 "$PROP_CB" discussion ;;
    R1_PREP)
      ensure_ledger
      echo "Preparing r1 (blind symmetric cross-review — parallel, neither sees the other's review):"
      fill_template review-r1.md "$COLLAB/prompts/ca-p2r1.md" \
        "COLLAB_DIR=$COLLAB" "PEER_PROPOSAL=$PROP_CB" "OWN_PROPOSAL=$PROP_CA" \
        "OUT_FILE=$(ca_review 1)"
      fill_template review-r1.md "$COLLAB/prompts/codex-p2r1.md" \
        "COLLAB_DIR=$COLLAB" "PEER_PROPOSAL=$PROP_CA" "OWN_PROPOSAL=$PROP_CB" \
        "OUT_FILE=$(cb_review 1)"
      echo
      print_ca_task "$COLLAB/prompts/ca-p2r1.md" ca-p2r1 "$(ca_review 1)" --require-consensus
      echo
      print_cb_resume codex-p2r1 "$(cb_review 1)" --require-consensus
      echo
      echo "Run both in the SAME message. When both reviews land, run: collect" ;;
    R1_INFLIGHT)
      echo "Waiting for r1 reviews:"
      nonempty "$(ca_review 1)" && echo "  CA r1: LANDED" || echo "  CA r1: pending"
      nonempty "$(cb_review 1)" && echo "  CB r1: LANDED" || echo "  CB r1: pending" ;;
    RN_COLLECT)
      echo "Round r$ROUND outputs are both in but not collected. Run: collect (ledger must be applied before the next round's prompts reference it)." ;;
    O_ACTION)
      echo "O must act before the engine can proceed." ;;
    PENNER_PREP)
      local pside="$PEN" pfx
      pfx="$([ "$pside" = ca ] && echo ca || echo codex)"
      echo "Preparing r$ROUND penner ($(side_name "$pside") writes the fusion draft first; second mover follows):"
      fill_template review-conv-penner.md "$COLLAB/prompts/$pfx-p2r$ROUND.md" \
        "N=$ROUND" "COLLAB_DIR=$COLLAB" \
        "REVIEW_FILES=$(review_files_upto $((ROUND - 1)))" \
        "OUT_FILE=$(side_review "$pside" "$ROUND")"
      echo
      if [ "$pside" = ca ]; then
        print_ca_task "$COLLAB/prompts/ca-p2r$ROUND.md" "ca-p2r$ROUND" "$(ca_review "$ROUND")" --require-consensus
      else
        print_cb_resume "codex-p2r$ROUND" "$(cb_review "$ROUND")" --require-consensus
      fi
      echo
      echo "When the penner review lands, re-run advance to prepare the second mover." ;;
    PENNER_INFLIGHT)
      echo "Waiting for r$ROUND penner ($(side_name "$PEN")) review: $(side_review "$PEN" "$ROUND")" ;;
    SECOND_PREP)
      local sside pfx
      sside="$(other_side "$PEN")"
      pfx="$([ "$sside" = ca ] && echo ca || echo codex)"
      echo "Preparing r$ROUND second mover ($(side_name "$sside") audits the fusion draft):"
      fill_template review-conv-second.md "$COLLAB/prompts/$pfx-p2r$ROUND.md" \
        "N=$ROUND" "COLLAB_DIR=$COLLAB" \
        "REVIEW_FILES=$(review_files_upto $((ROUND - 1)))" \
        "DRAFT_FILE=$(side_review "$PEN" "$ROUND")" \
        "OUT_FILE=$(side_review "$sside" "$ROUND")"
      echo
      if [ "$sside" = ca ]; then
        print_ca_task "$COLLAB/prompts/ca-p2r$ROUND.md" "ca-p2r$ROUND" "$(ca_review "$ROUND")" --require-consensus
      else
        print_cb_resume "codex-p2r$ROUND" "$(cb_review "$ROUND")" --require-consensus
      fi
      echo
      echo "When the second review lands, run: collect" ;;
    SECOND_INFLIGHT)
      echo "Waiting for r$ROUND second mover ($(side_name "$(other_side "$PEN")")) review." ;;
    FINALIZE_PREP)
      local pfx tpl outc
      pfx="$([ "$PEN" = ca ] && echo ca || echo codex)"
      tpl="plan-finalize-$([ "$PEN" = ca ] && echo ca || echo cb).md"
      echo "Converged. Preparing Phase 3 finalize (penner $(side_name "$PEN") writes PLAN/TASKS — O does not hold the pen):"
      fill_template "$tpl" "$COLLAB/prompts/$pfx-p3-finalize.md" \
        "COLLAB_DIR=$COLLAB" \
        "FINAL_DRAFT_FILE=$(side_review "$PEN" "$(max_round)")" \
        "REVIEW_FILES=$(review_files_upto "$(max_round)")" \
        "DRIFT_FILES=(none — first finalize pass)"
      echo
      if [ "$PEN" = ca ]; then
        print_ca_task "$COLLAB/prompts/ca-p3-finalize.md" ca-p3-finalize "$PLAN"
        echo "CA writes $PLAN and $TASKS directly; when they land, re-run advance (moves straight to readback)."
      else
        print_cb_resume codex-p3-finalize "$COMBINED"
        echo "CB output is one combined file; when it lands, run collect (splits it into 30/31)."
      fi ;;
    FINALIZE_INFLIGHT)
      echo "Waiting for finalize output from $(side_name "$PEN") (then run collect)." ;;
    FINALIZE_COLLECT)
      echo "Combined finalize output landed. Run: collect (splits $COMBINED into $PLAN + $TASKS)." ;;
    READBACK_PREP)
      echo "Preparing readback (both sides re-read the FULL PLAN/TASKS; drift check against the penner):"
      fill_template plan-readback.md "$COLLAB/prompts/ca-p3-readback.md" \
        "COLLAB_DIR=$COLLAB" "OUT_FILE=$RB_CA"
      fill_template plan-readback.md "$COLLAB/prompts/codex-p3-readback.md" \
        "COLLAB_DIR=$COLLAB" "OUT_FILE=$RB_CB"
      echo
      print_ca_task "$COLLAB/prompts/ca-p3-readback.md" ca-p3-readback "$RB_CA" --require-consensus
      echo
      print_cb_resume codex-p3-readback "$RB_CB" --require-consensus
      echo
      echo "Run both in the SAME message. When both readbacks land, run: collect" ;;
    READBACK_INFLIGHT)
      echo "Waiting for readbacks:"
      nonempty "$RB_CA" && echo "  CA readback: LANDED" || echo "  CA readback: pending"
      nonempty "$RB_CB" && echo "  CB readback: LANDED" || echo "  CB readback: pending" ;;
    READBACK_COLLECT)
      echo "Both readbacks in. Run: collect" ;;
    READBACK_FIX)
      # Treat the fix as a fresh finalize pass: archive the objected readbacks AND the
      # drifted PLAN/TASKS, then regenerate the standard finalize prompt with the drift
      # inputs filled. The existing FINALIZE_* / READBACK_* states then handle the rest.
      mkdir -p "$RB_ARCHIVE"
      local attempt; attempt="$(rb_attempt)"
      local pfx tpl drift="" base f
      for f in "$RB_CA" "$RB_CB"; do
        [ -e "$f" ] || continue
        base="$(basename "$f" .md)"
        mv "$f" "$RB_ARCHIVE/${base}-attempt${attempt}.md"
        drift="${drift:+$drift, }$RB_ARCHIVE/${base}-attempt${attempt}.md"
      done
      [ -e "$PLAN" ]  && mv "$PLAN"  "$RB_ARCHIVE/30_PLAN-attempt${attempt}.md"  && drift="$drift; previous PLAN: $RB_ARCHIVE/30_PLAN-attempt${attempt}.md"
      [ -e "$TASKS" ] && mv "$TASKS" "$RB_ARCHIVE/31_TASKS-attempt${attempt}.md" && drift="$drift; previous TASKS: $RB_ARCHIVE/31_TASKS-attempt${attempt}.md"
      rm -f "$COMBINED" \
            "$COLLAB/prompts/ca-p3-finalize.md" "$COLLAB/prompts/codex-p3-finalize.md" \
            "$COLLAB/prompts/ca-p3-readback.md" "$COLLAB/prompts/codex-p3-readback.md"
      echo "Readback OBJECT — archived readbacks + drifted PLAN/TASKS to $RB_ARCHIVE (attempt $attempt)."
      pfx="$([ "$PEN" = ca ] && echo ca || echo codex)"
      tpl="plan-finalize-$([ "$PEN" = ca ] && echo ca || echo cb).md"
      fill_template "$tpl" "$COLLAB/prompts/$pfx-p3-finalize.md" \
        "COLLAB_DIR=$COLLAB" \
        "FINAL_DRAFT_FILE=$(side_review "$PEN" "$(max_round)")" \
        "REVIEW_FILES=$(review_files_upto "$(max_round)")" \
        "DRIFT_FILES=$drift"
      echo
      if [ "$PEN" = ca ]; then
        print_ca_task "$COLLAB/prompts/ca-p3-finalize.md" ca-p3-finalize "$PLAN"
        echo "CA rewrites $PLAN and $TASKS directly; when they land, re-run advance (readback re-runs for both sides)."
      else
        print_cb_resume codex-p3-finalize "$COMBINED"
        echo "CB output is one combined file; when it lands, run collect (re-split), then advance (readback re-runs)."
      fi
      echo
      echo "Drift repair is O's fidelity duty routed to the penner — it does NOT count against Phase 2 rounds." ;;
    USER_GATE)
      echo "Readback signed off. ENGINE END STATE (step-1 scope) — O assembles the approval package:"
      echo "  - $PLAN + $TASKS (worker-authored; O adds NOTHING to their substance)"
      echo "  - shared-assumptions list: mechanically extract residual-risk / dropped-objection lines from all AGREE credentials"
      echo "  - O's only authored text: a 3–5 line reading guide"
      echo "  - present to the user for approval; on approval append 'User approved <date>' to $PLAN"
      echo "Phases 4–7 (implementation, review, integration, summary) stay on the manual flow in SKILL.md." ;;
    *) echo "Unhandled state: $STATE" ;;
  esac
}

# ---------- collect ----------
do_collect() {
  ensure_snapshot
  infer_state
  case "$STATE" in
    RN_COLLECT|SECOND_INFLIGHT|PENNER_INFLIGHT|R1_INFLIGHT|P1_INFLIGHT|FINALIZE_COLLECT|READBACK_COLLECT|FINALIZE_INFLIGHT|READBACK_INFLIGHT|O_ACTION) ;;
    *) echo "STATE: $STATE — nothing to collect here; run status/advance."; return ;;
  esac

  case "$STATE" in
    P1_INFLIGHT)
      echo "Proposals not both in yet:"
      nonempty "$PROP_CA" && echo "  CA: LANDED" || echo "  CA: pending ($PROP_CA)"
      nonempty "$PROP_CB" && echo "  CB: LANDED" || echo "  CB: pending ($PROP_CB)"
      echo "(once both land, state moves to R1_PREP — run advance)" ;;
    R1_INFLIGHT|PENNER_INFLIGHT|SECOND_INFLIGHT|FINALIZE_INFLIGHT|READBACK_INFLIGHT)
      echo "STATE: $STATE — still waiting; nothing to collect yet."; return ;;
    O_ACTION)
      echo "STATE: O_ACTION — $NOTE"; return ;;
    RN_COLLECT)
      local n="$ROUND" caf cbf
      caf="$(ca_review "$n")"; cbf="$(cb_review "$n")"
      ensure_ledger
      receipt_start "$COLLAB/receipts/r$n.md"
      rlog "=== RECEIPT r$n (phase2) ==="
      quote_consensus CA "$caf"
      quote_consensus CB "$cbf"
      rlog "--- formal precheck ---"
      local bad=0
      formal_flags CA "$caf" review || bad=1
      formal_flags CB "$cbf" review || bad=1
      rlog "--- ledger application (authority-checked, chronological: penner first) ---"
      # r2+: the penner declares before seeing nothing; the second mover declares after
      # reading the draft — the informed, later declaration must be applied last so it
      # wins same-round conflicts. r1 is blind-parallel and its ledger is empty
      # beforehand (only new= items), so order cannot matter there.
      if [ "$n" -ge 2 ] && [ "$(penner_of "$n")" = cb ]; then
        apply_disputes CB "$cbf" "$n"
        apply_disputes CA "$caf" "$n"
      else
        apply_disputes CA "$caf" "$n"
        apply_disputes CB "$cbf" "$n"
      fi
      local open pend
      open="$(ledger_count 'open')"; pend="$(ledger_count 'pending-confirm')"
      rlog "--- ledger summary: open=$open pending-confirm=$pend ---"
      worktree_guard
      local va vb; va="$(verdict_of "$caf")"; vb="$(verdict_of "$cbf")"
      if [ "$va" = MISSING ] || [ "$vb" = MISSING ]; then
        rlog "VERDICT: O-ACTION — missing CONSENSUS line; exercise the formal return (redo lands in the same round) or fix by hand"
      elif [ "$va" = AGREE ] && [ "$vb" = AGREE ]; then
        if [ "$bad" -eq 1 ]; then
          rlog "VERDICT: RETURN-CANDIDATE — double AGREE with formal defects; O may return ONCE per output (redo stays round r$n), or advance --accept-hollow"
        else
          if [ "$open" -gt 0 ] || [ "$pend" -gt 0 ]; then
            rlog "FLAG: double AGREE but ledger still shows open/pending disputes — likely a forgotten confirm-close; O checks before advancing"
          fi
          local fp; fp="$(finalize_penner)"
          rlog "VERDICT: CONVERGED -> Phase 3 finalize (penner: ${fp:-'O must pick via advance --penner ca|cb (r1 convergence)'})"
        fi
      else
        local m=$((n + 1))
        rlog "VERDICT: CONTINUE -> r$m (penner: $(side_name "$(penner_of "$m")"))"
        [ "$bad" -eq 1 ] && rlog "NOTE: formal defects flagged above — O may exercise the one-time return before continuing"
      fi
      rlog "NEXT: advance"
      echo
      echo "(receipt saved: $COLLAB/receipts/r$n.md)" ;;
    FINALIZE_COLLECT)
      receipt_start "$COLLAB/receipts/finalize.md"
      rlog "=== RECEIPT finalize ==="
      if nonempty "$COMBINED" && ! nonempty "$PLAN"; then
        awk -v plan="$PLAN" -v tasks="$TASKS" '
          /<!-- FILE: 30_PLAN\.md -->/  { f=1; next }
          /<!-- FILE: 31_TASKS\.md -->/ { f=2; next }
          f==1 { print > plan }
          f==2 { print > tasks }' "$COMBINED"
        rlog "split $COMBINED -> $PLAN + $TASKS"
      fi
      if nonempty "$PLAN" && nonempty "$TASKS"; then
        rlog "PLAN: $PLAN ($(wc -l < "$PLAN") lines)"
        rlog "TASKS: $TASKS ($(wc -l < "$TASKS") lines)"
        worktree_guard
        rlog "VERDICT: FINALIZE-IN"
        rlog "NEXT: advance (prepares readback for both sides)"
      else
        rlog "VERDICT: SPLIT-FAILED — check $COMBINED for the '<!-- FILE: 30_PLAN.md -->' / '<!-- FILE: 31_TASKS.md -->' markers"
      fi ;;
    READBACK_COLLECT)
      receipt_start "$COLLAB/receipts/readback-attempt$(rb_attempt).md"
      rlog "=== RECEIPT readback (attempt $(rb_attempt)) ==="
      quote_consensus CA "$RB_CA"
      quote_consensus CB "$RB_CB"
      rlog "--- formal precheck ---"
      local bad=0
      formal_flags CA "$RB_CA" readback || bad=1
      formal_flags CB "$RB_CB" readback || bad=1
      worktree_guard
      local ra rb; ra="$(verdict_of "$RB_CA")"; rb="$(verdict_of "$RB_CB")"
      if [ "$ra" = AGREE ] && [ "$rb" = AGREE ] && [ "$bad" -eq 0 ]; then
        if ! grep -qF '## Readback sign-off' "$PLAN"; then
          {
            echo
            echo "## Readback sign-off"
            echo
            echo "CA: $(consensus_line "$RB_CA")"
            echo "CB: $(consensus_line "$RB_CB")"
          } >> "$PLAN"
          rlog "sign-off appended to $PLAN (verbatim CONSENSUS lines)"
        else
          rlog "sign-off already present in $PLAN (idempotent skip)"
        fi
        rlog "VERDICT: READBACK-PASS"
        rlog "NEXT: advance (prints the user-gate assembly checklist)"
      elif [ "$ra" = OBJECT ] || [ "$rb" = OBJECT ]; then
        rlog "VERDICT: READBACK-OBJECT — drift claimed; NEXT: advance (archives readbacks, routes the fix to the penner; does NOT count against Phase 2 rounds)"
      else
        rlog "VERDICT: O-ACTION — formal defect in a readback (see flags)"
      fi ;;
  esac
}

# ---------- status ----------
do_status() {
  infer_state
  echo "collab:  $COLLAB"
  echo "STATE:   $STATE"
  [ "$ROUND" -gt 0 ] && echo "round:   r$ROUND"
  [ -n "$PEN" ] && echo "penner:  $(side_name "$PEN")"
  [ -n "$NOTE" ] && echo "note:    $NOTE"
  if [ -f "$LEDGER" ]; then
    echo "ledger:  open=$(ledger_count 'open') pending-confirm=$(ledger_count 'pending-confirm') closed=$(ledger_count 'closed-[a-z]+')"
  else
    echo "ledger:  (not created yet)"
  fi
  echo
  case "$STATE" in
    *_PREP|P0_TOPIC|READBACK_FIX) echo "NEXT: advance" ;;
    *_INFLIGHT)                   echo "NEXT: wait for outputs, then collect (or advance to re-print launch instructions)" ;;
    *_COLLECT|RN_COLLECT)         echo "NEXT: collect" ;;
    O_ACTION)                     echo "NEXT: O acts (see note), then advance/collect" ;;
    USER_GATE)                    echo "NEXT: advance (prints the approval-package checklist)" ;;
  esac
}

case "$CMD" in
  status)  do_status ;;
  advance) do_advance ;;
  collect) do_collect ;;
esac
