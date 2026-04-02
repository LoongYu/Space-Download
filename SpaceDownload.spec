# -*- mode: python ; coding: utf-8 -*-
import sys
from pathlib import Path

import streamlit
from PyInstaller.utils.hooks import collect_all

PROJECT_ROOT = Path.cwd()
STREAMLIT_PATH = Path(streamlit.__file__).resolve().parent

datas = [
    (str(PROJECT_ROOT / 'yt_dlp_gui.py'), '.'),
    (str(STREAMLIT_PATH), 'streamlit'),
]
binaries = []
hiddenimports = []
for package_name in ('streamlit', 'webview', 'yt_dlp', 'deep_translator'):
    package_datas, package_binaries, package_hiddenimports = collect_all(package_name)
    datas += package_datas
    binaries += package_binaries
    hiddenimports += package_hiddenimports


a = Analysis(
    ['main.py'],
    pathex=[str(PROJECT_ROOT)],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['matplotlib', 'notebook', 'test'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='SpaceDownload',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='SpaceDownload',
)

if sys.platform == 'darwin':
    app = BUNDLE(
        coll,
        name='SpaceDownload.app',
        icon=None,
        bundle_identifier='com.loongyu.spacedownload',
    )
