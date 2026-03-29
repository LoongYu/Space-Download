import os
import sys
import socket
import threading
import time
import webview
import subprocess


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


def find_python():
    """找系统里真正的 Python 解释器"""
    import shutil

    candidates = [
        shutil.which("python"),
        shutil.which("python3"),
        shutil.which("python3.11"),
    ]
    if sys.platform == "win32":
        candidates += [
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Python", "Python311", "python.exe"),
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Python", "Python312", "python.exe"),
            os.path.join(os.environ.get("LOCALAPPDATA", ""), "Programs", "Python", "Python313", "python.exe"),
            os.path.join(os.environ.get("PROGRAMFILES", ""), "Python311", "python.exe"),
            os.path.join(os.environ.get("PROGRAMFILES", ""), "Python312", "python.exe"),
            os.path.join(os.environ.get("PROGRAMFILES", ""), "Python313", "python.exe"),
        ]
    else:
        candidates += [
            "/opt/homebrew/bin/python3.11",
            shutil.which("python3.11"),
        ]

    for c in candidates:
        if c and os.path.exists(c):
            try:
                ver = subprocess.check_output([c, "--version"], text=True, stderr=subprocess.STDOUT).strip()
                if "Python 3." in ver:
                    return c
            except Exception:
                continue
    return None


def ensure_deps(python_exe):
    """确保 streamlit 和 pywebview 已安装，缺失则自动安装"""
    missing = []
    for mod in ("streamlit", "webview"):
        try:
            subprocess.check_output(
                [python_exe, "-c", f"import {mod}"],
                stderr=subprocess.STDOUT,
            )
        except subprocess.CalledProcessError:
            missing.append(mod)

    if not missing:
        return True

    pip_map = {"webview": "pywebview"}
    pip_names = [pip_map.get(m, m) for m in missing]
    print(f"正在安装缺失依赖: {', '.join(pip_names)} ...")

    flags = []
    if sys.platform == "win32":
        flags = ["--user"]

    try:
        subprocess.check_call(
            [python_exe, "-m", "pip", "install"] + flags + pip_names,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return True
    except subprocess.CalledProcessError:
        return False


def show_error(msg):
    """显示错误（Windows 弹窗，其他平台打印）"""
    if sys.platform == "win32":
        try:
            import ctypes

            ctypes.windll.user32.MessageBoxW(0, msg, "Space Download", 0x10)
        except Exception:
            pass
    print(msg)


def run_app():
    if getattr(sys, "frozen", False):
        base_path = sys._MEIPASS
    else:
        base_path = os.path.dirname(os.path.abspath(__file__))
        python_exe = sys.executable

    if getattr(sys, "frozen", False):
        python_exe = find_python()
        if not python_exe:
            show_error(
                "未找到 Python，请安装 Python 3.11+ 并勾选 Add to PATH。\n下载地址: https://www.python.org/downloads/"
            )
            sys.exit(1)

        if not ensure_deps(python_exe):
            show_error(f"依赖安装失败，请手动执行:\n{python_exe} -m pip install streamlit pywebview")
            sys.exit(1)

    gui_script = os.path.join(base_path, "yt_dlp_gui.py")
    port = get_free_port()

    env = os.environ.copy()
    if getattr(sys, "frozen", False):
        # 把 bundled _internal 加到 PYTHONPATH（让子进程找到 yt_dlp）
        # streamlit 不打包在 _internal 里（--exclude-module=streamlit），
        # 子进程会从用户系统 site-packages 找到完整的 streamlit
        env["PYTHONPATH"] = base_path

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

    print(f"正在启动 Streamlit 服务 (端口: {port})...")
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
                print(f"[Streamlit] {line.strip()}")
        except Exception:
            pass

    threading.Thread(target=log_reader, args=(proc.stdout,), daemon=True).start()

    max_retries = 80
    retry_count = 0
    while not is_port_open(port) and retry_count < max_retries:
        if proc.poll() is not None:
            print(f"Streamlit 子进程提前退出，退出码: {proc.returncode}")
            sys.exit(1)
        time.sleep(0.5)
        retry_count += 1

    if retry_count >= max_retries:
        print("错误: Streamlit 服务启动超时。")
        try:
            proc.terminate()
        except Exception:
            pass
        sys.exit(1)

    print("服务已就绪，正在开启应用窗口...")

    window = webview.create_window(
        "Space Download",
        f"http://127.0.0.1:{port}",
        width=1000,
        height=700,
        background_color="#000000",
        resizable=True,
    )

    def force_reload(window, url):
        time.sleep(2)
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
        except Exception:
            try:
                proc.kill()
            except Exception:
                pass


if __name__ == "__main__":
    if sys.platform == "win32":
        log_dir = os.path.join(os.path.dirname(os.path.abspath(sys.argv[0])), "logs")
        os.makedirs(log_dir, exist_ok=True)
        log_file = os.path.join(log_dir, "app.log")
        sys.stdout = open(log_file, "a", encoding="utf-8")
        sys.stderr = sys.stdout
    run_app()
