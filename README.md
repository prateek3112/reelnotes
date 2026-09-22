# ReelVault

ReelVault is a personal AI-powered content research and knowledge-management application for short-form videos (Instagram Reels).

## Architecture Overview

```text
Instagram Reel (Share Sheet)
        │
        ▼
iOS Share Extension  ──(POST URL)──►  FastAPI API Server
                                             │
                                             ▼
                                     Supabase PostgreSQL
                                      (Job Queue Table)
                                             │
                                             ▼
                                      Worker Process
                                             │
                                  ┌──────────┴──────────┐
                                  ▼                     ▼
                             yt-dlp + FFmpeg      faster-whisper
                             (Download & Audio)   (Transcription)
                                                        │
                                                        ▼
                                                   AI Analyzer
                                              (Title, Hook, Summary,
                                               Tags, Structure)
                                                        │
                                                        ▼
                                                  Supabase DB
                                                 (Realtime sync)
                                                        │
                                                        ▼
                                                   SwiftUI App
                                                (Library & Search)
```

## Directory Structure

- `backend/`: FastAPI application, worker process, media pipeline, Docker configs.
- `supabase/migrations/`: SQL migration files for tables, indexes, and atomic RPC job dispatching.
- `ios/`: SwiftUI iOS App (`ReelVault`) and Share Extension (`ReelVaultShareExtension`).
- `docs/`: Product Requirements Document and Architecture details.

## Quick Start (Backend)

1. Navigate to `backend/`
2. Create `.env` based on `.env.example`:
   ```bash
   cp .env.example .env
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Start the API server:
   ```bash
   uvicorn app.main:app --reload --port 8000
   ```
5. In a separate terminal, run the processing worker:
   ```bash
   python -m app.workers.poller
   ```
