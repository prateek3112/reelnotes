import pytest
from app.core.exceptions import AudioExtractionError
from app.services.audio import AudioExtractor


def test_audio_extractor_missing_file():
    with pytest.raises(AudioExtractionError):
        AudioExtractor.extract_audio("/non/existent/video/path.mp4", "/tmp/out.wav")
