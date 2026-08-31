# 抖音真实探测记录

日期：2026-08-31（Asia/Shanghai）

## 工具与边界

- 使用仓库 `native/prepare_tools.sh` 准备的 `native/.tools/yt-dlp`
- yt-dlp：stable 2026.08.19，commit `594bd50c2`，`darwin_exe`
- ffmpeg / ffprobe：8.0.1
- 仅探测抖音公开单视频；未使用账号、Cookie 或浏览器认证
- 显式使用 `--ignore-config --proxy ''` 排除用户配置和本地代理影响

## 真实链接与 metadata

主测试链接：`https://www.douyin.com/video/7593658955180657960`（公开索引显示为央视网于 2026-01-10 发布的视频）。另用标准链接 `https://www.douyin.com/video/7448553671069060371` 交叉验证。

匿名命令：

```bash
native/.tools/yt-dlp --ignore-config --proxy '' --verbose --no-warnings \
  --skip-download --dump-single-json \
  'https://www.douyin.com/video/7593658955180657960'
```

两条标准链接均进入 `[Douyin]` extractor 和 `Downloading web detail JSON`，随后退出码为 1：

```text
Failed to parse JSON: Expecting value in '': line 1 column 1 (char 0)
ERROR: Fresh cookies (not necessarily logged in) are needed
```

stdout 仅为 `null`，没有可信的 `id`、`title`、`uploader`、`duration`、`thumbnail` 或 `formats` metadata。加入 `--impersonate chrome` 后错误不变，因此应用没有引入浏览器模拟参数。

## 短链

测试 `https://v.douyin.com/i2fr44YG/`。yt-dlp 安全跟随重定向至 `https://www.douyin.com/video/7364022131870453028?previous_page=app_code_link`，随后进入同一 Douyin extractor，并被相同 fresh cookies 风控阻止。这验证短链入口可安全交给 yt-dlp 解析，但没有验证匿名 metadata 或下载成功。

## 下载与 ffprobe

metadata 阶段已经失败，因此没有启动真实媒体下载，也没有可供 ffprobe 验证的文件。本文不声称匿名下载成功。

## 设置决策与降级

- 无真实 metadata 可证明作者和日期字段稳定存在，默认命名保守采用 `%(title)s(%(id)s)`；运行时仍使用 yt-dlp 返回的真实 metadata 命名。
- 抖音内容标题通常已是中文，默认关闭标题翻译；用户可在抖音独立设置中开启。
- 若 Cookie-backed metadata 成功，封面服务从真实 `thumbnails` 候选选择像素面积最大的版本，并合并 metadata 请求头。
- yt-dlp 明确要求 fresh cookies（不一定登录），所以用户手动选择 Netscape 格式 `cookies.txt` 是合理降级。本次没有用户 Cookie，未验证该降级能成功下载。
- 应用禁止 `--cookies-from-browser`，不读取 Chrome 或其他浏览器认证，也不会复用 TikTok Cookie。
