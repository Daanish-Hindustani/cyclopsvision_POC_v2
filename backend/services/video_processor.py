"""
CyclopsVision Backend - Video Processing Service
Handles video upload, frame extraction, and audio extraction
"""
import os
import uuid
import base64
import tempfile
from pathlib import Path
from typing import List, Tuple, Optional
import asyncio

# We'll use moviepy for video processing
# MoviePy 2.x changed the import path (removed moviepy.editor)
try:
    from moviepy import VideoFileClip
    MOVIEPY_AVAILABLE = True
except ImportError:
    try:
        # Fallback for moviepy 1.x
        from moviepy.editor import VideoFileClip
        MOVIEPY_AVAILABLE = True
    except ImportError:
        MOVIEPY_AVAILABLE = False
        print("Warning: moviepy not available, video processing will be limited")

from PIL import Image
import io


class VideoProcessor:
    """Handles video file operations for lesson creation"""
    
    def __init__(self, storage_path: str = "storage/videos"):
        self.storage_path = Path(storage_path)
        self.storage_path.mkdir(parents=True, exist_ok=True)
    
    async def save_video(self, file_content: bytes, filename: str) -> str:
        """
        Save uploaded video file and return the path
        
        Args:
            file_content: Raw video bytes
            filename: Original filename
            
        Returns:
            Path to saved video file
        """
        # Generate unique filename
        ext = Path(filename).suffix or ".mp4"
        unique_name = f"{uuid.uuid4()}{ext}"
        file_path = self.storage_path / unique_name
        
        # Save asynchronously
        loop = asyncio.get_event_loop()
        await loop.run_in_executor(None, self._write_file, file_path, file_content)
        
        return str(file_path)
    
    def _write_file(self, path: Path, content: bytes):
        """Synchronous file write helper"""
        with open(path, "wb") as f:
            f.write(content)
    
    def extract_frames(
        self, 
        video_path: str, 
        num_frames: int = 10,
        max_size: Tuple[int, int] = (512, 512)
    ) -> List[str]:
        """
        Extract evenly-spaced frames from video as base64 strings
        
        Args:
            video_path: Path to video file
            num_frames: Number of frames to extract
            max_size: Maximum frame dimensions (for API efficiency)
            
        Returns:
            List of base64-encoded JPEG images
        """
        if not MOVIEPY_AVAILABLE:
            return []
        
        frames_base64 = []
        
        try:
            clip = VideoFileClip(video_path)
            duration = clip.duration
            
            # Calculate frame timestamps
            timestamps = [duration * i / (num_frames - 1) for i in range(num_frames)]
            
            for ts in timestamps:
                # Get frame at timestamp
                frame = clip.get_frame(ts)
                
                # Convert to PIL Image
                img = Image.fromarray(frame)
                
                # Resize maintaining aspect ratio
                img.thumbnail(max_size, Image.Resampling.LANCZOS)
                
                # Convert to base64
                buffer = io.BytesIO()
                img.save(buffer, format="JPEG", quality=85)
                b64 = base64.b64encode(buffer.getvalue()).decode("utf-8")
                frames_base64.append(b64)
            
            clip.close()
            
        except Exception as e:
            print(f"Error extracting frames: {e}")
        
        return frames_base64
    
    def extract_audio(self, video_path: str) -> Optional[str]:
        """
        Extract audio from video as temporary WAV file
        
        Args:
            video_path: Path to video file
            
        Returns:
            Path to extracted audio file, or None if extraction fails
        """
        if not MOVIEPY_AVAILABLE:
            return None
        
        try:
            clip = VideoFileClip(video_path)
            
            if clip.audio is None:
                clip.close()
                return None
            
            # Create temp file for audio
            audio_path = tempfile.mktemp(suffix=".wav")
            clip.audio.write_audiofile(audio_path, logger=None)
            clip.close()
            
            return audio_path
            
        except Exception as e:
            print(f"Error extracting audio: {e}")
            return None
    
    def get_video_info(self, video_path: str) -> dict:
        """
        Get video metadata
        
        Returns:
            Dict with duration, fps, resolution
        """
        if not MOVIEPY_AVAILABLE:
            return {"duration": 0, "fps": 0, "width": 0, "height": 0}
        
        try:
            clip = VideoFileClip(video_path)
            info = {
                "duration": clip.duration,
                "fps": clip.fps,
                "width": clip.size[0],
                "height": clip.size[1]
            }
            clip.close()
            return info
        except Exception as e:
            print(f"Error getting video info: {e}")
            return {"duration": 0, "fps": 0, "width": 0, "height": 0}
    
    def extract_clip(
        self,
        video_path: str,
        start_time: float,
        end_time: float,
        output_filename: str
    ) -> Optional[str]:
        """
        Extract a clip from a video between start and end times
        
        Args:
            video_path: Path to source video
            start_time: Start time in seconds
            end_time: End time in seconds  
            output_filename: Name for the output clip file
            
        Returns:
            Path to extracted clip, or None if extraction fails
        """
        if not MOVIEPY_AVAILABLE:
            return None
        
        # Create clips directory
        clips_path = Path("storage/clips")
        clips_path.mkdir(parents=True, exist_ok=True)
        
        output_path = clips_path / output_filename
        
        try:
            clip = VideoFileClip(video_path)
            
            # Ensure times are within bounds
            start_time = max(0, min(start_time, clip.duration))
            end_time = max(start_time + 0.5, min(end_time, clip.duration))
            
            # Extract subclip
            subclip = clip.subclipped(start_time, end_time)
            
            # Write to file (lower quality for smaller file size)
            subclip.write_videofile(
                str(output_path),
                codec="libx264",
                audio_codec="aac",
                bitrate="1000k",
                logger=None
            )
            
            subclip.close()
            clip.close()
            
            return str(output_path)
            
        except Exception as e:
            print(f"Error extracting clip: {e}")
            return None


# Singleton instance
video_processor = VideoProcessor()
