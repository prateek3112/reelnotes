import os
import signal
import socket
import sys
import time
from app.config import settings
from app.core.cleanup import cleanup_stale_temp_dirs
from app.core.logging import logger
from app.models.enums import ProcessingStatus
from app.services.supabase_service import SupabaseService
from app.workers.pipeline import process_reel_job


class WorkerPoller:
    """
    Long-running background worker daemon that continuously polls
    Supabase's processing_jobs table using atomic claim_next_job RPC.
    """

    def __init__(self, poll_interval: float = 3.0):
        self.poll_interval = poll_interval or settings.WORKER_POLL_INTERVAL
        self.running = True
        self.worker_id = f"worker-{socket.gethostname()}-{os.getpid()}"
        self.supabase = SupabaseService()

        # Handle process termination signals gracefully
        signal.signal(signal.SIGINT, self._handle_exit)
        signal.signal(signal.SIGTERM, self._handle_exit)

    def _handle_exit(self, signum, frame):
        logger.info(f"Signal ({signum}) received. Shutting down worker gracefully...")
        self.running = False

    def run(self):
        logger.info(f"Worker {self.worker_id} started. Polling every {self.poll_interval}s...")
        cleanup_stale_temp_dirs(settings.TEMP_MEDIA_DIR)

        while self.running:
            try:
                # Atomically claim the next queued job
                job = self.supabase.claim_job(self.worker_id)
                if job:
                    job_id = job["id"]
                    reel_id = job["reel_id"]
                    logger.info(f"Worker {self.worker_id} claimed Job {job_id} for Reel {reel_id}.")

                    try:
                        process_reel_job(job, self.supabase)
                    except Exception as e:
                        logger.exception(f"Job {job_id} failed with error: {str(e)}")
                        # Update database with failure state
                        friendly_error = (
                            "Media unavailable or requires authentication."
                            if "DownloadError" in type(e).__name__
                            else str(e)
                        )
                        self.supabase.update_reel_status(
                            reel_id,
                            ProcessingStatus.FAILED,
                            error_message=friendly_error
                        )
                        self.supabase.fail_job(job_id, str(e))
                else:
                    # No pending jobs; idle sleep
                    time.sleep(self.poll_interval)
            except Exception as e:
                logger.error(f"Error in worker polling loop: {str(e)}")
                time.sleep(self.poll_interval)

        logger.info(f"Worker {self.worker_id} stopped cleanly.")


if __name__ == "__main__":
    poller = WorkerPoller()
    poller.run()
