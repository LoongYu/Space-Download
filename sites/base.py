from abc import ABC, abstractmethod
from dataclasses import dataclass, field


@dataclass
class DownloadOptions:
    """站点下载器返回给 GUI 的统一配置"""

    quality: str = "best"
    output_format: str = "mp4"
    save_dir: str = ""
    filename_tmpl: str = "%(title)s"
    translate_title: bool = False
    embed_thumbnail: bool = False
    proxy: str = ""
    username: str = ""
    password: str = ""
    cookiefile: str = ""


class BaseDownloader(ABC):
    """站点下载器基类。每个站点继承此类，实现 3 个方法即可。"""

    # 站点显示名称（GUI 下拉菜单显示）
    name: str = "Unknown"

    @abstractmethod
    def match_url(self, url: str) -> bool:
        """判断 URL 是否属于本站点"""
        ...

    @abstractmethod
    def get_cookie_file(self, temp_dir: str) -> str:
        """返回 cookie 文件路径。返回空字符串表示不需要 cookie"""
        ...

    @abstractmethod
    def get_http_headers(self) -> dict:
        """返回 HTTP 请求头"""
        ...

    def is_collection_url(self, url: str) -> bool:
        """判断是否为合集/列表链接（可被子类覆盖）"""
        return False
