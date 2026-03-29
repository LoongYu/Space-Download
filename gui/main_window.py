"""PyQt5 主窗口"""

import os
import sys
from datetime import datetime
from pathlib import Path

from PyQt5.QtCore import Qt, QTimer
from PyQt5.QtWidgets import (
    QApplication,
    QWidget,
    QVBoxLayout,
    QHBoxLayout,
    QGridLayout,
    QLabel,
    QLineEdit,
    QTextEdit,
    QComboBox,
    QCheckBox,
    QPushButton,
    QProgressBar,
    QGroupBox,
    QFileDialog,
    QSizePolicy,
)

from gui.consts import QUALITY_OPTIONS, FORMAT_OPTIONS, NAME_TEMPLATES, DARK_STYLE
from gui.download_thread import DownloadThread
from sites import registry, get_downloader


class MainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Space Download")
        self.setMinimumSize(900, 650)
        self.download_thread = None
        self._logs = []
        self._init_ui()

    def _init_ui(self):
        root = QVBoxLayout(self)
        root.setContentsMargins(16, 12, 16, 12)
        root.setSpacing(10)

        # ---- 左侧设置区 ----
        top = QHBoxLayout()
        settings = QGroupBox("设置")
        sg = QGridLayout(settings)
        sg.setSpacing(8)

        # 站点（自动识别，只读展示）
        sg.addWidget(QLabel("站点:"), 0, 0)
        self.site_label = QLabel("粘贴链接后自动识别")
        sg.addWidget(self.site_label, 0, 1, 1, 3)

        # 视频质量
        sg.addWidget(QLabel("视频质量:"), 1, 0)
        self.quality_combo = QComboBox()
        self.quality_combo.addItems(QUALITY_OPTIONS.keys())
        self.quality_combo.setCurrentIndex(0)
        sg.addWidget(self.quality_combo, 1, 1)

        # 输出格式
        sg.addWidget(QLabel("输出格式:"), 1, 2)
        self.format_combo = QComboBox()
        self.format_combo.addItems(FORMAT_OPTIONS)
        sg.addWidget(self.format_combo, 1, 3)

        # 保存目录
        sg.addWidget(QLabel("保存目录:"), 2, 0)
        dir_layout = QHBoxLayout()
        self.dir_input = QLineEdit(str(Path.home() / "Downloads"))
        self.dir_btn = QPushButton("浏览")
        self.dir_btn.setFixedWidth(60)
        self.dir_btn.clicked.connect(self._browse_dir)
        dir_layout.addWidget(self.dir_input)
        dir_layout.addWidget(self.dir_btn)
        sg.addLayout(dir_layout, 2, 1, 1, 3)

        # 文件命名模板
        sg.addWidget(QLabel("命名模板:"), 3, 0)
        self.name_combo = QComboBox()
        self.name_combo.addItems(NAME_TEMPLATES.keys())
        self.name_combo.setCurrentText("作者/日期 - 标题")
        self.name_combo.currentTextChanged.connect(self._on_template_changed)
        sg.addWidget(self.name_combo, 3, 1)

        self.custom_tmpl = QLineEdit("%(title)s")
        self.custom_tmpl.setVisible(False)
        sg.addWidget(self.custom_tmpl, 3, 2, 1, 2)

        # 选项
        opt_layout = QHBoxLayout()
        self.translate_cb = QCheckBox("标题翻译为中文")
        self.thumbnail_cb = QCheckBox("下载封面")
        self.thumbnail_cb.setChecked(True)
        opt_layout.addWidget(self.translate_cb)
        opt_layout.addWidget(self.thumbnail_cb)
        opt_layout.addStretch()
        sg.addLayout(opt_layout, 4, 0, 1, 4)

        # 代理
        self.proxy_cb = QCheckBox("启用代理")
        self.proxy_cb.toggled.connect(lambda v: self.proxy_input.setEnabled(v))
        sg.addWidget(self.proxy_cb, 5, 0)
        self.proxy_input = QLineEdit("http://127.0.0.1:7890")
        self.proxy_input.setEnabled(False)
        sg.addWidget(self.proxy_input, 5, 1, 1, 3)

        # 登录
        sg.addWidget(QLabel("账号:"), 6, 0)
        self.user_input = QLineEdit()
        sg.addWidget(self.user_input, 6, 1)
        sg.addWidget(QLabel("密码:"), 6, 2)
        self.pass_input = QLineEdit()
        self.pass_input.setEchoMode(QLineEdit.Password)
        sg.addWidget(self.pass_input, 6, 3)

        # Cookie
        self.cookie_cb = QCheckBox("Cookies 文件:")
        self.cookie_cb.toggled.connect(lambda v: self.cookie_btn.setEnabled(v))
        sg.addWidget(self.cookie_cb, 7, 0)
        self.cookie_btn = QPushButton("选择文件")
        self.cookie_btn.setEnabled(False)
        self.cookie_btn.clicked.connect(self._browse_cookie)
        self.cookie_path = ""
        sg.addWidget(self.cookie_btn, 7, 1)

        top.addWidget(settings, 3)

        # ---- 右侧日志 ----
        log_group = QGroupBox("运行日志")
        log_layout = QVBoxLayout(log_group)
        self.log_view = QTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setStyleSheet(
            "background-color: #0a0a0a; color: #d4d4d4; font-family: Menlo, Consolas, monospace; font-size: 12px;"
        )
        log_layout.addWidget(self.log_view)
        top.addWidget(log_group, 5)

        root.addLayout(top)

        # ---- URL 输入 + 按钮 ----
        url_layout = QHBoxLayout()
        self.url_input = QLineEdit()
        self.url_input.setPlaceholderText("在此处粘贴视频、频道或列表链接...")
        self.url_input.textChanged.connect(self._on_url_changed)
        url_layout.addWidget(self.url_input, 1)

        self.start_btn = QPushButton("开始下载")
        self.start_btn.setFixedWidth(100)
        self.start_btn.clicked.connect(self._start_download)
        url_layout.addWidget(self.start_btn)

        self.stop_btn = QPushButton("停止")
        self.stop_btn.setObjectName("stopBtn")
        self.stop_btn.setFixedWidth(80)
        self.stop_btn.setEnabled(False)
        self.stop_btn.clicked.connect(self._stop_download)
        url_layout.addWidget(self.stop_btn)

        root.addLayout(url_layout)

        # ---- 进度条 ----
        self.progress_bar = QProgressBar()
        self.progress_bar.setRange(0, 100)
        self.progress_bar.setValue(0)
        root.addWidget(self.progress_bar)

        self.status_label = QLabel("等待任务开始")
        self.status_label.setObjectName("statusLabel")
        root.addWidget(self.status_label)

    def _browse_dir(self):
        d = QFileDialog.getExistingDirectory(self, "选择保存目录", self.dir_input.text())
        if d:
            self.dir_input.setText(d)

    def _browse_cookie(self):
        f, _ = QFileDialog.getOpenFileName(self, "选择 Cookies 文件", "", "Text (*.txt)")
        if f:
            self.cookie_path = f
            self.cookie_btn.setText(os.path.basename(f))

    def _on_template_changed(self, text):
        self.custom_tmpl.setVisible(text == "自定义")

    def _on_url_changed(self, url):
        site = get_downloader(url.strip()) if url.strip() else None
        if site:
            self.site_label.setText(f"✓ {site.name}")
        else:
            self.site_label.setText("粘贴链接后自动识别")

    def _append_log(self, msg):
        ts = datetime.now().strftime("%H:%M:%S")
        line = f"{ts} - {msg}"
        self._logs.append(line)
        if len(self._logs) > 500:
            self._logs = self._logs[-500:]
        self.log_view.setPlainText("\n".join(self._logs))
        sb = self.log_view.verticalScrollBar()
        sb.setValue(sb.maximum())

    def _start_download(self):
        url = self.url_input.text().strip()
        if not url:
            self._append_log("请输入链接")
            return

        site = get_downloader(url)
        if not site:
            self._append_log("未识别的站点，请检查链接")
            return

        name_key = self.name_combo.currentText()
        tmpl = NAME_TEMPLATES.get(name_key)
        if tmpl is None:
            tmpl = self.custom_tmpl.text().strip() or "%(title)s"

        opts = {
            "quality": QUALITY_OPTIONS[self.quality_combo.currentText()],
            "output_format": self.format_combo.currentText(),
            "save_dir": self.dir_input.text().strip(),
            "filename_tmpl": tmpl,
            "translate_title": self.translate_cb.isChecked(),
            "embed_thumbnail": self.thumbnail_cb.isChecked(),
            "proxy": self.proxy_input.text().strip() if self.proxy_cb.isChecked() else "",
            "username": self.user_input.text().strip(),
            "password": self.pass_input.text(),
            "cookiefile": self.cookie_path if self.cookie_cb.isChecked() else "",
        }

        self.start_btn.setEnabled(False)
        self.stop_btn.setEnabled(True)
        self.progress_bar.setValue(0)
        self.status_label.setText("正在启动...")
        self._append_log(f"站点: {site.name} | 开始下载: {url}")

        self.download_thread = DownloadThread(url, opts, site, parent=self)
        self.download_thread.log_signal.connect(self._append_log)
        self.download_thread.progress_signal.connect(lambda p: self.progress_bar.setValue(int(p * 100)))
        self.download_thread.status_signal.connect(self.status_label.setText)
        self.download_thread.task_count_signal.connect(self._on_task_count)
        self.download_thread.done_signal.connect(self._on_done)
        self.download_thread.start()

    def _stop_download(self):
        if self.download_thread:
            self.download_thread.stop()
            self._append_log("正在停止...")

    def _on_task_count(self, current, total):
        self.status_label.setText(f"进度: {current} / {total}")

    def _on_done(self, result):
        self.start_btn.setEnabled(True)
        self.stop_btn.setEnabled(False)
        if result == "success":
            self.progress_bar.setValue(100)
            self.status_label.setText("任务已完成")
            self._append_log("任务执行完毕")
        elif result == "stopped":
            self.status_label.setText("已停止")
            self._append_log("用户已停止")
        else:
            self.status_label.setText(f"出错: {result[6:]}")
            self._append_log(f"下载失败: {result[6:]}")
