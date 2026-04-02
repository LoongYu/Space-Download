import atexit
import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time
import uuid
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import requests
import streamlit as st
import yt_dlp

try:
    from deep_translator import GoogleTranslator
except Exception:
    GoogleTranslator = None


DEFAULT_DOWNLOAD_PATH = str(Path.home() / "Downloads")
DEFAULT_USER_SETTINGS = {
    "download_path": DEFAULT_DOWNLOAD_PATH,
    "saved_quality": "最佳",
    "saved_out_format": "mp4",
    "saved_template_name": "作者/日期-标题(id)",
    "saved_custom_template": "%(title)s(%(id)s)",
    "saved_page_selection": "",
    "saved_translate_title": True,
    "saved_embed_thumbnail": True,
    "saved_use_proxy": False,
    "saved_proxy_url": "http://127.0.0.1:7890",
    "saved_username": "",
    "saved_use_cookies": False,
}
COMMON_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7",
    "Accept-Language": "en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7",
}
PORNHUB_HEADERS = {
    **COMMON_HEADERS,
    "Referer": "https://www.pornhub.com/",
}
PORNHUB_COOKIE_LINES = [
    ".pornhub.com\tTRUE\t/\tFALSE\t0\tage_verified\t1",
    ".pornhub.com\tTRUE\t/\tFALSE\t0\taccessAgeDisclaimerPH\t1",
    ".pornhub.com\tTRUE\t/\tFALSE\t0\taccessPH\t1",
    ".pornhub.com\tTRUE\t/\tFALSE\t0\taccessAgeDisclaimerUK\t1",
]

TEMP_PATHS = set()
TEMP_PATHS_LOCK = threading.Lock()


def register_temp_path(path):
    with TEMP_PATHS_LOCK:
        TEMP_PATHS.add(path)
    return path



def cleanup_registered_temp_paths():
    with TEMP_PATHS_LOCK:
        paths = list(TEMP_PATHS)
        TEMP_PATHS.clear()
    for path in paths:
        try:
            if os.path.isdir(path):
                shutil.rmtree(path, ignore_errors=True)
            elif os.path.exists(path):
                os.remove(path)
        except Exception:
            pass


atexit.register(cleanup_registered_temp_paths)



def get_user_settings_path():
    if sys.platform == "darwin":
        base_dir = Path.home() / "Library" / "Application Support" / "SpaceDownload"
    elif sys.platform.startswith("win"):
        base_dir = Path(os.environ.get("APPDATA", str(Path.home() / "AppData" / "Roaming"))) / "SpaceDownload"
    else:
        base_dir = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config"))) / "SpaceDownload"
    return base_dir / "user_settings.json"



def load_user_settings():
    settings = DEFAULT_USER_SETTINGS.copy()
    settings_path = get_user_settings_path()
    if not settings_path.exists():
        return settings
    try:
        loaded = json.loads(settings_path.read_text(encoding="utf-8"))
    except Exception:
        return settings
    if not isinstance(loaded, dict):
        return settings
    for key in settings:
        if key in loaded:
            settings[key] = loaded[key]
    return settings



def collect_user_settings():
    return {key: st.session_state.get(key, default_value) for key, default_value in DEFAULT_USER_SETTINGS.items()}



def save_user_settings(settings):
    settings_path = get_user_settings_path()
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2), encoding="utf-8")



def initialize_user_settings_state():
    if st.session_state.get("_user_settings_initialized"):
        return
    loaded_settings = load_user_settings()
    for key, value in loaded_settings.items():
        if key not in st.session_state:
            st.session_state[key] = value
    st.session_state["_last_saved_user_settings"] = collect_user_settings()
    st.session_state["_user_settings_initialized"] = True



def persist_user_settings_if_needed():
    current_settings = collect_user_settings()
    if current_settings == st.session_state.get("_last_saved_user_settings"):
        return
    save_user_settings(current_settings)
    st.session_state["_last_saved_user_settings"] = current_settings


st.set_page_config(
    page_title="🚀Space Download",
    page_icon="🚀",
    layout="wide",
    initial_sidebar_state="expanded",
)

st.markdown(
    """
    <style>
    header, [data-testid="stHeader"] {
        background: transparent !important;
        border: none !important;
        box-shadow: none !important;
        min-height: 0 !important;
        height: 0 !important;
        line-height: 0 !important;
        padding: 0 !important;
        margin: 0 !important;
        overflow: visible !important;
    }
    [data-testid="stDecoration"], [data-testid="stHeaderActionElements"] {
        display: none !important;
    }
    [data-testid="stToolbar"] {
        min-height: 0 !important;
        height: 0 !important;
        padding: 0 !important;
        margin: 0 !important;
        overflow: visible !important;
        background: transparent !important;
        position: relative !important;
    }
    [data-testid="stToolbar"] > div {
        min-height: 0 !important;
        height: 0 !important;
        padding: 0 !important;
        margin: 0 !important;
        overflow: visible !important;
    }
    [data-testid="stToolbar"] > div > div:last-child,
    [data-testid="stAppDeployButton"],
    [data-testid="stToolbarActions"],
    [data-testid="stMainMenu"] {
        display: none !important;
    }
    .stHeadingAnchor, a[href^="#"] {
        display: none !important;
    }
    [data-testid="stSidebarHeader"] {
        min-height: 0 !important;
        height: 0 !important;
        padding: 0 !important;
        margin: 0 !important;
        overflow: visible !important;
        position: relative !important;
    }
    [data-testid="stSidebarCollapseButton"], [data-testid="stExpandSidebarButton"] {
        display: flex !important;
        visibility: visible !important;
        opacity: 1 !important;
        z-index: 1000 !important;
    }
    [data-testid="stSidebarCollapseButton"] {
        position: absolute !important;
        top: 0.15rem !important;
        right: 0.3rem !important;
        margin: 0 !important;
        padding: 0 !important;
        background: transparent !important;
    }
    [data-testid="stExpandSidebarButton"] {
        position: fixed !important;
        top: 0.22rem !important;
        left: 0.45rem !important;
        padding: 0 !important;
        margin: 0 !important;
        background: transparent !important;
    }
    [data-testid="stSidebarCollapseButton"] button,
    [data-testid="stExpandSidebarButton"] {
        min-height: 34px !important;
        width: 34px !important;
        height: 34px !important;
        border-radius: 10px !important;
        background: rgba(0, 0, 0, 0.88) !important;
        border: 1px solid #333 !important;
    }
    .stApp { background-color: #000000; color: #ffffff; }
    .stTextInput div[data-baseweb="input"] {
        height: 48px !important;
        background-color: #000000 !important;
        border: 2px solid #ff9900 !important;
        border-radius: 12px !important;
        padding: 0 10px !important;
    }
    .stTextInput input {
        font-size: 17px !important;
        font-weight: bold !important;
        color: #ff9900 !important;
        text-align: left !important;
        background-color: transparent !important;
        height: 48px !important;
        line-height: 48px !important;
    }
    .stTextArea div[data-baseweb="textarea"] {
        background-color: #000000 !important;
        background: #000000 !important;
        border: 2px solid #ff9900 !important;
        border-radius: 12px !important;
        padding: 8px 10px !important;
    }
    .stTextArea div[data-baseweb="textarea"] > div,
    .stTextArea div[data-baseweb="textarea"] > div > div {
        background-color: transparent !important;
    }
    .stTextArea textarea {
        color: #ff9900 !important;
        font-size: 19px !important;
        font-weight: bold !important;
        background: transparent !important;
        background-color: transparent !important;
        background-image: none !important;
        min-height: 96px !important;
        line-height: 1.4 !important;
        box-shadow: none !important;
    }
    .stTextArea textarea::placeholder {
        color: rgba(255, 153, 0, 0.4) !important;
    }
    .stTextInput input::placeholder { color: rgba(255, 153, 0, 0.4) !important; }
    .stTextInput div[data-baseweb="input"] > div { border: none !important; background-color: transparent !important; }
    [data-testid="stSidebar"] .stTextInput div[data-baseweb="input"],
    [data-testid="stSidebar"] .stTextArea div[data-baseweb="textarea"],
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
    [data-testid="stSidebar"] textarea {
        font-size: 14px !important;
        color: #ffffff !important;
        font-weight: normal !important;
        min-height: 40px !important;
    }
    .stButton > button {
        background-color: #ff9900 !important;
        color: #000000 !important;
        font-weight: bold !important;
        border: none !important;
        border-radius: 14px !important;
        height: 54px !important;
        font-size: 17px !important;
        width: 100% !important;
        padding: 0 12px !important;
        white-space: nowrap !important;
        word-break: keep-all !important;
        overflow: hidden !important;
        text-overflow: ellipsis !important;
    }
    [data-testid="stSidebar"] .stButton > button {
        height: 40px !important;
        font-size: 14px !important;
        border-radius: 5px !important;
        white-space: nowrap !important;
        padding: 0 8px !important;
        min-width: 0 !important;
    }
    .stSidebar { background-color: #111111; border-right: 1px solid #333; }
    h1, h2, h3 { color: #ff9900 !important; text-align: left !important; }
    [data-testid="stSidebar"] h1 { text-align: left !important; font-size: 24px !important; }
    .main .block-container,
    [data-testid="stMainBlockContainer"] {
        padding-top: 2rem !important;
        padding-bottom: 1rem !important;
        max-height: 100vh;
        overflow: hidden !important;
    }
    html, body, [data-testid="stAppViewContainer"], [data-testid="stMain"], [data-testid="stAppViewContainer"] > .main {
        height: 100vh !important;
        overflow: hidden !important;
    }
    [data-testid="stSidebarContent"] {
        padding-top: 0.2rem !important;
    }
    ::-webkit-scrollbar {
        display: none !important;
        width: 0 !important;
    }
    .log-area {
        background-color: #0a0a0a;
        border: 1px solid #333;
        border-radius: 10px;
        padding: 12px;
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
    .log-area::-webkit-scrollbar {
        display: block;
        width: 6px;
    }
    .log-area::-webkit-scrollbar-thumb {
        background: #333;
        border-radius: 10px;
    }
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
    .stProgress { display: none !important; }
    [data-testid="stSidebar"] section {
        padding-top: 0.2rem !important;
    }
    .sidebar-title {
        color: #ff9900;
        font-size: 1.95rem;
        font-weight: 700;
        line-height: 1.08;
        margin: 0.08rem 0 0.92rem 0;
        display: block;
    }
    </style>
""",
    unsafe_allow_html=True,
)

initialize_user_settings_state()

if "sid" not in st.session_state:
    st.session_state.sid = str(uuid.uuid4())
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
    st.session_state.task_counts = {"current": 0, "total": 0, "completed": 0, "failed": 0}
if "_done_handled" not in st.session_state:
    st.session_state._done_handled = False


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



def is_pornhub_url(url):
    host = (urlsplit(url or "").hostname or "").lower()
    return "pornhub" in host



def supports_page_url_selection(url):
    if not is_collection_url(url) or not is_pornhub_url(url):
        return False
    return "/playlist/" not in (urlsplit(url or "").path or "").lower()



def update_page_query(url, page_num):
    split_result = urlsplit(url)
    query_items = [(key, value) for key, value in parse_qsl(split_result.query, keep_blank_values=True) if key != "page"]
    query_items.append(("page", str(page_num)))
    return urlunsplit(
        (
            split_result.scheme,
            split_result.netloc,
            split_result.path,
            urlencode(query_items),
            split_result.fragment,
        )
    )



def build_pornhub_page_url(url, page_num):
    split_result = urlsplit(url)
    clean_path = split_result.path.rstrip("/") or split_result.path
    path_lower = clean_path.lower()
    root_collection_markers = (
        "/model/",
        "/models/",
        "/channels/",
        "/channel/",
        "/users/",
        "/user/",
        "/pornstar/",
        "/pornstars/",
    )
    if any(path_lower.startswith(marker) for marker in root_collection_markers) and "/videos" not in path_lower:
        clean_path = f"{clean_path}/videos"
    normalized_url = urlunsplit(
        (
            split_result.scheme,
            split_result.netloc,
            clean_path,
            split_result.query,
            split_result.fragment,
        )
    )
    return update_page_query(normalized_url, page_num)



def log_json_metadata(task_queue, prefix, info_dict):
    if not isinstance(info_dict, dict):
        task_queue.put(("log", f"{prefix}: <empty>"))
        return

    relevant_keys = [
        "id",
        "title",
        "alt_title",
        "uploader",
        "channel",
        "upload_date",
        "duration",
        "view_count",
        "like_count",
        "comment_count",
        "webpage_url",
        "original_url",
        "extractor",
        "extractor_key",
        "format",
        "format_id",
        "ext",
        "resolution",
        "width",
        "height",
        "fps",
        "filesize",
        "filesize_approx",
        "thumbnail",
        "description",
        "tags",
        "categories",
        "age_limit",
    ]
    filtered_info = {key: info_dict.get(key) for key in relevant_keys if info_dict.get(key) not in (None, "", [], {})}

    formats = info_dict.get("formats")
    if isinstance(formats, list):
        filtered_formats = []
        for item in formats[:8]:
            if not isinstance(item, dict):
                continue
            filtered_item = {
                "format_id": item.get("format_id"),
                "ext": item.get("ext"),
                "resolution": item.get("resolution"),
                "width": item.get("width"),
                "height": item.get("height"),
                "fps": item.get("fps"),
                "filesize": item.get("filesize") or item.get("filesize_approx"),
                "protocol": item.get("protocol"),
                "format_note": item.get("format_note"),
            }
            filtered_item = {key: value for key, value in filtered_item.items() if value not in (None, "")}
            if filtered_item:
                filtered_formats.append(filtered_item)
        if filtered_formats:
            filtered_info["formats"] = filtered_formats

    try:
        metadata_text = json.dumps(filtered_info, ensure_ascii=False, indent=2, default=str)
    except Exception:
        metadata_text = json.dumps({k: str(v) for k, v in filtered_info.items()}, ensure_ascii=False, indent=2)
    task_queue.put(("log", f"{prefix}:\n{metadata_text}"))



def parse_input_urls(raw_text):
    urls = []
    for line in (raw_text or "").splitlines():
        line = line.strip()
        if line:
            urls.append(line)
    return urls



def parse_page_selection(selection_text):
    selection = (selection_text or "").strip()
    if not selection:
        return None
    pages = set()
    for part in selection.split(","):
        token = part.strip()
        if not token:
            continue
        try:
            if "-" in token:
                start_text, end_text = token.split("-", 1)
                start = int(start_text.strip())
                end = int(end_text.strip())
                if start <= 0 or end <= 0 or end < start:
                    raise ValueError
                for page in range(start, end + 1):
                    pages.add(page)
            else:
                page = int(token)
                if page <= 0:
                    raise ValueError
                pages.add(page)
        except ValueError as exc:
            raise ValueError(f"无效分页输入: {token}") from exc
    return pages



def build_thumbnail_headers(source_url):
    return PORNHUB_HEADERS if is_pornhub_url(source_url) else COMMON_HEADERS



def download_thumbnail(task_queue, source_url, ydl_opts, info_dict):
    thumbnail_url = info_dict.get("thumbnail")
    if not thumbnail_url:
        return
    ydl_config = {
        "paths": ydl_opts.get("paths"),
        "outtmpl": ydl_opts.get("outtmpl"),
        "restrictfilenames": ydl_opts.get("restrictfilenames", False),
    }
    with yt_dlp.YoutubeDL(ydl_config) as ydl_temp:
        target_path = Path(ydl_temp.prepare_filename(info_dict)).with_suffix(".jpg")
    target_path.parent.mkdir(parents=True, exist_ok=True)
    response = requests.get(thumbnail_url, headers=build_thumbnail_headers(source_url), timeout=15)
    response.raise_for_status()
    target_path.write_bytes(response.content)
    task_queue.put(("log", f"INFO: 已保存封面图: {target_path.name}"))



def log_failure_summary(task_queue, failures):
    if not failures:
        return
    task_queue.put(("log", f"以下视频下载失败，共 {len(failures)} 个:"))
    for index, failure in enumerate(failures, start=1):
        title = failure.get("title") or "未知标题"
        url = failure.get("url") or "未知链接"
        error = failure.get("error") or "未知错误"
        task_queue.put(("log", f"[失败 {index}] {title}\n链接: {url}\n原因: {error}"))



def normalize_entries(info):
    if not isinstance(info, dict):
        return []
    entries = info.get("entries") or []
    if not isinstance(entries, (list, tuple)):
        entries = list(entries)
    return [entry for entry in entries if isinstance(entry, dict)]



def create_temp_cookie_file(temp_dir, filename, lines=None, payload=None):
    path = register_temp_path(os.path.join(temp_dir, filename))
    if payload is not None:
        Path(path).write_bytes(payload)
    else:
        text = "# Netscape HTTP Cookie File\n"
        if lines:
            text += "\n".join(lines) + "\n"
        Path(path).write_text(text, encoding="utf-8")
    return path



def build_base_opts(quality, out_format, filename_tmpl, save_dir, temp_dir, ffmpeg_path, proxy_url=None, auth=None):
    opts = {
        "format": quality,
        "n_threads": 3,
        "outtmpl": {
            "default": f"{filename_tmpl}.%(ext)s",
            "thumbnail": f"{filename_tmpl}.%(ext)s",
        },
        "writethumbnail": False,
        "postprocessors": [
            {
                "key": "FFmpegVideoConvertor",
                "preferedformat": out_format,
            },
        ],
        "noplaylist": False,
        "restrictfilenames": False,
        "noprogress": True,
        "concurrent_fragment_downloads": 8,
        "merge_output_format": out_format,
        "paths": {
            "home": save_dir,
            "temp": temp_dir,
        },
        "keep_fragments": False,
        "nopart": True,
        "socket_timeout": 30,
        "retries": 5,
        "fragment_retries": 5,
        "http_chunk_size": 0,
        "hls_use_mpegts": True,
        "http_headers": COMMON_HEADERS.copy(),
    }
    if ffmpeg_path:
        opts["ffmpeg_location"] = ffmpeg_path
    if proxy_url:
        opts["proxy"] = proxy_url
    if auth:
        opts.update(auth)
    return opts



def build_opts_for_url(base_opts, url, cookiefile=None):
    opts = base_opts.copy()
    opts["http_headers"] = COMMON_HEADERS.copy()
    if is_pornhub_url(url):
        opts["http_headers"] = PORNHUB_HEADERS.copy()
        if cookiefile:
            opts["cookiefile"] = cookiefile
    elif cookiefile:
        opts["cookiefile"] = cookiefile
    return opts



def resolve_ffmpeg_path():
    return shutil.which("ffmpeg")



def download_worker(task_queue, stop_event, urls, base_opts, translate_title, embed_thumbnail_flag, page_selection, cookiefiles):
    important_debug_markers = (
        "Destination:",
        "Download completed",
        "MoveFiles",
        "VideoConvertor",
        "Merging formats into",
        "Deleting original file",
        "Extracting URL",
    )

    class InnerLogger:
        def debug(self, msg):
            if stop_event.is_set():
                raise Exception("USER_STOPPED")
            message = str(msg)
            if any(marker in message for marker in important_debug_markers):
                task_queue.put(("log", f"DEBUG: {message}"))

        def info(self, msg):
            if stop_event.is_set():
                raise Exception("USER_STOPPED")
            message = str(msg)
            if message.startswith("[download]") or message.startswith("[ExtractAudio]"):
                task_queue.put(("log", f"INFO: {message}"))

        def warning(self, msg):
            if stop_event.is_set():
                raise Exception("USER_STOPPED")
            task_queue.put(("log", f"WARN: {msg}"))

        def error(self, msg):
            if stop_event.is_set():
                raise Exception("USER_STOPPED")
            task_queue.put(("log", f"ERROR: {msg}"))

    stats = {"current": 0, "total": 0, "completed": 0, "failed": 0}
    failures = []

    def update_counts():
        stats["current"] = stats["completed"] + stats["failed"]
        task_queue.put(("task_count", stats.copy()))

    def update_overall_progress():
        total = max(stats["total"], 1)
        task_queue.put(("progress", min((stats["completed"] + stats["failed"]) / total, 1.0)))

    def record_failure(url, error, title=None):
        failures.append({"title": title or "", "url": url, "error": str(error)})
        stats["failed"] += 1
        update_counts()
        update_overall_progress()
        task_queue.put(("log", f"❌ 视频下载失败: {title or url} | {error}"))

    def mark_success():
        stats["completed"] += 1
        update_counts()
        update_overall_progress()

    def progress_hook(d):
        if stop_event.is_set():
            raise Exception("USER_STOPPED")
        if d.get("status") == "downloading":
            percent_str = (d.get("_percent_str") or "0%").replace("%", "").strip()
            try:
                percent = float(percent_str) / 100.0
                task_queue.put(("progress", percent))
            except Exception:
                pass
            task_queue.put(
                (
                    "status",
                    f"📦 正在下载: {d.get('_percent_str')} | 速度: {d.get('_speed_str')} | 剩余: {d.get('_eta_str')}",
                )
            )
        elif d.get("status") == "finished":
            task_queue.put(("progress", 1.0))

    try:
        for url_index, url in enumerate(urls, start=1):
            if stop_event.is_set():
                break
            task_queue.put(("log", f"正在解析链接 [{url_index}/{len(urls)}]: {url}"))
            url_cookiefile = cookiefiles.get("pornhub") if is_pornhub_url(url) else cookiefiles.get("default")
            auto_playlist = is_collection_url(url)

            if not auto_playlist:
                single_opts = build_opts_for_url(base_opts, url, url_cookiefile)
                single_opts.update({
                    "logger": InnerLogger(),
                    "progress_hooks": [progress_hook],
                    "noplaylist": True,
                    "ignoreerrors": False,
                })
                stats["total"] += 1
                update_counts()
                with yt_dlp.YoutubeDL(single_opts) as ydl:
                    item_info = None
                    try:
                        task_queue.put(("log", "正在提取视频元数据..."))
                        item_info = ydl.extract_info(url, download=False)
                        if not isinstance(item_info, dict):
                            raise Exception("解析结果为空，未获取到视频信息")
                        log_json_metadata(task_queue, "JSON metadata", item_info)
                        if translate_title:
                            item_info["title"] = translate_text(item_info.get("title", ""))
                        ydl.process_ie_result(item_info, download=True)
                        if embed_thumbnail_flag:
                            download_thumbnail(task_queue, url, single_opts, item_info)
                        mark_success()
                    except Exception as e:
                        record_failure(url, e, (item_info or {}).get("title"))
                continue

            extract_opts = build_opts_for_url(base_opts, url, url_cookiefile)
            extract_opts.update({
                "extract_flat": "in_playlist",
                "logger": InnerLogger(),
                "noplaylist": False,
            })
            with yt_dlp.YoutubeDL(extract_opts) as ydl_extract:
                selected_entries = []
                seen_urls = set()

                def append_entry(entry, index, page_num=None, page_item_index=None):
                    if not isinstance(entry, dict):
                        return False
                    entry_url = entry.get("webpage_url") or entry.get("original_url") or entry.get("url")
                    if not (isinstance(entry_url, str) and entry_url.startswith("http")):
                        return False
                    if entry_url in seen_urls:
                        return False
                    seen_urls.add(entry_url)
                    selected_entries.append(
                        {
                            "index": index,
                            "url": entry_url,
                            "title": entry.get("title") or "",
                            "page": page_num,
                            "page_item_index": page_item_index,
                        }
                    )
                    return True

                if page_selection and supports_page_url_selection(url):
                    requested_pages = sorted(page_selection)
                    task_queue.put(("log", f"正在按网页分页解析列表: 第 {', '.join(str(page) for page in requested_pages)} 页"))
                    for page_num in requested_pages:
                        page_url = build_pornhub_page_url(url, page_num)
                        task_queue.put(("log", f"正在快速扫描第 {page_num} 页: {page_url}"))
                        try:
                            page_info = ydl_extract.extract_info(page_url, download=False)
                        except Exception as page_error:
                            task_queue.put(("log", f"WARN: 第 {page_num} 页解析失败: {page_error}"))
                            continue
                        page_entries = normalize_entries(page_info)
                        page_added = 0
                        for page_item_index, entry in enumerate(page_entries, start=1):
                            page_added += int(
                                append_entry(entry, len(selected_entries) + 1, page_num=page_num, page_item_index=page_item_index)
                            )
                        task_queue.put(("log", f"第 {page_num} 页识别到 {page_added} 个可下载视频"))
                    task_queue.put(("log", f"✅ 已按网页页码筛选 {len(requested_pages)} 页，共 {len(selected_entries)} 个视频"))
                else:
                    if page_selection and not supports_page_url_selection(url):
                        task_queue.put(("log", "WARN: 当前链接不支持按网页页码筛选，已忽略页码输入并按整个列表下载"))
                    task_queue.put(("log", "正在快速扫描列表信息..."))
                    list_info = ydl_extract.extract_info(url, download=False)
                    entries = normalize_entries(list_info)
                    for idx, entry in enumerate(entries, start=1):
                        append_entry(entry, idx)
                    task_queue.put(("log", f"✅ 识别到批量列表，共 {len(selected_entries)} 个视频"))

            if not selected_entries:
                raise Exception("批量解析失败：未获取到可下载的视频链接")

            stats["total"] += len(selected_entries)
            update_counts()

            for entry in selected_entries:
                if stop_event.is_set():
                    break
                item_url = entry["url"]
                item_title = entry["title"]
                item_index = entry["index"]
                item_page = entry.get("page")
                item_page_index = entry.get("page_item_index")
                item_info = None
                final_opts = build_opts_for_url(base_opts, item_url, url_cookiefile)
                final_opts.update({
                    "logger": InnerLogger(),
                    "progress_hooks": [progress_hook],
                    "ignoreerrors": True,
                })
                with yt_dlp.YoutubeDL(final_opts) as ydl:
                    try:
                        item_info = ydl.extract_info(item_url, download=False)
                        if not isinstance(item_info, dict):
                            raise Exception("视频信息为空")
                        if item_page:
                            metadata_label = f"JSON metadata [第 {item_page} 页 / 第 {item_page_index} 个视频]"
                        else:
                            metadata_label = f"JSON metadata [第 {item_index} 个视频]"
                        log_json_metadata(task_queue, metadata_label, item_info)
                        if translate_title:
                            item_info["title"] = translate_text(item_info.get("title", ""))
                        ydl.process_ie_result(item_info, download=True)
                        if embed_thumbnail_flag:
                            download_thumbnail(task_queue, item_url, final_opts, item_info)
                        mark_success()
                    except Exception as e:
                        record_failure(item_url, e, item_title or (item_info or {}).get("title"))

        log_failure_summary(task_queue, failures)
        task_queue.put(("log", f"任务完成：成功 {stats['completed']} 个，失败 {stats['failed']} 个"))
        task_queue.put(("done", "success" if not stop_event.is_set() else "stopped"))
    except Exception as e:
        task_queue.put(("done", "stopped" if "USER_STOPPED" in str(e) else f"error:{e}"))
    finally:
        for key, path in cookiefiles.items():
            if path and os.path.exists(path):
                try:
                    os.remove(path)
                except Exception as cleanup_error:
                    task_queue.put(("log", f"WARN: 清理临时文件失败 {os.path.basename(path)}: {cleanup_error}"))


with st.sidebar:
    st.markdown('<div class="sidebar-title">设置</div>', unsafe_allow_html=True)
    quality_options = {
        "最佳": "best",
        "4K (2160p)": "bestvideo[height<=2160]+bestaudio/best[height<=2160]",
        "2K (1440p)": "bestvideo[height<=1440]+bestaudio/best[height<=1440]",
        "1080p": "bestvideo[height<=1080]+bestaudio/best[height<=1080]",
        "720p": "bestvideo[height<=720]+bestaudio/best[height<=720]",
        "480p": "bestvideo[height<=480]+bestaudio/best[height<=480]",
    }
    quality_names = list(quality_options.keys())
    saved_quality = st.session_state.get("saved_quality", quality_names[0])
    if saved_quality not in quality_names:
        st.session_state.saved_quality = quality_names[0]
    quality = st.selectbox("视频质量", quality_names, key="saved_quality")

    output_formats = ["mp4", "mkv", "webm", "flv"]
    saved_out_format = st.session_state.get("saved_out_format", output_formats[0])
    if saved_out_format not in output_formats:
        st.session_state.saved_out_format = output_formats[0]
    out_format = st.selectbox("输出视频格式", output_formats, key="saved_out_format")
    if st.session_state.get("_pending_download_path"):
        st.session_state.download_path = st.session_state.pop("_pending_download_path")
    st.caption("保存目录")
    col_dir, col_browse = st.columns([5, 1.3])
    with col_dir:
        st.text_input("保存目录", key="download_path", label_visibility="collapsed")
        save_dir = st.session_state.download_path
    with col_browse:
        browse_clicked = st.button("浏览", key="browse_dir")
    if browse_clicked:
        try:
            import platform

            chosen = ""
            if platform.system() == "Darwin":
                result = subprocess.run(
                    ["osascript", "-e", 'POSIX path of (choose folder with prompt "选择保存目录")'],
                    capture_output=True,
                    text=True,
                    timeout=60,
                )
                chosen = result.stdout.strip()
            elif platform.system() == "Windows":
                import tkinter as tk
                from tkinter import filedialog

                root = tk.Tk()
                root.withdraw()
                root.attributes("-topmost", True)
                chosen = filedialog.askdirectory(title="选择保存目录") or ""
                root.destroy()
            if chosen:
                st.session_state["_pending_download_path"] = chosen
                st.rerun()
        except Exception as e:
            st.error(f"无法打开目录选择器: {e}")

    name_templates = {
        "仅标题(id)": "%(title)s(%(id)s)",
        "作者-标题(id)": "%(uploader)s-%(title)s(%(id)s)",
        "日期-标题(id)": "%(upload_date)s-%(title)s(%(id)s)",
        "作者/日期-标题(id)": "%(uploader)s/%(upload_date)s-%(title)s(%(id)s)",
        "作者/标题(id)": "%(uploader)s/%(title)s(%(id)s)",
        "自定义": "custom",
    }
    template_names = list(name_templates.keys())
    saved_template_name = st.session_state.get("saved_template_name", template_names[0])
    if saved_template_name not in template_names:
        st.session_state.saved_template_name = template_names[0]
    selected_tpl = st.selectbox("文件命名模板", template_names, key="saved_template_name")
    if selected_tpl == "自定义":
        filename_tmpl = st.text_input("自定义模板", key="saved_custom_template")
    else:
        filename_tmpl = name_templates[selected_tpl]
        st.caption(f"当前规则: `{filename_tmpl}`")

    page_selection_text = st.text_input("批量分页下载", key="saved_page_selection", placeholder="如 1-3,5；留空下载全部")
    translate_title = st.checkbox("翻译标题为中文", key="saved_translate_title")
    embed_thumbnail = st.checkbox("写入封面图", key="saved_embed_thumbnail")

    use_proxy = st.checkbox("启用代理", key="saved_use_proxy")
    proxy_url = st.text_input("代理地址", key="saved_proxy_url", disabled=not use_proxy)

    with st.expander("账号认证 (可选)"):
        username = st.text_input("账号", key="saved_username")
        password = st.text_input("密码", type="password")
        use_cookies = st.checkbox("使用 Cookies 文件", key="saved_use_cookies")
        cookie_file = st.file_uploader("上传 cookies.txt", type=["txt"], disabled=not use_cookies)

persist_user_settings_if_needed()

st.title("🚀Space Download")

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
        elif event_type == "done" and not st.session_state._done_handled:
            st.session_state._done_handled = True
            st.session_state.running = False
            st.session_state.worker = None
            if payload == "success":
                failed_count = st.session_state.task_counts.get("failed", 0)
                if failed_count:
                    st.session_state.status = f"⚠️ 任务完成，失败 {failed_count} 个"
                    append_log(f"任务已全部完成，失败 {failed_count} 个")
                else:
                    st.session_state.status = "✅ 下载完成"
                    append_log("任务已全部完成")
                st.session_state.progress = 1.0
            elif payload == "stopped":
                st.session_state.status = "⏹️ 已停止"
                append_log("用户已停止下载")
            elif payload.startswith("error:"):
                st.session_state.last_error = payload[6:]
                st.session_state.status = "❌ 下载失败"
                append_log(f"错误: {st.session_state.last_error}")
    except queue.Empty:
        break

col_url, col_start, col_stop = st.columns([4.9, 0.86, 0.86], gap="small", vertical_alignment="center")
with col_url:
    url_text = st.text_area(
        "链接",
        placeholder="每行一个视频、频道或列表链接；支持多个单视频链接",
        label_visibility="collapsed",
        height=96,
    )
with col_start:
    start_btn = st.button("开始下载", disabled=st.session_state.running, key="start_download_btn")
with col_stop:
    stop_btn = st.button("停止下载", disabled=not st.session_state.running, key="stop_download_btn")

if stop_btn and st.session_state.running:
    st.session_state.stop_event.set()
    append_log("INFO: 正在发出停止指令...")
    st.rerun()

if start_btn:
    input_urls = parse_input_urls(url_text)
    if not input_urls:
        st.error("请先输入链接！")
    else:
        try:
            page_selection = parse_page_selection(page_selection_text)
        except ValueError as e:
            st.error(str(e))
            st.stop()
        st.session_state.logs = []
        st.session_state.progress = 0.0
        st.session_state.status = "🚀 正在初始化..."
        st.session_state.last_error = ""
        st.session_state.show_success = False
        st.session_state.stop_event = threading.Event()
        st.session_state.queue = queue.Queue()
        st.session_state.running = True
        st.session_state._done_handled = False
        st.session_state.task_counts = {"current": 0, "total": 0, "completed": 0, "failed": 0}
        append_log("开始新任务...")
        append_log(f"已接收 {len(input_urls)} 个链接")
        if page_selection:
            append_log(f"批量页码筛选: {','.join(str(x) for x in sorted(page_selection))}")

        temp_dir = register_temp_path(os.path.join(save_dir, ".yt_dlp_temp", st.session_state.sid))
        os.makedirs(temp_dir, exist_ok=True)

        cookiefiles = {"default": None, "pornhub": None}
        cookiefiles["pornhub"] = create_temp_cookie_file(temp_dir, f"ph_cookies_{st.session_state.sid}.txt", lines=PORNHUB_COOKIE_LINES)
        if use_cookies and cookie_file:
            cookiefiles["default"] = create_temp_cookie_file(
                temp_dir,
                f"user_cookies_{st.session_state.sid}.txt",
                payload=cookie_file.getbuffer(),
            )

        ffmpeg_path = resolve_ffmpeg_path()

        auth = None
        if username and password:
            auth = {"username": username, "password": password}

        base_opts = build_base_opts(
            quality_options[quality],
            out_format,
            filename_tmpl,
            save_dir,
            temp_dir,
            ffmpeg_path,
            proxy_url=proxy_url if use_proxy and proxy_url else None,
            auth=auth,
        )

        worker = threading.Thread(
            target=download_worker,
            args=(
                st.session_state.queue,
                st.session_state.stop_event,
                input_urls,
                base_opts,
                translate_title,
                embed_thumbnail,
                page_selection,
                cookiefiles,
            ),
            daemon=True,
        )
        st.session_state.worker = worker
        worker.start()
        st.rerun()

if st.session_state.running:
    st.caption("下载进行中，界面会自动刷新。")

col_prog, col_perc = st.columns([12, 1])
with col_prog:
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

if st.session_state.task_counts["total"] > 0:
    curr = st.session_state.task_counts["current"]
    total = st.session_state.task_counts["total"]
    completed = st.session_state.task_counts["completed"]
    failed = st.session_state.task_counts["failed"]
    st.markdown(
        f"<div style='text-align: right; color: #ff9900; font-size: 14px; margin-top: -10px;'>进度统计: 已处理 {curr} / {total} 视频 | 成功 {completed} | 失败 {failed}</div>",
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

if st.session_state.running:
    time.sleep(0.4)
    st.rerun()
