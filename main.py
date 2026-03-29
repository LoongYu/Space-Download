#!/usr/bin/env python3
import os
import sys
import socket
import time
import multiprocessing

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


def get_free_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def run_streamlit_server(gui_script, port):
    """在独立进程里启动 streamlit 服务器"""
    from streamlit.web import bootstrap

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

    bootstrap.run(gui_script, "", [], server_args)


def wait_for_server(port, timeout=30):
    """等待 streamlit 页面真正可访问"""
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            import urllib.request

            resp = urllib.request.urlopen(f"http://127.0.0.1:{port}", timeout=2)
            if resp.status == 200:
                return True
        except Exception:
            pass
        time.sleep(0.5)
    return False


def main():
    import webview

    if getattr(sys, "frozen", False):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))

    gui_script = os.path.join(base_path, "yt_dlp_gui.py")
    port = get_free_port()

    # streamlit 放到独立进程
    server_proc = multiprocessing.Process(
        target=run_streamlit_server,
        args=(gui_script, port),
        daemon=True,
    )
    server_proc.start()

    # 等 streamlit 真正可访问（不只是端口开了）
    if not wait_for_server(port, timeout=30):
        print("Streamlit 服务启动超时")
        server_proc.terminate()
        sys.exit(1)

    # pywebview 必须在主线程
    window = webview.create_window(
        "Space Download",
        f"http://127.0.0.1:{port}",
        width=1000,
        height=700,
        background_color="#000000",
        resizable=True,
    )

    import threading

    def force_reload(w, url):
        time.sleep(3)
        try:
            w.load_url(url)
        except Exception:
            pass

    threading.Thread(target=force_reload, args=(window, f"http://127.0.0.1:{port}"), daemon=True).start()

    try:
        webview.start(debug=False)
    finally:
        server_proc.terminate()
        server_proc.join(timeout=3)
        os._exit(0)


if __name__ == "__main__":
    multiprocessing.freeze_support()

    # Windows --windowed 模式写日志
    if sys.platform == "win32" and getattr(sys, "frozen", False):
        log_dir = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "logs")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, "app.log")
        sys.stdout = open(log_file, "a", encoding="utf-8")
        sys.stderr = sys.stdout

    main()
