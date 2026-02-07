"""
CyclopsVision Backend - TTS Service
Handles text-to-speech generation using OpenAI or local Kokoro
"""
import os
from abc import ABC, abstractmethod
import asyncio

class TTSService(ABC):
    """Abstract base class for TTS services"""
    
    @abstractmethod
    async def generate_audio(self, text: str, output_path: str):
        """Generate audio from text and save to output_path"""
        pass

class OpenAITTSService(TTSService):
    """OpenAI TTS implementation"""
    
    def __init__(self):
        import openai
        self.api_key = os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY environment variable is required")
        self.client = openai.AsyncOpenAI(api_key=self.api_key)
        
    async def generate_audio(self, text: str, output_path: str):
        response = await self.client.audio.speech.create(
            model="tts-1",
            voice="alloy",
            input=text
        )
        response.stream_to_file(output_path)

def get_tts_service() -> TTSService:
    """Factory to get the configured TTS service"""
    # Currently only OpenAI is supported
    print("[TTS Factory] Using OpenAI (Cloud)")
    return OpenAITTSService()
