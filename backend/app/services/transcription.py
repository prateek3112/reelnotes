import os
from typing import Any, Dict, List, Optional, TypedDict
import httpx
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
    Unified transcription engine supporting:
    1. Local faster-whisper (CTranslate2)
    2. Cloud Whisper via Groq (Free tier, Whisper Large v3, 0 RAM usage on Render)
    3. Cloud Whisper via OpenAI
    """
    _instance: Optional["TranscriptionEngine"] = None
    _local_model: Any = None

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super(TranscriptionEngine, cls).__new__(cls)
            cls._instance._init_provider()
        return cls._instance

    def _init_provider(self):
        provider = (settings.TRANSCRIPTION_PROVIDER or "whisper").lower()
        if provider in ["groq", "openai"]:
            logger.info(f"Using Cloud Transcription Provider: '{provider}'. Zero local RAM required.")
            return

        # Initialize local faster-whisper
        try:
            from faster_whisper import WhisperModel
            import torch
        except ImportError:
            logger.warning("faster-whisper is not installed. TranscriptionEngine in fallback mode.")
            self._local_model = None
            return

        device = "cuda" if torch.cuda.is_available() else "cpu"
        compute_type = "float16" if device == "cuda" else settings.WHISPER_COMPUTE_TYPE
        model_name = settings.WHISPER_MODEL
        cpu_threads = settings.WHISPER_CPU_THREADS

        logger.info(
            f"Loading faster-whisper '{model_name}' on {device} (compute={compute_type}, threads={cpu_threads})..."
        )

        try:
            self._local_model = WhisperModel(
                model_name,
                device=device,
                compute_type=compute_type,
                cpu_threads=cpu_threads,
                download_root=settings.WHISPER_CACHE_DIR,
            )
            logger.info(f"faster-whisper model '{model_name}' ready.")
        except Exception as e:
            logger.error(f"Failed to load Whisper model: {str(e)}")
            self._local_model = None

    def transcribe(
        self,
        audio_path: str,
        is_hinglish: bool = True,
        initial_prompt: Optional[str] = None
    ) -> TranscriptResult:
        if not os.path.exists(audio_path):
            raise TranscriptionError(f"Audio file does not exist at: {audio_path}")

        prompt = initial_prompt
        if prompt is None and is_hinglish:
            prompt = (
                "Yeh video bohot informative hai. We will discuss technology, AI models, "
                "coding, startup tools, productivity, and workflows."
            )

        provider = (settings.TRANSCRIPTION_PROVIDER or "whisper").lower()

        # Route 1: Cloud Groq Whisper (ideal for low-memory Render deployments)
        if provider == "groq" or (provider == "whisper" and not self._local_model and (settings.GROQ_API_KEY or settings.AI_API_KEY)):
            api_key = settings.GROQ_API_KEY or settings.AI_API_KEY
            if api_key:
                return self._transcribe_groq(audio_path, api_key, prompt)

        # Route 2: Cloud OpenAI Whisper
        if provider == "openai" and settings.OPENAI_API_KEY:
            return self._transcribe_openai(audio_path, settings.OPENAI_API_KEY, prompt)

        # Route 3: Local faster-whisper
        if self._local_model is not None:
            return self._transcribe_local(audio_path, prompt)

        raise TranscriptionError(
            "No transcription engine available. Either configure faster-whisper or set TRANSCRIPTION_PROVIDER='groq' with GROQ_API_KEY."
        )

    def _transcribe_local(self, audio_path: str, prompt: Optional[str]) -> TranscriptResult:
        logger.info(f"Transcribing audio locally via faster-whisper: {audio_path}")
        try:
            segments_generator, info = self._local_model.transcribe(
                audio_path,
                beam_size=5,
                language=None,
                initial_prompt=prompt,
                vad_filter=True,
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

            return {
                "text": " ".join(full_text_list).strip(),
                "language": info.language,
                "language_probability": round(info.language_probability, 3),
                "duration": round(info.duration, 2),
                "segments": structured_segments
            }
        except Exception as e:
            logger.error(f"Local Whisper transcription failed: {str(e)}")
            raise TranscriptionError(f"Audio transcription failed: {str(e)}") from e

    def _transcribe_groq(self, audio_path: str, api_key: str, prompt: Optional[str]) -> TranscriptResult:
        logger.info(f"Transcribing audio in cloud via Groq Whisper Large v3 (0 RAM usage): {audio_path}")
        url = "https://api.groq.com/openai/v1/audio/transcriptions"
        headers = {"Authorization": f"Bearer {api_key}"}

        try:
            with open(audio_path, "rb") as f:
                files = {"file": ("audio.wav", f, "audio/wav")}
                data = {
                    "model": "whisper-large-v3",
                    "response_format": "verbose_json",
                    "temperature": "0.0"
                }
                if prompt:
                    data["prompt"] = prompt

                with httpx.Client(timeout=60.0) as client:
                    resp = client.post(url, headers=headers, files=files, data=data)
                    if resp.status_code != 200:
                        raise TranscriptionError(f"Groq Whisper API returned {resp.status_code}: {resp.text}")

                    res = resp.json()
                    full_text = res.get("text", "").strip()
                    lang = res.get("language", "en")
                    duration = float(res.get("duration", 0.0))
                    raw_segments = res.get("segments", [])

                    segments: List[TranscriptSegment] = [
                        {"start": s.get("start", 0.0), "end": s.get("end", 0.0), "text": s.get("text", "").strip()}
                        for s in raw_segments if s.get("text")
                    ]

                    logger.info(f"Groq transcription completed: {len(segments)} segments, duration: {duration}s")
                    return {
                        "text": full_text,
                        "language": lang,
                        "language_probability": 0.99,
                        "duration": duration,
                        "segments": segments
                    }
        except Exception as e:
            logger.error(f"Groq Whisper transcription failed: {str(e)}")
            raise TranscriptionError(f"Cloud Whisper transcription failed: {str(e)}") from e

    def _transcribe_openai(self, audio_path: str, api_key: str, prompt: Optional[str]) -> TranscriptResult:
        logger.info(f"Transcribing audio via OpenAI Whisper API: {audio_path}")
        url = "https://api.openai.com/v1/audio/transcriptions"
        headers = {"Authorization": f"Bearer {api_key}"}

        try:
            with open(audio_path, "rb") as f:
                files = {"file": ("audio.wav", f, "audio/wav")}
                data = {"model": "whisper-1", "response_format": "verbose_json"}
                if prompt:
                    data["prompt"] = prompt

                with httpx.Client(timeout=60.0) as client:
                    resp = client.post(url, headers=headers, files=files, data=data)
                    if resp.status_code != 200:
                        raise TranscriptionError(f"OpenAI API returned {resp.status_code}: {resp.text}")

                    res = resp.json()
                    return {
                        "text": res.get("text", "").strip(),
                        "language": res.get("language", "en"),
                        "language_probability": 0.99,
                        "duration": float(res.get("duration", 0.0)),
                        "segments": [
                            {"start": s.get("start", 0.0), "end": s.get("end", 0.0), "text": s.get("text", "").strip()}
                            for s in res.get("segments", [])
                        ]
                    }
        except Exception as e:
            raise TranscriptionError(f"OpenAI Whisper transcription failed: {str(e)}") from e
