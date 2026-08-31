# X 真实探测记录

- 日期：2026-08-31（Asia/Shanghai）
- 工具：将随 app 打包的 `native/.tools/yt-dlp`，版本 `2026.08.19`
- 方式：`--no-config --skip-download --dump-single-json --no-warnings`，未使用 Cookies，也未读取浏览器数据

## 成功探测

公开链接：`https://twitter.com/CTVJLaidlaw/status/1600649710662213632`

结果：退出码 0，metadata 类型为 playlist，`n_entries = 2`，识别到两个独立视频资源：

- `1600649511827038209`，时长约 113.49 秒，最高候选 720×1280
- `1600649511827013632`，时长约 102.226 秒，最高候选 720×1280

本次只执行 metadata 探测，没有写入媒体文件，因此不把它描述为完整下载成功。

## 未成功样例

以下两个近期公开 SpaceX status 均由同一工具返回 `No video could be found in this tweet`（退出码 1），没有计为成功：

- `https://x.com/SpaceX/status/2000459900460347480`
- `https://x.com/SpaceX/status/1764455416665350500`

结论：当前网络可匿名解析至少一个公开双视频 X 帖子的完整 metadata；帖子是否仍含可提取视频会随远端内容与 X 接口变化。
