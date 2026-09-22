import pytest
from app.services.downloader import MediaDownloader


def test_extract_shortcode_standard_reel():
    url = "https://www.instagram.com/reel/C8ABC123xyz/"
    assert MediaDownloader.extract_shortcode(url) == "C8ABC123xyz"


def test_extract_shortcode_reels_plural():
    url = "https://instagram.com/reels/DA123456789/"
    assert MediaDownloader.extract_shortcode(url) == "DA123456789"


def test_extract_shortcode_post_format():
    url = "https://www.instagram.com/p/B_xyz_987/?igsh=MWFqY24xdHNr"
    assert MediaDownloader.extract_shortcode(url) == "B_xyz_987"


def test_sanitize_url():
    dirty_url = "https://www.instagram.com/reel/C8ABC123xyz/?igsh=NDF5amc4aW93bHlm&utm_source=qr"
    clean_url = MediaDownloader.sanitize_url(dirty_url)
    assert clean_url == "https://www.instagram.com/reel/C8ABC123xyz/"
    assert "?" not in clean_url
    assert "igsh" not in clean_url
