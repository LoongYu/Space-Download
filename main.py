#!/usr/bin/env python3
import os
import sys
from pathlib import Path

from PyQt5.QtCore import QCoreApplication, Qt
from PyQt5.QtGui import QIcon
from PyQt5.QtWidgets import QApplication

from gui.consts import DARK_STYLE
from gui.main_window import MainWindow


def main():
    app = QApplication(sys.argv)
    app.setStyleSheet(DARK_STYLE)

    # 尝试设置图标
    icon_candidates = [
        Path(__file__).parent / "resources" / "icon.png",
        Path(sys._MEIPASS) / "resources" / "icon.png" if getattr(sys, "frozen", False) else None,
    ]
    for p in icon_candidates:
        if p and p.exists():
            app.setWindowIcon(QIcon(str(p)))
            break

    window = MainWindow()
    window.show()

    sys.exit(app.exec_())


if __name__ == "__main__":
    if getattr(sys, "frozen", False):
        meipass = getattr(sys, "_MEIPASS", None)
        if meipass and meipass not in sys.path:
            sys.path.insert(0, meipass)
    main()
