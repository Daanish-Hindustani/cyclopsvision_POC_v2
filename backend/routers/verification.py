"""
CyclopsVision Backend - Step Verification Router
Uses Ollama VLM for continuous step monitoring
Returns: in_progress | complete | mistake
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional, Literal
import logging
import time
import json
import re

router = APIRouter()
logger = logging.getLogger(__name__)

# Rate Limiting
LAST_REQUEST_TIME = {}
RATE_LIMIT_SECONDS = 2.0  # Allow checks every 2 seconds


class VerificationRequest(BaseModel):
    lesson_id: str
    step_id: int
    step_title: str
    step_description: str
    frames_base64: list[str]  # 3-5 frames for temporal context


class VerificationResponse(BaseModel):
    status: Literal["in_progress", "complete", "mistake"]
    reason: str
    confidence: float
    suggestion: Optional[str] = None  # What to fix if mistake


@router.post("/verify_step", response_model=VerificationResponse)
async def verify_step_completion(request: VerificationRequest):
    """
    Continuous step monitoring using Ollama VLM.
    Returns status: in_progress, complete, or mistake.
    """
    # Check Rate Limit
    now = time.time()
    last_time = LAST_REQUEST_TIME.get(request.lesson_id, 0)
    if now - last_time < RATE_LIMIT_SECONDS:
        return VerificationResponse(
            status="in_progress",
            reason="Checking...",
            confidence=0.0,
            suggestion=None
        )
    
    LAST_REQUEST_TIME[request.lesson_id] = now
    
    logger.info(f"🔍 Checking step {request.step_id}: '{request.step_title}' ({len(request.frames_base64)} frames)")
    
    # Use Ollama service
    from services.ai_service import OllamaVideoService
    
    try:
        ai_service = OllamaVideoService()
    except Exception as e:
        logger.error(f"Failed to initialize Ollama: {e}")
        return VerificationResponse(
            status="in_progress",
            reason="AI unavailable",
            confidence=0.0,
            suggestion="Check Ollama"
        )
    
    try:
        # Build monitoring prompt
        prompt = f"""You are monitoring a student performing a procedural task step-by-step.

CURRENT STEP:
Title: {request.step_title}
Description: {request.step_description}

You are shown {len(request.frames_base64)} frames captured over ~2 seconds.

ANALYZE and determine the status:

1. "in_progress" - User is still working on the step, hasn't completed it yet
2. "complete" - The step has been successfully completed (matches AFTER state)
3. "mistake" - User made an error that needs correction

OUTPUT FORMAT (JSON only):
{{
    "status": "in_progress" | "complete" | "mistake",
    "confidence": 0.0 to 1.0,
    "reason": "Brief observation (max 8 words)",
    "suggestion": "What to fix (only if mistake, else null)"
}}

GUIDELINES:
- CHECK TOOL USAGE: Verify that the user is using the specific tools mentioned in the step description.
- If the WRONG tool is used, mark status as "mistake" and reason as "Wrong tool".
- Be patient: Don't mark complete until you're CERTAIN the result is correct
- Be helpful: If there's a clear mistake, identify it specifically
- Most frames will be "in_progress" - that's normal

Return ONLY JSON, no other text."""

        # Build message with multiple frames
        user_content = [{"type": "text", "text": prompt}]
        
        for b64 in request.frames_base64:
            user_content.append({
                "type": "image_url",
                "image_url": {
                    "url": f"data:image/jpeg;base64,{b64}",
                    "detail": "low"
                }
            })
        
        # Call Ollama
        response = await ai_service.client.chat.completions.create(
            model=ai_service.model,
            messages=[
                {"role": "system", "content": "You are a patient teacher monitoring a student. Output only valid JSON."},
                {"role": "user", "content": user_content}
            ],
            temperature=0.1
        )
        
        result = response.choices[0].message.content
        logger.info(f"VLM response: {result[:300]}...")
        
        # Parse JSON from response
        try:
            match = re.search(r"\{.*\}", result, re.DOTALL)
            if match:
                data = json.loads(match.group())
                status = data.get("status", "in_progress")
                
                # Validate status
                if status not in ["in_progress", "complete", "mistake"]:
                    status = "in_progress"
                
                return VerificationResponse(
                    status=status,
                    reason=data.get("reason", "Analyzing..."),
                    confidence=data.get("confidence", 0.5),
                    suggestion=data.get("suggestion")
                )
            else:
                return VerificationResponse(
                    status="in_progress",
                    reason="Processing...",
                    confidence=0.0,
                    suggestion=None
                )
        except json.JSONDecodeError as e:
            logger.warning(f"JSON parse error: {e}")
            return VerificationResponse(
                status="in_progress",
                reason="Analyzing...",
                confidence=0.0,
                suggestion=None
            )

    except Exception as e:
        logger.error(f"Verification failed: {e}")
        return VerificationResponse(
            status="in_progress",
            reason="Error",
            confidence=0.0,
            suggestion=str(e)[:50]
        )
