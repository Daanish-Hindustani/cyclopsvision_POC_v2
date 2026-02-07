"""
CyclopsVision Backend - AI Video Analysis Service
Supports multiple providers for whole-video processing with step extraction
"""
import os
import json
import time
import base64
import httpx
from abc import ABC, abstractmethod
from typing import Optional

from models.lesson import TeacherConfig, Step

# Build shared prompt for video analysis
def build_video_analysis_prompt(title: str = "") -> str:
    """Build the prompt for whole-video step extraction"""
    return f"""You are an expert instructor analyzing a procedural/tutorial video.

{f"Title: {title}" if title else ""}

=== TASK ===

Analyze this video and extract procedural steps with EXACT timestamps.

=== RULES ===

1. SKIP intro content: title screens, logos, setup frames, hands positioning before action starts
2. Each step must show ONE distinct action
3. Provide EXACT start/end times in seconds (e.g., 2.5, not frame numbers)
4. Steps should be granular - one action per step

=== DESCRIPTION FORMAT ===

Each description MUST include:
- BEFORE: What you see at the START of this action
- ACTION: The SINGLE specific movement happening
- AFTER: What it looks like when done correctly
- FAILURE: What wrong execution looks like

=== JSON OUTPUT ===

{{
  "steps": [
    {{
      "step_id": 1,
      "title": "Short action title",
      "description": "BEFORE: [state]. ACTION: [movement]. AFTER: [result]. FAILURE: [what's wrong].",
      "start_time": 2.5,
      "end_time": 5.0,
      "expected_objects": ["object1", "object2"],
      "expected_motion": "motion_type"
    }}
  ]
}}

Motion types: positioning, rotation_clockwise, rotation_counterclockwise, pressing, pulling, folding, cutting, connecting, holding, releasing.

Output ONLY valid JSON, no other text.
"""


class AIVideoService(ABC):
    """Abstract base class for video analysis services"""
    
    @abstractmethod
    async def analyze_video(self, video_path: str, title: str = "") -> TeacherConfig:
        """
        Analyze a video and extract procedural steps with timestamps.
        
        Args:
            video_path: Path to the video file
            title: Optional lesson title for context
            
        Returns:
            TeacherConfig with extracted steps
        """
        pass
    
    def _parse_response(self, response_text: str, lesson_id: str = "") -> TeacherConfig:
        """Parse AI response into TeacherConfig"""
        try:
            # Clean up response
            text = response_text.strip()
            
            # Remove markdown code blocks if present
            if text.startswith("```"):
                lines = text.split("\n")
                text = "\n".join(lines[1:-1] if lines[-1] == "```" else lines[1:])
            
            data = json.loads(text)
            steps_data = data.get("steps", [])
            
            steps = []
            for s in steps_data:
                step = Step(
                    step_id=s.get("step_id", len(steps) + 1),
                    title=s.get("title", "Untitled Step"),
                    description=s.get("description", ""),
                    expected_objects=s.get("expected_objects", []),
                    expected_motion=s.get("expected_motion", ""),
                    start_time=float(s.get("start_time", 0)),
                    end_time=float(s.get("end_time", 0))
                )
                steps.append(step)
            
            return TeacherConfig(
                lesson_id=lesson_id,
                total_steps=len(steps),
                steps=steps
            )
            
        except Exception as e:
            print(f"Error parsing AI response: {e}")
            print(f"Response was: {response_text[:500]}")
            return TeacherConfig(lesson_id=lesson_id, total_steps=0, steps=[])


    @abstractmethod
    async def analyze_frame(self, frame_base64: str, prompt: str) -> str:
        """Analyze a single frame"""
        pass

    @abstractmethod
    async def generate_correction_overlay(self, step: Step, mistake_type: str, frame_base64: Optional[str] = None) -> dict:
        """Generate overlay instructions for a mistake"""
        pass
    
    def _parse_overlay_response(self, response_text: str) -> dict:
        """Parse overlay response into dict"""
        try:
            text = response_text.strip()
            if text.startswith("```"):
                lines = text.split("\n")
                text = "\n".join(lines[1:-1] if lines[-1] == "```" else lines[1:])
            return json.loads(text)
        except:
            return {
                "overlay_type": "diagram",
                "audio_text": "Please adjust your technique.",
                "elements": []
            }



class OllamaVideoService(AIVideoService):
    """Ollama - processes video frames using local/remote Ollama instance"""
    
    def __init__(self):
        self.base_url = os.getenv("OLLAMA_BASE_URL", "http://localhost:11434/v1")
        self.model = os.getenv("OLLAMA_MODEL", "llama3.2-vision")
        self.api_key = "ollama" # Dummy key required by client
            
        import openai
        print(f"[Ollama] Initializing client at {self.base_url} with model {self.model}")
        self.client = openai.AsyncOpenAI(
            base_url=self.base_url,
            api_key=self.api_key
        )
    
    async def analyze_video(self, video_path: str, title: str = "") -> TeacherConfig:
        """Extract frames and send to Ollama for analysis"""
        from services.video_processor import video_processor
        
        print(f"[Ollama] Analyzing video: {video_path}")
        
        # Open video and extract frames
        video_info = video_processor.get_video_info(video_path)
        duration = video_info.get("duration", 0)
        
        # Extract fewer frames for local models to prevent context overflow/timeout
        num_frames = 10 
        frames_base64 = video_processor.extract_frames(
            video_path, 
            num_frames=num_frames,
            max_size=(512, 512)
        )
        
        if not frames_base64:
            raise Exception("Failed to extract frames from video")
            
        # Build prompt with timestamps
        frame_interval = duration / (num_frames - 1) if duration > 0 and num_frames > 1 else 0
        frame_times = [f"Frame {i+1} = {frame_interval * i:.1f}s" for i in range(len(frames_base64))]
        
        system_prompt = build_video_analysis_prompt(title)
        
        # Add frame timestamp info to the user prompt
        user_content = [
            {"type": "text", "text": f"Video duration: {duration:.1f}s. Frame timestamps:\n" + "\n".join(frame_times)}
        ]
        
        # Add images
        for b64 in frames_base64:
            user_content.append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{b64}",
                    "detail": "low"
                }
            })
            
        try:
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_content}
                ],
                response_format={"type": "json_object"},
                temperature=0.2
            )
            
            content = response.choices[0].message.content
            return self._parse_response(content)
        except Exception as e:
            print(f"[Ollama] Error during analysis: {e}")
            raise

    async def generate_correction_overlay(self, step: Step, mistake_type: str, frame_base64: Optional[str] = None) -> dict:
        """Generate diagram overlay instructions for a detected mistake using Ollama"""
        print(f"[Ollama] Generating correction for mistake: {mistake_type}")
        
        prompt = f"""You are an expert AI tutor. A learner made a mistake executing this step:
Title: {step.title}
Description: {step.description}
Mistake Detected: {mistake_type}

Generate a visual overlay and audio feedback to fix this.

OUTPUT SPECIFICATION:
JSON with:
1. "overlay_type": "diagram" or "highlight"
2. "audio_text": concise spoken correction (max 1 sentence)
3. "elements": list of visual elements to draw on screen
   - type: "arrow", "circle", "text", "path"
   - color: hex code (red for wrong, green for correction)
   - points: [[x1,y1], [x2,y2]] (0-1 normalized coordinates)
"""
        messages = [
            {"role": "system", "content": "You are a helpful AI tutor. Output JSON only."},
            {"role": "user", "content": [{"type": "text", "text": prompt}]}
        ]
        
        if frame_base64:
            messages[1]["content"].append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{frame_base64}",
                    "detail": "low"
                }
            })
            
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            response_format={"type": "json_object"}
        )
        
        return self._parse_overlay_response(response.choices[0].message.content)
    
    async def analyze_frame(self, frame_base64: str, prompt: str) -> str:
        """Analyze single frame with Ollama"""
        messages = [
            {"role": "system", "content": "You are a helpful AI assistant."},
            {"role": "user", "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{frame_base64}", "detail": "low"}}
            ]}
        ]
        
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            max_tokens=500
        )
        return response.choices[0].message.content


class OpenAIVideoService(AIVideoService):
    """OpenAI GPT-4o - processes video frames"""
    
    def __init__(self):
        self.api_key = os.getenv("OPENAI_API_KEY")
        if not self.api_key:
            raise ValueError("OPENAI_API_KEY environment variable is required")
            
        import openai
        self.client = openai.AsyncOpenAI(api_key=self.api_key)
        self.model = "gpt-4o"
    
    async def analyze_video(self, video_path: str, title: str = "") -> TeacherConfig:
        """Extract frames and send to GPT-4o for analysis"""
        from services.video_processor import video_processor
        
        print(f"[OpenAI] Analyzing video: {video_path}")
        
        # Open video and extract frames
        # GPT-4o works best with a sequence of frames
        video_info = video_processor.get_video_info(video_path)
        duration = video_info.get("duration", 0)
        
        # Extract 20 frames (good balance for OpenAI)
        num_frames = 20
        frames_base64 = video_processor.extract_frames(
            video_path, 
            num_frames=num_frames,
            max_size=(512, 512)
        )
        
        if not frames_base64:
            raise Exception("Failed to extract frames from video")
            
        # Build prompt with timestamps
        frame_interval = duration / (num_frames - 1) if duration > 0 and num_frames > 1 else 0
        frame_times = [f"Frame {i+1} = {frame_interval * i:.1f}s" for i in range(len(frames_base64))]
        
        system_prompt = build_video_analysis_prompt(title)
        
        # Add frame timestamp info to the user prompt
        user_content = [
            {"type": "text", "text": f"Video duration: {duration:.1f}s. Frame timestamps:\n" + "\n".join(frame_times)}
        ]
        
        # Add images
        for b64 in frames_base64:
            user_content.append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{b64}",
                    "detail": "low" # low detail is cheaper and usually sufficient for simple steps
                }
            })
            
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_content}
            ],
            response_format={"type": "json_object"},
            temperature=0.2
        )
        
        content = response.choices[0].message.content
        return self._parse_response(content)

    async def generate_correction_overlay(self, step: Step, mistake_type: str, frame_base64: Optional[str] = None) -> dict:
        """Generate diagram overlay instructions for a detected mistake using GPT-4o"""
        print(f"[OpenAI] Generating correction for mistake: {mistake_type}")
        
        prompt = f"""You are an expert AI tutor. A learner made a mistake executing this step:
Title: {step.title}
Description: {step.description}
Mistake Detected: {mistake_type}

Generate a visual overlay and audio feedback to fix this.

OUTPUT SPECIFICATION:
JSON with:
1. "overlay_type": "diagram" or "highlight"
2. "audio_text": concise spoken correction (max 1 sentence)
3. "elements": list of visual elements to draw on screen
   - type: "arrow", "circle", "text", "path"
   - color: hex code (red for wrong, green for correction)
   - points: [[x1,y1], [x2,y2]] (0-1 normalized coordinates)
"""
        messages = [
            {"role": "system", "content": "You are a helpful AI tutor. Output JSON only."},
            {"role": "user", "content": [{"type": "text", "text": prompt}]}
        ]
        
        if frame_base64:
            messages[1]["content"].append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{frame_base64}",
                    "detail": "low"
                }
            })
            
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            response_format={"type": "json_object"}
        )
        
        return self._parse_overlay_response(response.choices[0].message.content)
    
    async def analyze_frame(self, frame_base64: str, prompt: str) -> str:
        """Analyze single frame with OpenAI GPT-4o"""
        messages = [
            {"role": "system", "content": "You are a helpful AI assistant."},
            {"role": "user", "content": [
                {"type": "text", "text": prompt},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{frame_base64}"}}
            ]}
        ]
        
        response = await self.client.chat.completions.create(
            model=self.model,
            messages=messages,
            max_tokens=500
        )
        return response.choices[0].message.content


# Factory function to get appropriate service
def get_ai_video_service() -> AIVideoService:
    """Get AI video service based on AI_PROVIDER env variable"""
    provider = os.getenv("AI_PROVIDER", "ollama").lower()
    
    if provider == "openai":
        print("[AI Service] Using OpenAI provider")
        return OpenAIVideoService()
    else:
        print("[AI Service] Using Ollama provider")
        return OllamaVideoService()


# Backwards compatibility alias
def get_gemini_service():
    """Backwards compatible - returns video service"""
    return get_ai_video_service()

