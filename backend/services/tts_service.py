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

class KokoroTTSService(TTSService):
    """Local Kokoro-TTS implementation"""
    
    def __init__(self):
        print("[Kokoro] Initializing local TTS...")
        try:
            from kokoro import KPipeline
            import soundfile as sf
            self.sf = sf
            # Initialize pipeline for US English
            # This triggers model download on first run (~300MB)
            self.pipeline = KPipeline(lang_code='a') 
            print("[Kokoro] Initialization complete")
        except ImportError:
            print("[Kokoro] Failed to import kokoro or soundfile. Please install dependencies.")
            raise

    async def generate_audio(self, text: str, output_path: str):
        print(f"[Kokoro] Generating audio for: {text[:30]}...")
        
        # Run generation in thread pool to avoid blocking async loop
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._generate_sync, text, output_path)
        
    def _generate_sync(self, text: str, output_path: str):
        # Generate audio
        # 4004 is a good voice (American female), speed 1.0
        generator = self.pipeline(
            text, 
            voice='af_sarah', # 'af_sarah' is a high quality voice
            speed=1.0, 
            split_pattern=r'\n+'
        )
        
        # Kokoro returns a generator of (graphemes, phonemes, audio)
        # We need to concatenate all audio chunks
        all_audio = []
        for _, _, audio in generator:
            all_audio.extend(audio)
            
        # Save to file using soundfile
        # Kokoro defaults to 24000 sample rate
        self.sf.write(output_path, all_audio, 24000)

def get_tts_service() -> TTSService:
    """Factory to get the configured TTS service"""
    provider = os.getenv("TTS_PROVIDER", "openai").lower()
    
    if provider == "kokoro":
        print("[TTS Factory] Using Kokoro (Local)")
        return KokoroTTSService()
    else:
        print("[TTS Factory] Using OpenAI (Cloud)")
        return OpenAITTSService()
