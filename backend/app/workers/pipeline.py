import os
import tempfile
import time
from typing import Any, Dict
from app.config import settings
from app.core.exceptions import ReelVaultError
from app.core.logging import logger
from app.models.enums import ProcessingStatus
from app.services.analysis import get_analysis_provider
from app.services.audio import AudioExtractor
from app.services.downloader import MediaDownloader
from app.services.supabase_service import SupabaseService
from app.services.transcription import TranscriptionEngine


def process_reel_job(job: Dict[str, Any], supabase: SupabaseService) -> Dict[str, Any]:
    """
    Executes the complete ReelVault processing pipeline for a queued job:
    1. Download media & extract metadata via yt-dlp
    2. Extract 16kHz mono audio via FFmpeg
    3. Transcribe audio via faster-whisper (Hinglish/English)
    4. Save raw transcript to database
    5. Perform AI analysis for title, topic, summary, hook, structure, and tags
    6. Update database with structured knowledge
    7. Ephemeral cleanup of video and audio
    """
    job_id = job["id"]
    reel_id = job["reel_id"]
    start_time = time.time()

    logger.info(f"==> Starting processing pipeline for Job {job_id} (Reel {reel_id})")

    # Fetch reel details
    reel = supabase.get_reel(reel_id)
    if not reel:
        raise ReelVaultError(f"Associated Reel {reel_id} not found in database.")

    reel_url = reel["original_url"]
    base_tmp = settings.TEMP_MEDIA_DIR
    os.makedirs(base_tmp, exist_ok=True)

    with tempfile.TemporaryDirectory(prefix=f"job_{job_id}_", dir=base_tmp) as tmp_dir:
        # --- STAGE 1: Download Media ---
        stage_start = time.time()
        supabase.update_reel_status(reel_id, ProcessingStatus.DOWNLOADING)
        logger.info(f"Stage [1/4] Downloading media for: {reel_url}")

        downloader = MediaDownloader()
        media_result = downloader.download(reel_url, output_dir=tmp_dir)
        video_path = media_result["video_path"]
        download_duration = time.time() - stage_start

        # Persist extracted metadata
        metadata_update = {
            "creator_username": media_result.get("uploader"),
            "creator_name": media_result.get("creator_name"),
            "duration_seconds": media_result.get("duration"),
            "thumbnail_url": media_result.get("thumbnail"),
        }
        if not reel.get("title") and media_result.get("title"):
            metadata_update["title"] = media_result["title"]

        supabase.update_reel(reel_id, metadata_update)
        logger.info(f"Stage [1/4] Downloaded in {download_duration:.2f}s: {video_path}")

        # --- STAGE 2: Extract Audio ---
        stage_start = time.time()
        supabase.update_reel_status(reel_id, ProcessingStatus.EXTRACTING_AUDIO)
        logger.info("Stage [2/4] Extracting 16kHz mono WAV audio via FFmpeg...")

        audio_path = os.path.join(tmp_dir, "audio_16k.wav")
        AudioExtractor.extract_audio(video_path, audio_path)
        audio_duration = time.time() - stage_start
        logger.info(f"Stage [2/4] Audio extracted in {audio_duration:.2f}s")

        # --- STAGE 3: Transcribe Audio ---
        stage_start = time.time()
        supabase.update_reel_status(reel_id, ProcessingStatus.TRANSCRIBING)
        logger.info("Stage [3/4] Transcribing audio via faster-whisper...")

        transcriber = TranscriptionEngine()
        transcript_res = transcriber.transcribe(audio_path, is_hinglish=True)
        raw_transcript = transcript_res["text"]
        transcribe_duration = time.time() - stage_start

        # Immediately save raw transcript so user retains it even if AI stage fails
        supabase.update_reel(reel_id, {
            "transcript": raw_transcript,
            "cleaned_transcript": raw_transcript,
        })
        logger.info(f"Stage [3/4] Transcribed in {transcribe_duration:.2f}s: '{raw_transcript[:60]}...'")

        # --- STAGE 4: AI Analysis ---
        stage_start = time.time()
        supabase.update_reel_status(reel_id, ProcessingStatus.ANALYZING)
        logger.info("Stage [4/4] Generating AI structured analysis (hook, summary, structure, tags)...")

        analysis_provider = get_analysis_provider()
        analysis_data = {}
        try:
            # Run async analyze inside synchronous worker pipeline
            import asyncio
            analysis_data = asyncio.run(analysis_provider.analyze(
                transcript=raw_transcript,
                metadata={
                    "title": reel.get("title") or media_result.get("title"),
                    "description": media_result.get("description"),
                    "uploader": media_result.get("uploader"),
                }
            ))
            analysis_duration = time.time() - stage_start
            logger.info(f"Stage [4/4] AI analysis completed in {analysis_duration:.2f}s")

            # Persist AI analysis
            supabase.update_reel(reel_id, {
                "title": analysis_data.get("title"),
                "topic": analysis_data.get("topic"),
                "summary": analysis_data.get("summary"),
                "hook": analysis_data.get("hook"),
                "tags": analysis_data.get("tags", []),
                "content_structure": analysis_data.get("content_structure", []),
                "cleaned_transcript": analysis_data.get("cleaned_transcript", raw_transcript),
            })
        except Exception as e:
            logger.warning(
                f"AI analysis failed ({str(e)}), but raw transcript was preserved for Reel {reel_id}."
            )

        # Mark Reel as COMPLETED
        supabase.update_reel_status(reel_id, ProcessingStatus.COMPLETED, error_message=None)
        supabase.complete_job(job_id)

        total_duration = time.time() - start_time
        logger.info(
            f"<== Job {job_id} successfully completed in {total_duration:.2f}s. "
            f"All temporary files cleaned."
        )

        return {
            "reel_id": reel_id,
            "job_id": job_id,
            "status": ProcessingStatus.COMPLETED.value,
            "total_duration": total_duration,
            "transcript_length": len(raw_transcript)
        }
