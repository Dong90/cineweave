# Issue Tracker：GitHub

CineWeave 的规格、开发任务和缺陷记录位于 `Dong90/cineweave` GitHub Issues。所有操作从本仓库目录使用 `gh` CLI，远程仓库必须先通过 `gh repo view --json nameWithOwner` 验证为 `Dong90/cineweave`。

## 基本操作

```powershell
# 创建、读取和列出 Issue
gh issue create --title "..." --body "..."
gh issue view <number> --json number,title,body,labels,comments
gh issue list --state open --json number,title,labels

# 评论、修改标签和关闭
gh issue comment <number> --body "..."
gh issue edit <number> --add-label "ready-for-agent"
gh issue edit <number> --remove-label "needs-info"
gh issue close <number> --comment "完成原因或不处理原因"
```

多行 Issue 正文使用 PowerShell here-string 或 `--body-file`，避免把换行和引号拼进单行命令。

## 规格与任务

- `/to-spec` 发布一个规格 Issue，并直接应用 `ready-for-agent`，无需再次分诊。
- `/to-tickets` 为每个纵向切片创建独立 Issue；已有规格时，将任务创建为其子 Issue。
- `/triage` 只处理外部或未经整理的原始请求；`/to-tickets` 产生的任务已经可以开发，不再经过 triage。
- Issue 标题和正文使用 `GLOSSARY.md` 的规范术语。

## 子任务与阻塞关系

当前 GitHub CLI 支持原生子 Issue 和依赖关系：

```powershell
# 创建子 Issue
gh issue create --parent <parent> --title "..." --body "..."

# 为已有 Issue 增加子 Issue
gh issue edit <parent> --add-sub-issue <child>

# 声明 child 被 blocker 阻塞
gh issue edit <child> --add-blocked-by <blocker>

# 查看仍未关闭的阻塞项数量
gh issue view <child> --json blockedBy `
  --jq '[.blockedBy.nodes[] | select(.state == "OPEN")] | length'
```

如果 GitHub 暂时不支持相应操作，在正文顶部使用 `Part of #<parent>` 和 `Blocked by: #<number>` 作为兼容表示。只有所有阻塞 Issue 均关闭的任务才能进入执行前沿。

## Wayfinding operations（决策地图）

`/wayfinder` 用一个带 `wayfinder:map` 标签的父 Issue 作为低分辨率索引。地图正文固定使用以下结构；开放 Ticket 不写进地图正文，而是通过父子关系查询：

```markdown
## Destination

<走到地图终点时会得到的规格、决定或变更，一到两行>

## Notes

<领域、每次会话要使用的技能和本次工作的长期偏好>

## Decisions so far

<!-- 每个已关闭 Ticket 一行：带标题的链接 + 一句话结论；不复制详细答案 -->

## Not yet specified

<!-- 仍在范围内、但目前还无法精确写成问题的迷雾 -->

## Out of scope

<!-- 明确超出本次 Destination 的工作，不会进入前沿 -->
```

每个当前已经能准确提出的问题是地图的子 Issue，正文只包含 `## Question` 和待回答的问题，并按照工作类型使用一个标签：

- `wayfinder:research`：查阅一手资料或验证外部事实。
- `wayfinder:prototype`：通过一次性原型回答必须运行或看见的问题。
- `wayfinder:grilling`：需要用户做产品、体验或取舍决定。
- `wayfinder:task`：在做决定前必须完成的人工或操作性工作，例如开通服务、提供访问权限或搬移数据；它只用于解除决策阻塞，不负责交付 Destination。

地图和子 Issue 只能使用相应的 `wayfinder:*` 标签，不能再添加 `ready-for-agent` 等分诊标签。

```powershell
# 创建决策地图；map-body-file 必须使用上面的固定正文结构
gh issue create --title "Decision map: <goal>" --body-file <map-body-file> `
  --label "wayfinder:map"

# 创建地图的决策子 Issue；ticket-body-file 只包含 ## Question 和问题
gh issue create --parent <map-number> --title "..." --body-file <ticket-body-file> `
  --label "wayfinder:research"

# 用原生依赖表达决策顺序
gh issue edit <child> --add-blocked-by <blocker>

# 领取前沿任务；指派是第一次写操作
gh issue edit <ticket-number> --add-assignee "@me"

# 完成后先写入答案与证据，再关闭 Ticket
gh issue comment <ticket-number> --body-file <answer-file>
gh issue close <ticket-number> --comment "Decision recorded in [<map-title>](<map-url>)."

# 将带标题的 Ticket 链接和一句话结论追加到 Decisions so far
gh issue edit <map-number> --body-file <updated-map-body-file>
```

执行前沿按以下顺序计算：读取地图的开放子 Issue；剔除仍有开放阻塞项的 Issue；剔除已有 assignee 的 Issue；保留 GitHub 子 Issue 列表的顺序。地图正文不维护开放 Ticket 或 Frontier 的副本。领取前只读取，确定目标后才用 `--add-assignee "@me"` 原子领取；如果领取失败或发现已有 assignee，重新计算前沿，不与其他执行者重复工作。

每关闭一个决策 Ticket，都要把“带 Ticket 标题的链接 + 一句话结论”追加到地图的“Decisions so far”；详细答案只保留在 Ticket 的 resolution comment 中。面向用户引用地图或 Ticket 时始终使用带链接的标题，不用裸 Issue 编号代替名称。随后把已经清晰的迷雾从“Not yet specified”移成新的子 Issue，并重新计算前沿。

`/wayfinder` 默认只消除未知并形成决策，一次会话最多解决一个非 Research Ticket；当地图已经足以达到 Destination 时转入 `/to-spec`，不要在决策 Ticket 中实现生产代码。

创建地图时先通过 `grilling` 和 `domain-modeling` 明确 Destination，再广度优先找出当前能准确提出的问题；先创建全部已知 Ticket，第二遍再添加阻塞关系。新建的 Research Ticket 可由独立代理并行解决，研究产物保存在一次性的 `research/CW-<map>-<slug>` 分支并推送，Issue 中记录带标题的提交链接，但不创建 PR、也不合并到产品分支。用户调用 `/wayfinder` 构图即构成对这些研究分支提交与推送的窄范围授权。继续已有地图时，先加载地图低分辨率索引，再领取第一个前沿 Ticket，按照它的 `wayfinder:<type>` 执行并回写结果。

## 写入边界

- 只在 `Dong90/cineweave` 创建 Issue，不向技能来源仓库 `mattpocock/skills` 写入内容。
- PR 不作为外部需求入口；外部 PR 不自动进入 `/triage`。
- 关闭 Issue 前先写明完成证据、替代方案或拒绝原因。
- GitHub Issue 与 Git 分支通过 `CW-<issue-number>` 关联，例如 `feature/CW-12-story-runtime`。

## 技能术语映射

- “publish to the issue tracker”表示创建 GitHub Issue。
- “fetch the relevant ticket”表示读取 Issue 正文、标签和评论。
- “blocking edges”表示 GitHub 原生依赖；不可用时使用正文中的 `Blocked by`。
- “frontier”表示所有阻塞项已经关闭、尚未被领取的开放任务集合。
