# CI 与分支保护

修改 GitHub Actions、引擎版本、PR 合同或 `main`/`develop` 保护规则时读取本文。产品运行说明仍归各模块 README；本文只定义开发守门合同。

## 单一版本来源

`engine/version.json` 是自动化使用的 Godot 版本来源，记录官方版本、固定 Fork 提交、Fork 地址、官方 Windows 归档及 SHA-256。脚本和 CI 读取该文件；ADR、许可和人类说明可以重复关键决定，但不得成为自动化的第二份配置。

升级引擎时在独立 Ticket 中同时更新版本清单、Submodule Gitlink、兼容测试和 ADR。归档哈希必须来自实际下载的官方文件。

## 稳定检查

`.github/workflows/player-ci.yml` 对进入 `develop` 或 `main` 的 PR 提供三个稳定检查名：

- `pr-contract`：验证 PR 正文结构、Issue 关联和 GitFlow 目标。
- `official-player`：校验版本清单和仓库合同，下载并验证官方 Godot，运行无窗口冒烟与主场景启动。
- `fork-player`：从固定 Submodule 构建 Fork，并用构建产物运行同一 Player 检查。

工作流权限保持 `contents: read`；每个 `uses:` 依赖固定到完整提交 SHA。运行结束必须用 `git status --porcelain` 确认导入、构建和测试没有生成待提交文件。

本地修改 CI 合同时运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\verify_repository.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\test_pr_contract.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\run_headless.ps1
```

GitHub Hosted Runner 的三个检查全部通过，才构成 CI 集成证据；本地静态检查不能替代它。

## PR 正文

功能和缺陷 PR 进入 `develop`，正文使用 `Refs #<issue>`；GitHub 只对进入默认分支的关闭关键词执行自动关闭，因此 Ticket 在 merge commit 完成并写入证据后由合并步骤关闭。

PowerShell 中的多行正文通过标准输入传递，避免每一行被拆成命令参数：

```powershell
$body = @'
## Summary

Refs #14

## Evidence

- **Before:** failing check
  **After:** passing check

## Merge Danger

**Door:** Two-way

**Blast Radius:** Development workflow
'@

$body | gh pr create --base develop --head feature/CW-14-player-ci-guardrails --body-file -
$body | gh pr edit 14 --body-file -
```

正文还必须保留 `.github/pull_request_template.md` 的 GitFlow 与 Impact Check 内容；`/pr` 的可视摘要和风险结构不能覆盖这些仓库检查项。

## 分支保护

CI 工作流合入后，再为 `main` 和 `develop` 启用保护，要求：

- 只能通过 PR 更新；分支必须与目标分支保持最新。
- `pr-contract`、`official-player`、`fork-player` 全部成功。
- 禁止强制推送和删除分支，并对管理员执行同一规则。
- 单人阶段的批准人数为零；出现第二名协作者后改为至少一名批准者。

保护启用后使用 GitHub API 或仓库设置页核对两个分支，不把“文档已写”当作“远端规则已生效”。

