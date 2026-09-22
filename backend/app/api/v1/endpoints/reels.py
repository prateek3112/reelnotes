from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from app.api.deps import get_supabase_service, verify_api_key
from app.core.exceptions import DuplicateReelError, ReelVaultError
from app.core.logging import logger
from app.models.enums import ProcessingStatus
from app.schemas.reel import ReelCreate, ReelDetail, ReelListResponse, ReelResponse
from app.services.downloader import MediaDownloader
from app.services.supabase_service import SupabaseService

router = APIRouter(prefix="/reels", tags=["reels"])


@router.post(
    "",
    response_model=ReelResponse,
    status_code=status.HTTP_202_ACCEPTED,
    summary="Submit a new Instagram Reel for capture and background processing",
    dependencies=[Depends(verify_api_key)]
)
async def submit_reel(
    payload: ReelCreate,
    supabase: SupabaseService = Depends(get_supabase_service)
):
    """
    Submits an Instagram Reel URL to the processing pipeline.
    Returns immediately (<1 sec) while media extraction, transcription,
    and AI categorization happen asynchronously in the background worker.
    """
    sanitized_url = MediaDownloader.sanitize_url(payload.url)
    shortcode = MediaDownloader.extract_shortcode(sanitized_url)

    try:
        # 1. Create reel row in Supabase
        reel = supabase.create_reel(
            original_url=sanitized_url,
            shortcode=shortcode,
            source_platform="instagram"
        )
        reel_id = reel["id"]

        # 2. Enqueue processing job
        supabase.create_job(reel_id)
        logger.info(f"Reel successfully enqueued: id={reel_id}, shortcode={shortcode}")

        return ReelResponse(
            id=reel_id,
            status=ProcessingStatus(reel.get("status", "pending")),
            original_url=sanitized_url,
            shortcode=shortcode,
            created_at=reel["created_at"],
            message="Reel queued for processing."
        )
    except DuplicateReelError as e:
        existing = supabase.check_duplicate(shortcode) if shortcode else None
        if existing:
            return ReelResponse(
                id=existing["id"],
                status=ProcessingStatus(existing.get("status", "completed")),
                original_url=existing.get("original_url", sanitized_url),
                shortcode=shortcode,
                created_at=existing.get("created_at"),
                message="Already in your library."
            )
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    except ReelVaultError as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(e))


@router.get(
    "",
    response_model=ReelListResponse,
    summary="List saved reels with full-text search, filtering and pagination",
    dependencies=[Depends(verify_api_key)]
)
async def list_reels(
    search: Optional[str] = Query(None, description="Full-text search query across titles, transcripts, and topics"),
    status: Optional[str] = Query(None, description="Filter by status (e.g. pending, completed, failed)"),
    topic: Optional[str] = Query(None, description="Filter by topic keyword"),
    page: int = Query(1, ge=1, description="Page number"),
    limit: int = Query(20, ge=1, le=100, description="Items per page"),
    supabase: SupabaseService = Depends(get_supabase_service)
):
    try:
        result = supabase.list_reels(
            search=search,
            status=status,
            topic=topic,
            page=page,
            limit=limit
        )
        return ReelListResponse(
            data=result["data"],
            total=result["total"],
            page=page,
            limit=limit
        )
    except Exception as e:
        logger.error(f"Error querying reels: {str(e)}")
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Failed to fetch reels: {str(e)}")


@router.get(
    "/{reel_id}",
    response_model=ReelDetail,
    summary="Get complete reel details including transcript, hook, and analysis",
    dependencies=[Depends(verify_api_key)]
)
async def get_reel(
    reel_id: str,
    supabase: SupabaseService = Depends(get_supabase_service)
):
    reel = supabase.get_reel(reel_id)
    if not reel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Reel with id '{reel_id}' not found.")
    return reel


@router.delete(
    "/{reel_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete a saved Reel and its associated job records",
    dependencies=[Depends(verify_api_key)]
)
async def delete_reel(
    reel_id: str,
    supabase: SupabaseService = Depends(get_supabase_service)
):
    deleted = supabase.delete_reel(reel_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Reel with id '{reel_id}' not found.")
    return None


@router.post(
    "/{reel_id}/retry",
    summary="Retry a failed Reel processing job",
    dependencies=[Depends(verify_api_key)]
)
async def retry_reel(
    reel_id: str,
    supabase: SupabaseService = Depends(get_supabase_service)
):
    reel = supabase.get_reel(reel_id)
    if not reel:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=f"Reel with id '{reel_id}' not found.")

    res = supabase.retry_reel(reel_id)
    return {"message": "Reel requeued for processing", "data": res}
