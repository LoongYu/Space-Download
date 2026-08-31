# X 真实探测记录

- 日期：2026-08-31（Asia/Shanghai）
- 工具：将随 app 打包的 `native/.tools/yt-dlp`，版本 `2026.08.19`
- 方式：`--no-config --skip-download --dump-single-json --no-warnings`，未使用 Cookies，也未读取浏览器数据

## 成功探测

公开链接：`https://twitter.com/CTVJLaidlaw/status/1600649710662213632`

结果：退出码 0，metadata 类型为 playlist，`n_entries = 2`，识别到两个独立视频资源：

- `1600649511827038209`，时长约 113.49 秒，最高候选 720×1280
- `1600649511827013632`，时长约 102.226 秒，最高候选 720×1280

## 临时目录真实下载验证

在 metadata 探测之后，使用同一个打包版 yt-dlp 在 `mktemp` 创建的 `/private/tmp/spacedownload-x-probe.*` 临时目录中执行：

```text
--no-config --yes-playlist --playlist-items 1
--download-sections *0-3 --force-keyframes-at-cuts
--format bestvideo+bestaudio/best --merge-output-format mp4
```

结果：退出码 0，selector `1` 命中独立媒体 ID `1600649511827038209`，实际生成 `1600649511827038209.mp4`。验证数据：

- 文件大小：775,734 字节
- SHA-256：`6a1253c43d8bc314b0c681bd4760975df806141204ab13e31b3162775380cb46`
- ffprobe：3.036367 秒，720×1280，H.264 视频与 AAC 音频

验证结束后已删除整个临时目录，没有向用户下载目录、应用设置目录或仓库写入媒体文件。该结果确认 playlist selector 能命中并下载帖子中的单个独立资源；只验证了第 1 个资源的前三秒，不代表两个完整视频均已下载。

## 未成功样例

以下两个近期公开 SpaceX status 均由同一工具返回 `No video could be found in this tweet`（退出码 1），没有计为成功：

- `https://x.com/SpaceX/status/2000459900460347480`
- `https://x.com/SpaceX/status/1764455416665350500`

结论：当前网络可匿名解析至少一个公开双视频 X 帖子的完整 metadata；帖子是否仍含可提取视频会随远端内容与 X 接口变化。
