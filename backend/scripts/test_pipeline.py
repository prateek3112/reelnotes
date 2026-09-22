#!/usr/bin/env python3
"""
Phase 2 Prototype Script:
Validates the complete standalone media processing pipeline on a real Instagram Reel URL:
URL -> yt-dlp (MP4) -> FFmpeg (16kHz WAV) -> faster-whisper (Text) -> AI Analysis -> Output.

Usage:
    python scripts/test_pipeline.py "https://www.instagram.com/reel/XXXXX/"
"""

import argparse
import asyncio
import os
import sys
import tempfile
import time

# Ensure project root is on sys.path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.services.downloader import MediaDownloader
from app.services.audio import AudioExtractor
from app.services.transcription import TranscriptionEngine
from app.services.analysis import get_analysis_provider
from app.core.logging import logger


def run_test_pipeline(url: str):
    print("=" * 60)
    print(f"🎬 ReelVault Prototype Pipeline Test")
    print(f"Target URL: {url}")
    print("=" * 60)

    start_total = time.time()
    with tempfile.TemporaryDirectory(prefix="test_pipeline_") as tmp_dir:
        # Step 1: Download Media
        print("\n📥 Step 1: Downloading Instagram Reel...")
        t0 = time.time()
        downloader = MediaDownloader()
        media = downloader.download(url, output_dir=tmp_dir)
        t_download = time.time() - t0
        print(f"   ✓ Video acquired in {t_download:.2f}s")
        print(f"   • Title: {media.get('title')}")
        print(f"   • Creator: @{media.get('uploader')}")
        print(f"   • Duration: {media.get('duration')}s")
        print(f"   • Local File: {media['video_path']}")

        # Step 2: Extract Audio
        print("\n🎵 Step 2: Extracting 16kHz Mono Audio via FFmpeg...")
        t0 = time.time()
        audio_path = os.path.join(tmp_dir, "test_audio.wav")
        AudioExtractor.extract_audio(media["video_path"], audio_path)
        t_audio = time.time() - t0
        print(f"   ✓ Audio extracted in {t_audio:.2f}s ({os.path.getsize(audio_path)} bytes)")

        # Step 3: Transcribe
        print("\n🗣️ Step 3: Transcribing Audio with faster-whisper...")
        t0 = time.time()
        transcriber = TranscriptionEngine()
        res = transcriber.transcribe(audio_path, is_hinglish=True)
        t_transcribe = time.time() - t0
        print(f"   ✓ Transcribed in {t_transcribe:.2f}s")
        print(f"   • Language Detected: {res['language']} (confidence: {res['language_probability']})")
        print(f"\n--- RAW TRANSCRIPT ---\n{res['text']}\n----------------------")

        # Step 4: AI Analysis
        print("\n🧠 Step 4: Generating Structured AI Analysis...")
        t0 = time.time()
        analyzer = get_analysis_provider()
        analysis = asyncio.run(analyzer.analyze(
            transcript=res["text"],
            metadata={"description": media.get("description"), "title": media.get("title")}
        ))
        t_analysis = time.time() - t0
        print(f"   ✓ Analysis generated in {t_analysis:.2f}s")
        print(f"\n--- STRUCTURED KNOWLEDGE ---")
        print(f"Title: {analysis['title']}")
        print(f"Topic: {analysis['topic']}")
        print(f"Hook: {analysis['hook']}")
        print(f"Summary: {analysis['summary']}")
        print(f"Tags: {', '.join(analysis['tags'])}")
        print(f"Content Structure:")
        for idx, item in enumerate(analysis.get("content_structure", []), 1):
            print(f"  {idx}. [{item.get('type').upper()}] {item.get('description')}")
        print("----------------------------")

    total_time = time.time() - start_total
    print(f"\n✅ All stages completed in {total_time:.2f}s. Temporary media purged.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scripts/test_pipeline.py <instagram_reel_url>")
        sys.exit(1)
    run_test_pipeline(sys.argv[1])
