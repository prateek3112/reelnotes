import os
import subprocess
from app.core.exceptions import AudioExtractionError
from app.core.logging import logger


class AudioExtractor:
    """
    Extracts high-fidelity 16kHz mono 16-bit PCM WAV audio from video files
    optimized specifically for Whisper speech recognition.
    """

    @staticmethod
    def extract_audio(video_path: str, output_wav_path: str, timeout_seconds: int = 120) -> str:
        if not os.path.exists(video_path):
            raise AudioExtractionError(f"Source video file not found at: {video_path}")

        command = [
            "ffmpeg",
            "-y",                   # Overwrite output without prompting
            "-i", video_path,       # Source video file
            "-vn",                  # Disable video recording
            "-c:a", "pcm_s16le",    # 16-bit signed PCM WAV
            "-ar", "16000",         # 16 kHz sample rate (Whisper native)
            "-ac", "1",             # Downmix to 1 mono channel
            output_wav_path
        ]

        logger.info(f"Extracting 16kHz mono audio via FFmpeg to: {output_wav_path}")
        try:
            result = subprocess.run(
                command,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                timeout=timeout_seconds
            )
            if not os.path.exists(output_wav_path) or os.path.getsize(output_wav_path) == 0:
                raise AudioExtractionError("FFmpeg completed but generated an empty or non-existent audio file.")
            
            logger.info(f"Audio extracted successfully: {os.path.getsize(output_wav_path)} bytes.")
            return output_wav_path
        except subprocess.TimeoutExpired as e:
            raise AudioExtractionError(f"FFmpeg timed out after {timeout_seconds}s extracting audio.") from e
        except subprocess.CalledProcessError as e:
            err_msg = e.stderr.strip() if e.stderr else "Unknown FFmpeg error"
            logger.error(f"FFmpeg error: {err_msg}")
            raise AudioExtractionError(f"FFmpeg audio extraction failed: {err_msg}") from e
