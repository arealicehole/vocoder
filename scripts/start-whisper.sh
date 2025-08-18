#!/usr/bin/env bash
# start-whisper.sh - Start the Whisper API service

set -euo pipefail

echo "Starting Whisper API service..."

# Check if running in Docker
if docker ps | grep -q whisper; then
    echo "✓ Whisper already running in Docker"
    exit 0
fi

# Check if systemd service exists
if systemctl --user list-unit-files | grep -q whisper-api; then
    echo "Starting via systemd..."
    systemctl --user start whisper-api.service
    sleep 2
    if systemctl --user is-active whisper-api.service >/dev/null; then
        echo "✓ Whisper API started via systemd"
    else
        echo "✗ Failed to start via systemd"
        exit 1
    fi
else
    echo "No whisper-api.service found."
    echo ""
    echo "To set up Whisper, you need one of:"
    echo "1. Docker container:"
    echo "   docker run -d -p 9000:9000 onerahmet/openai-whisper-asr-webservice:latest"
    echo ""
    echo "2. Python service (if you have the FastAPI app):"
    echo "   cd /path/to/whisper-api"
    echo "   uvicorn main:app --host 127.0.0.1 --port 8765"
    echo ""
    echo "3. Create systemd service at ~/.config/systemd/user/whisper-api.service"
    exit 1
fi

# Test the API
echo -n "Testing API health... "
if curl -s -f "http://127.0.0.1:8765/health" >/dev/null 2>&1; then
    echo "✓ API is healthy"
else
    echo "✗ API not responding"
    exit 1
fi