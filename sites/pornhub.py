import os

from sites.base import BaseDownloader


class PornhubDownloader(BaseDownloader):
    name = "PornHub"

    COLLECTION_MARKERS = (
        "/playlist/",
        "/model/",
        "/models/",
        "/channels/",
        "/channel/",
        "/users/",
        "/user/",
        "/pornstar/",
        "/pornstars/",
    )

    def match_url(self, url: str) -> bool:
        return "pornhub.com" in url

    def is_collection_url(self, url: str) -> bool:
        u = url.lower()
        return any(m in u for m in self.COLLECTION_MARKERS)

    def get_cookie_file(self, temp_dir: str) -> str:
        path = os.path.join(temp_dir, "ph_cookies.txt")
        with open(path, "w", encoding="utf-8") as f:
            f.write("# Netscape HTTP Cookie File\n")
            f.write(".pornhub.com\tTRUE\t/\tFALSE\t0\tage_verified\t1\n")
            f.write(".pornhub.com\tTRUE\t/\tFALSE\t0\taccessAgeDisclaimerPH\t1\n")
            f.write(".pornhub.com\tTRUE\t/\tFALSE\t0\taccessPH\t1\n")
            f.write(".pornhub.com\tTRUE\t/\tFALSE\t0\taccessAgeDisclaimerUK\t1\n")
        return path

    def get_http_headers(self) -> dict:
        return {
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/120.0.0.0 Safari/537.36"
            ),
            "Accept": (
                "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8"
            ),
            "Accept-Language": "en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7",
            "Referer": "https://www.pornhub.com/",
        }
