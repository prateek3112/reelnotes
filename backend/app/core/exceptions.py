class ReelVaultError(Exception):
    """Base exception for all ReelVault pipeline operations."""
    pass


class DownloadError(ReelVaultError):
    """Raised when yt-dlp fails to retrieve media or metadata."""
    pass


class AudioExtractionError(ReelVaultError):
    """Raised when FFmpeg fails to transcode media to 16kHz mono WAV."""
    pass


class TranscriptionError(ReelVaultError):
    """Raised when the Whisper model fails to process audio."""
    pass


class AnalysisError(ReelVaultError):
    """Raised when the AI analysis engine fails to return structured insights."""
    pass


class DuplicateReelError(ReelVaultError):
    """Raised when a reel has already been captured and processed."""
    pass
