"""
CyclopsVision Backend - AI Feedback Router
Handles real-time mistake feedback and overlay generation
"""
from fastapi import APIRouter, HTTPException
from typing import Optional

from models import (
    FeedbackRequest, 
    FeedbackResponse, 
    OverlayInstruction,
    Step
)
from services import get_gemini_service, lesson_storage

router = APIRouter(prefix="/ai", tags=["ai"])


@router.post("/feedback", response_model=FeedbackResponse)
async def get_feedback(request: FeedbackRequest):
    """
    Process a detected mistake and generate corrective feedback.
    
    Called by the iOS app when a mistake is detected on-device.
    Returns diagram-style overlay instructions and audio text.
    """
    # Get the lesson
    lesson = lesson_storage.get(request.lesson_id)
    
    if not lesson:
        raise HTTPException(status_code=404, detail="Lesson not found")
    
    if not lesson.ai_teacher_config:
        raise HTTPException(status_code=400, detail="Lesson has no AI teacher config")
    
    # Find the current step
    current_step: Optional[Step] = None
    for step in lesson.ai_teacher_config.steps:
        if step.step_id == request.step_id:
            current_step = step
            break
    
    if not current_step:
        raise HTTPException(
            status_code=400, 
            detail=f"Step {request.step_id} not found in lesson"
        )
    
    try:
        # Generate correction overlay using Gemini
        gemini = get_gemini_service()
        overlay_data = await gemini.generate_correction_overlay(
            step=current_step,
            mistake_type=request.mistake_type,
            frame_base64=request.frame_base64
        )
        
        # Build overlay instruction
        overlay = OverlayInstruction(
            overlay_type=overlay_data.get("overlay_type", "diagram"),
            audio_text=overlay_data.get("audio_text", "Please adjust your technique."),
            elements=overlay_data.get("elements", []),
            duration_seconds=overlay_data.get("duration_seconds", 5.0)
        )
        
        return FeedbackResponse(
            success=True,
            overlay=overlay,
            message="Correction generated successfully"
        )
        
    except Exception as e:
        print(f"Feedback generation error: {e}")
        
        # Return a fallback response
        fallback_overlay = OverlayInstruction(
            overlay_type="diagram",
            audio_text=f"Please check your technique for: {current_step.title}",
            elements=[
                {
                    "type": "label",
                    "position": [0.5, 0.1],
                    "text": f"Review: {current_step.title}",
                    "font_size": 18,
                    "color": "#FFFFFF",
                    "background": "#FF4444CC"
                }
            ],
            duration_seconds=5.0
        )
        
        return FeedbackResponse(
            success=True,
            overlay=fallback_overlay,
            message="Using fallback correction"
        )


@router.get("/health")
async def health_check():
    """
    Check if AI services are available
    """
    try:
        gemini = get_gemini_service()
        return {
            "status": "healthy",
            "ai_service": "gemini",
            "model": "gemini-1.5-flash"
        }
    except Exception as e:
        return {
            "status": "degraded",
            "error": str(e)
        }
