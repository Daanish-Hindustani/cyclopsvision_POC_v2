"""
CyclopsVision Backend - Overlay Instruction Models
"""
from pydantic import BaseModel, Field
from typing import List, Literal, Optional, Union
from enum import Enum


class OverlayElementType(str, Enum):
    CIRCLE = "circle"
    ARROW = "arrow"
    LABEL = "label"
    RECTANGLE = "rectangle"


class CircleElement(BaseModel):
    """Circle/ring highlighting a component"""
    type: Literal["circle"] = "circle"
    center: List[float] = Field(..., description="[x, y] normalized coordinates (0-1)")
    radius: float = Field(..., description="Radius as fraction of screen width")
    color: str = Field(default="#FFD700", description="Hex color")
    stroke_width: float = Field(default=3.0, description="Line thickness")
    style: str = Field(default="solid", description="solid or dashed")
    fill: Optional[str] = Field(None, description="Optional fill color with alpha")


class ArrowElement(BaseModel):
    """Directional arrow for guidance"""
    type: Literal["arrow"] = "arrow"
    from_point: List[float] = Field(..., alias="from", description="[x, y] start point (normalized)")
    to_point: List[float] = Field(..., alias="to", description="[x, y] end point (normalized)")
    color: str = Field(default="#FF4444", description="Hex color")
    stroke_width: float = Field(default=3.0, description="Line thickness")
    style: str = Field(default="solid", description="solid or curved")
    head_style: str = Field(default="filled", description="Arrow head style")

    class Config:
        populate_by_name = True


class LabelElement(BaseModel):
    """Text callout label"""
    type: Literal["label"] = "label"
    position: List[float] = Field(..., description="[x, y] normalized coordinates")
    text: str = Field(..., description="Label text")
    font_size: int = Field(default=14, description="Font size in points")
    color: str = Field(default="#FFFFFF", description="Text color")
    background: Optional[str] = Field(default="#000000AA", description="Background color with alpha")


class RectangleElement(BaseModel):
    """Rectangle for highlighting areas"""
    type: Literal["rectangle"] = "rectangle"
    origin: List[float] = Field(..., description="[x, y] top-left corner (normalized)")
    size: List[float] = Field(..., description="[width, height] (normalized)")
    color: str = Field(default="#00FF00", description="Stroke color")
    stroke_width: float = Field(default=2.0)
    corner_radius: float = Field(default=0.0, description="Corner rounding")


OverlayElement = Union[CircleElement, ArrowElement, LabelElement, RectangleElement]


class OverlayInstruction(BaseModel):
    """Complete overlay instruction for iOS rendering"""
    overlay_type: str = Field(default="diagram", description="Type of overlay")
    audio_text: str = Field(..., description="TTS-ready correction text")
    elements: List[OverlayElement] = Field(default_factory=list, description="Visual elements to render")
    duration_seconds: float = Field(default=5.0, description="How long to display overlay")


class FeedbackRequest(BaseModel):
    """Request model for AI feedback endpoint"""
    lesson_id: str = Field(..., description="Current lesson ID")
    step_id: int = Field(..., description="Current step index")
    mistake_type: str = Field(..., description="Detected mistake type")
    confidence: float = Field(..., ge=0.0, le=1.0, description="Detection confidence")
    frame_base64: Optional[str] = Field(None, description="Base64-encoded frame image")


class FeedbackResponse(BaseModel):
    """Response model for AI feedback endpoint"""
    success: bool
    overlay: Optional[OverlayInstruction]
    message: str = ""
