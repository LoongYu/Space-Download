#!/usr/bin/env python3
"""
Space Download 构建脚本
- 本地构建 macOS dmg
- 创建 GitHub Release
- 上传 dmg 到 Release
"""

import os
import sys
import subprocess
import json
import re
from datetime import datetime


def get_next_release_name():
    """获取下一个 release 名称：yyyymmdd + 序号"""
    today = datetime.now().strftime("%Y%m%d")

    # 获取已有 releases
    try:
        result = subprocess.run(
            ["gh", "release", "list", "--repo", "LoongYu/Space-Download", "--limit", "50"],
            capture_output=True,
            text=True,
            check=True,
        )
        releases = result.stdout.strip().split("\n")

        # 统计今天已有多少个 release
        count = 0
        for line in releases:
            if line.startswith(today):
                count += 1

        return f"{today}{count + 1:02d}"
    except Exception:
        return f"{today}01"


def build_dmg(release_name):
    """构建 macOS dmg"""
    print(f"开始构建 macOS DMG: SpaceDownload-{release_name}.dmg")

    # 清理旧构建
    for d in ["build", "dist"]:
        if os.path.exists(d):
            import shutil

            shutil.rmtree(d)

    # 使用 Python 3.11 构建
    python_exe = "/opt/homebrew/bin/python3.11"
    if not os.path.exists(python_exe):
        print(f"❌ 未找到 Python 3.11: {python_exe}")
        sys.exit(1)

    import streamlit

    streamlit_path = os.path.dirname(streamlit.__file__)

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

    subprocess.run(cmd, check=True)

    # 创建 DMG
    dmg_name = f"SpaceDownload-{release_name}.dmg"
    dmg_path = f"dist/{dmg_name}"

    try:
        subprocess.run(
            [
                "create-dmg",
                "--volname",
                "Space Download",
                "--window-pos",
                "200",
                "120",
                "--window-size",
                "800",
                "400",
                "--icon-size",
                "100",
                "--icon",
                "SpaceDownload.app",
                "200",
                "190",
                "--hide-extension",
                "SpaceDownload.app",
                "--app-drop-link",
                "600",
                "185",
                dmg_path,
                "dist/SpaceDownload.app",
            ],
            check=True,
        )
    except FileNotFoundError:
        subprocess.run(
            [
                "hdiutil",
                "create",
                "-volname",
                "Space Download",
                "-srcfolder",
                "dist/SpaceDownload.app",
                "-ov",
                "-format",
                "UDZO",
                dmg_path,
            ],
            check=True,
        )

    print(f"✅ DMG 构建完成: {dmg_path}")
    return dmg_path


def create_release(release_name, dmg_path):
    """创建 GitHub Release 并上传 dmg"""
    print(f"创建 Release: {release_name}")

    subprocess.run(
        [
            "gh",
            "release",
            "create",
            release_name,
            dmg_path,
            "--title",
            f"SpaceDownload {release_name}",
            "--repo",
            "LoongYu/Space-Download",
            "--generate-notes",
        ],
        check=True,
    )

    print(f"✅ Release 创建成功: https://github.com/LoongYu/Space-Download/releases/tag/{release_name}")


def trigger_windows_build(release_name):
    """触发 Windows 构建"""
    print(f"触发 Windows 构建: {release_name}")

    subprocess.run(
        [
            "gh",
            "workflow",
            "run",
            "build-windows.yml",
            "--repo",
            "LoongYu/Space-Download",
            "--field",
            f"release_name={release_name}",
        ],
        check=True,
    )

    print("✅ Windows 构建已触发")


def main():
    if len(sys.argv) > 1:
        release_name = sys.argv[1]
    else:
        release_name = get_next_release_name()

    print(f"Release: {release_name}")

    # 构建 DMG
    dmg_path = build_dmg(release_name)

    # 创建 Release
    create_release(release_name, dmg_path)

    # 触发 Windows 构建
    trigger_windows_build(release_name)

    print("\n✅ 完成！")
    print(f"macOS: 已上传")
    print(f"Windows: 构建中，完成后需手动上传到 Release")


if __name__ == "__main__":
    main()
