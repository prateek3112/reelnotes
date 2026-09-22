import os
from datetime import datetime
from typing import Any, Dict, List, Optional
from supabase import Client, create_client
from app.config import settings
from app.core.exceptions import DuplicateReelError, ReelVaultError
from app.core.logging import logger
from app.models.enums import JobStatus, ProcessingStatus


class SupabaseService:
    """
    Encapsulates all Supabase PostgREST, RPC, and Storage interactions.
    Utilizes the SERVICE_ROLE_KEY for administrative and worker operations.
    """

    def __init__(self, url: Optional[str] = None, key: Optional[str] = None):
        self.url = url or settings.SUPABASE_URL
        self.key = key or settings.SUPABASE_SERVICE_ROLE_KEY
        self._client: Optional[Client] = None

    @property
    def client(self) -> Client:
        if self._client is None:
            if not self.url or self.url == "https://placeholder.supabase.co":
                logger.warning("SUPABASE_URL is not set or has placeholder value.")
            self._client = create_client(self.url, self.key)
        return self._client

    # --- REELS CRUD ---

    def create_reel(
        self,
        original_url: str,
        shortcode: Optional[str] = None,
        user_id: Optional[str] = None,
        source_platform: str = "instagram"
    ) -> Dict[str, Any]:
        """Creates a new reel entry with duplicate validation."""
        if shortcode:
            existing = self.check_duplicate(shortcode, user_id)
            if existing:
                raise DuplicateReelError(f"Reel {shortcode} already exists in library (id: {existing['id']})")

        payload = {
            "original_url": original_url,
            "shortcode": shortcode,
            "source_platform": source_platform,
            "status": ProcessingStatus.PENDING.value,
        }
        if user_id:
            payload["user_id"] = user_id

        try:
            res = self.client.table("reels").insert(payload).execute()
            if not res.data:
                raise ReelVaultError("Failed to insert reel record into Supabase.")
            return res.data[0]
        except Exception as e:
            if "DuplicateReelError" in str(e) or "duplicate key value" in str(e).lower():
                raise DuplicateReelError(f"Reel already exists in library: {str(e)}") from e
            logger.error(f"Error creating reel: {str(e)}")
            raise ReelVaultError(f"Database error while saving reel: {str(e)}") from e

    def get_reel(self, reel_id: str) -> Optional[Dict[str, Any]]:
        res = self.client.table("reels").select("*").eq("id", reel_id).execute()
        return res.data[0] if res.data else None

    def list_reels(
        self,
        search: Optional[str] = None,
        status: Optional[str] = None,
        topic: Optional[str] = None,
        page: int = 1,
        limit: int = 20,
        user_id: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        Lists reels with support for full-text search, filtering, and pagination.
        """
        offset = (page - 1) * limit
        query = self.client.table("reels").select("*", count="exact")

        if user_id:
            query = query.eq("user_id", user_id)

        if status:
            query = query.eq("status", status)

        if topic:
            query = query.ilike("topic", f"%{topic}%")

        if search and search.strip():
            term = search.strip()
            # Search using PostgreSQL textSearch or ilike fallback
            query = query.or_(
                f"title.ilike.%{term}%,"
                f"transcript.ilike.%{term}%,"
                f"summary.ilike.%{term}%,"
                f"creator_username.ilike.%{term}%,"
                f"topic.ilike.%{term}%"
            )

        query = query.order("created_at", desc=True).range(offset, offset + limit - 1)
        res = query.execute()

        total = res.count if res.count is not None else len(res.data)
        return {
            "data": res.data or [],
            "total": total,
            "page": page,
            "limit": limit
        }

    def update_reel(self, reel_id: str, fields: Dict[str, Any]) -> Dict[str, Any]:
        fields["updated_at"] = datetime.utcnow().isoformat()
        res = self.client.table("reels").update(fields).eq("id", reel_id).execute()
        return res.data[0] if res.data else {}

    def update_reel_status(
        self,
        reel_id: str,
        status: ProcessingStatus,
        error_message: Optional[str] = None
    ) -> Dict[str, Any]:
        update_data: Dict[str, Any] = {
            "status": status.value,
            "updated_at": datetime.utcnow().isoformat()
        }
        if error_message is not None:
            update_data["error_message"] = error_message
        if status == ProcessingStatus.COMPLETED:
            update_data["processed_at"] = datetime.utcnow().isoformat()

        res = self.client.table("reels").update(update_data).eq("id", reel_id).execute()
        return res.data[0] if res.data else {}

    def delete_reel(self, reel_id: str) -> bool:
        res = self.client.table("reels").delete().eq("id", reel_id).execute()
        return bool(res.data)

    def check_duplicate(self, shortcode: str, user_id: Optional[str] = None) -> Optional[Dict[str, Any]]:
        query = self.client.table("reels").select("id, status, original_url").eq("shortcode", shortcode)
        if user_id:
            query = query.eq("user_id", user_id)
        res = query.execute()
        return res.data[0] if res.data else None

    # --- PROCESSING JOBS ---

    def create_job(self, reel_id: str) -> Dict[str, Any]:
        payload = {
            "reel_id": reel_id,
            "status": JobStatus.QUEUED.value,
            "attempt_count": 0
        }
        res = self.client.table("processing_jobs").insert(payload).execute()
        return res.data[0] if res.data else {}

    def claim_job(self, worker_identifier: str) -> Optional[Dict[str, Any]]:
        """Invokes the atomic PostgreSQL claim_next_job stored procedure."""
        try:
            res = self.client.rpc("claim_next_job", {"worker_identifier": worker_identifier}).execute()
            if res.data and len(res.data) > 0:
                return res.data[0]
            return None
        except Exception as e:
            logger.error(f"Error calling claim_next_job RPC: {str(e)}")
            return None

    def complete_job(self, job_id: str) -> Dict[str, Any]:
        update_data = {
            "status": JobStatus.COMPLETED.value,
            "completed_at": datetime.utcnow().isoformat()
        }
        res = self.client.table("processing_jobs").update(update_data).eq("id", job_id).execute()
        return res.data[0] if res.data else {}

    def fail_job(self, job_id: str, error_message: str) -> Dict[str, Any]:
        update_data = {
            "status": JobStatus.FAILED.value,
            "error_message": error_message,
            "completed_at": datetime.utcnow().isoformat()
        }
        res = self.client.table("processing_jobs").update(update_data).eq("id", job_id).execute()
        return res.data[0] if res.data else {}

    def retry_reel(self, reel_id: str) -> Dict[str, Any]:
        """Resets reel to pending and inserts a new job into the queue."""
        self.update_reel_status(reel_id, ProcessingStatus.PENDING, error_message=None)
        job = self.create_job(reel_id)
        return {"reel_id": reel_id, "job_id": job.get("id"), "status": ProcessingStatus.PENDING.value}
