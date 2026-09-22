# Root Dockerfile for Render / Cloud deployment
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

# Copy and install python dependencies from backend/
COPY backend/requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Pre-download Whisper base model (lightweight, ~140MB, fits easily in Render 512MB RAM)
ARG PRELOAD_WHISPER=true
ARG PRELOAD_MODEL=base
RUN if [ "$PRELOAD_WHISPER" = "true" ] ; then \
        python -c "from faster_whisper import WhisperModel; WhisperModel('$PRELOAD_MODEL', device='cpu', compute_type='int8')" ; \
    fi

# Copy entire backend source code to /app
COPY backend/ .

# Ensure entrypoint script is executable
RUN chmod +x entrypoint.sh

EXPOSE 8000 10000

# Entrypoint starts both Worker daemon and FastAPI on Render's $PORT
CMD ["./entrypoint.sh"]
