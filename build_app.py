import PyInstaller.__main__
import os
import shutil
import sys
import subprocess


def build_mac_app():
    print("开始构建 macOS App...")

    # 确保清理旧的构建目录
    for d in ["build", "dist"]:
        if os.path.exists(d):
            try:
                shutil.rmtree(d)
            except Exception as e:
                print(f"警告: 无法完全删除目录 {d}，尝试继续构建... ({e})")

    # 找到 streamlit 的路径，因为需要打包它的静态资源
    import streamlit

    streamlit_path = os.path.dirname(streamlit.__file__)

    # 使用 Python 3.11 的路径
    python_exe = "/opt/homebrew/bin/python3.11"
    if not os.path.exists(python_exe):
        print(f"❌ 未找到 Python 3.11: {python_exe}")
        sys.exit(1)

    # 构建 PyInstaller 命令
    cmd = [
        python_exe,
        "-m",
        "PyInstaller",
        "main.py",
        "--name=SpaceDownload",
        "--windowed",
        "--onedir",
        "--noconfirm",
        "--clean",
        "--add-data=yt_dlp_gui.py:.",
        f"--add-data={streamlit_path}:streamlit",
        "--collect-all=streamlit",
        "--collect-all=webview",
        "--collect-all=yt_dlp",
        "--exclude-module=matplotlib",
        "--exclude-module=notebook",
        "--exclude-module=test",
    ]

    # 执行构建
    try:
        subprocess.run(cmd, check=True)
        print("\n✅ 构建完成！请在 dist 目录下找到 SpaceDownload.app")
    except subprocess.CalledProcessError as e:
        print(f"\n❌ 构建失败: {e}")
        sys.exit(1)


if __name__ == "__main__":
    build_mac_app()
