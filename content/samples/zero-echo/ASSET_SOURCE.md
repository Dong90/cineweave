# 《零点回声》测试媒体来源

`media/zero-echo.ogv` 是 CineWeave 项目原创的程序化测试媒体，不含外部图片、字体、录音或第三方素材。画面由 FFmpeg 的纯色、网格和几何滤镜生成；声音由正弦波滤镜生成。

权威生成入口是 `tools/media/generate_zero_echo.ps1`。脚本固定时长、分辨率、帧率、Theora/Vorbis 编码参数并清除输入元数据，然后调用 `tools/content/sync_storypacks.ps1` 生成 Godot 可导入副本。

该媒体与 CineWeave 仓库代码一同按根目录 `LICENSE` 的 MIT License 提供。它只作为自动测试和 V0.1 占位样片使用，不主张包含任何人物、表演或现实录音的权利。
