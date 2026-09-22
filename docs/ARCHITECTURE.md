# Architecture Document: ReelVault

## 1. System Overview

ReelVault is composed of three primary subsystems:
1. **iOS Client Ecosystem**:
   - **ReelVault Main App**: SwiftUI iOS 17+ client using MVVM with `@Observable`, SwiftData local caching, and Supabase Realtime for instant status reflections.
   - **ReelVault Share Extension**: Lightweight extension hosted in an App Group, capable of extracting Instagram URLs from `public.url` and `public.plain-text` item providers and dispatching them asynchronously to the FastAPI backend.
2. **Backend Services**:
   - **FastAPI Web Service**: High-throughput REST API for job ingest, status polling, library querying, and full-text search.
   - **Background Worker Process**: Long-running background daemon polling Supabase via PostgreSQL's `FOR UPDATE SKIP LOCKED` stored procedure (`claim_next_job`).
3. **Media Pipeline & AI Services**:
   - **Media Acquisition**: `yt-dlp` programmatic wrapper with optional Instagram cookies.
   - **Audio Extraction**: FFmpeg subprocess converting video streams into 16kHz mono 16-bit PCM WAV.
   - **Transcription**: `faster-whisper` (CTranslate2) utilizing auto-detect and vocabulary biasing for Hinglish / English.
   - **AI Analysis**: Pluggable provider layer (Gemini, Groq, Ollama, OpenAI) extracting Hook, Title, Topic, Summary, Structure, and Tags without fabricating data.

## 2. Data Flow & Idempotency

1. User taps "Share" on an Instagram Reel -> selects ReelVault.
2. Share Extension extracts clean Reel URL (stripping `igsh`, `utm_*`).
3. Extension POSTs URL to `/api/v1/reels` with `X-API-Key`.
4. API validates URL regex, extracts shortcode, and inserts a row into `public.reels` (`status='pending'`) and `public.processing_jobs` (`status='queued'`).
5. Extension receives HTTP 202 / 200 with `id` and `status`, displays success checkmark, and exits in < 1 second.
6. Worker poller calls `claim_next_job(worker_id)` via Supabase RPC.
7. Worker updates reel status through pipeline states:
   - `downloading` -> `extracting_audio` -> `transcribing` -> `analyzing` -> `completed`.
8. Realtime events from Supabase update SwiftUI views automatically.
9. Temporary media (video MP4 and WAV) is stored in an ephemeral job-isolated directory and guaranteed deleted immediately upon completion or failure.
