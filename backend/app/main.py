from contextlib import asynccontextmanager
from fastapi import FastAPI, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.api.v1.router import api_router
from app.config import settings
from app.core.cleanup import cleanup_stale_temp_dirs
from app.core.exceptions import ReelVaultError
from app.core.logging import logger


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: perform temporary directory sweep
    logger.info(f"Starting {settings.APP_NAME} in '{settings.ENVIRONMENT}' mode...")
    cleanup_stale_temp_dirs(settings.TEMP_MEDIA_DIR)
    yield
    # Shutdown
    logger.info(f"Shutting down {settings.APP_NAME}...")


app = FastAPI(
    title=settings.APP_NAME,
    version="0.1.0",
    description="ReelVault: AI-powered knowledge management backend for Instagram Reels",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS configuration for iOS app and web clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(ReelVaultError)
async def reelvault_exception_handler(request: Request, exc: ReelVaultError):
    logger.error(f"Handled ReelVaultError on {request.url.path}: {str(exc)}")
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"detail": str(exc), "type": type(exc).__name__}
    )


# Include aggregated API v1 router
app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/", include_in_schema=False)
async def root():
    return {
        "app": settings.APP_NAME,
        "docs": "/docs",
        "health": f"{settings.API_V1_PREFIX}/healthz"
    }
