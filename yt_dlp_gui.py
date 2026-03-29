import streamlit as st
import streamlit.components.v1 as components
import sys
import os
import time
import json
from pathlib import Path
import threading
import queue
import uuid
import requests  # 新增，用于独立下载封面

try:
    from deep_translator import GoogleTranslator
except Exception:
    GoogleTranslator = None

sys.path.append(os.getcwd())
import yt_dlp

st.set_page_config(
    page_title="🚀Space Download",
    page_icon="🚀",
    layout="wide",
    initial_sidebar_state="collapsed",
)

st.markdown(
    """
    <style>
    .stApp { background-color: #000000; color: #ffffff; }
    .stTextInput div[data-baseweb="input"] {
        height: 60px !important;
        background-color: #000000 !important;
        border: 2px solid #ff9900 !important;
        border-radius: 12px !important;
        padding: 0 10px !important;
    }
    .stTextInput input {
        font-size: 18px !important;
        font-weight: bold !important;
        color: #ff9900 !important;
        text-align: left !important;
        background-color: transparent !important;
        height: 60px !important;
        line-height: 60px !important;
    }
    .stTextInput input::placeholder { color: rgba(255, 153, 0, 0.4) !important; }
    .stTextInput div[data-baseweb="input"] > div { border: none !important; background-color: transparent !important; }
    [data-testid="stSidebar"] .stTextInput div[data-baseweb="input"],
    [data-testid="stSidebar"] .stNumberInput div[data-baseweb="input"],
    [data-testid="stSidebar"] .stSelectbox div[data-baseweb="select"],
    [data-testid="stSidebar"] .stSelectbox div[data-baseweb="input"] {
        height: 40px !important;
        background-color: #1a1a1a !important;
        border: 1px solid #333 !important;
        border-radius: 5px !important;
    }
    [data-testid="stSidebar"] input {
        font-size: 14px !important;
        height: 40px !important;
        line-height: 40px !important;
        text-align: left !important;
        color: #ffffff !important;
        font-weight: normal !important;
    }
    .stButton > button {
        background-color: #ff9900 !important;
        color: #000000 !important;
        font-weight: bold !important;
        border: none !important;
        border-radius: 12px !important;
        height: 60px !important;
        font-size: 18px !important;
        width: 100% !important;
    }
    .stSidebar { background-color: #111111; border-right: 1px solid #333; }
    h1, h2, h3 { color: #ff9900 !important; text-align: left !important; }
    [data-testid="stSidebar"] h1 { text-align: left !important; font-size: 24px !important; }
    .main .block-container { padding-top: 2rem; }
    /* Hide Global Scrollbar */
    html, body, [data-testid="stAppViewContainer"], [data-testid="stMain"] {
        overflow: hidden !important;
        height: 100vh !important;
    }
    ::-webkit-scrollbar {
        display: none !important;
        width: 0 !important;
    }
    /* Compact Layout */
    .stMarkdown h1 { margin-top: -30px !important; margin-bottom: 10px !important; }
    .log-area {
        background-color: #0a0a0a;
        border: 1px solid #333;
        border-radius: 10px;
        padding: 15px;
        font-family: Menlo, Monaco, "Courier New", monospace;
        font-size: 13px;
        color: #ffffff;
        height: 300px;
        overflow-y: auto;
        white-space: pre-wrap;
        user-select: text !important;
        -webkit-user-select: text !important;
        display: flex;
        flex-direction: column-reverse;
    }
    /* Show scrollbar only for log-area if needed */
    .log-area::-webkit-scrollbar {
        display: block;
        width: 6px;
    }
    .log-area::-webkit-scrollbar-thumb {
        background: #333;
        border-radius: 10px;
    }
    /* Custom Progress Bar Style */
    .progress-container {
        width: 100%;
        height: 24px;
        background-color: transparent;
        border: 2px solid #ff9900;
        border-radius: 20px;
        overflow: hidden;
        position: relative;
        margin: 10px 0;
    }
    .progress-bar-inner {
        height: 100%;
        background-color: #ff9900;
        border-radius: 0;
        transition: width 0.4s ease;
    }
    /* Hide native progress bar if any */
    .stProgress { display: none !important; }
    
    /* Sidebar styling cleanup */
    [data-testid="stSidebar"] section {
        padding-top: 1rem !important;
    }
    [data-testid="stSidebar"] .stMarkdown h1 {
        margin-bottom: 0.5rem !important;
    }
    </style>
""",
    unsafe_allow_html=True,
)

if "sid" not in st.session_state:
    st.session_state.sid = str(uuid.uuid4())
if "download_path" not in st.session_state:
    st.session_state.download_path = str(Path.home() / "Downloads")
if "logs" not in st.session_state:
    st.session_state.logs = []
if "running" not in st.session_state:
    st.session_state.running = False
if "progress" not in st.session_state:
    st.session_state.progress = 0.0
if "status" not in st.session_state:
    st.session_state.status = ""
if "queue" not in st.session_state:
    st.session_state.queue = queue.Queue()
if "stop_event" not in st.session_state:
    st.session_state.stop_event = threading.Event()
if "worker" not in st.session_state:
    st.session_state.worker = None
if "last_error" not in st.session_state:
    st.session_state.last_error = ""
if "show_success" not in st.session_state:
    st.session_state.show_success = False
if "task_counts" not in st.session_state:
    st.session_state.task_counts = {"current": 0, "total": 0}


def append_log(message):
    st.session_state.logs.append(f"{time.strftime('%H:%M:%S')} - {message}")
    if len(st.session_state.logs) > 300:
        st.session_state.logs = st.session_state.logs[-300:]


def translate_text(text):
    if GoogleTranslator is None:
        return text
    try:
        return GoogleTranslator(source="auto", target="zh-CN").translate(text)
    except Exception:
        return text


def is_collection_url(url):
    u = (url or "").lower()
    collection_markers = (
        "/playlist/",
        "/model/",
        "/models/",
        "/channels/",
        "/channel/",
        "/users/",
        "/user/",
        "/pornstar/",
        "/pornstars/",
    )
    return any(marker in u for marker in collection_markers)


def log_json_metadata(task_queue, prefix, info_dict):
    if not isinstance(info_dict, dict):
        task_queue.put(("log", f"{prefix}: <empty>"))
        return

    try:
        metadata_text = json.dumps(info_dict, ensure_ascii=False, indent=2, default=str)
        # 限制日志长度，避免过长
        if len(metadata_text) > 2000:
            metadata_text = metadata_text[:2000] + "\n... (截断，共 " + str(len(metadata_text)) + " 字符)"
    except Exception as e:
        safe_info = {k: str(v) for k, v in info_dict.items()}
        metadata_text = json.dumps(safe_info, ensure_ascii=False, indent=2)
        if len(metadata_text) > 2000:
            metadata_text = metadata_text[:2000] + "\n... (截断，共 " + str(len(metadata_text)) + " 字符)"

    task_queue.put(("log", f"{prefix}:\n{metadata_text}"))


def download_worker(
    task_queue, stop_event, url, opts, translate_title, save_dir, filename_tmpl, embed_thumbnail_flag, auto_playlist
):
    class InnerLogger:
        def debug(self, msg):
            if stop_event.is_set():
                raise Exception("USER_STOPPED")
            if "[debug]" not in msg:
                task_queue.put(("log", f"DEBUG: {msg}"))

        def info(self, msg):
            if stop_event.is_set():
                raise Exception("USER_STOPPED")
            task_queue.put(("log", f"INFO: {msg}"))

        def warning(self, msg):
            if stop_event.is_set():
                raise Exception("USER_STOPPED")
            task_queue.put(("log", f"WARN: {msg}"))

        def error(self, msg):
            if stop_event.is_set():
                raise Exception("USER_STOPPED")
            task_queue.put(("log", f"ERROR: {msg}"))

    def progress_hook(d):
        if stop_event.is_set():
            raise Exception("USER_STOPPED")
        if d["status"] == "downloading":
            percent_str = (d.get("_percent_str") or "0%").replace("%", "").strip()
            try:
                percent = float(percent_str) / 100.0
                task_queue.put(("progress", percent))
                # 提取正在下载的文件名（可选）
                filename = os.path.basename(d.get("filename", ""))
                task_queue.put(
                    (
                        "status",
                        f"📦 正在下载: {d.get('_percent_str')} | 速度: {d.get('_speed_str')} | 剩余: {d.get('_eta_str')}",
                    )
                )
            except Exception:
                pass
        elif d["status"] == "finished":
            task_queue.put(("progress", 1.0))

    try:
        task_queue.put(("log", f"正在解析链接: {url}"))

        # 单视频模式：不走 extract_flat，避免把带时效签名的 m3u8 当成最终下载地址导致 403
        if not auto_playlist:
            single_opts = opts.copy()
            single_opts.update(
                {
                    "logger": InnerLogger(),
                    "progress_hooks": [progress_hook],
                    "noplaylist": True,
                    "ignoreerrors": False,
                }
            )
            task_queue.put(("task_count", {"current": 0, "total": 1}))
            with yt_dlp.YoutubeDL(single_opts) as ydl:
                task_queue.put(("log", "正在提取视频元数据..."))
                item_info = ydl.extract_info(url, download=False)
                if not isinstance(item_info, dict):
                    raise Exception("解析结果为空，未获取到视频信息")
                log_json_metadata(task_queue, "JSON metadata", item_info)
                task_queue.put(("task_count", {"current": 1, "total": 1}))
                if translate_title:
                    item_info["title"] = translate_text(item_info.get("title", ""))
                if embed_thumbnail_flag:
                    t_url = item_info.get("thumbnail")
                    if t_url:
                        try:
                            headers = {"User-Agent": "Mozilla/5.0", "Referer": "https://www.pornhub.com/"}
                            with yt_dlp.YoutubeDL({"outtmpl": filename_tmpl}) as ydl_temp:
                                b_name = os.path.splitext(ydl_temp.prepare_filename(item_info))[0]
                                t_path = os.path.join(save_dir, f"{b_name}.jpg")
                            os.makedirs(os.path.dirname(t_path), exist_ok=True)
                            r = requests.get(t_url, headers=headers, timeout=15, verify=False)
                            if r.status_code == 200:
                                with open(t_path, "wb") as f:
                                    f.write(r.content)
                        except Exception:
                            pass
                ydl.process_ie_result(item_info, download=True)
            task_queue.put(("done", "success"))
            return

        # 批量模式预处理：先获取列表总数
        extract_opts = opts.copy()
        extract_opts.update(
            {
                "extract_flat": "in_playlist",
                "logger": InnerLogger(),
                "noplaylist": False,
            }
        )
        with yt_dlp.YoutubeDL(extract_opts) as ydl_extract:
            task_queue.put(("log", "正在快速扫描列表信息..."))
            list_info = ydl_extract.extract_info(url, download=False)
            entries = list(list_info.get("entries") or [])
            entries = [e for e in entries if isinstance(e, dict)]
            total_count = len(entries)
            task_queue.put(("log", f"✅ 识别到批量列表，共 {total_count} 个视频"))
            task_queue.put(("task_count", {"current": 0, "total": total_count}))

        # 准备批量下载的 URL 列表：优先网页链接，避免直接拿到临时 m3u8 链接
        url_list = []
        for entry in entries:
            e_url = entry.get("webpage_url") or entry.get("original_url") or entry.get("url")
            if isinstance(e_url, str) and e_url.startswith("http"):
                url_list.append(e_url)

        if not url_list:
            raise Exception("批量解析失败：未获取到可下载的视频链接")

        # 边查边下模式：逐个处理视频
        final_opts = opts.copy()
        final_opts.update(
            {
                "logger": InnerLogger(),
                "progress_hooks": [progress_hook],
                "concurrent_fragment_downloads": 8,
                "ignoreerrors": True,
                "http_chunk_size": 0,
                "hls_use_mpegts": True,
            }
        )

        def download_item(ydl, item_url, idx):
            if stop_event.is_set():
                return
            task_queue.put(("task_count", {"current": idx + 1, "total": len(url_list)}))
            try:
                # 提取信息（为了翻译和封面）
                item_info = ydl.extract_info(item_url, download=False)
                if not isinstance(item_info, dict):
                    raise Exception("视频信息为空")
                log_json_metadata(task_queue, f"JSON metadata [{idx + 1}/{len(url_list)}]", item_info)

                # 翻译标题
                if translate_title:
                    item_info["title"] = translate_text(item_info.get("title", ""))

                # 独立封面下载
                if embed_thumbnail_flag:
                    t_url = item_info.get("thumbnail")
                    if t_url:
                        try:
                            headers = {"User-Agent": "Mozilla/5.0", "Referer": "https://www.pornhub.com/"}
                            with yt_dlp.YoutubeDL({"outtmpl": filename_tmpl}) as ydl_temp:
                                b_name = os.path.splitext(ydl_temp.prepare_filename(item_info))[0]
                                t_path = os.path.join(save_dir, f"{b_name}.jpg")
                            os.makedirs(os.path.dirname(t_path), exist_ok=True)
                            r = requests.get(t_url, headers=headers, timeout=15, verify=False)
                            if r.status_code == 200:
                                with open(t_path, "wb") as f:
                                    f.write(r.content)
                        except Exception:
                            pass

                # 执行下载
                ydl.process_ie_result(item_info, download=True)
            except Exception as e:
                task_queue.put(("log", f"❌ 视频下载失败: {str(e)}"))

        with yt_dlp.YoutubeDL(final_opts) as ydl:
            for i, item_url in enumerate(url_list):
                if stop_event.is_set():
                    break
                download_item(ydl, item_url, i)

        task_queue.put(("done", "success"))
    except Exception as e:
        if "USER_STOPPED" in str(e):
            task_queue.put(("done", "stopped"))
        else:
            task_queue.put(("done", f"error:{e}"))


with st.sidebar:
    st.title("设置")
    quality_options = {
        "最佳": "best",
        "4K (2160p)": "bestvideo[height<=2160]+bestaudio/best[height<=2160]",
        "2K (1440p)": "bestvideo[height<=1440]+bestaudio/best[height<=1440]",
        "1080p": "bestvideo[height<=1080]+bestaudio/best[height<=1080]",
        "720p": "bestvideo[height<=720]+bestaudio/best[height<=720]",
        "480p": "bestvideo[height<=480]+bestaudio/best[height<=480]",
    }
    quality = st.selectbox("视频质量", list(quality_options.keys()), index=0)
    out_format = st.selectbox("输出视频格式", ["mp4", "mkv", "webm", "flv"], index=0)
    save_dir = st.text_input("保存目录", value=st.session_state.download_path)
    if save_dir != st.session_state.download_path:
        st.session_state.download_path = save_dir

    name_templates = {
        "仅标题": "%(title)s",
        "作者-标题": "%(uploader)s-%(title)s",
        "日期-标题": "%(upload_date)s-%(title)s",
        "作者/日期-标题": "%(uploader)s/%(upload_date)s-%(title)s",
        "作者/标题": "%(uploader)s/%(title)s",
        "自定义": "custom",
    }
    selected_tpl = st.selectbox("文件命名模板", list(name_templates.keys()), index=3)
    if selected_tpl == "自定义":
        filename_tmpl = st.text_input("自定义模板", value="%(title)s")
    else:
        filename_tmpl = name_templates[selected_tpl]
        st.caption(f"当前规则: `{filename_tmpl}`")

    translate_title = st.checkbox("翻译标题为中文", value=True)
    embed_thumbnail = st.checkbox("写入封面图", value=True)

    use_proxy = st.checkbox("启用代理")
    proxy_url = st.text_input("代理地址", value="http://127.0.0.1:7890", disabled=not use_proxy)

    with st.expander("账号认证 (可选)"):
        username = st.text_input("账号")
        password = st.text_input("密码", type="password")
        use_cookies = st.checkbox("使用 Cookies 文件")
        cookie_file = st.file_uploader("上传 cookies.txt", type=["txt"], disabled=not use_cookies)

st.title("🚀Space Download")

# 处理后台任务队列 (放在 UI 渲染之前)
while not st.session_state.queue.empty():
    try:
        event_type, payload = st.session_state.queue.get_nowait()
        if event_type == "log":
            append_log(payload)
        elif event_type == "progress":
            st.session_state.progress = payload
        elif event_type == "status":
            st.session_state.status = payload
        elif event_type == "task_count":
            st.session_state.task_counts = payload
        elif event_type == "done":
            st.session_state.running = False
            if payload == "success":
                st.session_state.status = "✅ 下载完成"
                st.session_state.progress = 1.0
                st.session_state.show_success = True
                append_log("任务执行完毕")
            elif payload == "stopped":
                st.session_state.status = "⏹️ 已停止"
                st.session_state.show_success = False
                append_log("用户已停止下载")
            elif payload.startswith("error:"):
                st.session_state.last_error = payload[6:]
                st.session_state.status = "❌ 下载失败"
                st.session_state.show_success = False
                append_log(f"错误: {st.session_state.last_error}")
            st.rerun()
    except queue.Empty:
        break

col_url, col_start, col_stop = st.columns([4, 1, 1])
with col_url:
    url = st.text_input("链接", placeholder="在此处粘贴视频、频道或列表链接...", label_visibility="collapsed")
with col_start:
    start_btn = st.button("开始下载", disabled=st.session_state.running, key="start_download_btn")
with col_stop:
    stop_btn = st.button("停止下载", disabled=not st.session_state.running, key="stop_download_btn")

if stop_btn and st.session_state.running:
    st.session_state.stop_event.set()
    append_log("INFO: 正在发出停止指令...")
    st.rerun()

if start_btn:
    if not url.strip():
        st.error("请先输入链接！")
    else:
        st.session_state.logs = []
        st.session_state.progress = 0.0
        st.session_state.status = "🚀 正在初始化..."
        st.session_state.last_error = ""
        st.session_state.show_success = False
        st.session_state.stop_event = threading.Event()
        st.session_state.queue = queue.Queue()
        st.session_state.running = True
        append_log("开始新任务...")
        auto_playlist = is_collection_url(url.strip())
        append_log(f"自动识别模式: {'列表/频道' if auto_playlist else '单视频'}")
        temp_dir = os.path.join(save_dir, ".yt_dlp_temp")
        os.makedirs(temp_dir, exist_ok=True)

        # 修复 Cookie 弃用警告：将 Cookie 写入临时文件
        cookie_path = os.path.join(temp_dir, f"ph_cookies_{st.session_state.sid}.txt")
        with open(cookie_path, "w") as f:
            f.write("# Netscape HTTP Cookie File\n")
            f.write(".pornhub.com\tTRUE\t/\tFALSE\t0\tage_verified\t1\n")
            f.write(".pornhub.com\tTRUE\t/\tFALSE\t0\taccessAgeDisclaimerPH\t1\n")
            f.write(".pornhub.com\tTRUE\t/\tFALSE\t0\taccessPH\t1\n")
            f.write(".pornhub.com\tTRUE\t/\tFALSE\t0\taccessAgeDisclaimerUK\t1\n")

        # 检查 ffmpeg 路径
        ffmpeg_path = "/opt/homebrew/bin/ffmpeg"
        if not os.path.exists(ffmpeg_path):
            ffmpeg_path = "ffmpeg"

        opts = {
            "format": quality_options[quality],
            "n_threads": 3,
            "outtmpl": {
                "default": f"{filename_tmpl}.%(ext)s",
                "thumbnail": f"{filename_tmpl}.%(ext)s",
            },
            "writethumbnail": embed_thumbnail,
            "postprocessors": [
                {
                    "key": "FFmpegVideoConvertor",
                    "preferedformat": out_format,
                },
            ],
            "noplaylist": not auto_playlist,
            "restrictfilenames": False,
            "noprogress": True,
            "concurrent_fragment_downloads": 8,
            "merge_output_format": out_format,
            "ffmpeg_location": ffmpeg_path,
            "paths": {
                "home": save_dir,
                "temp": temp_dir,
            },
            "keep_fragments": False,
            "nopart": True,
            "nocheckcertificate": True,
            "socket_timeout": 30,
            "retries": 10,
            "fragment_retries": 10,
            "http_chunk_size": 0,
            "hls_use_mpegts": True,
            "cookiefile": cookie_path,
            "http_headers": {
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
                "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
                "Accept-Language": "en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7",
                "Referer": "https://www.pornhub.com/",
            },
        }
        if embed_thumbnail:
            # 我们已经通过 requests 优先下载了封面图到目标文件夹
            # 这里的 EmbedThumbnail 在没有 mutagen/AtomicParsley 的环境下极其容易失败
            # 为了防止任务报错中断，我们不再添加这个后置处理器，改由前面的逻辑直接保存封面文件
            opts["writethumbnail"] = False  # 禁用 yt-dlp 自带的，改用我们的
            opts["nocheckcertificate"] = True
        if use_proxy and proxy_url:
            opts["proxy"] = proxy_url
        if username and password:
            opts["username"] = username
            opts["password"] = password
        if use_cookies and cookie_file:
            temp_cookie = os.path.join(temp_dir, f"user_cookies_{st.session_state.sid}.txt")
            with open(temp_cookie, "wb") as f:
                f.write(cookie_file.getbuffer())
            opts["cookiefile"] = temp_cookie  # 用户上传的覆盖内置的
        worker = threading.Thread(
            target=download_worker,
            args=(
                st.session_state.queue,
                st.session_state.stop_event,
                url.strip(),
                opts,
                translate_title,
                save_dir,
                filename_tmpl,
                embed_thumbnail,
                auto_playlist,
            ),
            daemon=True,
        )
        st.session_state.worker = worker
        worker.start()
        st.rerun()

col_prog, col_perc = st.columns([12, 1])
with col_prog:
    # 使用自定义 HTML 替代 st.progress
    progress_val = int(st.session_state.progress * 100)
    st.markdown(
        f"""
        <div class="progress-container">
            <div class="progress-bar-inner" style="width: {progress_val}%;"></div>
        </div>
    """,
        unsafe_allow_html=True,
    )
with col_perc:
    st.markdown(
        f"<div style='margin-top: 10px;'><b>{int(st.session_state.progress * 100)}%</b></div>", unsafe_allow_html=True
    )

# 显示下载计数统计
if st.session_state.task_counts["total"] > 0:
    curr = st.session_state.task_counts["current"]
    total = st.session_state.task_counts["total"]
    st.markdown(
        f"<div style='text-align: right; color: #ff9900; font-size: 14px; margin-top: -10px;'>进度统计: {curr} / {total} 视频</div>",
        unsafe_allow_html=True,
    )

status_info = st.empty()
status_info.markdown(st.session_state.status or "等待任务开始")
st.markdown("### 📋 运行日志")
log_placeholder = st.empty()
log_text = "\n".join(st.session_state.logs[-200:])
log_placeholder.markdown(f'<div id="log-area" class="log-area">{log_text}</div>', unsafe_allow_html=True)

if st.session_state.last_error:
    st.error(f"❌ 运行报错: {st.session_state.last_error}")

if (not st.session_state.running) and st.session_state.show_success:
    st.success("🎉 任务已全部完成！")

if st.session_state.running:
    time.sleep(0.4)
    st.rerun()
