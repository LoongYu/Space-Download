# TikTok 真实探测记录

探测日期：2026-08-31（Asia/Shanghai）

## 范围

- 仅 TikTok 公开单视频
- 未提供 Cookies，也未读取 Chrome 或其他浏览器数据
- 测试链接：`https://www.tiktok.com/@scout2015/video/6718335390845095173`
- 链接来自 TikTok 官方 Embed Player 文档中的公开示例
- yt-dlp：2026.02.21

## 匿名 metadata

`--ignore-config --no-playlist --skip-download --dump-single-json` 退出码为 0。关键字段：

- `id`: `6718335390845095173`
- `uploader`: `scout2015`
- `upload_date`: `20190727`
- `duration`: 10 秒
- `ext`: `mp4`
- `title` / `description`: 均有值
- `thumbnail`: 有值，`thumbnails` 共 3 项
- `webpage_url` / `original_url`: 均为标准 TikTok 单视频链接

这组真实字段用于确定 TikTok 默认设置：作者/日期-标题(ID) 命名、默认不翻译短描述与标签、成功后从 metadata 封面候选中保存最高像素版本。

## 受控真实下载与 ffprobe

在 `/tmp/spacedownload-tiktok-probe.XXXXXX` 临时目录完成公开帖完整下载，yt-dlp 退出码为 0，文件大小 2,004,627 字节。ffprobe 验证：

- 容器：MP4
- 时长：10.495011 秒
- 视频：HEVC，720×1280
- 音频：AAC

yt-dlp 同时给出两项真实警告：本机 2026.02.21 版本超过 90 天，以及 TikTok extractor 尝试 impersonation 但本机没有可用 target；两项均未阻止本次下载。验证完成后临时目录已清理。

## 结论

当前网络可匿名解析并下载该公开 TikTok 单视频。远端帖子状态、TikTok 接口和出口网络可能变化；未来失败时应保留 yt-dlp 的真实错误，不据本次结果推断所有公开视频均可匿名下载。
