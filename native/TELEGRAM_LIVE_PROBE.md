# Telegram 公开消息真实探测

探测日期：2026-08-31；工具：`native/.tools/yt-dlp` 2026.08.19，全程未提供 Cookies。

## 官方 extractor 行为

仓库内 `TelegramEmbedIE` 仅请求公开 embed 页面，没有登录、Cookie 或浏览器会话逻辑。因此本阶段不提供虚假的 Cookie 开关，只处理匿名可访问的公开单条消息。`?single` 会令多视频消息只返回一个条目，应用会在资源发现前清除它及其他分享查询参数。

官方 extractor 本身只匹配 `t.me`；直接传入 `telegram.me/europa_press/613` 会返回 `ERROR: Unsupported URL`。应用层会先将经过严格路径校验的 `telegram.me` 等价入口规范化为 `t.me`。

## 单视频 metadata 与下载

公开样例 `https://t.me/europa_press/613` 匿名 metadata 成功：ID `613`、频道 `Europa Press ✔`、日期 `20211030`、时长 61 秒，并提供标题和 JPEG 封面；字段没有 `uploader`。据此 Telegram 默认采用“日期-标题(ID)”、关闭翻译并保存封面。

同一消息完成真实下载，产物为 5,796,200 字节 MP4。`ffprobe` 验证视频 H.264 848×480、音频 AAC、时长 61.114921 秒；封面 URL 亦匿名下载成功，为 320×181 JPEG。

## 多媒体样例

官方双视频样例 `https://t.me/vorposte/29342?single` 在本次网络探测中返回 `unable to extract timestamp` 及 `Extractor telegram:embed returned nothing`，未能取得当前有效的公开多媒体 metadata。因此 selector 的 1-based 拆分行为由官方 extractor 结构和本地合成 metadata 测试验证，但不将其描述为本次 live 成功。图片仅在任务模型中识别；未完成公开图片样例实测，当前不会下载或宣称图片支持。

私有群、受限频道、邀请链接、`/c/` 链接和整频道抓取均不在本阶段范围。
