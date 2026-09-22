import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # Application
    APP_NAME: str = "ReelVault API"
    ENVIRONMENT: str = "development"
    DEBUG: bool = False
    API_V1_PREFIX: str = "/api/v1"
    API_KEY: Optional[str] = "reelvault-secret-api-key"

    # Supabase credentials
    SUPABASE_URL: str = "https://placeholder.supabase.co"
    SUPABASE_ANON_KEY: str = "placeholder-anon-key"
    SUPABASE_SERVICE_ROLE_KEY: str = "placeholder-service-role-key"
    SUPABASE_STORAGE_BUCKET: str = "thumbnails"

    # Worker Settings
    WORKER_POLL_INTERVAL: float = 3.0
    MAX_PROCESSING_ATTEMPTS: int = 3
    TEMP_MEDIA_DIR: str = "/tmp/reelvault"

    # Transcription Settings
    # "whisper" (local faster-whisper), "groq" (cloud Whisper Large v3 - 100% free, 0 RAM), or "openai"
    TRANSCRIPTION_PROVIDER: str = "whisper"
    WHISPER_MODEL: str = "base"  # base or tiny for low-RAM hosts like Render Free/Starter, small for >=2GB RAM
    WHISPER_CPU_THREADS: int = 2
    WHISPER_COMPUTE_TYPE: str = "int8"
    WHISPER_CACHE_DIR: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None
    OPENAI_API_KEY: Optional[str] = None

    # AI Analysis Provider Settings
    AI_PROVIDER: str = "gemini"  # gemini, groq, ollama, openai
    AI_API_KEY: Optional[str] = None
    AI_MODEL: str = "gemini-2.0-flash"
    OLLAMA_BASE_URL: str = "http://localhost:11434"

    # Instagram Acquisition
    INSTAGRAM_COOKIES_PATH: Optional[str] = "./secrets/cookies.txt"
    INSTAGRAM_COOKIES_TEXT: Optional[str] = None  # Direct paste into environment variable

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore"
    )


settings = Settings()
