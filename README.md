# CyclopsVision – AI-Guided AR Training POC

A zero-auth proof-of-concept AR + AI training system that demonstrates:

- ✅ Lesson creation from demo videos
- ✅ Automatic AI extraction of procedural steps
- ✅ Generation of AI Teacher configurations
- ✅ Real-time step tracking and mistake detection on iOS
- ✅ Cloud-based AI correction with diagram-style visual overlays
- ✅ End-to-end AR guidance using real Swift (iOS) and a real backend web app

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Web App       │     │   Backend API   │     │   iOS App       │
│   (Next.js)     │────▶│   (FastAPI)     │◀────│   (Swift)       │
│                 │     │                 │     │                 │
│ • Upload video  │     │ • Gemini AI     │     │ • Camera feed   │
│ • View steps    │     │ • Step extract  │     │ • VLM on-device │
│ • Get config    │     │ • Overlays      │     │ • AR overlays   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Quick Start

### 1. Backend Setup

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env
# Edit .env and add your GEMINI_API_KEY

# Run the server
python main.py
```

The backend will be available at `http://localhost:8000`
- API docs: `http://localhost:8000/docs`

### 2. Web App Setup

```bash
cd web

# Install dependencies
npm install

# Run development server
npm run dev
```

The web app will be available at `http://localhost:3000`

### 3. iOS App Setup

1. Open `ios/CyclopsVision/CyclopsVision.xcodeproj` in Xcode
2. Select your development team in Signing & Capabilities
3. Build and run on a physical device (camera required)

## Getting a Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Click "Create API Key"
3. Copy the key and paste it in `backend/.env`

The free tier includes:
- 60 requests per minute
- 1,500 requests per day

## Usage

### Creating a Lesson

1. Open the web app at `http://localhost:3000`
2. Enter a lesson title (e.g., "How to Wire a Terminal")
3. Upload a demo video showing the procedure
4. Wait for AI processing (~10-30 seconds)
5. View the extracted steps and AI Teacher configuration

### Running a Lesson on iOS

1. Open the CyclopsVision app on your iPhone
2. Make sure the backend URL is configured in Settings
3. Select a lesson from the list
4. Follow the on-screen steps
5. When a mistake is detected, an AR overlay will appear with correction guidance

### Demo Controls (iOS)

The iOS app includes demo controls for testing:

- **Mistake**: Manually trigger a mistake detection
- **Next**: Advance to the next step
- **Overlay**: Toggle the overlay visibility
- **Audio**: Replay the audio instruction

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `POST /lessons` | Create lesson from video upload |
| `GET /lessons` | List all lessons |
| `GET /lessons/{id}` | Get specific lesson |
| `DELETE /lessons/{id}` | Delete a lesson |
| `POST /ai/feedback` | Get correction overlay for mistake |
| `GET /health` | Health check |

## Project Structure

```
cyclopsvision_POC_v2/
├── backend/                 # FastAPI backend
│   ├── main.py             # App entry point
│   ├── models/             # Pydantic models
│   ├── routers/            # API routes
│   ├── services/           # Business logic
│   └── storage/            # Local file storage
├── web/                    # Next.js web app
│   ├── app/                # App router pages
│   ├── components/         # React components
│   └── lib/                # Utilities
└── ios/                    # iOS Swift app
    └── CyclopsVision/
        ├── Models/         # Data models
        ├── Services/       # Camera, Vision, Audio
        ├── Views/          # SwiftUI views
        └── Overlays/       # Diagram rendering
```

## Technology Stack

### Backend
- **FastAPI** - Python web framework
- **Google Gemini** - AI for video analysis and step extraction
- **MoviePy** - Video processing

### Web App
- **Next.js 15** - React framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling

### iOS App
- **SwiftUI** - UI framework
- **AVFoundation** - Camera capture
- **Vision** - On-device AI
- **AVSpeechSynthesizer** - Text-to-speech

## Success Criteria

The POC is successful if:

1. ✅ A demo video produces usable steps automatically
2. ✅ The AI detects a mistake on-device
3. ✅ The backend generates diagram-style overlay + audio correction
4. ✅ Overlays look like instruction manuals, not bounding boxes
5. ✅ Latency feels near real-time

## License

This is a proof-of-concept for demonstration purposes only.
