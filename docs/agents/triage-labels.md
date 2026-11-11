# 分诊标签

技能使用五种规范角色表示 Issue 当前由谁处理以及下一步是什么。GitHub 上保持英文标签名称，中文说明只用于帮助理解。

| 规范角色 | GitHub 标签 | 含义 | 下一步 |
|---|---|---|---|
| `needs-triage` | `needs-triage` | 新的原始请求，等待维护者判断范围、优先级和重复情况 | 进入 `needs-info`、`ready-for-agent`、`ready-for-human` 或 `wontfix` |
| `needs-info` | `needs-info` | 需求、复现步骤或验收条件不足 | 报告者补充后回到 `needs-triage` |
| `ready-for-agent` | `ready-for-agent` | 规格、依赖和验收标准完整 | 可从执行前沿领取并开发 |
| `ready-for-human` | `ready-for-human` | 需要产品判断、视觉确认、账号授权或人工操作 | 由用户或指定负责人处理 |
| `wontfix` | `wontfix` | 已决定不执行 | 记录原因并关闭 |

```text
原始 Issue
  → needs-triage
      → needs-info → 补充后重新分诊
      → ready-for-agent → 开发流程
      → ready-for-human → 人工处理
      → wontfix → 说明原因并关闭
```

由 `/to-spec` 和 `/to-tickets` 创建的 Issue 已经过结构化整理，直接使用 `ready-for-agent`。只有外部报告、未经整理的需求和积压请求进入 `needs-triage`。

`wayfinder:map`、`wayfinder:research`、`wayfinder:prototype`、`wayfinder:grilling` 和 `wayfinder:task` 是 `/wayfinder` 的工作类型标签，不表示分诊状态；具体操作见 [Issue Tracker 配置](issue-tracker.md#wayfinding-operations决策地图)。
