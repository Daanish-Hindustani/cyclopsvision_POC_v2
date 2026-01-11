"""
CyclopsVision Backend - AI Service using Ollama
Handles video analysis, step extraction, and teacher config generation
"""
import os
import json
import httpx
from typing import List, Optional

from models.lesson import TeacherConfig, Step, MistakePattern


class OllamaService:
    """Ollama AI service for video analysis and step extraction"""
    
    def __init__(self):
        self.host = os.getenv("OLLAMA_HOST", "http://localhost:11434")
        self.model = os.getenv("OLLAMA_MODEL", "llava:7b")
        self.timeout = 120.0  # Vision models can be slow
    
    async def analyze_video_for_steps(
        self, 
        frames_base64: List[str],
        lesson_title: str = "",
        audio_transcript: str = "",
        video_duration: float = 0.0
    ) -> TeacherConfig:
        """
        Analyze video frames to extract procedural steps
        
        Args:
            frames_base64: List of base64-encoded frame images
            lesson_title: Optional title hint for context
            audio_transcript: Optional audio transcript
            video_duration: Duration of the video in seconds
            
        Returns:
            TeacherConfig with extracted steps
        """
        # Build the prompt
        prompt = self._build_step_extraction_prompt(lesson_title, audio_transcript, video_duration)
        
        # Send to Ollama with images
        response_text = await self._generate_with_images(prompt, frames_base64)
        
        # Parse the response
        return self._parse_teacher_config(response_text, lesson_title, video_duration)
    
    async def _generate_with_images(self, prompt: str, images_base64: List[str]) -> str:
        """Send prompt with images to Ollama API"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.host}/api/generate",
                json={
                    "model": self.model,
                    "prompt": prompt,
                    "images": images_base64,
                    "stream": False,
                    "options": {
                        "temperature": 0.2,
                        "num_predict": 8192,
                    }
                }
            )
            response.raise_for_status()
            data = response.json()
            return data.get("response", "")
    
    async def _generate_text(self, prompt: str) -> str:
        """Send text-only prompt to Ollama API"""
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.host}/api/generate",
                json={
                    "model": self.model,
                    "prompt": prompt,
                    "stream": False,
                    "options": {
                        "temperature": 0.3,
                        "num_predict": 1024,
                    }
                }
            )
            response.raise_for_status()
            data = response.json()
            return data.get("response", "")
    
    def _build_step_extraction_prompt(self, title: str, transcript: str, video_duration: float = 0.0) -> str:
        """Build the prompt for step extraction"""
        duration_hint = f"\nVideo duration: {video_duration:.1f} seconds. Distribute steps across the full video." if video_duration > 0 else ""
        
        return f"""You are an expert instructor analyzing a training video. Extract DETAILED procedural steps from these video frames.

{"Title: " + title if title else ""}
{"Transcript: " + transcript if transcript else ""}{duration_hint}

The frames shown are evenly distributed across the video timeline.

For each step, provide:
- A clear title (2-5 words)
- A VERY DETAILED description (3-5 sentences) explaining exactly what to do, how to position hands, angles, techniques, what the result should look like, and tips for success
- Objects involved
- The motion type
- start_time and end_time in seconds (estimate based on frame positions)

Respond with ONLY valid JSON:
{{
  "steps": [
    {{
      "step_id": 1,
      "title": "Step Title Here",
      "description": "Very detailed description with hand positions, angles, techniques, expected result, and tips.",
      "expected_objects": ["object1", "object2"],
      "expected_motion": "motion_type",
      "start_time": 0.0,
      "end_time": 10.0
    }}
  ]
}}

Motion types: positioning, rotation_clockwise, rotation_counterclockwise, pressing, pulling, folding, cutting, connecting, holding, releasing.

Extract 3-10 detailed steps with accurate timestamps. Steps should cover the entire video duration. Output only JSON.
"""
    
    def _parse_teacher_config(self, response_text: str, lesson_id: str, video_duration: float = 0.0) -> TeacherConfig:
        """Parse Ollama's response into a TeacherConfig"""
        try:
            # Extract JSON from response (handle markdown code blocks)
            json_str = response_text
            if "```json" in json_str:
                json_str = json_str.split("```json")[1].split("```")[0]
            elif "```" in json_str:
                json_str = json_str.split("```")[1].split("```")[0]
            
            # Try to parse, then try to repair truncated JSON
            json_str = json_str.strip()
            try:
                data = json.loads(json_str)
            except json.JSONDecodeError:
                # Try to repair truncated JSON by finding complete steps
                data = self._repair_truncated_json(json_str)
            
            steps = []
            num_steps = len(data.get("steps", []))
            
            for i, step_data in enumerate(data.get("steps", [])):
                mistake_patterns = [
                    MistakePattern(**mp) for mp in step_data.get("mistake_patterns", [])
                ]
                
                # Get timestamps from AI or calculate fallback
                start_time = step_data.get("start_time", 0.0)
                end_time = step_data.get("end_time", 0.0)
                
                # If no valid timestamps, distribute evenly across video
                if end_time <= start_time and video_duration > 0 and num_steps > 0:
                    step_duration = video_duration / num_steps
                    start_time = i * step_duration
                    end_time = (i + 1) * step_duration
                
                steps.append(Step(
                    step_id=step_data.get("step_id", len(steps) + 1),
                    title=step_data.get("title", f"Step {len(steps) + 1}"),
                    description=step_data.get("description", ""),
                    expected_objects=step_data.get("expected_objects", []),
                    expected_motion=step_data.get("expected_motion", ""),
                    expected_duration_seconds=step_data.get("expected_duration_seconds", int(end_time - start_time) or 10),
                    mistake_patterns=mistake_patterns,
                    correction_mode="diagram_overlay_audio",
                    start_time=start_time,
                    end_time=end_time
                ))
            
            if steps:
                return TeacherConfig(
                    lesson_id=lesson_id,
                    total_steps=len(steps),
                    steps=steps
                )
            raise ValueError("No steps parsed")
            
        except json.JSONDecodeError as e:
            print(f"Failed to parse Ollama response: {e}")
            print(f"Response was: {response_text[:500]}")
            # Return a basic config if parsing fails
            return TeacherConfig(
                lesson_id=lesson_id,
                total_steps=1,
                steps=[Step(
                    step_id=1,
                    title="Procedure",
                    description="Follow the demonstration",
                    expected_objects=[],
                    expected_motion="",
                    expected_duration_seconds=30,
                    mistake_patterns=[]
                )]
            )
    
    def _repair_truncated_json(self, json_str: str) -> dict:
        """Try to extract complete step objects from truncated JSON"""
        import re
        
        # Find all complete step objects using regex
        # Look for patterns like {"step_id": N, ... }
        step_pattern = r'\{\s*"step_id"\s*:\s*\d+[^{}]*(?:\{[^{}]*\}[^{}]*)*\}'
        matches = re.findall(step_pattern, json_str, re.DOTALL)
        
        steps = []
        for match in matches:
            try:
                step_obj = json.loads(match)
                if "step_id" in step_obj:
                    steps.append(step_obj)
            except json.JSONDecodeError:
                continue
        
        if steps:
            print(f"Repaired truncated JSON: extracted {len(steps)} complete steps")
            return {"steps": steps}
        
        raise json.JSONDecodeError("Could not repair JSON", json_str, 0)
    
    async def generate_correction_overlay(
        self,
        step: Step,
        mistake_type: str,
        frame_base64: Optional[str] = None
    ) -> dict:
        """
        Generate diagram overlay instructions for a detected mistake
        
        Args:
            step: Current step configuration
            mistake_type: Type of mistake detected
            frame_base64: Optional frame showing the mistake
            
        Returns:
            OverlayInstruction dict
        """
        prompt = f"""You are an expert at creating visual instructional overlays for AR training systems.

The user is on this step: "{step.title}"
Description: {step.description}
Expected objects: {', '.join(step.expected_objects)}
Expected motion: {step.expected_motion}

They made this mistake: "{mistake_type}"

Generate a helpful diagram-style overlay to correct them. The overlay should look like a technical instruction manual, NOT like raw bounding boxes.

Respond with ONLY valid JSON:
{{
    "audio_text": "Clear, concise verbal instruction (1-2 sentences)",
    "elements": [
        {{
            "type": "circle",
            "center": [0.5, 0.5],
            "radius": 0.1,
            "color": "#FFD700",
            "stroke_width": 3,
            "style": "solid"
        }},
        {{
            "type": "arrow",
            "from": [0.3, 0.6],
            "to": [0.5, 0.4],
            "color": "#FF4444",
            "stroke_width": 3,
            "style": "curved"
        }},
        {{
            "type": "label",
            "position": [0.5, 0.2],
            "text": "Brief instruction",
            "font_size": 16,
            "color": "#FFFFFF",
            "background": "#000000AA"
        }}
    ]
}}

Guidelines:
- Use normalized coordinates (0.0 to 1.0) where (0,0) is top-left
- Use yellow (#FFD700) for highlighting targets
- Use red (#FF4444) for arrows showing direction
- Use green (#00FF00) for correct positions
- Keep labels short and actionable
- Place elements where they would logically appear based on the task
- Use 2-4 elements maximum for clarity
"""
        
        # Use vision if frame is provided, otherwise text-only
        if frame_base64:
            response_text = await self._generate_with_images(prompt, [frame_base64])
        else:
            response_text = await self._generate_text(prompt)
        
        return self._parse_overlay_response(response_text)
    
    def _parse_overlay_response(self, response_text: str) -> dict:
        """Parse overlay generation response"""
        try:
            json_str = response_text
            if "```json" in json_str:
                json_str = json_str.split("```json")[1].split("```")[0]
            elif "```" in json_str:
                json_str = json_str.split("```")[1].split("```")[0]
            
            data = json.loads(json_str.strip())
            
            return {
                "overlay_type": "diagram",
                "audio_text": data.get("audio_text", "Please adjust your technique."),
                "elements": data.get("elements", []),
                "duration_seconds": 5.0
            }
            
        except json.JSONDecodeError as e:
            print(f"Failed to parse overlay response: {e}")
            return {
                "overlay_type": "diagram",
                "audio_text": "Please check your technique and try again.",
                "elements": [
                    {
                        "type": "label",
                        "position": [0.5, 0.1],
                        "text": "Check your technique",
                        "font_size": 18,
                        "color": "#FFFFFF",
                        "background": "#FF4444CC"
                    }
                ],
                "duration_seconds": 5.0
            }


# Singleton instance
_ollama_service = None

def get_gemini_service() -> OllamaService:
    """Get or create the Ollama service singleton (kept as get_gemini_service for compatibility)"""
    global _ollama_service
    if _ollama_service is None:
        _ollama_service = OllamaService()
    return _ollama_service

# Alias for clarity
get_ollama_service = get_gemini_service
