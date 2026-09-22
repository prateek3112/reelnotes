from fastapi import APIRouter
from app.config import settings

router = APIRouter()


@router.get("/healthz", summary="Health check probe")
async def health_check():
    return {
        "status": "ok",
        "app": settings.APP_NAME,
        "environment": settings.ENVIRONMENT,
        "whisper_model": settings.WHISPER_MODEL,
        "ai_provider": settings.AI_PROVIDER
    }
