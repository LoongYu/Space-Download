# SpaceDownload

SpaceDownload 的原生 macOS SwiftUI 客户端，与现有 Python 客户端并存，不会覆盖旧应用。

## 已实现

- 原生 SwiftUI 主窗口与 Pornhub 风格深色界面
- 标准 macOS `设置…` 菜单与独立设置窗口
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
- Pornhub 与 YouTube 独立的命名、标题翻译、封面和 Cookies 设置
- YouTube 独立字幕语言、编码偏好和批量请求间隔设置
- YouTube 公开内容优先使用免 Cookies 流程，并隔离外部 yt-dlp 配置和未启用的环境代理
- YouTube 标题翻译在命名阶段生效，封面从 metadata 候选中选择最高像素版本并继承专属请求头
- 可复用的社交帖子多资源任务模型；首个适配站点为 X（`x.com` / `twitter.com`）单条 status
- X 支持单视频、animated GIF 以及一个帖子中的多个视频资源，逐项进度、失败统计和重复媒体 ID 跳过继续
- X 使用独立设置与可选手动 `cookies.txt`，不读取浏览器 Cookie；图片仅预留资源类型，当前未验证且不下载
- 实时下载进度、速度、ETA、成功/失败数量和失败清单
- 完整 JSON metadata 日志
- 5 次下载/分片重试，以及可配置的下载限速和 1–16 分片并发
- 标题中文翻译和成功后封面保存
- 代理、账号、密码、Cookies 文件及 Pornhub 自动年龄验证 Cookies
- 可终止当前 `yt-dlp` 子进程的停止下载功能
- 固定使用单层 macOS 自适应图标，不再因构建环境切换为双层图标

密码和 Cookies 文件路径不会写入设置文件。

## 站点设置

通过 `SpaceDownload > 设置…` 或 `⌘,` 打开独立设置窗口。全局设置影响所有站点；站点设置页的下拉列表只选择当前编辑的站点，实际下载站点始终由链接自动识别。

- Pornhub 的“批量网页分页”按列表页面的页码筛选，例如 `1-3,5`。
- YouTube 的“播放列表序号”按播放列表中的视频顺序筛选，例如 `1-20,25`。
- YouTube 频道链接可以选择视频、Shorts、直播或全部内容。
- YouTube 需要登录、年龄验证或私有内容时，可以单独启用并选择 `cookies.txt`。
- YouTube 若拒绝当前网络的匿名访问，请先更换可用代理；应用不会自动读取 Chrome 或其他浏览器数据。
- X 仅接受单条 status 链接。公开帖子通常无需 Cookies；受限帖子可在 X 设置中手动选择 `cookies.txt`。

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

运行日志会实时追加到：

```text
~/Library/Logs/SpaceDownload/app.log
```
