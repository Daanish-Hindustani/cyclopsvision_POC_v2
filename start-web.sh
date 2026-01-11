#!/bin/bash

# CyclopsVision Web App Startup Script

echo "🚀 Starting CyclopsVision Web App..."

cd "$(dirname "$0")/web"

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Run development server
echo "🌐 Starting Next.js on http://localhost:3000"
echo ""
npm run dev
