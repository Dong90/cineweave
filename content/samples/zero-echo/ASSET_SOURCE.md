# 《零点回声》素材来源与权利

## 正式内容

《零点回声》的正式剧情文本、对白、字幕、原创程序化画面和原创合成环境音由 CineWeave 项目制作。画面只使用 FFmpeg 的纯色、网格和几何滤镜；声音只使用固定种子的合成噪声与正弦波，不包含外部图片、表演、现实录音或第三方素材。

Copyright © 2026 Dong90. All rights reserved.

除非另有书面许可，上述正式内容不随 CineWeave 根目录 MIT License 授权。该声明不适用于 CineWeave 程序代码、第三方字体或另行标明许可的测试夹具。

正式媒体由 `tools/media/generate_zero_echo.ps1` 生成。脚本固定时长、分辨率、帧率、Theora/Vorbis 编码参数和合成源，并通过 FFprobe 与完整解码检查。每个成品的参数、大小和 SHA-256 记录在 `media/media-manifest.json`。

## 第三方字体

Player 使用未经修改的 Noto Sans SC。该字体按 SIL Open Font License 1.1 分发，不受 CineWeave 根目录 MIT License 重新授权。完整来源、固定提交、文件哈希和许可证见 `apps/player-godot/assets/fonts/noto-sans-sc/` 及根目录 `THIRD_PARTY_NOTICES.md`。

## 程序化测试夹具

原 `media/zero-echo.ogv` 是不含人物、表演、外部录音或第三方素材的 3 秒程序化测试媒体。它此前已按 CineWeave 根目录 MIT License 提供，继续保留该授权，仅用于自动测试和历史可追溯性，不代表正式《零点回声》样片的授权。

## 正式素材清单

| 路径 | 内容 | 创作方式 | 权利 |
|---|---|---|---|
| `storypack.json` | 剧情、分支、字幕 | 项目原创 | © 2026 Dong90，保留所有权利 |
| `media/platform-2357.ogv` | 23:57 空站台 | 程序化画面与合成环境音 | © 2026 Dong90，保留所有权利 |
| `media/future-warning.ogv` | 未来警告 | 程序化画面与合成环境音 | © 2026 Dong90，保留所有权利 |
| `media/midnight-train-arrives.ogv` | 零点列车进站 | 程序化画面与合成环境音 | © 2026 Dong90，保留所有权利 |
| `media/board-loop-reveal.ogv` | 循环真相 | 程序化画面与合成环境音 | © 2026 Dong90，保留所有权利 |
| `media/leave-to-0001.ogv` | 00:01 出站 | 程序化画面与合成环境音 | © 2026 Dong90，保留所有权利 |

准确哈希以同目录 `media/media-manifest.json` 为准。
