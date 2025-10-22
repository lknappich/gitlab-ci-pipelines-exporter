#!/bin/bash

# Simple test server for the GitLab CI Dashboard
echo "🦊 Starting GitLab CI Dashboard Test Server"
echo "=========================================="

# Check if Python is available
if command -v python3 &> /dev/null; then
    echo "Using Python 3 HTTP server..."
    cd web
    echo "Frontend available at: http://localhost:3000"
    echo "Note: You'll need to set GCPE_GITLAB_TOKEN and start the exporter separately"
    echo ""
    echo "To start the exporter:"
    echo "  export GCPE_GITLAB_TOKEN=your_actual_gitlab_token"
    echo "  sudo docker compose up -d"
    echo ""
    echo "Starting frontend server..."
    python3 -m http.server 3000
elif command -v python &> /dev/null; then
    echo "Using Python 2 HTTP server..."
    cd web
    echo "Frontend available at: http://localhost:3000"
    python -m SimpleHTTPServer 3000
else
    echo "Python not found. Please install Python or use a different web server."
    exit 1
fi
