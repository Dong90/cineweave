# 固定开发流程与技能命令

本文是 CineWeave 使用工程技能开发功能的执行入口。技能负责需求澄清、规格、实现和审查；[CONTRIBUTING.md](../../CONTRIBUTING.md) 是 GitFlow 分支、提交、合并、标签与发布规则的权威规范，本文把常用命令串成可执行流程。两者冲突时，先停止并修正文档，不能临时绕过任一规则。

## 1. 最短使用说明

正常功能只需要记住五条主动命令：

```text
/grill-with-docs <目标>
/to-spec
/to-tickets
/implement <Issue>
/retro
```

执行顺序固定为：

```text
需求访谈
→ 规格 Issue
→ 纵向任务与阻塞关系
→ GitFlow 功能分支
→ TDD 实现
→ Standards + Spec 双轴审查
→ PR 到 develop
→ 合并
→ 复盘
```

不知道入口时使用：

```text
/ask-matt 我现在想做……，应该走哪条流程？
```

## 2. 功能开发主流程

### 阶段 1：澄清需求

用户执行：

```text
/grill-with-docs 开始设计并开发 CineWeave <版本或功能>
```

访谈解决产品、领域、UI、失败状态、兼容性、AI 回退和验收问题。只有引入或改变领域概念时才更新 `GLOSSARY.md`；只有产生需要长期保留的架构决定时才新增或更新 ADR。事实由代理调查，产品决定由用户确认。

完成标准：所有影响实现的设计分支已经决定，或被明确列入 Out of Scope；领域术语无歧义。

如果问题必须看见或运行才能回答，先通过 `/handoff` 切到独立目录，用 `/prototype` 构建一次性原型，再把结论 `/handoff` 回主流程。原型不直接演化为正式代码。

### 阶段 2：形成规格

用户执行：

```text
/to-spec
```

代理先探索仓库并提出公共测试 seam；用户确认 seam 后，规格以 GitHub Issue 发布，包含问题、方案、用户故事、实现决定、测试决定、非目标和备注，并标记 `ready-for-agent`。

完成标准：规格 Issue 可独立解释目标，关键行为具有可观察的测试边界。

### 阶段 3：拆分纵向任务

用户执行：

```text
/to-tickets <规格 Issue>
```

每个 Ticket 必须是能够单独演示或验证的纵向切片，而不是“先做全部数据层、再做全部 UI”的横向阶段。代理先展示拆分和阻塞关系，用户确认后才发布子 Issue。

完成标准：每个 Ticket 适合一个新上下文完成；阻塞边正确；所有 Ticket 都有验收标准并标记 `ready-for-agent`。

### 阶段 4：创建 GitFlow 分支

领取执行前沿中没有开放阻塞项的 Ticket：

```powershell
git switch develop
git pull --ff-only origin develop
git switch -c feature/CW-<issue>-<slug>
```

缺陷使用 `bugfix/CW-<issue>-<slug>`。分支必须关联一个可验收 Issue；`main` 和 `develop` 不直接开发。

完成标准：当前分支名称、Issue 和验收目标一一对应，工作区起点干净。

### 阶段 5：TDD 实现

用户执行：

```text
/implement #<issue-number>
```

`implement` 读取 Ticket，调用 `/tdd` 在预先确认的公共 seam 上逐个完成红—绿切片，定期运行局部检查，结束时运行完整检查。每个测试验证外部行为，不耦合私有实现。

完成标准：验收标准全部满足；测试先失败后通过；完整测试和构建通过；变更已提交到当前功能分支。

多 Ticket 规格默认逐个使用 `/implement`，保持小 PR。只有用户明确希望一次编排整个任务图时才使用：

```text
/implement-spec #<spec-issue>
```

### 阶段 6：审查

`implement` 完成前调用 `/code-review`。独立审查时指定固定比较点：

```text
/code-review origin/develop
```

审查保持两条轴线分开：

- **Standards：** 是否符合仓库规范和代码气味基线。
- **Spec：** 是否漏做规格、做错行为或引入未要求范围。

完成标准：固定点有效且 diff 非空；两个审查报告均完成；阻断发现已经修复并重新验证。

### 阶段 7：创建 PR

用户说“创建 PR”后，代理使用 `/pr` 生成摘要、前后证据、门类型和影响半径：

```powershell
git push -u origin feature/CW-<issue>-<slug>
gh pr create --base develop --head feature/CW-<issue>-<slug>
```

PR 必须引用 Issue，CI 全绿，并按照 `.github/pull_request_template.md` 说明迁移、离线回退、AI 安全、资产权利和回滚。功能 PR 的目标只能是 `develop`。

完成标准：PR 可复核、证据充分、所有对话已解决；获得用户或仓库规则要求的批准后才能合并。

### 阶段 8：完成与复盘

PR 以 merge commit 合入 `develop`，删除功能分支并关闭对应 Issue。随后用户执行：

```text
/retro
```

复盘只改进代理环境：导航指针、自动检查、CI、真正需要判断的编码规范和工具访问。机械错误优先转化为确定性检查。

完成标准：Issue 有完成证据；本地 `develop` 与 `origin/develop` 一致；复盘候选得到记录或明确拒绝。

## 3. 其他固定流程

### 原始请求分诊

```text
/triage
```

仅处理外部 Bug、未经整理的需求和积压 Issue。`/to-spec`、`/to-tickets` 创建的 Issue 已经是 `ready-for-agent`，不再分诊。

### 复杂 Bug

```text
diagnosing-bugs
→ 建立能稳定失败的最小反馈循环
→ 假设与证据
→ 回归测试
→ bugfix/* 实现
→ code-review
→ PR 到 develop
→ retro
```

简单、原因明确的缺陷可以直接建立 Bug Issue 后 `/implement`；难复现、间歇性或性能回归才进入完整诊断流程。

### 大型模糊工作

```text
/wayfinder <远期目标>
→ 决策地图与决策 Ticket
→ 逐步消除未知
→ /to-spec
→ /to-tickets
→ /implement
```

`wayfinder` 只形成决策，不直接实现。能够在一次访谈中说清的功能使用 `/grill-with-docs`。

### 架构维护

```text
/improve-codebase-architecture
→ 选择一个 deepening opportunity
→ /grill-with-docs
→ /to-spec
→ 主流程
```

### Release

当版本验收门全部通过：

```powershell
git switch develop
git pull --ff-only origin develop
git switch -c release/<version>
# 只允许版本、CHANGELOG、发行配置和阻断修复
# 提交并推送后创建 PR: release/<version> → main
git push -u origin release/<version>
gh pr create --base main --head release/<version>
# PR 经检查并以 merge commit 合并后，标签必须创建在更新后的 main 上
git switch main
git pull --ff-only origin main
git tag -a v<version> -m "CineWeave v<version>"
git push origin v<version>
# 保留 release 分支，创建 PR: release/<version> → develop，回合发行修复
gh pr create --base develop --head release/<version>
```

PR 的审查、非快进合并、回合与分支删除严格执行 [CONTRIBUTING.md 的 Release 流程](../../CONTRIBUTING.md#4-release-流程)。正式发行还必须满足 `docs/ROADMAP.md`；标签、ReleaseManifest 与 ReleaseBundle 版本一致。

### Hotfix

```powershell
git switch main
git pull --ff-only origin main
# 确认显示的是当前生产版本，并验证该标签是 main 的祖先
git describe --tags --abbrev=0
git merge-base --is-ancestor v<current-version> HEAD
git switch -c hotfix/<patch-version>
# 修复、测试、提交并推送后创建 PR: hotfix/<patch-version> → main
git push -u origin hotfix/<patch-version>
gh pr create --base main --head hotfix/<patch-version>
# PR 合并后，更新 main，在 main 的补丁发布提交上打标签并推送
git switch main
git pull --ff-only origin main
git tag -a v<patch-version> -m "CineWeave v<patch-version>"
git push origin v<patch-version>
# 再将 hotfix 分支通过 PR 回合 develop；存在活动 release 分支时也回合进去
gh pr create --base develop --head hotfix/<patch-version>
```

Hotfix 只处理已发布版本的紧急问题，不承载普通新功能；完整合并和清理规则见 [CONTRIBUTING.md 的 Hotfix 流程](../../CONTRIBUTING.md#5-hotfix-流程)。

## 4. 所有稳定技能

### 用户主动调用

这些技能只有用户明确输入名称时启动：

| 命令 | 使用时机 |
|---|---|
| `/ask-matt` | 不知道该选择哪条技能流程 |
| `/setup-matt-pocock-skills` | 首次配置或切换 Issue Tracker、标签、领域文档布局 |
| `/grill-with-docs` | 在仓库内澄清功能或设计，并保留术语/ADR 记录 |
| `/triage` | 处理未经整理的外部请求和 Bug |
| `/improve-codebase-architecture` | 扫描模块深度和架构改进候选 |
| `/to-spec` | 把已完成的讨论发布为规格 Issue |
| `/to-tickets` | 把规格拆成具有阻塞边的纵向任务 |
| `/implement` | 实现一个规格或 Ticket |
| `/implement-spec` | 在一个集成分支上编排整份任务图 |
| `/wayfinder` | 为无法在一个会话内看清的大型工作绘制决策地图 |
| `/retro` | 复盘一次开发会话并改进代理环境 |
| `/grill-me` | 没有仓库时进行无状态需求访谈 |
| `/handoff` | 跨目录、代理、同事或独立原型传递上下文 |
| `/teach` | 以当前目录保存进度，分阶段学习概念 |
| `/to-questionnaire` | 把只能由第三方回答的问题整理成问卷 |
| `/wait-what` | 上一条解释没听懂时，要求用项目术语重新说明 |

### 模型按任务调用

用户也可以直接点名；通常由代理在符合条件时自动使用：

| 技能 | 使用时机 |
|---|---|
| `prototype` | 用一次性程序回答 UI、状态或逻辑设计问题 |
| `diagnosing-bugs` | 诊断复杂、间歇性或性能类缺陷 |
| `research` | 基于高可信一手资料完成调研并留下引用文档 |
| `tdd` | 在已确认 seam 上进行红—绿纵向切片 |
| `domain-modeling` | 澄清术语、边界、反例和架构决策 |
| `codebase-design` | 设计深模块、小接口、适配器和测试 seam |
| `code-review` | 分开检查 Standards 与 Spec |
| `pr` | 编写有可视摘要、证据和合并风险的 PR 正文 |
| `wizard` | 为必须由人完成的基础设施、凭据或控制台步骤生成向导 |
| `grilling` | 为访谈、分诊、wayfinding 等流程提供追问机制 |
| `writing-for-agents` | 编写 AGENTS、技能和代理消费的引用文档 |

上游实验技能与低频 misc 工具不属于 CineWeave 的稳定开发合同；需要时单独评估、安装和记录。

## 5. 用户与代理的责任边界

用户负责：产品取舍、测试 seam 确认、Ticket 拆分批准、视觉判断、账号授权、PR 合并许可和发行决定。

代理负责：仓库探索、术语一致性、规格与任务发布、GitFlow 分支、TDD、测试、审查、PR 证据、迁移/回滚检查和状态汇报。

代理可以在用户明确调用 `/implement` 后按该技能要求提交当前功能分支。用户调用 `/wayfinder` 构图时，只授权代理为新建的 Research Ticket 提交并推送 `research/CW-<map>-<slug>` 上下文分支；这些分支不开 PR、永不合并。除此之外，推送、创建 PR、合并、打标签和发布仍需用户在当前任务中明确授权。

## 6. V0.1 示例

```text
/grill-with-docs 开始设计并开发 CineWeave V0.1
/to-spec
/to-tickets <V0.1 规格 Issue>
/implement #<第一个无阻塞 Ticket>
创建 PR
/retro
```

一个 Ticket 合并后，从 GitHub Issues 选择下一个没有开放阻塞项的 `ready-for-agent` Ticket，重复 `/implement → PR → retro`，直到 V0.1 验收门全部通过，再进入 Release 流程。
