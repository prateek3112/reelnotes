# Multi-stage optimized Dockerfile for ReelVault API and Worker
FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HF_HOME=/root/.cache/huggingface \
    TMPDIR=/tmp/reelvault

# Install system dependencies: ffmpeg, libgomp1 (OpenMP for ctranslate2), curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libgomp1 \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Ensure scratch directories exist
RUN mkdir -p /tmp/reelvault /root/.cache/huggingface /app/secrets

# Copy and install python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Pre-download Whisper model into the container image to prevent runtime latency
ARG PRELOAD_WHISPER=true
RUN if [ "$PRELOAD_WHISPER" = "true" ] ; then \
        python -c "from faster_whisper import WhisperModel; WhisperModel('small', device='cpu', compute_type='int8')" ; \
    fi

COPY . .

EXPOSE 8000

# Default entrypoint runs FastAPI API server
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
