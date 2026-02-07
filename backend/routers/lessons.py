"""
CyclopsVision Backend - Lessons Router
Handles lesson creation and retrieval endpoints
"""
from fastapi import APIRouter, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.responses import JSONResponse, FileResponse
from typing import List, Optional
from pathlib import Path
import uuid

from models import Lesson, LessonCreate, LessonResponse, TeacherConfig
from services import video_processor, get_ai_video_service, lesson_storage

router = APIRouter(prefix="/lessons", tags=["lessons"])


def extract_step_clips(lesson_id: str, video_path: str, steps: list):
    """Extract video clips for each step in the background"""
    for step in steps:
        if step.start_time >= 0 and step.end_time > step.start_time:
            clip_filename = f"{lesson_id}_step_{step.step_id}.mp4"
            clip_path = video_processor.extract_clip(
                video_path,
                step.start_time,
                step.end_time,
                clip_filename
            )
            if clip_path:
                step.clip_url = f"/lessons/{lesson_id}/clips/{step.step_id}"
    
    # Update lesson storage with clip URLs
    lesson = lesson_storage.get(lesson_id)
    if lesson and lesson.ai_teacher_config:
        lesson_storage.update(lesson_id, {
            "ai_teacher_config": lesson.ai_teacher_config
        })


@router.post("", response_model=LessonResponse)
async def create_lesson(
    background_tasks: BackgroundTasks,
    video: UploadFile = File(..., description="Demo video file"),
    title: str = Form(default="Untitled Lesson", description="Lesson title")
):
    """
    Create a new lesson from a demo video.
    
    The backend will:
    1. Save the uploaded video
    2. Extract frames and audio
    3. Use AI to generate procedural steps with timestamps
    4. Extract video clips for each step
    5. Create an AI Teacher configuration
    """
    # Validate file type
    if not video.content_type or not video.content_type.startswith("video/"):
        raise HTTPException(
            status_code=400, 
            detail="File must be a video (mp4, mov, avi, etc.)"
        )
    
    try:
        # Read video content
        content = await video.read()
        
        # Save video
        video_path = await video_processor.save_video(content, video.filename or "video.mp4")
        
        # Get video info for duration
        video_info = video_processor.get_video_info(video_path)
        video_duration = video_info.get("duration", 0)
        
        # Create initial lesson
        lesson = Lesson(
            id=str(uuid.uuid4()),
            title=title,
            demo_video_url=video_path,
            ai_teacher_config=None
        )
        
        # Save initial lesson
        lesson_storage.create(lesson)
        
        # Process video with AI (sends whole video for analysis)
        try:
            # Get AI service based on AI_PROVIDER env var
            ai_service = get_ai_video_service()
            
            # Analyze video - returns steps with exact timestamps
            teacher_config = await ai_service.analyze_video(
                video_path=video_path,
                title=title
            )
            teacher_config.lesson_id = lesson.id
            
            # Extract clips for each step using AI-provided timestamps
            if teacher_config.steps:
                for step in teacher_config.steps:
                    if step.start_time >= 0 and step.end_time > step.start_time:
                        clip_filename = f"{lesson.id}_step_{step.step_id}.mp4"
                        clip_path = video_processor.extract_clip(
                            video_path,
                            step.start_time,
                            step.end_time,
                            clip_filename
                        )
                        if clip_path:
                            step.clip_url = f"/lessons/{lesson.id}/clips/{step.step_id}"
            
            # Update lesson with config
            lesson_storage.update(lesson.id, {
                "ai_teacher_config": teacher_config
            })
            lesson.ai_teacher_config = teacher_config
                
        except Exception as e:
            print(f"AI processing error: {e}")
            import traceback
            traceback.print_exc()
            # Keep lesson but without AI config
        
        return LessonResponse(
            id=lesson.id,
            title=lesson.title,
            demo_video_url=lesson.demo_video_url,
            ai_teacher_config=lesson.ai_teacher_config,
            created_at=lesson.created_at.isoformat()
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to create lesson: {str(e)}")


@router.get("", response_model=List[LessonResponse])
async def list_lessons():
    """
    List all available lessons
    """
    lessons = lesson_storage.get_all()
    return [
        LessonResponse(
            id=l.id,
            title=l.title,
            demo_video_url=l.demo_video_url,
            ai_teacher_config=l.ai_teacher_config,
            created_at=l.created_at.isoformat()
        )
        for l in lessons
    ]


@router.get("/{lesson_id}", response_model=LessonResponse)
async def get_lesson(lesson_id: str):
    """
    Get a specific lesson by ID
    """
    lesson = lesson_storage.get(lesson_id)
    
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    
    return LessonResponse(
        id=lesson.id,
        title=lesson.title,
        demo_video_url=lesson.demo_video_url,
        ai_teacher_config=lesson.ai_teacher_config,
        created_at=lesson.created_at.isoformat()
    )


@router.get("/{lesson_id}/clips/{step_id}")
async def get_step_clip(lesson_id: str, step_id: int):
    """
    Get the video clip for a specific step
    """
    clip_path = Path(f"storage/clips/{lesson_id}_step_{step_id}.mp4")
    
    if not clip_path.exists():
        raise HTTPException(status_code=404, detail="Clip not found")
    
    return FileResponse(
        clip_path,
        media_type="video/mp4",
        filename=f"step_{step_id}.mp4"
    )


@router.post("/{lesson_id}/regenerate-clips", response_model=LessonResponse)
async def regenerate_clips(lesson_id: str):
    """
    Regenerate video clips for each step of an existing lesson.
    Useful if clips were not created initially or need to be recreated.
    """
    lesson = lesson_storage.get(lesson_id)
    
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    
    if not lesson.ai_teacher_config or not lesson.ai_teacher_config.steps:
        raise HTTPException(status_code=400, detail="Lesson has no steps to extract clips from")
    
    # Extract clips for each step
    for step in lesson.ai_teacher_config.steps:
        if step.start_time >= 0 and step.end_time > step.start_time:
            clip_filename = f"{lesson.id}_step_{step.step_id}.mp4"
            clip_path = video_processor.extract_clip(
                lesson.demo_video_url,
                step.start_time,
                step.end_time,
                clip_filename
            )
            if clip_path:
                step.clip_url = f"/lessons/{lesson.id}/clips/{step.step_id}"
    
    # Update lesson storage with clip URLs
    lesson_storage.update(lesson.id, {
        "ai_teacher_config": lesson.ai_teacher_config
    })
    
    return LessonResponse(
        id=lesson.id,
        title=lesson.title,
        demo_video_url=lesson.demo_video_url,
        ai_teacher_config=lesson.ai_teacher_config,
        created_at=lesson.created_at.isoformat()
    )


@router.delete("/{lesson_id}")
async def delete_lesson(lesson_id: str):
    """
    Delete a lesson
    """
    success = lesson_storage.delete(lesson_id)
    
    if not success:
        raise HTTPException(status_code=404, detail="Lesson not found")
    
    return {"message": "Lesson deleted successfully"}
