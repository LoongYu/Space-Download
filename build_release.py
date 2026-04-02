#!/usr/bin/env python3
"""
Space Download 构建脚本
- 本地构建 macOS dmg
- 创建 GitHub Release
- 上传 dmg 到 Release
"""

import subprocess
import sys
from datetime import datetime
from pathlib import Path

from build_app import build_dmg

PROJECT_ROOT = Path(__file__).resolve().parent



def get_next_release_name():
    today = datetime.now().strftime("%Y%m%d")
    try:
        result = subprocess.run(
            ["gh", "release", "list", "--repo", "LoongYu/Space-Download", "--limit", "50"],
            capture_output=True,
            text=True,
            check=True,
            cwd=PROJECT_ROOT,
        )
        releases = result.stdout.strip().split("\n") if result.stdout.strip() else []
        count = sum(1 for line in releases if line.startswith(today))
        return f"{today}{count + 1:02d}"
    except Exception:
        return f"{today}01"



def create_release(release_name, dmg_path):
    print(f"创建 Release: {release_name}")
    subprocess.run(
        [
            "gh",
            "release",
            "create",
            release_name,
            str(dmg_path),
            "--title",
            f"SpaceDownload {release_name}",
            "--repo",
            "LoongYu/Space-Download",
            "--generate-notes",
        ],
        check=True,
        cwd=PROJECT_ROOT,
    )
    print(f"✅ Release 创建成功: https://github.com/LoongYu/Space-Download/releases/tag/{release_name}")



def trigger_windows_build(release_name):
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
        cwd=PROJECT_ROOT,
    )
    print("✅ Windows 构建已触发")



def main():
    if len(sys.argv) > 1:
        release_name = sys.argv[1]
    else:
        release_name = get_next_release_name()

    print(f"Release: {release_name}")
    dmg_path = build_dmg()
    release_dmg_path = dmg_path.with_name(f"SpaceDownload-{release_name}.dmg")
    if release_dmg_path.exists():
        release_dmg_path.unlink()
    dmg_path.rename(release_dmg_path)

    create_release(release_name, release_dmg_path)
    trigger_windows_build(release_name)

    print("\n✅ 完成！")
    print("macOS: 已上传")
    print("Windows: 构建中，完成后需手动上传到 Release")


if __name__ == "__main__":
    main()
