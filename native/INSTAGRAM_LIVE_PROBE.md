# Instagram 匿名真实探测

探测日期：2026-08-31（Asia/Shanghai）

## 边界与工具

- 仅使用仓库内 `native/.tools/yt-dlp`，版本 `2026.08.19`，SHA-256 `0f192b7ec147ab6288885d6351d9ab67367640029b4377576ef46dd79cf7b202`
- 全程匿名直连，没有 Cookies，也没有 `--cookies-from-browser` 或任何浏览器认证
- 输出媒体使用 `ffprobe` 检查；探测临时目录不纳入仓库

## Metadata 结果

| 类型 | 公开样例 | 结果 |
|---|---|---|
| Reel | `https://www.instagram.com/reel/Chunk8-jurw/` | 成功；ID `Chunk8-jurw`，作者 `Instagram`，日期 `20220826`，标题、缩略图列表和 MP4 格式存在 |
| 单帖 video | `https://www.instagram.com/p/aye83DjauH/` | 成功；ID `aye83DjauH`，作者、日期 `20130620`、标题、缩略图列表和 MP4 格式存在 |
| carousel | `https://www.instagram.com/p/BQ0eAlwhDrw/` | 成功；识别 3 个视频 entry：`BQ0dSaohpPW`、`BQ0dTpOhuHT`、`BQ0dT7RBFeF`，每项均有作者、日期、标题与封面 |
| IGTV 路由 | `https://www.instagram.com/tv/BkfuX9UB-eK/` | 失败；Instagram 返回空媒体响应并提示该旧帖可能不可匿名访问。仅验证 `/tv/CODE` adapter/命令路由，不宣称此样例下载成功 |

这些真实字段决定默认命名使用 `%(uploader)s/%(upload_date)s-%(title)s(%(id)s)`，默认不翻译标题；封面从当前资源 metadata 的 `thumbnails` 中选择像素面积最大的候选并继承请求头。

## 真实下载与 selector

| 资源 | 结果 | ffprobe |
|---|---|---|
| Reel `Chunk8-jurw` | 成功；SHA-256 `64c7d81d2251172ed0f9beaf3a753765adb7afdd8f93e86aee5aed3675f8e35e` | H.264，720×1280，4.966667 秒，1,949,801 bytes |
| 单帖 `aye83DjauH` | 成功；SHA-256 `909bc3d959d55c9ed4c6a64a389dd264aad5ba3bb7514c2b64988ed935d31653` | H.264，640×640，8.742075 秒，1,017,829 bytes |
| carousel 第 2 项 | `--yes-playlist --playlist-items 2` 成功且只生成 `BQ0dTpOhuHT`；SHA-256 `5f5845a12416d86c830252dd6259ba570ed361507c6323ef984be5702a0cf761` | H.264，640×640，31.698365 秒，2,524,830 bytes |

carousel 样例只包含视频，因而验证了视频 selector，没有验证 Instagram 图片下载。应用可以识别 metadata 中明确标记的图片资源，但当前不会执行图片下载，也不会宣称支持。
