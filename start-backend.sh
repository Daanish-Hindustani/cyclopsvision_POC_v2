#!/bin/bash

# CyclopsVision Backend Startup Script

echo "🚀 Starting CyclopsVision Backend..."

cd "$(dirname "$0")/backend"

# Check if virtual environment exists
if [ ! -d "venv" ]; then
    echo "📦 Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install/update dependencies
echo "📦 Installing dependencies..."
pip install -r requirements.txt --quiet

# Check for .env file
if [ ! -f ".env" ]; then
    echo "⚠️  No .env file found. Creating from template..."
    cp .env.example .env
    echo "   Please edit backend/.env and add your GEMINI_API_KEY"
    echo ""
fi

# Check for API key
if grep -q "your_gemini_api_key_here" .env; then
    echo "⚠️  WARNING: GEMINI_API_KEY not set in .env"
    echo "   AI features will not work without a valid API key."
    echo "   Get one at: https://makersuite.google.com/app/apikey"
    echo ""
fi

# Run the server
echo "🌐 Starting FastAPI server on http://localhost:8000"
echo "📚 API docs available at http://localhost:8000/docs"
echo ""
python main.py
