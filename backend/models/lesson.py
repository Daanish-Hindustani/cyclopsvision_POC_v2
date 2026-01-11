"""
CyclopsVision Backend - Pydantic Models for Lessons
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
import uuid


class MistakePattern(BaseModel):
    """Defines a common mistake pattern for a step"""
    type: str = Field(..., description="Mistake type identifier")
    description: str = Field(..., description="Human-readable description")


class Step(BaseModel):
    """Individual procedural step within a lesson"""
    step_id: int = Field(..., description="Sequential step number")
    title: str = Field(..., description="Short step title")
    description: str = Field(..., description="Detailed step description")
    expected_objects: List[str] = Field(default_factory=list, description="Objects expected to be visible")
    expected_motion: str = Field(default="", description="Expected motion type")
    expected_duration_seconds: int = Field(default=10, description="Expected time to complete")
    mistake_patterns: List[MistakePattern] = Field(default_factory=list, description="Common mistakes")
    correction_mode: str = Field(default="diagram_overlay_audio", description="How to correct mistakes")
    # Video snippet fields
    start_time: float = Field(default=0.0, description="Start time in source video (seconds)")
    end_time: float = Field(default=0.0, description="End time in source video (seconds)")
    clip_url: Optional[str] = Field(default=None, description="URL to extracted video clip")


class TeacherConfig(BaseModel):
    """AI Teacher configuration generated from demo video"""
    lesson_id: str = Field(..., description="Associated lesson ID")
    total_steps: int = Field(..., description="Total number of steps")
    steps: List[Step] = Field(default_factory=list, description="List of procedural steps")


class Lesson(BaseModel):
    """Complete lesson model"""
    id: str = Field(default_factory=lambda: str(uuid.uuid4()), description="Unique lesson ID")
    title: str = Field(..., description="Lesson title")
    demo_video_url: str = Field(..., description="Path to demo video file")
    ai_teacher_config: Optional[TeacherConfig] = Field(None, description="Generated AI teacher config")
    created_at: datetime = Field(default_factory=datetime.utcnow, description="Creation timestamp")

    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class LessonCreate(BaseModel):
    """Request model for creating a lesson"""
    title: str = Field(default="Untitled Lesson", description="Lesson title")


class LessonResponse(BaseModel):
    """Response model for lesson endpoints"""
    id: str
    title: str
    demo_video_url: str
    ai_teacher_config: Optional[TeacherConfig]
    created_at: str
