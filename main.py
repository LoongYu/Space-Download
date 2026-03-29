#!/usr/bin/env python3
import os
import sys
import socket
import threading
import time
import webview

# Windows: 修复 cp1252 编码崩溃
if sys.platform == "win32":
    try:
        if sys.stdout:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if sys.stderr:
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass

# frozen 模式下，把 bundled 目录加到 sys.path
if getattr(sys, "frozen", False):
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass and meipass not in sys.path:
        sys.path.insert(0, meipass)

import streamlit
from streamlit.web import bootstrap
from streamlit import config as st_config


def get_free_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def start_streamlit(gui_script, port):
    """在当前进程内启动 streamlit 服务器"""
    server_args = type(
        "Args",
        (),
        {
            "global_development_mode": False,
            "global_log_level": "error",
            "global_disable_watchdog_warning": False,
            "global_show_warning_on_direct_execution": False,
            "server_headless": True,
            "server_port": port,
            "server_address": "127.0.0.1",
            "browser_gather_usage_stats": False,
            "server_run_on_save": False,
        },
    )()

    bootstrap.load_config_options(
        flag_options={
            "server.port": port,
            "server.address": "127.0.0.1",
            "server.headless": True,
            "browser.gatherUsageStats": False,
            "server.runOnSave": False,
            "global.developmentMode": False,
            "global.showWarningOnDirectExecution": False,
        }
    )

    bootstrap.run(gui_script, "", [], server_args)


def main():
    if getattr(sys, "frozen", False):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))

    gui_script = os.path.join(base_path, "yt_dlp_gui.py")
    port = get_free_port()

    # 在后台线程启动 streamlit 服务器
    def run_server():
        try:
            start_streamlit(gui_script, port)
        except Exception as e:
            print(f"Streamlit 服务异常: {e}")

    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()

    # 等待 streamlit 就绪
    for _ in range(60):
        try:
            with socket.create_connection(("127.0.0.1", port), timeout=1):
                break
        except OSError:
            time.sleep(0.5)

    # 创建桌面窗口
    window = webview.create_window(
        "Space Download",
        f"http://127.0.0.1:{port}",
        width=1000,
        height=700,
        background_color="#000000",
        resizable=True,
    )

    def force_reload(w, url):
        time.sleep(2)
        w.load_url(url)

    threading.Thread(target=force_reload, args=(window, f"http://127.0.0.1:{port}"), daemon=True).start()

    try:
        webview.start(debug=False)
    finally:
        os._exit(0)


if __name__ == "__main__":
    # Windows --windowed 模式写日志
    if sys.platform == "win32" and getattr(sys, "frozen", False):
        log_dir = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "logs")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, "app.log")
        sys.stdout = open(log_file, "a", encoding="utf-8")
        sys.stderr = sys.stdout
    main()
