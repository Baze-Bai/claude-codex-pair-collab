<!-- O 填充说明(发送前删除本注释块):Phase 5 全量审查派活(单 owner 默认;双开互审时改材料为对方文件集)。
     审查方=非 owner。CA:SendMessage,自己写 50_claude_reviews_codex.md。
     CB:cb-round.sh resume <讨论会话UUID>(read-only 可跑 git diff),-o 落 51_codex_reviews_claude.md,加 --require-consensus。
     早期校准审查复用本模板:范围改为首个成形任务的切片,专核「对 PLAN 的理解是否走偏」。 -->
实现完成,你作为审查方审**整个 diff**。

范围与命令:
- 基线 SHA:{{BASELINE_SHA}}(见 {{COLLAB_DIR}}/baseline.txt)
- `git diff {{BASELINE_SHA}} -- {{FILE_SET}}`
- owner 新建的文件(不在 diff 里,一并纳入审查):{{NEW_FILES}}

语义基准 = {{COLLAB_DIR}}/30_PLAN.md + 末尾全部已通过修正案。**专项:自洽误读**——单人实现的特有风险是同一个脑子写接口两侧,读错 PLAN 也错得前后一致、测试不报错;建议(非强制)先盲读 PLAN 写下你对接口/语义的预期,再开 diff 对照——看过实现再读 PLAN 会被实现反向锚定。

要求:
- 发现按严重度分级(阻塞/非阻塞),每条稳定编号(#1…);只提实质问题,找错不表演。
- 关键断言附 file:line 锚点;可由只读实验判定的疑点径行实验附输出。
- 修复由 owner 执行,你只提不改;你提出的发现由你复核验收(从第二次驳回起须给可核验的关闭标准:与发现同范围、owner 定向测试可自证、满足即关闭)。
- 落盘/交付 {{REVIEW_FILE}},末尾单独一行(AGREE=无阻塞问题,同样带凭证):
  `CONSENSUS: OBJECT — <一句话:什么阻塞问题未解决>`
  或
  `CONSENSUS: AGREE — 残余风险:<…>;放弃的最强反对:<…>`
