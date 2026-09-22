import re
from datetime import datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, field_validator
from app.models.enums import ProcessingStatus


class ReelCreate(BaseModel):
    url: str = Field(..., description="Instagram Reel URL (e.g. https://www.instagram.com/reel/C8abc123/)")

    @field_validator("url")
    @classmethod
    def validate_url(cls, v: str) -> str:
        clean_url = v.strip()
        # Basic check for instagram URL
        pattern = r"instagram\.com/(reel|reels|p)/([A-Za-z0-9_-]+)"
        if not re.search(pattern, clean_url, re.IGNORECASE):
            raise ValueError("URL must be a valid Instagram Reel or Post link (e.g. https://www.instagram.com/reel/ABC123/)")
        return clean_url


class ReelResponse(BaseModel):
    id: str
    status: ProcessingStatus
    original_url: str
    shortcode: Optional[str] = None
    created_at: datetime
    message: Optional[str] = "Reel queued for processing."


class ContentStructureItem(BaseModel):
    type: str
    description: str


class ReelDetail(BaseModel):
    id: str
    user_id: Optional[str] = None
    source_platform: str = "instagram"
    original_url: str
    shortcode: Optional[str] = None
    creator_username: Optional[str] = None
    creator_name: Optional[str] = None
    title: Optional[str] = None
    topic: Optional[str] = None
    summary: Optional[str] = None
    hook: Optional[str] = None
    transcript: Optional[str] = None
    cleaned_transcript: Optional[str] = None
    content_structure: Optional[List[Dict[str, Any]]] = None
    tags: List[str] = Field(default_factory=list)
    thumbnail_url: Optional[str] = None
    duration_seconds: Optional[int] = None
    status: ProcessingStatus
    error_message: Optional[str] = None
    created_at: datetime
    processed_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None


class ReelListResponse(BaseModel):
    data: List[ReelDetail]
    total: int
    page: int
    limit: int
