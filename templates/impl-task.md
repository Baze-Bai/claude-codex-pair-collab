<!-- O 填充说明(发送前删除本注释块):Phase 4 实现派活。
     owner=CA:SendMessage;worklog=41_claude_worklog.md。
     owner=CB:首次经 cb-round.sh new <collab目录> codex-p4-smoke workspace-write … implementation 冒烟
     (首条 prompt 只要求往 40_codex_worklog.md 写一行标题,验证落盘),冒烟过后 resume 实现会话发本模板;
     worklog=40_codex_worklog.md。 -->
方案已获用户批准。你是本主题的实现 owner,按 {{COLLAB_DIR}}/30_PLAN.md(**含末尾「## 修正案」全部已通过条目**)与 {{COLLAB_DIR}}/31_TASKS.md 实现划给你的任务:{{TASK_IDS}}。

硬约束:
- 只碰 31_TASKS.md 划给你的文件:{{FILE_SET}}
- 禁止 git add/commit/push;禁止安装/升级依赖;不 commit,工作树留给集成阶段。
- 只跑自己任务的定向测试(命令见 TASKS 表),全量验证归 O 的集成阶段。
- 实现日志落盘 {{WORKLOG_FILE}}(做了什么/关键决定/定向测试结果),回执给 O 一句话摘要。

**PLAN 修正案程序**(唯一合法偏离通道;静默偏离禁止):实现中发现 PLAN 某条假设被现实推翻(接口冻结错了、依赖行为与设想不符等)→ 暂停受影响任务,向 O 提修正案:被推翻的 PLAN 条目 + 证据(file:line / 定向测试或探针输出)+ 最小提议。O 会转另一侧审议(每修正案 ≤2 轮),通过前不按你的提议动工。
