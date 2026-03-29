"""GUI 常量：质量选项、格式、命名模板等"""

QUALITY_OPTIONS = {
    "最佳": "best",
    "4K (2160p)": "bestvideo[height<=2160]+bestaudio/best[height<=2160]",
    "2K (1440p)": "bestvideo[height<=1440]+bestaudio/best[height<=1440]",
    "1080p": "bestvideo[height<=1080]+bestaudio/best[height<=1080]",
    "720p": "bestvideo[height<=720]+bestaudio/best[height<=720]",
    "480p": "bestvideo[height<=480]+bestaudio/best[height<=480]",
}

FORMAT_OPTIONS = ["mp4", "mkv", "webm", "flv"]

NAME_TEMPLATES = {
    "仅标题": "%(title)s",
    "作者-标题": "%(uploader)s - %(title)s",
    "日期-标题": "%(upload_date)s - %(title)s",
    "作者/日期 - 标题": "%(uploader)s/%(upload_date)s - %(title)s",
    "作者/标题": "%(uploader)s/%(title)s",
    "自定义": None,
}

DARK_STYLE = """
QMainWindow, QWidget {
    background-color: #1e1e1e;
    color: #d4d4d4;
    font-family: "Microsoft YaHei", "PingFang SC", "Noto Sans CJK SC", sans-serif;
    font-size: 13px;
}
QLineEdit, QTextEdit, QComboBox, QSpinBox {
    background-color: #2d2d2d;
    border: 1px solid #3e3e3e;
    border-radius: 4px;
    padding: 5px 8px;
    color: #d4d4d4;
}
QLineEdit:focus, QTextEdit:focus, QComboBox:focus {
    border-color: #007acc;
}
QPushButton {
    background-color: #0e639c;
    color: white;
    border: none;
    border-radius: 4px;
    padding: 6px 16px;
    font-weight: bold;
}
QPushButton:hover {
    background-color: #1177bb;
}
QPushButton:pressed {
    background-color: #094771;
}
QPushButton#stopBtn {
    background-color: #c42b1c;
}
QPushButton#stopBtn:hover {
    background-color: #e33920;
}
QCheckBox {
    spacing: 6px;
}
QProgressBar {
    border: 1px solid #3e3e3e;
    border-radius: 4px;
    text-align: center;
    background-color: #2d2d2d;
    height: 18px;
}
QProgressBar::chunk {
    background-color: #0e639c;
    border-radius: 3px;
}
QLabel#statusLabel {
    color: #4ec9b0;
    font-size: 12px;
}
QGroupBox {
    border: 1px solid #3e3e3e;
    border-radius: 6px;
    margin-top: 12px;
    padding-top: 16px;
    font-weight: bold;
}
QGroupBox::title {
    subcontrol-origin: margin;
    left: 12px;
    padding: 0 6px;
}
"""
