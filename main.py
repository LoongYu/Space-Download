#!/usr/bin/env python3
import os
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import traceback

import webview


def get_log_file():
    if not getattr(sys, "frozen", False):
        return None
    log_dir = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "logs")
    os.makedirs(log_dir, exist_ok=True)
    return os.path.join(log_dir, "app.log")


def log_message(message):
    log_file = get_log_file()
    if log_file:
        with open(log_file, "a", encoding="utf-8", errors="replace") as f:
            f.write(f"{time.strftime('%Y-%m-%d %H:%M:%S')} {message}\n")
    else:
        print(message, flush=True)


def get_free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


def is_port_open(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(1)
        return s.connect_ex(("127.0.0.1", port)) == 0


def get_base_path():
    if getattr(sys, "frozen", False):
        meipass = getattr(sys, "_MEIPASS", None)
        if meipass:
            return meipass
        return os.path.dirname(os.path.abspath(sys.executable))
    return os.path.dirname(os.path.abspath(__file__))


def get_python_executable():
    if not getattr(sys, "frozen", False):
        return sys.executable

    candidates = [
        "/opt/homebrew/bin/python3.11",
        shutil.which("python3.11"),
        shutil.which("python3"),
    ]
    python_exe = next((p for p in candidates if p and os.path.exists(p)), None)
    if not python_exe:
        raise RuntimeError("未找到可用的 Python 解释器（需要 python3.11 或 python3）")
    return python_exe


def terminate_process_group(proc):
    if not proc:
        return
    try:
        os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        time.sleep(0.5)
        if proc.poll() is None:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass


def run_app():
    base_path = get_base_path()
    python_exe = get_python_executable()
    gui_script = os.path.join(base_path, "yt_dlp_gui.py")
    port = get_free_port()

    log_message(f"Launching app. base_path={base_path} gui_script={gui_script}")
    log_message(f"Using python executable: {python_exe}")
    log_message(f"Selected port: {port}")

    env = os.environ.copy()
    if getattr(sys, "frozen", False):
        env["PYTHONPATH"] = base_path
        env["STREAMLIT_SERVER_STATIC_FILE_PATH"] = os.path.join(base_path, "streamlit", "static")

    cmd = [
        python_exe,
        "-m",
        "streamlit",
        "run",
        gui_script,
        "--global.developmentMode",
        "false",
        "--global.showWarningOnDirectExecution",
        "false",
        "--server.port",
        str(port),
        "--server.headless",
        "true",
        "--browser.gatherUsageStats",
        "false",
        "--server.runOnSave",
        "false",
        "--server.address",
        "127.0.0.1",
    ]

    log_message(f"Starting Streamlit subprocess: {' '.join(cmd)}")
    proc = subprocess.Popen(
        cmd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True,
    )

    def log_reader(pipe):
        try:
            for line in iter(pipe.readline, ""):
                log_message(f"[Streamlit] {line.rstrip()}")
        except Exception:
            log_message("Streamlit log reader crashed:\n" + traceback.format_exc())

    threading.Thread(target=log_reader, args=(proc.stdout,), daemon=True).start()

    max_retries = 80
    retry_count = 0
    while not is_port_open(port) and retry_count < max_retries:
        if proc.poll() is not None:
            log_message(f"Streamlit 子进程提前退出，退出码: {proc.returncode}")
            raise RuntimeError(f"Streamlit 子进程提前退出，退出码: {proc.returncode}")
        time.sleep(0.5)
        retry_count += 1

    if retry_count >= max_retries:
        log_message("Streamlit 服务启动超时")
        terminate_process_group(proc)
        raise RuntimeError("Streamlit 服务启动超时")

    log_message("Streamlit 服务已就绪，开始创建窗口")
    window = webview.create_window(
        "Space Download",
        f"http://127.0.0.1:{port}",
        width=1600,
        height=900,
        background_color="#000000",
        resizable=True,
    )

    try:
        webview.start(debug=False)
    except Exception:
        log_message("webview.start crashed:\n" + traceback.format_exc())
        raise
    finally:
        log_message("Cleaning up Streamlit subprocess")
        terminate_process_group(proc)


if __name__ == "__main__":
    if getattr(sys, "frozen", False):
        log_file = get_log_file()
        sys.stdout = open(log_file, "a", encoding="utf-8", errors="replace")
        sys.stderr = sys.stdout

    run_app()
