import os
import re
from typing import Any, Dict, Optional, TypedDict
import yt_dlp
from app.core.exceptions import DownloadError
from app.core.logging import logger


class MediaResult(TypedDict):
    video_path: str
    shortcode: str
    title: Optional[str]
    description: Optional[str]
    uploader: Optional[str]
    creator_name: Optional[str]
    duration: Optional[int]
    thumbnail: Optional[str]


class MediaDownloader:
    """
    Acquires Instagram Reel media and metadata using yt-dlp.
    Encapsulated behind a clean interface to ensure future provider swappability.
    """

    def __init__(self, cookies_path: Optional[str] = None):
        self.cookies_path = cookies_path or os.getenv("INSTAGRAM_COOKIES_PATH")

    @staticmethod
    def extract_shortcode(url: str) -> Optional[str]:
        pattern = r"instagram\.com/(?:reel|reels|p)/([A-Za-z0-9_-]+)"
        match = re.search(pattern, url, re.IGNORECASE)
        return match.group(1) if match else None

    @staticmethod
    def sanitize_url(url: str) -> str:
        """Strip tracking parameters such as igsh, utm_*, etc."""
        clean = re.sub(r"\?.*$", "", url.strip())
        if not clean.endswith("/"):
            clean += "/"
        return clean

    def download(self, url: str, output_dir: str) -> MediaResult:
        os.makedirs(output_dir, exist_ok=True)
        sanitized = self.sanitize_url(url)
        extracted_shortcode = self.extract_shortcode(sanitized) or "reel"
        output_template = os.path.join(output_dir, f"{extracted_shortcode}.%(ext)s")

        ydl_opts: Dict[str, Any] = {
            "format": "bestvideo+bestaudio/best",
            "merge_output_format": "mp4",
            "outtmpl": output_template,
            "quiet": True,
            "no_warnings": True,
            "noplaylist": True,
            "socket_timeout": 30,
            "retries": 3,
            "http_headers": {
                "User-Agent": (
                    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                    "AppleWebKit/537.36 (KHTML, like Gecko) "
                    "Chrome/128.0.0.0 Safari/537.36"
                ),
                "Accept-Language": "en-US,en;q=0.9",
            },
        }

        if self.cookies_path and os.path.exists(self.cookies_path):
            logger.info(f"Using cookies file: {self.cookies_path}")
            ydl_opts["cookiefile"] = self.cookies_path
        else:
            logger.debug("No cookies file provided; proceeding with unauthenticated request.")

        try:
            logger.info(f"Downloading media for Reel: {sanitized}")
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(sanitized, download=True)
                downloaded_file = ydl.prepare_filename(info)

                # Ensure merged MP4 file is located correctly
                if not os.path.exists(downloaded_file):
                    base, _ = os.path.splitext(downloaded_file)
                    downloaded_file = f"{base}.mp4"

                if not os.path.exists(downloaded_file):
                    # Check if any file matching shortcode was created in output_dir
                    for f in os.listdir(output_dir):
                        if f.startswith(extracted_shortcode):
                            downloaded_file = os.path.join(output_dir, f)
                            break

                shortcode = info.get("id") or extracted_shortcode
                title = info.get("title") or (info.get("description", "")[:80] if info.get("description") else None)
                uploader = info.get("uploader") or info.get("channel")

                return {
                    "video_path": downloaded_file,
                    "shortcode": shortcode,
                    "title": title,
                    "description": info.get("description"),
                    "uploader": uploader,
                    "creator_name": info.get("uploader_id") or uploader,
                    "duration": int(info.get("duration", 0)) if info.get("duration") else None,
                    "thumbnail": info.get("thumbnail"),
                }
        except Exception as e:
            logger.error(f"Media download failed for {url}: {str(e)}")
            raise DownloadError(f"Failed to download Instagram Reel media: {str(e)}") from e
