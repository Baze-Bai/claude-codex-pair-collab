#!/usr/bin/env bash
# pair-collab:CB(Codex)调用统一封装 —— SKILL.md「驱动工程师 B」的默认入口;
# 原始命令见该节(本脚本故障时的降级路径)。
# 统一处理:stdin 喂 prompt(防 PowerShell stdin EOF 卡死)、tee 日志、抓取并登记 session id、
# per-UUID 单写者锁(把「单写者规则」从纪律变成机制)、产出形式预检(非空 / CONSENSUS 行)。
#
# 用法(在 repo 内任意目录调用;collab 目录与输出文件用 repo 根相对路径):
#   bash cb-round.sh new    <collab目录> <标签> <read-only|workspace-write> <输出文件> <purpose> [--require-consensus]
#   bash cb-round.sh resume <collab目录> <标签> <UUID> <输出文件> [--require-consensus]
#
#   <标签>    prompt/日志名:读 <collab目录>/prompts/<标签>.md,日志写同目录 <标签>.log(命名规范 codex-pNrM)
#   <purpose> new 专用,记入 codex_sessions.txt(规范值 discussion / implementation;降级重建可用 discussion-2 等)
#   --require-consensus  评审/定稿复读/审查/修正案轮加:产出须含行首 `CONSENSUS: AGREE|OBJECT`
#   CB_EFFORT 环境变量  reasoning effort 档位,默认 xhigh;每次调用(含 resume)显式下发,
#                       把 effort 从「随 ~/.codex/config.toml 漂移」钉成 skill 默认(model 不钉,仍随 config)
#
# 退出码:0 成功;2 codex 退出非 0;3 输出文件为空;4 缺 CONSENSUS 行(形式不合格,O 按退回权处理);
#         5 UUID 锁冲突(单写者);6 参数/前置错误;7 codex 成功但未抓到 session id(产出仍有效,人工补记)
set -u -o pipefail

CB_EFFORT="${CB_EFFORT:-xhigh}"

usage_die() { echo "cb-round: $*" >&2; exit 6; }

MODE="${1:-}"
case "$MODE" in
  new|resume) ;;
  *) usage_die "未知模式 '${MODE}'(用 new|resume,详见文件头)" ;;
esac

COLLAB="${2:-}"; LABEL="${3:-}"
[ -n "$COLLAB" ] && [ -n "$LABEL" ] || usage_die "参数不足(见文件头用法)"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || usage_die "必须在 repo 内运行"
cd "$REPO_ROOT" || usage_die "无法进入 repo 根:$REPO_ROOT"
[ -d "$COLLAB" ] || usage_die "collab 目录不存在:$COLLAB"

PROMPT="$COLLAB/prompts/$LABEL.md"
LOG="$COLLAB/prompts/$LABEL.log"
[ -s "$PROMPT" ] || usage_die "prompt 缺失或为空:$PROMPT(先 Write 好再调用)"

REQUIRE_CONSENSUS=0
SANDBOX=""; UUID=""; OUTFILE=""; PURPOSE=""
if [ "$MODE" = new ]; then
  SANDBOX="${4:-}"; OUTFILE="${5:-}"; PURPOSE="${6:-}"
  case "$SANDBOX" in
    read-only|workspace-write) ;;
    *) usage_die "sandbox 须为 read-only|workspace-write,得到 '${SANDBOX}'" ;;
  esac
  [ -n "$OUTFILE" ] && [ -n "$PURPOSE" ] || usage_die "new 需要 <输出文件> <purpose>"
  [ "${7:-}" = "--require-consensus" ] && REQUIRE_CONSENSUS=1
else
  UUID="${4:-}"; OUTFILE="${5:-}"
  [ -n "$UUID" ] && [ -n "$OUTFILE" ] || usage_die "resume 需要 <UUID> <输出文件>"
  echo "$UUID" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' \
    || usage_die "resume 一律用 UUID(线程名不唯一不稳定),得到 '${UUID}'"
  [ "${6:-}" = "--require-consensus" ] && REQUIRE_CONSENSUS=1
fi

# per-UUID 单写者锁(仅 resume;两次 new 是不同会话,无冲突)
if [ "$MODE" = resume ]; then
  mkdir -p "$COLLAB/.locks"
  LOCKDIR="$COLLAB/.locks/$UUID"
  if ! mkdir "$LOCKDIR" 2>/dev/null; then
    echo "cb-round: 锁冲突 —— $LOCKDIR 已存在(holder pid: $(cat "$LOCKDIR/pid" 2>/dev/null || echo '?'))" >&2
    echo "cb-round: 单写者规则:先确认前次对该 UUID 的任务确已退出,再手工删除该锁目录重试" >&2
    exit 5
  fi
  echo $$ > "$LOCKDIR/pid"
  trap 'rm -rf "$LOCKDIR"' EXIT
fi

RC=0
if [ "$MODE" = new ]; then
  codex exec -C "$REPO_ROOT" -s "$SANDBOX" -c model_reasoning_effort="$CB_EFFORT" -o "$OUTFILE" - < "$PROMPT" 2>&1 | tee "$LOG" || RC=$?
else
  codex exec resume "$UUID" -c model_reasoning_effort="$CB_EFFORT" -o "$OUTFILE" - < "$PROMPT" 2>&1 | tee "$LOG" || RC=$?
fi
if [ "$RC" -ne 0 ]; then
  echo "cb-round: codex 退出码 $RC,读 $LOG 排查(必要时加 --json 重跑)" >&2
  exit 2
fi

[ -s "$OUTFILE" ] || { echo "cb-round: 输出为空:$OUTFILE(读 $LOG)" >&2; exit 3; }

if [ "$REQUIRE_CONSENSUS" -eq 1 ] && ! grep -qE '^CONSENSUS: (AGREE|OBJECT)' "$OUTFILE"; then
  echo "cb-round: 产出缺 CONSENSUS 行(形式不合格):$OUTFILE —— O 按退回权处理" >&2
  exit 4
fi

if [ "$MODE" = new ]; then
  SESSIONS="$COLLAB/codex_sessions.txt"
  SID="$(grep -m1 -oE 'session id: [0-9a-f-]+' "$LOG" | sed 's/^session id: //')"
  if [ -z "$SID" ]; then
    echo "cb-round: 产出有效但未从 $LOG 抓到 session id(banner 格式漂移?)——人工补记 $SESSIONS" >&2
    exit 7
  fi
  if [ ! -f "$SESSIONS" ] || ! grep -q '^# codex ' "$SESSIONS"; then
    echo "# codex $(codex --version 2>/dev/null | head -n1)" >> "$SESSIONS"
  fi
  echo "$PURPOSE=$SID" >> "$SESSIONS"
  echo "cb-round: session_id=$SID(已记入 $SESSIONS)"
fi

echo "cb-round: OK → $OUTFILE"
