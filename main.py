import os
import sys
import socket
import threading
import time
import webview
import subprocess
import shutil

if sys.platform == "win32":
    try:
        if sys.stdout:
            sys.stdout.reconfigure(encoding="utf-8", errors="replace")
        if sys.stderr:
            sys.stderr.reconfigure(encoding="utf-8", errors="replace")
    except Exception:
        pass


def get_free_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def is_port_open(port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.settimeout(1)
        return s.connect_ex(("127.0.0.1", port)) == 0


def run_app():
    if getattr(sys, "frozen", False):
        base_path = sys._MEIPASS
        candidates = [
            "/opt/homebrew/bin/python3.11",
            shutil.which("python3.11"),
            shutil.which("python3"),
        ]
        python_exe = next((p for p in candidates if p and os.path.exists(p)), None)
        if not python_exe:
            print("❌ 未找到可用的 Python 解释器（需要 python3.11）")
            sys.exit(1)
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))
        python_exe = sys.executable

    gui_script = os.path.join(base_path, "yt_dlp_gui.py")
    port = get_free_port()

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

    print(f"🚀 正在启动 Streamlit 服务 (端口: {port})...")
    proc = subprocess.Popen(
        cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True
    )

    def log_reader(pipe):
        try:
            for line in iter(pipe.readline, ""):
                print(f"[Streamlit] {line.strip()}")
        except Exception:
            pass

    threading.Thread(target=log_reader, args=(proc.stdout,), daemon=True).start()

    max_retries = 80
    retry_count = 0
    while not is_port_open(port) and retry_count < max_retries:
        if proc.poll() is not None:
            print(f"❌ Streamlit 子进程提前退出，退出码: {proc.returncode}")
            sys.exit(1)
        time.sleep(0.5)
        retry_count += 1
        if retry_count % 10 == 0:
            print(f"⏳ 正在等待服务响应... ({retry_count}/{max_retries})")

    if retry_count >= max_retries:
        print("❌ 错误: Streamlit 服务启动超时。")
        try:
            import signal

            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
        except Exception:
            pass
        sys.exit(1)

    print("✅ 服务已就绪，正在开启应用窗口...")

    window = webview.create_window(
        "🚀Space Download",
        f"http://127.0.0.1:{port}",
        width=1000,
        height=700,
        background_color="#000000",
        resizable=True,
    )

    def force_reload(window, url):
        time.sleep(2)
        print("🔄 正在执行首屏强制刷新...")
        window.load_url(url)

    threading.Thread(target=force_reload, args=(window, f"http://127.0.0.1:{port}"), daemon=True).start()

    try:
        webview.start(debug=False)
    finally:
        print("👋 正在清理并关闭程序...")
        try:
            import signal

            os.killpg(os.getpgid(proc.pid), signal.SIGTERM)
            time.sleep(0.5)
            if proc.poll() is None:
                os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        except Exception as e:
            print(f"清理进程时出错: {e}")
            proc.kill()


if __name__ == "__main__":
    run_app()
