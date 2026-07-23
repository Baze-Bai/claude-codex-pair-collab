# pair-collab

**[English →](README.md)**

一个 [Claude Code](https://claude.com/claude-code) skill,编排**由确定性回合引擎驱动的 Claude × Codex 双智能体结对协作协议**:两个对称的 AI 工程师各自独立提案、在引擎管理的回合下对抗式交叉评审、收敛成由 worker 亲笔的共识方案;经用户明确批准后由一方实现、另一方全量审查 diff。发起 skill 的会话充当严格**中立的 Orchestrator**——不下场编码、不持技术立场、不执共识之笔。

## 为什么

两个 LLM 互相礼貌附和毫无价值。本协议针对这一失败模式做了工程化设计:

- **防锚定**:两侧并行独立写提案,互相看不到对方草稿;评审第 1 轮同样是盲态对称对审。
- **AGREE 有成本**:裸 AGREE 会被机械拒收。每个 AGREE 必须附带「残余风险」和「放弃的最强反对」。r1 就双 AGREE 且反对为空,按红旗处理而非好兆头。
- **分歧属于提出方——且由机器强制**:每份评审以机器可读的 `DISPUTES:` 行结尾,引擎按**权属规则**把声明记入台账(只有提出方能 confirm-close 或 withdraw;已关闭的分歧不因 worker 声明回退)。任何人——包括 Orchestrator——都无法替提出方关闭分歧。
- **全程零转述**:worker 直接读盘看对方原文;引擎回执只引用逐字摘录;共识 PLAN 由执笔最后一版融合草案的 worker 按「搬运不重写」契约亲笔,再由双方定稿复读查漂移(漏搬/压缩/加料)。Orchestrator 在批准包里唯一亲笔的文字是 3–5 行导读。
- **实证优先**:关于现状代码行为的关键断言必须附 `file:line` 锚点,对方会抽查真伪;凡可由只读实验判定的分歧,径行实验、呈证优先于论辩。
- **用户是唯一的非 LLM 检查点**:方案批准闸门与集成测试被明确定位为「兜住两个模型共有盲区」的最后防线。skill 要求 Orchestrator 把这一点向用户明说,而不是让「两个 AI 评审过」伪装成充分把关。

## 架构

| 角色 | 承载 | 职责 |
|---|---|---|
| Orchestrator(O) | 发起 skill 的 Claude Code 会话 | 中立编排:跑引擎命令、执行其打印的发射动作、做引擎做不了的语义判定、处理异常、亲自跑集成测试——**不编码、不持技术立场、不执共识之笔** |
| 回合引擎 | `scripts/collab-engine.sh`(确定性状态机) | 从盘上文件推断状态、机械填充模板、编排回合次序、形式预检产出、按权属规则维护分歧台账、产出逐字摘录回执——**从不调用 LLM、从不判断对错** |
| 工程师 A(CA) | headless `claude -p` CLI 会话(默认)或 Claude subagent(回落) | 提案、评审、实现或审查 |
| 工程师 B(CB) | Codex CLI(`codex exec` 无头调用) | 提案、评审、实现或审查 |
| 用户 | 你 | 出题;批准方案;裁决真分歧 |

流程:`Phase 0` 开题 → `1` 独立提案(并行、隔离)→ `2` 交叉评审收敛(≤10 轮;引擎排序,O 判定)→ `3` 共识 PLAN/TASKS **由 finalize penner 亲笔**、双侧定稿复读核验后过**用户批准闸门** → `4` 实现(默认单 owner;PLAN 修正案走正式程序)→ `5` 非 owner 全量 diff 审查(修复↔验收 3 次上限 + 可核验关闭标准)→ `6` O 亲自集成验证 → `7` 总结 + 协作收益审计。引擎覆盖 Phase 1–3 的 happy path;Phase 4–7 与全部异常路径仍归 O。

所有产出落盘 `collab/<date>-<slug>/` 纯 Markdown 文件——**盘上文件是流程状态的唯一权威**(引擎自身零状态),整个协作可跨会话中断与上下文压缩恢复。

## 前提

- **Claude Code**(本体是它的 skill)。
- **Codex CLI**:`npm install -g @openai/codex` 并已登录(与 Codex 桌面 App 共享 `~/.codex`)。
- Claude Code 可用 **Bash**(Windows 上为 Git Bash)——全部 worker 调用经封装脚本以 stdin 驱动。
- 默认的 headless-CA 承载需要**独立 Claude CLI 已认证**:运行一次 `claude setup-token`(桌面 App 托管的登录态到不了嵌套的 `claude -p`)。没配也能用——自动回落 subagent 承载。

## 安装

在你的项目根目录:

```bash
git clone https://github.com/Baze-Bai/claude-codex-pair-collab.git .claude/skills/pair-collab
```

建议把 `collab/`(每主题工作区)加入 `.git/info/exclude`——引擎的越界哨兵以此为前提。

## 用法

```
/pair-collab <主题描述>
```

Orchestrator 会建好主题工作区、经引擎并行驱动两侧工程师,常规流程只在两个节点回来找你:方案批准、真分歧裁决。

完整操作说明见 **[使用指南](USAGE.zh-CN.md)**:前提配置、你会被需要的节点、产出物地图、故障恢复、成本注意事项。

## 仓库结构

```
SKILL.md      # 协议本体(全部契约文字的规范源)
templates/    # 11 个 prompt 模板(8 个引擎填充:提案/评审/定稿/复读;
              #  3 个 O 手动填充,用于手动阶段:修正案/实现/审查)
scripts/
  collab-engine.sh  # 回合引擎:status / advance / collect(Phase 1–3 happy path)
  ca-round.sh       # headless-CA 调用封装:会话钉扎、单写者锁、
                    #  权限钉扎+deny 表、产出预检
  cb-round.sh       # Codex 调用封装:stdin 喂入、日志、session id 抓取、
                    #  单写者锁、模型/effort 钉扎(默认 gpt-5.6-sol / xhigh,
                    #  env CB_MODEL / CB_EFFORT 覆盖)、产出预检
```

## 语言

协议正文与模板为**英文**。Orchestrator 用你的语言与你沟通,collab 文档跟随你的工作语言(代码与命令保留英文)。

## 机制局限(诚实声明)

CA、CB、乃至 O 同为 LLM(O 也是 Claude,不构成独立第三方视角)。交叉评审只能覆盖两个模型**不重叠**的盲区;对共有盲区(近期 API 变更、隐性 repo 约束、安全威胁建模、并发与失败模式、以及双方都被训练得倾向附和)无免疫。引擎给**程序**加确定性,不给**判断**加智能——它消除的是转述漂移与记账差错,仅此而已。给 AGREE 加成本、给 O 退回权、机械化权属规则,只**降低**而非**消除**礼貌趋同——真正兜住共同盲区的是用户批准闸门与集成测试这两个非 LLM 检查点。skill 明确要求 Orchestrator 向用户点明这一点。

## License

MIT
