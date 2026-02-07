"""
Text-to-Speech Router using OpenAI TTS
"""
from fastapi import APIRouter, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel
import openai
import os

router = APIRouter(prefix="/tts", tags=["tts"])

# Initialize OpenAI client
client = openai.OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


class TTSRequest(BaseModel):
    text: str
    voice: str = "nova"  # Options: alloy, echo, fable, onyx, nova, shimmer


@router.post("/speak")
async def text_to_speech(request: TTSRequest):
    """
    Convert text to natural speech using OpenAI TTS.
    Returns MP3 audio data.
    """
    if not request.text:
        raise HTTPException(status_code=400, detail="Text is required")
    
    try:
        response = client.audio.speech.create(
            model="tts-1",  # tts-1 is faster, tts-1-hd is higher quality
            voice=request.voice,
            input=request.text,
            response_format="mp3"
        )
        
        # Get audio bytes
        audio_data = response.content
        
        return Response(
            content=audio_data,
            media_type="audio/mpeg",
            headers={"Content-Disposition": "inline; filename=speech.mp3"}
        )
        
    except Exception as e:
        print(f"TTS Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
