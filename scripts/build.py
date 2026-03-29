import argparse
import os
import platform
import shutil
import subprocess
import sys
import time
from pathlib import Path


def run(cmd, check=True):
    print(f"  → {' '.join(cmd)}")
    return subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, check=check)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", "-v", default="")
    parser.add_argument("--app-name", "-n", default="SpaceDownload")
    parser.add_argument("--create-dmg", action="store_true")
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    is_mac = platform.system() == "Darwin"
    is_win = platform.system() == "Windows"
    app_name = args.app_name
    version = args.version or time.strftime("%Y%m%d%H")

    print(f"构建 {app_name} {version} ({platform.platform()})")

    # 清理
    for d in ("build", "dist"):
        if Path(d).exists():
            shutil.rmtree(d)
    for f in Path(".").glob("*.spec"):
        f.unlink()

    # 生成 spec
    cmd = [
        "pyi-makespec",
        "--name",
        f"{app_name}-{version}",
        "--noupx",
        "-w",
        "main.py",
        "-p",
        ".",
        "--add-data",
        f"gui{os.pathsep}gui",
        "--add-data",
        f"sites{os.pathsep}sites",
        "--add-data",
        f"yt_dlp{os.pathsep}yt_dlp",
        "--collect-all",
        "yt_dlp",
        "--collect-all",
        "PyQt5",
        "--hidden-import",
        "yt_dlp",
        "--hidden-import",
        "sites.pornhub",
    ]
    if is_mac:
        cmd += ["--onefile"]
    else:
        cmd += ["--onefile"]

    run(cmd)

    # 构建
    spec_file = f"{app_name}-{version}.spec"
    run(["pyinstaller", spec_file, "-y"])

    # 验证
    if is_win:
        exe = Path(f"dist/{app_name}-{version}.exe")
        if exe.exists():
            print(f"✅ 构建成功: {exe} ({exe.stat().st_size / 1024 / 1024:.1f} MB)")
        else:
            print("❌ 构建失败: exe 不存在")
            sys.exit(1)
    elif is_mac:
        app = Path(f"dist/{app_name}-{version}.app")
        if app.exists():
            print(f"✅ 构建成功: {app}")
        else:
            print("❌ 构建失败: .app 不存在")
            sys.exit(1)

        if args.create_dmg:
            _create_dmg(app_name, version)

    # 清理
    if not args.debug:
        for d in ("build",):
            if Path(d).exists():
                shutil.rmtree(d)
        for f in Path(".").glob("*.spec"):
            f.unlink()

    print(f"完成，耗时 {int(time.time() - start_time)}秒")


def _create_dmg(app_name, version):
    dmg = Path(f"dist/{app_name}-{version}.dmg")
    stage = Path("dist/.dmg-stage")
    if stage.exists():
        shutil.rmtree(stage)
    stage.mkdir()

    shutil.copytree(f"dist/{app_name}-{version}.app", stage / f"{app_name}-{version}.app", symlinks=True)
    os.symlink("/Applications", stage / "Applications")

    if dmg.exists():
        dmg.unlink()

    run(
        [
            "hdiutil",
            "create",
            "-volname",
            app_name,
            "-srcfolder",
            str(stage),
            "-ov",
            "-format",
            "UDZO",
            str(dmg),
        ]
    )
    shutil.rmtree(stage)
    print(f"✅ DMG: {dmg} ({dmg.stat().st_size / 1024 / 1024:.1f} MB)")


start_time = time.time()

if __name__ == "__main__":
    main()
