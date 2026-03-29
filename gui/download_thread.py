"""QThread 下载线程：用 Qt signal 与 GUI 通信"""

import json
import os
import threading

import requests
import yt_dlp
from PyQt5.QtCore import QThread, pyqtSignal

from sites.base import BaseDownloader


class DownloadThread(QThread):
    log_signal = pyqtSignal(str)
    progress_signal = pyqtSignal(float)
    status_signal = pyqtSignal(str)
    task_count_signal = pyqtSignal(int, int)
    done_signal = pyqtSignal(str)  # "success" / "stopped" / "error:..."

    def __init__(self, url: str, opts: dict, site: BaseDownloader, parent=None):
        super().__init__(parent)
        self.url = url
        self.opts = opts
        self.site = site
        self._stop_event = threading.Event()

    def stop(self):
        self._stop_event.set()

    def _log(self, msg: str):
        self.log_signal.emit(msg)

    def _log_json(self, prefix: str, info: dict):
        if not isinstance(info, dict):
            self._log(f"{prefix}: <empty>")
            return
        try:
            text = json.dumps(info, ensure_ascii=False, indent=2, default=str)
        except Exception:
            text = json.dumps({k: str(v) for k, v in info.items()}, ensure_ascii=False, indent=2)
        self._log(f"{prefix}:\n{text[:2000]}")

    def _translate_title(self, title: str) -> str:
        try:
            from deep_translator import GoogleTranslator

            return GoogleTranslator(source="auto", target="zh-CN").translate(title)
        except Exception:
            return title

    def _download_thumbnail(self, info: dict, save_dir: str, filename_tmpl: str, site: BaseDownloader):
        t_url = info.get("thumbnail")
        if not t_url:
            return
        try:
            with yt_dlp.YoutubeDL({"outtmpl": filename_tmpl}) as ydl_temp:
                base = os.path.splitext(ydl_temp.prepare_filename(info))[0]
                t_path = os.path.join(save_dir, f"{base}.jpg")
            r = requests.get(t_url, headers=site.get_http_headers(), timeout=15, verify=False)
            with open(t_path, "wb") as f:
                f.write(r.content)
            self._log(f"封面已保存: {t_path}")
        except Exception as e:
            self._log(f"封面下载失败: {e}")

    def _progress_hook(self, d):
        if self._stop_event.is_set():
            raise Exception("USER_STOPPED")
        if d["status"] == "downloading":
            pct = d.get("_percent_str", "0%").strip().replace("%", "")
            try:
                self.progress_signal.emit(float(pct) / 100.0)
            except ValueError:
                pass
            spd = d.get("_speed_str", "").strip()
            eta = d.get("_eta_str", "").strip()
            self.status_signal.emit(f"下载中 | 速度: {spd} | 剩余: {eta}")
        elif d["status"] == "finished":
            self.progress_signal.emit(1.0)
            self.status_signal.emit("合并文件中...")

    def run(self):
        try:
            self._run()
        except Exception as e:
            if "USER_STOPPED" in str(e):
                self.done_signal.emit("stopped")
            else:
                self.done_signal.emit(f"error:{e}")

    def _run(self):
        save_dir = self.opts["save_dir"]
        filename_tmpl = self.opts["filename_tmpl"]
        translate = self.opts.get("translate_title", False)
        embed_thumb = self.opts.get("embed_thumbnail", False)
        is_collection = self.site.is_collection_url(self.url)

        base_opts = {
            "format": self.opts["quality"],
            "outtmpl": {"default": f"{filename_tmpl}.%(ext)s", "thumbnail": f"{filename_tmpl}.%(ext)s"},
            "writethumbnail": False,
            "postprocessors": [{"key": "FFmpegVideoConvertor", "preferedformat": self.opts["output_format"]}],
            "restrictfilenames": False,
            "noprogress": True,
            "concurrent_fragment_downloads": 1,
            "merge_output_format": self.opts["output_format"],
            "keep_fragments": False,
            "nopart": True,
            "nocheckcertificate": True,
            "socket_timeout": 30,
            "retries": 10,
            "fragment_retries": 10,
            "http_chunk_size": 0,
            "hls_use_mpegts": True,
            "http_headers": self.site.get_http_headers(),
            "paths": {"home": save_dir, "temp": os.path.join(save_dir, ".temp")},
        }

        cookie = self.site.get_cookie_file(base_opts["paths"]["temp"])
        if cookie:
            base_opts["cookiefile"] = cookie
        if self.opts.get("proxy"):
            base_opts["proxy"] = self.opts["proxy"]
        if self.opts.get("username"):
            base_opts["username"] = self.opts["username"]
        if self.opts.get("password"):
            base_opts["password"] = self.opts["password"]

        if not is_collection:
            self._run_single(base_opts, save_dir, filename_tmpl, translate, embed_thumb)
        else:
            self._run_batch(base_opts, save_dir, filename_tmpl, translate, embed_thumb)

        self.done_signal.emit("success")

    def _run_single(self, base_opts, save_dir, filename_tmpl, translate, embed_thumb):
        self.task_count_signal.emit(0, 1)
        opts = dict(base_opts)
        opts["noplaylist"] = True
        opts["ignoreerrors"] = False
        opts["logger"] = _YtdlLogger(self._log)
        opts["progress_hooks"] = [self._progress_hook]

        with yt_dlp.YoutubeDL(opts) as ydl:
            self._log("正在提取视频元数据...")
            info = ydl.extract_info(self.url, download=False)
            if not isinstance(info, dict):
                raise Exception("解析结果为空")
            self._log_json("JSON metadata", info)

            if translate:
                info["title"] = self._translate_title(info.get("title", ""))
            if embed_thumb:
                self._download_thumbnail(info, save_dir, filename_tmpl, self.site)

            self.task_count_signal.emit(1, 1)
            ydl.process_ie_result(info, download=True)

    def _run_batch(self, base_opts, save_dir, filename_tmpl, translate, embed_thumb):
        extract_opts = dict(base_opts)
        extract_opts["extract_flat"] = "in_playlist"

        with yt_dlp.YoutubeDL(extract_opts) as ydl_extract:
            self._log("正在扫描列表...")
            list_info = ydl_extract.extract_info(self.url, download=False)
            self._log_json("JSON metadata", list_info)

        entries = [e for e in (list_info.get("entries") or []) if isinstance(e, dict)]
        total = len(entries)
        self._log(f"共发现 {total} 个视频")

        urls = []
        for e in entries:
            u = e.get("webpage_url") or e.get("original_url") or e.get("url")
            if isinstance(u, str) and u.startswith("http"):
                urls.append(u)

        final_opts = dict(base_opts)
        final_opts["noplaylist"] = True
        final_opts["ignoreerrors"] = True
        final_opts["logger"] = _YtdlLogger(self._log)
        final_opts["progress_hooks"] = [self._progress_hook]

        with yt_dlp.YoutubeDL(final_opts) as ydl:
            for idx, item_url in enumerate(urls):
                if self._stop_event.is_set():
                    self.done_signal.emit("stopped")
                    return

                self.task_count_signal.emit(idx + 1, total)
                self._log(f"[{idx + 1}/{total}] {item_url}")

                try:
                    info = ydl.extract_info(item_url, download=False)
                    if not isinstance(info, dict):
                        self._log(f"[{idx + 1}] 解析失败，跳过")
                        continue

                    self._log_json(f"JSON metadata [{idx + 1}/{total}]", info)

                    if translate:
                        info["title"] = self._translate_title(info.get("title", ""))
                    if embed_thumb:
                        self._download_thumbnail(info, save_dir, filename_tmpl, self.site)

                    ydl.process_ie_result(info, download=True)
                except Exception as e:
                    self._log(f"[{idx + 1}] 下载失败: {e}")


class _YtdlLogger:
    def __init__(self, log_fn):
        self._log = log_fn

    def debug(self, msg):
        if msg.startswith("[download]"):
            self._log(msg)
        elif msg.startswith("[PornHub]") or msg.startswith("[generic]"):
            self._log(f"DEBUG: {msg}")

    def warning(self, msg):
        self._log(f"WARN: {msg}")

    def error(self, msg):
        self._log(f"ERROR: {msg}")
