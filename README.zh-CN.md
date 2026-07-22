# pair-collab

**[English →](README.md)**

一个 [Claude Code](https://claude.com/claude-code) skill,编排 **Claude × Codex 双智能体结对协作协议**:两个对称的 AI 工程师各自独立提案、对抗式交叉评审、收敛成共识方案,经用户明确批准后由一方实现、另一方全量审查。发起 skill 的会话充当严格**中立的 Orchestrator**——不下场编码、不持技术立场。

## 为什么

两个 LLM 互相礼貌附和毫无价值。本协议针对这一失败模式做了工程化设计:

- **防锚定**:两侧并行独立写提案,互相看不到对方草稿;评审第 1 轮同样是盲态对称对审。
- **AGREE 有成本**:裸 AGREE 不合格。每个 AGREE 必须附带「残余风险」和「放弃的最强反对」。r1 就双 AGREE 且反对为空,按红旗处理而非好兆头。
- **分歧属于提出方**:只有提出方能关闭自己的分歧(确认、撤回、或用户裁决)。Orchestrator 只记台账,无权替任何一方宣告分歧已解决。
- **实证优先**:关于现状代码行为的关键断言必须附 `file:line` 锚点,对方会抽查真伪;凡可由只读实验判定的分歧,径行实验、呈证优先于论辩。
- **用户是唯一的非 LLM 检查点**:方案批准闸门与集成测试被明确定位为「兜住两个模型共有盲区」的最后防线。skill 要求 Orchestrator 把这一点向用户明说,而不是让「两个 AI 评审过」伪装成充分把关。

## 架构

| 角色 | 承载 | 职责 |
|---|---|---|
| Orchestrator(O) | 发起 skill 的 Claude Code 会话 | 中立编排:派活、传话、共识记账、集成测试、总结——**不编码、不持技术立场** |
| 工程师 A(CA) | O 派生的 Claude subagent(后台) | 提案、评审、实现或审查 |
| 工程师 B(CB) | Codex CLI(`codex exec` 无头调用) | 提案、评审、实现或审查 |
| 用户 | 你 | 出题;批准方案;裁决真分歧 |

流程:`Phase 0` 开题 → `1` 独立提案(并行、隔离)→ `2` 交叉评审收敛(≤10 轮,分歧台账)→ `3` 共识 PLAN/TASKS + **用户批准闸门** → `4` 实现(默认单 owner;PLAN 修正案走正式程序)→ `5` 非 owner 全量 diff 审查(修复↔验收 3 次上限 + 可核验关闭标准)→ `6` O 亲自集成验证 → `7` 总结 + 协作收益审计。

所有产出落盘 `collab/<date>-<slug>/` 纯 Markdown 文件——**盘上文件是流程状态的唯一权威**,整个协作可跨会话中断与上下文压缩恢复。

## 前提

- **Claude Code**(本体是它的 skill)。
- **Codex CLI**:`npm install -g @openai/codex` 并已登录(与 Codex 桌面 App 共享 `~/.codex`)。
- Claude Code 可用 **Bash**(Windows 上为 Git Bash)——Codex 调用经 `scripts/cb-round.sh` 以 stdin 驱动。

## 安装

在你的项目根目录:

```bash
git clone https://github.com/Baze-Bai/claude-codex-pair-collab.git .claude/skills/pair-collab
```

建议把 `collab/`(每主题工作区)加入 `.git/info/exclude`。

## 用法

```
/pair-collab <主题描述>
```

Orchestrator 会建好主题工作区、并行驱动两侧工程师,常规流程只在两个节点回来找你:方案批准、真分歧裁决。

完整操作说明见 **[使用指南](USAGE.zh-CN.md)**:前提配置、你会被需要的节点、产出物地图、故障恢复、成本注意事项。

## 仓库结构

```
SKILL.md      # 协议本体(规范源)
templates/    # 8 个派活 prompt 底稿(提案/评审/定稿复读/修正案/实现/审查)
scripts/
  cb-round.sh # Codex 调用统一封装:stdin 喂 prompt、tee 日志、抓取 session id、
              # per-UUID 单写者锁、产出形式预检(非空 / CONSENSUS 行)
```

## 机制局限(诚实声明)

CA、CB、乃至 O 同为 LLM(O 也是 Claude,不构成独立第三方视角)。交叉评审只能覆盖两个模型**不重叠**的盲区;对共有盲区(近期 API 变更、隐性 repo 约束、安全威胁建模、并发与失败模式、以及双方都被训练得倾向附和)无免疫。给 AGREE 加成本、给 O 退回权,只**降低**而非**消除**礼貌趋同——真正兜住共同盲区的是用户批准闸门与集成测试这两个非 LLM 检查点。skill 明确要求 Orchestrator 向用户点明这一点。

## License

MIT
