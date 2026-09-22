from typing import Optional
from fastapi import Header, HTTPException, Security, status
from fastapi.security import APIKeyHeader, HTTPBearer, HTTPAuthorizationCredentials
from app.config import settings
from app.services.supabase_service import SupabaseService

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)
bearer_auth = HTTPBearer(auto_error=False)

_supabase_service: Optional[SupabaseService] = None


def get_supabase_service() -> SupabaseService:
    global _supabase_service
    if _supabase_service is None:
        _supabase_service = SupabaseService()
    return _supabase_service


async def verify_api_key(
    x_api_key: Optional[str] = Security(api_key_header),
    credentials: Optional[HTTPAuthorizationCredentials] = Security(bearer_auth)
) -> bool:
    """
    Validates API key from either X-API-Key header or Bearer token.
    If no API_KEY is configured in settings, requests are permitted (MVP local dev).
    """
    expected_key = settings.API_KEY
    if not expected_key:
        return True

    # Check X-API-Key header
    if x_api_key and x_api_key == expected_key:
        return True

    # Check Bearer token
    if credentials and credentials.credentials == expected_key:
        return True

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing API Key. Include 'X-API-Key' header or Bearer token.",
        headers={"WWW-Authenticate": "Bearer"},
    )
