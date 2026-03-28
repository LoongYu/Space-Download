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
        if sys.platform == "win32":
            # Windows: sys.exeutable 是 frozen exe，需要找系统里真正的 Python
            candidates = [
                shutil.which("python"),
                shutil.which("python3"),
                shutil.which("python3.11"),
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Python", "Python311", "python.exe"),
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Python", "Python312", "python.exe"),
                os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Python", "Python313", "python.exe"),
                os.path.join(os.environ.get("PROGRAMFILES", ""), "Python311", "python.exe"),
                os.path.join(os.environ.get("PROGRAMFILES", ""), "Python312", "python.exe"),
                os.path.join(os.environ.get("PROGRAMFILES", ""), "Python313", "python.exe"),
            ]
            python_exe = None
            for c in candidates:
                if c and os.path.exists(c):
                    try:
                        ver = subprocess.check_output([c, "--version"], text=True, stderr=subprocess.STDOUT).strip()
                        if "Python 3." in ver:
                            python_exe = c
                            break
                    except Exception:
                        continue
            if not python_exe:
                try:
                    import ctypes

                    ctypes.windll.user32.MessageBoxW(
                        0,
                        "请先安装 Python 3.11+，安装时勾选 Add to PATH。\n下载地址: https://www.python.org/downloads/",
                        "Space Download - 缺少 Python",
                        0x10,
                    )
                except Exception:
                    pass
                print("未找到 Python，请安装 Python 3.11+ 并添加到 PATH")
                sys.exit(1)
        else:
            candidates = [
                "/opt/homebrew/bin/python3.11",
                shutil.which("python3.11"),
                shutil.which("python3"),
            ]
            python_exe = next((p for p in candidates if p and os.path.exists(p)), None)
            if not python_exe:
                print("未找到可用的 Python 解释器（需要 python3.11）")
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
        print("错误: Streamlit 服务启动超时。")
        try:
            proc.terminate()
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
        print("正在清理并关闭程序...")
        try:
            proc.terminate()
            time.sleep(0.5)
            if proc.poll() is None:
                proc.kill()
        except Exception as e:
            print(f"清理进程时出错: {e}")
            proc.kill()


if __name__ == "__main__":
    # Windows --windowed 模式没有控制台，错误写入日志文件方便排查
    if sys.platform == "win32":
        log_dir = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "logs")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, "app.log")
        sys.stdout = open(log_file, "a", encoding="utf-8")
        sys.stderr = sys.stdout
    run_app()
