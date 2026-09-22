import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_health_check_endpoint():
    response = client.get("/api/v1/healthz")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "app" in data
    assert "whisper_model" in data


def test_submit_reel_invalid_url():
    response = client.post(
        "/api/v1/reels",
        json={"url": "https://example.com/not-an-instagram-link"},
        headers={"X-API-Key": "reelvault-secret-api-key"}
    )
    assert response.status_code == 422  # Pydantic validation error


def test_api_key_unauthorized():
    response = client.post(
        "/api/v1/reels",
        json={"url": "https://www.instagram.com/reel/C8ABC123xyz/"},
        headers={"X-API-Key": "wrong-key"}
    )
    assert response.status_code == 401
