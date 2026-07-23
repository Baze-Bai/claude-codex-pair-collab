# 使用指南

**[English →](USAGE.md)**

本指南从**用户视角**讲清楚:怎么装、怎么发起、流程中你会在哪些节点被需要、产出物在哪看、出问题怎么恢复。协议机制的规范源是 [SKILL.md](SKILL.md)(英文)。

## 1. 前提

| 组件 | 要求 |
|---|---|
| Claude Code | 已安装并可用(本体是它的 skill) |
| Codex CLI | `npm install -g @openai/codex`,且已登录。CLI 与 Codex 桌面 App 共享 `~/.codex`——App 已登录则 CLI 直接复用登录态 |
| Bash | Claude Code 需要能调用 Bash(Windows 上即 Git Bash,随 Git for Windows 自带)——全部 worker 调用经封装脚本以 stdin 驱动,PowerShell 后台跑会因 stdin 未关而永久卡死 |
| 独立 Claude CLI 认证 *(默认 headless-CA 承载所需)* | 运行一次 `claude setup-token`——桌面 App 托管的登录态到不了嵌套的 `claude -p`(缺失时封装脚本报退出码 8)。可选:没配会自动回落 subagent 承载 |
| Git 仓库 | 在一个 git 仓库内使用(协作基线、越界哨兵、diff 审查都依赖 git) |

## 2. 安装

在你的项目根目录:

```bash
git clone https://github.com/Baze-Bai/claude-codex-pair-collab.git .claude/skills/pair-collab
```

建议把每主题工作区目录加入本地排除(不污染 `git status`;引擎的越界哨兵也以此为前提):

```bash
echo "collab/" >> .git/info/exclude
```

## 3. 发起一个主题

在 Claude Code 会话里:

```
/pair-collab 给导出服务加断点续传,要求兼容现有 REST 契约
```

主题描述越具体越好(动机、约束、验收期望)。信息不足时 Orchestrator 会先问你,再开工。

发起后 Orchestrator 会:建好 `collab/<日期>-<slug>/` 工作区并把路径告诉你,然后经**回合引擎**(`collab-engine.sh status / advance / collect`)驱动 Phase 1–3——引擎填充 prompt、编排回合次序、形式预检产出;Orchestrator 只负责发射引擎打印的 worker 命令、以及做引擎做不了的语义判定。凡流程允许之处,两侧工程师都**并行且隔离**地跑。

**规模提示**:单函数级的琐碎改动不值得启动本协议(双侧提案+多轮评审有固定开销),Orchestrator 会直说并由你定。小任务的产物会自动收缩(提案一页要点、PLAN/TASKS 合并),但四件事永不收缩:用户批准闸门、独立提案防锚定、CONSENSUS 凭证、评审姿态。

## 4. 全流程:你会在哪些节点被需要

常规流程只有**两个必到节点**;其余时间自动推进,你随时可以打开 collab 目录看进度(每轮还有一屏回执)。

### 节点一:方案批准(Phase 3,必到)

评审收敛后,**finalize penner**(执笔最后一版融合草案的那位工程师——绝不是 Orchestrator)亲笔写出定稿方案,双方全文复读查漂移。然后你会收到批准包:

- `30_PLAN.md`(worker 亲笔的共识方案,末尾带双方复读签署)+ `31_TASKS.md`(分工表);
- 一份**「双方一致但未经对抗验证的关键假设」清单**——从所有 AGREE 凭证栏机械抽取。这是两个 AI 都没质疑、最可能一起踩空的地方,**请重点审这份清单**,而不是只看方案顺不顺眼;
- 请你顺带**增补/调整验收项**(最终集成验证会按它跑)——这是注入外部视角的机会;
- 实现分工(谁实现、谁审查)也在此时由你拍板——Orchestrator 只给建议,不替你定;
- Orchestrator 唯一亲笔的文字是顶部 3–5 行导读。

你可以:批准 / 驳回 / 附修改意见(意见会以「用户裁决」身份进入定向收敛,改完重新呈批)。**未获你批准,不动任何代码。**

### 节点二:真分歧裁决(仅在出现时)

两侧若仍有真实分歧(评审 10 轮上限、分歧台账僵局提前升级、修正案 2 轮不过、审查修复 3 次驳回不过),Orchestrator 会把分歧整理成 2–4 个选项交你裁决。这不是流程失败——是存在值得人来拍板的真实设计张力。

### 其他触点(非常规)

- 实现中若修正案**动到范围或验收标准**,会直接来找你(工程师共识不能替授权背书);
- 收尾时**提交与否由你决定**——全程谁都不 commit,工作树留给你验收。

## 5. 产出物:collab 目录地图

所有过程产物实时落盘 `collab/<日期>-<slug>/`,纯 Markdown,随时可看:

| 文件 | 内容 |
|---|---|
| `00_TOPIC.md` | 题面:主题、约束、代码入口、验收标准 |
| `10_/11_*_proposal.md` | 两侧独立提案 |
| `20_/21_*_review_rN.md` | 各轮交叉评审(r2 起执笔方文件首节含融合草案) |
| `25_disputes.md` | 分歧台账——引擎按权属规则维护 |
| `30_PLAN.md` / `31_TASKS.md` | 共识方案+分工表,**由 finalize penner 亲笔**(末尾附复读签署、你的批准记录、修正案) |
| `32_finalize_combined.md` | 仅 CB 执笔时:引擎拆分前的合并交付 |
| `35_/36_*_readback.md` | 双方定稿复读判定 |
| `40_/41_*_worklog.md` | 实现日志 |
| `50_/51_*_reviews_*.md` | 代码审查(含复核/驳回往返) |
| `90_SUMMARY.md` | 总结 + 协作收益审计 |
| `receipts/` | 引擎逐轮回执:CONSENSUS/DISPUTES 逐字摘录、预检标记、台账变更 |
| `readback_archive/` | 被驳回的复读 + 漂移版 PLAN/TASKS(按修复尝试归档) |
| `prompts/` | 全部派活 prompt 与日志存档 |
| `baseline.txt` | Phase 4 开工基线:stash SHA + porcelain 开工清单(O 写) |
| `opening_snapshot.txt` | 越界哨兵的工作树基准快照 |
| `.locks/` | 封装脚本的 per-UUID 单写者锁目录(正常态为空) |
| `codex_sessions.txt` / `claude_sessions.txt` / `agents.txt` | worker 会话登记(`claude_sessions.txt` 存在即选中 headless CA 承载) |

**盘上文件是流程状态的唯一权威**——引擎自身零状态,每次调用都从盘上重推。这是整个协作能跨会话中断恢复的根基。

## 6. 进阶用法

- **续接既有会话**:两边已有读过项目、方案成形的会话时,可跳过独立提案直接进交叉评审。Codex 侧用会话 **UUID** 指认(线程名不唯一不稳定);接管会向那条 App 对话追加内容,Orchestrator 会先征得你同意,协作期间请勿在 App 里使用那条对话。
- **CA 承载**:默认是 **headless `claude -p` CLI 会话**(全程脚本驱动、O 会话死了它还在、且带最严的工具级权限钉扎)。回落选项:后台 **subagent**(零额外配置即可用)、或你能单独打开的**独立顶层会话**(半自动,每轮派活需你确认)。
- **双开并行实现**:仅当任务低耦合可分、接口可提前冻结、两块工作量都大且赶墙钟时才值得;硬规则是两侧文件集必须不相交。默认单 owner 实现 + 另一方全量审查,协作红利集中在定方案与审代码,不在并行编码。
- **模型钉扎**:CB 每次调用固定跑 `gpt-5.6-sol` @ `xhigh`(per-topic 用 env `CB_MODEL` / `CB_EFFORT` 覆盖)——主题进行中改 Codex App/config 默认不会让在跑的主题悄悄换档。headless CA 默认随你的 Claude CLI 设置,要钉就设 `CA_MODEL`。

## 7. 故障与恢复

- **Orchestrator 会话中断/上下文被压缩**:直接在新会话再次 `/pair-collab <同主题>`——发现同主题 collab 目录会自动进入恢复模式,`collab-engine.sh status` 从盘上精确重推状态。Codex 与 headless-CA 会话在各自库中持久,按登记的 UUID 续跑;subagent CA 随会话消失,会自动重新派生。
- **Codex 调用失败**:自动降级链 = 重试一次 → 新建会话喂 collab 文件重建立场 → **信箱模式**(把 prompt 原文交你贴进 Codex App,回复存回对应文件),流程其余不变。
- **headless-CA 调用失败**:同一阶梯少一级——重试 → 重建会话 → **回落 subagent 承载**(同模型、进程内)。退出码 8 = 独立 CLI 未认证:运行一次 `claude setup-token`。
- **引擎故障**:任何异常 → Orchestrator 停用引擎、走手动流程(手填模板、直接驱动封装脚本、手记台账);盘上文件两种模式下都是唯一权威,可安全交错。
- **封装脚本退出码**(`cb-round.sh` / `ca-round.sh`):`2` worker CLI 退出非 0(读同名 `.log`)/ `3` 交付为空 / `4` 缺 CONSENSUS 行(形式不合格)/ `5` UUID 单写者锁冲突(先确认前次任务确已退出,再删 `collab/<slug>/.locks/<UUID>` 重试)/ `6` 用法错误 / `7`(仅 cb)产出有效但没抓到 session id,人工补记 / `8`(仅 ca)独立 CLI 未登录。
- **工程师越界改了不该改的文件**:两套独立机制。讨论阶段(Phase 1–3)由引擎的越界哨兵把工作树与 `opening_snapshot.txt` 比对、在回执里标记任何变动——只检测不阻止,Orchestrator 会先核实(也可能是你自己在改)。实现阶段(Phase 4)起,越界文件按开工基线(`baseline.txt` 里的 stash SHA)恢复;协议红线禁止对你协作前已有改动的文件用 `git checkout` 恢复到 HEAD——你自己的未提交工作靠这条红线保护。

## 8. 注意事项与成本

- **烧两份配额**:工程师 B 走你的 ChatGPT/Codex 订阅,与 Claude 用量池互不挤占——这也是把独立成块的任务分给 Codex 实现的理由之一。
- **主题进行中不要升级 Codex CLI**(防 resume 版本漂移),也不要在 App 里动协作中的那条 Codex 会话。
- **讨论阶段 CB 一律只读沙箱**;写权限只在实现/修复阶段;任何情况下不使用 `--dangerously-bypass-approvals-and-sandbox` 或 `bypassPermissions`。
- **诚实的期望管理**:两个工程师和 Orchestrator 都是 LLM。交叉评审覆盖的是两个模型**不重叠**的盲区,对共有盲区无免疫。引擎给程序加确定性,不给判断加智能。你的方案批准与集成测试是仅有的两个非 LLM 检查点——「两个 AI 评审过」不等于「已充分把关」,批准包里的共享假设清单值得你认真读。
