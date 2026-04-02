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


STREAMLIT_READY_MARKERS = (
    "You can now view your Streamlit app in your browser.",
    "Network URL:",
    "Local URL:",
)
STREAMLIT_FAILURE_MARKERS = (
    "port ",
    "is already in use",
)


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
        s.bind(("127.0.0.1", 0))
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



def get_launch_executable():
    return sys.executable



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



def build_streamlit_command(gui_script, port):
    if getattr(sys, "frozen", False):
        return [
            get_launch_executable(),
            "--streamlit-child",
            gui_script,
            str(port),
        ]
    return [
        get_launch_executable(),
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



def build_streamlit_env(base_path):
    env = os.environ.copy()
    if getattr(sys, "frozen", False):
        existing_pythonpath = env.get("PYTHONPATH")
        env["PYTHONPATH"] = base_path if not existing_pythonpath else os.pathsep.join((base_path, existing_pythonpath))
        env["STREAMLIT_SERVER_STATIC_FILE_PATH"] = os.path.join(base_path, "streamlit", "static")
    return env



def wait_for_streamlit_ready(proc, port, startup_state, timeout_seconds=40):
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        if proc.poll() is not None:
            raise RuntimeError(f"Streamlit 子进程提前退出，退出码: {proc.returncode}")
        if startup_state["port_in_use"]:
            raise OSError("PORT_IN_USE")
        if startup_state["fatal_error"]:
            raise RuntimeError(startup_state["fatal_error"])
        if startup_state["ready"] and is_port_open(port):
            return
        if is_port_open(port):
            startup_state["ready"] = True
            return
        time.sleep(0.2)
    raise TimeoutError("Streamlit 服务启动超时")



def launch_streamlit(base_path, gui_script):
    env = build_streamlit_env(base_path)
    last_error = None
    for attempt in range(1, 6):
        port = get_free_port()
        cmd = build_streamlit_command(gui_script, port)
        log_message(f"Starting Streamlit process (attempt {attempt}) on port {port}: {' '.join(cmd)}")
        proc = subprocess.Popen(
            cmd,
            env=env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            start_new_session=True,
        )
        startup_state = {"ready": False, "port_in_use": False, "fatal_error": None}

        def log_reader(pipe, state):
            try:
                for line in iter(pipe.readline, ""):
                    message = line.rstrip()
                    lowered = message.lower()
                    log_message(f"[Streamlit] {message}")
                    if any(marker in message for marker in STREAMLIT_READY_MARKERS):
                        state["ready"] = True
                    if all(marker in lowered for marker in STREAMLIT_FAILURE_MARKERS):
                        state["port_in_use"] = True
                    if "traceback" in lowered:
                        state["fatal_error"] = message
            except Exception:
                log_message("Streamlit log reader crashed:\n" + traceback.format_exc())

        threading.Thread(target=log_reader, args=(proc.stdout, startup_state), daemon=True).start()

        try:
            wait_for_streamlit_ready(proc, port, startup_state)
            return proc, port
        except OSError as error:
            last_error = error
            log_message(f"Port {port} unavailable, retrying startup")
            terminate_process_group(proc)
        except Exception as error:
            terminate_process_group(proc)
            raise error

    raise RuntimeError(f"无法启动 Streamlit 服务: {last_error or '未知错误'}")



def run_streamlit_child():
    if len(sys.argv) < 4:
        raise SystemExit("Missing streamlit child arguments")
    _, _, gui_script, port = sys.argv[:4]
    from streamlit.web import cli as stcli

    sys.argv = [
        "streamlit",
        "run",
        gui_script,
        "--global.developmentMode",
        "false",
        "--global.showWarningOnDirectExecution",
        "false",
        "--server.port",
        port,
        "--server.headless",
        "true",
        "--browser.gatherUsageStats",
        "false",
        "--server.runOnSave",
        "false",
        "--server.address",
        "127.0.0.1",
    ]
    raise SystemExit(stcli.main())



def run_app():
    base_path = get_base_path()
    gui_script = os.path.join(base_path, "yt_dlp_gui.py")

    log_message(f"Launching app. base_path={base_path} gui_script={gui_script}")
    log_message(f"Using launcher executable: {get_launch_executable()}")

    proc, port = launch_streamlit(base_path, gui_script)

    log_message("Streamlit 服务已就绪，开始创建窗口")
    window = webview.create_window(
        "Space Download",
        f"http://127.0.0.1:{port}",
        width=1200,
        height=800,
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
    if "--streamlit-child" in sys.argv:
        run_streamlit_child()

    if getattr(sys, "frozen", False):
        log_file = get_log_file()
        sys.stdout = open(log_file, "a", encoding="utf-8", errors="replace")
        sys.stderr = sys.stdout

    run_app()
