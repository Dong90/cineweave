# 固定独立 Godot Fork，同时保持官方兼容

CineWeave 使用 `Dong90/godot` 独立 Fork，并在每个产品版本中通过 Git Submodule 固定明确提交；这样未来可以修改引擎，同时避免把庞大的引擎源码复制进产品仓库。V0.1 固定到官方 `4.7.2-stable` 对应提交 `ed1daf0bf001b61586d9930840f2f1394092c079`，并把未经修改的官方 Godot 4.7.2 作为兼容门，防止 Player 在没有明确版本决策时依赖 Fork 专属行为。

## Consequences

- 引擎升级必须在独立功能分支中更新 Submodule 提交，并让官方版本与 Fork 构建都通过 Player 检查。
- 已发布 CineWeave 版本的 Submodule 提交保持不变；需要新的引擎能力时创建新的产品版本。
- 引擎二进制和构建缓存保留在仓库外或 Submodule 的忽略目录中，不进入 CineWeave Git 历史。
