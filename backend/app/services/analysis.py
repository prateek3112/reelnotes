import abc
import json
import re
from typing import Any, Dict, List, Optional, TypedDict
import httpx
from app.config import settings
from app.core.exceptions import AnalysisError
from app.core.logging import logger


class AnalysisResult(TypedDict):
    title: str
    topic: str
    summary: str
    hook: str
    content_structure: List[Dict[str, str]]
    tags: List[str]
    cleaned_transcript: str


ANALYSIS_SYSTEM_PROMPT = """You are ReelVault's expert short-form content research intelligence agent.
Your objective is to transform raw video transcripts of Instagram Reels into structured, high-value knowledge notes for creators and researchers.

Follow these strict guidelines:
1. Understand the Reel thoroughly from the transcript and available caption metadata.
2. Formulate a concise, descriptive title (maximum 8-10 words, informative, no cheap clickbait).
3. Identify the primary topic (e.g., 'AI / Local Models', 'Coding Tools', 'Content Strategy').
4. Write an insightful 2-3 sentence summary summarizing the core takeaways.
5. Identify the exact opening hook spoken in the first 3-5 seconds.
6. Outline the content structure as an array of step objects, e.g.:
   - {"type": "hook", "description": "Claims older model is obsolete"}
   - {"type": "context", "description": "Explains hardware requirements"}
   - {"type": "reveal", "description": "Introduces the new framework"}
   - {"type": "demonstration", "description": "Shows terminal command and live output"}
   - {"type": "cta", "description": "Asks viewers to comment for code link"}
7. Generate 3 to 7 relevant searchable tags.
8. Clean the raw transcript: correct obvious transcription typos, fix punctuation, add readable paragraph breaks, remove excessive stutter/fillers ('um', 'uh'), but DO NOT change the spoken meaning.
9. HINGLISH PRESERVATION: If speech is code-mixed Hindi and English, PRESERVE IT in Romanized script. DO NOT translate Hindi speech into pure English.
10. NEVER fabricate tools, specs, or claims that were not mentioned in the transcript.

You MUST respond strictly with valid, unescaped JSON matching this schema:
{
  "title": "string",
  "topic": "string",
  "summary": "string",
  "hook": "string",
  "content_structure": [
    {"type": "hook", "description": "string"},
    {"type": "reveal", "description": "string"}
  ],
  "tags": ["string"],
  "cleaned_transcript": "string"
}
"""


class AnalysisProvider(abc.ABC):
    """Abstract Base Class for pluggable AI LLM providers."""

    @abc.abstractmethod
    async def analyze(self, transcript: str, metadata: Dict[str, Any]) -> AnalysisResult:
        pass


class GeminiAnalysisProvider(AnalysisProvider):
    """Google Gemini AI Provider."""

    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None):
        self.api_key = api_key or settings.AI_API_KEY
        self.model = model or settings.AI_MODEL

    async def analyze(self, transcript: str, metadata: Dict[str, Any]) -> AnalysisResult:
        if not self.api_key:
            raise AnalysisError("Gemini API key is not configured.")

        url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.model}:generateContent?key={self.api_key}"
        user_prompt = f"CAPTION METADATA:\n{metadata.get('description', '')}\n\nRAW TRANSCRIPT:\n{transcript}"

        payload = {
            "contents": [
                {
                    "role": "user",
                    "parts": [{"text": f"{ANALYSIS_SYSTEM_PROMPT}\n\n{user_prompt}"}]
                }
            ],
            "generationConfig": {
                "temperature": 0.2,
                "responseMimeType": "application/json"
            }
        }

        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(url, json=payload)
            if response.status_code != 200:
                raise AnalysisError(f"Gemini API returned error {response.status_code}: {response.text}")

            data = response.json()
            try:
                candidate = data["candidates"][0]["content"]["parts"][0]["text"]
                return self._parse_json_result(candidate, transcript)
            except (KeyError, IndexError) as e:
                raise AnalysisError(f"Unexpected response format from Gemini: {str(e)}")

    def _parse_json_result(self, raw_text: str, original_transcript: str) -> AnalysisResult:
        clean_text = re.sub(r"^```json\s*", "", raw_text.strip())
        clean_text = re.sub(r"\s*```$", "", clean_text)
        parsed = json.loads(clean_text)
        return {
            "title": parsed.get("title", "Saved Reel"),
            "topic": parsed.get("topic", "General"),
            "summary": parsed.get("summary", ""),
            "hook": parsed.get("hook", ""),
            "content_structure": parsed.get("content_structure", []),
            "tags": parsed.get("tags", []),
            "cleaned_transcript": parsed.get("cleaned_transcript", original_transcript),
        }


class GroqAnalysisProvider(AnalysisProvider):
    """Groq Provider (Llama-3.1 / Mixtral inference)."""

    def __init__(self, api_key: Optional[str] = None, model: Optional[str] = None):
        self.api_key = api_key or settings.AI_API_KEY
        self.model = model or "llama-3.1-70b-versatile"

    async def analyze(self, transcript: str, metadata: Dict[str, Any]) -> AnalysisResult:
        if not self.api_key:
            raise AnalysisError("Groq API key is not configured.")

        url = "https://api.groq.com/openai/v1/chat/completions"
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": ANALYSIS_SYSTEM_PROMPT},
                {"role": "user", "content": f"Metadata: {metadata.get('description', '')}\n\nTranscript:\n{transcript}"}
            ],
            "response_format": {"type": "json_object"},
            "temperature": 0.2
        }

        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(url, headers=headers, json=payload)
            if response.status_code != 200:
                raise AnalysisError(f"Groq API returned {response.status_code}: {response.text}")
            content = response.json()["choices"][0]["message"]["content"]
            parsed = json.loads(content)
            return {
                "title": parsed.get("title", "Saved Reel"),
                "topic": parsed.get("topic", "General"),
                "summary": parsed.get("summary", ""),
                "hook": parsed.get("hook", ""),
                "content_structure": parsed.get("content_structure", []),
                "tags": parsed.get("tags", []),
                "cleaned_transcript": parsed.get("cleaned_transcript", transcript),
            }


class OllamaAnalysisProvider(AnalysisProvider):
    """Local Ollama Provider (100% offline & zero cost)."""

    def __init__(self, base_url: Optional[str] = None, model: Optional[str] = None):
        self.base_url = (base_url or settings.OLLAMA_BASE_URL).rstrip("/")
        self.model = model or "llama3.1:8b"

    async def analyze(self, transcript: str, metadata: Dict[str, Any]) -> AnalysisResult:
        url = f"{self.base_url}/api/chat"
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": ANALYSIS_SYSTEM_PROMPT},
                {"role": "user", "content": f"Metadata: {metadata.get('description', '')}\n\nTranscript:\n{transcript}"}
            ],
            "format": "json",
            "stream": False,
            "options": {"temperature": 0.2}
        }

        async with httpx.AsyncClient(timeout=90.0) as client:
            response = await client.post(url, json=payload)
            if response.status_code != 200:
                raise AnalysisError(f"Ollama returned {response.status_code}: {response.text}")
            content = response.json()["message"]["content"]
            parsed = json.loads(content)
            return {
                "title": parsed.get("title", "Saved Reel"),
                "topic": parsed.get("topic", "General"),
                "summary": parsed.get("summary", ""),
                "hook": parsed.get("hook", ""),
                "content_structure": parsed.get("content_structure", []),
                "tags": parsed.get("tags", []),
                "cleaned_transcript": parsed.get("cleaned_transcript", transcript),
            }


class FallbackHeuristicProvider(AnalysisProvider):
    """
    Rule-based analyzer when no external AI API key is configured.
    Ensures the user can still use ReelVault completely offline or without API keys.
    """

    async def analyze(self, transcript: str, metadata: Dict[str, Any]) -> AnalysisResult:
        # Extract first sentence as hook
        sentences = re.split(r"(?<=[.!?])\s+", transcript.strip())
        hook = sentences[0] if sentences else ""
        title = metadata.get("title") or (sentences[0][:60] + "..." if len(sentences[0]) > 60 else sentences[0])
        summary = " ".join(sentences[:3]) if len(sentences) >= 3 else transcript[:200]

        # Extract basic tags from metadata or common keywords
        words = re.findall(r"\b[A-Za-z]{4,}\b", transcript.lower())
        tags = list(dict.fromkeys([w.capitalize() for w in words[:6]]))

        return {
            "title": title or "Saved Reel",
            "topic": "General Research",
            "summary": summary,
            "hook": hook,
            "content_structure": [
                {"type": "hook", "description": hook[:80]},
                {"type": "body", "description": "Core discussion in Reel"}
            ],
            "tags": tags,
            "cleaned_transcript": transcript
        }


def get_analysis_provider() -> AnalysisProvider:
    """Factory to retrieve configured analysis provider."""
    provider = settings.AI_PROVIDER.lower()
    if provider == "gemini" and settings.AI_API_KEY:
        return GeminiAnalysisProvider()
    elif provider == "groq" and settings.AI_API_KEY:
        return GroqAnalysisProvider()
    elif provider == "ollama":
        return OllamaAnalysisProvider()
    else:
        logger.info("Using FallbackHeuristicProvider (no external LLM key required).")
        return FallbackHeuristicProvider()
