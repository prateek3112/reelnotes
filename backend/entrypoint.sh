#!/bin/bash
set -e

# Port provided by Render or default to 8000
PORT="${PORT:-8000}"

echo "=================================================="
echo "🚀 Starting ReelVault on Render"
echo "Port: $PORT"
echo "=================================================="

# Start background worker poller process
echo "⚙️ Starting background worker poller..."
python -m app.workers.poller &
WORKER_PID=$!
echo "✓ Worker process started with PID: $WORKER_PID"

# Function to gracefully shut down both processes
cleanup() {
    echo "Shutting down worker PID $WORKER_PID..."
    kill -TERM "$WORKER_PID" 2>/dev/null || true
    wait "$WORKER_PID" 2>/dev/null || true
    exit 0
}

trap cleanup SIGINT SIGTERM

# Start FastAPI web server on Render's assigned $PORT
echo "🌐 Starting FastAPI server on 0.0.0.0:$PORT..."
exec uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
