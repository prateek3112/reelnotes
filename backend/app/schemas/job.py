from datetime import datetime
from typing import Optional
from pydantic import BaseModel
from app.models.enums import JobStatus


class JobResponse(BaseModel):
    id: str
    reel_id: str
    status: JobStatus
    attempt_count: int
    max_attempts: int
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    error_message: Optional[str] = None
    created_at: datetime
