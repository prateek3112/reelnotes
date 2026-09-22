import os
import shutil
import time
from app.core.logging import logger


def cleanup_stale_temp_dirs(base_dir: str = "/tmp/reelvault", max_age_seconds: int = 7200):
    """
    Purges leftover job directories older than max_age_seconds (default 2 hours)
    to prevent disk exhaustion in case of hard process terminations (SIGKILL/OOM).
    """
    if not os.path.exists(base_dir):
        return

    now = time.time()
    cleaned_count = 0
    for entry in os.scandir(base_dir):
        if entry.is_dir() and entry.name.startswith("job_"):
            try:
                mtime = entry.stat().st_mtime
                if (now - mtime) > max_age_seconds:
                    logger.warning(f"Purging stale temp directory: {entry.path}")
                    shutil.rmtree(entry.path, ignore_errors=True)
                    cleaned_count += 1
            except Exception as e:
                logger.error(f"Error inspecting/cleaning temp dir {entry.path}: {e}")

    if cleaned_count > 0:
        logger.info(f"Cleaned up {cleaned_count} stale temporary directories.")
