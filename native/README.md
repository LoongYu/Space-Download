# SpaceDownload

SpaceDownload 的原生 macOS SwiftUI 客户端，与现有 Python 客户端并存，不会覆盖旧应用。

## 已实现

- 原生 SwiftUI 主窗口与 Pornhub 风格深色界面
- 可收缩且始终可重新展开的设置栏
- AppKit 原生保存目录选择器
- 多视频链接输入、去重和格式校验
- 批量页码表达式解析，例如 `1-3,5`
- 与 Python 客户端共用 `user_settings.json`，自动读取和保存设置
- 内置官方独立版 `yt-dlp_macos`，也支持 Homebrew/PATH 回退
- 单链接、多链接和列表逐项下载
- Pornhub 频道、用户、模特等列表按网页页码下载
- 独立站点适配器架构，Pornhub 与 YouTube 设置和下载规则互不混用
- YouTube 单视频、播放列表和频道下载
- YouTube 播放列表序号筛选，以及频道视频、Shorts、直播和全部内容范围筛选
- YouTube 独立 Cookies、字幕语言、编码偏好和批量请求间隔设置
- 实时下载进度、速度、ETA、成功/失败数量和失败清单
- 完整 JSON metadata 日志
- 5 次下载/分片重试和 8 路分片并发
- 标题中文翻译和成功后封面保存
- 代理、账号、密码、Cookies 文件及 Pornhub 自动年龄验证 Cookies
- 可终止当前 `yt-dlp` 子进程的停止下载功能
- 固定使用单层 macOS 自适应图标，不再因构建环境切换为双层图标

密码和 Cookies 文件路径不会写入设置文件。

## 站点设置

左侧“站点设置”默认使用自动识别，粘贴链接后会切换到对应站点的配置。也可以手动选择站点，提前修改该站点参数。

- Pornhub 的“批量网页分页”按列表页面的页码筛选，例如 `1-3,5`。
- YouTube 的“播放列表序号”按播放列表中的视频顺序筛选，例如 `1-20,25`。
- YouTube 频道链接可以选择视频、Shorts、直播或全部内容。
- YouTube 需要登录、年龄验证或私有内容时，可以单独启用并选择 `cookies.txt`。

## 构建与测试

```bash
cd native
swift test --disable-sandbox --build-path .build \
  --cache-path .build/cache \
  --config-path .build/config \
  --security-path .build/security

./build_app.sh
open "dist/SpaceDownload.app"
```

首次构建前运行 `./prepare_tools.sh`，下载官方独立版 `yt-dlp_macos`。视频合并和格式转换需要 `ffmpeg`，应用会依次在 Resources、Homebrew 和 PATH 中查找。

设置文件位于：

```text
~/Library/Application Support/SpaceDownload/user_settings.json
```
