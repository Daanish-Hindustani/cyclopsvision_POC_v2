"""
CyclopsVision Backend - Main FastAPI Application
POC for AI-Guided AR Training System
"""
import os
from pathlib import Path
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

from routers import lessons_router, ai_feedback_router, verification, tts


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler"""
    # Startup
    print("🚀 CyclopsVision Backend starting...")
    
    # Ensure storage directories exist
    Path("storage/videos").mkdir(parents=True, exist_ok=True)
    
    # Check for API key
    # Check for API key
    if not os.getenv("OPENAI_API_KEY"):
        print("⚠️  Warning: OPENAI_API_KEY not set. AI features will be unavailable.")
    else:
        print("✅ OpenAI API key configured")
    
    yield
    
    # Shutdown
    print("👋 CyclopsVision Backend shutting down...")


# Create FastAPI application
app = FastAPI(
    title="CyclopsVision API",
    description="""
    AI-Guided AR Training System - Backend API
    
    ## Features
    
    - **Lesson Creation**: Upload demo videos to automatically generate training lessons
    - **AI Step Extraction**: OpenAI GPT-4o analyzes videos to extract procedural steps
    - **Real-time Feedback**: Generate diagram-style overlays for mistake correction
    
    ## Endpoints
    
    - `POST /lessons` - Create a new lesson from video
    - `GET /lessons` - List all lessons
    - `GET /lessons/{id}` - Get specific lesson
    - `POST /ai/feedback` - Get correction overlay for detected mistake
    """,
    version="0.1.0",
    lifespan=lifespan
)

# Configure CORS for web app and iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # POC: Allow all origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for video serving
app.mount("/storage", StaticFiles(directory="storage"), name="storage")

# Include routers
# Include routers
app.include_router(lessons_router) # Preserved at root for existing clients
app.include_router(ai_feedback_router, prefix="/api")
app.include_router(verification.router, prefix="/api")
app.include_router(tts.router, prefix="/api")


@app.get("/")
async def root():
    """Root endpoint with API info"""
    return {
        "name": "CyclopsVision API",
        "version": "0.1.0",
        "status": "running",
        "docs": "/docs",
        "endpoints": {
            "lessons": "/lessons",
            "ai_feedback": "/ai/feedback",
            "health": "/ai/health"
        }
    }


@app.get("/health")
async def health():
    """Health check endpoint"""
    return {"status": "healthy"}


if __name__ == "__main__":
    import uvicorn
    
    host = os.getenv("HOST", "0.0.0.0")
    port = int(os.getenv("PORT", "8000"))
    debug = os.getenv("DEBUG", "false").lower() == "true"
    
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=debug
    )
