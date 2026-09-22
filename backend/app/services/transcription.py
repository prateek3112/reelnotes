import os
from typing import Any, Dict, List, Optional, TypedDict
from app.config import settings
from app.core.exceptions import TranscriptionError
from app.core.logging import logger


class TranscriptSegment(TypedDict):
    start: float
    end: float
    text: str


class TranscriptResult(TypedDict):
    text: str
    language: str
    language_probability: float
    duration: float
    segments: List[TranscriptSegment]


class TranscriptionEngine:
    """
    Singleton wrapper around faster-whisper CTranslate2 model.
    Loads weights once in memory and reuses them across all worker tasks.
    """
    _instance: Optional["TranscriptionEngine"] = None
    _model: Any = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(TranscriptionEngine, cls).__new__(cls)
            cls._instance._init_model()
        return cls._instance

    def _init_model(self):
        try:
            from faster_whisper import WhisperModel
            import torch
        except ImportError:
            logger.warning("faster-whisper is not installed. TranscriptionEngine initialized in fallback mode.")
            self._model = None
            return

        device = "cuda" if torch.cuda.is_available() else "cpu"
        compute_type = "float16" if device == "cuda" else settings.WHISPER_COMPUTE_TYPE
        model_name = settings.WHISPER_MODEL
        cpu_threads = settings.WHISPER_CPU_THREADS

        logger.info(
            f"Loading faster-whisper model '{model_name}' on {device} (compute_type={compute_type}, threads={cpu_threads})..."
        )

        try:
            self._model = WhisperModel(
                model_name,
                device=device,
                compute_type=compute_type,
                cpu_threads=cpu_threads,
                download_root=settings.WHISPER_CACHE_DIR,
            )
            logger.info(f"faster-whisper model '{model_name}' loaded successfully.")
        except Exception as e:
            logger.error(f"Failed to load Whisper model: {str(e)}")
            self._model = None
            raise TranscriptionError(f"Failed to initialize Whisper model: {str(e)}") from e

    def transcribe(
        self,
        audio_path: str,
        is_hinglish: bool = True,
        initial_prompt: Optional[str] = None
    ) -> TranscriptResult:
        if self._model is None:
            raise TranscriptionError(
                "WhisperModel is not initialized. Ensure faster-whisper and ctranslate2 are installed."
            )

        if not os.path.exists(audio_path):
            raise TranscriptionError(f"Audio file does not exist at: {audio_path}")

        # Vocabulary bias for Hinglish / Indian English / tech slang
        prompt = initial_prompt
        if prompt is None and is_hinglish:
            prompt = (
                "Yeh video bohot informative hai. We will discuss technology, AI models, "
                "coding, startup tools, productivity, and workflows."
            )

        logger.info(f"Transcribing audio file: {audio_path}")
        try:
            segments_generator, info = self._model.transcribe(
                audio_path,
                beam_size=5,
                language=None,          # Auto-detect language (Hindi, English, etc.)
                initial_prompt=prompt,  # Primes model for Romanized Hindi / English code-switching
                vad_filter=True,        # Strips silence and background music
                vad_parameters=dict(min_silence_duration_ms=500),
                word_timestamps=False
            )

            full_text_list: List[str] = []
            structured_segments: List[TranscriptSegment] = []

            for seg in segments_generator:
                text_clean = seg.text.strip()
                if text_clean:
                    full_text_list.append(text_clean)
                    structured_segments.append({
                        "start": round(seg.start, 2),
                        "end": round(seg.end, 2),
                        "text": text_clean
                    })

            full_transcript = " ".join(full_text_list).strip()
            logger.info(
                f"Transcription complete: {len(structured_segments)} segments, "
                f"language='{info.language}' (prob={info.language_probability:.2f}), "
                f"duration={info.duration:.1f}s."
            )

            return {
                "text": full_transcript,
                "language": info.language,
                "language_probability": round(info.language_probability, 3),
                "duration": round(info.duration, 2),
                "segments": structured_segments
            }
        except Exception as e:
            logger.error(f"Whisper transcription failed: {str(e)}")
            raise TranscriptionError(f"Audio transcription failed: {str(e)}") from e
