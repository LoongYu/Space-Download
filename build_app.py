import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent
DIST_DIR = PROJECT_ROOT / "dist"
SPEC_PATH = PROJECT_ROOT / "SpaceDownload.spec"
APP_PATH = DIST_DIR / "SpaceDownload.app"
DMG_PATH = DIST_DIR / "SpaceDownload.dmg"



def clean_build_artifacts():
    for directory in (PROJECT_ROOT / "build", DIST_DIR):
        if directory.exists():
            shutil.rmtree(directory)



def run_pyinstaller():
    subprocess.run(
        [sys.executable, "-m", "PyInstaller", "--noconfirm", "--clean", str(SPEC_PATH)],
        check=True,
        cwd=PROJECT_ROOT,
    )



def build_mac_app():
    print("开始构建 macOS App...")
    clean_build_artifacts()
    run_pyinstaller()
    print(f"\n✅ 构建完成：{APP_PATH}")
    return APP_PATH



def build_dmg():
    print("开始构建 macOS DMG 安装包...")
    build_mac_app()

    if not APP_PATH.exists():
        print(f"❌ 未找到 {APP_PATH}")
        sys.exit(1)

    if DMG_PATH.exists():
        DMG_PATH.unlink()

    print("正在创建 DMG 文件...")
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
                str(DMG_PATH),
                str(APP_PATH),
            ],
            check=True,
            cwd=PROJECT_ROOT,
        )
    except FileNotFoundError:
        print("create-dmg 未安装，使用 hdiutil...")
        staging_dir = DIST_DIR / "dmg-staging"
        if staging_dir.exists():
            shutil.rmtree(staging_dir)
        staging_dir.mkdir(parents=True)
        shutil.copytree(APP_PATH, staging_dir / APP_PATH.name)
        applications_link = staging_dir / "Applications"
        if not applications_link.exists():
            applications_link.symlink_to("/Applications")
        try:
            subprocess.run(
                [
                    "hdiutil",
                    "create",
                    "-volname",
                    "Space Download",
                    "-srcfolder",
                    str(staging_dir),
                    "-ov",
                    "-format",
                    "UDZO",
                    str(DMG_PATH),
                ],
                check=True,
                cwd=PROJECT_ROOT,
            )
        finally:
            shutil.rmtree(staging_dir, ignore_errors=True)
    print(f"\n✅ DMG 构建完成: {DMG_PATH}")
    return DMG_PATH


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "dmg":
        build_dmg()
    else:
        build_mac_app()
