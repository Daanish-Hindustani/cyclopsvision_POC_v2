# CyclopsVision Makefile
# Run both backend and webapp with: make run

.PHONY: run backend web install install-backend install-web clean clean-ports help

# Clean up ports before starting (kills any process using 8000 or 3000)
clean-ports:
	@echo "🧹 Cleaning up ports 8000 and 3000..."
	@-lsof -ti:8000 | xargs kill -9 2>/dev/null || true
	@-lsof -ti:3000 | xargs kill -9 2>/dev/null || true
	@echo "✅ Ports cleared"

# Default target: run both backend and webapp
run: clean-ports
	@echo "🚀 Starting CyclopsVision (Backend + Web App)..."
	@make -j2 backend web

# Run backend only
backend:
	@echo "🔧 Starting Backend on http://localhost:8000"
	@./start-backend.sh

# Run web app only
web:
	@echo "🌐 Starting Web App on http://localhost:3000"
	@./start-web.sh

# Install all dependencies
install: install-backend install-web
	@echo "✅ All dependencies installed"

# Install backend dependencies
install-backend:
	@echo "📦 Installing backend dependencies..."
	@cd backend && \
		python3 -m venv venv && \
		. venv/bin/activate && \
		pip install -r requirements.txt

# Install web dependencies
install-web:
	@echo "📦 Installing web dependencies..."
	@cd web && npm install

# Setup environment (create .env from template)
setup:
	@echo "⚙️  Setting up environment..."
	@if [ ! -f backend/.env ]; then \
		cp backend/.env.example backend/.env; \
		echo "✅ Created backend/.env from template"; \
		echo "⚠️  Please edit backend/.env and add your GEMINI_API_KEY"; \
	else \
		echo "ℹ️  backend/.env already exists"; \
	fi

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	@rm -rf backend/__pycache__ backend/**/__pycache__
	@rm -rf web/.next web/node_modules/.cache
	@echo "✅ Cleaned"

# Show help
help:
	@echo "CyclopsVision Makefile Commands:"
	@echo ""
	@echo "  make run            - Run both backend and web app (default)"
	@echo "  make backend        - Run backend only"
	@echo "  make web            - Run web app only"
	@echo "  make install        - Install all dependencies"
	@echo "  make install-backend - Install backend dependencies"
	@echo "  make install-web    - Install web dependencies"
	@echo "  make setup          - Create .env from template"
	@echo "  make clean          - Clean build artifacts"
	@echo "  make clean-ports    - Kill processes on ports 8000 and 3000"
	@echo "  make help           - Show this help"
