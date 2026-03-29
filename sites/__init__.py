"""站点注册表：自动发现 sites/ 下所有 BaseDownloader 子类"""

import importlib
import pkgutil
from pathlib import Path

from sites.base import BaseDownloader

# 所有已注册的下载器
registry: list[BaseDownloader] = []


def _discover():
    """自动导入 sites/ 包下的所有模块，注册 BaseDownloader 子类"""
    sites_dir = Path(__file__).parent
    for finder, name, _ in pkgutil.iter_modules([str(sites_dir)]):
        if name in ("base", "__init__"):
            continue
        try:
            mod = importlib.import_module(f"sites.{name}")
            for attr_name in dir(mod):
                obj = getattr(mod, attr_name)
                if isinstance(obj, type) and issubclass(obj, BaseDownloader) and obj is not BaseDownloader:
                    registry.append(obj())
        except Exception:
            pass


def get_downloader(url: str) -> BaseDownloader | None:
    """根据 URL 返回匹配的下载器，无匹配返回 None"""
    for dl in registry:
        try:
            if dl.match_url(url):
                return dl
        except Exception:
            continue
    return None


# 导入时自动发现
_discover()
